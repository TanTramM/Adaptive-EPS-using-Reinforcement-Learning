function refine_pidopt(runId, maxEvals)
%REFINE_PIDOPT Stage 1, local part: patternsearch from the best feasible design of surrogateopt run runId (initial mesh 0.05 of the box, stop below 0.02 or after maxEvals, default 60),
%   cache Result/Controllers/PIDOpt/Calib/PIDOpt_CALIB_ref<runId>_s10000.csv. Same method as refine_mappid.m.
if nargin < 2 || isempty(maxEvals), maxEvals = 60; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
vn = {'Kp', 'Ki', 'Kd', 'Tf'};
outDir = result_dir('PIDOpt', 'Calib');
T = readtable(fullfile(outDir, sprintf('PIDOpt_CALIB_opt%d_s10000.csv', runId)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0;
assert(any(ok), 'refine_pidopt: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = table2array(T(ib, vn));
fprintf('refine_pidopt(%d): start J %.4f (R %.3f %%, S %.4f) at %s\n', runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('PIDOpt_CALIB_ref%d_s10000.csv', runId));
fun = @(u) objective(u, csvFile);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, 'Display', 'iter', ...
    'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, pidopt_x2u(x0), [], [], [], [], zeros(1, 4), ones(1, 4), [], opts);
fprintf('refine_pidopt(%d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', runId, flag, out.funccount, exp(fval), mat2str(pidopt_u2x(u), 5));
end

function f = objective(u, csvFile)
try
    o = pidlag_eval('PIDOpt', pidopt_u2x(u), 10000, csvFile);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
