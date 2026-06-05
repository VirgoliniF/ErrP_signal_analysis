% =========================================================================
%  plot_acceleration_profiles.m
%
%  Visualizza i profili di velocità e accelerazione registrati con
%  AccelerationTest o VelocityTest.
%
%  STRUTTURA FIGURE
%  ─────────────────────────────────────────────────────────────────────
%  Modalità A — Velocity sweep (più bag con velocità diverse, stessa accel)
%    Fig 1 : Profili di velocità  — subplot per direzione (LEFT / RIGHT)
%             Ogni bag = una linea colorata + linea target tratteggiata
%    Fig 2 : Profili di accelerazione — subplot per direzione
%             Derivata target (tratteggiata), odom wcias (continua),
%             encoder grezzo (puntinata)
%
%  Modalità B — Acceleration sweep (stessa vel_target, accel diverse)
%    Fig 3 : Profili di velocità sovrapposti
%    Fig 4 : Profili di accelerazione sovrapposti
%
%  Il numero di bag è rilevato automaticamente dalla cartella selezionata.
%  I bag vengono associati a una label (es. "vel=0.2", "accel=0.1") che
%  puoi personalizzare nella sezione CONFIG.
%
%  Topic letti:
%    /acceleration_test/target_velocity  [std_msgs/Float64]
%    /acceleration_test/phase            [std_msgs/String]
%    /wcias_controller/odom              [nav_msgs/Odometry]
%    /odometry/filtered                  [nav_msgs/Odometry]
%    /encoder_counter                    [std_msgs/Int32MultiArray]
%    /events/bus                         [rosneuro_msgs/NeuroEvent]
%    /gui/cmd_vel                        [geometry_msgs/Twist]
%
%  Richiede: ROS Toolbox, Signal Processing Toolbox (sgolayfilt)
%            MATLAB R2021b+
% =========================================================================

clear; clc; close all;

%% ── 0. CONFIGURAZIONE ────────────────────────────────────────────────────

% ── Modalità ─────────────────────────────────────────────────────────────
% 'velocity'     : confronto tra bag con velocità diverse (vel sweep)
% 'acceleration' : confronto tra bag con accel diverse (accel sweep)
% 'auto'         : detecta automaticamente leggendo i target nei bag
MODE = 'auto';

% ── Label per ciascuna bag (ordine = ordine alfabetico file nella cartella)
% Lascia vuoto {} per label automatiche (bag 1, bag 2, ...)
% Esempi:
%   velocity sweep:     BAG_LABELS = {'vel=0.2','vel=0.35','vel=0.5'};
%   acceleration sweep: BAG_LABELS = {'accel=0.05','accel=0.2','accel=0.5'};
BAG_LABELS = {};

% ── Bag da escludere (indice nella lista ordinata, es. [2] per saltare bag2)
BAG_SKIP = [1, 2, 3];

% ── Parametri fisici wheelchair (per derivare wz da encoder grezzo)
RADIUS   = 0.175;   % [m]  raggio ruota
LW       = 0.566;   % [m]  track width
N_ONEROT = 500;     % encoder ticks per "half revolution" (formula: pi/N)
N_SP_R   = 26;      % small pulley right
N_BP_R   = 71.53;   % big   pulley right
N_SP_L   = 28;      % small pulley left
N_BP_L   = 71.63;   % big   pulley left

% ── Smoothing Savitzky-Golay per accelerazione
SG_ORDER  = 3;
SG_FRAMES = 15;   % deve essere dispari e > SG_ORDER

% ── Margine temporale attorno a ogni step [s]
%    pre:  quanti secondi prima dell'evento START includere
%    post: quanti secondi dopo l'evento STOP includere
T_PRE  = 0.2;
T_POST = 0.5;

% ── Colori per le bag (si ciclano se le bag sono più dei colori)
COLORS = [
    0.22  0.48  0.72;   % blu
    0.13  0.62  0.46;   % verde
    0.73  0.35  0.09;   % arancio
    0.70  0.17  0.43;   % viola
    0.85  0.33  0.10;   % rosso
    0.30  0.68  0.29;   % verde chiaro
    0.50  0.23  0.56;   % indaco
    0.93  0.69  0.13;   % giallo
];

