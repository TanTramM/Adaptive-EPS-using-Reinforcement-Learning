function T = scan_mappid_screen(nPerBin)
%SCAN_MAPPID_SCREEN O2b of DieuKhien_MapPID.txt: how far can the linear screen (mappid_margins: PM, GM over 68 plants x 5 slopes) be trusted?
%
%   T = scan_mappid_screen()          20 random designs, 4 per linear-PM bin [0,10), [10,20), [20,30), [30,40), [40,Inf), plus two controls
%   T = scan_mappid_screen(nPerBin)   nPerBin designs per bin
%   Every design is run through the SIMULATION gate calib_margin (nominal, actuator gain x2, controller delay +1 ms; seed 30000; QuyChuan 5.2: both
%   R ratios <= 2). The thresholds are then chosen by the rule written in advance (DieuKhien_MapPID.txt, O2b):
%     PM* = smallest b in {0, 10, 20, 30, 40} deg such that EVERY design with linear PM >= b passes the gate (at least 3 designs); none -> 30 and a warning
%     GM* = smallest g in {1, 1.5, 2, 3} such that every design with PM >= PM* and GM >= g passes the gate; none -> 2
%   Resumable: rows already in Result/Controllers/MapPID/Design/MapPID_screen_s30000.csv are not run again (the sample is regenerated with the fixed rng).
%   Output: that csv, MapPID_screen_decision_s30000.csv (PM*, GM*, rates) and MapPID_screen_s30000.png.
if nargin < 1, nPerBin = 4; end
SEED = 30000; EDGES = [0 10 20 30 40 Inf]; PMc = [0 10 20 30 40]; GMc = [1 1.5 2 3];
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Design');
csvFile = fullfile(outDir, 'MapPID_screen_s30000.csv');
[Gj, w] = mappid_plants();
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
Ts0 = dm.Ts0; w2 = 2 * pi * 2;

%% sample (fixed rng), stratified on the linear PM
rng(20261013);
bins = cell(1, numel(EDGES) - 1); cnt = zeros(1, numel(EDGES) - 1);
nTry = 0; maxTry = 40000;
while any(cnt < nPerBin) && nTry < maxTry
    nTry = nTry + 1;
    x = [16 * rand, expU(5, 500), expU(1.2, 300), expU(8, 120), 0.1 + 0.8 * rand, 3 * rand, expU(2, 200), (rand > 0.3) * (0.002 + 0.048 * rand), expU(0.001, 0.02)];
    d = xToDesign(x, Ts0);
    if d.lead.p > pi / 1e-3 || d.lag.p1 < 3 || abs((1 + 1i * w2 / d.lag.z1) / (1 + 1i * w2 / d.lag.p1)) < 1 / sqrt(2), continue; end
    R = mappid_margins(Gj, w, d); R.PM = min(R.PM, 999);
    if ~R.stable || R.PM < 0 || R.GM <= 0, continue; end
    b = find(R.PM >= EDGES(1:end-1) & R.PM < EDGES(2:end), 1);
    if isempty(b) || cnt(b) >= nPerBin, continue; end
    cnt(b) = cnt(b) + 1; bins{b}(end + 1, :) = [x R.PM R.GM R.HF];
end
fprintf('scan_mappid_screen: %d candidates drawn, designs per PM bin: %s\n', nTry, mat2str(cnt));
xs = [mapDesignX(dm); pidDesignX(dm, q)];
rows = [xs, nan(2, 3), ones(2, 1) * 0, [1; 2]];    % controls (PM, GM, HF filled below)
for i = 1:2
    R = mappid_margins(Gj, w, xToDesign(xs(i, :), Ts0)); rows(i, 10:12) = [R.PM R.GM R.HF];
end
X = [rows(:, 1:12), -ones(2, 1)];                      % column 13 = bin (-1 = control)
for b = 1:numel(bins)
    if ~isempty(bins{b}), X = [X; bins{b}, b * ones(size(bins{b}, 1), 1)]; end %#ok<AGROW>
end
n = size(X, 1);

