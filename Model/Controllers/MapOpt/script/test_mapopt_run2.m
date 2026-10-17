function test_mapopt_run2()
%TEST_MAPOPT_RUN2 Check the run-2 additions of MapOpt (DieuKhien_MapOpt.txt Part M; thresholds PM >= 30 deg and GM >= 2 during the search, start points from run 1).
%   (1) mapopt_run1_points: the start points of chain 1 are finite, inside the box, and their constraints are those of the thresholds of run 2.
%   (2) mapopt_eval with the thresholds of run 1 reproduces the stored J of a run-1 design with PM < 25 deg (deterministic simulation, seed 0; relative tolerance 1e-4: a rerun differs from the stored value by about 2e-6); with the thresholds of run 2 the same
%       design is rejected by the linear screen (not simulated) and c1 = 30 - PM.
%   (3) a run-1 design with PM >= 31 deg and GM >= 2.1 gives the same J under both thresholds.
%   Needs Result/Controllers/MapOpt/Calib_run1 (the run-1 evaluations). Prints "[MapOpt] RUN2 TEST PASS".
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
r1 = fullfile(fileparts(outDir), 'Calib_run1');
cfg1 = mapopt_cfg(''); cfg2 = mapopt_cfg('b');
assert(cfg1.PMmin == 0 && cfg1.GMmin == 1 && cfg2.PMmin == 30 && cfg2.GMmin == 2, 'mapopt_cfg thresholds');

ip = mapopt_run1_points(outDir, 1, cfg2);
assert(size(ip.X, 1) > 100 && size(ip.X, 2) == 5, 'too few start points');
assert(all(ip.X(:) >= -1e-9 & ip.X(:) <= 1 + 1e-9), 'start points outside the box');
assert(all(isfinite(ip.Fval)) && all(isfinite(ip.Ineq(:))) && size(ip.Ineq, 2) == 4, 'start point values not finite');
fprintf('[MapOpt run2] (1) %d start points from run 1, %d feasible under the thresholds of run 2\n', size(ip.X, 1), sum(all(ip.Ineq <= 0, 2)));

T = readtable(fullfile(r1, 'MapOpt_CALIB_opt1_s00000.csv'));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & T.PM_deg < 25;
assert(any(ok), 'no run-1 design with PM < 25 deg');
T2 = T(ok, :); [~, ib] = min(T2.J);
x = [T2.K(ib) T2.z(ib) T2.p_over_z(ib) T2.z1(ib) T2.p1_over_z1(ib)];
o2 = mapopt_eval(x, 0, '', cfg2);
assert(o2.simulated == 0 && abs(o2.c(1) - (30 - T2.PM_deg(ib))) < 1e-3, 'run-2 thresholds must reject the design by the linear screen');
o1 = mapopt_eval(x, 0, '', cfg1);
assert(o1.simulated == 1 && abs(o1.J - T2.J(ib)) <= 1e-4 * T2.J(ib), 'run-1 thresholds must reproduce the stored J');
fprintf('[MapOpt run2] (2) PM %.1f deg: run-1 thresholds J %.5f (stored %.5f), run-2 thresholds rejected (c1 %.2f)\n', T2.PM_deg(ib), o1.J, T2.J(ib), o2.c(1));

S = T(T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & T.PM_deg >= 31 & T.GM >= 2.1, :);
assert(~isempty(S), 'no run-1 design with PM >= 31 deg');
[~, jb] = min(S.J); x3 = [S.K(jb) S.z(jb) S.p_over_z(jb) S.z1(jb) S.p1_over_z1(jb)];
o3 = mapopt_eval(x3, 0, '', cfg2);
assert(o3.simulated == 1 && abs(o3.J - S.J(jb)) <= 1e-4 * S.J(jb), 'a design inside both limits must give the stored J under the thresholds of run 2');
fprintf('[MapOpt run2] (3) PM %.1f deg GM %.2f: run-2 thresholds J %.5f (stored %.5f)\n', S.PM_deg(jb), S.GM(jb), o3.J, S.J(jb));
Simulink.sdi.clear;
fprintf('[MapOpt] RUN2 TEST PASS\n');
end
