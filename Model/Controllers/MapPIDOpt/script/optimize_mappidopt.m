function optimize_mappidopt(runId, maxEvals)
%OPTIMIZE_MAPPIDOPT O4 of DieuKhien_MapPIDOpt.txt: global search of the nine MapPIDOpt variables on the simulated objective J = R*S (case CALIB, seed 30000).
%
%   optimize_mappidopt(runId, maxEvals)   one independent surrogateopt run (runId 1, 2, 3: own random seed 1000+runId, own files), maxEvals evaluations
%                                      (an evaluation rejected by the linear screen costs no simulation but counts in maxEvals)
%   Variables: u in [0,1]^9, mapped by mappidopt_u2x (bounds of C2). Objective log(J) (same minimizer, better scaled for the surrogate); a design rejected by
%   the linear screen gets log(30) (J = 30 is worse than every useful design) with its constraint values. Constraints, declared separately (C3, option C):
%   linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707 (mappidopt_eval c1-c3), e_rel <= 5 % (c4, 0 when not simulated).
%   Starting points: none given (the user chose not to start from the Map or the PID design; the systune designs of O3 were degenerate), surrogateopt
%   draws its own random design of experiments (MinSurrogatePoints 30). Resumable: every evaluation is cached in
%   Result/Controllers/MapPIDOpt/Calib/MapPIDOpt_CALIB_opt<runId>_s30000.csv (mappidopt_eval) and the solver state in MapPIDOpt_CALIB_opt<runId>_ckpt.mat.
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPIDOpt', 'Calib');
csvFile = fullfile(outDir, sprintf('MapPIDOpt_CALIB_opt%d_s30000.csv', runId));
ckpt = fullfile(outDir, sprintf('MapPIDOpt_CALIB_opt%d_ckpt.mat', runId));
fun = @(u) objconstr(u, csvFile);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, ...
    'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1
    % surrogateopt's own design of experiments is deterministic (the same quasi-random points in every run, seen 2026-10-13), so runs 2, 3, ...
    % start from their OWN 30 uniform random points (rng 1000+runId); run 1 keeps the default design. This makes the runs independent.
    opts = optimoptions(opts, 'InitialPoints', rand(30, 9));
end
tStart = tic;
if exist(ckpt, 'file')
    fprintf('optimize_mappidopt(%d): resuming from %s\n', runId, ckpt);
    [u, fval, flag, out] = surrogateopt(ckpt, opts);
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, 9), ones(1, 9), [], [], [], [], [], opts);
end
x = mappidopt_u2x(u);
fprintf('optimize_mappidopt(%d) DONE: flag %d, %d evaluations, best J %.4f at K %.3g z %.4g p/z %.4g z1 %.4g p1/z1 %.3g Kp %.3g Ki %.4g Kd %.4g Tf %.4g (%.0f min)\n', ...
    runId, flag, out.funccount, exp(fval), x, toc(tStart) / 60);
end

function F = objconstr(u, csvFile)
x = mappidopt_u2x(u);
try
    o = mappidopt_eval(x, 30000, csvFile);
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
