%        __      ________ _____            _____ ______ 
%       /\ \    / /  ____|  __ \     /\   / ____|  ____|
%      /  \ \  / /| |__  | |__) |   /  \ | |  __| |__   
%     / /\ \ \/ / |  __| |  _  /   / /\ \| | |_ |  __|  
%    / ____ \  /  | |____| | \ \  / ____ \ |__| | |____ 
%   /_/    \_\/   |______|_|  \_\/_/    \_\_____|______|
% 

clearvars; clc;

% The main subj, needed to decide the captype
subject = 'learn_errp_p_4'; %'errp_an_1'; fb_acc_errp_p_1

% active_errp_p_2
% learn_errp_p_2

% To add multiple subj, just add in this cell 
includepat  = {subject};%, 'norm_ar_1', 'norm_a_1' 'norm_t_1', 'norm_p_1', 'norm_p_2'}; % {'s1', 's2', ecc

%fb_norm_fast_p_1

% Load only the calibration run if you want to compile the classificator
excludepat  = {
  % 'unfiltered',
  %'evaluation', 
  %'calibration'
  %'fb',
  %'rebase'
  'baseline',
  'fast',
};
%   'errp_an_1.20250204.182153.calibration.wheelchiar_errp' };

spatialfilter = 'none'; %  {'csd', 'car', 'none'}
artifactrej   = 'none'; % {'FORCe', 'none'}

%y_li = [-2.5 3.7];

y_li_acc = [-60.0 60.0] * 1e2;
y_li = [-8.0 8.0];

create_classifier = false;
plot_freqs = false;

% Just in case
baseline_correction = false;

compute_permutation_test = false;

compute_time_freuency_decomposition = true;

%% May no need anymore this 
with_dtw = false;


with_delay    = false;
refvel = 200;
if contains(subject, 'fb')
    refvel = 800;
    refvel_n = 1400;
else
    refvel   = 1100;
    refvel_n = 1100;
end

with_delay_fix = false;
diff_pnt = 400;

%% Decide withc cap I need

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
normal32 = {'FP1', 'FPz', 'FP2', 'F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6','M1','T7','C3','Cz','C4', 'T8', 'M2', 'CP5','CP1','CP2','CP6','P7','P3', 'Pz', 'P4', 'P8', 'POz','O1','Oz','O2'};

sensors = {'sens1','sens2','sens3','sens4','sens5','sens6','sens7','sens8','sens9','sens10','sens11','sens12','sens13','sens14','sens15','sens16','sens17','sens18','sens19','sens20','sens21','sens22','sens23','sens24' };

mask = '';
classificator_channel = {};
remove_mask = {};

%remove_mask = {'M1', 'T7', 'T8', 'M2'};

if contains(subject, 'norm') 
    mask = normal32;
    classificator_channel = {'F3','Fz','F4','FC5','FC1','C3','Cz','C4', 'CP1','CP2','P3', 'Pz', 'P4'};
    chanlocspath  = 'ch32Locations.mat'; 
elseif contains(subject, 'errp') || contains(subject, 'test') 
    mask = errp_cap;
    classificator_channel = { 'F1', 'Fz', 'F2', 'FC1', 'FCz', 'FC2', 'C1', 'Cz', 'C2',  'CP1',  'CPz',  'CP2'};
    %classificator_channel = errp_cap;
    chanlocspath = 'ErrP_cap_chan_file.mat';
end

if contains(subject, 'acc') 
    mask = [mask , sensors];
end

refchannel = {'cz'};
sec_refchannel = {'fcz'};

if contains(subject, 'acc')
    if contains(subject, 'fb')
        sec_refchannel = {'sens4'};
    else
        sec_refchannel = {'sens5'};
    end
end

eegchannels = setdiff(mask, remove_mask, 'stable');

datapath      = ['analysis/' artifactrej '/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
bagspath      = 'analysis/bags/aligned/';


%datafiles = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat);
%bagsfiles = util_getfile3(bagspath, '.mat', 'include', includepat, 'exclude', excludepat);