% ── Stili linea per le tre sorgenti
STYLE_TARGET = '--';   % linea tratteggiata per il target
STYLE_WCIAS  = '-';    % linea continua  per ODOM_WCIAS
STYLE_FILT   = '-.';   % linea tratto-punto per ODOM_FILT
STYLE_ENC    = ':';    % puntini per encoder grezzo

LW_TARGET = 1.8;
LW_MEAS   = 1.5;
LW_ENC    = 1.2;

% ── Costanti evento (devono coincidere con VelocityTest.h / AccelerationTest.h)
VT_CLOSE_MASK = 1000;   % AT_CLOSE_MASK
VT_INIT       = 1;
VT_END        = 2;

%% ── 1. Selezione cartella ────────────────────────────────────────────────

bag_dir = uigetdir(pwd, 'Seleziona la cartella con i file .bag');
if isequal(bag_dir, 0), disp('Annullato.'); return; end

all_bags = dir(fullfile(bag_dir, '*.bag'));
if isempty(all_bags)
    error('Nessun file .bag trovato in: %s', bag_dir);
end

% Rimuovi bag da skippare
keep = setdiff(1:numel(all_bags), BAG_SKIP);
all_bags = all_bags(keep);

n_bags = numel(all_bags);
fprintf('Trovate %d bag (dopo esclusioni).\n\n', n_bags);

% Label automatiche se non specificate
if isempty(BAG_LABELS)
    BAG_LABELS = arrayfun(@(i) sprintf('bag %d', i), 1:n_bags, 'UniformOutput', false);
elseif numel(BAG_LABELS) ~= n_bags
    warning('BAG_LABELS ha %d elementi ma le bag sono %d — uso label automatiche.', ...
            numel(BAG_LABELS), n_bags);
    BAG_LABELS = arrayfun(@(i) sprintf('bag %d', i), 1:n_bags, 'UniformOutput', false);
end

%% ── 2. Lettura bag ───────────────────────────────────────────────────────

data = struct();   % data(b).steps = struct array

