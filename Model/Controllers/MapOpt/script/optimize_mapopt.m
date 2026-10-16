function optimize_mapopt(runId, maxEvals)
%OPTIMIZE_MAPOPT Global search of the five MapOpt variables on J = R*S (case CALIB, seed 0): surrogateopt, the MapPID method (optimize_mappid.m, O4).
%   optimize_mapopt(runId, maxEvals)   runId 1, 2, 3: own random seed 1000+runId, own files; maxEvals default 250. Resumable (csv cache + solver checkpoint) in
%   Result/Controllers/MapOpt/Calib/MapOpt_CALIB_opt<runId>_s00000.csv and _ckpt.mat. A corrupt checkpoint (crash during the write) is moved aside and the run
%   restarts from the csv cache (already evaluated points are not simulated again).
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
csvFile = fullfile(outDir, sprintf('MapOpt_CALIB_opt%d_s00000.csv', runId));
ckpt = fullfile(outDir, sprintf('MapOpt_CALIB_opt%d_ckpt.mat', runId));
fun = @(u) objconstr(u, csvFile);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, 'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1, opts = optimoptions(opts, 'InitialPoints', rand(30, 5)); end   % the default design of experiments is deterministic: runs 2, 3 draw their own
tStart = tic;
if exist(ckpt, 'file')
    try
        [u, fval, flag, out] = surrogateopt(ckpt, opts);
    catch ME
        fprintf('optimize_mapopt(%d): checkpoint unusable (%s); restarting from the csv cache\n', runId, ME.message);
        movefile(ckpt, [ckpt(1:end-4) '_corrupt.bak']);
        [u, fval, flag, out] = surrogateopt(fun, zeros(1, 5), ones(1, 5), [], [], [], [], [], opts);
    end
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, 5), ones(1, 5), [], [], [], [], [], opts);
end
x = mapopt_u2x(u);
fprintf('optimize_mapopt(%d) DONE: flag %d, %d evaluations, best J %.4f at %s (%.0f min)\n', runId, flag, out.funccount, exp(fval), mat2str(x, 5), toc(tStart) / 60);
end

function F = objconstr(u, csvFile)
x = mapopt_u2x(u);
try
    o = mapopt_eval(x, 0, csvFile);
catch ME
    fprintf('objconstr: evaluation failed (%s), counted as infeasible\n', ME.message);
    F.Fval = log(30); F.Ineq = [200 200 200 200]; return;
end
if o.simulated
    F.Fval = log(max(o.R * o.S, 1e-6)); F.Ineq = [o.c(1:3), o.erel - 5];
else
    F.Fval = log(30); F.Ineq = [o.c(1:3), 0];
end
F.Ineq(isnan(F.Ineq)) = 200;
F.Ineq = max(min(F.Ineq, 200), -200);
if ~isfinite(F.Fval), F.Fval = log(30); end
end
