clearvars; clc;

% The main subj, needed to decide the captype
subject = 'fb_acc_errp_p';

% fb_acc_errp_p
% active_errp_p_2


includepat  = {subject};

% Esclude the calibration runs
excludepat  = {
  %'calibration', 
  %'evaluation'
  %'navigation'
};

spatialfilter = 'none'; %  {'csd', 'car', 'none'}
artifactrej   = 'none'; % {'FORCe', 'none'}

compute_time_freuency_decomposition = true;

% The path od the classifier used on the 
%decoder_path = '/var/home/piero/Projects/ros/errp_usa_ws/cfg/base11-Feb-2025norm_p_2.mat';
%'/var/home/piero/Projects/ros/errp_usa_ws/cfg/base07-Feb-2025norm_a_1.mat';
%if contains(subject, 'run_acc_errp_j_')
%    decoder_path = '/var/home/piero/Projects/ros/errp_usa_ws/cfg/base31-Mar-2025fb_acc_errp_j_.mat';
%elseif contains(subject, 'run_acc_errp_al_')
%    decoder_path = '/var/home/piero/Projects/ros/errp_usa_ws/cfg/base03-Apr-2025fb_acc_errp_al_.mat';
%end
decoder_path = '/var/home/piero/Projects/ros/errp_usa_ws/cfg/base06-May-2025learn_errp_p.mat';

% Just in case
baseline_correction = false;

%% Decide withc cap I need

errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
normal32 = {'FP1', 'FPz', 'FP2', 'F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6','M1','T7','C3','Cz','C4', 'T8', 'M2', 'CP5','CP1','CP2','CP6','P7','P3', 'Pz', 'P4', 'P8', 'POz','O1','Oz','O2'};
sensors = {'sens1','sens2','sens3','sens4','sens5','sens6','sens7','sens8','sens9','sens10','sens11','sens12','sens13','sens14','sens15','sens16','sens17','sens18','sens19','sens20','sens21','sens22','sens23','sens24' };


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

if contains(subject, 'acc') 
    mask = [mask , sensors];
end


refchannel = {'fz'};
sec_refchannel = {'fz'};

eegchannels = setdiff(mask, remove_mask);

