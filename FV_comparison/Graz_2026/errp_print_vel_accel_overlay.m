function [] = errp_print_vel_accel_overlay(all_data)
% errp_print_vel_accel_overlay
%
% Generates FIVE figures, each with 3 subplots (one per condition).
% All figures show:
%   - Mean ± SEM of (error - correct) across subjects
%   - Velocity anchored at EEG zero (as in errp_print_subject_variability)
%   - Smoothed acceleration (deriv of mean velocity, window=8)
%
% Figures differ in how acceleration is scaled and positioned:
%   Figure 1: acceleration uses the SAME scale factor as velocity (scale=10),
%             anchored at the BOTTOM of the y-axis
%   Figure 2: acceleration uses an INDEPENDENT scale factor (fills bottom 25%
%             of the plot), anchored at the BOTTOM of the y-axis
%   Figure 3: acceleration uses an INDEPENDENT scale factor (fills top 25%
%             of the plot), anchored at the TOP of the y-axis
%
% Input:
%   all_data - cell array of condition structs (output of main script)

    n_conditions = length(all_data);

    colors = {[0.18 0.45 0.72], [0.18 0.65 0.33], [0.93 0.55 0.14]};

    condition_labels = {
        'Pipeline 1 - Visual ErrP', ...
        'Pipeline 1 - Movement ErrP - Vision allowed', ...
        'Pipeline 2 - Movement ErrP - Blindfolded'
    };

    setting_ref = all_data{1}.settings;

    %% ── Figure 1: shared scale factor for velocity and acceleration ───────
    fig1 = figure();
    fig1.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'shared');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  vel & accel (shared scale)']);

    save_figure(fig1, setting_ref, 'SEM_vel_accel_shared');

    %% ── Figure 2: independent scale factor for acceleration ───────────────
    fig2 = figure();
    fig2.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'independent');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  vel & accel (independent scale)']);

    save_figure(fig2, setting_ref, 'SEM_vel_accel_independent');

    %% ── Figure 3: independent scale, acceleration anchored at TOP ─────────
    fig3 = figure();
    fig3.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'independent_top');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  vel & accel (independent scale, accel at top)']);

    save_figure(fig3, setting_ref, 'SEM_vel_accel_independent_top');

    %% ── Figure 4: accel at zero, shared right axis with velocity ──────────
    fig4 = figure();
    fig4.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'zero_shared');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  vel & accel at zero (shared right axis)']);

    save_figure(fig4, setting_ref, 'SEM_vel_accel_zero_shared');

    %% ── Figure 5: accel at zero, two separate right axes ──────────────────
    fig5 = figure();
    fig5.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'zero_independent');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  vel & accel at zero (separate right axes)']);

    save_figure(fig5, setting_ref, 'SEM_vel_accel_zero_independent');

    %% ── Figure 6: accel range matched to velocity range, shared zero ───────
    fig6 = figure();
    fig6.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'zero_range_matched');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  accel range matched to vel range (shared zero & right axis)']);

    save_figure(fig6, setting_ref, 'SEM_vel_accel_zero_range_matched');

    %% ── Figure 7: accel scaled so accel(end) = y_lim(2), zero at EEG zero ──
    fig7 = figure();
    fig7.Position = [100 100 1300 900];

    for idx_c = 1:n_conditions
        d             = all_data{idx_c};
        setting       = d.settings;
        t             = setting.t;
        n_s           = d.n_subjects;
        refchannelidx = setting.refchannelidx;
        col           = colors{idx_c};

        diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s);
        grand_mean       = mean(diff_per_subject, 2);
        sem              = std(diff_per_subject, 0, 2) / sqrt(n_s);

        vl_plot = [];
        if idx_c > 1
            vl_plot = d.vl;
        end

        subplot(3, 1, idx_c);
        if idx_c == 2
            ylim([-4 4]);
        end
        plot_vel_accel(t, grand_mean, sem, col, condition_labels{idx_c}, vl_plot, 'zero_tend_scaled');
    end

    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Mean \pm SEM  |  accel(end) anchored to y_{max}, zero at EEG zero']);

    save_figure(fig7, setting_ref, 'SEM_vel_accel_zero_tend_scaled');

