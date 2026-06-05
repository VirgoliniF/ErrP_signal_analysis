% =========================================================================
%  analyze_ramp_slopes.m
%
%  Extension of analyze_velocity_bags.m.
%  For each commanded velocity step it extracts:
%    1. Steady-state velocity statistics (same as before)
%    2. RAMP-UP slope  [rad/s²] — linear fit on the rising edge
%    3. RAMP-DOWN slope [rad/s²] — linear fit on the falling edge
%    4. Time-to-target [s]       — how long the ramp-up took
%    5. R-Net scale factors      — k_speed and k_accel per profile
%
%  The ramp is detected by thresholding |wz| between RAMP_LOW_FRAC and
%  RAMP_HIGH_FRAC of the step's peak velocity, then fitting a line.
%
%  Outputs:
%    - Summary table printed to the Command Window
%    - ramp_results_<timestamp>.xlsx  saved next to the bag files
%    - One figure per bag: time-series + detected ramp regions
%
%  Event code convention (matches VelocityTest.cpp):
%    100+i → LEFT   rotation step i (start)
%    200+i → RIGHT  rotation step i (start)
%    code + 32768   → STOP
%    1 → VT_INIT,  2 → VT_END
%
%  Requires: ROS Toolbox, Signal Processing Toolbox (sgolayfilt),
%            MATLAB R2021b+
% =========================================================================

clear; clc; close all;

%% ── 0. Configuration ────────────────────────────────────────────────────

VT_CLOSE_MASK = 32768;
VT_INIT       = 1;
VT_END        = 2;

ODOM_TOPICS = {'/odometry/filtered', '/wcias_controller/odom'};
ODOM_LABELS = {'ODOM_FILT',          'ODOM_WCIAS'};

CMD_TOPIC   = '/gui/cmd_vel';
EVENT_TOPIC = '/events/bus';

% ── Ramp detection thresholds ────────────────────────────────────────────
% Ramp-up   fitted between RAMP_LOW_FRAC  and RAMP_HIGH_FRAC of peak |wz|
% Ramp-down fitted between RAMP_HIGH_FRAC and RAMP_LOW_FRAC  (reversed)
RAMP_LOW_FRAC  = 0.10;   % 10% of peak — avoids dead-band at start
RAMP_HIGH_FRAC = 0.85;   % 85% of peak — avoids plateau saturation

% Minimum number of samples required inside the ramp window to attempt fit
MIN_RAMP_SAMPLES = 5;

% Savitzky-Golay parameters for acceleration estimation
SG_ORDER  = 3;
SG_FRAMES = 11;

% R-Net profile units for each bag (edit to match your recordings)
% Order must match the bags as they are sorted in the selected folder.
% Set to NaN if unknown — scale factors will be skipped for that bag.
% Profile 1: max_speed=11, accel=13, decel=14
% Profile 2: max_speed=10, accel=15, decel=5
% Profile 3: max_speed=20, accel=15, decel=10
RNET_PROFILE_UNITS = struct( ...
    'bag_substring', {'15-13-49', '15-17-31', '15-18-35', '15-24-26'}, ...
    'profile_name',  {'Profile2', 'DISCARD',  'Profile3', 'Profile1'}, ...
    'max_speed',     {10,          NaN,         20,         11},        ...
    'accel_units',   {15,          NaN,         15,         13},        ...
    'decel_units',   {5,           NaN,         10,         14}         ...
);

% Set to true to show per-step time-series plots
PLOT_STEPS = true;

%% ── 1. Select folder ────────────────────────────────────────────────────

bag_dir = uigetdir(pwd, 'Select folder containing .bag files');
if isequal(bag_dir, 0), disp('Cancelled.'); return; end

bag_files = dir(fullfile(bag_dir, '*.bag'));
if isempty(bag_files)
    error('No .bag files found in: %s', bag_dir);
end
fprintf('Found %d bag file(s) in %s\n\n', numel(bag_files), bag_dir);

%% ── 2. Allocate results ─────────────────────────────────────────────────

all_results = {};

%% ── 3. Process each bag ─────────────────────────────────────────────────