% Allow to use of multiple subjects
datafiles = {};
datafiles_unfiltered = {};
for i = 1:length(includepat)
    tmp_d = util_getfile3(datapath, '.mat', 'include', includepat(i), 'exclude', excludepat);
    matches = contains(tmp_d, 'unfiltered');
    unmatches = ~contains(tmp_d, 'unfiltered');

    subset = tmp_d(matches);
    unsubset = tmp_d(unmatches);

    datafiles_unfiltered = [datafiles_unfiltered; subset];
    datafiles = [datafiles; unsubset];
end

ndatafiles = length(datafiles);
util_bdisp(['[io] - Found ' num2str(ndatafiles) ' data files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') ')']);

chanlocs_a = '';
if contains(subject, 'norm')
    chanlocstr        = load(chanlocspath);
    chanlocs_a        = errp_util_get_chanlocs(eegchannels, chanlocstr.ch32Locations);
elseif contains(subject, 'errp') || contains(subject, 'test') 
    chanlocstr        = load(chanlocspath);
    chanlocs_a        = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
end


%% Remove the channels that I do not want

remove_mask = {};

eegchannels = setdiff(mask, remove_mask, 'stable');



%% Parameters
MASK_N = 'CAMERA';
mode = 'default';

if contains(subject, 'fb')
    MASK_N = 'AUDIO';
elseif contains(subject, 'learn')
    MASK_N = 'FEEDBACK';
elseif contains(subject, 'active')
    MASK_N = 'CAMERA';
    mode = 'active';
else
    MASK_N = 'COMMAND';
end

MASK_N = 'FEEDBACK';


mask_name = {'CAMERA', 'BUTTON', 'COMMAND', 'AUDIO', 'FEEDBACK'};
mask_colors = ['--r'; '--g'; '--b'; '--m'];


mask_value = [0, 80, 60, 40, 30];

[~, id_m ] = ismember(upper(MASK_N), upper(mask_name));



MASK = mask_value(id_m);

if contains(subject, 'wheel_test_sbj1')
    MASK = 40;
end

Stop        = 100 + MASK;
CommandLx   = 101 + MASK;
CommandFx   = 102 + MASK;
CommandRx   = 103 + MASK;
ErrorLx     = 5101 + MASK;
ErrorRx     = 5103 + MASK;
NoReleaseLx = 4101 + MASK;
NoReleaseFx = 4102 + MASK;
NoReleaseRx = 4103 + MASK;

% if contains(subject, 'j') &&  contains(subject, 'run')
%     CommandLx   = 5101 + MASK;
%     CommandRx   = 5103 + MASK;
%     ErrorLx     = 101 + MASK;
%     ErrorRx     = 103 + MASK;
% end

epoch = [-0.5 3.5];

%classifier_epoch = [0.35 0.8];
classifier_epoch = [0.1 0.8];


%% Importing data
util_bdisp(['[io] - Importing ' num2str(ndatafiles) ' files from ' datapath ':']);
[eeg, eog, events, labels, settings] = errp_concatenate_bandpass(datafiles);

[eeg_unfiltered, ~, ~, ~, ~] = errp_concatenate_bandpass(datafiles_unfiltered);

%[pose, twist, cmdvel, bagevents, baglabels] = errp_concatenate_bags(bagsfiles);

nchannels  = size(eeg, 2);
samplerate = settings.samplerate;
eTYP       = events.TYP;

% Change a little the TYPE of the events, in a way that are compatible with
% the premade pipeline
eTYP = recomputeTYP(eTYP, mode);

ePOS       = events.POS;

%bTYP       = bagevents.TYP;
%bPOS       = bagevents.POS;


%% Compute the integral of the thow singlas
%% 36 37
%t = linspace(1, size(eeg,1), size(eeg,1)) / 512;
%eeg(:,36) = cumtrapz(t, eeg(:,36));
%eeg(:,37) = cumtrapz(t, eeg(:,37));


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

%rm_evtidx = union(rmevt_refractory, rmevt_epoch);
%rm_evtidx = union(rm_evtidx, rmevt_peaks);

rm_evtidx = unique([rmevt_refractory, rmevt_epoch]);

