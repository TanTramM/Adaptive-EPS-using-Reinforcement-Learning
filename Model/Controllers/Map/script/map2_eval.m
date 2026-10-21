function out = map2_eval(x, seed, csvFile)
%MAP2_EVAL Evaluate ONE pair x = [K, g_min] of the two-variable Map grid search (PhuongPhap_TimThamSo.txt 14.2).
%   out = map2_eval(x, seed, csvFile)
%     1. lead-lag synthesis design_leadlag(Gj, w, K, g_min < 1, [g_min 12.57]) over the 68 linear plants (fail: simulated = 0, synth_ok = 0, J = Inf, c = Inf);
%     2. outer linear constraints c1 = 30 - PM, c2 = 2 - GM, c3 = 1/sqrt(2) - lagGain2Hz (any > 0: not simulated);
%     3. CALIB v2 simulation at `seed` (R, S, TV, e_rel, rev); J = R*S whenever simulated (also when e_rel fails: c4 = e_rel - 10 carries the gate);
%     4. calib_margin('Model_Map', 1, vars) for every simulated point of the search seed 0 (needed by the centre rule R2 and the fallback pick).
%   Every evaluation is appended to csvFile (resumable: a pair already stored for the same seed is returned from the file, not recomputed).
if nargin < 2 || isempty(seed), seed = 0; end
if nargin < 3, csvFile = ''; end
persistent Gj w Cal Ts0 haveBase
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
x = x(:)';
assert(numel(x) == 2, 'x must be [K, g_min]');
names = {'K', 'g_min'};
erelMax = 10; PMmin = 30; GMmin = 2; gLagMin = 1 / sqrt(2); Ts = 1e-3; wBand = 12.57;

if ~isempty(csvFile) && exist(csvFile, 'file')
    T = readtable(csvFile);
    hit = T.seed == seed;
    for i = 1:2, hit = hit & abs(T.(names{i}) - x(i)) <= 1e-9 * max(1, abs(x(i))); end
    if any(hit)
        out = rowToOut(T(find(hit, 1), :), x, seed);
        return;
    end
end

if isempty(Gj)
    [Gj, w] = map_opt_plants();
    Cal = calibrate_map_cached();
    Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;   % dead zone: structural parameter, not a result
end
tStart = tic;
out = struct('x', x, 'seed', seed, 'J', Inf, 'R', NaN, 'S', NaN, 'TV', NaN, 'erel', NaN, 'rev', NaN, 'PM', NaN, 'GM', NaN, 'HF', NaN, ...
    'lagGain2Hz', NaN, 'simulated', 0, 'synth_ok', 0, 'c', [Inf Inf Inf Inf], 'z', NaN, 'p', NaN, 'z1', NaN, 'p1', NaN, ...
    'ratio_gain', NaN, 'ratio_delay', NaN, 'pass_margin', 0, 'cached', false);

D0 = design_leadlag(Gj, w, x(1), x(2) < 1, [x(2) wBand]);
if ~D0.ok
    finish(); return;
end
out.synth_ok = 1; out.z = D0.z; out.p = D0.p; out.z1 = D0.z1; out.p1 = D0.p1;
if x(2) >= 1, out.z1 = Inf; out.p1 = Inf; end            % lag off
d = struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', out.z, 'p', out.p), 'lag', struct('z1', out.z1, 'p1', out.p1));
if isfinite(out.z1), lagGain = abs((1 + 1i * wBand / out.z1) / (1 + 1i * wBand / out.p1)); lagFac = out.p1 / out.z1;
else, lagGain = 1; lagFac = 1; end
R = map_opt_margins(Gj, w, d);
PMeff = R.PM; if ~R.stable, PMeff = -180; end
out.PM = R.PM; out.GM = R.GM; out.HF = x(1) * (out.p / out.z) * lagFac; out.lagGain2Hz = lagGain;
out.c = [PMmin - PMeff, GMmin - R.GM, gLagMin - lagGain - 1e-9, Inf];   % 1e-9: g_min = 1/sqrt(2) equals the synthesis bound up to round-off
if any(out.c(1:3) > 0)
    finish(); return;
end

if isempty(haveBase)
    assignin('base', 'Map_calibration_override', Cal);
    evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
    haveBase = true;
end
if ~exist(fullfile(modelDir, 'Controllers', 'Map', 'Model_Map.mdl'), 'file'), build_closed_loop('Map'); end
V = map_variables(Cal, d);
[~, m] = calib_run('Model_Map', seed, V);
Simulink.sdi.clear;
out.R = m.R; out.S = m.S; out.TV = m.TV; out.erel = m.erel; out.rev = m.rev; out.simulated = 1;
out.c(4) = m.erel - erelMax;
out.J = m.R * m.S;
if seed == 0
    M = calib_margin('Model_Map', 1, V);
    Simulink.sdi.clear;
    out.ratio_gain = M.ratio_gain; out.ratio_delay = M.ratio_delay; out.pass_margin = double(M.pass);
end
finish();

    function finish()
        if ~isempty(csvFile), writeRow(csvFile, names, x, seed, out, toc(tStart)); end
    end
end

function out = rowToOut(r, x, seed)
out = struct('x', x, 'seed', seed, 'J', r.J, 'R', r.R_pct, 'S', r.S_Nm, 'TV', r.TV, 'erel', r.erel_pct, 'rev', r.rev_pct, 'PM', r.PM_deg, 'GM', r.GM, ...
    'HF', r.HF, 'lagGain2Hz', r.lagGain2Hz, 'simulated', r.simulated, 'synth_ok', r.synth_ok, 'c', [r.c1 r.c2 r.c3 r.c4], ...
    'z', r.z, 'p', r.p, 'z1', r.z1, 'p1', r.p1, 'ratio_gain', r.ratio_gain, 'ratio_delay', r.ratio_delay, 'pass_margin', r.pass_margin, 'cached', true);
end

function writeRow(csvFile, names, x, seed, out, secs)
hdr = [names, {'seed', 'J', 'R_pct', 'S_Nm', 'TV', 'erel_pct', 'rev_pct', 'PM_deg', 'GM', 'HF', 'lagGain2Hz', 'simulated', 'c1', 'c2', 'c3', 'c4', 'synth_ok', ...
    'z', 'p', 'z1', 'p1', 'ratio_gain', 'ratio_delay', 'pass_margin', 'seconds'}];
newFile = ~exist(csvFile, 'file');
fid = fopen(csvFile, 'a');
if newFile, fprintf(fid, '%s\n', strjoin(hdr, ',')); end
fprintf(fid, '%.15g,%.15g,%d,', x(1), x(2), seed);
fprintf(fid, '%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,', out.J, out.R, out.S, out.TV, out.erel, out.rev, out.PM, out.GM, out.HF, out.lagGain2Hz);
fprintf(fid, '%d,%.10g,%.10g,%.10g,%.10g,%d,', out.simulated, out.c(1), out.c(2), out.c(3), out.c(4), out.synth_ok);
fprintf(fid, '%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%d,%.2f\n', out.z, out.p, out.z1, out.p1, out.ratio_gain, out.ratio_delay, out.pass_margin, secs);
fclose(fid);
end
