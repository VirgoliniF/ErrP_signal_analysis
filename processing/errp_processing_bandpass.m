clearvars; clc;

subject = 'learn_errp_p_4';

task = 'learn';
if (contains(subject, 'learn'))
    task = 'learn';
elseif (contains(subject, 'fb'))
    task = 'calibration';
elseif (contains(subject, 'run'))
    task = 'run';
elseif (contains(subject, 'active'))
    task = 'visual_control';
end

includepat  = {subject};
excludepat  = {'filtered'};
depthlevel  = 2;

rootpath    = '/var/home/piero/Projects/';
folder      = 'gdf_recordings/wheelchiar_errp';
gdfpath       = [rootpath '/' folder '/' task '/' ];

replace_labels = false; 

reframe_to_errp = false; 

%% Setup cap
%chanlocspath  = 'chanlocs64.mat';        %chanlocs
%chanlocspath  = 'ch32Locations.mat';     %ch32Locations
%chanlocspath = 'ErrP_cap_chan_file.mat';  %chan

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
normal32 = {'FP1', 'FPz', 'FP2', 'F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6','M1','T7','C3','Cz','C4', 'T8', 'M2', 'CP5','CP1','CP2','CP6','P7','P3', 'Pz', 'P4', 'P8', 'POz','O1','Oz','O2'};

% For the gyro/acc
sensors = {'sens1','sens2','sens3','sens4','sens5','sens6','sens7','sens8','sens9','sens10','sens11','sens12','sens13','sens14','sens15','sens16','sens17','sens18','sens19','sens20','sens21','sens22','sens23','sens24' };

%l = [errp_cap, 'ref']

remove_mask = {};
%remove_mask = {'M1', 'T7', 'T8', 'M2'};
mask = '';
chanlocspath = '';

% Default
%mask = errp_cap;


if (contains(subject, 'norm') && reframe_to_errp == false)
    mask = normal32;
    chanlocspath  = 'ch32Locations.mat'; 
elseif (contains(subject, 'errp') || reframe_to_errp == true ) || contains(subject, 'test') 
    mask = errp_cap;
    chanlocspath = 'ErrP_cap_chan_file.mat';
end

if contains(subject, 'acc') 
    mask = [mask , sensors];
end

%% Processing parameters

eegchannels = setdiff(mask, remove_mask, 'stable');

eogchannels       = {'Fz'}; % {'EOG'};

chanlocstr        = load(chanlocspath);

chanlocs = '';

if (contains(subject, 'norm') && reframe_to_errp == false)
    chanlocs          = errp_util_get_chanlocs(eegchannels, chanlocstr.ch32Locations);
elseif (contains(subject, 'errp') || reframe_to_errp == true ) || contains(subject, 'test') 
    chanlocs          = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
end