disp(['       |- Excluded events index: [' strjoin(compose('%g', rm_evtidx), ' ') ']']);
ePOS(rm_evtidx) = [];
eTYP(rm_evtidx) = [];

%% Compute the distance between the events
[diff_t, std_t] = errp_compute_distance_events(eTYP, ePOS, [CommandLx CommandRx ErrorLx ErrorRx], MASK, mask_value);


%% Extract trials
util_bdisp('[proc] + Extracting trials:');

% Extract events
disp('     |- Extract events');
evtidx = errp_util_get_event_type([CommandLx CommandRx ErrorLx ErrorRx NoReleaseFx NoReleaseRx NoReleaseLx], eTYP);

%evtidx = errp_util_get_event_type([CommandRx ErrorLx ], eTYP);
%evtidx = errp_util_get_event_type([CommandLx ErrorRx], eTYP);

%evtidx = errp_util_get_event_type([CommandLx ErrorLx], eTYP);
%evtidx = errp_util_get_event_type([CommandRx ErrorRx], eTYP);



eTYP = eTYP(evtidx);
ePOS = ePOS(evtidx);

% Remove the trials with a strong peak
max_peak = 200;
epoch_tmp = epoch;
epoch_tmp(2) = epoch(2);
disp('     |- Find events with a strong peak (>' + string(max_peak) + 'uV) into the timewind');
rmevt_peaks = errp_with_peaks(ePOS, eeg(:,1:32), epoch_tmp, 512, max_peak );
ePOS(rmevt_peaks) = [];
eTYP(rmevt_peaks) = [];


% % Compute delay based on wheelchair velocity
rmevt_velocity = [];
disp(['     |- Compute delays based on reference acceleration: ' num2str(refvel)]);
[~, sec_refchannelidx] = ismember(upper(sec_refchannel), upper(settings.channels.eeg));
ntrials = length(ePOS);
delays  = zeros(ntrials, 1);
%figure
%hold on
if with_delay == true

for trId = 1:ntrials
    dt = 0.32;
    cstart = ePOS(trId);
    if contains(subject, 'run')
        cstart = ePOS(trId)  + floor(dt*samplerate);
    end
    cstop  = ePOS(trId) + floor(epoch(2)*samplerate);
    acc_data = eeg(cstart:cstop, sec_refchannelidx);
 
    %overidx = find((acc_data) >= refvel, 1, 'first');

    %% FOR CLASS ALLINEAMENT:
    if contains(subject, 'fb')
        if eTYP(trId) == CommandRx ||  eTYP(trId) ==  ErrorLx
            overidx = find((acc_data) <= -refvel_n, 1, 'first');
        elseif eTYP(trId) == CommandLx ||  eTYP(trId) ==  ErrorRx
            overidx = find((acc_data) >= refvel, 1, 'first');
        end
    elseif contains(subject, 'run')
        if eTYP(trId) == CommandRx ||  eTYP(trId) ==  ErrorRx        
           overidx = find((acc_data) <= -refvel, 1, 'first');
        elseif eTYP(trId) == CommandLx ||  eTYP(trId) ==  ErrorLx
           %overidx = find((acc_data) >= refvel, 1, 'first');  
           overidx = find((acc_data) <= -refvel_n, 1, 'first');

           %acc_data = acc_data(acc_data < -1200);
           %acc_data = abs(acc_data);
            
           %[pks, locs] = findpeaks(acc_data, 'MinPeakHeight', refvel_n, 'MinPeakProminence', 0.2);

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


%% setup
ntrials   = length(ePOS);

% Command correct
Ck = false(ntrials, 1);
correctindex = eTYP == CommandLx | eTYP == CommandRx;
Ck(correctindex) = true;

% Command error
Ek = false(ntrials, 1);
errorindex = eTYP == ErrorLx | eTYP == ErrorRx;
Ek(errorindex) = true;

%%


% if with_delay_fix == true
%     ePOS = ePOS - diff_pnt;
% end
% 
% if with_dtw == true
%     [~, refchannelidx] = ismember(upper(refchannel), upper(settings.channels.eeg));
%     ePOS = ePOS - errp_util_dtw(eeg, refchannelidx, eTYP, ePOS, epoch, samplerate , [ErrorLx, ErrorRx], [CommandLx, CommandRx], Ck, Ek );
% end
% 
if with_delay == true
    ePOS = ePOS + delays;
