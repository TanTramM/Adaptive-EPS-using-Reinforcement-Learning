function T = run_pid_sweep(stage, useLinearFilter)
%RUN_PID_SWEEP Sweep (Kp, Ki, Kd, Tf) of the PID on calibration case CALIB (seed 10000), resumable, results appended to PID_CALIB_sweep_s10000.csv.
%
%   T = run_pid_sweep('coarse')   coarse grid, only points that are linearly stable under the stress of QuyChuan 5.2 (gain x2, +1 ms delay)
%   T = run_pid_sweep('coarse2')  extra Ki = 3, 5, 7 for Kp 0.75-1.25 (same Ki grid as the PI)
%   T = run_pid_sweep('wide')     sparse grid up to the PID's own stress stability boundary (scan_pid_stability.m, 2026-10-11):
%                                 Kp 1.5-5, Ki 8-100, Kd 0.02 and 0.04, Tf 2.5 and 5 ms (the first grids used the PI bound Kp <= 1.5, Ki <= 8)
%   T = run_pid_sweep('fine')     3^4 grid around the design currently stored in data/pid.json, RELATIVE steps since 2026-10-11
%                                 (Kp x0.85/1.15, Ki x0.75/1.25, Kd x0.75/1.25, Tf x0.7/1.4), same filter
%
%   Kaw = Ki/Kp (fixed, as in the PI). Kd = 0 is the PI of the same family (one Tf only). Linear model: pid_stress_stable below (same plant as the PI:
%   K/(J s^2 + C s + K + k_r) with the motor lag, 1 ms zero-order hold, one extra sample of delay, loop gain x2, dry (k_r) and saturated (k_r = 0) tire).

if nargin < 2 || isempty(useLinearFilter), useLinearFilter = false; end   % QuyChuan v5: the linear stress filter is NOT a gate any more
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
SEED = 10000;
outDir = result_dir('PID', 'Calib');
candFile = fullfile(outDir, 'PID_CALIB_sweep_s10000.csv');

switch stage
    case 'coarse'
        [KP, KI, KD, TF] = ndgrid([0.25 0.5 0.75 1.0 1.25], [1 2 4 6 8], [0.01 0.02 0.04], [0.005 0.01 0.02]);
        G = [KP(:) KI(:) KD(:) TF(:)];
        [KP, KI] = ndgrid([0.25 0.5 0.75 1.0 1.25], [1 2 4 6 8]);
        G = [G; KP(:) KI(:) zeros(numel(KP), 1) 0.01 * ones(numel(KP), 1)];        % PI baseline (Kd = 0)
    case 'coarse2'      % fills the Ki values 3, 5, 7 (the PI grid has every integer Ki; e_rel is not monotonic in Ki), Kp >= 0.75 only (R > 38 % below)
        [KP, KI, KD, TF] = ndgrid([0.75 1.0 1.25], [3 5 7], [0.01 0.02 0.04], [0.005 0.01 0.02]);
        G = [KP(:) KI(:) KD(:) TF(:)];
        [KP, KI] = ndgrid([0.75 1.0 1.25], [3 5 7]);
        G = [G; KP(:) KI(:) zeros(numel(KP), 1) 0.01 * ones(numel(KP), 1)];
    case 'coarse3'      % Kp = 1.5 (linear stability bound of the PI under stress is Kp 1.5): the best points of the first grids sit at Kp = 1.25, the edge (QuyChuan 6.1)
        [KP, KI, KD, TF] = ndgrid(1.5, [2 3 4 6 8], [0.01 0.02 0.04], [0.005 0.01 0.02]);
        G = [KP(:) KI(:) KD(:) TF(:)];
        [KP, KI] = ndgrid(1.5, [2 3 4 6 8]);
        G = [G; KP(:) KI(:) zeros(numel(KP), 1) 0.01 * ones(numel(KP), 1)];
    case 'wide'         % sparse grid inside the PID stress stability boundary (Result/Controllers/PID/Design/PID_stability_boundary.csv)
        [KP, KI, KD, TF] = ndgrid([1.5 2 2.5 3 4 5], [8 16 32 64 100], [0.02 0.04], [0.0025 0.005]);
        G = [KP(:) KI(:) KD(:) TF(:)];
    case 'fine'
        J = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
        d = J.design;
        kpv = d.Kp * [0.85 1 1.15]; kiv = d.Ki * [0.75 1 1.25];
        if d.Kd > 0, kdv = d.Kd * [0.75 1 1.25]; tfv = d.Tf * [0.7 1 1.4]; else, kdv = [0 0.005 0.01]; tfv = d.Tf; end
        [KP, KI, KD, TF] = ndgrid(kpv, kiv, kdv, tfv);
        G = [KP(:) KI(:) KD(:) TF(:)];
        G = G(G(:, 1) > 0 & G(:, 2) > 0 & G(:, 3) >= 0, :);
    otherwise
        error('run_pid_sweep:stage', 'stage must be coarse, coarse2, coarse3, wide or fine');
