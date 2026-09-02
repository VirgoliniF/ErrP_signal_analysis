function [] = new_errp_print_grand_average(T, E, Ek, Ck, setting)


    % Plotting
    t = setting.t;
    
    [~, refchannelidx]     = ismember(upper(setting.refchannel), upper(setting.settings.channels.eeg));
    [~, sec_refchannelidx] = ismember(upper(setting.sec_refchannel), upper(setting.settings.channels.eeg));
    
        
    chanlocs = setting.settings.channels.chanlocs;
    
    perc_err = 100*sum(Ek)./(sum(Ek) + sum(Ck));
    
    m_eeg_err = squeeze(mean(T(:, :, Ek), 3));

    fprintf('Num error trials (Ek): %d\n', sum(Ek));
    fprintf('NaN in m_eeg_err: %d\n', sum(sum(isnan(m_eeg_err))));
    m_eeg_cor = squeeze(mean(T(:, :, Ck), 3));
    m_eog_err = squeeze(mean(E(:, :, Ek), 3));
    m_eog_cor = squeeze(mean(E(:, :, Ck), 3));
    
    std_eeg_err = squeeze(std(T(:, :, Ek),0, 3));
    std_eeg_cor = squeeze(std(T(:, :, Ck),0, 3));
    std_eog_err = squeeze(std(E(:, :, Ek),0, 3));
    std_eog_cor = squeeze(std(E(:, :, Ck),0, 3));
    
    topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ] + setting.delta_topo; 
    
    % Figure
    fig = figure('Visible', 'off');
    %fig = figure;

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
    plot_errp_s(t, m_eeg_cor(:, sec_refchannelidx), m_eeg_err(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx), std_eeg_cor(:, sec_refchannelidx));
    hold off;
    grid on;
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    xlim([t(1) t(end)]);
    %xlim([t(204) t(512)]);
    %ylim(setting.y_li);
    %ylim([-3 3])

    title(['channel: ' char(setting.sec_refchannel) ' | error vs. correct']);
    
    % EEG signal]; 
    subplot(nrows, ncols, get_slot_layout(3));
    hold on
    % Baseline
    %plot(t, m_t_baseline(:,refchannelidx), '--k')
    plot_errp_s(t, m_eeg_cor(:, refchannelidx), m_eeg_err(:, refchannelidx), std_eeg_cor(:, refchannelidx), std_eeg_err(:, refchannelidx));
    %plot_errp(t, m_eeg_cor(:, refchannelidx), m_eeg_err(:, refchannelidx));
    
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    %xlim([t(204) t(512)]);
    %ylim(setting.y_li);
    %ylim([-3 3])
    
    %if create_classifier == true
    %    plot_vline(classifier_epoch(1), '--k');
    %    plot_vline(classifier_epoch(2), '--k');
    %end
    
    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    

    
    title(['channel: ' char(setting.refchannel) ' | error vs. correct']);
    
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
    
    range_v = setting.range_v;
    
    % Imagesc error trials
    subplot(nrows, ncols, get_slot_layout([2 4]));
    imagesc(t, 1:sum(Ek), squeeze(T(:, refchannelidx, Ek))', range_v);
    colorbar;
    plot_vline(0, 'k');
    set(gca, 'YDir', 'normal');
    title(['channel: ' char(setting.refchannel) ' | error trials']);
    xlabel('time [s]')
    ylabel('# trial')
    
    % Imagesc correct trials
    subplot(nrows, ncols, get_slot_layout([6 8]));
    imagesc(t, 1:sum(Ck), squeeze(T(:, refchannelidx, Ck))', range_v);
    colorbar;
    plot_vline(0, 'k');
    set(gca, 'YDir', 'normal');
    title(['channel: ' char(setting.refchannel) ' | correct trials']);
    xlabel('time [s]')
    ylabel('# trial')
    
        
    sgtitle(setting.title);
    
    if strcmp(setting.error_modality, 'visual')
        folder = 'presentations/imgs/grand_average/visual';
    else
        folder = 'presentations/imgs/grand_average/vestibular';
    end
    filter_type = setting.spatialfilter;
    folder = fullfile(folder, filter_type);         


    % Save the immagessetting.check_movement_cue == true
    if ~exist(folder, 'dir'); mkdir(folder); end
    file = fullfile(folder, "plot_" + setting.includepat{1} + ".png");
    set(gca, 'LooseInset', get(gca,'TightInset'));  % removes extra padding
    %saveas(fig, fullfile(folder, "plot_" + setting.includepat{1} + ".png"));

    fig.Position = [100 100 1600 800];
    exportgraphics(fig, file, 'Resolution', setting.img_resolution);
    close(fig)

end

function x= find_over(v, value)

    x = ones(size(v, 2), 1);

    for trId = 1:size(v, 2)
        tmp = find(v(:, trId) >= value, 1, 'first');
        if(isempty(tmp) == false)
            x(trId) = tmp;
        end
    end

end