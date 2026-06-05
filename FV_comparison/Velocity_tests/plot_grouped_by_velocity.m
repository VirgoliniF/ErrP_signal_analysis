% =========================================================================
%  plot_grouped_by_velocity.m
%
%  Reads all .bag files in a selected folder (VelocityTest or
%  AccelerationTest bags) and produces, for each unique commanded
%  velocity value found across all bags:
%
%    Fig A — Velocity profile
%      LEFT subplot | RIGHT subplot
%      One colored line per bag that contains that command.
%      Horizontal dashed line = commanded velocity (target).
%
%    Fig B — Acceleration profile
%      Same subplot structure.
%      One colored line per bag (derived from ODOM_WCIAS).
%      Dotted line = encoder raw acceleration.
%
%  Grouping key: |angular.z| of /gui/cmd_vel, rounded to 2 decimal places.
%  Bags with different numbers of steps are handled automatically:
%  a bag simply contributes no line to a velocity group it does not contain.
%
%  Topic letti:
%    /gui/cmd_vel               [geometry_msgs/Twist]
%    /wcias_controller/odom     [nav_msgs/Odometry]
%    /odometry/filtered         [nav_msgs/Odometry]
%    /encoder_counter           [std_msgs/Int32MultiArray]
%    /events/bus                [rosneuro_msgs/NeuroEvent]
%
%  Richiede: ROS Toolbox, Signal Processing Toolbox
%            MATLAB R2021b+
% =========================================================================

clear; clc; close all;

%% ── 0. CONFIGURAZIONE ────────────────────────────────────────────────────

% Parametri fisici wheelchair
RADIUS   = 0.175;
LW       = 0.566;
N_ONEROT = 500;
N_SP_R   = 26;    N_BP_R = 71.53;
N_SP_L   = 28;    N_BP_L = 71.63;

% Savitzky-Golay
SG_ORDER  = 3;
SG_FRAMES = 15;

% Margini temporali attorno allo step [s]
T_PRE  = 0.3;
T_POST = 0.8;

% Bag da escludere (indici nella lista ordinata, es. [2])
BAG_SKIP = [4,5,6];

% Costanti evento (VelocityTest usa VT_CLOSE_MASK=32768)
VT_CLOSE_MASK = 32768;
AT_CLOSE_MASK = 1000;
VT_INIT       = 1;
VT_END        = 2;

% Colori per le bag (si ciclano se le bag sono più dei colori)
BAG_COLORS = [
    0.22  0.48  0.72;   % blu
    0.84  0.19  0.15;   % rosso
    0.13  0.62  0.46;   % verde
    0.73  0.35  0.09;   % arancio
    0.50  0.23  0.56;   % viola
    0.93  0.69  0.13;   % giallo
    0.30  0.68  0.29;   % verde chiaro
    0.60  0.60  0.60;   % grigio
];

LW_TARGET = 1.6;
LW_MEAS   = 1.5;
LW_FILT   = 1.2;
LW_ENC    = 1.1;

%% ── 1. Selezione cartella ────────────────────────────────────────────────

bag_dir = uigetdir(pwd, 'Seleziona la cartella con i file .bag');
if isequal(bag_dir, 0), disp('Annullato.'); return; end

all_bags = dir(fullfile(bag_dir, '*.bag'));
if isempty(all_bags)
    error('Nessun file .bag trovato in: %s', bag_dir);
end

keep     = setdiff(1:numel(all_bags), BAG_SKIP);
all_bags = all_bags(keep);
n_bags   = numel(all_bags);
fprintf('Trovate %d bag.\n\n', n_bags);

%% ── 2. Lettura di tutte le bag ───────────────────────────────────────────
% Struttura: bag_data(b).steps = array di struct, uno per step
%            bag_data(b).label = nome breve della bag
%            bag_data(b).color = colore per i plot

bag_data = struct([]);

