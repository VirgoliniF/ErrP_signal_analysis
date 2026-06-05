function new_errp_print_frequency(tf_neg, tf_neu, tf_diff, frex, setting)
    
    fig =figure('Visible', 'off'); 

    subplot(1, 3, 1);
    contourf(setting.t(80:end-80),frex,tf_neg(:,(80:end-80)))
    title(['tf of negative valence trials (db conversion']);
    %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
    %set(gca,'clim',[0 400],'ydir','normal')
    xlabel('Time [s]', 'FontSize',10);
    ylabel('Frequency [Hz]', 'FontSize',10);
    colorbar
    clim(setting.range_f);

    subplot(1, 3, 2);
    contourf(setting.t(80:end-80),frex,tf_neu(:,(80:end-80)))
    title(['tf of neutral valence trials (db conversion)']);
    %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
    %set(gca,'clim',[0 400],'ydir','normal')
    xlabel('Time [s]', 'FontSize',10);
    ylabel('Frequency [Hz]', 'FontSize',10);
    colorbar
    clim(setting.range_f);


    subplot(1, 3, 3);
    contourf(setting.t(80:end-80),frex,tf_diff(:,(80:end-80)))
    title(['tf of difference valence trials (db conversion)']);
    %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
    %set(gca,'clim',[0 400],'ydir','normal')
    xlabel('Time [s]', 'FontSize',10);
    ylabel('Frequency [Hz]', 'FontSize',10);
    colorbar
    clim(setting.range_f);

    % sgtitle([setting.title]);


    % -----------------------------------------------------------
    if strcmp(setting.error_modality, 'visual')
        folder = 'presentations/imgs/freq/visual';
    else
        folder = 'presentations/imgs/freq/vestibular';
    end
    if ~exist(folder, 'dir'); mkdir(folder); end

    % Save the immages
    if ~exist(folder, 'dir'); mkdir(folder); end
    file = fullfile(folder, "plot_" + setting.includepat{1} + ".png");
    set(gca, 'LooseInset', get(gca,'TightInset'));  % removes extra padding
    %saveas(fig, fullfile(folder, "plot_" + setting.includepat{1} + ".png"));

    fig.Position = [100 100 1600 400];
    exportgraphics(fig, file, 'Resolution', setting.img_resolution);
    close(fig)


end

