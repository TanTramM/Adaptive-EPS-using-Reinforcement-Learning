function T = run_smc_sweep()
%RUN_SMC_SWEEP Sweep (lambda, Phi, Tf) of the SMC-sat (no integral) on calibration case CALIB (seed 20000), resumable, results appended to SMC_CALIB_sweep_s20000.csv.
%
%   T = run_smc_sweep()
%
%   Grid fixed before running (QuyChuan 6.1): lambda [rad/s] x Phi [N.m/s] x Tf [s]. Phi range 50-800 because the equivalent derivative gain is Tamax/Phi (0.01-0.2 s, like the PID Kd);
%   the first grid (Phi 0.25-8, 21 points kept in SMC_CALIB_sweep_grid1_s20000.csv) gave a 25 Hz limit cycle (T_a +-9 N.m) at every point. Every point is simulated (no linear pre-filter: the sat law is
%   nonlinear); stability margin and bang-bang are evaluated on the finalists by select_smc.m. Same table columns as PID_CALIB_sweep_s10000.csv.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
SEED = 20000;
outDir = result_dir('SMC', 'Calib');
candFile = fullfile(outDir, 'SMC_CALIB_sweep_s20000.csv');

[LAM, PHI, TF] = ndgrid([10 20 40 80 160], [50 100 200 400 800], [0.005 0.01]);
G = round([LAM(:) PHI(:) TF(:)], 6);

if exist(candFile, 'file'), T = readtable(candFile); else, T = table(); end
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'SMC', 'load_smc.m'), '\', '/')));
mdl = 'Model_SMC';
if ~bdIsLoaded(mdl), load_system(mdl); end
for i = 1:size(G, 1)
    lam = G(i, 1); phi = G(i, 2); tf_ = G(i, 3);
    if ~isempty(T) && any(abs(T.lambda_rad_s - lam) < 1e-6 & abs(T.Phi_Nm_s - phi) < 1e-6 & abs(T.Tf_s - tf_) < 1e-6), continue; end
    tStart = tic;
    vars = struct('SMC_lambda', lam, 'SMC_Phi', phi, 'SMC_Tf', tf_);
    try
        [~, m] = calib_run(mdl, SEED, vars);
        row = table(lam, phi, tf_, m.R, m.Rg.static, m.Rg.dyn, m.Rg.small, m.Rg.mu, m.S, m.Scmd, m.TV, m.maxTa, m.erel, 100 * m.rev, ...
            'VariableNames', {'lambda_rad_s', 'Phi_Nm_s', 'Tf_s', 'R_pct', 'R_static_pct', 'R_dyn_pct', 'R_small_pct', 'R_mu_pct', ...
            'S_Nm', 'S_cmd_Nm', 'TV_Nm_per_s', 'max_Ta_Nm', 'erel_pct', 'rev_pct'});
        if isempty(T), T = row; else, T = [T; row]; end %#ok<AGROW>
        writetable(T, candFile);
        fprintf('run_smc_sweep %3d/%3d lambda %5.1f Phi %5.2f Tf %.3f | R %6.2f S %.4f TV %6.1f erel %5.2f rev %5.2f (%.1f s)\n', ...
            i, size(G, 1), lam, phi, tf_, m.R, m.S, m.TV, m.erel, 100 * m.rev, toc(tStart));
    catch ME
        fprintf('run_smc_sweep FAILED lambda %g Phi %g Tf %g: %s\n', lam, phi, tf_, ME.message);
    end
end
end
