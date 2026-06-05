function [T, E] = errp_load_baseline(includepat, datapath, MASK, epoch)

for i = 1:length(includepat)
  includepat{i} = [ includepat{i} '_baseline'];
end

excludepat  = {
   'rebase'
};

% Allow to use of multiple subjects
datafiles = {};
for i = 1:length(includepat)
    try
        tmp_d = util_getfile3(datapath, '.mat', 'include', includepat(i), 'exclude', excludepat);
        datafiles = [datafiles; tmp_d];
    end
end

T = [];
E = [];

if length(datafiles) > 0
    
    ndatafiles = length(datafiles);
    util_bdisp(['[io] - Found ' num2str(ndatafiles) ' data files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') ')']);
    
    Stop        = 100 + MASK;
    CommandLx   = 101 + MASK;
    CommandFx   = 102 + MASK;
    CommandRx   = 103 + MASK;
    ErrorLx     = 5101 + MASK;
    ErrorRx     = 5103 + MASK;
    NoReleaseLx = 4101 + MASK;
    NoReleaseFx = 4102 + MASK;
    NoReleaseRx = 4103 + MASK;
    
    %% Importing data
    util_bdisp(['[io] - Importing ' num2str(ndatafiles) ' files from ' datapath ':']);
    [eeg, eog, events, labels, settings] = errp_concatenate_bandpass(datafiles);
    
    nchannels  = size(eeg, 2);
    samplerate = settings.samplerate;
    eTYP       = events.TYP;
    ePOS       = events.POS;
    
    %% Analyze events
    util_bdisp('[proc] + Analysizing events:');
    % Removing events within refractory period to avoid overlap while computing AMICA
    refractory = 0.0; %length(epoch(1):1/samplerate:epoch(2));
    disp(['       |- Find events within the refractory period (' num2str(refractory/samplerate, '%3.2f') ' s)']);
    rmevt_refractory = errp_util_events_refractory(ePOS, refractory);
    
    % Find the first event and last event consistent with the epoch
    disp(['       |- Find events not consistent with epoch [' strjoin(compose('%g', floor(epoch*samplerate)), ' ') ']']);
    firstevt    = find(ePOS > floor(abs(epoch(1)*samplerate)), 1, 'first');
    lastevt     = find(ePOS < size(eeg, 1) - floor(abs(epoch(2)*samplerate)), 1, 'last');
    rmevt_epoch = setdiff(1:length(eTYP), firstevt:lastevt);
    
    rm_evtidx = unique([rmevt_refractory, rmevt_epoch]);
    
    disp(['       |- Excluded events index: [' strjoin(compose('%g', rm_evtidx), ' ') ']']);
    ePOS(rm_evtidx) = [];
    eTYP(rm_evtidx) = [];
    
    %% Extract trials
    util_bdisp('[proc] + Extracting trials:');
    
    % Extract events
    disp('     |- Extract events');
    evtidx = errp_util_get_event_type([CommandLx CommandRx ErrorLx ErrorRx NoReleaseFx NoReleaseRx NoReleaseLx], eTYP);
    eTYP = eTYP(evtidx);
    ePOS = ePOS(evtidx);
    
    % Remove the trials with a strong peak
    max_peak = 100;
    disp('     |- Find events with a strong peak (>' + string(max_peak) + 'uV) into the timewind');
    rmevt_peaks = errp_with_peaks(ePOS, eeg, epoch, 512, max_peak );
    ePOS(rmevt_peaks) = [];
    eTYP(rmevt_peaks) = [];
    
    %% setup
    ntrials   = length(ePOS);
    
    % Extract epochs
    disp(['     |- Extract epochs [' strjoin(compose('%g', epoch), ' ') '] seconds']);
    nsamples  = length(epoch(1):1/samplerate:epoch(2));
    ntrials   = length(ePOS);
    T    = nan(nsamples, nchannels, ntrials);
    E    = nan(nsamples, 1, ntrials);
    
    for trId = 1:ntrials
        cstart = ePOS(trId) + floor(epoch(1)*samplerate);
        cstop  = ePOS(trId) + floor(epoch(2)*samplerate);
    
        T(:, :, trId) = eeg(cstart:cstop, :);
        E(:, :, trId) = eog(cstart:cstop, :);
    end
end