end

% Extract epochs
disp(['     |- Extract epochs [' strjoin(compose('%g', epoch), ' ') '] seconds']);
nsamples  = length(epoch(1):1/samplerate:epoch(2));
ntrials   = length(ePOS);
T    = zeros(nsamples, nchannels, ntrials);
Tu   = zeros(nsamples, nchannels, ntrials);
E    = nan(nsamples, 1, ntrials);
%velz = nan(nsamples, ntrials);

for trId = 1:ntrials
    cstart = ePOS(trId) + floor(epoch(1)*samplerate);
    cstop  = ePOS(trId) + floor(epoch(2)*samplerate);

    if cstop>size(eeg,1)
        continue
    end

    %Compute FORCe!
    %tmp_eeg = FORCe(eeg(cstart:cstop, :)', 512, chanlocs_a, 0 );

    %T(:, :, trId) = tmp_eeg';% eeg(cstart:cstop, :);
    T(:, :, trId)  = eeg(cstart:cstop, :);
    Tu(:, :, trId) = eeg_unfiltered(cstart:cstop, :);


    E(:, :, trId) = eog(cstart:cstop, :);
    %velz(:, trId) = twist.z(cstart:cstop, :);
end

% Create label vectors
disp('     |- Create label vectors');

%% Compute the abs of the velocity
% if size(T,2) == 56
%     T(:,33:56,:) = abs(T(:,33:56,:));
% end


%% BASELINE CORRECTION
if (baseline_correction == true)
    disp('     |- Performing baseline correction');

    pos_zero = -epoch(1) * 512 - 0.3*512;
    length_baseline = 0.1 * 512;

    inf_sup = round(pos_zero);
    inf_inf = round(inf_sup - length_baseline);

    baseline_median = nanmean(T(inf_inf:inf_sup,1:32,:), 1);

    for i = 1:size(T,3)
        T(:, 1:32, i) = T(:, 1:32, i) - baseline_median(:, :, i);
    end

end

%% Load baseline

[T_baseline, ~ ] =  errp_load_baseline(includepat, datapath, MASK, epoch);

if isempty(T_baseline)
    T_baseline = zeros(size(T,1),size(T,2),size(T,3));
end

%% Plotting
t = epoch(1):1/samplerate:epoch(2);

[~, refchannelidx] = ismember(upper(refchannel), upper(settings.channels.eeg));
[~, sec_refchannelidx] = ismember(upper(sec_refchannel), upper(settings.channels.eeg));

% Computing permutation test
if compute_permutation_test == true
    errp_compute_permutation_test(T(:,:,Ek), T(:,:,Ck), [refchannelidx, sec_refchannelidx], T_baseline, length(includepat)>1) %  TODO: aggiungere il coso della baseline
end

if compute_time_freuency_decomposition == true
    params.epochTime = t;
    params.fsamp = 512;
    eegEpochs_pre.data = Tu;
    eegEpochs_pre.label = zeros(size(T,3),1);
    eegEpochs_pre.label = eegEpochs_pre.label + Ek;
    eegEpochs_pre.label = eegEpochs_pre.label + Ck * 3;
    compute_theta_peak_v3_1Dcursor(eegEpochs_pre, params, false, true, true, refchannelidx);
end

nrefchannel = length(refchannel);

chanlocs = settings.channels.chanlocs;

perc_err = 100*sum(Ek)./(sum(Ek) + sum(Ck));

m_eeg_err = squeeze(mean(T(:, :, Ek), 3));
m_eeg_cor = squeeze(mean(T(:, :, Ck), 3));
m_eog_err = squeeze(mean(E(:, :, Ek), 3));
m_eog_cor = squeeze(mean(E(:, :, Ck), 3));

a = (m_eeg_err(:,refchannelidx));
save('a.mat','a');

m_t_baseline = squeeze(mean(T_baseline(:, :, :), 3));

std_eeg_err = squeeze(std(T(:, :, Ek),0, 3));
std_eeg_cor = squeeze(std(T(:, :, Ck),0, 3));
std_eog_err = squeeze(std(E(:, :, Ek),0, 3));
std_eog_cor = squeeze(std(E(:, :, Ck),0, 3));


%topowins = [-0.1 -0.0; 0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5 ]; % ; 0.75 1.0; 1.25 1.5];
topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ] - 0.1; % ; 0.75 1.0; 1.25 1.5];

