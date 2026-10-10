function T = run_pi_sweep(runSim, kiStepMode)
%RUN_PI_SWEEP Step P4 of the PI plan: simulate calibration case TK on the coarse grid.
%
%   T = run_pi_sweep()                  simulate coarse grid candidates (resumable)
%   T = run_pi_sweep(runSim, kiStepMode)
%
%   Inputs:
%     runSim     logical, true to run simulations (default true)
%     kiStepMode 'coarse_1' (default, Ki in [0.5, 1, 2, ..., 8] -> 103 points inside boundary)
%                'coarse_0p5' (Ki in 0.5:0.5:8.0 -> 181 points inside boundary)
%
%   Boundary:
%     Linear stability boundary under stress (Actuator gain x2, delay +1 ms)
%     from Result/Controllers/PI/Design/PI_stability_boundary.csv (P3).
%     Kp in [0.05:0.10:1.45] (15 points). Only points with Ki <= max_Ki_under_stress
%     are simulated, guaranteeing that points outside the feasible boundary
%     (which are guaranteed to violate gate 5.2) are not run.
%
%   Case TK:
%     117 s case with 3 speed blocks (20, 60, 100 km/h), 19 windows,
%     sensor noise with local seed 10000.
%     Metrics: R (average of 4 groups: static, dyn, small, mu), S, Scmd,
%     TV, maxTa, erel (worst across 11 static windows), rev, and per-block scores.
%
%   Outputs:
%     T table of all simulated candidates written to
%     Result/Controllers/PI/Sweep/PI_candidates_TK.csv (resumable).
%     Pareto figure saved to Result/Controllers/PI/Sweep/PI_pareto_coarse.png.

if nargin < 1 || isempty(runSim), runSim = true; end
if nargin < 2 || isempty(kiStepMode), kiStepMode = 'coarse_1'; end

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

SEED = 10000;
blocks = [20 60 100];
outDir = result_dir('PI', 'Sweep');
candFile = fullfile(outDir, 'PI_candidates_TK.csv');

% Load stability boundary from P3
boundFile = fullfile(result_dir('PI', 'Design'), 'PI_stability_boundary.csv');
if ~exist(boundFile, 'file')
    error('run_pi_sweep:missing_boundary', 'Stability boundary file not found: %s. Run identify_plant first.', boundFile);
end
boundTable = readtable(boundFile);

% Define coarse grid
kpGrid = 0.05:0.10:1.45;
if strcmp(kiStepMode, 'coarse_0p5')
    kiGrid = 0.5:0.5:8.0;
else
    kiGrid = [0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0];
end

% Build candidate list inside linear stability boundary
C = [];
for kp = kpGrid
    maxKi = interp1(boundTable.Kp, boundTable.max_Ki_under_stress, kp, 'linear', 'extrap');
    validKi = kiGrid(kiGrid <= (maxKi + 1e-4));
    for ki = validKi
        C = [C; kp, ki, ki / kp]; %#ok<AGROW>
    end
end
numCand = size(C, 1);
fprintf('run_pi_sweep: Coarse grid defined with %d points inside stability boundary (%s mode).\n', numCand, kiStepMode);

% Load existing results if resumable
if exist(candFile, 'file')
    T = readtable(candFile);
    fprintf('run_pi_sweep: Loaded existing candidate table with %d rows from %s.\n', height(T), candFile);
else
    T = table();
end