for b = 1:n_bags

    bpath = fullfile(all_bags(b).folder, all_bags(b).name);
    bname = all_bags(b).name;
    fprintf('[%d/%d] Leggo: %s\n', b, n_bags, bname);

    try
        bag = rosbag(bpath);
    catch ME
        warning('  Impossibile aprire: %s', ME.message); continue
    end

    % ── Tipo bag ─────────────────────────────────────────────────────────
    try
        ev_sel  = select(bag, 'Topic', '/events/bus');
        ev_msgs = readMessages(ev_sel, 'DataFormat', 'struct');
        ev_t    = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                               double(m.Header.Stamp.Nsec)*1e-9, ev_msgs);
        ev_code = cellfun(@(m) double(m.Event), ev_msgs);
    catch
        warning('  /events/bus non trovato — skip.'); continue
    end

    if max(ev_code) >= 32768
        close_mask = VT_CLOSE_MASK;
    else
        close_mask = AT_CLOSE_MASK;
    end

    % ── cmd_vel ───────────────────────────────────────────────────────────
    try
        cv_sel  = select(bag, 'Topic', '/gui/cmd_vel');
        cv_msgs = readMessages(cv_sel, 'DataFormat', 'struct');
        cv_info = cv_sel.MessageList;
        cv_t    = cv_info.Time(:);
        cv_angz = cellfun(@(m) double(m.Angular.Z), cv_msgs);
    catch
        warning('  /gui/cmd_vel non trovato — skip.'); continue
    end

    % ── Odometrie ─────────────────────────────────────────────────────────
    odom = struct();
    tmap = struct('wcias','/wcias_controller/odom', ...
                  'filt', '/odometry/filtered');
    for fn = fieldnames(tmap)'
        lbl = fn{1};
        try
            od_sel  = select(bag, 'Topic', tmap.(lbl));
            od_msgs = readMessages(od_sel, 'DataFormat', 'struct');
            od_t    = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                                   double(m.Header.Stamp.Nsec)*1e-9, od_msgs);
            od_wz   = cellfun(@(m) double(m.Twist.Twist.Angular.Z), od_msgs);
            odom.(lbl).t  = od_t(:);
            odom.(lbl).wz = od_wz(:);
        catch
            odom.(lbl).t  = []; odom.(lbl).wz = [];
        end
    end

    % ── Encoder grezzo ────────────────────────────────────────────────────
    enc_t = []; enc_l = []; enc_r = [];
    try
        enc_sel  = select(bag, 'Topic', '/encoder_counter');
        enc_msgs = readMessages(enc_sel, 'DataFormat', 'struct');
        enc_info = enc_sel.MessageList;
        enc_t    = enc_info.Time(:);
        enc_l    = cellfun(@(m) double(m.Data(1)), enc_msgs);
        enc_r    = cellfun(@(m) double(m.Data(2)), enc_msgs);
    catch
    end

    % ── Identifica step ───────────────────────────────────────────────────
    smask     = ev_code ~= VT_INIT & ev_code ~= VT_END & ...
                ev_code  < close_mask;
    start_ids = find(smask);

    if isempty(start_ids)
        warning('  Nessuno step trovato — skip.'); continue
    end

    % ── Estrai dati per ogni step ─────────────────────────────────────────
    steps = struct([]);
    for si = 1:numel(start_ids)
        ii    = start_ids(si);
        scode = ev_code(ii);
        stime = ev_t(ii);

        stop_m = ev_code == (scode + close_mask) & ev_t > stime;
        etime  = stime + 15;
        if any(stop_m), etime = ev_t(find(stop_m,1)); end

        [dir_str, stype] = decodeEventCode(scode);

        % Commanded velocity: cmd_vel message closest to event START
        [~, ci]  = min(abs(cv_t - stime));
        cmd_val  = cv_angz(ci);          % signed
        cmd_abs  = round(abs(cmd_val), 2);  % grouping key

        step.dir       = dir_str;
        step.type      = stype;
        step.code      = scode;
        step.idx       = mod(scode, 100);
        step.cmd_val   = cmd_val;     % signed commanded velocity
        step.cmd_abs   = cmd_abs;     % grouping key (|cmd|, 2dp)
        step.duration  = etime - stime;

        tw0 = stime - T_PRE;
        tw1 = etime + T_POST;

        % Odometrie nella finestra
        for fn = fieldnames(odom)'
            lbl = fn{1};
            if ~isempty(odom.(lbl).t)
                m   = odom.(lbl).t >= tw0 & odom.(lbl).t <= tw1;
                t_w = odom.(lbl).t(m) - stime;
                w_w = odom.(lbl).wz(m);
                step.([lbl '_t'])   = t_w;
                step.([lbl '_wz'])  = w_w;
                step.([lbl '_acc']) = safeDerive(t_w, w_w, SG_ORDER, SG_FRAMES);
            else
                step.([lbl '_t'])   = [];
                step.([lbl '_wz'])  = [];
                step.([lbl '_acc']) = [];
            end
        end

        % Encoder grezzo
        if ~isempty(enc_t)
            m = enc_t >= tw0 & enc_t <= tw1;
            if sum(m) > 4
                et   = enc_t(m) - stime;
                el   = enc_l(m); er = enc_r(m);
                dt_e = diff(et); dt_e(dt_e<1e-9) = 1e-9;
                dotR = diff(er) .*(pi/N_ONEROT).*(N_SP_R/N_BP_R)./dt_e;
                dotL = (-diff(el)).*(pi/N_ONEROT).*(N_SP_L/N_BP_L)./dt_e;
                wz_e = (RADIUS/LW).*(dotR - dotL);
                nf   = makeOdd(min(SG_FRAMES, numel(wz_e)-1));
                if numel(wz_e) >= nf
                    wz_e = sgolayfilt(wz_e, SG_ORDER, nf);
                end
                step.enc_t   = et(1:end-1);
                step.enc_wz  = wz_e;
                step.enc_acc = safeDerive(et(1:end-1), wz_e, SG_ORDER, SG_FRAMES);
            else
                step.enc_t=[]; step.enc_wz=[]; step.enc_acc=[];
            end
        else
            step.enc_t=[]; step.enc_wz=[]; step.enc_acc=[];
        end

        if isempty(steps), steps = step;
        else,              steps(end+1) = step; end %#ok<AGROW>
    end

    fprintf('  %d step (velocità: %s rad/s)\n', numel(steps), ...
            strjoin(arrayfun(@(s) sprintf('%.2f',s.cmd_abs), ...
                    steps(strcmp({steps.dir},'LEFT')),'UniformOutput',false),', '));

    % Short label: use timestamp part of filename
    [~, fname] = fileparts(bname);
    parts = strsplit(fname,'_');
    if numel(parts) >= 3
        short_lbl = strjoin(parts(end-1:end),'_');   % e.g. "11-18-10"
    else
        short_lbl = fname;
    end

    bag_data(end+1).steps = steps; %#ok<AGROW>
    bag_data(end).label   = short_lbl;
    bag_data(end).color   = BAG_COLORS(mod(b-1,size(BAG_COLORS,1))+1,:);
    bag_data(end).bagname = bname;

    clear bag steps odom enc_t enc_l enc_r cv_t cv_angz;
