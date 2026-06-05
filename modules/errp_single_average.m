%     _____ _____ _   _  _____ _      ______ 
%    / ____|_   _| \ | |/ ____| |    |  ____|
%   | (___   | | |  \| | |  __| |    | |__   
%    \___ \  | | | . ` | | |_ | |    |  __|  
%    ____) |_| |_| |\  | |__| | |____| |____ 
%   |_____/|_____|_| \_|\_____|______|______|
%

clearvars; clc;

% The main subj, needed to decide the captype
subject = 'run_errp_p_1'; %'errp_an_1';

% To add multiple subj, just add in this cell 
includepat  = {subject};

% Load only the calibration run if you want to compile the classificator
excludepat  = {
  %'evaluation', 
  %'calibration'
  %'fb',
  %'rebase'
  'baseline',
  'fast'
};

spatialfilter = 'none'; %  {'csd', 'car', 'none'}
artifactrej   = 'none'; % {'FORCe', 'none'}

%y_li = [-2.5 3.7];
y_li = [-6.0 6.0];

create_classifier = false;
plot_freqs = false;

% Just in case
baseline_correction = false;

compute_permutation_test = false;

%% May no need anymore this 
with_dtw = false;

with_delay    = false;
refvel = 0.001;

with_delay_fix = false;
diff_pnt = 400;

%% Decide withc cap I need

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
normal32 = {'FP1', 'FPz', 'FP2', 'F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6','M1','T7','C3','Cz','C4', 'T8', 'M2', 'CP5','CP1','CP2','CP6','P7','P3', 'Pz', 'P4', 'P8', 'POz','O1','Oz','O2'};

mask = '';
classificator_channel = {};
remove_mask = {};

%remove_mask = {'M1', 'T7', 'T8', 'M2'};

if contains(subject, 'norm') || contains(subject, 'tmp') 
    mask = normal32;
    classificator_channel = {'F3','Fz','F4','FC5','FC1','C3','Cz','C4', 'CP1','CP2','P3', 'Pz', 'P4'};
    chanlocspath  = 'ch32Locations.mat'; 
elseif contains(subject, 'errp')
    mask = errp_cap;
    classificator_channel = { 'F1', 'Fz', 'F2', 'FC1', 'FCz', 'FC2', 'C1', 'Cz', 'C2',  'CP1',  'CPz',  'CP2'};
    chanlocspath = 'ErrP_cap_chan_file.mat';
end


refchannel = {'cz'};
sec_refchannel = {'fz'};

eegchannels = setdiff(mask, remove_mask);

datapath      = ['analysis/' artifactrej '/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
bagspath      = 'analysis/bags/aligned/';


%datafiles = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat);
%bagsfiles = util_getfile3(bagspath, '.mat', 'include', includepat, 'exclude', excludepat);

% Allow to use of multiple subjects
datafiles = {};
for i = 1:length(includepat)
    tmp_d = util_getfile3(datapath, '.mat', 'include', includepat(i), 'exclude', excludepat);
    datafiles = [datafiles; tmp_d];
end

ndatafiles = length(datafiles);
util_bdisp(['[io] - Found ' num2str(ndatafiles) ' data files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') ')']);

chanlocs_a = '';
if contains(subject, 'norm')
    chanlocstr        = load(chanlocspath);
    chanlocs_a        = errp_util_get_chanlocs(eegchannels, chanlocstr.ch32Locations);
elseif contains(subject, 'errp')
    chanlocstr        = load(chanlocspath);
    chanlocs_a        = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
end


%% Remove the channels that I do not want

remove_mask = {};

eegchannels = setdiff(mask, remove_mask);



%% Parameters
MASK_N = 'CAMERA';

mask_name = {'CAMERA', 'BUTTON', 'COMMAND', 'AUDIO'};
mask_colors = ['--r'; '--g'; '--b'; '--m'];


mask_value = [0, 80, 60, 40];

[~, id_m ] = ismember(upper(MASK_N), upper(mask_name));

MASK = mask_value(id_m);

Stop        = 100 + MASK;
CommandLx   = 101 + MASK;
CommandFx   = 102 + MASK;
CommandRx   = 103 + MASK;
ErrorLx     = 5101 + MASK;
ErrorRx     = 5103 + MASK;
NoReleaseLx = 4101 + MASK;
NoReleaseFx = 4102 + MASK;
NoReleaseRx = 4103 + MASK;

epoch = [-2.0 2.0];

%classifier_epoch = [0.35 0.8];
classifier_epoch = [1.15 1.6];


%% Importing data
util_bdisp(['[io] - Importing ' num2str(ndatafiles) ' files from ' datapath ':']);
[eeg, eog, events, labels, settings] = errp_concatenate_bandpass(datafiles);
%[pose, twist, cmdvel, bagevents, baglabels] = errp_concatenate_bags(bagsfiles);

nchannels  = size(eeg, 2);
samplerate = settings.samplerate;
eTYP       = events.TYP;

eTYP = recomputeTYP(eTYP);

ePOS       = events.POS;

%bTYP       = bagevents.TYP;
%bPOS       = bagevents.POS;

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

%evtidx = errp_util_get_event_type([CommandRx ErrorRx ], eTYP);
%evtidx = errp_util_get_event_type([CommandRx ErrorRx], eTYP);



eTYP = eTYP(evtidx);
ePOS = ePOS(evtidx);

% Remove the trials with a strong peak
max_peak = 200;
disp('     |- Find events with a strong peak (>' + string(max_peak) + 'uV) into the timewind');
rmevt_peaks = errp_with_peaks(ePOS, eeg, epoch, 512, max_peak );
ePOS(rmevt_peaks) = [];
eTYP(rmevt_peaks) = [];

% % Compute delay based on wheelchair velocity
% rmevt_velocity = [];
% disp(['     |- Compute delays based on reference velocity: ' num2str(refvel)]);
% ntrials = length(ePOS);
% delays  = zeros(ntrials, 1);
% for trId = 1:ntrials
%     cstart = ePOS(trId);
%     cstop  = ePOS(trId) + floor(epoch(2)*samplerate);
%     overidx = find(abs(twist.z(cstart:cstop)) >= refvel, 1, 'first');
%     if isempty(overidx) == true
%         rmevt_velocity = cat(1, rmevt_velocity, trId);
%     else
%         delays(trId) = overidx;
%     end
% end


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
% if with_delay == true
%     ePOS = ePOS + delays;
% end

% Extract epochs
disp(['     |- Extract epochs [' strjoin(compose('%g', epoch), ' ') '] seconds']);
nsamples  = length(epoch(1):1/samplerate:epoch(2));
ntrials   = length(ePOS);
T    = nan(nsamples, nchannels, ntrials);
E    = nan(nsamples, 1, ntrials);
%velz = nan(nsamples, ntrials);

for trId = 1:ntrials
    cstart = ePOS(trId) + floor(epoch(1)*samplerate);
    cstop  = ePOS(trId) + floor(epoch(2)*samplerate);
    %Compute FORCe!
    %tmp_eeg = FORCe(eeg(cstart:cstop, :)', 512, chanlocs_a, 0 );

    %T(:, :, trId) = tmp_eeg';% eeg(cstart:cstop, :);
    T(:, :, trId) = eeg(cstart:cstop, :);

    E(:, :, trId) = eog(cstart:cstop, :);
    %velz(:, trId) = twist.z(cstart:cstop, :);
end

% Create label vectors
disp('     |- Create label vectors');

if (baseline_correction == true)
    disp('     |- Performing baseline correction');

    i = round( 512 * 0.5);

    baseline_median = nanmedian(T(1:i,:,:), 1);

    for i = 1:size(T,3)
        T(:, :, i) = T(:, :, i) - baseline_median(:, :, i);
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

nrefchannel = length(refchannel);

chanlocs = settings.channels.chanlocs;

perc_err = 100*sum(Ek)./(sum(Ek) + sum(Ck));


m_eeg_err = squeeze(mean(T(:, :, Ek), 3));
m_eeg_cor = squeeze(mean(T(:, :, Ck), 3));
m_eog_err = squeeze(mean(E(:, :, Ek), 3));
m_eog_cor = squeeze(mean(E(:, :, Ck), 3));

m_t_baseline = squeeze(mean(T_baseline(:, :, :), 3));

std_eeg_err = squeeze(std(T(:, :, Ek),0, 3));
std_eeg_cor = squeeze(std(T(:, :, Ck),0, 3));
std_eog_err = squeeze(std(E(:, :, Ek),0, 3));
std_eog_cor = squeeze(std(E(:, :, Ck),0, 3));


%topowins = [-0.1 -0.0; 0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5 ]; % ; 0.75 1.0; 1.25 1.5];
topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ] - 1.5 ; % ; 0.75 1.0; 1.25 1.5];

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
plot_errp_s(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx));
%plot_errp(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx));

hold off;
grid on;
plot_vline(0, 'k');
plot_hline(0, 'k');
xlim([t(1) t(end)]);
ylim(y_li);
title(['subject: ' subject ' | channel: FZ | error vs. correct']);

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

ax = gca; % Current subplot
pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates

for tmp = 1:length(diff_t)
    vline = diff_t(tmp);

    try
        if (vline > epoch(1))
            x_norm = pos(1) + (vline - epoch(1)) / (epoch(2) - epoch(1)) * pos(3);
            y_norm = pos(2) - 0.04; % Align annotation to the bottom of subplot
        
            plot_vline(vline, mask_colors(tmp,:));
        
            annotation('textarrow', [x_norm x_norm], [y_norm y_norm+0.02], ...
            'String', mask_name(tmp), 'FontSize', 12, 'Color', 'k');
        end
    end
end

title(['Subject: ' subject ' | channel: ' char(refchannel) ' | error vs. correct']);

% Topoplot error
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

% Imagesc error trials
subplot(nrows, ncols, get_slot_layout([2 4]));
imagesc(t, 1:sum(Ek), squeeze(T(:, refchannelidx, Ek))', [-15 15]);
colorbar;
plot_vline(0, 'k');
set(gca, 'YDir', 'normal');
title(['Subject: ' subject ' | channel: ' char(refchannel) ' | error trials']);
xlabel('time [s]')
ylabel('# trial')

% Imagesc correct trials
subplot(nrows, ncols, get_slot_layout([6 8]));
imagesc(t, 1:sum(Ck), squeeze(T(:, refchannelidx, Ck))', [-15 15]);
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

