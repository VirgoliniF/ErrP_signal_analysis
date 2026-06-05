clearvars; clc;

subject = 'sub_errp_al_2';

includepat  = {subject};
excludepat  = {};
depthlevel  = 2;
%chanlocspath  = 'chanlocs64.mat';
chanlocspath = 'ErrP_cap_chan_file.mat';  %chan


%% Processing parameters
errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
channels     = errp_cap;

datapath = ['analysis/amica/preprocessed/' num2str(length(channels)) '/'];
savedir  = ['analysis/amica/components/' num2str(length(channels)) '/'];

Stop         = 100;
CommandLx    = 101;
CommandFx    = 102;
CommandRx    = 103;
ErrorLx      = 5101;
ErrorRx      = 5103;
NoReleaseLx  = 4101;
NoReleaseFx  = 4102;
NoReleaseRx  = 4103;

epoch        = [-0.5 2];

%% Get datafiles
files = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);

nfiles = length(files);
if(nfiles > 0)
    util_bdisp(['[io] - Found ' num2str(nfiles) ' files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
else
    error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
end

%% Create directory
util_mkdir(pwd, savedir);

%% Extract epochs

% eeglab structure
amica = eeg_emptyset;

for fId = 1:nfiles

    cfullname = files{fId};
    [cfilepath, cfilename, cfileext] = fileparts(cfullname);
    
    %% Loading data
    util_bdisp(['[io] + Loading file ' num2str(fId) '/' num2str(nfiles)]);
    disp(['     |- File: ' cfullname]);
    
    data = load(cfullname);
    
    eeg        = data.eeg;
    samplerate = data.settings.samplerate;
    POS     = data.settings.events.POS;
    TYP     = data.settings.events.TYP;

    %% Analyzing events
    BeginEvt = CommandFx;
    EndEvt   = Stop;
    util_bdisp('[proc] + Analyzing events');
    
%     % Extract begin and end events
%     disp(['       |- Find begin (' num2str(BeginEvt) ') and end (' num2str(EndEvt) ') events']);
%     evtidx = errp_util_extract_begin_end(TYP, BeginEvt, EndEvt);
%     disp(['       |- Exclude events not within begin and end. Excluded events index: [' strjoin(compose('%g', setdiff(1:length(TYP), evtidx)), ' ') ']']);
%     POS = POS(evtidx);
%     TYP = TYP(evtidx);

    % Removing events within refractory period to avoid overlap while computing AMICA
    refractory = length(epoch(1):1/samplerate:epoch(2));
    disp(['       |- Find events within the refractory period (' num2str(refractory/samplerate, '%3.2f') ' s)']);
    rmevt_refractory = errp_util_events_refractory(POS, refractory);
    
    % Find the first event and last event consistent with the epoch
    disp(['       |- Find events not consistent with epoch [' strjoin(compose('%g', floor(epoch*samplerate)), ' ') ']']);
    firstevt    = find(POS > floor(abs(epoch(1)*samplerate)), 1, 'first');
    lastevt     = find(POS < size(eeg, 1) - floor(abs(epoch(2)*samplerate)), 1, 'last');
    rmevt_epoch = setdiff(1:length(TYP), firstevt:lastevt);
    
    rm_evtidx = union(rmevt_refractory, rmevt_epoch);
    disp(['       |- Excluded events index: [' strjoin(compose('%g', rm_evtidx), ' ') ']']);
    POS(rm_evtidx) = [];
    TYP(rm_evtidx) = [];
    
    
    %% Extract epochs
    util_bdisp('[proc] + Extracting epochs');
    disp(['       |- Epoch period: [' strjoin(compose('%g', epoch), ' ') '] s']);
    
    % Get command events
    cmdidx = errp_util_get_event_type([CommandLx CommandRx ErrorLx ErrorRx NoReleaseFx NoReleaseRx NoReleaseLx], TYP);
    cmdPOS = POS(cmdidx);
    cmdTYP = TYP(cmdidx);

    % Get stop events
    stpidx = errp_util_get_event_type(Stop, TYP);
    stpPOS = POS(stpidx);
    
    % Exclude epoch when a stop command occurs in epoch(2) seconds after the command
    excludedidx = find(sum(cmdPOS - stpPOS' > -epoch(2)*samplerate & cmdPOS - stpPOS' < 0, 2));
    cmdPOS(excludedidx) = [];
    cmdTYP(excludedidx) = [];
    disp(['       |- Excluding epochs with stop command within ' num2str(epoch(2)) ' s: ' strjoin(compose('%g', excludedidx), ', ')]);
    
    % Extract epochs (already in eeglab format)
    nepochs   = length(cmdPOS);
    nsamples  = length(epoch(1):1/samplerate:epoch(2));
    nchannels = size(eeg, 2);
    epochs = nan(nchannels, nsamples, nepochs);
    for eId = 1:nepochs
        cstart = cmdPOS(eId) + floor(epoch(1)*samplerate);
        cstop  = cmdPOS(eId) + floor(epoch(2)*samplerate);
        epochs(:, :, eId) = eeg(cstart:cstop, :)';
    end

    % Concatenating epochs between files
    util_bdisp('[proc] + Concatenating epochs in eeg structure');
    amica.data = cat(3, amica.data, epochs);
end

%% Checking eeg structure
% Update eeg structure fields
util_bdisp('[proc] + Updating eeg structure fields');
disp(['       |- ''eeg.srate'': ' num2str(samplerate)]);
amica.srate    = samplerate;
disp(['       |- ''eeg.nbchan'': ' num2str(size(amica.data, 1))]);
amica.nbchan   = size(amica.data, 1);
disp(['       |- ''eeg.trials'': ' num2str(size(amica.data, 3))]);
amica.trials   = size(amica.data, 3);
disp(['       |- ''eeg.pnts'': ' num2str(size(amica.data, 2))]);
amica.pnts     = size(amica.data, 2);
disp(['       |- ''eeg.xmin'': ' num2str(epoch(1))]);
amica.xmin     = epoch(1);
disp(['       |- ''eeg.xmax'': ' num2str(epoch(2))]);
amica.xmax     = epoch(2);
disp(['       |- ''eeg.chanlocs'' extracted from: ''' which(chanlocspath)'']);
chanlocstr   = load('chanlocs64.mat');
amica.chanlocs = errp_util_get_chanlocs(channels, chanlocstr.chanlocs);

% Checking consistency eeg structure
util_bdisp('[proc] + Checking consistency eeg structure');
amica = eeg_checkset(amica);

%% Compute AMICA
util_bdisp('[amica] + Computing AMICA');

% Reshape data to concatenate trials
data = reshape(amica.data, [], size(amica.data, 2)*size(amica.data, 3));
disp(['        |- Reshaping the data from ' strjoin(compose('%g', size(amica.data)), 'x') ' to ' strjoin(compose('%g', size(data)), 'x')]);
amicadrk = getrank(data);
disp(['        |- Getting the rank: ' num2str(amicadrk)]);

% AMICA arguments
disp('        |+ AMICA parameters:');
amica_arglist;
arglist(4)  = {size(data, 1)};       % nchannels
arglist(6)  = {amicadrk};            % PCA keep 
arglist(8)  = {8};                   % Max number of threads
arglist(12) = {1};                   % Number of processes
for i = 1:2:length(arglist)
    disp(['         |- ''' arglist{i} ''': ' num2str(arglist{i+1})])
end

[W,S,mods] = runamica15(data, arglist{:});
amica.icaweights = W;
amica.icasphere  = S(1:size(W,1),:);
amica.icawinv    = mods.A(:,:,1);

% Check coherence of data structure
amica = eeg_checkset(amica, 'ica');

%% Save AMICA components
info = errp_util_get_info(files{1});
sfilename = fullfile(savedir, [info.subject '.' info.date '.' info.task '.' info.extra1 '.' info.extra2 '.amica.mat']);
util_bdisp(['[out] - Saving AMICA components in: ' sfilename]);
save(sfilename, 'amica'); 






