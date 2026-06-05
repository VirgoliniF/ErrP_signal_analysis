% =========================================================================
%  plot_acceleration_profiles_single_bags.m
%
%  Per ogni bag nella cartella selezionata, produce due figure dedicate:
%
%  Fig A  — Profili di VELOCITÀ (una per bag)
%    Righe  : step_idx (0, 1, 2, ...)
%    Colonne: LEFT  |  RIGHT
%    Contenuto di ogni subplot:
%      - target velocity  : linea orizzontale tratteggiata nera (VelocityTest)
%                           oppure profilo continuo (AccelerationTest)
%      - ODOM_WCIAS       : linea continua blu
%      - ODOM_FILT        : linea tratto-punto verde
%      - linee verticali grigie: START (t=0, --) e STOP (:)
%
%  Fig B  — Profili di ACCELERAZIONE (una per bag)
%    Stessa struttura di subplot
%    Contenuto:
%      - accelerazione target  (AccelerationTest only, tratteggiato nero)
%      - ODOM_WCIAS derivata   (continua blu)
%      - encoder grezzo        (puntinato arancio)
%
%  COMPATIBILITÀ BAG:
%    VelocityTest    — target come yline orizzontale (un solo punto per step)
%    AccelerationTest — target come profilo continuo a 100 Hz
%    Il tipo viene rilevato automaticamente.
%
%  NOTA su T_PRE / T_POST:
%    Estendono la finestra temporale attorno allo step. Nei bag VelocityTest
%    i margini mostrano la sedia ferma (wz≈0) perché tra uno step e l'altro
%    c'è una pausa a velocità zero. Nei bag AccelerationTest mostrano la
%    rampa di ingresso e uscita dallo step.
%
%  Topic letti:
%    /acceleration_test/target_velocity  [std_msgs/Float64]  (AccelerationTest)
%    /gui/cmd_vel                        [geometry_msgs/Twist] (VelocityTest)
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

% ── Parametri fisici wheelchair (encoder → wz)
RADIUS   = 0.175;
LW       = 0.566;
N_ONEROT = 500;
N_SP_R   = 26;    N_BP_R = 71.53;
N_SP_L   = 28;    N_BP_L = 71.63;

% ── Savitzky-Golay (smoothing accelerazione)
SG_ORDER  = 3;
SG_FRAMES = 15;   % dispari, > SG_ORDER

% ── Margini temporali attorno a ogni step [s]
%    Nei bag VelocityTest non cambiano visivamente (la sedia è ferma fuori dallo step).
%    Nei bag AccelerationTest mostrano la rampa di ingresso/uscita.
T_PRE  = 0.3;
T_POST = 0.8;

% ── Costanti evento
VT_CLOSE_MASK = 1000;   % AT_CLOSE_MASK (AccelerationTest)
%                32768  % VT_CLOSE_MASK (VelocityTest) — rilevato automaticamente
VT_INIT       = 1;
VT_END        = 2;

% ── Bag da escludere (indici nella lista ordinata, es. [2])
BAG_SKIP = [];

% ── Colori fissi per sorgente
CLR_TARGET = [0.15 0.15 0.15];   % nero
CLR_WCIAS  = [0.22 0.48 0.72];   % blu
CLR_FILT   = [0.13 0.62 0.46];   % verde
CLR_ENC    = [0.73 0.35 0.09];   % arancio

LW_TARGET = 1.6;
LW_MEAS   = 1.5;
LW_ENC    = 1.2;

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

%% ── 2. Loop principale ───────────────────────────────────────────────────

