function acc_errp_plot_frequency_by_difficulty(T_by_cat, Ek_by_cat, Ck_by_cat, category_names, setting)
% ACC_ERRP_PLOT_FREQUENCY_BY_DIFFICULTY
%   Computes and plots time-frequency power for each difficulty category,
%   one figure per category, showing error vs. correct side by side for
%   the reference channel and the secondary reference channel.
%
% INPUTS:
%   T_by_cat       : cell array {1 x nCats}, each cell is [nsamples x nchannels x ntrials]
%                    (unfiltered epoched EEG, equivalent to Tu in the pipeline)
%   Ek_by_cat      : cell array {1 x nCats}, each cell is [ntrials x 1] logical (error mask)
%   Ck_by_cat      : cell array {1 x nCats}, each cell is [ntrials x 1] logical (correct mask)
%   category_names : cell array of strings, e.g. {'high', 'medium', 'low'}
%   setting        : settings struct from new_errp_load_setting, must contain:
%                      .t              – time vector [1 x nsamples]
%                      .samplerate     – sampling rate in Hz
%                      .refchannel     – primary reference channel name (string)
%                      .sec_refchannel – secondary reference channel name (string)
%                      .mask           – cell array of channel names
%                      .error_modality – 'visual' or 'vestibular'
%                      .spatialfilter  – string, used for output folder
%                      .img_resolution – DPI for saved figures
%
% OUTPUT:
%   One PNG figure saved per category under:
%       presentations/imgs/frequency/<error_modality>/<spatialfilter>/
%
% USAGE (from pipeline, after acc_errp_load_data):
%
%   % Build per-category inputs from the full T, Tu, Ek, Ck, trial_Rk, bagsfiles
%   difficulty_categories = {'high', 'medium', 'low'};
%   T_by_cat  = {};
%   Ek_by_cat = {};
%   Ck_by_cat = {};
%   valid_cats = {};
%   for k = 1:length(difficulty_categories)
%       tag          = difficulty_categories{k};
%       cat_rk_mask  = contains(bagsfiles, ['_' tag]);
%       cat_rk_ids   = find(cat_rk_mask);
%       trial_in_cat = ismember(trial_Rk, cat_rk_ids);
%       Ek_k = Ek & trial_in_cat;
%       Ck_k = Ck & trial_in_cat;
%       if sum(Ek_k) == 0 && sum(Ck_k) == 0; continue; end
%       T_by_cat{end+1}  = Tu;          % full tensor – indexing via Ek_k/Ck_k
%       Ek_by_cat{end+1} = Ek_k;
%       Ck_by_cat{end+1} = Ck_k;
%       valid_cats{end+1} = tag;
%   end
%   acc_errp_plot_frequency_by_difficulty(T_by_cat, Ek_by_cat, Ck_by_cat, valid_cats, settings);

    % ------------------------------------------------------------------ %
    %  Output folder
    % ------------------------------------------------------------------ %
    if strcmp(setting.error_modality, 'visual')
        base_folder = 'presentations/imgs/frequency/visual';
    else
        base_folder = 'presentations/imgs/frequency/vestibular';
    end
    folder = fullfile(base_folder, setting.spatialfilter);
    if ~exist(folder, 'dir'); mkdir(folder); end

    % ------------------------------------------------------------------ %
    %  Channel indices (resolved once, shared across all categories)
    % ------------------------------------------------------------------ %
    [~, refchannelidx]     = ismember(upper(setting.refchannel),     upper(setting.mask));
    [~, sec_refchannelidx] = ismember(upper(setting.sec_refchannel), upper(setting.mask));

    if refchannelidx == 0
        error('refchannel "%s" not found in setting.mask.', setting.refchannel);
    end
    if sec_refchannelidx == 0
        error('sec_refchannel "%s" not found in setting.mask.', setting.sec_refchannel);
    end

    % ------------------------------------------------------------------ %
    %  Shared params struct for errp_compute_frequency
    % ------------------------------------------------------------------ %
    params.epochTime = setting.t;
    params.fsamp     = setting.samplerate;

    % ------------------------------------------------------------------ %
    %  Loop over categories
    % ------------------------------------------------------------------ %
    nCats = length(category_names);

    for cIdx = 1:nCats
        category = category_names{cIdx};
        Tu_cat   = T_by_cat{cIdx};
        Ek_cat   = Ek_by_cat{cIdx};
        Ck_cat   = Ck_by_cat{cIdx};

        fprintf('[freq] Category "%s": %d error, %d correct trials.\n', ...
            category, sum(Ek_cat), sum(Ck_cat));

        % ---- compute TF for reference channel ------------------------ %
        [tf_err_ref, tf_cor_ref, ~, frex] = ...
            compute_tf_for_channel(Tu_cat, Ek_cat, Ck_cat, setting, refchannelidx);

        % ---- compute TF for secondary reference channel -------------- %
        [tf_err_sec, tf_cor_sec, ~, ~] = ...
            compute_tf_for_channel(Tu_cat, Ek_cat, Ck_cat, setting, sec_refchannelidx);

        % ---- plot ---------------------------------------------------- %
        fig = figure('Visible', 'off');
        fig.Position = [100 100 1600 700];

        t   = setting.t;
        clim_ref = compute_clim(tf_err_ref, tf_cor_ref);
        clim_sec = compute_clim(tf_err_sec, tf_cor_sec);

        % Row 1 – reference channel
        subplot(2, 2, 1);
        plot_tf(t, frex, tf_err_ref, clim_ref);
        title(sprintf('Channel: %s  |  Error  [%s]', ...
            char(setting.refchannel), upper(category)));
        xlabel('Time [s]'); ylabel('Frequency [Hz]');

        subplot(2, 2, 2);
        plot_tf(t, frex, tf_cor_ref, clim_ref);
        title(sprintf('Channel: %s  |  Correct  [%s]', ...
            char(setting.refchannel), upper(category)));
        xlabel('Time [s]'); ylabel('Frequency [Hz]');

        % Row 2 – secondary reference channel
        subplot(2, 2, 3);
        plot_tf(t, frex, tf_err_sec, clim_sec);
        title(sprintf('Channel: %s  |  Error  [%s]', ...
            char(setting.sec_refchannel), upper(category)));
        xlabel('Time [s]'); ylabel('Frequency [Hz]');

        subplot(2, 2, 4);
        plot_tf(t, frex, tf_cor_sec, clim_sec);
        title(sprintf('Channel: %s  |  Correct  [%s]', ...
            char(setting.sec_refchannel), upper(category)));
        xlabel('Time [s]'); ylabel('Frequency [Hz]');

        sgtitle(sprintf('Time-Frequency Power  –  %s  |  %s', ...
            strrep(char(setting.includepat{1}), '_', '\_'), upper(category)));

        % ---- save ---------------------------------------------------- %
        file = fullfile(folder, sprintf('tf_%s_%s.png', ...
            char(setting.includepat{1}), category));
        exportgraphics(fig, file, 'Resolution', setting.img_resolution);
        close(fig);
        fprintf('[freq] Saved: %s\n', file);
    end
