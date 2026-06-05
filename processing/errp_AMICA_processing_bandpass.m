clearvars; clc;

subject = 'sub_errp_al_2';
includepat  = {subject};
excludepat  = {};
depthlevel  = 2;

spatialfilter = 'car';
eegchannels    = {'FP1', 'FP2', 'F1', 'FZ', 'F2', 'FC1', 'FCz', 'FC2', 'C1', 'CZ', 'C2', 'CP1', 'CP2'};

datapath   = ['analysis/amica/cleaned/' num2str(length(eegchannels)) '/'];
savedir    = ['analysis/amica/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];

%% Processing parameters
filter.order = 4;
filter.bands = [2 16];

%% Get datafiles
files = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat);

nfiles = length(files);
if(nfiles > 0)
    util_bdisp(['[io] - Found ' num2str(nfiles) ' files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
else
    error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
end

%% Create directory
util_mkdir(pwd, savedir);

for fId = 1:nfiles

    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);

    util_bdisp(['[io] + Loading cleaned data ' num2str(fId) '/' num2str(nfiles)]);
    disp(['     |-File: ' cfullname]);
    
    data = load(cfullname);
    
    eeg        = double(data.eeg);
    eog        = double(data.eog);
    events     = data.settings.events;
    samplerate = data.settings.samplerate;

    %% Processing data
    util_bdisp('[proc] + Processing the data');
    disp(['       |- Bandpass filter order ' num2str(filter.order) ': [' strjoin(compose('%g', filter.bands), ' ') '] Hz']);
   
    % Compute bandpass filters
    eeg_bp = filt_bp(eeg, filter.order, filter.bands, samplerate);
    eog_bp = filt_bp(eog, filter.order, filter.bands, samplerate);
    
    %% Storing data and information
    cinfo = errp_util_get_info(cfullname);

    settings                = data.settings;
    settings.filter         = filter;
    settings.task.name      = cinfo.task;
    settings.device.name    = cinfo.extra1;
    settings.control.name   = cinfo.extra2;
    settings.control.legend = {'discrete', 'continuous', 'unknown'};
    settings.info           = cinfo;

    eeg = eeg_bp;
    eog = eog_bp;

    %% Saving bandpassed data
    sfilename = fullfile(savedir, [cfilename '.mat']);
    util_bdisp(['[out] - Saving bandpass in: ' sfilename]);
    save(sfilename, 'eeg', 'eog', 'settings'); 

end