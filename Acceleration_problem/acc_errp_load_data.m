function [T, Tu, E, Ek, Ck, eeg, eeg_un, setting, velz, trial_Rk, bagsfiles] = acc_errp_load_data(includepat, excludepat, setting)
% Same as original, with two additional output arguments:
%   trial_Rk  : [ntrials x 1] integer, the run-index (Rk) of the bag file
%               that each trial belongs to (from baglabels.samples.Rk).
%   bagsfiles : cell array of aligned bag .mat file paths, in the same
%               order as the Rk values (Rk==1 -> bagsfiles{1}, etc.).
% These allow the caller to split trials by difficulty category without
% reloading any data.

    error_modality = setting.error_modality;

    spatialfilter = setting.spatialfilter;
    artifactrej   = setting.artifactrej;

    with_delay = setting.with_delay;

    baseline_correction = setting.baseline_correction;

    refvel = setting.refvel;

    mask = setting.mask;
    remove_mask = setting.remove_mask;
    chanlocspath = setting.chanlocspath;

    eegchannels = setdiff(mask, remove_mask, 'stable');
    subject = setting.includepat;

    if strcmp(error_modality, 'visual')
        datapath      = ['analysis_visual/' artifactrej '/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
        bagspath      = 'analysis_visual/bags/aligned/';
    else
        datapath      = ['analysis_vestibular/' artifactrej '/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
        bagspath      = 'analysis_vestibular/bags/aligned/';
    end

    %% Allow to use of multiple subjects
    datafiles = {};
    datafiles_unfiltered = {};
    bagsfiles = {};
    for i = 1:length(includepat)
        % gdf
        tmp_d = util_getfile3(datapath, '.mat', 'include', includepat(i), 'exclude', excludepat);
        % bag
        tmp_b = util_getfile3(bagspath, '.mat', 'include', includepat(i), 'exclude', excludepat);

        matches   = contains(tmp_d, 'unfiltered');
        unmatches = ~contains(tmp_d, 'unfiltered');

        subset   = tmp_d(matches);
        unsubset = tmp_d(unmatches);

        datafiles_unfiltered = [datafiles_unfiltered; subset];
        datafiles            = [datafiles; unsubset];

        bagsfiles = [bagsfiles; tmp_b];
    end

    ndatafiles = length(datafiles);
    util_bdisp(['[io] - Found ' num2str(ndatafiles) ' data files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') ')']);

    chanlocs_a = '';
    if contains(setting.cap, 'norm')
        chanlocstr = load(chanlocspath);
        chanlocs_a = errp_util_get_chanlocs(eegchannels, chanlocstr.ch32Locations);
    elseif contains(setting.cap, 'errp')
        chanlocstr = load(chanlocspath);
        chanlocs_a = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
    end

    %% Remove the channels that I do not want
    remove_mask = setting.remove_mask;
    eegchannels = setdiff(mask, remove_mask, 'stable');

    %% Load the codec
    CommandLx   = setting.ev_cod.CommandLx;
    CommandRx   = setting.ev_cod.CommandRx;
    ErrorLx     = setting.ev_cod.ErrorLx;
    ErrorRx     = setting.ev_cod.ErrorRx;
    MovErrLeft  = setting.ev_cod.MovErrLeft;
    MovErrRight = setting.ev_cod.MovErrRight;
    ErrLxMov    = setting.ev_cod.ErrLxMov;
    ErrRxMov    = setting.ev_cod.ErrRxMov;

    epoch = setting.epoch;

    %% Importing data
    util_bdisp(['[io] - Importing ' num2str(ndatafiles) ' files from ' datapath ':']);
    % Load the data
    [eeg, eog, events, labels, settings] = errp_concatenate_bandpass(datafiles);
    % Load the unfiltered data
    [eeg_unfiltered, ~, ~, ~, ~] = errp_concatenate_bandpass(datafiles_unfiltered);
    % Load the bags data  — baglabels.samples.Rk is the per-sample run index
    [pose, twist, cmdvel, bagevents, baglabels] = errp_concatenate_bags(bagsfiles);

    % Francesca 30.03.26
    setting.saturation_vel = max(abs(twist.z));   % full-recording max

    nchannels  = size(eeg, 2);
    samplerate = settings.samplerate;
    eTYP       = events.TYP;
    ePOS       = events.POS;
    bTYP       = bagevents.TYP;
    bPOS       = bagevents.POS;

    %% Analyze events
    util_bdisp('[proc] + Analysizing events:');

    % Extract events
    disp('     |- Extract events');
    evtidx = errp_util_get_event_type([CommandLx CommandRx ErrorLx ErrorRx MovErrLeft MovErrRight ErrLxMov ErrRxMov], eTYP);

    eTYP = eTYP(evtidx);
    ePOS = ePOS(evtidx);

    bTYP = bTYP(evtidx);
    bPOS = bPOS(evtidx);

    % Removing events within refractory period
    refractory = setting.refractory;
    disp(['       |- Find events within the refractory period (' num2str(refractory/samplerate, '%3.2f') ' s)']);
    rmevt_refractory = errp_util_events_refractory(ePOS, refractory);

    % Find events not consistent with epoch
    disp(['       |- Find events not consistent with epoch [' strjoin(compose('%g', floor(epoch*samplerate)), ' ') ']']);
    firstevt    = find(ePOS > floor(abs(epoch(1)*samplerate)), 1, 'first');
    lastevt     = find(ePOS < size(eeg, 1) - floor(abs(epoch(2)*samplerate)), 1, 'last');
    rmevt_epoch = setdiff(1:length(eTYP), firstevt:lastevt);

    rm_evtidx = unique([rmevt_refractory, rmevt_epoch]);
    disp(['       |- Excluded events index: [' strjoin(compose('%g', rm_evtidx), ' ') ']']);

    %% Extract trials
    util_bdisp('[proc] + Extracting trials:');

    % Remove the trials with a strong peak in EEG
    max_peak  = setting.max_peak;
    epoch_tmp = epoch;
    disp('     |- Find events with a strong peak (>' + string(max_peak) + 'uV) into the timewind');
    rmevt_peaks = errp_with_peaks(ePOS, eeg(:, setting.refchannelidx), epoch_tmp, 512, max_peak);
    ePOS(rmevt_peaks) = [];
    eTYP(rmevt_peaks) = [];
    bPOS(rmevt_peaks) = [];
    bTYP(rmevt_peaks) = [];

    % Remove the trials with a strong peak in EOG
    epoch_tmp = epoch;
    disp('     |- Find events with a strong peak (>' + string(max_peak) + 'uV) into the timewind');
    rmevt_peaks = errp_with_peaks(ePOS, eog(:, :), epoch_tmp, 512, setting.max_peak_eog);
    ePOS(rmevt_peaks) = [];
    eTYP(rmevt_peaks) = [];
    bPOS(rmevt_peaks) = [];
    bTYP(rmevt_peaks) = [];

    % Compute delay based on wheelchair velocity (unchanged from original)
    rmevt_velocity = [];
    if with_delay == true
        disp(['     |- Compute delays based on reference acceleration: ' num2str(refvel)]);
        [~, sec_refchannelidx] = ismember(upper(sec_refchannel), upper(settings.channels.eeg));
        ntrials = length(ePOS);
        delays  = zeros(ntrials, 1);

        for trId = 1:ntrials
            dt     = 0.32;
            cstart = ePOS(trId);
            if contains(subject, 'run')
                cstart = ePOS(trId) + floor(dt*samplerate);
            end
            cstop    = ePOS(trId) + floor(epoch(2)*samplerate);
            acc_data = eeg(cstart:cstop, sec_refchannelidx);

            if contains(subject, 'fb')
                if eTYP(trId) == CommandRx || eTYP(trId) == ErrorLx
                    overidx = find((acc_data) <= -refvel_n, 1, 'first');
                elseif eTYP(trId) == CommandLx || eTYP(trId) == ErrorRx
                    overidx = find((acc_data) >= refvel, 1, 'first');
                end
            elseif contains(subject, 'run')
                if eTYP(trId) == CommandRx || eTYP(trId) == ErrorRx
                    overidx = find((acc_data) <= -refvel, 1, 'first');
                elseif eTYP(trId) == CommandLx || eTYP(trId) == ErrorLx
                    overidx = find((acc_data) <= -refvel_n, 1, 'first');
                end
            end

            if isempty(overidx) == true
                rmevt_velocity = cat(1, rmevt_velocity, trId);
            else
                delays(trId) = overidx(1);
                if contains(subject, 'run')
                    delays(trId) = overidx(1) + floor(dt*samplerate);
                end
            end
        end
    end

    %% Setup error / correct labels
    ntrials = length(ePOS);

    if strcmp(error_modality, 'visual')
        Ck = false(ntrials, 1);
        Ck(eTYP == CommandLx | eTYP == CommandRx) = true;
        Ek = false(ntrials, 1);
        Ek(eTYP == ErrorLx | eTYP == ErrorRx) = true;
    elseif strcmp(error_modality, 'vestibular')
        Ck = false(ntrials, 1);
        Ck(eTYP == CommandLx | eTYP == CommandRx) = true;
        Ek = false(ntrials, 1);
        Ek(eTYP == ErrLxMov | eTYP == ErrRxMov) = true;
    else
        error('Modality not well setted')
    end

    if with_delay == true
        ePOS = ePOS + delays;
        bPOS = bPOS + delays;
    end

    %% Extract epochs
    disp(['     |- Extract epochs [' strjoin(compose('%g', epoch), ' ') '] seconds']);
    nsamples = length(epoch(1):1/samplerate:epoch(2));
    ntrials  = length(ePOS);
    T      = zeros(nsamples, nchannels, ntrials);
    Tu     = zeros(nsamples, nchannels, ntrials);
    E      = nan(nsamples, size(setting.eog_channels, 2), ntrials);
    velz   = nan(nsamples, ntrials);

    % --- NEW: per-trial run index (which bag file the trial came from) ---
    trial_Rk = zeros(ntrials, 1);
    % ---------------------------------------------------------------------

    for trId = 1:ntrials
        cstart = ePOS(trId) + floor(epoch(1)*samplerate);
        cstop  = ePOS(trId) + floor(epoch(2)*samplerate);

        if cstop > size(eeg, 1)
            continue
        end

        % Francesca 05.03.26
        if cstop > size(twist.z, 1)
            continue
        end

        T(:, :, trId)  = eeg(cstart:cstop, :);
        Tu(:, :, trId) = eeg_unfiltered(cstart:cstop, :);
        E(:, :, trId)  = eog(cstart:cstop, :);
        velz(:, trId)  = twist.z(cstart:cstop, :);

        % Look up which bag run this event sample belongs to.
        % ePOS(trId) is the event onset sample in the concatenated timeline;
        % baglabels.samples.Rk maps every sample to its run (bag file) index.
        trial_Rk(trId) = baglabels.samples.Rk(ePOS(trId));
    end

    eeg_un = eeg_unfiltered;

    % Create label vectors
    disp('     |- Create label vectors');

    %% Baseline correction
    if baseline_correction == true
        disp('     |- Performing baseline correction');

        pos_zero        = -epoch(1) * 512;
        length_baseline = 0.1 * 512;
        inf_sup         = round(pos_zero);
        inf_inf         = round(inf_sup - length_baseline);

        baseline_median = nanmean(T(inf_inf:inf_sup, 1:32, :), 1);

        for i = 1:size(T, 3)
            T(:, 1:32, i) = T(:, 1:32, i) - baseline_median(:, :, i);
        end
    end

    setting.settings = settings;

end
