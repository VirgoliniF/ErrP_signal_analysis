function errp_artifact_detection()
% ERRP_ARTIFACT_DETECTION
%   For each bag+GDF pair in a selected directory, epochs the EEG around
%   movement onset events and flags trials exceeding an amplitude threshold.
%
%   Epoch window  : [0, epoch(2)] from errp_load_setting (movement onset = t=0)
%   Channels      : classifier channels (reference highlighted) + EOG (same figure)
%   Layout        : 3-column grid, EOG continues after EEG channels
%   Threshold     : max_peak / max_peak_eog from errp_load_setting
%   Aggregation   : flagged trials pooled per subject across runs before plotting
%
%   Movement onset events (COMMAND mask = 260):
%       361, 363, 461, 463, 5361, 5363, 5461, 5463

clc; close;
addpath(genpath(pwd), '-begin');

%% ── User-settable parameters ────────────────────────────────────────────────
MASK_NAME       = 'COMMAND';
OWNER           = 'Francesca';
DATA_OWNER      = 'Francesca';
PIERO_ANALYSIS  = 'movement';
EXCLUDEPAT      = {'fb'};

MOVEMENT_EVENTS = [361, 363, 461, 463, 5361, 5363, 5461, 5463];
N_COLS          = 3;   % columns in the channel grid

%% ── Select bag directory ────────────────────────────────────────────────────
bagdir = uigetdir(pwd, 'Select folder containing aligned bag .mat files');
if bagdir == 0
    disp('No folder selected. Exiting.');
    return;
end

bagfiles_all = dir(fullfile(bagdir, '*.mat'));
if isempty(bagfiles_all)
    error('No .mat files found in: %s', bagdir);
end

%% ── Infer unique subject names and let the user pick ────────────────────────
all_subjects = {};
for k = 1:length(bagfiles_all)
    tok = regexp(bagfiles_all(k).name, '(learn_errp_\w+)', 'tokens', 'once');
    if ~isempty(tok)
        all_subjects{end+1} = tok{1}; %#ok<AGROW>
    end
end
all_subjects = unique(all_subjects);

if isempty(all_subjects)
    error('No recognisable subject names found in folder: %s', bagdir);
end

[sel_idx, ok] = listdlg( ...
    'PromptString',  'Select subjects to process:', ...
    'ListString',    all_subjects, ...
    'SelectionMode', 'multiple', ...
    'ListSize',      [300 200], ...
    'Name',          'Subject selection');

if ~ok || isempty(sel_idx)
    disp('No subjects selected. Exiting.');
    return;
end

selected_subjects = all_subjects(sel_idx);
fprintf('\n[io] Selected %d subject(s): %s\n', ...
        length(selected_subjects), strjoin(selected_subjects, ', '));

% Keep only bag files belonging to selected subjects
keep = cellfun(@(f) any(cellfun(@(s) contains(f, s), selected_subjects)), ...
               {bagfiles_all.name});
bagfiles = bagfiles_all(keep);
fprintf('[io] Processing %d bag file(s) in: %s\n', length(bagfiles), bagdir);

%% ── Build cond struct ───────────────────────────────────────────────────────
cond.owner          = OWNER;
cond.data_owner     = DATA_OWNER;
cond.piero_analysis = PIERO_ANALYSIS;

%% ── Per-subject accumulator ─────────────────────────────────────────────────
% subj_acc.(subjectName).T_clf   : [samples x n_clf x n_flagged_trials]  (flagged only)
% subj_acc.(subjectName).T_eog   : [samples x n_eog x n_flagged_trials]
% subj_acc.(subjectName).flag_clf_ch : [n_clf x n_flagged_trials]  per-channel flag
% subj_acc.(subjectName).flag_eog_ch : [n_eog x n_flagged_trials]
% subj_acc.(subjectName).n_total : total trials across runs
% subj_acc.(subjectName).n_flagged
% subj_acc.(subjectName).settings, .t_axis  (filled on first run for subject)
subj_acc = struct();

