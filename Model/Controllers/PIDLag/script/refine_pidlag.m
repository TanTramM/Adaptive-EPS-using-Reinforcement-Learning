function refine_pidlag(ctrl, runId, maxEvals)
%REFINE_PIDLAG Local refinement by patternsearch from the best feasible design of the surrogateopt run runId (the MapPID method, refine_mappid.m, O5).
%
%   refine_pidlag(ctrl, runId, maxEvals)   start = best feasible row (simulated, all constraints <= 0) of <ctrl>_CALIB_opt<runId>_s10000.csv;
%                                          objective log(J) on the normalized variables u (pidlag_u2x), infeasible -> 10; initial mesh 0.05, stop below 0.02 or after maxEvals (default 60)
%   Evaluations cached in Result/Controllers/<ctrl>/Calib/<ctrl>_CALIB_ref<runId>_s10000.csv (resumable through pidlag_eval).
if nargin < 3 || isempty(maxEvals), maxEvals = 60; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
n = 4 + 2 * strcmp(ctrl, 'PIDLag');
vn = {'Kp', 'Ki', 'Kd', 'Tf', 'z1', 'p1_over_z1'}; vn = vn(1:n);
outDir = result_dir(ctrl, 'Calib');
T = readtable(fullfile(outDir, sprintf('%s_CALIB_opt%d_s10000.csv', ctrl, runId)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0;
assert(any(ok), 'refine_pidlag: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = table2array(T(ib, vn));
fprintf('refine_pidlag(%s,%d): start J %.4f (R %.3f %%, S %.4f) at %s\n', ctrl, runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('%s_CALIB_ref%d_s10000.csv', ctrl, runId));
fun = @(u) objective(ctrl, u, csvFile);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, ...
    'Display', 'iter', 'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, pidlag_x2u(ctrl, x0), [], [], [], [], zeros(1, n), ones(1, n), [], opts);
x = pidlag_u2x(ctrl, u);
fprintf('refine_pidlag(%s,%d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', ctrl, runId, flag, out.funccount, exp(fval), mat2str(x, 5));
end

function f = objective(ctrl, u, csvFile)
try
    o = pidlag_eval(ctrl, pidlag_u2x(ctrl, u), 10000, csvFile);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
