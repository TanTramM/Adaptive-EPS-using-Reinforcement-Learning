function refine_mappidlag(runId, maxEvals, variant)
%REFINE_MAPPIDLAG P5 of DieuKhien_MapPIDLag.txt: local refinement by patternsearch from the best feasible design of the surrogateopt run runId (P4).
%
%   refine_mappidlag(runId, maxEvals, variant)   start = best feasible row (simulated, all constraints <= 0) of <variant>_CALIB_opt<runId>_s50000.csv;
%                                    objective log(J) on the normalized variables u (mappidlag_u2x), infeasible -> 10 (patternsearch needs finite values);
%                                    initial mesh 0.05 of the box, stop when the mesh is below 0.02 (two contractions) or after maxEvals (default 60)
%   variant 'MapPIDLag' (default, seven variables) or 'PIDLag' (K = 0, six variables). Same method as refine_mappid.m.
%   Evaluations cached in Result/Controllers/MapPIDLag/Calib/<variant>_CALIB_ref<runId>_s50000.csv (resumable through mappidlag_eval).
if nargin < 2 || isempty(maxEvals), maxEvals = 60; end
if nargin < 3 || isempty(variant), variant = 'MapPIDLag'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPIDLag', 'Calib');
T = readtable(fullfile(outDir, sprintf('%s_CALIB_opt%d_s50000.csv', variant, runId)));
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0;
assert(any(ok), 'refine_mappidlag: run %d has no feasible design', runId);
T = T(ok, :); [~, ib] = min(T.J);
x0 = [T.K(ib) T.z1(ib) T.p1_over_z1(ib) T.Kp(ib) T.Ki(ib) T.Kd(ib) T.Tf(ib)];
fprintf('refine_mappidlag(%s, %d): start J %.4f (R %.3f %%, S %.4f) at %s\n', variant, runId, T.J(ib), T.R_pct(ib), T.S_Nm(ib), mat2str(x0, 5));
csvFile = fullfile(outDir, sprintf('%s_CALIB_ref%d_s50000.csv', variant, runId));
u0 = mappidlag_x2u(x0);
if strcmp(variant, 'PIDLag'), u0 = u0(2:end); end
nv = numel(u0);
fun = @(u) objective(u, csvFile, variant);
opts = optimoptions('patternsearch', 'MaxFunctionEvaluations', maxEvals, 'InitialMeshSize', 0.05, 'MeshTolerance', 0.02, ...
    'Display', 'iter', 'UseCompletePoll', false, 'PollMethod', 'GPSPositiveBasis2N', 'Cache', 'on', 'ScaleMesh', 'off');
[u, fval, flag, out] = patternsearch(fun, u0, [], [], [], [], zeros(1, nv), ones(1, nv), [], opts);
x = mappidlag_u2x(embed(u, variant));
fprintf('refine_mappidlag(%s, %d) DONE: flag %d, %d evaluations, best J %.4f at %s\n', variant, runId, flag, out.funccount, exp(fval), mat2str(x, 5));
end

function u7 = embed(u, variant)
if strcmp(variant, 'PIDLag'), u7 = [0, u(:)']; else, u7 = u(:)'; end
end

function f = objective(u, csvFile, variant)
try
    o = mappidlag_eval(mappidlag_u2x(embed(u, variant)), 50000, csvFile);
catch ME
    fprintf('objective: evaluation failed (%s)\n', ME.message); f = 10; return;
end
if o.simulated && all(o.c <= 0), f = log(max(o.R * o.S, 1e-6)); else, f = 10; end
end
