function errp_plot_velocity_profiles(all_data)
% errp_plot_velocity_profiles  Plot full-recording velocity per subject per condition.
%
%   One figure per condition, one subplot per subject.
%   Error trial onsets in red, correct trial onsets in blue.

    n_conditions = length(all_data);

    for idx_c = 1:n_conditions
        d          = all_data{idx_c};
        n_subjects = d.n_subjects;
        cond       = d.cond;
        sr         = d.settings.samplerate;   % 512 Hz

        % Layout: try to make subplots roughly square
        % n_cols = ceil(sqrt(n_subjects));
        % n_rows = ceil(n_subjects / n_cols);
        n_cols = 1;
        n_rows = n_subjects;

        fig_title = sprintf('Velocity profiles | owner: %s | analysis: %s', ...
            cond.owner, cond.piero_analysis);
        figure('Name', fig_title, 'NumberTitle', 'off', ...
               'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        sgtitle(fig_title, 'Interpreter', 'none', 'FontSize', 13, 'FontWeight', 'bold');

        for idx_s = 1:n_subjects
            rv   = d.r_vect{idx_s};
            t_ax = (0:length(rv.twist.z)-1) / sr;   % time axis in seconds

            ax = subplot(n_rows, n_cols, idx_s);
            hold(ax, 'on');

            % --- full velocity trace ---
            plot(ax, t_ax, rv.twist.z, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);

            % --- correct trial onsets (blue) ---
            pos_ck = rv.ePOS(rv.Ck) / sr;
            for k = 1:length(pos_ck)
                xline(ax, pos_ck(k), 'b', 'Alpha', 0.4, 'LineWidth', 0.8);
            end

            % --- error trial onsets (red) ---
            pos_ek = rv.ePOS(rv.Ek) / sr;
            for k = 1:length(pos_ek)
                xline(ax, pos_ek(k), 'r', 'Alpha', 0.4, 'LineWidth', 0.8);
            end

            % --- formatting ---
            xlabel(ax, 'Time (s)');
            ylabel(ax, 'Vel z (m/s)');
            title(ax, strrep(rv.subj, '_', '\_'), 'FontSize', 9);
            grid(ax, 'on');
            box(ax, 'on');

            % legend only on first subplot to avoid clutter
            if idx_s == 1
                legend(ax, {'velocity', 'correct onset', 'error onset'}, ...
                    'Location', 'best', 'FontSize', 7);
            end
        end
    end
end