%topowins = [1.1 1.2; 1.2 1.3; 1.3 1.4; 1.4 1.5; 1.5 1.6; 1.6 1.7 ]; % ; 0.75 1.0; 1.25 1.5];


% Figure
fig = figure;
nrows = 4;
ncols = 12;

eogtimeslot     = 4;
eegtimeslot     = 7;
eegerrimgslot   = [2 5];
eegcorrimgslot  = [8 11];
velxerrimgslot  = [3 6];
velxcorrimgslot = [9 12];

get_slot_layout = @(slot) sort(reshape(((slot-1).*6 + [1 2 3 4 5 6]'), 1, length(slot).*6));

% EOG signal
subplot(nrows, ncols, get_slot_layout(1));
hold on;
% plot(t, m_eog_cor(:, 1), 'b');
% plot(t, m_eog_err(:, 1), 'r');
%Plot baseline
plot(t, m_t_baseline(:,sec_refchannelidx), '--k')
%plot_errp_s(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx));
%plot_errp(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx));

if contains(subject, 'acc') 
    data = T(:,sec_refchannelidx,:);
    %data = abs(data);
    m_acc_err = squeeze(mean(data(:, :, Ek), 3));
    m_acc_cor = squeeze(mean(data(:, :, Ck), 3));
    plot_errp(t, m_acc_err(:, 1), m_acc_cor(:, 1));
else
    plot_errp_s(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx));
end



hold off;
grid on;
plot_vline(0, 'k');
plot_hline(0, 'k');
xlim([t(1) t(end)]);

if contains(subject, 'acc') 
    ylim(y_li_acc);
else
    ylim(y_li);
end

title(['subject: ' subject ' | channel: acc | error vs. correct']);

% EEG signal]; 
subplot(nrows, ncols, get_slot_layout(3));
hold on
% Baseline
plot(t, m_t_baseline(:,refchannelidx), '--k')
plot_errp_s(t, m_eeg_cor(:, refchannelidx), m_eeg_err(:, refchannelidx), std_eeg_cor(:, refchannelidx), std_eeg_err(:, refchannelidx));
%plot_errp(t, m_eeg_cor(:, refchannelidx), m_eeg_err(:, refchannelidx));


plot_vline(0, 'k');
plot_hline(0, 'k');
ylim(y_li);

if create_classifier == true
    plot_vline(classifier_epoch(1), '--k');
    plot_vline(classifier_epoch(2), '--k');
end

% if contains(subject, 'fb') 
%     plot_vline(0.68, '--k');
% end

ax = gca; % Current subplot
pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates


%% VERTICAL COMMENT
% for tmp = 1:length(diff_t)
%     vline = diff_t(tmp);
% 
%     try
%         if (vline > epoch(1))
%             x_norm = pos(1) + (vline - epoch(1)) / (epoch(2) - epoch(1)) * pos(3);
%             y_norm = pos(2) - 0.04; % Align annotation to the bottom of subplot
% 
%             plot_vline(vline, mask_colors(tmp,:));
% 
% 
% 
%             %annotation('textarrow', [x_norm x_norm], [y_norm y_norm+0.02], ...
%             %'String', mask_name(tmp), 'FontSize', 12, 'Color', 'k');
%         end
%     end
% end

title(['Subject: ' subject ' | channel: ' char(refchannel) ' | error vs. correct']);