end


% ======================================================================= %
%  Local helpers
% ======================================================================= %

function [tf_err, tf_cor, tf_diff, frex] = compute_tf_for_channel(Tu, Ek, Ck, setting, chanIdx)
% Wraps errp_compute_frequency so it analyses a specific channel.
% We temporarily reroute setting.refchannel to the desired channel by
% passing the index directly through a minimal params / data struct,
% matching exactly what errp_compute_frequency does internally.

    params.epochTime = setting.t;
    params.fsamp     = setting.samplerate;

    eegEpochs.data  = Tu;
    eegEpochs.label = zeros(size(Tu, 3), 1);
    eegEpochs.label = eegEpochs.label + Ek;
    eegEpochs.label = eegEpochs.label + Ck * 3;

    [tf_err, tf_cor, tf_diff, frex] = ...
        compute_theta_peak_v3_1Dcursor(eegEpochs, params, false, true, true, chanIdx);
end


function clim = compute_clim(tf_a, tf_b)
% Symmetric colour limits shared between error and correct panels.
    all_vals = [tf_a(:); tf_b(:)];
    mx = max(abs(all_vals(isfinite(all_vals))));
    if mx == 0 || isnan(mx)
        clim = [-1 1];
    else
        clim = [-mx mx];
    end
end


function plot_tf(t, frex, tf_data, clim)
% Imagesc wrapper with a consistent look.
    imagesc(t, frex, tf_data, clim);
    axis xy;                      % low frequencies at the bottom
    colormap(gca, 'jet');
    colorbar;
    plot_vline(0, 'k');           % event onset marker
end
