% =========================================================================
%  plot_steps_overlay.m
%
%  Per ogni bag nella cartella selezionata, produce due figure:
%
%  Fig A — Velocità: tutti gli step sovrapposti
%    Subplot LEFT | RIGHT
%    Ogni step = una linea colorata diversa
%    Target = linea nera tratteggiata (se AccelerationTest)
%           = yline orizzontale     (se VelocityTest)
%
%  Fig B — Accelerazione: tutti gli step sovrapposti
%    Stessa struttura
%    Sorgenti: ODOM_WCIAS (continua) + encoder grezzo (puntinata)
%    Target accel = tratteggiato nero (solo AccelerationTest)
%
%  L'asse temporale è relativo a t=0 (evento START di ogni step).
%  Le linee verticali grigie indicano START (t=0, --) e STOP (:).
%
%  Topic letti:
%    /acceleration_test/target_velocity  [std_msgs/Float64]
%    /gui/cmd_vel                        [geometry_msgs/Twist]
%    /wcias_controller/odom              [nav_msgs/Odometry]
%    /odometry/filtered                  [nav_msgs/Odometry]
%    /encoder_counter                    [std_msgs/Int32MultiArray]
%    /events/bus                         [rosneuro_msgs/NeuroEvent]
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

% Savitzky-Golay (smoothing accelerazione)
SG_ORDER  = 3;
SG_FRAMES = 15;

% Margini temporali attorno a ogni step [s]
T_PRE  = 0.3;
T_POST = 0.8;

% Costanti evento
VT_CLOSE_MASK = 1000;
VT_INIT       = 1;
VT_END        = 2;

% Bag da escludere (indici nella lista ordinata)
BAG_SKIP = [];

% Colori per i passi (si ciclano se gli step sono più dei colori)
STEP_COLORS = [
    0.22  0.48  0.72;   % blu
    0.84  0.19  0.15;   % rosso
    0.13  0.62  0.46;   % verde
    0.73  0.35  0.09;   % arancio
    0.50  0.23  0.56;   % viola
    0.93  0.69  0.13;   % giallo
    0.30  0.68  0.29;   % verde chiaro
    0.60  0.60  0.60;   % grigio
];

LW_TARGET = 1.8;
LW_MEAS   = 1.5;
LW_ENC    = 1.2;
LW_FILT   = 1.2;

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

%% ── 2. Loop bag ──────────────────────────────────────────────────────────

