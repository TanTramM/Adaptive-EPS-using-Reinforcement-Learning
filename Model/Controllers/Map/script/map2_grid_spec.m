function spec = map2_grid_spec(centreRule)
%MAP2_GRID_SPEC Configuration of the two-variable Map grid search (K, g_min), PhuongPhap_TimThamSo.txt 14.
%   Same method as PID (common/grid_search.m, common/select_pareto.m); coarse grid 13 x 13 levels, fine grid 3 x 3 around the centre.
if nargin < 1, centreRule = 'R1'; end   % 'R2': centre of the fine grid from the safe pairs only (added 2026-10-21 after the R1 run centred on pairs failing calib_margin)
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Ts0 = J.design.Ts0;                      % dead zone [N.m]: structural parameter
spec = struct();
spec.name = 'Map';
spec.n = 2;
spec.vn = {'K', 'g_min'};
spec.u2x = @map2_u2x;
spec.x2u = @map2_x2u;
spec.evalFcn = @map2_eval;
spec.seed = 0;
spec.seed0 = 0;
spec.seeds = 1:5;
spec.outDir = fullfile(result_dir('Map', 'Calib'), 'Grid2');   % own folder: select_pareto reads every Map_CALIB_*_w*_s00000.csv of outDir
spec.tag = 'grid2';
spec.free = 1:2;
spec.u0 = [0.5 0.5];
spec.coarse = true;
spec.coarseLevels = (0:12) / 12;
spec.hStart = 1 / 24;
spec.PMfin = 30;
spec.GMfin = 2;
spec.erelMax = 10;
spec.marginWorkers = 1;
spec.keepTsCtrl = true;
spec.centerFcn = @(T, s) map2_center(T, s, centreRule);
spec.marginFcn = @(x) map2_margin(x, spec);
spec.toDesign = @(x) map2_design(x, spec, Ts0);
spec.jsonPath = fullfile(modelDir, 'data', 'map.json');
end

function xc = map2_center(T, spec, centreRule)
%MAP2_CENTER Fine-grid centre (14.4). R1: all gates, minimum J. R2 (R1 empty): safety gates c1-c3 and calib_margin, minimum J. R3: none -> stop.
sim = T.simulated == 1;
r1 = sim & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & isfinite(T.J);
r2 = sim & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.pass_margin == 1 & isfinite(T.J);
if strcmp(centreRule, 'R1') && any(r1), rule = 'R1'; Q = T(r1, :);
elseif any(r2), rule = 'R2'; Q = T(r2, :);
else
    writeNoSolution(T, spec);
    error('map2:R3', 'No pair passes the safety gates (R3); see Map_CALIB_grid2_R3_s00000.csv.');
end
[~, ib] = min(Q.J);
xc = [Q.K(ib), Q.g_min(ib)];
fprintf('[grid2] centre rule %s (%d candidates) -> K %.6g, g_min %.6g, J %.6g\n', rule, height(Q), xc(1), xc(2), Q.J(ib));
end

function writeNoSolution(T, spec)
%WRITENOSOLUTION Report of the case R3 (no safe pair).
nSynthFail = nnz(T.synth_ok == 0); nLinFail = nnz(T.synth_ok == 1 & T.simulated == 0);
sim = T.simulated == 1; nMarginFail = nnz(sim & T.pass_margin ~= 1);
rg = T.ratio_gain; rg(~isfinite(rg)) = Inf; [mg, ig] = min(rg);
R = table(height(T), nSynthFail, nLinFail, nnz(sim), nMarginFail, mg, T.K(ig), T.g_min(ig), ...
    'VariableNames', {'pairs', 'synth_fail', 'linear_fail', 'simulated', 'margin_fail', 'min_ratio_gain', 'K_at_min', 'g_min_at_min'});
writetable(R, fullfile(spec.outDir, 'Map_CALIB_grid2_R3_s00000.csv'));
end

function row = findRow(x, spec)
%FINDROW Row of the search seed for x in the stored CSVs of the grid (empty if absent).
files = dir(fullfile(spec.outDir, 'Map_CALIB_grid2_w*_s00000.csv')); row = [];
for i = 1:numel(files)
    T = readtable(fullfile(files(i).folder, files(i).name));
    hit = T.seed == 0 & abs(T.K - x(1)) <= 1e-9 * max(1, abs(x(1))) & abs(T.g_min - x(2)) <= 1e-9 * max(1, abs(x(2)));
    if any(hit), row = T(find(hit, 1), :); return; end
end
end

function M = map2_margin(x, spec)
%MAP2_MARGIN calib_margin result of the pair, READ from the CSV written by map2_eval (not simulated again); computed only if the pair is absent.
r = findRow(x, spec);
if isempty(r)
    map2_eval(x, 0, fullfile(spec.outDir, 'Map_CALIB_grid2_w0_s00000.csv'));
    r = findRow(x, spec);
end
M = struct('pass', r.pass_margin == 1, 'ratio_gain', r.ratio_gain, 'ratio_delay', r.ratio_delay);
end

function d = map2_design(x, spec, Ts0)
%MAP2_DESIGN Design struct of the pair (same fields as mapDesign of map_grid_spec); lag off: z1 = p1 (cancelling pair).
r = findRow(x, spec);
if isempty(r), map2_margin(x, spec); r = findRow(x, spec); end
z1 = r.z1; p1 = r.p1;
if ~isfinite(z1) || ~isfinite(p1), z1 = 120; p1 = 120; end
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', r.z, 'p', r.p), 'lag', struct('z1', z1, 'p1', p1));
end
