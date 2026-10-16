function optimize_pidlag(ctrl, runId, maxEvals)
%OPTIMIZE_PIDLAG Global search of the PIDOpt (4) or PIDLag (6) variables on the simulated objective J = R*S (case CALIB, seed 10000): the MapPID method (optimize_mappid.m, O4).
%
%   optimize_pidlag(ctrl, runId, maxEvals)   one independent surrogateopt run (runId 1, 2, 3: own random seed 1000+runId, own files), maxEvals evaluations (default 250)
%   Variables: u in [0,1]^n mapped by pidlag_u2x. Objective log(J); a design rejected by the linear screen gets log(30) with its constraint values.
%   Constraints declared separately: linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707, e_rel <= 5 % (pidlag_eval c1-c4).
%   Resumable: every evaluation is cached in Result/Controllers/<ctrl>/Calib/<ctrl>_CALIB_opt<runId>_s10000.csv and the solver state in <ctrl>_CALIB_opt<runId>_ckpt.mat.
if nargin < 3 || isempty(maxEvals), maxEvals = 250; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
n = 4 + 2 * strcmp(ctrl, 'PIDLag');
outDir = result_dir(ctrl, 'Calib');
csvFile = fullfile(outDir, sprintf('%s_CALIB_opt%d_s10000.csv', ctrl, runId));
ckpt = fullfile(outDir, sprintf('%s_CALIB_opt%d_ckpt.mat', ctrl, runId));
fun = @(u) objconstr(ctrl, u, csvFile);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, ...
    'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1
    % surrogateopt's own design of experiments is deterministic (the same quasi-random points in every run), so runs 2, 3 start from their OWN 30 random points
    opts = optimoptions(opts, 'InitialPoints', rand(30, n));
end
tStart = tic;
if exist(ckpt, 'file')
    fprintf('optimize_pidlag(%s,%d): resuming from %s\n', ctrl, runId, ckpt);
    [u, fval, flag, out] = surrogateopt(ckpt, opts);
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, n), ones(1, n), [], [], [], [], [], opts);
end
x = pidlag_u2x(ctrl, u);
fprintf('optimize_pidlag(%s,%d) DONE: flag %d, %d evaluations, best J %.4f at %s (%.0f min)\n', ctrl, runId, flag, out.funccount, exp(fval), mat2str(x, 5), toc(tStart) / 60);
end

function F = objconstr(ctrl, u, csvFile)
x = pidlag_u2x(ctrl, u);
try
    o = pidlag_eval(ctrl, x, 10000, csvFile);
catch ME
    fprintf('objconstr: evaluation failed (%s), counted as infeasible\n', ME.message);
    F.Fval = log(30); F.Ineq = [200 200 200 200]; return;
end
if o.simulated
    F.Fval = log(max(o.R * o.S, 1e-6));
    F.Ineq = [o.c(1:3), o.erel - 5];
else
    F.Fval = log(30);
    F.Ineq = [o.c(1:3), 0];
end
F.Ineq(isnan(F.Ineq)) = 200;
F.Ineq = max(min(F.Ineq, 200), -200);
if ~isfinite(F.Fval), F.Fval = log(30); end
end