for b = 1:n_bags

    bpath = fullfile(all_bags(b).folder, all_bags(b).name);
    bname = all_bags(b).name;
    fprintf('[%d/%d] %s\n', b, n_bags, bname);

    % ── Apri bag ─────────────────────────────────────────────────────────
    try
        bag = rosbag(bpath);
    catch ME
        warning('  Impossibile aprire: %s', ME.message); continue
    end

    % ── Leggi eventi ─────────────────────────────────────────────────────
    try
        ev_sel  = select(bag, 'Topic', '/events/bus');
        ev_msgs = readMessages(ev_sel, 'DataFormat', 'struct');
        ev_t    = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                               double(m.Header.Stamp.Nsec)*1e-9, ev_msgs);
        ev_code = cellfun(@(m) double(m.Event), ev_msgs);
    catch
        warning('  /events/bus non trovato — skip.'); continue
    end

    % ── Tipo bag ─────────────────────────────────────────────────────────
    if max(ev_code) >= 32768
        close_mask = 32768;
        bag_type   = 'VelocityTest';
    else
        close_mask = 1000;
        bag_type   = 'AccelerationTest';
    end
    fprintf('  Tipo: %s\n', bag_type);

    % ── Target velocity ───────────────────────────────────────────────────
    has_continuous_target = false;
    tv_t = []; tv_val = [];
    if strcmp(bag_type, 'AccelerationTest')
        try
            tv_sel  = select(bag, 'Topic', '/acceleration_test/target_velocity');
            tv_msgs = readMessages(tv_sel, 'DataFormat', 'struct');
            tv_info = tv_sel.MessageList;
            tv_t    = tv_info.Time(:);
            tv_val  = cellfun(@(m) double(m.Data), tv_msgs);
            tv_val  = tv_val(:);
            has_continuous_target = true;
            fprintf('  Target trovato (%d campioni).\n', numel(tv_t));
        catch ME
            warning('  Target velocity non trovato: %s', ME.message);
        end
    end

    % cmd_vel puntuale per VelocityTest / fallback
    cmd_step_val = containers.Map('KeyType','int32','ValueType','double');
    try
        cv_sel  = select(bag, 'Topic', '/gui/cmd_vel');
        cv_msgs = readMessages(cv_sel, 'DataFormat', 'struct');
        cv_info = cv_sel.MessageList;
        cv_t    = cv_info.Time(:);
        cv_angz = cellfun(@(m) double(m.Angular.Z), cv_msgs);
        smask   = ev_code ~= VT_INIT & ev_code ~= VT_END & ev_code < close_mask;
        for ii = find(smask)'
            [~,ci] = min(abs(cv_t - ev_t(ii)));
            cmd_step_val(int32(ev_code(ii))) = cv_angz(ci);
        end
    catch
    end

    % ── Odometrie ─────────────────────────────────────────────────────────
    odom = struct();
    tmap = struct('wcias','/wcias_controller/odom','filt','/odometry/filtered');
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
    smask     = ev_code ~= VT_INIT & ev_code ~= VT_END & ev_code < close_mask;
    start_ids = find(smask);
    if isempty(start_ids)
        warning('  Nessuno step trovato.'); continue
    end

    % ── Estrai dati step ──────────────────────────────────────────────────
    steps = struct([]);
    for si = 1:numel(start_ids)
        ii    = start_ids(si);
        scode = ev_code(ii);
        stime = ev_t(ii);

        stop_m = ev_code == (scode + close_mask) & ev_t > stime;
        etime  = stime + 15;
        if any(stop_m), etime = ev_t(find(stop_m,1)); end

        [dir_str, stype] = decodeEventCode(scode);

        step.dir      = dir_str;
        step.type     = stype;
        step.code     = scode;
        step.idx      = mod(scode, 100);
        step.duration = etime - stime;

        % Target puntuale
        if isKey(cmd_step_val, int32(scode))
            step.target_yval = cmd_step_val(int32(scode));
        else
            step.target_yval = NaN;
        end

        tw0 = stime - T_PRE;
        tw1 = etime + T_POST;

        % Target continuo
        if has_continuous_target
            m = tv_t >= tw0 & tv_t <= tw1;
            step.target_t   = tv_t(m)   - stime;
            step.target_vel = tv_val(m);
            step.target_acc = safeDerive(step.target_t, step.target_vel, ...
                                         SG_ORDER, SG_FRAMES);
        else
            step.target_t = []; step.target_vel = []; step.target_acc = [];
        end

        % Odometrie
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

        % Encoder
        if ~isempty(enc_t)
            m = enc_t >= tw0 & enc_t <= tw1;
            if sum(m) > 4
                et   = enc_t(m) - stime;
                el   = enc_l(m); er = enc_r(m);
                dt_e = diff(et); dt_e(dt_e<1e-9) = 1e-9;
                dotR = diff(er) .* (pi/N_ONEROT).*(N_SP_R/N_BP_R) ./ dt_e;
                dotL = (-diff(el)).*(pi/N_ONEROT).*(N_SP_L/N_BP_L) ./ dt_e;
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

    fprintf('  %d step estratti.\n', numel(steps));

    % ── Organizza per direzione ───────────────────────────────────────────
    directions = {'LEFT','RIGHT'};
    n_dirs     = numel(directions);

    % Raggruppa step per direzione
    dir_steps = cell(1, n_dirs);
    for di = 1:n_dirs
        mask = arrayfun(@(s) strcmp(s.dir, directions{di}) && ...
                             strcmp(s.type,'ROTATION'), steps);
        dir_steps{di} = steps(mask);
    end

    % Numero massimo di step per direzione (per la legenda)
    n_steps_max = max(cellfun(@numel, dir_steps));
    if n_steps_max == 0, continue; end

    [~, short_name] = fileparts(bname);
    if numel(short_name) > 55
        short_name = [short_name(1:52) '...'];
    end

    fig_w = 720 * n_dirs;
    fig_h = 480;

    % ── FIGURA A: VELOCITÀ — step sovrapposti ─────────────────────────────
    fig_v = figure('Name', sprintf('VEL overlay | %s', bname), ...
                   'NumberTitle','off', ...
                   'Position', [30+b*14, 60+b*14, fig_w, fig_h]);

    ax_v = gobjects(1, n_dirs);
    for di = 1:n_dirs
        ax = subplot(1, n_dirs, di);
        ax_v(di) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        set(ax,'FontSize',10);
        title(ax, directions{di}, 'FontWeight','normal');
        xlabel(ax,'t [s]');
        ylabel(ax,'wz [rad/s]');

        ss = dir_steps{di};
        if isempty(ss), continue; end

        for si = 1:numel(ss)
            s   = ss(si);
            clr = STEP_COLORS(mod(si-1, size(STEP_COLORS,1))+1, :);
            lbl = sprintf('step %d  (a=%.3g rad/s²)', s.idx, ...
                          vel_target_label(s, has_continuous_target));

            % ── Target ────────────────────────────────────────────────────
            if has_continuous_target && ~isempty(s.target_t)
                plot(ax, s.target_t, s.target_vel, '--', ...
                     'Color', clr, 'LineWidth', LW_TARGET, ...
                     'HandleVisibility','off');
            elseif ~isnan(s.target_yval)
                t_line = [-T_PRE, s.duration + T_POST];
                plot(ax, t_line, [s.target_yval, s.target_yval], '--', ...
                     'Color', clr, 'LineWidth', LW_TARGET, ...
                     'HandleVisibility','off');
            end

            % ── ODOM_WCIAS ────────────────────────────────────────────────
            if ~isempty(s.wcias_t)
                plot(ax, s.wcias_t, s.wcias_wz, '-', ...
                     'Color', clr, 'LineWidth', LW_MEAS, ...
                     'DisplayName', buildLabel(s, has_continuous_target, tv_t, tv_val, si));
            end

            % ── ODOM_FILT ─────────────────────────────────────────────────
            if ~isempty(s.filt_t)
                plot(ax, s.filt_t, s.filt_wz, '-.', ...
                     'Color', clr.*0.75, 'LineWidth', LW_FILT, ...
                     'HandleVisibility','off');
            end

            % Linee verticali START/STOP (solo prima iterazione)
            if si == 1
                xline(ax, 0,          '--','Color',[.6 .6 .6], ...
                      'LineWidth',0.8,'HandleVisibility','off');
                xline(ax, s.duration, ':','Color',[.6 .6 .6], ...
                      'LineWidth',0.8,'HandleVisibility','off');
            end
        end

        legend(ax,'show','Location','best','FontSize',8);
    end

    % Asse Y condiviso tra LEFT e RIGHT
    linkaxes(ax_v, 'y');

    type_str = sprintf('(%s)', bag_type);
    sgtitle(fig_v, sprintf('Velocità — step sovrapposti  %s\n%s', ...
            type_str, short_name), ...
            'FontSize',11,'FontWeight','bold','Interpreter','none');
    addLegendNote(fig_v, ...
        'wcias (——)   filt (-·-, colore scuro)   target (---, stesso colore step)   |   vert: START(--)  STOP(:)');

    % ── FIGURA B: ACCELERAZIONE — step sovrapposti ────────────────────────
    fig_a = figure('Name', sprintf('ACC overlay | %s', bname), ...
                   'NumberTitle','off', ...
                   'Position', [50+b*14, 80+b*14, fig_w, fig_h]);

    ax_a = gobjects(1, n_dirs);
    for di = 1:n_dirs
        ax = subplot(1, n_dirs, di);
        ax_a(di) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        set(ax,'FontSize',10);
        title(ax, directions{di}, 'FontWeight','normal');
        xlabel(ax,'t [s]');
        ylabel(ax,'az [rad/s²]');

        ss = dir_steps{di};
        if isempty(ss), continue; end

        if ~has_continuous_target
            text(ax, 0.5, 0.95, 'target accel: N/A (VelocityTest)', ...
                 'Units','normalized','HorizontalAlignment','center', ...
                 'FontSize',8,'Color',[0.5 0.5 0.5],'HandleVisibility','off');
        end

        for si = 1:numel(ss)
            s   = ss(si);
            clr = STEP_COLORS(mod(si-1, size(STEP_COLORS,1))+1, :);

            % ── Target accel ──────────────────────────────────────────────
            if has_continuous_target && ~isempty(s.target_acc)
                plot(ax, s.target_t, s.target_acc, '--', ...
                     'Color', clr, 'LineWidth', LW_TARGET, ...
                     'HandleVisibility','off');
            end

            % ── ODOM_WCIAS accel ──────────────────────────────────────────
            if ~isempty(s.wcias_acc)
                plot(ax, s.wcias_t, s.wcias_acc, '-', ...
                     'Color', clr, 'LineWidth', LW_MEAS, ...
                     'DisplayName', buildLabel(s, has_continuous_target, tv_t, tv_val, si));
            end

            % ── Encoder raw accel ─────────────────────────────────────────
            if ~isempty(s.enc_acc)
                plot(ax, s.enc_t, s.enc_acc, ':', ...
                     'Color', clr, 'LineWidth', LW_ENC, ...
                     'HandleVisibility','off');
            end

            if si == 1
                xline(ax, 0,          '--','Color',[.6 .6 .6], ...
                      'LineWidth',0.8,'HandleVisibility','off');
                xline(ax, s.duration, ':','Color',[.6 .6 .6], ...
                      'LineWidth',0.8,'HandleVisibility','off');
            end
        end

        legend(ax,'show','Location','best','FontSize',8);
    end

    linkaxes(ax_a, 'y');

    sgtitle(fig_a, sprintf('Accelerazione — step sovrapposti  %s\n%s', ...
            type_str, short_name), ...
            'FontSize',11,'FontWeight','bold','Interpreter','none');
    addLegendNote(fig_a, ...
        'wcias accel (——)   encoder raw (···)   target accel (---, AccelerationTest only)');

    clear bag steps odom enc_t enc_l enc_r tv_t tv_val cmd_step_val dir_steps;
    drawnow;

