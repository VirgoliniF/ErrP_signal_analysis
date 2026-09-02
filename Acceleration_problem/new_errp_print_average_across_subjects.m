function [] = new_errp_print_average_across_subjects(T, E, Ek, Ck, setting , vlc)

    % if strcmp(setting.data_owner, 'Francesca') && not(strcmp(setting.spatialfilter, 'none'))
    %     setting.y_li=[-5, 5];
    % end

    % Plotting
    t = setting.t;
    
    refchannelidx = setting.refchannelidx;
    sec_refchannelidx = setting.sec_refchannelidx;
    
    chanlocs = setting.settings.channels.chanlocs;
    
    m_eeg_err = squeeze(mean(T(:, :, Ek), 3));
    m_eeg_cor = squeeze(mean(T(:, :, Ck), 3));
    m_eog_err = squeeze(mean(E(:, :, Ek), 3));
    m_eog_cor = squeeze(mean(E(:, :, Ck), 3));
    
    std_eeg_err = squeeze(std(T(:, :, Ek),0, 3));
    std_eeg_cor = squeeze(std(T(:, :, Ck),0, 3));
    std_eog_err = squeeze(std(E(:, :, Ek),0, 3));
    std_eog_cor = squeeze(std(E(:, :, Ck),0, 3));

    difference = T(:, :, Ek) - T(:, :, Ck);
    
    %topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ]; 
    %topowins = [0.0 0.1; 0.11 0.17; 0.17 0.24; 0.24 0.37; 0.37 0.47; 0.5 0.6 ]; 

    topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ] + setting.delta_topo; 
    %topowins = [0.0 0.1; 0.1 0.18; 0.19 0.23; 0.28 0.33; 0.36 0.46; 0.5 0.56 ]; 



    % Figure
    fig = figure();%('Visible', 'off');
    nrows = 4;
    ncols = 12;
    
    eogtimeslot     = 4;
    eegtimeslot     = 7;
    eegerrimgslot   = [2 5];
    eegcorrimgslot  = [8 11];
    velxerrimgslot  = [3 6];
    velxcorrimgslot = [9 12];
    
    get_slot_layout = @(slot) sort(reshape(((slot-1).*6 + [1 2 3 4 5 6]'), 1, length(slot).*6));
    
    % % Secondary channel plot
    % subplot(nrows, ncols, get_slot_layout(1));
    % hold on;
    % for tId = 1:size(difference, 3)
    %   plot(t, difference(:, sec_refchannelidx, tId), '--k');
    % end
    % plot(t, squeeze(mean(difference(:, sec_refchannelidx, :), 3)), 'k', 'LineWidth', 2);
    % 
    % hold off;
    % grid on;
    % plot_vline(0, 'k');
    % plot_hline(0, 'k');
    % xlim([t(1) t(end)]);
    % 
    % ylim(setting.y_li);
    % 
    % title(['channel: ' char(setting.sec_refchannel) ' | difference']);
    
    % Primary channel plot - Difference
    subplot(nrows, ncols, get_slot_layout(1));
    hold on
    % for tId = 1:size(difference, 3)
    %   plot(t, difference(:, refchannelidx, tId), 'k');
    % end%folder = 'presentations/imgs/confusion_matrix/';
    %plot(t, squeeze(mean(difference(:, refchannelidx, :), 3)), 'k', 'LineWidth', 2);

    tmp_e = T(:, :, Ek);
    tmp_c = T(:, :, Ck);
    m_e = squeeze(mean(tmp_e(:, refchannelidx, :), 3));
    m_c = squeeze(mean(tmp_c(:, refchannelidx, :), 3));


    v  = nanmean(vlc,2)';
    vstd = nanstd(vlc')* 1.5;

    fill([t fliplr(t)], [v*10+vstd fliplr(v*10-vstd)] - v(1)*10, ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');


    plot(t,v*10 - v(1)*10, 'r', 'LineWidth', 2)

    plot(t, m_e - m_c, 'k', 'LineWidth', 2);


    
    % Add text near the arrow tip
    ax = gca;
    fig = gcf;
    
    % Get normalized figure coordinates    
    % Normalize
    
    % Draw arrow
    annotation('textarrow', [0.16 0+0.184], [0.91 0.89]);    
    text(-0.25, 1.94, 'Turn command', 'FontSize',10);

 
    hold off;
    grid on;
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    %ylim(setting.y_li);
    % if strcmp(setting.data_owner, 'Francesca') && not(strcmp(setting.spatialfilter, 'none'))
    %     ylim([-1.2 1.2])
    % else
    %     ylim([-2.2 2.2]);
    % end
    ylim([-5.0 5.0]);
    %xlim([t(240) t(512)])
    xlim([t(1) t(end)])

    xlabel("time [s]")
    ylabel("microvolt [\muV]")

    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    
    
    % VERTICAL COMMENT
    % for tmp = 1:length(diff_t)
    %     vline = diff_t(tmp);
    % 
    %     try
    %         if (vline > epoch(1))
    %             x_norm = pos(1) + (vline - epoch(1)) / (epoch(2) - epoch(1)) * pos(3);
    %             y_norm = pos(2) - 0.04; % Align annotation to the bottom of subplot
    % 
    %             plot_vline(vline, mask_colors(tmp,:));
    % 
    % 
    % 
    %             %annotation('textarrow', [x_norm x_norm], [y_norm y_norm+0.02], ...
    %             %'String', mask_name(tmp), 'FontSize', 12, 'Color', 'k');
    %         end
    %     end
    % end
    
    title(['channel: ' char(setting.refchannel) ' | Difference']);

    % -----------------------------------------------------------------------------
    % EOG - Error
    subplot(nrows, ncols, get_slot_layout(5));
    hold on
    tmp = E(:, :, Ek);
    for tId = 1:size(tmp, 3)
      plot(t, tmp(:, :, tId), '--k');
    end
    plot(t, squeeze(mean(tmp(:, :, :), 3)), 'k', 'LineWidth', 2);
    hold off;
    grid on;
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    ylim(setting.y_li);
    xlim([t(1) t(end)]);


    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    title(['channel: EOG| error ']);
    % EOG - Correct
    subplot(nrows, ncols, get_slot_layout(7));
    hold on
    tmp = E(:, :, Ck);
    for tId = 1:size(tmp, 3)
      plot(t, tmp(:, :, tId), '--k');
    end
    plot(t, squeeze(mean(tmp(:, :, :), 3)), 'k', 'LineWidth', 2);
    hold off;
    grid on;
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    ylim(setting.y_li);
    xlim([t(1) t(end)]);

    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    title(['channel: EOG | correct ']);
    ylabel("microvolt [\muV]")
    xlabel("time [s]")

    text(1,1,"Error")

    

    

    % -----------------------------------------------------------------------------
    % Topoplot error
    htop = [];
    for tId = 1:size(topowins, 1)
        subplot(nrows, ncols, 18 + tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        h = topoplot(mean(m_eeg_err(cstart:cstop, :), 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))]);
        htop = cat(1, htop, h);
        colorbar
    end
    
    % Topoplot correct
    for tId = 1:size(topowins, 1)
        subplot(nrows, ncols, 42 + tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        h = topoplot(mean(m_eeg_cor(cstart:cstop, :), 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))])
        htop = cat(1, htop, h);
        colorbar
    end

    

    % Topoplot e-c
    for tId = 1:size(topowins, 1)
        subplot(nrows, ncols, 12 + tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        tmp = m_eeg_err(cstart:cstop, :) - m_eeg_cor(cstart:cstop, :);
        h = topoplot(mean(tmp, 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))])
        htop = cat(1, htop, h);
    end

    errp_set_clim(htop);
    
    
    range_v = setting.range_v;

    % -----------------------------------------------------------------------------
    % Primary channel error trials
    subplot(nrows, ncols, get_slot_layout(2));
    hold on
    tmp = T(:, :, Ek);
    for tId = 1:size(tmp, 3)
      plot(t, tmp(:, refchannelidx, tId), '--k');
    end
    plot(t, squeeze(mean(tmp(:, refchannelidx, :), 3)), 'k', 'LineWidth', 2);
    hold off;
    grid on;
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    ylim(setting.y_li);
    %ylim([-2 2])
    %xlim([t(240) t(512)])
    xlim([t(1) t(end)])

    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    title(['channel: ' char(setting.refchannel) ' | error ']);

    % Primary channel correct trials
    subplot(nrows, ncols, get_slot_layout(6));
    hold on
    tmp = T(:, :, Ck);
    for tId = 1:size(tmp, 3)
      plot(t, tmp(:, refchannelidx, tId), '--k');
    end
    plot(t, squeeze(mean(tmp(:, refchannelidx, :), 3)), 'k', 'LineWidth', 2);
    hold off;
    grid on;
    
    plot_vline(0, 'k');
    plot_hline(0, 'k');
    ylim(setting.y_li);
    %ylim([-2 2])
    %xlim([t(240) t(512)])
    xlim([t(1) t(end)])
    
    ax = gca; % Current subplot
    pos = get(ax, 'Position'); % [left bottom width height] in normalized figure coordinates
    title(['channel: ' char(setting.refchannel) ' | correct ']);

    ylabel("microvolt [\muV]")
    xlabel("time [s]")

    text(1,1,"Correct")


    

    % % Imagesc error trials
    % subplot(nrows, ncols, get_slot_layout([2 4]));
    % imagesc(t, 1:sum(Ek), squeeze(T(:, refchannelidx, Ek))', range_v);
    % colorbar;
    % plot_vline(0, 'k');
    % set(gca, 'YDir', 'normal');
    % title(['channel: ' char(setting.refchannel) ' | error trials']);
    % xlabel('time [s]')
    % ylabel('# trial')
    
    % Imagesc correct trials
    % subplot(nrows, ncols, get_slot_layout([6 8]));
    % imagesc(t, 1:sum(Ck), squeeze(T(:, refchannelidx, Ck))', range_v);
    % colorbar;
    % plot_vline(0, 'k');
    % set(gca, 'YDir', 'normal');
    % title(['channel: ' char(setting.refchannel) ' | correct trials']);
    % xlabel('time [s]')
    % ylabel('# trial')
    % 
    sgtitle(['Across subjects | ' , setting.spatialfilter]);




    % -----------------------------------------------------------

    if strcmp(setting.error_modality, 'visual')
        folder = 'presentations/imgs/grand_average/visual';
    else
        folder = 'presentations/imgs/grand_average/vestibular';
    end 

    filter_type = setting.spatialfilter;
    folder = fullfile(folder, filter_type);   

    if ~exist(folder, 'dir'); mkdir(folder); end


    % Save the immages
    if ~exist(folder, 'dir'); mkdir(folder); end
    file = fullfile(folder, "plot_" + setting.includepat{1} + ".png");
    set(gca, 'LooseInset', get(gca,'TightInset'));  % removes extra padding
    %saveas(fig, fullfile(folder, "plot_" + setting.includepat{1} + ".png"));

    fig.Position = [100 100 1600 800];
    exportgraphics(fig, file, 'Resolution', setting.img_resolution);

    print(fig, 'my_vector_plot.svg', '-dsvg', '-vector');
    %close(fig)

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
