function out = pidlag_eval(ctrl, x, seed, csvFile)
%PIDLAG_EVAL Evaluate ONE PIDOpt / PIDLag design on the calibration case CALIB: linear screen first (cheap), then the simulation (one calib_run).
%
%   out = pidlag_eval(ctrl, x, seed, csvFile)
%     ctrl    'PIDOpt' (x = [Kp, Ki, Kd, Tf]) or 'PIDLag' (x = [Kp, Ki, Kd, Tf, z1, p1/z1]); Kp, Ki [1/s], Kd [s], Tf [s], lag z1, p1 [rad/s]; Kaw = Ki/Kp
%     seed    run seed of the sensor noise (tuning seed 10000, check seed 10001: the PID family seed, so the result is comparable with PI and PID)
%     csvFile optional: every evaluation is appended as one row (resumable: a design already in the file is returned from it, not simulated again)
%   Same method and constraints as MapPID (mappid_eval.m, DieuKhien_MapPID.txt C3, D13, D14): while searching, linear PM > 0 and GM >= 1 over the 68 plants,
%   lag gain at 2 Hz >= 0.707 (steering band, QuyChuan 6.2), e_rel <= 5 % on the 9 static windows (QuyChuan 5.3); Tf <= 79.6 ms holds by the bound (20 ms).
%   out.c = [PM_min - PM, GM_min - GM, g_lag_min - lagGain2Hz, erel - 5] (feasible when all <= 0); out.J = R*S [% N.m], Inf when a constraint fails or
%   when the simulation was not run; out.R, S, TV, erel, rev, PM, GM, HF, lagGain2Hz, simulated. The simulation margin gate (calib_margin) is run only for the final candidates.
if nargin < 3 || isempty(seed), seed = 10000; end
if nargin < 4, csvFile = ''; end
persistent Gj w
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
x = x(:)';
nx = 4 + 2 * strcmp(ctrl, 'PIDLag');
assert(numel(x) == nx, 'x must have %d entries for %s', nx, ctrl);
names = {'Kp', 'Ki', 'Kd', 'Tf', 'z1', 'p1_over_z1'};
names = names(1:nx);
PMmin = 0; GMmin = 1; gLagMin = 1 / sqrt(2); erelMax = 5; Ts = 1e-3;

if ~isempty(csvFile) && exist(csvFile, 'file')
    T = readtable(csvFile);
    hit = T.seed == seed;
    for i = 1:nx, hit = hit & abs(T.(names{i}) - x(i)) <= 1e-9 * max(1, abs(x(i))); end
    if any(hit)
        r = T(find(hit, 1), :);
        out = struct('x', x, 'seed', seed, 'J', r.J, 'R', r.R_pct, 'S', r.S_Nm, 'TV', r.TV, 'erel', r.erel_pct, 'rev', r.rev_pct, 'PM', r.PM_deg, 'GM', r.GM, ...
            'HF', r.HF, 'lagGain2Hz', r.lagGain2Hz, 'simulated', r.simulated, 'c', [r.c1 r.c2 r.c3 r.c4], 'cached', true);
        return;
    end
end

if isempty(Gj), [Gj, w] = mappid_plants(); end
d = xToDesign(ctrl, x, Ts);
w2 = 2 * pi * 2;
lagGain = 1;
if isfield(d, 'lag'), lagGain = abs((1 + 1i * w2 / d.lag.z1) / (1 + 1i * w2 / d.lag.p1)); end
c = [0 0 0 0];
out = struct('x', x, 'seed', seed, 'J', Inf, 'R', NaN, 'S', NaN, 'TV', NaN, 'erel', NaN, 'rev', NaN, 'PM', NaN, 'GM', NaN, 'HF', NaN, ...
    'lagGain2Hz', lagGain, 'simulated', 0, 'c', c, 'cached', false);
tStart = tic;

bad = isfield(d, 'lag') && (d.lag.p1 < 3 || d.lag.p1 > d.lag.z1 + 1e-9);
R = pidlag_margins(Gj, w, d);
out.PM = R.PM; out.GM = R.GM; out.HF = R.HF;
PMeff = R.PM; if ~R.stable, PMeff = -180; end
c(1) = PMmin - PMeff; c(2) = GMmin - R.GM; c(3) = gLagMin - lagGain;
out.c = c;
if bad || any(c(1:3) > 0)
    if bad, out.c(3) = max(out.c(3), 1); end
    finish(); return;
end

if ~evalin('base', sprintf('exist(''%s_Kp'', ''var'')', ctrl))
    evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', ctrl, ['load_' lower(ctrl) '.m']), '\', '/')));
end
if ~exist(fullfile(modelDir, 'Controllers', ctrl, ['Model_' ctrl '.mdl']), 'file'), build_closed_loop(ctrl); end
[~, m] = calib_run(['Model_' ctrl], seed, pidlag_variables(ctrl, d));
Simulink.sdi.clear;                 % the Simulation Data Inspector keeps every run (about 190 MB each in the temp .dmr file) and filled the C drive on 2026-10-13
out.R = m.R; out.S = m.S; out.TV = m.TV; out.erel = m.erel; out.rev = 100 * m.rev; out.simulated = 1;
out.c(4) = m.erel - erelMax;
if out.c(4) <= 0, out.J = m.R * m.S; else, out.J = Inf; end
finish();

    function finish()
        if ~isempty(csvFile)
            writeRow(csvFile, names, x, seed, out, toc(tStart));
        end
    end
end

function d = xToDesign(ctrl, x, Ts)
d = struct('Ts_ctrl', Ts, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
if strcmp(ctrl, 'PIDLag'), d.lag = struct('z1', x(5), 'p1', x(5) * x(6)); end
end

function writeRow(csvFile, names, x, seed, out, secs)
hdr = [names, {'seed', 'J', 'R_pct', 'S_Nm', 'TV', 'erel_pct', 'rev_pct', 'PM_deg', 'GM', 'HF', 'lagGain2Hz', 'simulated', 'c1', 'c2', 'c3', 'c4', 'seconds'}];
newFile = ~exist(csvFile, 'file');
fid = fopen(csvFile, 'a');
if newFile, fprintf(fid, '%s\n', strjoin(hdr, ',')); end
fprintf(fid, '%.15g,', x); fprintf(fid, '%d,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%d,%.10g,%.10g,%.10g,%.10g,%.2f\n', ...
    seed, out.J, out.R, out.S, out.TV, out.erel, out.rev, out.PM, out.GM, out.HF, out.lagGain2Hz, out.simulated, out.c(1), out.c(2), out.c(3), out.c(4), secs);
fclose(fid);
end