%% ════════════════════════════════════════════════════════════════════════════
%  PASS 1 — iterate files, collect per-run stats, accumulate flagged epochs
%% ════════════════════════════════════════════════════════════════════════════
for fId = 1:length(bagfiles)

    bagfile = fullfile(bagdir, bagfiles(fId).name);
    [~, fname] = fileparts(bagfile);

    fprintf('\n================================================================\n');
    fprintf('[%d/%d] Processing: %s\n', fId, length(bagfiles), fname);
    fprintf('================================================================\n');

    %% ── Infer subject name ──────────────────────────────────────────────────
    % tok = regexp(fname, '(learn_errp_\w+)', 'tokens', 'once');
    % if isempty(tok)
    %     warning('Cannot infer subject from filename: %s. Skipping.', fname);
    %     continue;
    % end
    % subject  = tok{1};
    % safe_key = strrep(subject, '-', '_');   % valid struct fieldname
    fprintf('[io] Subject: %s\n', subject);

    %% ── Load settings ───────────────────────────────────────────────────────
    cfg = errp_load_setting({subject}, false, cond);
    cfg.data_owner     = DATA_OWNER;
    cfg.owner          = OWNER;
    cfg.piero_analysis = PIERO_ANALYSIS;

    samplerate   = cfg.samplerate;
    epoch        = cfg.epoch;
    max_peak     = cfg.max_peak;
    max_peak_eog = cfg.max_peak_eog;
    mask         = cfg.mask;
    clf_ch       = cfg.classificator_channel;
    clf_idx      = cfg.classificator_channel_idx;
    ref_ch       = cfg.refchannel{1};
    eog_ch       = cfg.eog_channels;
    remove_mask  = cfg.remove_mask;
    eegchannels  = setdiff(mask, remove_mask, 'stable');

    mvt_epoch    = [0, epoch(2)];
    nsamples_mvt = length(0 : 1/samplerate : mvt_epoch(2));
    t_axis       = (0 : nsamples_mvt-1) / samplerate;

    [~, ref_clf_pos] = ismember(upper(ref_ch), upper(clf_ch));

    fprintf('[settings] Movement epoch: [%.2f, %.2f] s  (%d samples)\n', ...
            mvt_epoch(1), mvt_epoch(2), nsamples_mvt);
    fprintf('[settings] Threshold EEG: %.1f uV  |  EOG: %.1f uV\n', ...
            max_peak, max_peak_eog);

    %% ── Locate GDF-derived .mat ─────────────────────────────────────────────
    % Datapath is inferred directly from the bag folder the user selected.
    % The bag folder IS the bandpass directory, so we use it as-is.
    datapath = bagdir;

    datafiles = util_getfile3(datapath, '.mat', 'include', {subject}, ...
                              'exclude', [EXCLUDEPAT, {'unfiltered'}]);
    if isempty(datafiles)
        warning('No GDF .mat found for %s in %s. Skipping.', subject, datapath);
        continue;
    end

    %% ── Load data ───────────────────────────────────────────────────────────
    fprintf('[io] EEG : %s\n', datafiles{1});
    [eeg, eog, gdf_events, ~] = errp_concatenate_bandpass(datafiles);

    fprintf('[io] Bag : %s\n', bagfile);

    %% ── Extract movement onset events ───────────────────────────────────────
    eTYP = gdf_events.TYP;
    ePOS = gdf_events.POS;

    mvt_mask = ismember(eTYP, MOVEMENT_EVENTS);
    mvt_POS  = ePOS(mvt_mask);
    n_trials = length(mvt_POS);

    if n_trials == 0
        warning('No movement onset events for %s. Skipping.', subject);
        continue;
    end

    % Remove out-of-bounds trials
    valid   = mvt_POS + nsamples_mvt - 1 <= size(eeg, 1) & mvt_POS >= 1;
    mvt_POS = mvt_POS(valid);
    n_trials = length(mvt_POS);
    fprintf('[events] Valid trials: %d\n', n_trials);

    %% ── Epoch ───────────────────────────────────────────────────────────────
    n_clf   = length(clf_idx);
    n_eog   = size(eog, 2);
    T_clf   = zeros(nsamples_mvt, n_clf,  n_trials);
    T_eog   = zeros(nsamples_mvt, n_eog,  n_trials);

    for tr = 1:n_trials
        cs = mvt_POS(tr);
        ce = cs + nsamples_mvt - 1;
        T_clf(:, :, tr) = eeg(cs:ce, clf_idx);
        T_eog(:, :, tr) = eog(cs:ce, :);
    end

    %% ── Detect artefacts ────────────────────────────────────────────────────
    peak_clf = reshape(max(abs(T_clf), [], 1), n_clf,  n_trials);  % [n_clf x n_trials]
    peak_eog = reshape(max(abs(T_eog), [], 1), n_eog, n_trials);  % [n_eog x n_trials]

    flag_clf      = peak_clf > max_peak;          % [n_clf x n_trials]
    flag_eog      = peak_eog > max_peak_eog;      % [n_eog x n_trials]
    trial_flagged = any(flag_clf, 1) | any(flag_eog, 1);  % [1 x n_trials]

    n_art     = sum(trial_flagged);
    pct       = 100 * n_art / n_trials;

    %% ── Per-run console summary ─────────────────────────────────────────────
    fprintf('\n--- RUN SUMMARY: %s ---\n', fname);
    fprintf('  Total trials    : %d\n',            n_trials);
    fprintf('  Flagged (any)   : %d  (%.1f%%)\n',  n_art, pct);
    fprintf('  Clean           : %d  (%.1f%%)\n',  n_trials - n_art, 100 - pct);

    fprintf('\n  EEG classifier channels (thr = %.1f uV):\n', max_peak);
    for ch = 1:n_clf
        ref_tag = '';
        if ref_clf_pos == ch, ref_tag = '  ◄ REF'; end
        fprintf('    %-6s : %d flagged%s\n', clf_ch{ch}, sum(flag_clf(ch,:)), ref_tag);
    end
    fprintf('\n  EOG channels (thr = %.1f uV):\n', max_peak_eog);
    for ch = 1:n_eog
        lbl = get_eog_label(ch, eog_ch);
        fprintf('    %-6s : %d flagged\n', lbl, sum(flag_eog(ch,:)));
    end

    %% ── Accumulate flagged epochs into per-subject struct ───────────────────
    trial_clean = ~trial_flagged;

    % Separate flagged and clean epochs
    flagged_T_clf  = T_clf(:, :, trial_flagged);
    flagged_T_eog  = T_eog(:, :, trial_flagged);
    flagged_clf_ch = flag_clf(:, trial_flagged);
    flagged_eog_ch = flag_eog(:, trial_flagged);

    clean_T_clf = T_clf(:, :, trial_clean);
    clean_T_eog = T_eog(:, :, trial_clean);

    if ~isfield(subj_acc, safe_key)
        % First run for this subject — initialise
        subj_acc.(safe_key).subject      = subject;
        subj_acc.(safe_key).T_clf_flag   = flagged_T_clf;
        subj_acc.(safe_key).T_eog_flag   = flagged_T_eog;
        subj_acc.(safe_key).T_clf_clean  = clean_T_clf;
        subj_acc.(safe_key).T_eog_clean  = clean_T_eog;
        subj_acc.(safe_key).flag_clf_ch  = flagged_clf_ch;
        subj_acc.(safe_key).flag_eog_ch  = flagged_eog_ch;
        subj_acc.(safe_key).n_total      = n_trials;
        subj_acc.(safe_key).n_flagged    = n_art;
        subj_acc.(safe_key).t_axis       = t_axis;
        subj_acc.(safe_key).clf_ch       = clf_ch;
        subj_acc.(safe_key).eog_ch       = eog_ch;
        subj_acc.(safe_key).ref_clf_pos  = ref_clf_pos;
        subj_acc.(safe_key).max_peak     = max_peak;
        subj_acc.(safe_key).max_peak_eog = max_peak_eog;
        subj_acc.(safe_key).mvt_epoch    = mvt_epoch;
    else
        % Subsequent run — concatenate along trial dimension
        subj_acc.(safe_key).T_clf_flag   = cat(3, subj_acc.(safe_key).T_clf_flag,  flagged_T_clf);
        subj_acc.(safe_key).T_eog_flag   = cat(3, subj_acc.(safe_key).T_eog_flag,  flagged_T_eog);
        subj_acc.(safe_key).T_clf_clean  = cat(3, subj_acc.(safe_key).T_clf_clean, clean_T_clf);
        subj_acc.(safe_key).T_eog_clean  = cat(3, subj_acc.(safe_key).T_eog_clean, clean_T_eog);
        subj_acc.(safe_key).flag_clf_ch  = cat(2, subj_acc.(safe_key).flag_clf_ch, flagged_clf_ch);
        subj_acc.(safe_key).flag_eog_ch  = cat(2, subj_acc.(safe_key).flag_eog_ch, flagged_eog_ch);
        subj_acc.(safe_key).n_total      = subj_acc.(safe_key).n_total   + n_trials;
        subj_acc.(safe_key).n_flagged    = subj_acc.(safe_key).n_flagged + n_art;
    end