if runSim
    % Ensure base workspace has variables and model is ready
    evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'PI', 'load_pi.m'), '\', '/')));
    mdl = 'Model_PI';
    if ~bdIsLoaded(mdl), load_system(mdl); end
    TKcase = test_cases('TK');

    for i = 1:numCand
        kp = C(i, 1);
        ki = C(i, 2);
        kaw = C(i, 3);

        % Check if already simulated
        if ~isempty(T) && any(abs(T.Kp - kp) < 1e-5 & abs(T.Ki_1_per_s - ki) < 1e-5)
            continue;
        end

        tStart = tic;
        vars = struct('PI_Kp', kp, 'PI_Ki', ki, 'PI_Kaw', kaw);
        try
            [L, m] = tk_run(mdl, SEED, vars);
            sc = tk_block_scores(L, TKcase, blocks);
            elTime = toc(tStart);

            row = table(kp, ki, kaw, ...
                m.R, m.Rg.static, m.Rg.dyn, m.Rg.small, m.Rg.mu, ...
                m.S, m.Scmd, m.TV, m.maxTa, m.erel, m.rev * 100, ...
                sc.R(1), sc.S(1), sc.TV(1), sc.erel(1), ...
                sc.R(2), sc.S(2), sc.TV(2), sc.erel(2), ...
                sc.R(3), sc.S(3), sc.TV(3), sc.erel(3), ...
                'VariableNames', { ...
                'Kp', 'Ki_1_per_s', 'Kaw', ...
                'R_pct', 'R_static_pct', 'R_dyn_pct', 'R_small_pct', 'R_mu_pct', ...
                'S_Nm', 'S_cmd_Nm', 'TV_Nm_per_s', 'max_Ta_Nm', 'erel_pct', 'rev_pct', ...
                'R_v20', 'S_v20', 'TV_v20', 'erel_v20', ...
                'R_v60', 'S_v60', 'TV_v60', 'erel_v60', ...
                'R_v100', 'S_v100', 'TV_v100', 'erel_v100'});

            if isempty(T)
                T = row;
            else
                T = [T; row]; %#ok<AGROW>
            end
            writetable(T, candFile);

            fprintf('run_pi_sweep: [%3d/%3d] Kp=%.2f, Ki=%.1f | R=%6.2f%%, S=%.4f, TV=%5.1f, erel=%5.2f%%, rev=%4.2f%% (%4.1fs)\n', ...
                i, numCand, kp, ki, m.R, m.S, m.TV, m.erel, m.rev * 100, elTime);
        catch ME
            fprintf('run_pi_sweep: [FAILED %3d/%3d] Kp=%.2f, Ki=%.1f: %s\n', i, numCand, kp, ki, ME.message);
        end
    end
end

% Plot preliminary Pareto front
if ~isempty(T)
    plotParetoCoarse(T, fullfile(outDir, 'PI_pareto_coarse.png'));
end

end

function plotParetoCoarse(T, outFile)
% Plots preliminary R vs S scatter with gate filtering

% Hard gates:
% 1. Reverse assist <= 1%
% 2. Steady accuracy erel <= 3%
passRev = T.rev_pct <= 1.0;
passErel = T.erel_pct <= 3.0;
passGates = passRev & passErel;

f = figure('Visible', 'off', 'Position', [100 100 850 600]);
hold on; grid on; box on;

% Plot points failing gates in light gray
if any(~passGates)
    plot(T.R_pct(~passGates), T.S_Nm(~passGates), 'x', ...
        'Color', [0.75 0.75 0.75], 'MarkerSize', 6, 'LineWidth', 1.0, ...
        'DisplayName', 'Failed gates (erel > 3% or rev > 1%)');
end

% Plot points passing gates
if any(passGates)
    scatter(T.R_pct(passGates), T.S_Nm(passGates), 40, T.Kp(passGates), 'filled', ...
        'DisplayName', 'Passed gates (colored by K_p)');
    cb = colorbar;
    cb.Label.String = 'K_p [N.m/(N.m)]';
end

xlabel('R: Total Response Error [%]', 'FontSize', 11);
ylabel('S: High-Pass RMS of T_a [N.m]', 'FontSize', 11);
title('PI Coarse Sweep (Case TK, 117s, seed 10000)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 9);

% Annotate best R and best S among gate-passing points
if any(passGates)
    idxPass = find(passGates);
    [minR, iR] = min(T.R_pct(idxPass));
    bestR_idx = idxPass(iR);
    text(T.R_pct(bestR_idx), T.S_Nm(bestR_idx), ...
        sprintf('  Min R (%.1f%%, Kp=%.2f, Ki=%.1f)', minR, T.Kp(bestR_idx), T.Ki_1_per_s(bestR_idx)), ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.8 0 0]);
end

saveas(f, outFile);
close(f);
fprintf('run_pi_sweep: Saved preliminary Pareto figure to %s\n', outFile);
end

