clearvars; clc;

subject = 'sub_errp_al_2';

includepat  = {subject};
excludepat  = {};
depthlevel  = 2;

rootpath    = '/var/home/piero/Projects/';
folder      = 'gdf_recordings';
gdfpath       = [rootpath '/' folder '/'];

%% Processing parameters

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
eegchannels  = errp_cap;
eogchannels  = {'AF3'};
filter.order = 4;
filter.bands = [1 45];
savedir      = ['analysis/amica/preprocessed/' num2str(length(eegchannels)) '/'];

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

%% Pre-processing files

for fId = 1:nfiles

    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);
    
    util_bdisp(['[io] + Loading file ' num2str(fId) '/' num2str(nfiles)]);
    disp(['     |- File: ' cfullname]);

    %% Loading data
    try
        [s, h] = sload(cfullname); 
    catch ME
        error(['[error] - Cannot load filename. Skipping it. ' Me.message]);
    end
    
    %% Extracting selected EEG channels
    util_bdisp('[proc] + Extracting selected EEG channels (in this ordered):');
    disp(['       |- Channels: ' strjoin(eegchannels, ', ')]);
   
    [~, eegchannelidx] = ismember(lower(eegchannels), lower(h.Label));
    s_eeg = s(:, eegchannelidx);
    
    %% Extracting selected EOG channels
    util_bdisp('[proc] + Extracting selected EOG channels (in this ordered):');
    disp(['       |- Channels: ' strjoin(eogchannels, ', ')]);
   
    [~, eogchannelidx] = ismember(lower(eogchannels), lower(h.Label));
    s_eog = s(:, eogchannelidx);

    %% Processing data
    util_bdisp('[proc] + Processing EEG the data');

    % Compute spatial filter
    disp('       |- Spatial filter: CAR');
    s_spatial = proc_car(s_eeg);

    % Compute bandpass filters
    disp(['       |- Bandpass filter order ' num2str(filter.order) ': [' strjoin(compose('%g', filter.bands), ' ') '] Hz']);
    s_bp = filt_bp(s_spatial, filter.order, filter.bands, h.SampleRate);

    %% Storing data and settings
    eeg = s_bp;
    eog = s_eog;

    settings.preprocess.spatial = 'car';
    settings.preprocess.filter  = filter;
    settings.channels.eeg       = eegchannels;
    settings.channels.eog       = eogchannels;
    settings.events.TYP         = h.EVENT.TYP;
    settings.events.POS         = h.EVENT.POS;
    settings.events.DUR         = h.EVENT.DUR;
    settings.samplerate         = h.SampleRate;

    %% Saving preprocessed data
    sfilename = fullfile(savedir, [cfilename '.mat']);
    util_bdisp(['[out] + Saving AMICA preprocessed data in: ' sfilename]);
    save(sfilename, 'eeg', 'eog', 'settings'); 
end