for b = 1:n_bags
    bpath = fullfile(all_bags(b).folder, all_bags(b).name);
    bname = all_bags(b).name;
    fprintf('[%d/%d] Lettura: %s\n', b, n_bags, bname);

    try
        bag = rosbag(bpath);
    catch ME
        warning('Impossibile aprire %s: %s', bpath, ME.message);
        data(b).valid = false;
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
        warning('  /events/bus non trovato — skip bag.');
        data(b).valid = false;
        continue
    end

    % ── Leggi target velocity ─────────────────────────────────────────────
    % std_msgs/Float64 has NO Header — use MessageList.Time for timestamps
    has_target = false;
    try
        tv_sel  = select(bag, 'Topic', '/acceleration_test/target_velocity');
        tv_msgs = readMessages(tv_sel, 'DataFormat', 'struct');
        tv_info = tv_sel.MessageList;
        tv_t    = tv_info.Time(:);
        tv_val  = cellfun(@(m) double(m.Data), tv_msgs);
        tv_val  = tv_val(:);
        has_target = true;
    catch
        % Fallback: usa /gui/cmd_vel come target
        try
            cv_sel  = select(bag, 'Topic', '/gui/cmd_vel');
            cv_msgs = readMessages(cv_sel, 'DataFormat', 'struct');
            cv_info = cv_sel.MessageList;
            tv_t    = cv_info.Time;
            tv_val  = cellfun(@(m) double(m.Angular.Z), cv_msgs);
            has_target = true;
        catch
        end
    end

    % ── Leggi odometrie ───────────────────────────────────────────────────
    odom = struct();
    for od_name = {'wcias', 'filt'}
        lbl = od_name{1};
        topic_map = struct('wcias', '/wcias_controller/odom', ...
                           'filt',  '/odometry/filtered');
        try
            od_sel  = select(bag, 'Topic', topic_map.(lbl));
            od_msgs = readMessages(od_sel, 'DataFormat', 'struct');
            od_t    = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                                   double(m.Header.Stamp.Nsec)*1e-9, od_msgs);
            od_wz   = cellfun(@(m) double(m.Twist.Twist.Angular.Z), od_msgs);
            odom.(lbl).t  = od_t(:);
            odom.(lbl).wz = od_wz(:);
        catch
            odom.(lbl).t  = [];
            odom.(lbl).wz = [];
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

    % ── Identifica step (START / STOP) ────────────────────────────────────
    start_mask = ev_code ~= VT_INIT & ev_code ~= VT_END & ...
                 ev_code  < VT_CLOSE_MASK;
    start_idx  = find(start_mask);

    steps = struct([]);
    for si = 1:numel(start_idx)
        ii    = start_idx(si);
        scode = ev_code(ii);
        stime = ev_t(ii);

        % STOP corrispondente
        stop_mask = ev_code == (scode + VT_CLOSE_MASK) & ev_t > stime;
        if any(stop_mask)
            etime = ev_t(find(stop_mask,1));
        else
            etime = stime + 15;
        end

        [dir_str, step_type] = decodeEventCode(scode);
        step_idx_val = mod(scode, 100);

        % Finestra con margini
        tw_start = stime - T_PRE;
        tw_end   = etime + T_POST;

        % Target nella finestra
        step.t_start = stime;
        step.t_end   = etime;
        step.dir     = dir_str;
        step.type    = step_type;
        step.code    = scode;
        step.idx     = step_idx_val;

        % Target velocity
        if has_target
            tv_m = tv_t >= tw_start & tv_t <= tw_end;
            step.target_t   = tv_t(tv_m)   - stime;
            step.target_vel = tv_val(tv_m);
            % Accelerazione target: derivata numerica smussata
            if numel(step.target_t) > SG_FRAMES
                dt_tv = diff(step.target_t);
                dt_tv(dt_tv < 1e-9) = 1e-9;
                step.target_acc = [0; sgolayfilt(diff(step.target_vel)./dt_tv, SG_ORDER, ...
                                   makeOdd(min(SG_FRAMES, numel(dt_tv)-1)))];
            else
                step.target_acc = zeros(size(step.target_t));
            end
        else
            step.target_t   = [];
            step.target_vel = [];
            step.target_acc = [];
        end

        % Odometrie
        for od_name = {'wcias','filt'}
            lbl = od_name{1};
            if ~isempty(odom.(lbl).t)
                od_m = odom.(lbl).t >= tw_start & odom.(lbl).t <= tw_end;
                t_w  = odom.(lbl).t(od_m)  - stime;
                wz_w = odom.(lbl).wz(od_m);
                % Accelerazione: derivata SG
                if numel(t_w) > SG_FRAMES
                    dt_w  = diff(t_w);
                    dt_w(dt_w < 1e-9) = 1e-9;
                    acc_w = [0; sgolayfilt(diff(wz_w)./dt_w, SG_ORDER, ...
                             makeOdd(min(SG_FRAMES, numel(dt_w)-1)))];
                else
                    acc_w = zeros(size(t_w));
                end
                step.([lbl '_t'])   = t_w;
                step.([lbl '_wz'])  = wz_w;
                step.([lbl '_acc']) = acc_w;
            else
                step.([lbl '_t'])   = [];
                step.([lbl '_wz'])  = [];
                step.([lbl '_acc']) = [];
            end
        end

        % Encoder grezzo → wz
        if ~isempty(enc_t)
            enc_m = enc_t >= tw_start & enc_t <= tw_end;
            if sum(enc_m) > 3
                et  = enc_t(enc_m) - stime;
                el  = enc_l(enc_m);
                er  = enc_r(enc_m);
                dt_enc = diff(et);
                dt_enc(dt_enc < 1e-9) = 1e-9;
                d_el = -diff(el);   % negato come in odom.cpp
                d_er =  diff(er);
                psi_r = d_er .* (pi / N_ONEROT) .* (N_SP_R / N_BP_R);
                psi_l = d_el .* (pi / N_ONEROT) .* (N_SP_L / N_BP_L);
                wz_enc_raw = (RADIUS / LW) .* (psi_r - psi_l) ./ dt_enc;
                % SG smooth
                nf = makeOdd(min(SG_FRAMES, numel(wz_enc_raw)-1));
                if numel(wz_enc_raw) > nf
                    wz_enc_sm  = sgolayfilt(wz_enc_raw, SG_ORDER, nf);
                    dt2        = diff(et(1:end-1));
                    dt2(dt2 < 1e-9) = 1e-9;
                    acc_enc    = [0; sgolayfilt(diff(wz_enc_sm)./dt2, SG_ORDER, ...
                                  makeOdd(min(SG_FRAMES, numel(dt2)-1)))];
                else
                    wz_enc_sm  = wz_enc_raw;
                    acc_enc    = zeros(size(wz_enc_raw));
                end
                step.enc_t   = et(1:end-1);
                step.enc_wz  = wz_enc_sm;
                step.enc_acc = acc_enc;
            else
                step.enc_t = []; step.enc_wz = []; step.enc_acc = [];
            end
        else
            step.enc_t = []; step.enc_wz = []; step.enc_acc = [];
        end

        if isempty(steps)
            steps = step;
        else
            steps(end+1) = step; %#ok<AGROW>
        end
    end

    data(b).valid  = true;
    data(b).label  = BAG_LABELS{b};
    data(b).steps  = steps;
    data(b).color  = COLORS(mod(b-1, size(COLORS,1))+1, :);

    % Determina vel_target e accel predominante per il modo auto
    if has_target && ~isempty(tv_val)
        data(b).vel_target = max(abs(tv_val));
    else
        data(b).vel_target = NaN;
    end

    fprintf('  %d step trovati.\n', numel(steps));
    bag_obj = bag; %#ok — keep reference for info
    clear bag;
