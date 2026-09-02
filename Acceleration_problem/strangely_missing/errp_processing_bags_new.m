function errp_processing_bags_new(includepat, excludepat, depthlevel, setting, bagpath, savedir)


subject = setting.includepat;
 

%% Processing parameters
samplerate  = setting.samplerate;

%Stop        = setting.ev_cod.Stop;
%CommandLx   = setting.ev_cod.CommandLx;
%CommandFx   = setting.ev_cod.CommandFx;
%CommandRx   = setting.ev_cod.CommandRx;
%ErrorLx     = setting.ev_cod.ErrorLx;
%ErrorRx     = setting.ev_cod.ErrorRx;

%NoReleaseLx = setting.ev_cod.NoReleaseLx;
%NoReleaseFx = setting.ev_cod.NoReleaseFx;
%NoReleaseRx = setting.ev_cod.NoReleaseRx;



%% Get datafiles
files = util_getfile3(bagpath, '.bag', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);

nfiles = length(files);
if(nfiles > 0)
    util_bdisp(['[io] - Found ' num2str(nfiles) ' files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
else
    error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
end

%% Create/Check for savepath
util_mkdir(pwd, savedir);

%% Processing files
minmax_errors = nan(nfiles, 2);
errors = [];
for fId = 1:nfiles

    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);

    sfilename = fullfile(savedir, [cfilename '.mat']);
    if isfile(sfilename)
        % skip this iteration completely
        disp(['     |- Precomputed skippiing:  ' sfilename ]);
        continue
    end
    
    util_bdisp(['[io] + Loading file ' num2str(fId) '/' num2str(nfiles)]);
    disp(['     |-File: ' cfullname]);
    
    % Read the bag
    bag = rosbagreader(cfullname);
    
    % Select the available topics
    disp('     |-Selecting topics from bag');
    seljoy    = select(bag, 'Topic', '/joy');
    selevent  = select(bag, 'Topic', '/events/bus');
    selodom  = select(bag, 'Topic', '/wcias_controller/odom');
    selcmdvel = select(bag, 'Topic', '/cmd_vel');
    
    % Read message for joy and events
    disp('     |-Extracting button and neuro events');
    msgjoy = readMessages(seljoy, 'DataFormat', 'struct');
    msgevt = readMessages(selevent, 'DataFormat', 'struct');
    
    % Extract button press
    % 19/11/2025 -- Pireo --- Moved from m.Button to m.Axes , 1 -> 7
    is_button_valid = cellfun(@(m) isempty(find(m.Axes, 7)) == false, msgjoy);
    button_value    = cellfun(@(m) find(m.Axes, 7), msgjoy, 'UniformOutput',false);
    button_value    = cell2mat(button_value(is_button_valid));
    button_time     = cellfun(@(m) double(m.Header.Stamp.Sec) + double(m.Header.Stamp.Nsec)*10^-9, msgjoy, 'UniformOutput', false);
    button_time     = cell2mat(button_time(is_button_valid));
    
    % Extract neuroevents
    event_value = cellfun(@(m) double(m.Event), msgevt);
    event_time  = cellfun(@(m) double(m.Header.Stamp.Sec) + double(m.Header.Stamp.Nsec)*10^-9, msgevt);
    
    
    % Get timeseries (not-uniform)
    disp('     |-Extracting timeseries');
    nuodom   = timeseries(selodom, 'Pose.Pose.Position.X', 'Pose.Pose.Position.Y', 'Pose.Pose.Position.Z', ...
                                   'Twist.Twist.Linear.X', 'Twist.Twist.Linear.Y', 'Twist.Twist.Angular.Z');
    nucmdvel = timeseries(selcmdvel, 'Linear.X', 'Linear.Y', 'Angular.Z');
    
    % Synchronize timeseries
    disp('     |-Synchronizing timeseries');
    [sodom, scmdvel] = synchronize(nuodom, nucmdvel, 'union');
    
    % Resample timeseries
    disp('     |-Resampling timeseries');
    t_common = sodom.Time(1):1/samplerate:sodom.Time(end)-1/samplerate;
    rodom   = resample(sodom, t_common);
    rcmdvel = resample(scmdvel, t_common);

    % Padding to the start of the bag
    disp('     |-Padding to match begin and end of bag');
    t_pad_begin = flipud((rcmdvel.Time(1)-1/samplerate:-1/samplerate:bag.StartTime-1/samplerate)');
    t_pad_end   = (rcmdvel.Time(end)+1/samplerate:1/samplerate:bag.EndTime+1/samplerate)';
    rodom = addsample(rodom, 'Time', t_pad_begin, 'Data', zeros(length(t_pad_begin), size(rodom.Data, 2)));
    rodom = addsample(rodom, 'Time', t_pad_end, 'Data', zeros(length(t_pad_end), size(rodom.Data, 2)));
    rcmdvel = addsample(rcmdvel, 'Time', t_pad_begin, 'Data', zeros(length(t_pad_begin), size(rcmdvel.Data, 2)));
    rcmdvel = addsample(rcmdvel, 'Time', t_pad_end, 'Data', zeros(length(t_pad_end), size(rcmdvel.Data, 2)));
    
    % Align button and neuro event
    disp('     |-Aligning events to resampled time support');
    t_align = rodom.Time(1):1/samplerate:rodom.Time(end)-1/samplerate;
    %% 19/11/2025 - piero
    try
        [buttonPOS, buttonERR] = errp_find_closest(button_time, t_align);
    catch
        buttonPOS = [];
        buttonERR = [];
    end
    [neuroPOS, neuroERR]   = errp_find_closest(event_time, t_align);
    
    % Create event structure
    buttonTYP = button_value;
    neuroTYP  = event_value;
    mergedPOS = [buttonPOS neuroPOS];
    mergedERR = [buttonERR neuroERR];
    mergedTYP = [buttonTYP' neuroTYP'];
    [events.POS, sindex] = sort(mergedPOS);
    events.ERR = mergedERR(sindex);
    events.TYP = mergedTYP(sindex);
    events.POS = events.POS';
    events.TYP = events.TYP';
    events.ERR = events.ERR';
    
    % Create data structure
    pose.x  = rodom.Data(:, 1);
    pose.y  = rodom.Data(:, 2);
    pose.z  = rodom.Data(:, 3);
    twist.x = rodom.Data(:, 4);
    twist.y = rodom.Data(:, 5);
    twist.z = rodom.Data(:, 6);
    cmdvel.x = rcmdvel.Data(:, 1);
    cmdvel.y = rcmdvel.Data(:, 2);
    cmdvel.z = rcmdvel.Data(:, 3);
    
    errors = cat(1, errors, events.ERR);
    minmax_errors(fId, :) = [min(events.ERR) max(events.ERR)];
     
    % Saving processed bags
    sfilename = fullfile(savedir, [cfilename '.mat']);
    util_bdisp(['[out] - Saving processed bags in: ' sfilename]);
    save(sfilename, 'pose', 'twist', 'cmdvel', 'events'); 
end

util_bdisp('[check] - Min/max alignment error for events:')
   
for fId = 1:nfiles
    disp(['        |-File ' num2str(fId) ': ' num2str(minmax_errors(fId, 1)*1000, '%7.5f') '/' num2str(minmax_errors(fId, 2)*1000, '%7.5f') ' ms']);
end

% figure;
% histogram(errors*1000);
% grid on;
% title([subject  ' | events resolution error']);
% ylabel('count');
% xlabel('ms');


end


      
      
 


