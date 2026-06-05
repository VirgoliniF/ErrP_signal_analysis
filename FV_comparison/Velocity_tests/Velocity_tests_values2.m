% =========================================================================
%  analyze_velocity_bags.m
%
%  Batch-processes all .bag files in a selected folder.
%  For each commanded velocity step (decoded from /events/bus), it
%  extracts the odometry response from:
%    - /odometry/filtered      (EKF-filtered)
%    - /wcias_controller/odom  (wheel-encoder)
%  and computes velocity and acceleration statistics per step.
%
%  Outputs:
%    - Summary table printed to the Command Window
%    - results_<timestamp>.xlsx  saved next to the bag files
%
%  Event code convention (matches VelocityTest.cpp):
%    100+i  → LEFT  rotation step i  (start)
%    200+i  → RIGHT rotation step i  (start)
%    300+i  → FWD   linear   step i  (start)
%    400+i  → BWD   linear   step i  (start)
%    code + 32768 → same step, STOP  (VT_CLOSE_MASK)
%    1      → VT_INIT
%    2      → VT_EN
%
%  Requires: ROS Toolbox (rosbag / rosbagreader)
%            MATLAB R2021b+ recommended
% =========================================================================

clear; clc; close all;

%% ── 0. Configuration ────────────────────────────────────────────────────

VT_CLOSE_MASK = 32768;   % must match VelocityTest.h
VT_INIT       = 1;
VT_END        = 2;

% Odometry topics to analyse
ODOM_TOPICS = {'/odometry/filtered', '/wcias_controller/odom'};
ODOM_LABELS = {'ODOM_FILT',          'ODOM_WCIAS'};

% Topic that carries velocity commands
CMD_TOPIC    = '/gui/cmd_vel';
EVENT_TOPIC  = '/events/bus';

% Acceleration smoothing: Savitzky-Golay filter parameters
%   (applied before differentiating to reduce noise)
SG_ORDER  = 3;   % polynomial order
SG_FRAMES = 11;  % frame length (must be odd, >= order+1)

%% ── 1. Select folder ────────────────────────────────────────────────────

bag_dir = uigetdir(pwd, 'Select folder containing .bag files');
if isequal(bag_dir, 0)
    disp('Cancelled.'); return
end

bag_files = dir(fullfile(bag_dir, '*.bag'));
if isempty(bag_files)
    error('No .bag files found in: %s', bag_dir);
end
fprintf('Found %d bag file(s) in %s\n\n', numel(bag_files), bag_dir);

%% ── 2. Allocate results storage ─────────────────────────────────────────

% Each row of the results table corresponds to one step in one bag file.
all_results = {};   % will be converted to a table at the end

%% ── 3. Process each bag ─────────────────────────────────────────────────