end


%% ── Helper: compute per-subject EEG (error - correct) diff ───────────────
function diff_per_subject = compute_per_subject_diff(d, refchannelidx, n_s)

    diff_per_subject = zeros(size(d.means_e, 1), n_s);

    for idx_s = 1:n_s
        m_e = squeeze(d.means_e(:, refchannelidx, idx_s));
        m_c = squeeze(d.means_c(:, refchannelidx, idx_s));
        diff_per_subject(:, idx_s) = m_e - m_c;
    end
end


%% ── Helper: smoothed acceleration from mean velocity ─────────────────────
function accel = compute_acceleration(t, vl)
% Derivative of mean velocity, smoothed with an 8-sample moving average.

    smooth_win = 8;

    v_mean = nanmean(vl, 2);
    v_mean = v_mean(:);
    t_col  = t(:);
    n      = length(t_col);
    accel  = zeros(n, 1);

    for i = 2:n-1
        dt       = t_col(i+1) - t_col(i-1);
        accel(i) = (v_mean(i+1) - v_mean(i-1)) / dt;
    end
    accel(1) = (v_mean(2)   - v_mean(1))   / (t_col(2)   - t_col(1));
    accel(n) = (v_mean(n)   - v_mean(n-1)) / (t_col(n)   - t_col(n-1));

    kernel = ones(smooth_win, 1) / smooth_win;
    accel  = conv(accel, kernel, 'same');
end


