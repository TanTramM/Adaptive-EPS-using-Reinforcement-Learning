function optimize_mapopt(runId, maxEvals, suffix)
%OPTIMIZE_MAPOPT Stage 1 of DieuKhien_MapOpt.txt (C1): global search of the five MapOpt variables on the simulated objective J = R*S (case CALIB, search seed 0).
%
%   optimize_mapopt(runId, maxEvals)   one independent surrogateopt run (runId 1, 2, 3: own random seed 1000+runId, own files), maxEvals evaluations
%                                      (an evaluation rejected by the linear screen costs no simulation but counts in maxEvals)
%   Variables: u in [0,1]^5, mapped by mapopt_u2x. Objective log(J); a design rejected by the linear screen gets log(30) with its constraint values. Constraints,
%   declared separately: linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707 (mapopt_eval c1-c3), e_rel <= 5 % (c4, 0 when not simulated). No starting points;
%   runs 2, 3 start from their OWN 30 uniform random points (the default design of experiments of surrogateopt is deterministic). Same method as optimize_mappid.m.
%   optimize_mapopt(runId, maxEvals, 'b')   RUN 2 (DieuKhien_MapOpt.txt Part M): thresholds PM >= 30 deg and GM >= 2 already in the search (mapopt_cfg), files ...opt<k>b...;
%   start points = the evaluations of the SAME chain of run 1 (folder Calib_run1; same seed, box and function, so they are valid): X = u, Fval and Ineq recomputed from the
%   stored PM, GM, c3, c4; they cost no simulation and are not counted in maxEvals (checked 2026-10-17: 40 start points with Fval and MaxFunctionEvaluations 50 give 50 calls).
%   Resumable: every evaluation is cached in Result/Controllers/MapOpt/Calib/MapOpt_CALIB_opt<runId>_s00000.csv and the solver state in MapOpt_CALIB_opt<runId>_ckpt.mat.
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
if nargin < 3, suffix = ''; end
cfg = mapopt_cfg(suffix);
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
csvFile = fullfile(outDir, sprintf('MapOpt_CALIB_opt%d%s_s00000.csv', runId, suffix));
ckpt = fullfile(outDir, sprintf('MapOpt_CALIB_opt%d%s_ckpt.mat', runId, suffix));
fun = @(u) objconstr(u, csvFile, cfg);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, ...
    'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if ~isempty(suffix)
    ip = mapopt_run1_points(outDir, runId, cfg);
    fprintf('optimize_mapopt(%d%s): %d start points from run 1\n', runId, suffix, size(ip.X, 1));
    opts = optimoptions(opts, 'InitialPoints', ip);
elseif runId ~= 1
    opts = optimoptions(opts, 'InitialPoints', rand(30, 5));
end
tStart = tic;
if exist(ckpt, 'file')
    fprintf('optimize_mapopt(%d): resuming from %s\n', runId, ckpt);
    [u, fval, flag, out] = surrogateopt(ckpt, opts);
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, 5), ones(1, 5), [], [], [], [], [], opts);
end
x = mapopt_u2x(u);
fprintf('optimize_mapopt(%d) DONE: flag %d, %d evaluations, best J %.4f at K %.3g z %.4g p/z %.4g z1 %.4g p1/z1 %.3g (%.0f min)\n', ...
    runId, flag, out.funccount, exp(fval), x, toc(tStart) / 60);
end

function F = objconstr(u, csvFile, cfg)
x = mapopt_u2x(u);
try
    o = mapopt_eval(x, 0, csvFile, cfg);
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