for b = 1:numel(bag_files)

    bag_path = fullfile(bag_files(b).folder, bag_files(b).name);
    bag_name = bag_files(b).name;
    fprintf('==========================================================\n');
    fprintf('Bag %d/%d : %s\n', b, numel(bag_files), bag_name);
    fprintf('==========================================================\n');

    % ── Match to R-Net profile ────────────────────────────────────────────
    rnet = struct('profile_name','UNKNOWN','max_speed',NaN, ...
                  'accel_units',NaN,'decel_units',NaN);
    for p = 1:numel(RNET_PROFILE_UNITS)
        if contains(bag_name, RNET_PROFILE_UNITS(p).bag_substring)
            rnet = RNET_PROFILE_UNITS(p);
            break
        end
    end
    fprintf('  R-Net profile : %s  (max_speed=%g, accel=%g, decel=%g)\n', ...
            rnet.profile_name, rnet.max_speed, rnet.accel_units, rnet.decel_units);

    if strcmp(rnet.profile_name, 'DISCARD')
        fprintf('  Skipping (marked DISCARD).\n\n');
        continue
    end

    % ── Open bag ─────────────────────────────────────────────────────────
    try
        bag = rosbag(bag_path);
    catch ME
        warning('Could not open bag: %s\n%s', bag_path, ME.message);
        continue
    end

    % ── Read events ───────────────────────────────────────────────────────
    try
        sel_ev  = select(bag, 'Topic', EVENT_TOPIC);
        ev_msgs = readMessages(sel_ev, 'DataFormat', 'struct');
    catch
        warning('Event topic not found — skipping bag.');
        continue
    end

    ev_times = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                             double(m.Header.Stamp.Nsec)*1e-9, ev_msgs);
    ev_codes = cellfun(@(m) double(m.Event), ev_msgs);

    % ── Read cmd_vel ──────────────────────────────────────────────────────
    cmd_times = []; cmd_angz = [];
    try
        sel_cmd  = select(bag, 'Topic', CMD_TOPIC);
        cmd_msgs = readMessages(sel_cmd, 'DataFormat', 'struct');
        cmd_info = sel_cmd.MessageList;
        cmd_times = cmd_info.Time;
        cmd_angz  = cellfun(@(m) double(m.Angular.Z), cmd_msgs);
    catch
        warning('cmd_vel topic not found.');
    end

    % ── Read odometry ─────────────────────────────────────────────────────
    odom_data = struct();
    for od = 1:numel(ODOM_TOPICS)
        lbl = ODOM_LABELS{od};
        try
            sel_od  = select(bag, 'Topic', ODOM_TOPICS{od});
            od_msgs = readMessages(sel_od, 'DataFormat', 'struct');
            od_t    = cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                                   double(m.Header.Stamp.Nsec)*1e-9, od_msgs);
            od_wz   = cellfun(@(m) double(m.Twist.Twist.Angular.Z), od_msgs);
            odom_data.(lbl).t  = od_t(:);
            odom_data.(lbl).wz = od_wz(:);
        catch
            odom_data.(lbl).t  = [];
            odom_data.(lbl).wz = [];
        end
    end

    % ── Find START events ─────────────────────────────────────────────────
    start_mask = ev_codes ~= VT_INIT & ev_codes ~= VT_END & ...
                 ev_codes  < VT_CLOSE_MASK;
    start_idx  = find(start_mask);

    if isempty(start_idx)
        warning('No step events found.'); continue
    end

    % ── Figure for this bag ───────────────────────────────────────────────
    if PLOT_STEPS
        fig = figure('Name', bag_name, 'NumberTitle', 'off', ...
                     'Position', [50 50 1400 700]);
        n_steps = numel(start_idx);
        n_cols  = ceil(sqrt(n_steps * 2));
        n_rows  = ceil(n_steps * 2 / n_cols);
        subplot_idx = 0;
    end

    % ── Process each step ─────────────────────────────────────────────────
    for si = 1:numel(start_idx)
        ii         = start_idx(si);
        start_code = ev_codes(ii);
        stop_code  = start_code + VT_CLOSE_MASK;
        t_start    = ev_times(ii);

        stop_ev = find(ev_codes == stop_code & ev_times > t_start, 1);
        t_stop  = t_start + 10;
        if ~isempty(stop_ev), t_stop = ev_times(stop_ev); end

        [direction, step_type] = decodeEventCode(start_code);

        % Commanded angular velocity for this step
        cmd_ang = NaN;
        if ~isempty(cmd_times)
            in_w = cmd_times >= t_start & cmd_times <= t_stop;
            if any(in_w), cmd_ang = median(cmd_angz(in_w)); end
        end

        % ── Per-odometry-source analysis ──────────────────────────────────
        for od = 1:numel(ODOM_LABELS)
            lbl  = ODOM_LABELS{od};
            od_t = odom_data.(lbl).t;
            od_w = odom_data.(lbl).wz;

            if isempty(od_t), continue; end

            in_win = od_t >= t_start & od_t <= t_stop;
            t_w    = od_t(in_win);
            wz_w   = od_w(in_win);

            if numel(t_w) < MIN_RAMP_SAMPLES
                all_results{end+1} = makeRow( ...
                    bag_name, rnet.profile_name, lbl, start_code, ...
                    direction, step_type, t_stop - t_start, cmd_ang, ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN);
                continue
            end

            % Relative time and absolute wz
            t_rel  = t_w - t_w(1);
            wz_abs = abs(wz_w);
            wz_peak = max(wz_abs);

            % ── Steady state: middle 60% ───────────────────────────────
            ss_lo  = 0.20 * t_rel(end);
            ss_hi  = 0.80 * t_rel(end);
            ss_idx = t_rel >= ss_lo & t_rel <= ss_hi;
            wz_ss_mean = mean(wz_abs(ss_idx));
            wz_ss_std  = std(wz_abs(ss_idx));

            % ── RAMP-UP detection ──────────────────────────────────────
            % Region where |wz| rises from LOW to HIGH fraction of peak
            lo_thr = RAMP_LOW_FRAC  * wz_peak;
            hi_thr = RAMP_HIGH_FRAC * wz_peak;

            up_idx = find(wz_abs >= lo_thr & wz_abs <= hi_thr & ...
                          t_rel  <= 0.5 * t_rel(end));   % first half only

            [slope_up, t2t, fit_up_t, fit_up_y] = fitRamp(t_rel, wz_abs, up_idx);

            % Time-to-target: extrapolate fit to wz_peak
            if ~isnan(slope_up) && slope_up > 0
                t2t = (wz_peak - fit_up_y(1)) / slope_up;
            else
                t2t = NaN;
            end

            % ── RAMP-DOWN detection ────────────────────────────────────
            % Region where |wz| falls from HIGH to LOW, in second half
            dn_idx = find(wz_abs >= lo_thr & wz_abs <= hi_thr & ...
                          t_rel  >= 0.5 * t_rel(end));   % second half

            [slope_dn, ~, fit_dn_t, fit_dn_y] = fitRamp(t_rel, wz_abs, dn_idx);
            % slope_dn will be negative; store magnitude
            slope_dn_mag = abs(slope_dn);

            % ── R-Net scale factors ────────────────────────────────────
            k_speed = NaN;
            k_accel = NaN;
            k_decel = NaN;
            if ~isnan(rnet.max_speed) && rnet.max_speed > 0
                k_speed = wz_ss_mean / rnet.max_speed;
            end
            if ~isnan(slope_up) && ~isnan(rnet.accel_units) && rnet.accel_units > 0
                k_accel = slope_up / rnet.accel_units;
            end
            if ~isnan(slope_dn_mag) && ~isnan(rnet.decel_units) && rnet.decel_units > 0
                k_decel = slope_dn_mag / rnet.decel_units;
            end

            fprintf(['  [%s | %s | %s | code=%d]  '...
                     'cmd=%.3f rad/s  ss=%.4f rad/s  '...
                     'slope_up=%.4f rad/s²  slope_dn=%.4f rad/s²  '...
                     't2t=%.3f s  k_speed=%.4f  k_accel=%.4f\n'], ...
                    lbl, direction, step_type, start_code, ...
                    cmd_ang, wz_ss_mean, slope_up, slope_dn_mag, t2t, ...
                    k_speed, k_accel);

            % ── Store result ───────────────────────────────────────────
            all_results{end+1} = makeRow( ...
                bag_name, rnet.profile_name, lbl, start_code, ...
                direction, step_type, t_stop - t_start, cmd_ang, ...
                wz_ss_mean, wz_ss_std, slope_up, slope_dn_mag, t2t, ...
                k_speed, k_accel, k_decel);

            % ── Plot ───────────────────────────────────────────────────
            if PLOT_STEPS
                subplot_idx = subplot_idx + 1;
                ax = subplot(n_rows, n_cols, subplot_idx, 'Parent', fig);
                hold(ax, 'on');

                plot(ax, t_rel, wz_abs, 'b-', 'LineWidth', 1.2);

                % Ramp-up fit
                if ~isempty(fit_up_t)
                    plot(ax, fit_up_t, fit_up_y, 'r-', 'LineWidth', 2);
                end
                % Ramp-down fit
                if ~isempty(fit_dn_t)
                    plot(ax, fit_dn_t, fit_dn_y, 'm-', 'LineWidth', 2);
                end

                % Threshold lines
                yline(ax, lo_thr, '--k', 'LineWidth', 0.8);
                yline(ax, hi_thr, '--k', 'LineWidth', 0.8);

                xlabel(ax, 'Time [s]');
                ylabel(ax, '|wz| [rad/s]');
                title(ax, sprintf('%s | %s | cmd=%.2f\nslope↑=%.3f  slope↓=%.3f  k_{spd}=%.3f', ...
                      lbl, direction, cmd_ang, slope_up, slope_dn_mag, k_speed), ...
                      'FontSize', 7, 'Interpreter', 'none');
                legend(ax, {'measured','ramp-up fit','ramp-dn fit'}, ...
                       'FontSize', 6, 'Location', 'best');
                grid(ax, 'on');
            end

        end % odom loop
    end % step loop

    if PLOT_STEPS
        sgtitle(fig, strrep(bag_name, '_', '\_'), 'Interpreter', 'tex');
        drawnow;
    end

    fprintf('  Processed %d steps.\n\n', numel(start_idx));
