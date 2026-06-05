% =========================================================================
%  plot_experiment_bags_separate_figures.m
%
%  Same processing as the original script, but:
%
%    -> ONE FIGURE PER BAG FILE
%
%  For every .bag:
%
%    Figure 1:
%       Angular velocity
%       LEFT vs RIGHT movement subplots
%
%    Figure 2:
%       Angular acceleration
%       LEFT vs RIGHT movement subplots
%
% =========================================================================

clear;
clc;
close all;

%% ========================================================================
%  CONFIGURATION
% =========================================================================

% Wheelchair parameters
RADIUS   = 0.175;
LW       = 0.566;
N_ONEROT = 500;
N_SP_R   = 26;
N_BP_R   = 71.53;
N_SP_L   = 28;
N_BP_L   = 71.63;

% Savitzky-Golay filtering
SG_ORDER  = 3;
SG_FRAMES = 15;

% Time window around movement [s]
T_PRE  = 0.5;
T_POST = 1.0;

% Ignore bags by index if needed
BAG_SKIP = [];

% Velocity threshold to detect movement
CMD_THRESHOLD = 0.05;

% Plot settings
LW_MEAS = 1.3;
LW_FILT = 1.0;
LW_ENC  = 1.0;

BAG_COLORS = [
    0.22 0.48 0.72;
    0.84 0.19 0.15;
    0.13 0.62 0.46;
    0.73 0.35 0.09;
    0.50 0.23 0.56;
    0.93 0.69 0.13;
    0.30 0.68 0.29;
    0.60 0.60 0.60;
];

%% ========================================================================
%  SELECT BAG FOLDER
% =========================================================================

bag_dir = uigetdir(pwd, 'Select folder containing .bag files');

if isequal(bag_dir, 0)
    disp('Cancelled');
    return;
end

all_bags = dir(fullfile(bag_dir, '*.bag'));

if isempty(all_bags)
    error('No .bag files found');
end

keep     = setdiff(1:numel(all_bags), BAG_SKIP);
all_bags = all_bags(keep);

n_bags = numel(all_bags);

fprintf('Found %d bag files\n', n_bags);

%% ========================================================================
%  PROCESS EACH BAG SEPARATELY
% =========================================================================