end
G = round(G, 6);

if exist(candFile, 'file'), T = readtable(candFile); else, T = table(); end
% linear stability filter under the stress of QuyChuan 5.2 (only the points that can pass the margin gate are simulated)
ok = false(size(G, 1), 1);
for i = 1:size(G, 1)
    if useLinearFilter, ok(i) = pid_stress_stable(G(i, 1), G(i, 2), G(i, 3), G(i, 4)); else, ok(i) = true; end
end
fprintf('run_pid_sweep[%s]: %d grid points, %d linearly stable under stress\n', stage, size(G, 1), nnz(ok));
G = G(ok, :);

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'PID', 'load_pid.m'), '\', '/')));
mdl = 'Model_PID';
if ~bdIsLoaded(mdl), load_system(mdl); end
for i = 1:size(G, 1)
    kp = G(i, 1); ki = G(i, 2); kd = G(i, 3); tf_ = G(i, 4);
    if ~isempty(T) && any(abs(T.Kp - kp) < 1e-6 & abs(T.Ki_1_per_s - ki) < 1e-6 & abs(T.Kd_s - kd) < 1e-6 & abs(T.Tf_s - tf_) < 1e-6), continue; end
    tStart = tic;
    vars = struct('PID_Kp', kp, 'PID_Ki', ki, 'PID_Kd', kd, 'PID_Tf', tf_, 'PID_Kaw', ki / kp);
    try
        [~, m] = calib_run(mdl, SEED, vars);
        row = table(kp, ki, kd, tf_, m.R, m.Rg.static, m.Rg.dyn, m.Rg.mu, m.S, m.Scmd, m.TV, m.maxTa, m.erel, 100 * m.rev, ...
            'VariableNames', {'Kp', 'Ki_1_per_s', 'Kd_s', 'Tf_s', 'R_pct', 'R_static_pct', 'R_dyn_pct', 'R_mu_pct', ...
            'S_Nm', 'S_cmd_Nm', 'TV_Nm_per_s', 'max_Ta_Nm', 'erel_pct', 'rev_pct'});
        if isempty(T), T = row; else, T = [T; row]; end %#ok<AGROW>
        writetable(T, candFile);
        fprintf('run_pid_sweep[%s] %3d/%3d Kp %.3f Ki %.2f Kd %.4f Tf %.4f | R %6.2f S %.4f TV %6.1f erel %5.2f rev %5.2f (%.1f s)\n', ...
            stage, i, size(G, 1), kp, ki, kd, tf_, m.R, m.S, m.TV, m.erel, 100 * m.rev, toc(tStart));
    catch ME
        fprintf('run_pid_sweep[%s] FAILED Kp %.3f Ki %.2f Kd %.4f Tf %.4f: %s\n', stage, kp, ki, kd, tf_, ME.message);
    end
end
end

function ok = pid_stress_stable(Kp, Ki, Kd, Tf)
% Discrete PID C(z) = Kp + Ki Ts/(z-1) + b (z-1)/(z-a) on both linear plants with gain x2 and one extra sample of delay.
Ts = 0.001;
[G1c, G0c] = pi_plant_lin();
z = tf('z', Ts);
a = Tf / (Tf + Ts); b = Kd / (Tf + Ts);
C = Kp + Ki * Ts / (z - 1) + b * (z - 1) / (z - a);
ok = true;
for Gc = {G1c, G0c}
    Gd = c2d(Gc{1}, Ts, 'zoh');
    ok = ok && isstable(feedback(2 * (1 / z) * C * Gd, 1));
end
end