for b = 1:numel(bag_files)
    bag_path = fullfile(bag_files(b).folder, bag_files(b).name);
    fprintf('==========================================================\n');
    fprintf('Bag %d/%d : %s\n', b, numel(bag_files), bag_files(b).name);
    fprintf('==========================================================\n');

    try
        bag = rosbag(bag_path);
    catch ME
        warning('Could not open bag: %s\nReason: %s', bag_path, ME.message);
        continue
    end

    % ── 3a. Read events ───────────────────────────────────────────────────
    try
        sel_ev  = select(bag, 'Topic', EVENT_TOPIC);
        ev_msgs = readMessages(sel_ev, 'DataFormat', 'struct');
    catch
        warning('Topic %s not found in %s — skipping.', EVENT_TOPIC, bag_files(b).name);
        continue
    end

    ev_times  = cell2mat(cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                                      double(m.Header.Stamp.Nsec)*1e-9, ...
                                 ev_msgs, 'UniformOutput', false));
    ev_codes  = cell2mat(cellfun(@(m) double(m.Event), ...
                                 ev_msgs, 'UniformOutput', false));

    % ── 3b. Read cmd_vel ──────────────────────────────────────────────────
    try
        sel_cmd  = select(bag, 'Topic', CMD_TOPIC);
        cmd_msgs = readMessages(sel_cmd, 'DataFormat', 'struct');
        cmd_times = bagTimeSeries(sel_cmd);   % timestamps [s]
        cmd_linx  = cell2mat(cellfun(@(m) m.Linear.X,  cmd_msgs, 'UniformOutput', false));
        cmd_angz  = cell2mat(cellfun(@(m) m.Angular.Z, cmd_msgs, 'UniformOutput', false));
    catch
        warning('Topic %s not found in %s.', CMD_TOPIC, bag_files(b).name);
        cmd_times = []; cmd_linx = []; cmd_angz = [];
    end

    % ── 3c. Read odometry ─────────────────────────────────────────────────
    odom_data = struct();
    for od = 1:numel(ODOM_TOPICS)
        label = ODOM_LABELS{od};
        try
            sel_od   = select(bag, 'Topic', ODOM_TOPICS{od});
            od_msgs  = readMessages(sel_od, 'DataFormat', 'struct');
            od_times = cell2mat(cellfun(@(m) double(m.Header.Stamp.Sec) + ...
                                             double(m.Header.Stamp.Nsec)*1e-9, ...
                                        od_msgs, 'UniformOutput', false));
            od_vx    = cell2mat(cellfun(@(m) double(m.Twist.Twist.Linear.X),  od_msgs, 'UniformOutput', false));
            od_wz    = cell2mat(cellfun(@(m) double(m.Twist.Twist.Angular.Z), od_msgs, 'UniformOutput', false));

            odom_data.(label).times = double(od_times(:));
            odom_data.(label).vx    = double(od_vx(:));
            odom_data.(label).wz    = double(od_wz(:));
        catch
            warning('Topic %s not found — skipping for this bag.', ODOM_TOPICS{od});
            odom_data.(label).times = [];
            odom_data.(label).vx    = [];
            odom_data.(label).wz    = [];
        end
    end

    % ── 3d. Pair START/STOP events into steps ─────────────────────────────
    % START codes: any code not equal to VT_INIT, VT_END, or a STOP code
    start_mask = (ev_codes ~= VT_INIT) & ...
                 (ev_codes ~= VT_END)  & ...
                 (ev_codes  < VT_CLOSE_MASK);
    start_idx  = find(start_mask);

    if isempty(start_idx)
        warning('No step events found in %s.', bag_files(b).name);
        continue
    end

    for si = 1:numel(start_idx)
        ii         = start_idx(si);
        start_code = ev_codes(ii);
        stop_code  = start_code + VT_CLOSE_MASK;
        t_start    = ev_times(ii);

        % Find matching STOP event
        stop_ev = find(ev_codes == stop_code & ev_times > t_start, 1, 'first');
        if isempty(stop_ev)
            t_stop = t_start + 10;   % fallback: 10 s window
            warning('No STOP event for code %d — using 10 s window.', start_code);
        else
            t_stop = ev_times(stop_ev);
        end

        step_dur = t_stop - t_start;

        % Decode step label from event code
        [direction, step_type] = decodeEventCode(start_code);

        % ── Commanded velocity during this step ───────────────────────
        cmd_lin_cmd = NaN;
        cmd_ang_cmd = NaN;
        if ~isempty(cmd_times)
            in_win = cmd_times >= t_start & cmd_times <= t_stop;
            if any(in_win)
                cmd_lin_cmd = median(cmd_linx(in_win));
                cmd_ang_cmd = median(cmd_angz(in_win));
            end
        end

        % ── Per-odometry-source stats ──────────────────────────────────
        for od = 1:numel(ODOM_LABELS)
            label = ODOM_LABELS{od};
            od_t  = odom_data.(label).times;
            od_vx = odom_data.(label).vx;
            od_wz = odom_data.(label).wz;

            if isempty(od_t)
                continue
            end

            in_win = od_t >= t_start & od_t <= t_stop;
            t_w    = od_t(in_win);
            vx_w   = od_vx(in_win);
            wz_w   = od_wz(in_win);

            if numel(t_w) < 4
                % Not enough samples for this window
                row = makeRow(bag_files(b).name, label, start_code, ...
                              direction, step_type, step_dur, ...
                              cmd_lin_cmd, cmd_ang_cmd, ...
                              NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN);
                all_results{end+1} = row; %#ok<SAGROW>
                continue
            end

            % Steady-state: middle 60% of the window
            t_rel  = t_w - t_w(1);
            t_ss1  = 0.2 * t_rel(end);
            t_ss2  = 0.8 * t_rel(end);
            ss_idx = t_rel >= t_ss1 & t_rel <= t_ss2;

            vx_mean = mean(vx_w(ss_idx));
            vx_std  = std(vx_w(ss_idx));
            wz_mean = mean(wz_w(ss_idx));
            wz_std  = std(wz_w(ss_idx));

            % Acceleration: differentiate, smooth with Savitzky-Golay
            % Ensure all arrays are double (ROS msgs may carry int32/single)
            t_w  = double(t_w);
            vx_w = double(vx_w);
            wz_w = double(wz_w);

            dt_vec = diff(t_w);
            dt_vec(dt_vec < 1e-9) = 1e-9;   % guard /0

            ax_raw = diff(vx_w) ./ dt_vec;
            az_raw = diff(wz_w) ./ dt_vec;

            % Apply SG filter if enough points
            nf = min(SG_FRAMES, 2*floor((numel(ax_raw)-1)/2)-1);
            nf = max(nf, SG_ORDER+2);
            if mod(nf,2)==0, nf = nf-1; end

            if numel(ax_raw) >= nf
                ax_sm = sgolayfilt(ax_raw, SG_ORDER, nf);
                az_sm = sgolayfilt(az_raw, SG_ORDER, nf);
            else
                ax_sm = ax_raw;
                az_sm = az_raw;
            end

            ax_peak = max(abs(ax_sm));
            az_peak = max(abs(az_sm));
            ax_mean = mean(ax_sm);
            az_mean = mean(az_sm);

            row = makeRow(bag_files(b).name, label, start_code, ...
                          direction, step_type, step_dur, ...
                          cmd_lin_cmd, cmd_ang_cmd, ...
                          vx_mean, vx_std, wz_mean, wz_std, ...
                          ax_peak, az_peak, ax_mean, az_mean);
            all_results{end+1} = row; %#ok<SAGROW>
        end % odom loop
    end % step loop

    fprintf('  Processed %d steps.\n\n', numel(start_idx));
