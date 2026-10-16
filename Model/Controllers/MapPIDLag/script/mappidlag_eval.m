function out = mappidlag_eval(x, seed, csvFile)
%MAPPIDLAG_EVAL Evaluate ONE MapPIDLag design on the calibration case CALIB: linear screen first (cheap), then the simulation (one calib_run, about 24 s).
%
%   out = mappidlag_eval(x, seed, csvFile)
%     x       row or column of the seven design variables
%             [K, z1, p1/z1, Kp, Ki, Kd, Tf]   K slope limit of the table; lag z1, p1 [rad/s] (p1/z1 <= 1; 1 = no lag) on the SUM of the two branches;
%                                              Kp, Ki [1/s], Kd [s], Tf [s] of the PID branch (Kaw = Ki/(Kp + K), taken after the lag)
%             K = 0 is the reference PID + lag (the Map branch is off)
%     seed    run seed of the sensor noise (MapPIDLag tuning seed 50000; the check seed 50001)
%     csvFile optional: every evaluation is appended as one row (resumable: a design already in the file is returned from it, not simulated again)
%   out.c      constraint vector, feasible when all <= 0:  [PM_min - PM, GM_min - GM, g_lag_min - lagGain2Hz, erel - 5]
%   out.J      R*S [% N.m], Inf when a linear constraint fails (not simulated); out.R, S, TV, erel, rev; out.PM, GM, HF, lagGain2Hz; out.simulated (0/1)
%   Constraints (DieuKhien_MapPIDLag.txt C3, as MapPID after D13): linear PM > 0 and GM >= 1 over 68 plants x 5 slopes while searching (the final point must
%   have PM >= 30 deg, GM >= 2: select_mappidlag); lag gain at 2 Hz >= 0.707 (steering band, QuyChuan 6.2); e_rel <= 5 % on the 9 static windows
%   (QuyChuan 5.3); p1 >= 3 rad/s and p1 <= z1. The simulation margin gate (calib_margin) is NOT run here: only for the final candidates.
if nargin < 2 || isempty(seed), seed = 50000; end
if nargin < 3, csvFile = ''; end
persistent Gj w Cal haveBase
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
x = x(:)';
assert(numel(x) == 7, 'x must have seven entries');
names = {'K', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
PMmin = 0; GMmin = 1; gLagMin = 1 / sqrt(2); erelMax = 5; Ts = 1e-3;

% cached row?
if ~isempty(csvFile) && exist(csvFile, 'file')
    T = readtable(csvFile);
    hit = T.seed == seed;
    for i = 1:7, hit = hit & abs(T.(names{i}) - x(i)) <= 1e-9 * max(1, abs(x(i))); end
    if any(hit)
        r = T(find(hit, 1), :);
        out = struct('x', x, 'seed', seed, 'J', r.J, 'R', r.R_pct, 'S', r.S_Nm, 'TV', r.TV, 'erel', r.erel_pct, 'rev', r.rev_pct, 'PM', r.PM_deg, 'GM', r.GM, ...
            'HF', r.HF, 'lagGain2Hz', r.lagGain2Hz, 'simulated', r.simulated, 'c', [r.c1 r.c2 r.c3 r.c4], 'cached', true);
        return;
    end
end

if isempty(Gj), [Gj, w] = mappidlag_plants(); Cal = calibrate_map_cached(); end
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
d = struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', x(1), 'lag', struct('z1', x(2), 'p1', x(2) * x(3)), 'Kp', x(4), 'Ki', x(5), 'Kd', x(6), 'Tf', x(7));
w2 = 2 * pi * 2;
lagGain = abs((1 + 1i * w2 / d.lag.z1) / (1 + 1i * w2 / d.lag.p1));
c = [0 0 0 0];
out = struct('x', x, 'seed', seed, 'J', Inf, 'R', NaN, 'S', NaN, 'TV', NaN, 'erel', NaN, 'rev', NaN, 'PM', NaN, 'GM', NaN, 'HF', NaN, ...
    'lagGain2Hz', lagGain, 'simulated', 0, 'c', c, 'cached', false);
tStart = tic;

% hard structural bounds (cheap)
bad = d.lag.p1 < 3 || d.lag.p1 > d.lag.z1;
R = mappidlag_margins(Gj, w, d);
out.PM = R.PM; out.GM = R.GM; out.HF = R.HF;
PMeff = R.PM; if ~R.stable, PMeff = -180; end
c(1) = PMmin - PMeff; c(2) = GMmin - R.GM; c(3) = gLagMin - lagGain;
out.c = c;
if bad || any(c(1:3) > 0)
    if bad, out.c(3) = max(out.c(3), 1); end
    finish(); return;
end

% simulation
if isempty(haveBase) || ~evalin('base', 'exist(''MapPIDLag_Kp'', ''var'')')
    evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'load_mappidlag.m'), '\', '/')));
    haveBase = true;
end
if ~exist(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'Model_MapPIDLag.mdl'), 'file'), build_closed_loop('MapPIDLag'); end
[~, m] = calib_run('Model_MapPIDLag', seed, mappidlag_variables(Cal, d));
Simulink.sdi.clear;                 % the Simulation Data Inspector keeps every run (about 190 MB each in the temp .dmr file) and filled the C drive on 2026-10-13
out.R = m.R; out.S = m.S; out.TV = m.TV; out.erel = m.erel; out.rev = m.rev; out.simulated = 1;
out.c(4) = m.erel - erelMax;
if out.c(4) <= 0, out.J = m.R * m.S; else, out.J = Inf; end
finish();

    function finish()
        if ~isempty(csvFile)
            writeRow(csvFile, names, x, seed, out, toc(tStart));
        end
    end
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
