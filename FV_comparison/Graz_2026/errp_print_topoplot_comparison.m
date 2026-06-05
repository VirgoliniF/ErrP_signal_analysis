function [] = errp_print_topoplot_comparison(all_data)
% errp_print_topoplot_comparison
% Plots topoplots of EEG difference (error - correct) for each condition,
% over time windows 0.3-0.9s in 0.1s bins.
% Each condition has its own shared clim across its time windows.
% Input: all_data - cell array of condition structs (output of main script)

    n_conditions = length(all_data);
    topowins = [0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6; 0.6 0.7; 0.7 0.8; 0.8 0.9; 0.9 1.0];
    %topowins = [0.3 0.35; 0.35 0.4; 0.4 0.45; 0.45 0.5; 0.5 0.55; 0.55 0.6; 0.6 0.65; 0.65 0.7; 0.7 0.75];

    fig = figure();
    fig.Position = [100 100 1600 400 * n_conditions];

    for idx_c = 1:n_conditions

        % %topowins 
        % if idx_c == 1
        %     topowins = [0.15 0.25; 0.25 0.35; 0.35 0.45; 0.45 0.55; 0.55 0.65];
        % elseif idx_c == 2
        %     topowins = [0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6; 0.6 0.7];
        % else
        %     topowins = [0.4 0.5; 0.5 0.6; 0.6 0.7; 0.7 0.8; 0.8 0.9];
        % end

        if idx_c == 1
            topowins = [0.18 0.22; 0.28 0.32; 0.38 0.42; 0.46 0.50];
        elseif idx_c == 2
            topowins = [0.32 0.36; 0.43 0.46; 0.53 0.56; 0.62 0.65];
        else
            topowins = [0.54 0.58; 0.65 0.68; 0.72 0.76; 0.84 0.88];
        end

        n_wins = size(topowins, 1);

        d       = all_data{idx_c};
        setting = d.settings;
        cond    = d.cond;
        t       = setting.t;
        chanlocs = setting.settings.channels.chanlocs;

        T   = cat(3, d.means_e, d.means_c);
        n_s = d.n_subjects;

        % Logical indices
        n_e = false(n_s * 2, 1);  n_e(1:n_s) = true;
        n_c = ~n_e;

        % Grand average error and correct
        m_eeg_err = squeeze(mean(T(:, :, n_e), 3));
        m_eeg_cor = squeeze(mean(T(:, :, n_c), 3));

        % Difference maps per time window
        topo_data = zeros(n_wins, size(m_eeg_err, 2));
        for tId = 1:n_wins
            cstart = find(t >= topowins(tId, 1), 1, 'first');
            cstop  = find(t <= topowins(tId, 2), 1, 'last');
            topo_data(tId, :) = mean(m_eeg_err(cstart:cstop, :), 1) - ...
                                 mean(m_eeg_cor(cstart:cstop, :), 1);
        end

        % Clim shared across windows for this condition
        clim_val = max(abs(topo_data(:)));
        clim = [-clim_val, clim_val];
        %clim = [-1 1];
         
        if idx_c == 1
            title_cond = 'Pipeline 1 - Visual ErrP';
        elseif idx_c == 2
            title_cond = 'Pipeline 1 - Movement ErrP - Vision allowed';
        else
            title_cond = 'Pipeline 2 - Movement Errp - Blindfolded';
        end

        % Condition label
        cond_label = sprintf('%s | %s', title_cond, cond.piero_analysis);

        % Plot one topoplot per time window
        for tId = 1:n_wins
            subplot(n_conditions, n_wins, (idx_c - 1) * n_wins + tId);
            topoplot(topo_data(tId, :), chanlocs);
            caxis(clim);
            title([num2str(topowins(tId,1)) '-' num2str(topowins(tId,2)) 's']);
            colorbar;

            % Add condition label on the left of the first topoplot in each row
            if tId == 1
                ylabel(cond_label, 'FontSize', 10, 'FontWeight', 'bold');
            end
        end
    end

    sgtitle(['Topoplots: error - correct | filter: ' ...
             all_data{1}.settings.spatialfilter]);

    % ── Save ──
    setting_ref = all_data{1}.settings;
    folder = fullfile('presentations/imgs/grand_average', 'Comparison');
    folder = fullfile(folder, setting_ref.spatialfilter);
    if ~exist(folder, 'dir'); mkdir(folder); end

    filename = sprintf('topoplot_comparison_%s.png', setting_ref.spatialfilter);
    file = fullfile(folder, filename);

    exportgraphics(fig, file, 'Resolution', setting_ref.img_resolution);
    print(fig, fullfile(folder, strrep(filename, '.png', '.svg')), ...
          '-dsvg', '-vector');
end