end

%% ── 3. Rilevamento automatico modalità ──────────────────────────────────

if strcmp(MODE, 'auto')
    vel_targets = arrayfun(@(d) d.vel_target, data(arrayfun(@(d) d.valid, data)));
    if numel(unique(round(vel_targets,3))) > 1
        MODE_DETECTED = 'velocity';
        fprintf('\nModalità AUTO → VELOCITY SWEEP (vel_target varia tra le bag)\n');
    else
        MODE_DETECTED = 'acceleration';
        fprintf('\nModalità AUTO → ACCELERATION SWEEP (vel_target costante)\n');
    end
else
    MODE_DETECTED = MODE;
end

%% ── 4. Costruisci struttura step per direzione ───────────────────────────
% Raggruppa: LEFT e RIGHT

directions = {'LEFT', 'RIGHT'};

% step_data{d}{b} = struct array degli step di direzione d per bag b
step_data = cell(numel(directions), n_bags);

for b = 1:n_bags
    if ~data(b).valid, continue; end
    for di = 1:numel(directions)
        dir = directions{di};
        idx = arrayfun(@(s) strcmp(s.dir, dir) && strcmp(s.type,'ROTATION'), data(b).steps);
        step_data{di, b} = data(b).steps(idx);
    end
end

%% ── 5. FIGURE ────────────────────────────────────────────────────────────
% Funzioni helper inline definite in fondo al file.

n_dirs = numel(directions);   % 2 (LEFT, RIGHT)

% ── Fig 1/3 : Profili di VELOCITÀ ─────────────────────────────────────────
fig_vel = figure('Name', sprintf('[%s] Profili di velocità', upper(MODE_DETECTED)), ...
                 'NumberTitle','off', 'Position',[50 50 1300 600]);