end % bag loop

%% ── 4. Assemble and display results table ────────────────────────────────

if isempty(all_results)
    disp('No results to show.'); return
end

T = vertcat(all_results{:});
T = struct2table(T);

disp('==========================================================');
disp('                  RESULTS SUMMARY');
disp('==========================================================');
disp(T);

%% ── 5. Export to Excel ───────────────────────────────────────────────────

ts       = datestr(now, 'yyyymmdd_HHMMSS');
out_path = fullfile(bag_dir, ['results_' ts '.xlsx']);

writetable(T, out_path, 'Sheet', 'VelocityTest');
fprintf('\nResults saved to:\n  %s\n', out_path);

% ── Auto-format the Excel file (column widths) ───────────────────────────
try
    e   = actxserver('Excel.Application');
    wb  = e.Workbooks.Open(out_path);
    ws  = wb.Sheets.Item('VelocityTest');
    ws.Columns.AutoFit();
    wb.Save();
    wb.Close();
    e.Quit();
    delete(e);
catch
    % actxserver not available (non-Windows); skip formatting silently
end

fprintf('Done.\n');

% =========================================================================
%  Local helpers
% =========================================================================

function [direction, step_type] = decodeEventCode(code)
%DECODEEVENTCODE  Map event code → human-readable direction & type strings.
    base = mod(code, 100);  %#ok — step index, unused here
    cat  = code - base;     % 100, 200, 300, or 400
    switch cat
        case 100,  direction = 'LEFT';     step_type = 'ROTATION';
        case 200,  direction = 'RIGHT';    step_type = 'ROTATION';
        case 300,  direction = 'FORWARD';  step_type = 'LINEAR';
        case 400,  direction = 'BACKWARD'; step_type = 'LINEAR';
        otherwise, direction = 'UNKNOWN';  step_type = 'UNKNOWN';
    end
end

function row = makeRow(bag_name, odom_src, event_code, ...
                        direction, step_type, duration, ...
                        cmd_lin, cmd_ang, ...
                        vx_mean, vx_std, wz_mean, wz_std, ...
                        ax_peak, az_peak, ax_mean, az_mean)
%MAKEROW  Package one step result into a struct (will become a table row).
    row.BagFile      = string(bag_name);
    row.OdomSource   = string(odom_src);
    row.EventCode    = event_code;
    row.Direction    = string(direction);
    row.StepType     = string(step_type);
    row.Duration_s   = duration;
    row.Cmd_LinX_ms  = cmd_lin;        % m/s
    row.Cmd_AngZ_rads= cmd_ang;        % rad/s
    row.Meas_Vx_mean = vx_mean;        % m/s
    row.Meas_Vx_std  = vx_std;
    row.Meas_Wz_mean = wz_mean;        % rad/s
    row.Meas_Wz_std  = wz_std;
    row.Accel_LinX_peak  = ax_peak;    % m/s²
    row.Accel_AngZ_peak  = az_peak;    % rad/s²
    row.Accel_LinX_mean  = ax_mean;
    row.Accel_AngZ_mean  = az_mean;
end

function t = bagTimeSeries(sel)
%BAGTIMESERIES  Return timestamps [s] for a rosbag selection.
    info = sel.MessageList;
    t    = info.Time;   % already in seconds as a double
end