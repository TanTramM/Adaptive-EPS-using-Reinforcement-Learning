function optimize_mappidlag(runId, maxEvals, variant)
%OPTIMIZE_MAPPIDLAG P4 of DieuKhien_MapPIDLag.txt: global search of the MapPIDLag variables on the simulated objective J = R*S (case CALIB, seed 50000).
%
%   optimize_mappidlag(runId, maxEvals, variant)   one independent surrogateopt run (runId 1, 2, 3: own random seed 1000+runId, own files), maxEvals evaluations
%                                      (an evaluation rejected by the linear screen costs no simulation but counts in maxEvals)
%   variant 'MapPIDLag' (default): seven variables u in [0,1]^7 mapped by mappidlag_u2x; 'PIDLag': the PID + lag reference, K fixed at 0, six variables
%   Objective log(J) (same minimizer, better scaled for the surrogate); a design rejected by the linear screen gets log(30) with its constraint values.
%   Constraints, declared separately (C3): linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707 (mappidlag_eval c1-c3), e_rel <= 5 % (c4, 0 when not simulated).
%   Same method as optimize_mappid.m (MapPID): no starting points (surrogateopt draws its own design of experiments, MinSurrogatePoints 30); the runs 2, 3 start
%   from their OWN 30 uniform random points because the default design is deterministic. Resumable: every evaluation is cached in
%   Result/Controllers/MapPIDLag/Calib/<variant>_CALIB_opt<runId>_s50000.csv and the solver state in <variant>_CALIB_opt<runId>_ckpt.mat.
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
if nargin < 3 || isempty(variant), variant = 'MapPIDLag'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
nv = nVars(variant);
outDir = result_dir('MapPIDLag', 'Calib');
csvFile = fullfile(outDir, sprintf('%s_CALIB_opt%d_s50000.csv', variant, runId));
ckpt = fullfile(outDir, sprintf('%s_CALIB_opt%d_ckpt.mat', variant, runId));
fun = @(u) objconstr(u, csvFile, variant);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, ...
    'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1
    opts = optimoptions(opts, 'InitialPoints', rand(30, nv));
end
tStart = tic;
if exist(ckpt, 'file')
    fprintf('optimize_mappidlag(%s, %d): resuming from %s\n', variant, runId, ckpt);
    [u, fval, flag, out] = surrogateopt(ckpt, opts);
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, nv), ones(1, nv), [], [], [], [], [], opts);
end
x = mappidlag_u2x(embed(u, variant));
fprintf('optimize_mappidlag(%s, %d) DONE: flag %d, %d evaluations, best J %.4f at K %.3g z1 %.4g p1/z1 %.3g Kp %.3g Ki %.4g Kd %.4g Tf %.4g (%.0f min)\n', ...
    variant, runId, flag, out.funccount, exp(fval), x, toc(tStart) / 60);
end

function n = nVars(variant)
if strcmp(variant, 'PIDLag'), n = 6; else, n = 7; end
end

function u7 = embed(u, variant)
% PIDLag: the optimisation variables are u(2..7) of the seven, K = 0 (u(1) = 0)
if strcmp(variant, 'PIDLag'), u7 = [0, u(:)']; else, u7 = u(:)'; end
end

function F = objconstr(u, csvFile, variant)
x = mappidlag_u2x(embed(u, variant));
try
    o = mappidlag_eval(x, 50000, csvFile);
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
