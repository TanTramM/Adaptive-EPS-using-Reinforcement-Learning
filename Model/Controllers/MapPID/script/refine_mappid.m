function refine_mappid(runId, maxEvals)
%REFINE_MAPPID O5 of DieuKhien_MapPID.txt: local refinement by patternsearch from the best feasible design of the surrogateopt run runId (O4).
%
%   refine_mappid(runId, maxEvals)   start = best feasible row (simulated, all constraints <= 0) of MapPID_CALIB_opt<runId>_s30000.csv;
%                                    objective log(J) on the normalized variables u (mappid_u2x), infeasible -> 10 (patternsearch needs finite values);
%                                    initial mesh 0.05 of the box, stop when the mesh is below 0.02 (two contractions) or after maxEvals (default 60)
%   Evaluations cached in Result/Controllers/MapPID/Calib/MapPID_CALIB_ref<runId>_s30000.csv (resumable through mappid_eval).
if nargin < 2 || isempty(maxEvals), maxEvals = 60; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Calib');
T = readtable(fullfile(outDir, sprintf('MapPID_CALIB_opt%d_s30000.csv', runId)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0;
assert(any(ok), 'refine_mappid: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = [T.K(ib) T.z(ib) T.p_over_z(ib) T.z1(ib) T.p1_over_z1(ib) T.Kp(ib) T.Ki(ib) T.Kd(ib) T.Tf(ib)];
fprintf('refine_mappid(%d): start J %.4f (R %.3f %%, S %.4f) at %s\n', runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('MapPID_CALIB_ref%d_s30000.csv', runId));
fun = @(u) objective(u, csvFile);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, ...
    'Display', 'iter', 'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, mappid_x2u(x0), [], [], [], [], zeros(1, 9), ones(1, 9), [], opts);
x = mappid_u2x(u);
fprintf('refine_mappid(%d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', runId, flag, out.funccount, exp(fval), mat2str(x, 5));
end

function f = objective(u, csvFile)
try
    o = mappid_eval(mappid_u2x(u), 30000, csvFile);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