end

if isempty(bag_data)
    error('Nessuna bag letta correttamente.');
end

n_bags_read = numel(bag_data);
fprintf('\nBag lette: %d\n', n_bags_read);

%% ── 3. Raccolta di tutti i valori di velocità unici ─────────────────────

all_cmd_abs = [];
for b = 1:n_bags_read
    ss = bag_data(b).steps;
    if isempty(ss), continue; end
    all_cmd_abs = [all_cmd_abs, [ss.cmd_abs]]; %#ok<AGROW>
end
unique_cmds = unique(round(all_cmd_abs,2));
n_cmds = numel(unique_cmds);

fprintf('Velocità uniche trovate: %s rad/s\n\n', ...
        strjoin(arrayfun(@(v) sprintf('%.2f',v), unique_cmds,'UniformOutput',false),', '));

%% ── 4. Una coppia di figure per ogni velocità ───────────────────────────

directions = {'LEFT','RIGHT'};

for ci = 1:n_cmds
    cmd_v = unique_cmds(ci);

    % ── Raccogli step di questa velocità da tutte le bag ──────────────────
    % group.(dir){b} = step struct (o [] se la bag non ha quel comando)
    group = struct();
    for di = 1:numel(directions)
        group.(directions{di}) = cell(1, n_bags_read);
    end

    for b = 1:n_bags_read
        ss = bag_data(b).steps;
        if isempty(ss), continue; end
        for di = 1:numel(directions)
            dir = directions{di};
            mask = abs([ss.cmd_abs] - cmd_v) < 0.005 & ...
                   strcmp({ss.dir}, dir) & ...
                   strcmp({ss.type},'ROTATION');
            found = ss(mask);
            if ~isempty(found)
                group.(dir){b} = found(1);   % prendi il primo match
            end
        end
    end

    % Controlla che almeno una bag abbia dati per questa velocità
    has_data = false;
    for di = 1:numel(directions)
        for b = 1:n_bags_read
            if ~isempty(group.(directions{di}){b}), has_data=true; break; end
        end
        if has_data, break; end
    end
    if ~has_data, continue; end

    % ── FIGURA A: VELOCITÀ ────────────────────────────────────────────────
    fig_v = figure('Name', sprintf('VEL | cmd=%.2f rad/s', cmd_v), ...
                   'NumberTitle','off', ...
                   'Position', [40+ci*20, 60+ci*20, 1200, 460]);

    ax_v = gobjects(1,2);
    for di = 1:numel(directions)
        dir   = directions{di};
        ax    = subplot(1,2,di);
        ax_v(di) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        set(ax,'FontSize',10);
        title(ax, dir,'FontWeight','normal');
        xlabel(ax,'t [s]');
        ylabel(ax,'wz [rad/s]');

        % Target line (horizontal, same for all bags)
        target_sign = 1;
        for b = 1:n_bags_read
            s = group.(dir){b};
            if ~isempty(s), target_sign = sign(s.cmd_val); break; end
        end
        yval = target_sign * cmd_v;

        % Determine x range from all steps in this group
        t_min = -T_PRE; t_max = 0;
        for b = 1:n_bags_read
            s = group.(dir){b};
            if ~isempty(s)
                t_max = max(t_max, s.duration + T_POST);
            end
        end

        % Draw target as horizontal dashed black line
        plot(ax, [t_min, t_max], [yval, yval], '--k', ...
             'LineWidth', LW_TARGET, ...
             'DisplayName', sprintf('target = %.2f rad/s', yval));

        % One line per bag
        for b = 1:n_bags_read
            s   = group.(dir){b};
            if isempty(s), continue; end
            clr = bag_data(b).color;
            %lbl = bag_data(b).label;
            lbl = sprintf('Bag %d', b);

            % ODOM_WCIAS
            if ~isempty(s.wcias_t)
                plot(ax, s.wcias_t, s.wcias_wz, '-', ...
                     'Color', clr, 'LineWidth', LW_MEAS, ...
                     'DisplayName', sprintf('%s  wcias', lbl));
            end

            % ODOM_FILT
            if ~isempty(s.filt_t)
                plot(ax, s.filt_t, s.filt_wz, '-.', ...
                     'Color', clr*0.7, 'LineWidth', LW_FILT, ...
                     'DisplayName', sprintf('%s  filt', lbl));
            end
        end

        % Vertical markers (use duration of first available step)
        dur = 0;
        for b = 1:n_bags_read
            s = group.(dir){b};
            if ~isempty(s), dur = s.duration; break; end
        end
        xline(ax, 0,   '--','Color',[.6 .6 .6],'LineWidth',0.8,'HandleVisibility','off');
        xline(ax, dur, ':','Color',[.6 .6 .6],'LineWidth',0.8,'HandleVisibility','off');

        legend(ax,'show','Location','best','FontSize',8);
    end

    linkaxes(ax_v,'y');
    sgtitle(fig_v, sprintf('Velocità — cmd = %.2f rad/s', cmd_v), ...
            'FontSize',12,'FontWeight','bold');
    addLegendNote(fig_v, ...
        'target (--k)   wcias (——)   filt (-·-, colore scuro)   |   vert: START(--)  STOP(:)');

    % ── FIGURA B: ACCELERAZIONE ────────────────────────────────────────────
    fig_a = figure('Name', sprintf('ACC | cmd=%.2f rad/s', cmd_v), ...
                   'NumberTitle','off', ...
                   'Position', [60+ci*20, 80+ci*20, 1200, 460]);

    ax_a = gobjects(1,2);
    for di = 1:numel(directions)
        dir = directions{di};
        ax  = subplot(1,2,di);
        ax_a(di) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        set(ax,'FontSize',10);
        title(ax, dir,'FontWeight','normal');
        xlabel(ax,'t [s]');
        ylabel(ax,'az [rad/s²]');

        t_min = -T_PRE; t_max = 0;
        for b = 1:n_bags_read
            s = group.(dir){b};
            if ~isempty(s), t_max = max(t_max, s.duration + T_POST); end
        end

        % Zero reference line
        plot(ax, [t_min, t_max], [0, 0], '--k', ...
             'LineWidth', 0.8, 'HandleVisibility','off');

        for b = 1:n_bags_read
            s   = group.(dir){b};
            if isempty(s), continue; end
            clr = bag_data(b).color;
            %lbl = bag_data(b).label;
            lbl = sprintf('Bag %d', b);

            % ODOM_WCIAS accel
            if ~isempty(s.wcias_acc)
                plot(ax, s.wcias_t, s.wcias_acc, '-', ...
                     'Color', clr, 'LineWidth', LW_MEAS, ...
                     'DisplayName', sprintf('%s  wcias', lbl));
            end

            % Encoder raw accel
            if ~isempty(s.enc_acc)
                plot(ax, s.enc_t, s.enc_acc, ':', ...
                     'Color', clr, 'LineWidth', LW_ENC, ...
                     'DisplayName', sprintf('%s  enc', lbl));
            end
        end

        dur = 0;
        for b = 1:n_bags_read
            s = group.(dir){b};
            if ~isempty(s), dur = s.duration; break; end
        end
        xline(ax, 0,   '--','Color',[.6 .6 .6],'LineWidth',0.8,'HandleVisibility','off');
        xline(ax, dur, ':','Color',[.6 .6 .6],'LineWidth',0.8,'HandleVisibility','off');

        legend(ax,'show','Location','best','FontSize',8);
    end

    linkaxes(ax_a,'y');
    sgtitle(fig_a, sprintf('Accelerazione — cmd = %.2f rad/s', cmd_v), ...
            'FontSize',12,'FontWeight','bold');
    addLegendNote(fig_a, ...
        'wcias accel (——)   encoder raw (···)   |   vert: START(--)  STOP(:)');

    drawnow;
