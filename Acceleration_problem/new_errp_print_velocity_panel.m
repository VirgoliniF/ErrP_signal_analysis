function new_errp_print_velocity_panel(ax, t, T, velz, Ek, Ck, setting)
% NEW_ERRP_PRINT_VELOCITY_PANEL
%   Plots the ERP difference (error minus correct) at the reference channel
%   overlaid with the mean wheelchair angular velocity, matching the style
%   used in new_errp_print_average_across_subjects.
%
%   Parameters
%   ----------
%   ax      : target axes handle (from subplot)
%   t       : [1 x nsamples] time vector (seconds)
%   T       : [nsamples x nchannels x ntrials] EEG epoch array
%   velz    : [nsamples x ntrials] angular velocity array (rad/s or raw units)
%   Ek      : [ntrials x 1] logical – error trials
%   Ck      : [ntrials x 1] logical – correct trials
%   setting : settings struct (needs refchannelidx, refchannel, y_li,
%             saturation_vel)

    [~, refchannelidx] = ismember(upper(setting.refchannel), upper(setting.settings.channels.eeg));

    %% EEG difference (error minus correct) at reference channel
    m_e = squeeze(mean(T(:, refchannelidx, Ek), 3));   % [nsamples x 1]
    m_c = squeeze(mean(T(:, refchannelidx, Ck), 3));   % [nsamples x 1]
    diff_eeg = m_e - m_c;

    %% Velocity: mean and std across trials (error + correct pooled)
    vlc = abs([velz(:, Ek)  velz(:, Ck)]);             % [nsamples x (nE+nC)]

    v    = nanmean(vlc, 2)';                            % [1 x nsamples]
    vstd = nanstd(vlc') * 1.5;                         % [1 x nsamples]

    v_plot = v    - v(1);                               % baseline-correct at t(1)
    scale  = 10;                                        % µV per unit velocity

    %% Plot
    axes(ax);
    hold on;

    % Shaded std band for velocity
    fill([t  fliplr(t)], ...
         [v_plot*scale + vstd  fliplr(v_plot*scale - vstd)], ...
         'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

    % Mean velocity line
    plot(t, v_plot * scale, 'r', 'LineWidth', 2);

    % EEG difference line
    plot(t, diff_eeg, 'k', 'LineWidth', 2);

    hold off;
    grid on;

    plot_vline(0, 'k');
    plot_hline(0, 'k');

    xlim([t(1) t(end)]);
    ylim([-3.0 3.0]);

    xlabel('time [s]');
    ylabel('microvolt [\muV]');

    % Annotation: turn-command arrow (same position as across-subjects plot)
    annotation('textarrow', [0.16 0+0.184], [0.91 0.89]);
    text(-0.25, 1.94, 'Turn command', 'FontSize', 10);

    title(['channel: ' char(setting.refchannel) ' | Difference + Velocity']);
end