end % bag loop

%% ── 4. Assemble results table ────────────────────────────────────────────

if isempty(all_results)
    disp('No results to show.'); return
end

T = struct2table(vertcat(all_results{:}));

disp('==========================================================');
disp('                  RAMP SLOPE RESULTS');
disp('==========================================================');
disp(T);

%% ── 5. Scale factor summary across profiles ─────────────────────────────

fprintf('\n==========================================================\n');
fprintf('   R-Net Scale Factor Summary (ODOM_WCIAS, ROTATION only)\n');
fprintf('==========================================================\n');

profiles = unique(T.Profile);
for p = 1:numel(profiles)
    pname = profiles(p);
    if strcmp(pname, 'DISCARD') || strcmp(pname, 'UNKNOWN'), continue; end

    mask = strcmp(T.Profile, pname) & ...
           strcmp(T.OdomSource, 'ODOM_WCIAS') & ...
           strcmp(T.StepType, 'ROTATION');

    k_spd = T.K_Speed(mask);
    k_acc = T.K_Accel(mask);
    k_dec = T.K_Decel(mask);

    k_spd = k_spd(~isnan(k_spd));
    k_acc = k_acc(~isnan(k_acc));
    k_dec = k_dec(~isnan(k_dec));

    fprintf('\n  %s\n', pname);
    if ~isempty(k_spd)
        fprintf('    k_speed  = %.5f ± %.5f  rad/s per R-Net unit\n', ...
                mean(k_spd), std(k_spd));
        fprintf('    → max_speed needed for 1.0 rad/s : %.1f units\n', ...
                1.0 / mean(k_spd));
        fprintf('    → max_speed needed for 0.2 rad/s : %.1f units  (min useful)\n', ...
                0.2 / mean(k_spd));
    end
    if ~isempty(k_acc)
        fprintf('    k_accel  = %.5f ± %.5f  rad/s² per R-Net unit\n', ...
                mean(k_acc), std(k_acc));
        fprintf('    → accel units for 0.5 rad/s² ramp: %.1f\n', ...
                0.5 / mean(k_acc));
    end
    if ~isempty(k_dec)
        fprintf('    k_decel  = %.5f ± %.5f  rad/s² per R-Net unit\n', ...
                mean(k_dec), std(k_dec));
    end