datapath      = ['analysis/' artifactrej '/' spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
bagspath      = 'analysis/bags/aligned/';

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
elseif contains(subject, 'errp')
    chanlocstr        = load(chanlocspath);
    chanlocs_a        = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
end


%% Remove the channels that I do not want

remove_mask = {};

eegchannels = setdiff(mask, remove_mask);


%% Parameters
MASK_N = 'CAMERA';

mode = '';

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

mask_name = {'CAMERA', 'BUTTON', 'COMMAND', 'AUDIO', 'FEEDBACK'};
mask_colors = ['--r'; '--g'; '--b'; '--m'];


mask_value = [0, 80, 60, 40, 30];

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

epoch = [-0.5 2.5];

min_i = -0.1;
max_i =  1.5;


%% Import the decoder
util_bdisp(['[io] - Importing the decoder from: ' decoder_path]);

decoder = load(decoder_path);
decoder = decoder.decoder;
%decoder.threshold = 0.51;


%% Importing data
util_bdisp(['[io] - Importing ' num2str(ndatafiles) ' files from ' datapath ':']);
[eeg, eog, events, labels, settings] = errp_concatenate_bandpass(datafiles);
[eeg_unfiltered, ~, ~, ~, ~] = errp_concatenate_bandpass(datafiles_unfiltered);
%[pose, twist, cmdvel, bagevents, baglabels] = errp_concatenate_bags(bagsfiles);

nchannels  = size(eeg, 2);
samplerate = settings.samplerate;
eTYP       = events.TYP;
ePOS       = events.POS;

% For the 'run' event it is needed to correct the type of the events
% It depends on the event 5000 only present in that gdfs
eTYP = recomputeTYP(eTYP,mode);

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


%% Extract trials
util_bdisp('[proc] + Extracting trials:');

% Extract events
disp('     |- Extract events');
evtidx = errp_util_get_event_type([CommandLx CommandRx ErrorLx ErrorRx NoReleaseFx NoReleaseRx NoReleaseLx], eTYP);
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

%% Extract epochs
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
    T(:, :, trId) = eeg(cstart:cstop, :);
    Tu(:, :, trId) = eeg_unfiltered(cstart:cstop, :);

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


%% Get the signals into shape
t = epoch(1):1/samplerate:epoch(2);

[~, refchannelidx] = ismember(upper(refchannel), upper(settings.channels.eeg));
[~, sec_refchannelidx] = ismember(upper(sec_refchannel), upper(settings.channels.eeg));

nrefchannel = length(refchannel);

chanlocs = settings.channels.chanlocs;

m_eeg_err = squeeze(mean(T(:, :, Ek), 3));
m_eeg_cor = squeeze(mean(T(:, :, Ck), 3));

overlap_window_samples = 32;

%overlap_window_samples = 2;


%prediction = zeros(size(T,1), size(T,3));

prediction = cell(size(T,3),1);
t = [];
%% Pseudo-online analisis
util_bdisp('[proc] - Performing the pseudo-online evaluation ');
for index = 1:size(T,3)
    run_data = T(:,decoder.refchannelidx,index);

    size_t = size(run_data, 1);
    size_window = decoder.time_leng;

    tmp_prob = [];
    t = [];

    t_a = epoch(1):1/samplerate:epoch(2);

    % Compute the prediction across the data, according to the overlap window
    for i = 1:overlap_window_samples:(size_t - size_window + 1)
        if (t_a(i) < min_i || t_a(i) > max_i )
            tmp_prob = [tmp_prob 0];
            t = [t, i];
        else
            inf_time = i;
            sup_time = i + size_window;
    
            if sup_time > size_t
                break;
            end
     
            data = downsample(run_data(inf_time:sup_time,:), 8);
    
            % Compute the prediction
            posterior = singleClassification(decoder, data, data);
            % posterior = probablity of presence of the errp
            tmp_prob = [tmp_prob posterior];
            t = [t, i];
        end
    end
    prediction{index} = tmp_prob;
end
t_a = epoch(1):1/samplerate:epoch(2);


% Convert into a matrix form
prediction = cell2mat(prediction);
% check the presence of the 

computed_prediction = prediction > decoder.threshold;

errp_print_prediction(computed_prediction, T, Tu, decoder, overlap_window_samples, refchannelidx, compute_time_freuency_decomposition, chanlocs);

computed_label = min(sum(computed_prediction, 2),1);
true_label = zeros(size(prediction, 1), 1);
true_label(Ek) = 1;
true_label(Ck) = 0;

err = prediction(Ek, :);
cor = prediction(Ck, :);

m_err = mean(err,1);
m_cor = mean(cor,1);
s_err = std(err,1);
s_cor = std(cor,1);

confusion_matrix = confusionmat((true_label), (computed_label));

% Compute the accuracy
numCorrect = sum(diag(confusion_matrix)); % Sum of diagonal elements
total = sum(confusion_matrix, 'all');     % Total number of predictions
accuracy = numCorrect / total;

% Display the result
disp(['     |- Accuracy: ', num2str(accuracy), '/1.0']);

y_lims = [0.4, 0.6];

figure()
x = 1:size(prediction,2);
x = t_a(t);


subplot(2,2,1)
classNames = {'no errp', 'errp'};
confusionchart(confusion_matrix, classNames);

subplot(2,2,3)
hold on
plot_errp_f(x, m_cor', m_err', s_cor', s_err')
yline(decoder.threshold, '--k', 'LineWidth', 1);
ylim(y_lims);
title("means")
hold off

subplot(2,2,2)
hold on
plot(x, err')
ylim(y_lims);
title("p err")
xlim([x(1) x(end)]);
yline(decoder.threshold, '--k', 'LineWidth', 1);
grid on;
hold off

t = epoch(1):1/samplerate:epoch(2);

subplot(2,2,4)
hold on
plot(x, cor')
yline(decoder.threshold, '--k', 'LineWidth', 1);
ylim(y_lims);
title("p corr")
xlim([x(1) x(end)]);
grid on;
hold off

sgtitle(['pseudo-online ' subject]) 


function plot_errp_f(t, correct, error, stdc, stde)

    hold on;
    plot_std(t, error, stde,'r');
    plot_std(t, correct, stdc,'b');
    % plot(t, error - correct, 'k', 'LineWidth', 2);
    legend('error', '', 'correct', '')
    hold off;
    
    xlim([t(1) t(end)]);
    grid on;

end

function plot_std(x, y,std_dev, c)    
    plot(x, y, c);
    patch([x flip(x)], [y-std_dev; flip(y+std_dev)], c, 'FaceAlpha',0.25, 'EdgeColor','none')
end