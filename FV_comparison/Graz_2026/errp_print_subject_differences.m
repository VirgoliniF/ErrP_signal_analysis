function [] = errp_print_subject_differences(all_data)
% errp_print_subject_differences
% For each condition: plots the per-subject EEG difference (error - correct)
% as dashed lines, and the grand mean difference as a solid line.
% Layout: 3 rows x 1 column (one row per condition).
% Input: all_data - cell array of condition structs (output of main script)

    n_conditions = length(all_data);

    % Colors: blue, green, orange
    colors = {[0.18 0.45 0.72], [0.18 0.65 0.33], [0.93 0.55 0.14]};

    setting_ref = all_data{1}.settings;

    fig = figure();
    fig.Position = [100 100 1300 400 * n_conditions];

    for idx_c = 1:n_conditions
        d       = all_data{idx_c};
        setting = d.settings;
        cond    = d.cond;
        t       = setting.t;
        refchannelidx = setting.refchannelidx;
        n_s     = d.n_subjects;
        col     = colors{idx_c};

        % Per-subject differences: means_e and means_c are [t x ch x subjects]
        diff_per_subject = d.means_e(:, refchannelidx, :) - ...
                           d.means_c(:, refchannelidx, :);  % [t x 1 x n_s]
        diff_per_subject = squeeze(diff_per_subject);        % [t x n_s]

        % Grand mean difference across subjects
        diff_mean = mean(diff_per_subject, 2);               % [t x 1]

        subplot(n_conditions, 1, idx_c);
        hold on;
        grid on;

        % Per-subject dashed lines
        for idx_s = 1:n_s
            plot(t, diff_per_subject(:, idx_s), '--', ...
                 'Color', [col 0.4], ...   % same color, more transparent
                 'LineWidth', 1.0);
        end

        % Grand mean solid line
        plot(t, diff_mean, '-', 'Color', col, 'LineWidth', 2.5);

        plot_vline(0, 'k');
        plot_hline(0, 'k');

        xlim([t(1) t(end)]);
        %ylim([-4 4]);
        xlabel('time [s]');
        ylabel('microvolt [\muV]');

        if idx_c == 1
            title_cond = 'Pipeline 1 - Visual ErrP';
        elseif idx_c == 2
            title_cond = 'Pipeline 1 - Movement ErrP - Vision allowed';
        else
            title_cond = 'Pipeline 2 - Movement Errp - Blindfolded';
        end

        cond_label = sprintf('%s | %s', title_cond, cond.piero_analysis);
        title(cond_label);

        % Legend with one representative dashed entry + mean
        h_sub  = plot(nan, nan, '--', 'Color', [col 0.4], 'LineWidth', 1.0);
        h_mean = plot(nan, nan, '-',  'Color', col,        'LineWidth', 2.5);
        legend([h_sub h_mean], {'per-subject diff', 'grand mean diff'}, ...
               'Location', 'northwest');
    end

    sgtitle(['Per-subject differences | channel: ' char(setting_ref.refchannel) ...
             ' | filter: ' setting_ref.spatialfilter]);

    % ── Save ──
    folder = fullfile('presentations/imgs/grand_average', 'Comparison');
    folder = fullfile(folder, setting_ref.spatialfilter);
    if ~exist(folder, 'dir'); mkdir(folder); end

    filename = sprintf('subject_differences_%s_%s.png', ...
        char(setting_ref.refchannel), setting_ref.spatialfilter);
    file = fullfile(folder, filename);

    exportgraphics(fig, file, 'Resolution', setting_ref.img_resolution);
    print(fig, fullfile(folder, strrep(filename, '.png', '.svg')), ...
          '-dsvg', '-vector');
end