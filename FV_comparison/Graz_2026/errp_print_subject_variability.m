function [] = errp_print_subject_variability(all_data)
% errp_print_subject_variability
%
% Generates TWO figures, each with 3 subplots (one per condition):
%   Figure 1: Mean ± Standard Error of the Mean (SEM) of (error - correct)
%             across subjects, with shaded SEM area.
%   Figure 2: Mean ± Standard Deviation (SD) of (error - correct)
%             across subjects, with shaded SD area.
%
% The shaded area style mirrors the velocity shading in errp_print_average_comparison.
%
% Input:
%   all_data - cell array of condition structs (output of main script)

    n_conditions = length(all_data);

    % Colors: blue, green, orange (same as errp_print_average_comparison)
    colors = {[0.18 0.45 0.72], [0.18 0.65 0.33], [0.93 0.55 0.14]};

    condition_labels = {
        'Pipeline 1 - Visual ErrP', ...
        'Pipeline 1 - Movement ErrP - Vision allowed', ...
        'Pipeline 2 - Movement ErrP - Blindfolded'
    };

    setting_ref = all_data{1}.settings;

    %% ── Figure 1: Mean ± SEM ──────────────────────────────────────────────
    fig_sem = figure();
    fig_sem.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d        = all_data{idx_c};
        setting  = d.settings;
        t        = setting.t;
        n_s      = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col      = colors{idx_c};

        % Per-subject EEG difference (error - correct), shape: [n_t x n_subjects]
        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);

        % Grand mean and SEM across subjects
        grand_mean = mean(diff_per_subject, 2);
        sem        = std(diff_per_subject, 0, 2) / sqrt(n_s);

        % Pass velocity only for conditions 2 and 3 (movement conditions)
        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_with_shading(t, grand_mean, sem, col, condition_labels{idx_c}, 'SEM', vl_plot);

    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM across subjects']);

    save_figure(fig_sem, setting_ref, 'SEM');

    %% ── Figure 2: Mean ± SD ───────────────────────────────────────────────
    fig_sd = figure();
    fig_sd.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d        = all_data{idx_c};
        setting  = d.settings;
        t        = setting.t;
        n_s      = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col      = colors{idx_c};

        % Per-subject EEG difference (error - correct), shape: [n_t x n_subjects]
        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);

        % Grand mean and SD across subjects
        grand_mean = mean(diff_per_subject, 2);
        sd         = std(diff_per_subject, 0, 2);

        % Pass velocity only for conditions 2 and 3 (movement conditions)
        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        plot_with_shading(t, grand_mean, sd, col, condition_labels{idx_c}, 'SD', vl_plot);
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SD across subjects']);

    save_figure(fig_sd, setting_ref, 'SD');

end


%% ── Helper: compute per-subject EEG (error - correct) diff ───────────────
function diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s)
% Returns matrix of size [n_t x n_subjects], one diff trace per subject.

    diff_per_subject = zeros(size(d.means_e, 1), n_s);

    for idx_s = 1:n_s
        m_e = squeeze(d.means_e(:, refchannelidx, idx_s));
        m_c = squeeze(d.means_c(:, refchannelidx, idx_s));
        diff_per_subject(:, idx_s) = m_e - m_c;
    end
end


%% ── Helper: subplot with shaded mean ± spread ────────────────────────────
function plot_with_shading(t, grand_mean, spread, col, title_str, spread_label, vl)

    if nargin < 7
        vl = [];
    end

    t_col    = t(:);
    mean_col = grand_mean(:);
    spr_col  = spread(:);

    upper = mean_col + spr_col;
    lower = mean_col - spr_col;

    hold on;
    grid on;

    % Shaded spread area
    fill([t_col; flipud(t_col)], [upper; flipud(lower)], ...
         col, 'FaceAlpha', 0.20, 'EdgeColor', 'none');

    % Mean EEG line
    plot(t_col, mean_col, '-', 'Color', col, 'LineWidth', 2);

    % Reference lines
    plot_vline(0, 'k');
    plot_hline(0, 'k');

    xlim([t_col(1) t_col(end)]);
    xticks(t_col(1):0.1:t_col(end));
    xlabel('time [s]');
    ylabel('amplitude [\muV]');

    % ── Optional velocity: plotted on left axis (scaled), right axis shows
    %    true velocity values as a reference ──────────────────────────────
    legend_entries = {spread_label, 'mean (error - correct)'};
    if ~isempty(vl)
        v       = nanmean(vl, 2)';          % mean across trials → row vector
        scale   = 10;                        % same scaling factor as before
        %v_shift = 0;
        %v_shift = v(1);
        v_shift  = v(1);                        % anchor: v(1) maps to EEG 0
        v_scaled = (v - v_shift) * scale;    % shifted so origin = 0

        % Plot on left axis (so it shares the EEG zero line)
        plot(t_col, v_scaled(:), ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5);
        legend_entries{end+1} = 'velocity';

        % % ── Peak-to-velocity line ─────────────────────────────────────────
        % [peak_val, peak_idx] = min(mean_col);        % most negative EEG point
        % t_peak               = t_col(peak_idx);      % time of the peak
        % v_at_peak            = v_scaled(peak_idx);   % velocity value at same time
        % 
        % % Vertical line from EEG peak down to the velocity curve
        % plot([t_peak t_peak], [peak_val v_at_peak], '--', ...
        %      'Color', [0.5 0.5 0.5], 'LineWidth', 1.3);
        % legend_entries{end+1} = 'EEG peak';


        % Add right axis showing the true velocity scale
        ax_left  = gca;
        left_lim = ax_left.YLim;             % current EEG y-limits

        % Convert left limits back to velocity units
        right_lim = left_lim / scale;

        ax_right = axes('Position', ax_left.Position, ...
                        'YAxisLocation', 'right', ...
                        'Color', 'none', ...
                        'XTick', [], ...
                        'YLim', right_lim, ...
                        'YColor', [0.2 0.2 0.2]);
        ylabel(ax_right, '\Delta angular velocity [rad/s]');

        % Make sure subsequent commands (title, legend) target the main axes
        axes(ax_left);
    end

    title(title_str);
    legend(legend_entries, 'Location', 'northwest');
end

%% ── Helper: save figure ──────────────────────────────────────────────────
function save_figure(fig, setting_ref, tag)
% Saves figure as PNG and SVG under the Comparison folder.

    folder = fullfile('presentations/imgs/grand_average', 'Comparison');
    folder = fullfile(folder, setting_ref.spatialfilter);
    if ~exist(folder, 'dir'); mkdir(folder); end

    filename = sprintf('subject_variability_%s_%s_%s.png', ...
        char(setting_ref.refchannel), setting_ref.spatialfilter, tag);
    file = fullfile(folder, filename);

    exportgraphics(fig, file, 'Resolution', setting_ref.img_resolution);
    print(fig, fullfile(folder, strrep(filename, '.png', '.svg')), ...
          '-dsvg', '-vector');
end