% Topoplot error
if ~contains(subject, 'test') 
    htop = [];
    for tId = 1:size(topowins, 1)
        subplot(nrows, ncols, 24 + tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        h = topoplot(mean(m_eeg_err(cstart:cstop, :), 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))]);
        htop = cat(1, htop, h);
    end
    
    % Topoplot correct
    for tId = 1:size(topowins, 1)
        subplot(nrows, ncols, 36 + tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        h = topoplot(mean(m_eeg_cor(cstart:cstop, :), 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))])
        htop = cat(1, htop, h);
    end

    errp_set_clim(htop);
end

range_v = [-15 15];

if ~contains(refchannel, 'sens')
    range_v = [-15 15];
else
    range_v = [-150 150] * 10;
end


% Imagesc error trials
subplot(nrows, ncols, get_slot_layout([2 4]));
imagesc(t, 1:sum(Ek), squeeze(T(:, refchannelidx, Ek))', range_v);
colorbar;
plot_vline(0, 'k');
set(gca, 'YDir', 'normal');
title(['Subject: ' subject ' | channel: ' char(refchannel) ' | error trials']);
xlabel('time [s]')
ylabel('# trial')

% Imagesc correct trials
subplot(nrows, ncols, get_slot_layout([6 8]));
imagesc(t, 1:sum(Ck), squeeze(T(:, refchannelidx, Ck))', range_v);
colorbar;
plot_vline(0, 'k');
set(gca, 'YDir', 'normal');
title(['Subject: ' subject ' | channel: ' char(refchannel) ' | correct trials']);
xlabel('time [s]')
ylabel('# trial')

%overvelz = find_over(abs(velz), 0.2);
% 
% % imagesc on velz
% subplot(nrows, ncols, get_slot_layout([3 6]));
% hold on;
% %imagesc(t, 1:sum(Ek), squeeze(abs(velz(:, Ek)))');
% axis image
% axis normal
% h = gca;
% %plot(t(overvelz(Ek)), 1:sum(Ek), '.w');
% hold off;
% xlim(h.XLim);
% ylim(h.YLim);
% plot_vline(0, 'w');
% title(['Subject: ' subject ' | abs angular velocity | error trials']);
% xlabel('time [s]')
% ylabel('# trial')

% subplot(nrows, ncols, get_slot_layout([9 12]));
% hold on;
% %imagesc(t, 1:sum(Ck), squeeze(abs(velz(:, Ck)))');
% axis image
% axis normal
% h = gca;
% %plot(t(overvelz(Ck)), 1:sum(Ck), '.w');
% hold off;
% xlim(h.XLim);
% ylim(h.YLim);
% plot_vline(0, 'w');
% title(['Subject: ' subject ' | abs angular velocity | correct trials']);
% xlabel('time [s]')
% ylabel('# trial')

figtitle = [subject ' grand average ' MASK_N ]; 
if with_delay == true
    figtitle = [figtitle ' with delay | threshold = ' num2str(refvel) ' m/s'];
end

if with_dtw == true
    figtitle = [figtitle ' with dtw'];
end

sgtitle(figtitle);

function x= find_over(v, value)

    x = ones(size(v, 2), 1);

    for trId = 1:size(v, 2)
        tmp = find(v(:, trId) >= value, 1, 'first');
        if(isempty(tmp) == false)
            x(trId) = tmp;
        end
    end

end

if plot_freqs == true
    plot_errp_freq(t, T(:, :, Ck), T(:, :, Ek), refchannelidx);
end

if create_classifier == true
    util_bdisp('[proc] + Computing classifier:');

    label = [subject '.' spatialfilter '.' refchannel];

    %% NB: I assume that epoch(1) has t < 0 !!!
    pos_0 = - (samplerate * epoch(1));
    margins = floor(classifier_epoch * samplerate + pos_0);

    disp('     |- Length time buffer for classifier ' + string(margins(2)-margins(1)));

    %margins = classifier_epoch - epoch;
    %margins(2) = - margins(2);
    %margins = floor(margins*samplerate);

    conf.t = t;
    conf.epoch = epoch;
    conf.sub = subject;
    conf.channels = eegchannels;
    [~,refchannelidx] = ismember(classificator_channel, mask);
    decoder = errp_create_classifier(T(:, :, Ek), T(:, :, Ck), refchannelidx, margins, label, conf, false);
end

