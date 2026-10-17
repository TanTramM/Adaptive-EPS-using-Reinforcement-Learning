function refine_mapopt(runId, maxEvals, suffix)
%REFINE_MAPOPT Stage 1 of DieuKhien_MapOpt.txt (C1): local refinement by patternsearch from the best feasible design of the surrogateopt run runId.
%
%   refine_mapopt(runId, maxEvals)   start = best feasible row (simulated, all constraints <= 0) of MapOpt_CALIB_opt<runId>_s00000.csv; objective log(J) on the normalized
%                                    variables u (mapopt_u2x), infeasible -> 10; initial mesh 0.05 of the box, stop when the mesh is below 0.02 or after maxEvals (default 60).
%   refine_mapopt(runId, maxEvals, 'b')   run 2: start = best design of MapOpt_CALIB_opt<runId>b feasible under the thresholds of run 2 (PM >= 30, GM >= 2); files ...ref<k>b...
%   Evaluations cached in Result/Controllers/MapOpt/Calib/MapOpt_CALIB_ref<runId>_s00000.csv (resumable). Same method as refine_mappid.m.
if nargin < 2 || isempty(maxEvals), maxEvals = 60; end
if nargin < 3, suffix = ''; end
cfg = mapopt_cfg(suffix);
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
T = readtable(fullfile(outDir, sprintf('MapOpt_CALIB_opt%d%s_s00000.csv', runId, suffix)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & T.PM_deg >= cfg.PMmin & T.GM >= cfg.GMmin;
assert(any(ok), 'refine_mapopt: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = [T.K(ib) T.z(ib) T.p_over_z(ib) T.z1(ib) T.p1_over_z1(ib)];
fprintf('refine_mapopt(%d): start J %.4f (R %.3f %%, S %.4f) at %s\n', runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('MapOpt_CALIB_ref%d%s_s00000.csv', runId, suffix));
fun = @(u) objective(u, csvFile, cfg);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, ...
    'Display', 'iter', 'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, mapopt_x2u(x0), [], [], [], [], zeros(1, 5), ones(1, 5), [], opts);
x = mapopt_u2x(u);
fprintf('refine_mapopt(%d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', runId, flag, out.funccount, exp(fval), mat2str(x, 5));
end

function f = objective(u, csvFile, cfg)
try
    o = mapopt_eval(mapopt_u2x(u), 0, csvFile, cfg);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
