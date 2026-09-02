function  errp_processing_align_bags_new(includepat, excludepat, depthlevel, setting, savedir_processed, bagpath, gdfpath)


savedir     = savedir_processed;


gdffiles = util_getfile3(gdfpath, '.gdf', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);
bagfiles = util_getfile3(bagpath, '.mat', 'include', includepat, 'exclude', excludepat);
nfiles = length(bagfiles);
util_bdisp(['[io] - Found ' num2str(nfiles) ' data files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') ')']);

%% Create/Check for savepath
util_mkdir(pwd, savedir);

%% Align bags
for fId = 1:nfiles
    cbagfile = bagfiles{fId};
    cgdffile = gdffiles{fId};
    [cbagfilepath, cbagfilename] = fileparts(cbagfile);
    [cgdffilepath, cgdffilename] = fileparts(cgdffile);

    sfilename = fullfile(savedir, [cbagfilename '.mat']);
    if isfile(sfilename)
        % skip this iteration completely
        disp(['     |- Precomputed skippiing:  ' sfilename ]);
        continue
    end
        
    util_bdisp(['[proc] + Loading bag mat file ' num2str(fId) '/' num2str(nfiles) ': ' cbagfile]);
    bagdata = load(cbagfile);
    
    util_bdisp(['[proc] + Loading gdf header file ' num2str(fId) '/' num2str(nfiles) ': ' cgdffile]);
    h = sopen(cgdffile, 'r');
    nsamples = h.NRec*h.SampleRate;

    util_bdisp('[proc] + Find alignment between gdf and bag files:');
    alignment = errp_find_alignment(bagdata.events, h.EVENT);
    disp(['       | Alignment (samples): ' num2str(alignment)]);
    
    util_bdisp('[proc] + Align bag file for:');
    events.TYP = bagdata.events.TYP;
    events.POS = bagdata.events.POS - alignment;
    events.ERR = bagdata.events.ERR;

    % Pose
    disp('       | Pose');
    pose.x    = padding_data(bagdata.pose.x, alignment, nsamples);
    pose.y    = padding_data(bagdata.pose.y, alignment, nsamples);
    pose.z    = padding_data(bagdata.pose.z, alignment, nsamples);

    % Twist
    disp('       | Twist');
    twist.x    = padding_data(bagdata.twist.x, alignment, nsamples);
    twist.y    = padding_data(bagdata.twist.y, alignment, nsamples);
    twist.z    = padding_data(bagdata.twist.z, alignment, nsamples);

    % Command velocity
    disp('       | Command velocity');
    cmdvel.x   = padding_data(bagdata.cmdvel.x, alignment, nsamples);
    cmdvel.y   = padding_data(bagdata.cmdvel.y, alignment, nsamples);
    cmdvel.z   = padding_data(bagdata.cmdvel.z, alignment, nsamples);

    % Saving processed bags
    sfilename = fullfile(savedir, [cbagfilename '.mat']);
    util_bdisp(['[out] - Saving aligned bags in: ' sfilename]);
    save(sfilename, 'pose', 'twist', 'cmdvel', 'events', 'alignment'); 
end



function out = padding_data(in, out_begin_id, out_end_id)

    in_begin_id = 1;
    padstart    = [];


    if(out_begin_id > in_begin_id)
        in_begin_id = out_begin_id;
    else
        padstart = nan(abs(out_begin_id), size(in, 2));
    end

    out = cat(1, padstart, in(in_begin_id:end, :));
    in_end_id   = length(out);
    padend      = [];

    
    if(out_end_id < in_end_id)
        in_end_id = out_end_id;
    else
        padend = nan((out_end_id-in_end_id), size(in, 2));
    end


    out = cat(1, out(1:in_end_id, :), padend);
end

end