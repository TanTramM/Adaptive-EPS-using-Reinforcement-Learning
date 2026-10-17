function optimize_pidopt(runId, maxEvals)
%OPTIMIZE_PIDOPT Stage 1 of the common method (KeHoach_ChonNhieuSeed.txt 3.1): global search of Kp, Ki, Kd, Tf on J = R*S (CALIB, seed 10000) in the WIDE box (pidopt_u2x), surrogateopt.
%   optimize_pidopt(runId, maxEvals)   runId 1, 2, 3: own random seed 1000+runId; maxEvals = TOTAL evaluations (default 250; 400 after the extra 150 of G10(b) when the three
%   chains have not converged: the run resumes from its checkpoint). Evaluations are cached in Result/Controllers/PIDOpt/Calib/PIDOpt_CALIB_opt<runId>_s10000.csv through pidlag_eval
%   (resumable); a corrupt checkpoint is moved aside and the run restarts from the csv cache.
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('PIDOpt', 'Calib');
csvFile = fullfile(outDir, sprintf('PIDOpt_CALIB_opt%d_s10000.csv', runId));
ckpt = fullfile(outDir, sprintf('PIDOpt_CALIB_opt%d_ckpt.mat', runId));
fun = @(u) objconstr(u, csvFile);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, 'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1, opts = optimoptions(opts, 'InitialPoints', rand(30, 4)); end   % the default design of experiments is deterministic: runs 2, 3 draw their own
tStart = tic;
if exist(ckpt, 'file')
    try
        [u, fval, flag, out] = surrogateopt(ckpt, opts);
    catch ME
        fprintf('optimize_pidopt(%d): checkpoint unusable (%s); restarting from the csv cache\n', runId, ME.message);
        movefile(ckpt, [ckpt(1:end-4) '_corrupt.bak']);
        [u, fval, flag, out] = surrogateopt(fun, zeros(1, 4), ones(1, 4), [], [], [], [], [], opts);
    end
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, 4), ones(1, 4), [], [], [], [], [], opts);
end
fprintf('optimize_pidopt(%d) DONE: flag %d, %d evaluations, best J %.4f at %s (%.0f min)\n', runId, flag, out.funccount, exp(fval), mat2str(pidopt_u2x(u), 5), toc(tStart) / 60);
end

function F = objconstr(u, csvFile)
x = pidopt_u2x(u);
try
    o = pidlag_eval('PIDOpt', x, 10000, csvFile);
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
