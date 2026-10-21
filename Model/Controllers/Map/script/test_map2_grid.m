function test_map2_grid(doSim)
%TEST_MAP2_GRID Check the two-variable Map grid search code (PhuongPhap_TimThamSo.txt 14.7 steps 3 and 4).
%   (1) map2_u2x(map2_x2u(x)) = x and the 13 levels of K and g_min fill the box; (2) with doSim (default true) one evaluation at K = 6.687403049764,
%   g_min = 0.707106781187 (code check only, written to scratch/map2_eval_check.csv, NOT to Grid2) against the expected R 12.42 %, S 0.4365, e_rel 28.2 %, ratio_gain 1.87 (1 % tolerance).
if nargin < 1, doSim = true; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

lev = (0:12) / 12;
X = zeros(numel(lev), 2);
for i = 1:numel(lev), X(i, :) = map2_u2x([lev(i) lev(i)]); end
fprintf('K levels:     %s\n', mat2str(X(:, 1)', 5));
fprintf('g_min levels: %s\n', mat2str(X(:, 2)', 5));
assert(abs(X(1, 1) - 1) < 1e-12 && abs(X(end, 1) - 30) < 1e-12, 'K box');
assert(abs(X(1, 2) - 1 / sqrt(2)) < 1e-12 && abs(X(end, 2) - 1) < 1e-12, 'g_min box');
assert(all(diff(X(:, 1)) > 0) && all(diff(X(:, 2)) > 0), 'levels must increase');
for i = 1:numel(lev)
    assert(max(abs(map2_u2x(map2_x2u(X(i, :))) - X(i, :)) ./ X(i, :)) < 1e-12, 'u2x(x2u(x)) != x');
end
x0 = [6.687403049764, 0.707106781187];
assert(max(abs(map2_u2x(map2_x2u(x0)) - x0) ./ x0) < 1e-10, 'round trip of the check point');
if ~doSim, fprintf('[Map2] GRID TEST (u<->x only) PASS\n'); return; end

csv = fullfile(fileparts(modelDir), 'scratch', 'map2_eval_check.csv');
if exist(csv, 'file'), delete(csv); end
o = map2_eval(x0, 0, csv);
fprintf('check: synth_ok %d, PM %.3f, GM %.3f, lagGain %.5f, simulated %d, R %.4f, S %.5f, e_rel %.3f, ratio_gain %.3f, ratio_delay %.3f, pass %d\n', ...
    o.synth_ok, o.PM, o.GM, o.lagGain2Hz, o.simulated, o.R, o.S, o.erel, o.ratio_gain, o.ratio_delay, o.pass_margin);
assert(o.synth_ok == 1 && o.simulated == 1, 'check point was not simulated');
exp = struct('R', 12.42, 'S', 0.4365, 'erel', 28.2, 'ratio_gain', 1.87);
for f = fieldnames(exp)'
    v = o.(f{1});
    assert(abs(v - exp.(f{1})) <= 0.01 * exp.(f{1}), 'check %s = %g, expected %g (1 %%)', f{1}, v, exp.(f{1}));
end
fprintf('[Map2] GRID TEST PASS\n');
end