end

%% ── 6. Profile 4 recommendation ─────────────────────────────────────────

fprintf('\n==========================================================\n');
fprintf('   Profile 4 Recommendation\n');
fprintf('==========================================================\n');

% Use weighted average of all available k values
wcias_rot = strcmp(T.OdomSource,'ODOM_WCIAS') & strcmp(T.StepType,'ROTATION');
k_spd_all = T.K_Speed(wcias_rot);
k_acc_all = T.K_Accel(wcias_rot);
k_dec_all = T.K_Decel(wcias_rot);

k_spd_all = k_spd_all(~isnan(k_spd_all));
k_acc_all = k_acc_all(~isnan(k_acc_all));
k_dec_all = k_dec_all(~isnan(k_dec_all));

if ~isempty(k_spd_all)
    k_s = mean(k_spd_all);
    rec_max_speed = round(1.0 / k_s);
    fprintf('  Mean k_speed = %.5f rad/s per unit\n', k_s);
    fprintf('  → Recommended max_speed (for 1.0 rad/s) : %d\n', rec_max_speed);
    fprintf('  → Recommended min_speed (symmetric)      : %d\n', rec_max_speed);
end
if ~isempty(k_acc_all)
    k_a = mean(k_acc_all);
    fprintf('  Mean k_accel = %.5f rad/s² per unit\n', k_a);
    fprintf('  → accel units for 0.3 rad/s² : %.1f\n', 0.3 / k_a);
    fprintf('  → accel units for 0.5 rad/s² : %.1f\n', 0.5 / k_a);
    fprintf('  → accel units for 1.0 rad/s² : %.1f\n', 1.0 / k_a);