spatial.filter    = 'none';  % {'csd',''car'}
filter.order      = 4;
filter.bands      = [2 10]; % [2-8] -> [2 16] -> [2 10]
savedir           = ['analysis/none/' spatial.filter '/bandpass/' num2str(length(eegchannels)) '/'];

%% Get datafiles
files = util_getfile3(gdfpath, '.gdf', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);

nfiles = length(files);
if(nfiles > 0)
    util_bdisp(['[io] - Found ' num2str(nfiles) ' files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
else
    error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
end

%% Create directory
util_mkdir(pwd, savedir);

%% Processing files
for fId = 1:nfiles
    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);
    
    cfilename_unf = ['unfiltered_' cfilename];
    
    util_bdisp(['[io] + Loading file ' num2str(fId) '/' num2str(nfiles)]);
    disp(['     |- File: ' cfullname]);
    
     %% Loading data
    try
        [s, h] = sload(cfullname); 
    catch ME
        error(['[error] - Cannot load filename. Skipping it. ' Me.message]);
    end

    if replace_labels == true
        % may needed if saved with a wrong cap aias
        h.Label = mask';
    end

    if reframe_to_errp == true
        h.Label = errp_cap';
        cfilename = ['reframe_' cfilename];

        [tf, idx] = ismember(errp_cap, mask);

        tmp_s = zeros(size(s,1), length(errp_cap));

        tmp_s(:, tf) = s(:, idx(tf));

        s = tmp_s;
    end
    
    
    %% Extracting selected EEG channels
    util_bdisp('[proc] + Extracting selected EEG channels (in this ordered):');
    disp(['       |- Channels: ' strjoin(eegchannels, ', ')]);
   
    [~, eegchannelidx] = ismember(lower(eegchannels), lower(h.Label));
    eegchannelidx = eegchannelidx(eegchannelidx ~= 0);
    s_eeg = s(:, eegchannelidx);
    
    %% Extracting selected EOG channels
    util_bdisp('[proc] + Extracting selected EOG channels (in this ordered):');
    disp(['       |- Channels: ' strjoin(eogchannels, ', ')]);
   
    [~, eogchannelidx] = ismember(lower(eogchannels), lower(h.Label));
    s_eog = s(:, eogchannelidx);
    
    
    %% Get information from filename
    cinfo = errp_util_get_info(cfullname);
    
    %% Processing data
    util_bdisp('[proc] + Processing the data');

    % Compute Spatial filter
    disp(['       |- Spatial filter: ' spatial.filter]);

    switch(spatial.filter)
        case 'none'
            s_eeg_spatial = s_eeg;
        case 'car'
            s_eeg_spatial = proc_car(s_eeg, 'excluded', [1 2]);
        case 'laplacian'
            error('Laplacian spatial filter not implemented yet');
        case 'csd'
            [G,H] = GetGH(chanlocs);
            X = CSD (s_eeg', G, H);
            s_eeg_spatial = X';
        otherwise
            error(['Unknown spatial filter selected ' spatial.filter]);
    end
    
    % Compute bandpass filters
    s_eeg_bp = filt_bp(s_eeg_spatial, filter.order, filter.bands, h.SampleRate);
    s_eog_bp = filt_bp(s_eog, filter.order, filter.bands, h.SampleRate);
    
    eeg = s_eeg_bp;
    eog = s_eog_bp;

    if contains(subject, 'acc') 
        tmp = filt_bp(s, 4, [1 100], h.SampleRate);
        eeg(:,33:56) = tmp(:,33:56);
    end

    
    % Extracting events
    disp('       |-Extract events');
    cevents     = h.EVENT;
    events.TYP = cevents.TYP;
    events.POS = cevents.POS;
    events.DUR = cevents.DUR;
    
    % Task
    disp('       |-Extract task info');
    task = cinfo.task;
    
    % Extra
    disp('       |-Extract extra info');
    device  = cinfo.extra1;
    control = 'discrete'; %cinfo.extra2;

    
    %% Create settings structure
    settings.spatial           = spatial;
    settings.filter            = filter;
    settings.channels.eeg      = eegchannels;
    settings.channels.eog      = eogchannels;
    settings.channels.chanlocs = chanlocs;
    settings.events.TYP        = h.EVENT.TYP;
    settings.events.POS        = h.EVENT.POS;
    settings.events.DUR        = h.EVENT.DUR;
    settings.samplerate        = h.SampleRate;
    settings.task.name         = task;
    settings.device.name       = device;
    settings.control.name      = control;
    settings.control.legend    = {'discrete', 'continuous', 'unknown'};
    settings.info              = cinfo;
    
    sfilename = fullfile(savedir, [cfilename '.mat']);
    util_bdisp(['[out] - Saving bandpass in: ' sfilename]);
    save(sfilename, 'eeg', 'eog', 'events', 'settings'); 

    sfilename_unfiltered = fullfile(savedir, [cfilename_unf '.mat']);
    util_bdisp(['[out] - Saving bandpass in: ' sfilename_unfiltered]);

    eeg = filt_bp(s_eeg, filter.order, [0.1 50], h.SampleRate);
    save(sfilename_unfiltered, 'eeg', 'eog', 'events', 'settings'); 
   
end