for di = 1:n_dirs
    ax = subplot(1, n_dirs, di);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    title(ax, directions{di}, 'FontWeight','normal');
    xlabel(ax,'Tempo relativo [s]');
    ylabel(ax,'Velocità angolare [rad/s]');

    for b = 1:n_bags
        if ~data(b).valid, continue; end
        clr = data(b).color;

        steps_b = step_data{di, b};
        if isempty(steps_b), continue; end

        for si = 1:numel(steps_b)
            s = steps_b(si);

            % Target
            if ~isempty(s.target_t)
                h_t = plot(ax, s.target_t, s.target_vel, ...
                           STYLE_TARGET, 'Color', clr, ...
                           'LineWidth', LW_TARGET, ...
                           'HandleVisibility', 'off');
            end

            % ODOM_WCIAS (linea principale)
            if ~isempty(s.wcias_t)
                h_w = plot(ax, s.wcias_t, s.wcias_wz, ...
                           STYLE_WCIAS, 'Color', clr, ...
                           'LineWidth', LW_MEAS, ...
                           'DisplayName', data(b).label);
                % Mostra in legenda solo il primo step per bag
                if si > 1
                    set(h_w,'HandleVisibility','off');
                end
            end

            % ODOM_FILT (più sottile, stessa linea)
            if ~isempty(s.filt_t)
                plot(ax, s.filt_t, s.filt_wz, ...
                     STYLE_FILT, 'Color', clr*0.8, ...
                     'LineWidth', LW_MEAS*0.8, ...
                     'HandleVisibility','off');
            end

            % Linea verticale a t=0 (START event)
            xline(ax, 0,          '--k', 'Alpha',0.3, 'HandleVisibility','off');
            xline(ax, s.t_end - s.t_start, ':k', 'Alpha',0.3, 'HandleVisibility','off');
        end
    end

    legend(ax, 'show', 'Location','best');
    set(ax,'FontSize',10);
end

sgtitle(fig_vel, sprintf('Profili di velocità — %s', ...
        strrep(strrep(MODE_DETECTED,'_',' '),'velocity','Velocity sweep')), ...
        'FontSize',13, 'FontWeight','bold');

addLegendNote(fig_vel, sprintf('%.0s: target (---)   wcias (——)   filt (-·-)',''));

% ── Fig 2/4 : Profili di ACCELERAZIONE ────────────────────────────────────
fig_acc = figure('Name', sprintf('[%s] Profili di accelerazione', upper(MODE_DETECTED)), ...
                 'NumberTitle','off', 'Position',[80 80 1300 600]);

for di = 1:n_dirs
    ax = subplot(1, n_dirs, di);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    title(ax, directions{di}, 'FontWeight','normal');
    xlabel(ax,'Tempo relativo [s]');
    ylabel(ax,'Accelerazione angolare [rad/s²]');

    for b = 1:n_bags
        if ~data(b).valid, continue; end
        clr = data(b).color;

        steps_b = step_data{di, b};
        if isempty(steps_b), continue; end

        for si = 1:numel(steps_b)
            s = steps_b(si);

            % Accelerazione target
            if ~isempty(s.target_t) && ~isempty(s.target_acc)
                plot(ax, s.target_t, s.target_acc, ...
                     STYLE_TARGET, 'Color', clr, ...
                     'LineWidth', LW_TARGET, ...
                     'HandleVisibility','off');
            end

            % Accelerazione da ODOM_WCIAS
            if ~isempty(s.wcias_t) && ~isempty(s.wcias_acc)
                h_w = plot(ax, s.wcias_t, s.wcias_acc, ...
                           STYLE_WCIAS, 'Color', clr, ...
                           'LineWidth', LW_MEAS, ...
                           'DisplayName', data(b).label);
                if si > 1
                    set(h_w,'HandleVisibility','off');
                end
            end

            % Accelerazione da encoder grezzo
            if ~isempty(s.enc_t) && ~isempty(s.enc_acc)
                plot(ax, s.enc_t, s.enc_acc, ...
                     STYLE_ENC, 'Color', clr, ...
                     'LineWidth', LW_ENC, ...
                     'HandleVisibility','off');
            end

            xline(ax, 0,           '--k', 'Alpha',0.3,'HandleVisibility','off');
            xline(ax, s.t_end - s.t_start, ':k', 'Alpha',0.3,'HandleVisibility','off');
        end
    end

    legend(ax,'show','Location','best');
    set(ax,'FontSize',10);