end
if ~isempty(k_dec_all)
    k_d = mean(k_dec_all);
    fprintf('  Mean k_decel = %.5f rad/s² per unit\n', k_d);
    fprintf('  → decel units for 0.3 rad/s² : %.1f\n', 0.3 / k_d);
    fprintf('  → decel units for 0.5 rad/s² : %.1f\n', 0.5 / k_d);
end

%% ── 7. Save to Excel ─────────────────────────────────────────────────────

ts       = datestr(now, 'yyyymmdd_HHMMSS');
out_path = fullfile(bag_dir, ['ramp_results_' ts '.xlsx']);
writetable(T, out_path, 'Sheet', 'RampSlopes');
fprintf('\nResults saved to:\n  %s\n', out_path);

try
    e  = actxserver('Excel.Application');
    wb = e.Workbooks.Open(out_path);
    ws = wb.Sheets.Item('RampSlopes');
    ws.Columns.AutoFit();
    wb.Save(); wb.Close(); e.Quit(); delete(e);
catch
    % Non-Windows: skip formatting
end

fprintf('Done.\n');

% =========================================================================
%  Local helpers
% =========================================================================

function [slope, t2t, fit_t, fit_y] = fitRamp(t_rel, wz_abs, region_idx)
%FITRAMP  Linear fit over a detected ramp region.
%  Returns slope [rad/s²], time-to-target [s], and fit line coordinates.
    slope = NaN; t2t = NaN; fit_t = []; fit_y = [];
    if numel(region_idx) < 5, return; end

    t_r = t_rel(region_idx);
    w_r = wz_abs(region_idx);

    % Robust linear fit
    p       = polyfit(t_r, w_r, 1);
    slope   = p(1);          % [rad/s²]
    fit_t   = [t_r(1); t_r(end)];
    fit_y   = polyval(p, fit_t);
    t2t     = NaN;           % caller fills this in for ramp-up
end

function [direction, step_type] = decodeEventCode(code)
    base = mod(code, 100);  %#ok
    cat  = code - base;
    switch cat
        case 100,  direction = 'LEFT';     step_type = 'ROTATION';
        case 200,  direction = 'RIGHT';    step_type = 'ROTATION';
        case 300,  direction = 'FORWARD';  step_type = 'LINEAR';
        case 400,  direction = 'BACKWARD'; step_type = 'LINEAR';
        otherwise, direction = 'UNKNOWN';  step_type = 'UNKNOWN';
    end
end

function row = makeRow(bag_name, profile, odom_src, event_code, ...
                        direction, step_type, duration, cmd_ang, ...
                        wz_ss_mean, wz_ss_std, slope_up, slope_dn, t2t, ...
                        k_speed, k_accel, k_decel)
    row.BagFile      = string(bag_name);
    row.Profile      = string(profile);
    row.OdomSource   = string(odom_src);
    row.EventCode    = event_code;
    row.Direction    = string(direction);
    row.StepType     = string(step_type);
    row.Duration_s   = duration;
    row.Cmd_AngZ_rads = cmd_ang;
    row.Wz_SS_mean   = wz_ss_mean;    % rad/s  steady-state mean
    row.Wz_SS_std    = wz_ss_std;     % rad/s  steady-state std
    row.Slope_Up     = slope_up;      % rad/s² ramp-up slope
    row.Slope_Down   = slope_dn;      % rad/s² ramp-down slope magnitude
    row.Time2Target  = t2t;           % s      time to reach peak from ramp start
    row.K_Speed      = k_speed;       % (rad/s) / R-Net unit
    row.K_Accel      = k_accel;       % (rad/s²) / R-Net unit
    row.K_Decel      = k_decel;       % (rad/s²) / R-Net unit
end