for b = 1:n_bags

    bpath = fullfile(all_bags(b).folder, all_bags(b).name);

    fprintf('\n[%d/%d] Reading %s\n', ...
        b, n_bags, all_bags(b).name);

    try
        bag = rosbag(bpath);
    catch ME
        warning('Cannot open bag: %s', ME.message);
        continue;
    end

    bag_color = BAG_COLORS(...
        mod(b-1, size(BAG_COLORS,1)) + 1, :);

    %% ====================================================================
    %  CMD_VEL
    % ====================================================================

    try

        cv_sel  = select(bag, 'Topic', '/gui/cmd_vel');
        cv_msgs = readMessages(cv_sel, 'DataFormat', 'struct');
        cv_info = cv_sel.MessageList;

        cv_t = cv_info.Time(:);

        cv_wz = cellfun(@(m) double(m.Angular.Z), cv_msgs);

    catch
        warning('/gui/cmd_vel not found');
        continue;
    end

    %% ====================================================================
    %  ODOMETRY
    % ====================================================================

    odom = struct();

    topic_map = struct(...
        'wcias', '/wcias_controller/odom', ...
        'filt',  '/odometry/filtered');

    for fn = fieldnames(topic_map)'

        lbl = fn{1};

        try

            od_sel  = select(bag, 'Topic', topic_map.(lbl));
            od_msgs = readMessages(od_sel, 'DataFormat', 'struct');

            od_t = cellfun(@(m) ...
                double(m.Header.Stamp.Sec) + ...
                double(m.Header.Stamp.Nsec)*1e-9, od_msgs);

            od_wz = cellfun(@(m) ...
                double(m.Twist.Twist.Angular.Z), od_msgs);

            odom.(lbl).t  = od_t(:);
            odom.(lbl).wz = od_wz(:);

        catch

            odom.(lbl).t  = [];
            odom.(lbl).wz = [];

        end
    end

    %% ====================================================================
    %  ENCODERS
    % ====================================================================

    enc_t = [];
    enc_l = [];
    enc_r = [];

    try

        enc_sel  = select(bag, 'Topic', '/encoder_counter');
        enc_msgs = readMessages(enc_sel, 'DataFormat', 'struct');
        enc_info = enc_sel.MessageList;

        enc_t = enc_info.Time(:);

        enc_l = cellfun(@(m) double(m.Data(1)), enc_msgs);
        enc_r = cellfun(@(m) double(m.Data(2)), enc_msgs);

    catch
    end

    %% ====================================================================
    %  DETECT MOVEMENTS
    % ====================================================================

    moving = abs(cv_wz) > CMD_THRESHOLD;

    dmove = diff([0; moving; 0]);

    start_idx = find(dmove == 1);
    stop_idx  = find(dmove == -1) - 1;

    fprintf('Detected %d wheelchair movements\n', ...
        numel(start_idx));

    LEFT_STEPS  = {};
    RIGHT_STEPS = {};

    %% ====================================================================
    %  EXTRACT EACH MOVEMENT
    % ====================================================================

    for k = 1:numel(start_idx)

        i0 = start_idx(k);
        i1 = stop_idx(k);

        t0 = cv_t(i0);
        t1 = cv_t(i1);

        cmd_segment = cv_wz(i0:i1);
        cmd_mean    = mean(cmd_segment);

        %% Determine movement direction

        if cmd_mean > 0
            direction = 'LEFT';
        else
            direction = 'RIGHT';
        end

        %% Time window

        tw0 = t0 - T_PRE;
        tw1 = t1 + T_POST;

        step = struct();

        step.direction = direction;
        step.cmd       = cmd_mean;
        step.duration  = t1 - t0;

        %% ----------------------------------------------------------------
        %  ODOMETRY EXTRACTION
        % -----------------------------------------------------------------

        for fn = fieldnames(odom)'

            lbl = fn{1};

            if isempty(odom.(lbl).t)

                step.([lbl '_t'])   = [];
                step.([lbl '_wz'])  = [];
                step.([lbl '_acc']) = [];

                continue;
            end

            mask = odom.(lbl).t >= tw0 & ...
                   odom.(lbl).t <= tw1;

            tt = odom.(lbl).t(mask) - t0;
            ww = odom.(lbl).wz(mask);

            step.([lbl '_t'])   = tt;
            step.([lbl '_wz'])  = ww;
            step.([lbl '_acc']) = safeDerive(...
                tt, ww, SG_ORDER, SG_FRAMES);

        end

        %% ----------------------------------------------------------------
        %  ENCODER EXTRACTION
        % -----------------------------------------------------------------

        if ~isempty(enc_t)

            mask = enc_t >= tw0 & enc_t <= tw1;

            if sum(mask) > 4

                et = enc_t(mask) - t0;
                el = enc_l(mask);
                er = enc_r(mask);

                dt_e = diff(et);
                dt_e(dt_e < 1e-9) = 1e-9;

                dotR = diff(er) .* (pi/N_ONEROT) .* ...
                       (N_SP_R/N_BP_R) ./ dt_e;

                dotL = (-diff(el)) .* (pi/N_ONEROT) .* ...
                       (N_SP_L/N_BP_L) ./ dt_e;

                wz_e = (RADIUS/LW) .* (dotR - dotL);

                nf = makeOdd(...
                    min(SG_FRAMES, numel(wz_e)-1));

                if numel(wz_e) >= nf
                    wz_e = sgolayfilt(...
                        wz_e, SG_ORDER, nf);
                end

                step.enc_t   = et(1:end-1);
                step.enc_wz  = wz_e;

                step.enc_acc = safeDerive(...
                    et(1:end-1), ...
                    wz_e, ...
                    SG_ORDER, ...
                    SG_FRAMES);

            else

                step.enc_t   = [];
                step.enc_wz  = [];
                step.enc_acc = [];

            end

        else

            step.enc_t   = [];
            step.enc_wz  = [];
            step.enc_acc = [];

        end

        %% Save by direction

        if strcmp(direction, 'LEFT')
            LEFT_STEPS{end+1} = step;
        else
            RIGHT_STEPS{end+1} = step;
        end

    end

    fprintf('LEFT movements : %d\n', numel(LEFT_STEPS));
    fprintf('RIGHT movements: %d\n', numel(RIGHT_STEPS));

    %% ====================================================================
    %  FIGURE 1 - VELOCITY
    % ====================================================================

    figure(...
        'Name', ['Velocity - ' all_bags(b).name], ...
        'NumberTitle', 'off', ...
        'Position', [100 100 1400 550]);

    DIRS = {'LEFT', 'RIGHT'};
    DATA = {LEFT_STEPS, RIGHT_STEPS};

    for di = 1:2

        subplot(1,2,di);

        hold on;
        grid on;
        box on;

        title(DIRS{di});

        xlabel('t [s]');
        ylabel('Angular velocity [rad/s]');

        dd = DATA{di};

        for i = 1:numel(dd)

            s = dd{i};

            %% WCIAS

            if ~isempty(s.wcias_t)

                plot(...
                    s.wcias_t, ...
                    s.wcias_wz, ...
                    '-', ...
                    'Color', bag_color, ...
                    'LineWidth', LW_MEAS);

            end

            %% FILTERED ODOM

            if ~isempty(s.filt_t)

                plot(...
                    s.filt_t, ...
                    s.filt_wz, ...
                    '-.', ...
                    'Color', bag_color * 0.7, ...
                    'LineWidth', LW_FILT);

            end

        end

        xline(0, '--k');

    end

    sgtitle([...
        'Wheelchair Angular Velocity - ', ...
        strrep(all_bags(b).name, '_', '\_')]);

    %% ====================================================================
    %  FIGURE 2 - ACCELERATION
    % ====================================================================

    figure(...
        'Name', ['Acceleration - ' all_bags(b).name], ...
        'NumberTitle', 'off', ...
        'Position', [120 120 1400 550]);

    for di = 1:2

        subplot(1,2,di);

        hold on;
        grid on;
        box on;

        title(DIRS{di});

        xlabel('t [s]');
        ylabel('Angular acceleration [rad/s^2]');

        dd = DATA{di};

        for i = 1:numel(dd)

            s = dd{i};

            %% WCIAS acceleration

            if ~isempty(s.wcias_acc)

                plot(...
                    s.wcias_t, ...
                    s.wcias_acc, ...
                    '-', ...
                    'Color', bag_color, ...
                    'LineWidth', LW_MEAS);

            end

            %% Encoder acceleration

            if ~isempty(s.enc_acc)

                plot(...
                    s.enc_t, ...
                    s.enc_acc, ...
                    ':', ...
                    'Color', bag_color, ...
                    'LineWidth', LW_ENC);

            end

        end

        xline(0, '--k');
        yline(0, ':k');

    end

    sgtitle([...
        'Wheelchair Angular Acceleration - ', ...
        strrep(all_bags(b).name, '_', '\_')]);

end

fprintf('\nDone.\n');

%% ========================================================================
%  LOCAL FUNCTIONS
% =========================================================================

function acc = safeDerive(t, v, sg_order, sg_frames)

    acc = zeros(size(t));

    if numel(t) < 4
        return;
    end

    dt = diff(t(:));
    dt(dt < 1e-9) = 1e-9;

    dv = diff(v(:)) ./ dt;

    nf = makeOdd(min(sg_frames, numel(dv)-1));

    if numel(dv) >= nf && nf > sg_order
        dv = sgolayfilt(dv, sg_order, nf);
    end

    acc = [0; dv];

    if numel(acc) > numel(t)
        acc = acc(1:numel(t));
    elseif numel(acc) < numel(t)
        acc(end+1:numel(t)) = acc(end);
    end

end

function nf = makeOdd(n)

    nf = max(5, n);

    if mod(nf,2) == 0
        nf = nf - 1;
    end

end