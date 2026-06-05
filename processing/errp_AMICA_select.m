clearvars; clc;

subject       = 'sub_errp_al_2';
includepat  = {subject};
excludepat  = {};
depthlevel  = 2;

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
eegchannels    = errp_cap;

amicapath = ['analysis/amica/components/' num2str(length(eegchannels)) '/'];
datapath  = ['analysis/amica/preprocessed/' num2str(length(eegchannels)) '/'];
savedir   = ['analysis/amica/cleaned/' num2str(length(eegchannels)) '/'];

%% Get preprocessed files
files = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);

nfiles = length(files);
if(nfiles > 0)
    util_bdisp(['[io] - Found ' num2str(nfiles) ' GDF files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
else
    error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
end

%% Get AMICA components
amicafiles = util_getfile3(amicapath, '.mat', 'include', includepat, 'exclude', excludepat);

if(isequal(length(amicafiles), 1) == false)
    error(['[io] - Multiple AMICA files for subject ' subject ' and number of channels ' num2str(length(eegchannels))])
else
    util_bdisp(['[io] - Found the AMICA file with IC components: ' amicafiles{1}]);
end

%% Create directory
util_mkdir(pwd, savedir);

%% AMICA component selection
util_bdisp('[amica] + Running AMICA selection:');
disp(['        |- Loading AMICA components from: ' amicafiles{1}]);
amica = load(amicafiles{1});
amica = amica.amica;

disp('        |- Select components to remove');
amica.icaact = geticaact(amica);
amica        = iclabel(amica);
[~, rmcomps]     = errp_pop_viewprops(amica, 0);
disp(['        |- Components marked to be removed: [' strjoin(compose('%g', rmcomps), ' ') ']']);

%% Remove selected components from each preprocessed file
util_bdisp('[amica] + Removing selected components from each preprocessed file:');
for fId = 1:nfiles

    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);

    %% Loading data
    disp(['        |- Loading file: ' cfullname]);
    
    data = load(cfullname);
    
    disp('        |- Create eeglab structure');
    eeg            = eeg_emptyset;
    eeg.data       = data.eeg';
    eeg.srate      = data.settings.samplerate;
    eeg.nbchan     = size(eeg.data, 1);
    eeg.trials     = 1;
    eeg.pnts       = size(eeg.data, 2);
    eeg.chanlocs   = amica.chanlocs;
    eeg.icaweights = amica.icaweights;
    eeg.icasphere  = amica.icasphere;
    eeg.icawinv    = amica.icawinv;
    
    disp('        |- Check coerence of the structure');
    eeg = eeg_checkset(eeg, 'ica');
    
    disp('        |- Removing selected components');
    eeg = pop_subcomp(eeg, rmcomps);
    eeg.etc.removed_comps = rmcomps;

    %% Storing data and settings
    settings = data.settings;
    settings.amica.icaweights  = amica.icaweights;
    settings.amica.icasphere   = amica.icasphere;
    settings.amica.icawinv     = amica.icawinv;
    settings.amica.removed     = rmcomps;
    settings.channels.chanlocs =  amica.chanlocs;

    eeg = eeg.data';
    eog = data.eog;
        
    %% Save cleaned data
    sfilename = fullfile(savedir, [cfilename '.mat']);
    util_bdisp(['[out] - Saving cleaned data in: ' sfilename]);
    save(sfilename, 'eeg', 'eog', 'settings'); 
end