end

sgtitle(fig_acc, sprintf('Profili di accelerazione — %s', ...
        strrep(MODE_DETECTED,'_',' ')), ...
        'FontSize',13,'FontWeight','bold');

addLegendNote(fig_acc, 'target (---)   wcias (——)   encoder (···)   | linee vert.: START (--) / STOP (:)');

% ── Fig 3 extra: tutti gli step sovrapposti per step_idx (solo accel sweep) ──
if strcmp(MODE_DETECTED,'acceleration')
    % Trova tutti gli step_idx unici
    all_idx = [];
    for b = 1:n_bags
        if ~data(b).valid, continue; end
        for di = 1:n_dirs
            ss = step_data{di,b};
            if ~isempty(ss)
                all_idx = union(all_idx, [ss.idx]);
            end
        end
    end

    n_step_idx = numel(all_idx);
    n_cols_s   = min(n_step_idx, 4);
    n_rows_s   = ceil(n_step_idx / n_cols_s);

    fig_sweep = figure('Name','[ACCEL SWEEP] Step sovrapposti — velocità', ...
                       'NumberTitle','off','Position',[110 110 1300 300*n_rows_s]);

    for ii = 1:n_step_idx
        sidx = all_idx(ii);
        ax   = subplot(n_rows_s, n_cols_s, ii);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        title(ax, sprintf('step %d', sidx),'FontWeight','normal');
        xlabel(ax,'t [s]'); ylabel(ax,'wz [rad/s]');

        for b = 1:n_bags
            if ~data(b).valid, continue; end
            clr = data(b).color;

            for di = 1:n_dirs
                ss = step_data{di,b};
                s_match = ss(arrayfun(@(x) x.idx==sidx, ss));
                if isempty(s_match), continue; end
                s = s_match(1);

                ls = {'-','--'};   % LEFT='-', RIGHT='--'
                if ~isempty(s.target_t)
                    plot(ax, s.target_t, s.target_vel, ':', ...
                         'Color', clr, 'LineWidth',1.2,'HandleVisibility','off');
                end
                if ~isempty(s.wcias_t)
                    lbl = sprintf('%s %s', data(b).label, directions{di});
                    plot(ax, s.wcias_t, s.wcias_wz, ls{di}, ...
                         'Color', clr, 'LineWidth',1.5,'DisplayName',lbl);
                end
            end
        end
        xline(ax,0,'--k','Alpha',0.3,'HandleVisibility','off');
        legend(ax,'show','Location','best','FontSize',7);
        set(ax,'FontSize',9);
    end
    sgtitle(fig_sweep,'Confronto velocità per step_idx (accel sweep)', ...
            'FontSize',12,'FontWeight','bold');
end

fprintf('\nPlot completati.\n');

%% ── Funzioni locali ──────────────────────────────────────────────────────

function [direction, step_type] = decodeEventCode(code)
    base = mod(code, 100); %#ok
    cat  = code - base;
    switch cat
        case 100,  direction = 'LEFT';     step_type = 'ROTATION';
        case 200,  direction = 'RIGHT';    step_type = 'ROTATION';
        case 300,  direction = 'FORWARD';  step_type = 'LINEAR';
        case 400,  direction = 'BACKWARD'; step_type = 'LINEAR';
        otherwise, direction = 'UNKNOWN';  step_type = 'UNKNOWN';
    end
end

function nf = makeOdd(n)
%MAKEODD  Restituisce il più vicino intero dispari >= 5.
    nf = max(5, n);
    if mod(nf, 2) == 0, nf = nf - 1; end
end

function addLegendNote(fig, note_str)
%ADDLEGENDNOTE  Aggiunge una nota in basso alla figura.
    annotation(fig, 'textbox', [0, 0, 1, 0.03], ...
               'String', note_str, ...
               'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', ...
               'FontSize', 9, ...
               'Color', [0.5 0.5 0.5]);
end
