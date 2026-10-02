function C = tune_pidf()
%TUNE_PIDF PID with a stronger derivative filter (PIDF): same crossover and phase margin as the Map, noise gain not above the Map's.
%
%   Writes data/pidf.json and Result/PIDF/Tuning/. The PID of tune_pid.m (pidtune) is NOT changed.
%
%   Design (chosen before running any test case, same criteria as the Map, see Documents/Sim/SoSanh.txt):
%     - Controller: discrete PIDF, Forward Euler, C(z) = Kp + Ki*Ts/(z-1) + Kd/(Tf + Ts/(z-1)) (the controller of build_pid.m).
%     - Plant: the linearized steering-column loop of the Map design (theta1 held, ZOH at Ts_ctrl): G1 (tire gripping, k_r) and
%       G0 (tire saturated, k_r = 0), as in tune_pid.m.
%     - Crossover wc = crossover of the Map loop at K_max (same speed as the Map); phase margin 45 deg on G1 (checked on G0).
%     - Ti*wc is kept as in the pidtune design (Ti = Kp/Ki of data/pid.json times its crossover).
%     - Noise gain = rms of |C(e^{j theta})| over 0..Nyquist (gain of C to white noise of the torque sensor sampled at Ts). It must
%       not exceed the Map's: K_max * rms|H| of the Map compensator (data/map.json). The derivative filter constant Tf is the free
%       parameter: the smallest Tf (weakest filter) whose noise gain does not exceed the Map's budget. For each Tf, Kp and Kd follow
%       from the complex loop condition C(e^{j wc Ts}) G1(e^{j wc Ts}) = e^{j(-180 + PM)} (two real equations, two unknowns).

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

Ts = 0.001;
pmTarget = 45;                                  % deg, same as the Map
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
mp = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
pj = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
assert(abs(mp.Ts_ctrl.value - Ts) < 1e-12 && abs(pj.Ts_ctrl.value - Ts) < 1e-12, 'sample time mismatch');

kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
G1 = c2d(tf(P.K, [P.J_col, P.C_col, P.K + kr]), Ts, 'zoh');
G0 = c2d(tf(P.K, [P.J_col, P.C_col, P.K]), Ts, 'zoh');
H  = tf(mp.lead.num(:)', mp.lead.den(:)', Ts)^mp.lead.stages;
[gmMap, pmMap, ~, wc] = margin(mp.Kmax.value * H * G1);
th = linspace(1e-4, pi, 4000);
noiseGain = @(Cz) sqrt(mean(abs(squeeze(freqresp(Cz, th / Ts))).^2));
budget = mp.Kmax.value * noiseGain(H);          % Map noise gain at its largest slope
z = tf('z', Ts);
cpid = @(Kp, Ki, Kd, Tf) Kp + Ki * Ts / (z - 1) + Kd / (Tf + Ts / (z - 1));
Cold = cpid(pj.Kp.value, pj.Ki.value, pj.Kd.value, pj.T_filt.value);
TiWc = (pj.Kp.value / pj.Ki.value) * wc;

% loop condition at wc for a given Tf
zc = exp(1j * wc * Ts);
target = exp(1j * (-pi + deg2rad(pmTarget))) / squeeze(freqresp(G1, wc));
Ti = TiWc / wc;
a = 1 + (Ts / Ti) / (zc - 1);                   % coefficient of Kp
solveGains = @(Tf) [real(a) real(1 / (Tf + Ts / (zc - 1))); imag(a) imag(1 / (Tf + Ts / (zc - 1)))] \ [real(target); imag(target)];

% smallest Tf with noise gain <= budget (noise gain decreases with Tf); Kp must stay positive
TfGrid = linspace(Ts / 2 * 1.01, 6e-3, 600);
Tf = NaN;
for k = 1:numel(TfGrid)
    s = solveGains(TfGrid(k));
    if s(1) <= 0 || s(2) <= 0, break; end
    if noiseGain(cpid(s(1), s(1) / Ti, s(2), TfGrid(k))) <= budget, Tf = TfGrid(k); break; end
end
assert(~isnan(Tf), 'no Tf meets the noise budget %.1f with Kp > 0', budget);
s = solveGains(Tf);
Kp = s(1); Kd = s(2); Ki = Kp / Ti;
C = cpid(Kp, Ki, Kd, Tf);
[gm1, pm1, ~, wc1] = margin(C * G1);
[gm0, pm0, ~, wc0] = margin(C * G0);
assert(isstable(feedback(C * G1, 1)) && isstable(feedback(C * G0, 1)), 'unstable loop');
assert(pm1 >= pmTarget - 0.5 && pm0 >= pmTarget - 0.5, 'phase margin below %g deg (G1 %.1f, G0 %.1f)', pmTarget, pm1, pm0);
ngNew = noiseGain(C);  ngOld = noiseGain(Cold);
[~, pmOld] = margin(Cold * G1);

