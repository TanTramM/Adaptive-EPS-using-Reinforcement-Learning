function optimize_map(runId, maxEvals)
%OPTIMIZE_MAP Stage 1 of the common method (KeHoach_ChonNhieuSeed.txt): global search of the five Map variables [K, z, p/z, z1, p1/z1] on the simulated objective J = R*S (case CALIB v2, search seed 0).
%
%   optimize_map(runId, maxEvals)   one independent surrogateopt run (runId 1, 2, 3: own random seed 1000+runId, own files), maxEvals evaluations (default 250;
%                                   an evaluation rejected by the linear screen costs no simulation but counts in maxEvals).
%   Variables: u in [0,1]^5 mapped by map_u2x. Objective log(J); a design rejected by the linear screen gets log(30). Constraints declared separately: linear PM >= 30 deg,
%   GM >= 2, lag gain at 2 Hz >= 0.707 (map_opt_eval c1-c3), e_rel <= 5 % on the 26 static windows (c4). No start points from earlier work (they were CALIB v1): the solver
%   starts from 30 uniform random points of its own.
%   Resumable: every evaluation is cached in Result/Controllers/Map/Calib_v2/Map_CALIB_opt<runId>_s00000.csv and the solver state in D:/MatlabTemp/map_ckpt/Map_CALIB_opt<runId>_ckpt.mat.
if nargin < 2 || isempty(maxEvals), maxEvals = 250; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Calib');
csvFile = fullfile(outDir, sprintf('Map_CALIB_opt%d_s00000.csv', runId));
ckptDir = 'D:/MatlabTemp/map_ckpt'; if ~isfolder(ckptDir), mkdir(ckptDir); end   % outside OneDrive: its sync read-locks the file and surrogateopt then fails to reload it (2026-10-18)
ckpt = fullfile(ckptDir, sprintf('Map_CALIB_opt%d_ckpt.mat', runId));
fun = @(u) objconstr(u, csvFile);
opts = optimoptions('surrogateopt', 'MaxFunctionEvaluations', maxEvals, 'MinSurrogatePoints', 30, 'CheckpointFile', ckpt, ...
    'Display', 'iter', 'PlotFcn', [], 'UseParallel', false);
rng(1000 + runId);
if runId ~= 1
    opts = optimoptions(opts, 'InitialPoints', rand(30, 5));    % the default design of experiments of surrogateopt is deterministic
end
tStart = tic;
if exist(ckpt, 'file')
    fprintf('optimize_map(%d): resuming from %s\n', runId, ckpt);
    [u, fval, flag, out] = surrogateopt(ckpt, opts);
else
    [u, fval, flag, out] = surrogateopt(fun, zeros(1, 5), ones(1, 5), [], [], [], [], [], opts);
end
x = map_u2x(u);
fprintf('optimize_map(%d) DONE: flag %d, %d evaluations, best J %.4f at K %.3g z %.4g p/z %.4g z1 %.4g p1/z1 %.3g (%.0f min)\n', ...
    runId, flag, out.funccount, exp(fval), x, toc(tStart) / 60);
end

function F = objconstr(u, csvFile)
x = map_u2x(u);
try
    o = map_opt_eval(x, 0, csvFile);
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