%% ── Helper: main subplot — EEG + velocity at zero + acceleration
function plot_vel_accel(t, grand_mean, spread, col, title_str, vl, accel_scale_mode)
% accel_scale_mode:
%   'shared'           — accel same scale=10 as velocity, anchored at bottom
%   'independent'      — accel independent scale, anchored at bottom (25%)
%   'independent_top'  — accel independent scale, anchored at top (25%)
%   'zero_shared'      — accel anchored at EEG zero, velocity right axis
%                        also serves as acceleration axis (same scale factor)
%   'zero_independent' — accel anchored at EEG zero, two separate right axes
%                        (velocity [rad/s] and acceleration [rad/s²])

    vel_scale = 10;   % velocity scaling factor (same as original function)

    t_col    = t(:);
    mean_col = grand_mean(:);
    spr_col  = spread(:);

    upper = mean_col + spr_col;
    lower = mean_col - spr_col;

    hold on;
    grid on;

    % ── EEG shaded area and mean line ─────────────────────────────────────
    fill([t_col; flipud(t_col)], [upper; flipud(lower)], ...
         col, 'FaceAlpha', 0.20, 'EdgeColor', 'none');
    plot(t_col, mean_col, '-', 'Color', col, 'LineWidth', 2);

    plot_vline(0, 'k');
    plot_hline(0, 'k');

    xlim([t_col(1) t_col(end)]);
    xticks(t_col(1):0.1:t_col(end));
    xlabel('time [s]');
    ylabel('amplitude [\muV]');

    legend_entries = {'SEM', 'mean (error - correct)'};

    if ~isempty(vl)

        % ── Velocity — anchored at EEG zero ───────────────────────────────
        v        = nanmean(vl, 2)';
        v_shift  = v(1);
        v_scaled = (v(:) - v_shift) * vel_scale;

        plot(t_col, v_scaled, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5);
        legend_entries{end+1} = 'velocity';

        % ── Acceleration — anchored at bottom of current y-axis ───────────
        accel = compute_acceleration(t_col, vl);

        % Get current y-limits (set by EEG data)
        ax_left  = gca;
        y_lim    = ax_left.YLim;
        y_bottom = y_lim(1);       % fixed bottom anchor

        % Choose scale factor and anchor point
        if strcmp(accel_scale_mode, 'shared')
            a_scale  = vel_scale;
            a_scaled = (accel - min(accel)) * a_scale + y_bottom;
        elseif strcmp(accel_scale_mode, 'independent')
            % Fit acceleration range into bottom 25% of plot
            a_range   = max(accel) - min(accel);
            plot_span = y_lim(2) - y_lim(1);
            if a_range > 0
                a_scale = (0.25 * plot_span) / a_range;
            else
                a_scale = vel_scale;
            end
            % Anchor minimum of scaled accel at y_bottom
            a_scaled = (accel - min(accel)) * a_scale + y_bottom;
        else  % 'independent_top'
            % Fit acceleration range into top 25% of plot
            a_range   = max(accel) - min(accel);
            plot_span = y_lim(2) - y_lim(1);
            if a_range > 0
                a_scale = (0.25 * plot_span) / a_range;
            else
                a_scale = vel_scale;
            end
            % Anchor maximum of scaled accel at y_top
            y_top    = y_lim(2);
            a_scaled = (accel - max(accel)) * a_scale + y_top;
        end

        % ── Zero-anchored modes (override above if needed) ─────────────────
        if strcmp(accel_scale_mode, 'zero_shared')
            % Accel shares the same scale factor as velocity → same right axis
            a_scale  = vel_scale;
            a_scaled = accel * a_scale;   % zero of accel maps to EEG zero

        elseif strcmp(accel_scale_mode, 'zero_independent')
            % Accel has its own scale so its range fits within the plot span,
            % but zero is still anchored to EEG zero
            a_range   = max(abs(accel)) * 2;   % symmetric around zero
            plot_span = y_lim(2) - y_lim(1);
            if a_range > 0
                a_scale = (0.5 * plot_span) / a_range;  % fills ~50% of plot
            else
                a_scale = vel_scale;
            end
            a_scaled = accel * a_scale;   % zero of accel maps to EEG zero

        elseif strcmp(accel_scale_mode, 'zero_range_matched')
            % Scale accel so its peak-to-peak range equals that of velocity.
            % Both signals share zero, so the right axis ticks apply to both.
            v_mean   = nanmean(vl, 2);
            v_pp     = max(v_mean) - min(v_mean);   % velocity peak-to-peak
            a_pp     = max(accel)  - min(accel);    % acceleration peak-to-peak
            if a_pp > 0
                % k such that accel*k has the same p-p as velocity,
                % then apply vel_scale so it plots in the same left-axis space
                k       = v_pp / a_pp;
                a_scale = k * vel_scale;
            else
                a_scale = vel_scale;
            end
            a_scaled = accel * a_scale;   % zero of accel maps to EEG zero

        elseif strcmp(accel_scale_mode, 'zero_tend_scaled')
            % Refresh y_lim now to capture any ylim() set externally (e.g.
            % the [-4 4] forced on subplot 2) before computing the scale.
            y_lim = ax_left.YLim;
            % Scale so that accel(end) maps exactly to y_lim(2) (top of plot).
            if accel(end) ~= 0
                a_scale = y_lim(2) / accel(end);
            else
                a_scale = vel_scale;
            end
            a_scaled = accel * a_scale;   % zero of accel maps to EEG zero
        end

        % ── Plot acceleration line ─────────────────────────────────────────
        if strcmp(accel_scale_mode, 'zero_range_matched') || ...
           strcmp(accel_scale_mode, 'zero_tend_scaled')
            % Dash-dot + low opacity so it does not overpower the EEG
            h = plot(t_col, a_scaled, '-.', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.2);
            h.Color(4) = 0.7;
        else
            plot(t_col, a_scaled, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5);
        end
        legend_entries{end+1} = 'acceleration (smoothed)';

        % ── Right axis/axes ───────────────────────────────────────────────
        if strcmp(accel_scale_mode, 'zero_shared')
            % Single right axis: both velocity and acceleration use vel_scale
            % so the same tick labels apply to both
            right_lim = y_lim / vel_scale;
            ax_right = axes('Position', ax_left.Position, ...
                            'YAxisLocation', 'right', ...
                            'Color', 'none', ...
                            'XTick', [], ...
                            'YLim', right_lim, ...
                            'YColor', [0.2 0.2 0.2]);
            ylabel(ax_right, {'\Delta angular velocity = acceleration', '[rad/s or rad/s^2]'});
            axes(ax_left);

        elseif strcmp(accel_scale_mode, 'zero_range_matched')
            % Single shared right axis: ticks show velocity units [rad/s].
            % Acceleration has been rescaled to the same p-p range, so the
            % same ticks also reflect the relative magnitude of acceleration
            % (absolute values differ, but relative peaks are preserved).
            right_lim = y_lim / vel_scale;
            ax_right = axes('Position', ax_left.Position, ...
                            'YAxisLocation', 'right', ...
                            'Color', 'none', ...
                            'XTick', [], ...
                            'YLim', right_lim, ...
                            'YColor', [0.2 0.2 0.2]);
            ylabel(ax_right, {'\Delta angular velocity [rad/s]', 'accel (range-matched)'});
            axes(ax_left);

        elseif strcmp(accel_scale_mode, 'zero_tend_scaled')
            % Right axis shows velocity units. Acceleration is scaled so
            % accel(end) hits y_lim(2); the right axis reflects vel scale.
            y_lim     = ax_left.YLim;   % re-read to capture forced ylim
            right_lim = y_lim / vel_scale;
            ax_right = axes('Position', ax_left.Position, ...
                            'YAxisLocation', 'right', ...
                            'Color', 'none', ...
                            'XTick', [], ...
                            'YLim', right_lim, ...
                            'YColor', [0.2 0.2 0.2]);
            ylabel(ax_right, {'\Delta angular velocity [rad/s]', 'accel (scaled to end)'});
            axes(ax_left);

        elseif strcmp(accel_scale_mode, 'zero_independent')
            % Two separate right axes: velocity on the right, acceleration
            % further right (offset label to avoid overlap)

            % Velocity right axis
            right_vel_lim = y_lim / vel_scale;
            ax_right_vel = axes('Position', ax_left.Position, ...
                                'YAxisLocation', 'right', ...
                                'Color', 'none', ...
                                'XTick', [], ...
                                'YLim', right_vel_lim, ...
                                'YColor', [0.2 0.2 0.2]);
            ylabel(ax_right_vel, '\Delta angular velocity [rad/s]');

            % Acceleration right axis: invert a_scaled = accel * a_scale
            % → accel = a_scaled / a_scale, so right lim = y_lim / a_scale
            right_acc_lim = y_lim / a_scale;
            ax_right_acc = axes('Position', ax_left.Position, ...
                                'YAxisLocation', 'right', ...
                                'Color', 'none', ...
                                'XTick', [], ...
                                'YLim', right_acc_lim, ...
                                'YColor', [0.55 0.55 0.55]);
            ax_right_acc.YLabel.Position(1) = ax_right_acc.YLabel.Position(1) + 0.04;
            ylabel(ax_right_acc, '\Delta angular acceleration [rad/s^2]');

            axes(ax_left);

        else
            % ── Right axis for velocity (existing modes) ───────────────────
            right_vel_lim = y_lim / vel_scale;
            ax_right_vel = axes('Position', ax_left.Position, ...
                                'YAxisLocation', 'right', ...
                                'Color', 'none', ...
                                'XTick', [], ...
                                'YLim', right_vel_lim, ...
                                'YColor', [0.2 0.2 0.2]);
            ylabel(ax_right_vel, '\Delta angular velocity [rad/s]');

            % ── Right axis for acceleration ────────────────────────────────
            if strcmp(accel_scale_mode, 'independent_top')
                accel_right_top    = max(accel);
                accel_right_bottom = accel_right_top + (y_bottom - y_top) / a_scale;
            else
                accel_right_bottom = min(accel);
                accel_right_top    = accel_right_bottom + (y_lim(2) - y_bottom) / a_scale;
            end

            ax_right_acc = axes('Position', ax_left.Position, ...
                                'YAxisLocation', 'right', ...
                                'Color', 'none', ...
                                'XTick', [], ...
                                'YLim', [accel_right_bottom, accel_right_top], ...
                                'YColor', [0.55 0.55 0.55]);
            ax_right_acc.YLabel.Position(1) = ax_right_acc.YLabel.Position(1) + 0.04;
            ylabel(ax_right_acc, '\Delta angular acceleration [rad/s^2]');

            axes(ax_left);
        end
    end

    title(title_str);
    legend(legend_entries, 'Location', 'northwest');
end


%% ── Helper: save figure ──────────────────────────────────────────────────
function save_figure(fig, setting_ref, tag)

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