for b = 1:n_bags

    bpath = fullfile(all_bags(b).folder, all_bags(b).name);
    bname = all_bags(b).name;
    fprintf('[%d/%d] %s\n', b, n_bags, bname);

    % ── Apri bag ─────────────────────────────────────────────────────────
    try
        bag = rosbag(bpath);
    catch ME
        warning('  Impossibile aprire: %s', ME.message);
        continue
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

    % ── Rileva tipo bag e close mask ──────────────────────────────────────
    % AccelerationTest usa AT_CLOSE_MASK=1000, VelocityTest usa VT_CLOSE_MASK=32768
    % Il tipo si distingue guardando il massimo event code presente
    max_code   = max(ev_code);
    if max_code >= 32768
        close_mask = 32768;
        bag_type   = 'VelocityTest';
    else
        close_mask = 1000;
        bag_type   = 'AccelerationTest';
    end
    fprintf('  Tipo rilevato: %s (close_mask=%d)\n', bag_type, close_mask);

    % ── Leggi target velocity ─────────────────────────────────────────────
    % AccelerationTest: topic continuo a 100 Hz
    % VelocityTest:     singoli messaggi /gui/cmd_vel (uno per step)
    has_continuous_target = false;
    tv_t = []; tv_val = [];

    if strcmp(bag_type, 'AccelerationTest')
        try
            tv_sel  = select(bag, 'Topic', '/acceleration_test/target_velocity');
            tv_msgs = readMessages(tv_sel, 'DataFormat', 'struct');
            % std_msgs/Float64 has NO Header — use bag record timestamps
            % from MessageList instead of m.Header.Stamp
            tv_info = tv_sel.MessageList;
            tv_t    = tv_info.Time;          % bag record time [s], double
            tv_val  = cellfun(@(m) double(m.Data), tv_msgs);
            % Ensure column vectors
            tv_t   = tv_t(:);
            tv_val = tv_val(:);
            has_continuous_target = true;
            fprintf('  Target continuo trovato (%d campioni).\n', numel(tv_t));
        catch ME
            warning('  /acceleration_test/target_velocity non trovato: %s', ME.message);
        end
    end

    % Per VelocityTest (o fallback): leggi /gui/cmd_vel come valori puntuali
    % Questi verranno usati come yline orizzontale, NON come time-series
    cmd_step_val = containers.Map('KeyType','int32','ValueType','double');
    try
        cv_sel  = select(bag, 'Topic', '/gui/cmd_vel');
        cv_msgs = readMessages(cv_sel, 'DataFormat', 'struct');
        cv_info = cv_sel.MessageList;
        cv_t    = cv_info.Time;
        cv_angz = cellfun(@(m) double(m.Angular.Z), cv_msgs);
        % Mappa: per ogni evento START, trova il cmd_vel più vicino
        start_mask_pre = ev_code ~= VT_INIT & ev_code ~= VT_END & ...
                         ev_code  < close_mask;
        for ii = find(start_mask_pre)'
            scode  = ev_code(ii);
            stime  = ev_t(ii);
            [~, ci] = min(abs(cv_t - stime));
            cmd_step_val(int32(scode)) = cv_angz(ci);
        end
    catch
    end

    % ── Leggi odometrie ───────────────────────────────────────────────────
    odom = struct();
    topic_map = struct('wcias','/wcias_controller/odom','filt','/odometry/filtered');
    for fn = fieldnames(topic_map)'
        lbl = fn{1};
        try
            od_sel  = select(bag, 'Topic', topic_map.(lbl));
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

    % ── Leggi encoder grezzo ──────────────────────────────────────────────
    enc_t = []; enc_l = []; enc_r = [];
    try
        enc_sel  = select(bag, 'Topic', '/encoder_counter');
        enc_msgs = readMessages(enc_sel, 'DataFormat', 'struct');
        enc_info = enc_sel.MessageList;
        enc_t    = enc_info.Time;
        enc_l    = cellfun(@(m) double(m.Data(1)), enc_msgs);
        enc_r    = cellfun(@(m) double(m.Data(2)), enc_msgs);
    catch
    end

    % ── Identifica step ───────────────────────────────────────────────────
    start_mask = ev_code ~= VT_INIT & ev_code ~= VT_END & ...
                 ev_code  < close_mask;
    start_idxs = find(start_mask);

    if isempty(start_idxs)
        warning('  Nessuno step trovato — skip.'); continue
    end

    % ── Estrai dati per ogni step ─────────────────────────────────────────
    steps = struct([]);
    for si = 1:numel(start_idxs)
        ii    = start_idxs(si);
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
        step.t_start  = stime;
        step.t_end    = etime;
        step.duration = etime - stime;

        % Valore target puntuale (per yline)
        if isKey(cmd_step_val, int32(scode))
            step.target_yval = cmd_step_val(int32(scode));
        else
            step.target_yval = NaN;
        end

        tw0 = stime - T_PRE;
        tw1 = etime + T_POST;

        % Target continuo (solo AccelerationTest)
        if has_continuous_target
            m = tv_t >= tw0 & tv_t <= tw1;
            step.target_t   = tv_t(m)   - stime;
            step.target_vel = tv_val(m);
            step.target_acc = safeDerive(step.target_t, step.target_vel, ...
                                         SG_ORDER, SG_FRAMES);
        else
            step.target_t   = [];
            step.target_vel = [];
            step.target_acc = [];
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

        % Encoder grezzo → wz
        if ~isempty(enc_t)
            m = enc_t >= tw0 & enc_t <= tw1;
            if sum(m) > 4
                et   = enc_t(m) - stime;
                el   = enc_l(m);
                er   = enc_r(m);
                dt_e = diff(et); dt_e(dt_e < 1e-9) = 1e-9;
                dotR = diff(er) .* (pi/N_ONEROT) .* (N_SP_R/N_BP_R) ./ dt_e;
                dotL = (-diff(el)) .* (pi/N_ONEROT) .* (N_SP_L/N_BP_L) ./ dt_e;
                wz_enc = (RADIUS/LW) .* (dotR - dotL);
                nf = makeOdd(min(SG_FRAMES, numel(wz_enc)-1));
                if numel(wz_enc) >= nf
                    wz_enc = sgolayfilt(wz_enc, SG_ORDER, nf);
                end
                step.enc_t   = et(1:end-1);
                step.enc_wz  = wz_enc;
                step.enc_acc = safeDerive(et(1:end-1), wz_enc, SG_ORDER, SG_FRAMES);
            else
                step.enc_t = []; step.enc_wz = []; step.enc_acc = [];
            end
        else
            step.enc_t = []; step.enc_wz = []; step.enc_acc = [];
        end

        if isempty(steps), steps = step;
        else,              steps(end+1) = step; end %#ok<AGROW>
    end

    fprintf('  %d step estratti.\n', numel(steps));

    % ── Layout subplot ────────────────────────────────────────────────────
    directions = {'LEFT','RIGHT'};
    step_idxs  = unique([steps.idx]);
    n_rows     = numel(step_idxs);
    n_cols     = numel(directions);
    fig_h      = max(320, 230 * n_rows);
    fig_w      = 700 * n_cols;

    [~, short_name] = fileparts(bname);
    if numel(short_name) > 55
        short_name = [short_name(1:52) '...'];
    end

    % ── FIGURA A: VELOCITÀ ────────────────────────────────────────────────
    fig_v = figure('Name', sprintf('VEL | %s', bname), ...
                   'NumberTitle','off', ...
                   'Position', [30+b*12, 60+b*12, fig_w, fig_h]);

    for ri = 1:n_rows
        for ci = 1:n_cols
            ax = subplot(n_rows, n_cols, (ri-1)*n_cols + ci);
            hold(ax,'on'); grid(ax,'on'); box(ax,'on');
            set(ax,'FontSize',9);

            sidx = step_idxs(ri);
            dir  = directions{ci};
            title(ax, sprintf('%s — step %d', dir, sidx), ...
                  'FontWeight','normal','FontSize',9);
            xlabel(ax,'t [s]');
            ylabel(ax,'wz [rad/s]');

            match = find(arrayfun(@(s) s.idx==sidx && strcmp(s.dir,dir), steps));
            if isempty(match), continue; end
            s = steps(match(1));

            % Linee verticali START/STOP
            xline(ax, 0,          '--','Color',[.6 .6 .6],'LineWidth',0.8, ...
                  'HandleVisibility','off');
            xline(ax, s.duration, ':','Color',[.6 .6 .6],'LineWidth',0.8, ...
                  'HandleVisibility','off');

            % ── TARGET ────────────────────────────────────────────────────
            if has_continuous_target && ~isempty(s.target_t)
                % AccelerationTest: profilo continuo
                plot(ax, s.target_t, s.target_vel, '--', ...
                     'Color', CLR_TARGET, 'LineWidth', LW_TARGET, ...
                     'DisplayName', 'target');
            elseif ~isnan(s.target_yval)
                % VelocityTest: singolo valore → linea orizzontale
                % tracciata sull'intera finestra dello step
                t_line = [-T_PRE, s.duration + T_POST];
                plot(ax, t_line, [s.target_yval, s.target_yval], '--', ...
                     'Color', CLR_TARGET, 'LineWidth', LW_TARGET, ...
                     'DisplayName', sprintf('target = %.3f rad/s', s.target_yval));
            end

            % ODOM_WCIAS
            if ~isempty(s.wcias_t)
                plot(ax, s.wcias_t, s.wcias_wz, '-', ...
                     'Color', CLR_WCIAS, 'LineWidth', LW_MEAS, ...
                     'DisplayName', 'wcias');
            end

            % ODOM_FILT
            if ~isempty(s.filt_t)
                plot(ax, s.filt_t, s.filt_wz, '-.', ...
                     'Color', CLR_FILT, 'LineWidth', LW_MEAS*0.9, ...
                     'DisplayName', 'filt');
            end

            legend(ax,'show','Location','best','FontSize',7);
        end
    end

    type_str = sprintf('(%s)', bag_type);
    sgtitle(fig_v, sprintf('Profili di velocità  %s\n%s', type_str, short_name), ...
            'FontSize',11,'FontWeight','bold','Interpreter','none');
    addLegendNote(fig_v, ...
        'target: — — —   |   wcias: ——   |   filt: -·-   |   vert: START(--)  STOP(:)');

    % ── FIGURA B: ACCELERAZIONE ───────────────────────────────────────────
    fig_a = figure('Name', sprintf('ACC | %s', bname), ...
                   'NumberTitle','off', ...
                   'Position', [50+b*12, 80+b*12, fig_w, fig_h]);

    for ri = 1:n_rows
        for ci = 1:n_cols
            ax = subplot(n_rows, n_cols, (ri-1)*n_cols + ci);
            hold(ax,'on'); grid(ax,'on'); box(ax,'on');
            set(ax,'FontSize',9);

            sidx = step_idxs(ri);
            dir  = directions{ci};
            title(ax, sprintf('%s — step %d', dir, sidx), ...
                  'FontWeight','normal','FontSize',9);
            xlabel(ax,'t [s]');
            ylabel(ax,'az [rad/s²]');

            match = find(arrayfun(@(s) s.idx==sidx && strcmp(s.dir,dir), steps));
            if isempty(match), continue; end
            s = steps(match(1));

            xline(ax, 0,          '--','Color',[.6 .6 .6],'LineWidth',0.8, ...
                  'HandleVisibility','off');
            xline(ax, s.duration, ':','Color',[.6 .6 .6],'LineWidth',0.8, ...
                  'HandleVisibility','off');

            % Target acceleration (solo AccelerationTest)
            if has_continuous_target && ~isempty(s.target_acc)
                plot(ax, s.target_t, s.target_acc, '--', ...
                     'Color', CLR_TARGET, 'LineWidth', LW_TARGET, ...
                     'DisplayName','target accel');
            else
                % VelocityTest: target accel non disponibile → nota testuale
                text(ax, 0.5, 0.92, 'target accel: N/A (VelocityTest)', ...
                     'Units','normalized','HorizontalAlignment','center', ...
                     'FontSize',7,'Color',[0.5 0.5 0.5], ...
                     'HandleVisibility','off');
            end

            % ODOM_WCIAS acceleration
            if ~isempty(s.wcias_acc)
                plot(ax, s.wcias_t, s.wcias_acc, '-', ...
                     'Color', CLR_WCIAS, 'LineWidth', LW_MEAS, ...
                     'DisplayName','wcias accel');
            end

            % Encoder grezzo
            if ~isempty(s.enc_acc)
                plot(ax, s.enc_t, s.enc_acc, ':', ...
                     'Color', CLR_ENC, 'LineWidth', LW_ENC, ...
                     'DisplayName','encoder raw');
            end

            legend(ax,'show','Location','best','FontSize',7);
        end
    end

    sgtitle(fig_a, sprintf('Profili di accelerazione  %s\n%s', type_str, short_name), ...
            'FontSize',11,'FontWeight','bold','Interpreter','none');
    addLegendNote(fig_a, ...
        'target accel: — — — (AccelerationTest only)   |   wcias: ——   |   encoder: ···');

    clear bag steps odom enc_t enc_l enc_r tv_t tv_val cmd_step_val;
    drawnow;

end  % loop bag

fprintf('\nDone — %d bag processate.\n', n_bags);

%% ── Funzioni locali ──────────────────────────────────────────────────────

function acc = safeDerive(t, v, sg_order, sg_frames)
    acc = zeros(size(t));
    if numel(t) < 4, return; end
    dt = diff(t(:)); dt(dt < 1e-9) = 1e-9;
    dv = diff(v(:)) ./ dt;
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
