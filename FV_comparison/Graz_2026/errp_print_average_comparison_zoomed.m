function [] = errp_print_average_comparison_zoomed(all_data)
% errp_print_average_comparison_zoomed
% Same layout as errp_print_average_comparison but each condition subplot
% uses a condition-specific x-axis zoom window:
%   subplot 1 (Visual ErrP):               0.10 s – 0.50 s
%   subplot 2 (Movement ErrP, sighted):    0.20 s – 0.60 s
%   subplot 3 (Movement ErrP, blindfold):  0.45 s – 0.85 s
%   subplot 4 (overlay):                   full time range, no custom xticks
% Y-axis ranges and all other styling are identical to the original function.
% Input: all_data - cell array of condition structs (output of main script)

    n_conditions = length(all_data);

    % Colors: blue, green, orange
    colors = {[0.18 0.45 0.72], [0.18 0.65 0.33], [0.93 0.55 0.14]};

    % Per-condition x-axis zoom windows [xmin xmax] in seconds
    zoom_windows = {[0.10 0.50], [0.20 0.60], [0.45 0.85]};

    setting_ref = all_data{1}.settings;

    fig = figure();
    fig.Position = [100 100 300 900];

    condition_labels = {};
    diff_eegs = {};  % store diffs for the last subplot

    for idx_c = 1:n_conditions
        d        = all_data{idx_c};
        setting  = d.settings;
        cond     = d.cond;

        if idx_c == 1
            title_cond = 'Pipeline 1 - Visual ErrP';
        elseif idx_c == 2
            title_cond = 'Pipeline 1 - Movement ErrP - Vision allowed';
        else
            title_cond = 'Pipeline 2 - Movement Errp - Blindfolded';
        end

        condition_labels{idx_c} = sprintf('%s', title_cond);

        T   = cat(3, d.means_e, d.means_c);
        vl  = d.vl;
        t   = setting.t;
        refchannelidx = setting.refchannelidx;
        n_s = d.n_subjects;

        % Logical indices
        n_e = false(n_s * 2, 1);  n_e(1:n_s) = true;
        n_c = ~n_e;

        % EEG difference: error - correct
        tmp_e = T(:, :, n_e);
        tmp_c = T(:, :, n_c);
        m_e   = squeeze(mean(tmp_e(:, refchannelidx, :), 3));
        m_c   = squeeze(mean(tmp_c(:, refchannelidx, :), 3));
        diff_eeg = m_e - m_c;
        diff_eegs{idx_c} = diff_eeg;

        if idx_c ~= 1
            % Velocity
            v    = nanmean(vl, 2)';
            vstd = nanstd(vl') * 1.5;
        end

        col  = colors{idx_c};
        xwin = zoom_windows{idx_c};

        % ── Subplot idx_c: EEG diff + velocity (zoomed x-axis) ──
        subplot(4, 1, idx_c);
        hold on;
        grid on;

        if idx_c ~= 1
            % Velocity shaded area
            fill([t fliplr(t)], ...
                 [v*10 + vstd  fliplr(v*10 - vstd)] - v(1)*10, ...
                 [0.6 0.6 0.6], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

            % Velocity mean line
            plot(t, v*10 - v(1)*10, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
        end

        % EEG difference line
        plot(t, diff_eeg, '-', 'Color', col, 'LineWidth', 2);

        % Reference lines
        plot_vline(0, 'k');
        plot_hline(0, 'k');

        % Zoomed x-axis for this condition
        xlim(xwin);
        xticks(xwin(1):0.1:xwin(2));

        % Y-axis ranges identical to original
        if idx_c == 3
            ylim([-2 2]);
        elseif idx_c == 2
            ylim([-3 5]);
        else
            ylim([-3 3]);
        end

        xlabel('time [s]');
        if idx_c == 1
            ylabel('microvolt [\muV]');
        end
        title(condition_labels{idx_c});
        if idx_c ~= 1
            legend({'velocity (shaded)', 'velocity', 'EEG diff'}, 'Location', 'northwest');
        else
            legend({'EEG diff'}, 'Location', 'northwest');
        end
    end

    % ── Subplot 4: all EEG diffs overlaid, full time range, no custom xticks ──
    subplot(4, 1, 4);
    hold on;
    grid on;

    for idx_c = 1:n_conditions
        col = colors{idx_c};
        t   = all_data{idx_c}.settings.t;
        plot(t, diff_eegs{idx_c}, '-', 'Color', col, 'LineWidth', 2);
    end

    plot_hline(0, 'k');
    plot_vline(0, 'k');

    xlim([setting_ref.t(1) setting_ref.t(end)]);
    ylim([-2.5 2.5]);
    xlabel('time [s]');
    title('EEG diff — all conditions');
    legend(condition_labels, 'Location', 'northwest');

    % ── Shared title ──
    sgtitle(['channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter ...
             ' | Comparison across experiments (zoomed)']);

    % ── Save ──
    folder = fullfile('presentations/imgs/grand_average', 'Comparison');
    folder = fullfile(folder, setting_ref.spatialfilter);
    if ~exist(folder, 'dir'); mkdir(folder); end

    filename = sprintf('comparison_zoomed_%s_%s.png', ...
        char(setting_ref.refchannel), setting_ref.spatialfilter);
    file = fullfile(folder, filename);

    exportgraphics(fig, file, 'Resolution', setting_ref.img_resolution);
    print(fig, fullfile(folder, strrep(filename, '.png', '.svg')), ...
          '-dsvg', '-vector');
end