end  % loop bag

fprintf('\nDone — %d bag processate.\n', n_bags);

%% ── Funzioni locali ──────────────────────────────────────────────────────

function lbl = buildLabel(s, has_continuous_target, tv_t, tv_val, si)
%BUILDLABEL  Costruisce la stringa legenda per uno step.
%  Se AccelerationTest: mostra l'accelerazione target dello step.
%  Se VelocityTest:     mostra la velocità comandata.
    if has_continuous_target && ~isempty(s.target_t) && ~isempty(s.target_vel)
        % Accelerazione: pendenza media nella fase di ramp-up (prima metà)
        t_r = s.target_t;
        v_r = s.target_vel;
        half = t_r(end)/2;
        peak = max(abs(v_r));
        up   = abs(v_r) >= 0.10*peak & abs(v_r) <= 0.85*peak & t_r <= half;
        if sum(up) >= 2
            p   = polyfit(t_r(up), abs(v_r(up)), 1);
            lbl = sprintf('step %d  (a≈%.3f rad/s²)', s.idx, p(1));
        else
            lbl = sprintf('step %d', s.idx);
        end
    elseif ~isnan(s.target_yval)
        lbl = sprintf('step %d  (cmd=%.3f rad/s)', s.idx, s.target_yval);
    else
        lbl = sprintf('step %d', s.idx);
    end
end

function val = vel_target_label(s, has_cont) %#ok<INUSL>
%VEL_TARGET_LABEL  Placeholder — restituisce 0 (non usato direttamente).
    val = 0;
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

function nf = makeOdd(n)
    nf = max(5,n);
    if mod(nf,2)==0, nf=nf-1; end
end

function addLegendNote(fig, note_str)
    annotation(fig,'textbox',[0,0,1,0.025],'String',note_str, ...
               'EdgeColor','none','HorizontalAlignment','center', ...
               'FontSize',8,'Color',[0.5 0.5 0.5]);
end