out = struct();
out.x_note = ['Discrete PIDF (Forward Euler) with a stronger derivative filter, written by Model/PID/script/tune_pidf.m: same crossover ' ...
    'and phase margin (45 deg) as the Map, derivative filter constant chosen so that the noise gain (rms gain to white noise up to ' ...
    'Nyquist) does not exceed the Map''s. The pidtune PID (data/pid.json) is unchanged.'];
out.Ts_ctrl = struct('value', Ts, 'unit', 's', 'desc', 'ECU sample time, same as the Map and the RL agent');
out.Kp      = struct('value', Kp, 'unit', '-', 'desc', 'proportional gain');
out.Ki      = struct('value', Ki, 'unit', '1/s', 'desc', 'integral gain (Forward Euler)');
out.Kd      = struct('value', Kd, 'unit', 's', 'desc', 'derivative gain');
out.T_filt  = struct('value', Tf, 'unit', 's', 'desc', 'derivative filter time constant (Forward Euler, > Ts/2)');
out.design  = struct('crossover_rad_s', wc, 'phase_margin_target_deg', pmTarget, 'pm_tire_deg', pm1, 'gm_tire', gm1, ...
    'pm_saturated_deg', pm0, 'gm_saturated', gm0, 'noise_gain', ngNew, 'noise_gain_budget_map', budget, ...
    'noise_gain_pid_pidtune', ngOld, 'Ti_times_wc', TiWc);
fid = fopen(fullfile(modelDir, 'data', 'pidf.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(out, 'PrettyPrint', true));
fclose(fid);

outDir = result_dir('PIDF', 'Tuning');
R = table(Ts, wc, Kp, Ki, Kd, Tf, pm1, gm1, wc1, pm0, gm0, wc0, ngNew, budget, ngOld, pmOld, ...
    'VariableNames', {'Ts_s', 'target_crossover_rad_s', 'Kp', 'Ki_1_per_s', 'Kd_s', 'T_filt_s', 'PM_tire_deg', 'GM_tire', ...
    'crossover_tire_rad_s', 'PM_saturated_deg', 'GM_saturated', 'crossover_saturated_rad_s', 'noise_gain', 'noise_gain_budget_Map', ...
    'noise_gain_PID_pidtune', 'PM_PID_pidtune_deg'});
writetable(R, fullfile(outDir, 'PIDF_tuning_result.csv'));
f = figure('Visible', 'off', 'Position', [100 100 1000 650]);
w = logspace(0, log10(pi / Ts), 600);
loglog(w, mp.Kmax.value * abs(squeeze(freqresp(H, w))), 'Color', [0.165 0.471 0.839], 'LineWidth', 1.4); hold on;
loglog(w, abs(squeeze(freqresp(Cold, w))), 'Color', [0.922 0.408 0.204], 'LineWidth', 1.4);
loglog(w, abs(squeeze(freqresp(C, w))), 'Color', [0.29 0.23 0.65], 'LineWidth', 1.4);
grid on; xlabel('\omega [rad/s]'); ylabel('|C(j\omega)| [N.m/N.m]');
legend({sprintf('Map (K_v = %g x lead), noise gain %.0f', mp.Kmax.value, budget), sprintf('PID pidtune, noise gain %.0f', ngOld), ...
    sprintf('PIDF, noise gain %.0f', ngNew)}, 'Location', 'northwest');
title(sprintf('Controller gain; crossover %.0f rad/s, PM: PID %.1f, PIDF %.1f deg', wc, pmOld, pm1));
exportgraphics(f, fullfile(outDir, 'PIDF_tuning_controller_gain.png'), 'Resolution', 130);
close(f);

fprintf(['tune_pidf: crossover %.1f rad/s (Map loop PM %.1f, GM %.2f), noise gain budget (Map) %.1f, PID pidtune %.1f, PIDF %.1f\n' ...
    '  Kp = %.4g, Ki = %.4g 1/s, Kd = %.4g s, T_filt = %.4g s (pidtune: %.4g ms)\n' ...
    '  PIDF loop: tire gripping PM %.1f deg GM %.2f; tire saturated PM %.1f deg GM %.2f\n  wrote data/pidf.json and %s\n'], ...
    wc, pmMap, gmMap, budget, ngOld, ngNew, Kp, Ki, Kd, Tf, pj.T_filt.value * 1e3, pm1, gm1, pm0, gm0, outDir);
end