end % fId

%% ════════════════════════════════════════════════════════════════════════════
%  PASS 2 — per-subject aggregate summary + plot
%% ════════════════════════════════════════════════════════════════════════════
subj_keys = fieldnames(subj_acc);

fprintf('\n################################################################\n');
fprintf('  AGGREGATE SUMMARY ACROSS RUNS\n');
fprintf('################################################################\n');

for si = 1:length(subj_keys)
    sk  = subj_keys{si};
    acc = subj_acc.(sk);

    n_tot  = acc.n_total;
    n_flag = acc.n_flagged;
    pct    = 100 * n_flag / n_tot;

    clf_ch      = acc.clf_ch;
    eog_ch      = acc.eog_ch;
    ref_pos     = acc.ref_clf_pos;
    n_clf       = length(clf_ch);
    n_eog       = size(acc.T_eog_flag, 2);
    t_axis      = acc.t_axis;
    max_peak     = acc.max_peak;
    max_peak_eog = acc.max_peak_eog;
    mvt_epoch    = acc.mvt_epoch;

    %% ── Aggregate console summary ───────────────────────────────────────────
    fprintf('\n=== SUBJECT: %s ===\n', acc.subject);
    fprintf('  Total trials (all runs)  : %d\n',           n_tot);
    fprintf('  Flagged (any)            : %d  (%.1f%%)\n', n_flag, pct);
    fprintf('  Clean                    : %d  (%.1f%%)\n', n_tot - n_flag, 100 - pct);

    fprintf('\n  EEG classifier channels (thr = %.1f uV):\n', max_peak);
    for ch = 1:n_clf
        ref_tag = '';
        if ref_pos == ch, ref_tag = '  ◄ REF'; end
        n_ch = sum(acc.flag_clf_ch(ch, :));
        fprintf('    %-6s : %d flagged%s\n', clf_ch{ch}, n_ch, ref_tag);
    end
    fprintf('\n  EOG channels (thr = %.1f uV):\n', max_peak_eog);
    for ch = 1:n_eog
        lbl  = get_eog_label(ch, eog_ch);
        n_ch = sum(acc.flag_eog_ch(ch, :));
        fprintf('    %-6s : %d flagged\n', lbl, n_ch);
    end

    %% ── Plot ────────────────────────────────────────────────────────────────
    n_channels = n_clf + n_eog;
    n_rows     = ceil(n_channels / N_COLS);

    col_eeg_clean    = [0.6 0.6 0.6];   % grey   (clean on this channel)
    col_eog_clean    = [0.3 0.7 0.3];   % green  (clean on this channel)
    col_flag_here    = [0.9 0.2 0.2];   % red    (flagged ON this channel)
    col_flag_other   = [0.5 0.1 0.8];   % purple (flagged on another channel)
    col_ref      = [0.1 0.4 0.9];   % blue label for reference channel

    fig = figure('Name', ['Artefact detection — ' acc.subject], ...
                 'NumberTitle', 'off', ...
                 'Units', 'normalized', ...
                 'OuterPosition', [0 0 1 1]);

    for ch = 1:n_channels

        ax = subplot(n_rows, N_COLS, ch);
        hold(ax, 'on');

        is_eog = ch > n_clf;
        ch_eeg = ch;           % index into clf channels (only valid if ~is_eog)
        ch_eog = ch - n_clf;   % index into EOG channels (only valid if is_eog)

        if ~is_eog
            thr       = max_peak;
            lbl       = clf_ch{ch_eeg};
            is_ref    = (ref_pos == ch_eeg);
            n_flag_ch = sum(acc.flag_clf_ch(ch_eeg, :));

            % flag_here: flagged ON this channel  [1 x n_flagged_trials]
            flag_here  = acc.flag_clf_ch(ch_eeg, :);   % logical row
            flag_other = ~flag_here;                    % flagged elsewhere but not here

            % Clean trials (grey)
            for tr = 1:size(acc.T_clf_clean, 3)
                plot(ax, t_axis, acc.T_clf_clean(:, ch_eeg, tr), ...
                     'Color', [col_eeg_clean, 0.35], 'LineWidth', 0.8);
            end
            % Flagged on another channel (purple, behind red)
            flag_other_idx = find(flag_other);
            for tr = flag_other_idx
                plot(ax, t_axis, acc.T_clf_flag(:, ch_eeg, tr), ...
                     'Color', [col_flag_other, 0.45], 'LineWidth', 0.8);
            end
            % Flagged on THIS channel (red, on top)
            flag_here_idx = find(flag_here);
            for tr = flag_here_idx
                plot(ax, t_axis, acc.T_clf_flag(:, ch_eeg, tr), ...
                     'Color', [col_flag_here, 0.75], 'LineWidth', 1.2);
            end
        else
            thr       = max_peak_eog;
            lbl       = get_eog_label(ch_eog, eog_ch);
            is_ref    = false;
            n_flag_ch = sum(acc.flag_eog_ch(ch_eog, :));

            flag_here  = acc.flag_eog_ch(ch_eog, :);
            flag_other = ~flag_here;

            % Clean trials (green)
            for tr = 1:size(acc.T_eog_clean, 3)
                plot(ax, t_axis, acc.T_eog_clean(:, ch_eog, tr), ...
                     'Color', [col_eog_clean, 0.35], 'LineWidth', 0.8);
            end
            % Flagged on another channel (purple)
            flag_other_idx = find(flag_other);
            for tr = flag_other_idx
                plot(ax, t_axis, acc.T_eog_flag(:, ch_eog, tr), ...
                     'Color', [col_flag_other, 0.45], 'LineWidth', 0.8);
            end
            % Flagged on THIS channel (red)
            flag_here_idx = find(flag_here);
            for tr = flag_here_idx
                plot(ax, t_axis, acc.T_eog_flag(:, ch_eog, tr), ...
                     'Color', [col_flag_here, 0.75], 'LineWidth', 1.2);
            end
        end

        % Threshold reference lines (always shown)
        yline(ax,  thr, '--k', 'LineWidth', 1.0, 'Alpha', 0.6);
        yline(ax, -thr, '--k', 'LineWidth', 1.0, 'Alpha', 0.6);
        xline(ax, 0,    ':k', 'LineWidth', 0.8, 'Alpha', 0.4);

        grid(ax, 'on');
        xlim(ax, [t_axis(1), t_axis(end)]);
        xlabel(ax, 'Time (s)', 'FontSize', 7);
        ylabel(ax, '\muV',     'FontSize', 7);

        % Title — reference channel highlighted in blue
        prefix = '';
        if is_eog, prefix = '[EOG] '; end
        title_str = sprintf('%s%s  |  flagged: %d', prefix, lbl, n_flag_ch);

        if is_ref
            title(ax, title_str, 'Color', col_ref, 'FontWeight', 'bold', 'FontSize', 8);
            ax.XColor = col_ref;
            ax.YColor = col_ref;
        else
            title(ax, title_str, 'FontSize', 8);
        end

        hold(ax, 'off');
    end

    % Hide any leftover empty subplots
    for ch = n_channels+1 : n_rows * N_COLS
        ax = subplot(n_rows, N_COLS, ch);
        axis(ax, 'off');
    end

    sgtitle(fig, ...
        sprintf('%s  |  mvt epoch [%.2f, %.2f] s  |  flagged (pooled): %d / %d  (%.1f%%)', ...
                acc.subject, mvt_epoch(1), mvt_epoch(2), n_flag, n_tot, pct), ...
        'FontSize', 12, 'FontWeight', 'bold');

    drawnow;

end % subjects

fprintf('\n[done] Artefact detection complete.\n');
end

%% ── Helper ──────────────────────────────────────────────────────────────────
function lbl = get_eog_label(ch_idx, eog_ch)
    if ch_idx <= length(eog_ch)
        lbl = eog_ch{ch_idx};
    else
        lbl = sprintf('EOG%d', ch_idx);
    end
end