end

fprintf('\nDone — %d figure per velocità (x2 vel+acc) = %d figure totali.\n', ...
        n_cmds, n_cmds*2);

%% ── Funzioni locali ──────────────────────────────────────────────────────

function [direction, step_type] = decodeEventCode(code)
    cat = code - mod(code,100);
    switch cat
        case 100,  direction='LEFT';     step_type='ROTATION';
        case 200,  direction='RIGHT';    step_type='ROTATION';
        case 300,  direction='FORWARD';  step_type='LINEAR';
        case 400,  direction='BACKWARD'; step_type='LINEAR';
        otherwise, direction='UNKNOWN';  step_type='UNKNOWN';
    end
end

function acc = safeDerive(t, v, sg_order, sg_frames)
    acc = zeros(size(t));
    if numel(t) < 4, return; end
    dt = diff(t(:)); dt(dt<1e-9) = 1e-9;
    dv = diff(v(:))./dt;
    nf = makeOdd(min(sg_frames, numel(dv)-1));
    if numel(dv) >= nf && nf > sg_order
        dv = sgolayfilt(dv, sg_order, nf);
    end
    acc = [0; dv];
    if numel(acc) > numel(t),     acc = acc(1:numel(t));
    elseif numel(acc) < numel(t), acc(end+1:numel(t)) = acc(end); end
end

function nf = makeOdd(n)
    nf = max(5,n);
    if mod(nf,2)==0, nf=nf-1; end
end

function addLegendNote(fig, note_str)
    annotation(fig,'textbox',[0,0,1,0.025],'String',note_str,...
               'EdgeColor','none','HorizontalAlignment','center',...
               'FontSize',8,'Color',[0.5 0.5 0.5]);
end