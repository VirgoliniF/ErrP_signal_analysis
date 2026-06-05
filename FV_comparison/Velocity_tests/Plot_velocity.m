clc; clear; close all;

%% ── 1. Select bag folder ────────────────────────────────────────────────
bag_dir = uigetdir(pwd, 'Select folder containing .bag files');
if isequal(bag_dir, 0)
    disp('Cancelled.'); return
end

bag_files = dir(fullfile(bag_dir, '*.bag'));
if isempty(bag_files)
    error('No .bag files found in: %s', bag_dir);
end
fprintf('Found %d bag file(s) in %s\n\n', numel(bag_files), bag_dir);

%% ── PARAMETRI ──────────────────────────────────────────────────────────
topic_cmd  = '/cmd_vel';
topic_odom = '/odometry/filtered';
time_window = 3; % secondi

%% ── Storage per cumulativi ──────────────────────────────────────────────
all_cmd = {};
all_odom = {};
all_acc_cmd = {};
all_acc_odom = {};

%% ── 3. Process each bag ─────────────────────────────────────────────────
for b = 1:numel(bag_files)

    bag_path = fullfile(bag_files(b).folder, bag_files(b).name);
    fprintf('==========================================================\n');
    fprintf('Processing: %s\n', bag_files(b).name);

    bag = rosbag(bag_path);

    %% --- CMD_VEL ---
    bag_cmd = select(bag, 'Topic', topic_cmd);
    msgs_cmd = readMessages(bag_cmd, 'DataFormat', 'struct');

    t_cmd = bag_cmd.MessageList.Time;
    t_cmd = t_cmd - t_cmd(1);

    idx_cmd = t_cmd <= time_window;
    t_cmd = t_cmd(idx_cmd);
    msgs_cmd = msgs_cmd(idx_cmd);

    wz_cmd = zeros(length(msgs_cmd),1);
    for i = 1:length(msgs_cmd)
        wz_cmd(i) = msgs_cmd{i}.Angular.Z;
    end

    %% --- ODOM ---
    bag_odom = select(bag, 'Topic', topic_odom);
    msgs_odom = readMessages(bag_odom, 'DataFormat', 'struct');

    t_odom = bag_odom.MessageList.Time;
    t_odom = t_odom - t_odom(1);

    idx_odom = t_odom <= time_window;
    t_odom = t_odom(idx_odom);
    msgs_odom = msgs_odom(idx_odom);

    wz_odom = zeros(length(msgs_odom),1);
    for i = 1:length(msgs_odom)
        wz_odom(i) = msgs_odom{i}.Twist.Twist.Angular.Z;
    end

    %% --- Tempo comune ---
    t_common = linspace(0, time_window, 300);

    wz_cmd_i  = interp1(t_cmd,  wz_cmd,  t_common, 'linear', 'extrap');
    wz_odom_i = interp1(t_odom, wz_odom, t_common, 'linear', 'extrap');

    %% --- Accelerazione ---
    dt = diff(t_common);
    acc_cmd  = diff(wz_cmd_i)  ./ dt;
    acc_odom = diff(wz_odom_i) ./ dt;
    t_acc = t_common(1:end-1);

    %% === FIGURA VELOCITÀ ===
    figure('Name', ['Vel_', bag_files(b).name]);

    subplot(3,1,1)
    plot(t_common, wz_cmd_i, 'LineWidth', 1.5); grid on;
    ylabel('\omega_z cmd')

    subplot(3,1,2)
    plot(t_common, wz_odom_i, 'LineWidth', 1.5); grid on;
    ylabel('\omega_z odom')

    subplot(3,1,3)
    plot(t_common, wz_cmd_i, '--'); hold on;
    plot(t_common, wz_odom_i, 'LineWidth', 1.5);
    grid on;
    ylabel('confronto')
    legend('cmd','odom')
    xlabel('Tempo [s]')

    sgtitle(['Velocità angolare - ', bag_files(b).name])

    %% === FIGURA ACCELERAZIONE ===
    figure('Name', ['Acc_', bag_files(b).name]);

    subplot(3,1,1)
    plot(t_acc, acc_cmd, 'LineWidth', 1.5); grid on;
    ylabel('\alpha cmd')

    subplot(3,1,2)
    plot(t_acc, acc_odom, 'LineWidth', 1.5); grid on;
    ylabel('\alpha odom')

    subplot(3,1,3)
    plot(t_acc, acc_cmd, '--'); hold on;
    plot(t_acc, acc_odom, 'LineWidth', 1.5);
    grid on;
    ylabel('confronto')
    legend('cmd','odom')
    xlabel('Tempo [s]')

    sgtitle(['Accelerazione angolare - ', bag_files(b).name])

    %% --- Salvataggio per cumulativi ---
    all_cmd{b}      = {t_common, wz_cmd_i};
    all_odom{b}     = {t_common, wz_odom_i};
    all_acc_cmd{b}  = {t_acc, acc_cmd};
    all_acc_odom{b} = {t_acc, acc_odom};

end

%% ── 4. FIGURE CUMULATIVE ───────────────────────────────────────────────

%% Velocità
figure;
sgtitle('Velocità angolare - tutte le bag')

subplot(3,1,1); hold on; grid on; title('cmd')
for k = 1:length(all_cmd)
    plot(all_cmd{k}{1}, all_cmd{k}{2});
end

subplot(3,1,2); hold on; grid on; title('odom')
for k = 1:length(all_odom)
    plot(all_odom{k}{1}, all_odom{k}{2});
end

subplot(3,1,3); hold on; grid on; title('confronto')
for k = 1:length(all_cmd)
    plot(all_cmd{k}{1}, all_cmd{k}{2}, '--');
    plot(all_odom{k}{1}, all_odom{k}{2});
end
xlabel('Tempo [s]')

%% Accelerazione
figure;
sgtitle('Accelerazione angolare - tutte le bag')

subplot(3,1,1); hold on; grid on; title('cmd')
for k = 1:length(all_acc_cmd)
    plot(all_acc_cmd{k}{1}, all_acc_cmd{k}{2});
end

subplot(3,1,2); hold on; grid on; title('odom')
for k = 1:length(all_acc_odom)
    plot(all_acc_odom{k}{1}, all_acc_odom{k}{2});
end

subplot(3,1,3); hold on; grid on; title('confronto')
for k = 1:length(all_acc_cmd)
    plot(all_acc_cmd{k}{1}, all_acc_cmd{k}{2}, '--');
    plot(all_acc_odom{k}{1}, all_acc_odom{k}{2});
end
xlabel('Tempo [s]')