%% simulation gate on every design (resumable)
names = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf', 'PM_deg', 'GM', 'HF', 'bin'};
if exist(csvFile, 'file'), T = readtable(csvFile); else, T = table(); end
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
if ~exist(fullfile(modelDir, 'Controllers', 'MapPID', 'Model_MapPID.mdl'), 'file'), build_closed_loop('MapPID'); end
for i = 1:n
    if ~isempty(T) && any(T.idx == i), continue; end
    d = xToDesign(X(i, 1:9), Ts0);
    tStart = tic;
    res = calib_margin('Model_MapPID', SEED, mappid_variables(Cal, d));
    fprintf('  design %d/%d: PM %.1f GM %.2f -> gate %d (R nominal %.2f %%, ratios %.2f / %.2f), %.0f s\n', i, n, X(i, 10), X(i, 11), res.pass, res.R_nom, res.ratio_gain, res.ratio_delay, toc(tStart));
    row = table(i, X(i, 13), 'VariableNames', {'idx', 'bin'});
    for k = 1:12, row.(names{k}) = X(i, k); end
    row.R_nom_pct = res.R_nom; row.ratio_gain = res.ratio_gain; row.ratio_delay = res.ratio_delay; row.pass = double(res.pass); row.seconds = toc(tStart);
    if isempty(T), T = row; else, T = [T; row]; end %#ok<AGROW>
    writetable(T, csvFile);
end

%% decision by the rule fixed in advance (controls excluded)
S = T(T.bin >= 1, :);
pmStar = NaN;
for b = PMc
    sel = S.PM_deg >= b;
    if nnz(sel) >= 3 && all(S.pass(sel) == 1), pmStar = b; break; end
end
warnPM = isnan(pmStar); if warnPM, pmStar = 30; warning('scan_mappid_screen:pm', 'no PM bin gives a clean pass: PM* = 30 deg kept, the linear screen is not reliable'); end
gmStar = NaN;
for g = GMc
    sel = S.PM_deg >= pmStar & S.GM >= g;
    if nnz(sel) >= 1 && all(S.pass(sel) == 1), gmStar = g; break; end
end
if isnan(gmStar), gmStar = 2; end
below = S.PM_deg < pmStar | S.GM < gmStar;
falseReject = mean(S.pass(below) == 1); if ~any(below), falseReject = NaN; end
leak = mean(S.pass(~below) == 0); if all(below), leak = NaN; end
fprintf('scan_mappid_screen: PM* = %g deg%s, GM* = %g; %d of %d designs below the screen would be rejected although %d pass the gate (false reject %.0f %%); leak %.0f %%\n', ...
    pmStar, ifelse(warnPM, ' (default, no clean bin)', ''), gmStar, nnz(below), height(S), nnz(below & S.pass == 1), 100 * falseReject, 100 * leak);
D = table(pmStar, gmStar, warnPM, nnz(below), height(S), nnz(below & S.pass == 1), falseReject, leak, nTry, ...
    'VariableNames', {'PM_star_deg', 'GM_star', 'default_used', 'n_below', 'n_designs', 'n_below_pass', 'false_reject', 'leak', 'n_candidates'});
writetable(D, fullfile(outDir, 'MapPID_screen_decision_s30000.csv'));

fig = figure('Visible', 'off', 'Position', [100 100 760 520]); hold on;
mk = S.pass == 1;
scatter(S.PM_deg(mk), max(S.ratio_gain(mk), S.ratio_delay(mk)), 50, [0.1 0.55 0.2], 'filled');
scatter(S.PM_deg(~mk), min(max(S.ratio_gain(~mk), S.ratio_delay(~mk)), 10), 50, [0.8 0.15 0.15], 'filled');
yline(2, '--k'); xline(pmStar, ':b', sprintf('PM* = %g', pmStar));
xlabel('Linear PM over 68 plants x 5 slopes [deg]'); ylabel('max(R ratio gain x2, R ratio delay +1 ms) (capped at 10)');
legend({'passes the gate', 'fails the gate'}, 'Location', 'northeast'); grid on;
title('MapPID: linear screen against the simulation margin gate (CALIB, seed 30000)');
exportgraphics(fig, fullfile(outDir, 'MapPID_screen_s30000.png'), 'Resolution', 120); close(fig);
end

function v = expU(a, b)
v = exp(log(a) + (log(b) - log(a)) * rand);
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)), ...
    'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end

function x = mapDesignX(dm)
x = [dm.Kmax, dm.lead.z, dm.lead.p / dm.lead.z, dm.lag.z1, dm.lag.p1 / dm.lag.z1, 0, 0, 0, 0.005];
end

function x = pidDesignX(dm, q)
x = [0, dm.lead.z, dm.lead.p / dm.lead.z, dm.lag.z1, dm.lag.p1 / dm.lag.z1, q.Kp, q.Ki, q.Kd, q.Tf];
end

function s = ifelse(c, a, b)
if c, s = a; else, s = b; end
end
