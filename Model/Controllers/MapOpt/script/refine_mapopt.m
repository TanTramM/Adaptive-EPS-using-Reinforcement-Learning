function refine_mapopt(runId, maxEvals)
%REFINE_MAPOPT Local refinement by patternsearch from the best feasible design of surrogateopt run runId (the MapPID method, refine_mappid.m, O5): initial mesh 0.05,
%   stop below 0.02 or after maxEvals (default 60); cache Result/Controllers/MapOpt/Calib/MapOpt_CALIB_ref<runId>_s00000.csv.
if nargin < 2 || isempty(maxEvals), maxEvals = 60; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1'};
outDir = result_dir('MapOpt', 'Calib');
T = readtable(fullfile(outDir, sprintf('MapOpt_CALIB_opt%d_s00000.csv', runId)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0;
assert(any(ok), 'refine_mapopt: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = table2array(T(ib, vn));
fprintf('refine_mapopt(%d): start J %.4f (R %.3f %%, S %.4f) at %s\n', runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('MapOpt_CALIB_ref%d_s00000.csv', runId));
fun = @(u) objective(u, csvFile);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, 'Display', 'iter', ...
    'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, mapopt_x2u(x0), [], [], [], [], zeros(1, 5), ones(1, 5), [], opts);
fprintf('refine_mapopt(%d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', runId, flag, out.funccount, exp(fval), mat2str(mapopt_u2x(u), 5));
end

function f = objective(u, csvFile)
try
    o = mapopt_eval(mapopt_u2x(u), 0, csvFile);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
