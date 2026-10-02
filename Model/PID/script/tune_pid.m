function C = tune_pid()
%TUNE_PID Tune the discrete PID at Ts_ctrl = 1 ms with pidtune (Control System Toolbox) and write data/pid.json.
%
%   Replaces the Ziegler-Nichols rule, which fails at 1 ms: the ultimate gain is about 2000-4000 there, so ZN gives
%   Kp ~ 2458 and a torque T_a that reverses sign every sample (Documents/PID/DieuKhien_PID.txt section 8.3).
%
%   Design model = the SAME linearized steering-column loop the Map's lead stage was designed on ([1] section III,
%   calibrate_map.m designLead), theta1 held, discretized with ZOH at Ts_ctrl:
%       G1(s) = K / (J_col s^2 + C_col s + K + k_r),  k_r = e_p0*C_alpha_f/n_st^2   (tire gripping)
%       G0(s) = K / (J_col s^2 + C_col s + K)                                      (tire saturated, k_r = 0)
%   G is the transfer from T_a to -T_s, so the PID (T_a = +PID(e_T), e_T = T_s - T_d,ref) closes a negative loop.
%   Criterion, the same as the Map's: phase margin >= 45 deg ([1] section III.D). Crossover frequency = crossover of
%   the Map loop at its largest slope K_max (Kmax * lead * G1), so PID and Map are equally fast and differ only in
%   structure. pidtune('PIDF', wc, PhaseMargin 45) on G1; the margins are then checked on both G1 and G0.
%
%   The discrete PIDF of pidtune with ForwardEuler integral and derivative formulas,
%       C(z) = Kp + Ki*Ts/(z-1) + Kd / (Tf + Ts/(z-1)),
%   is exactly the controller built by build_pid.m (u_I Forward Euler, w = (e - x)/T_filt, x[k+1] = x[k] + Ts*w,
%   u_D = Kd*w), so the gains are used as they are, with T_filt = Tf.
%
%   Writes: data/pid.json (Ts_ctrl, Kp, Ki, Kd, T_filt + the design record)
%           Result/PID/Tuning/PID_tuning_result.csv  gains, crossover, margins on G1 and G0, Map loop for comparison
%           Result/PID/Tuning/PID_tuning_loop_bode.png  open-loop Bode of the Map loop and the PID loop (G1)

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

Ts = 0.001;          % common controller sample time of all controllers (same as the Map)
pmTarget = 45;       % deg, [1] section III.D, same criterion as the Map's lead stage

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
mp = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
assert(abs(mp.Ts_ctrl.value - Ts) < 1e-12, 'map.json Ts_ctrl differs from the PID sample time');

kr = P.e_p0 * P.C_alpha_f / P.n_st^2;                         % same k_r as calibrate_map.m
G1 = c2d(tf(P.K, [P.J_col, P.C_col, P.K + kr]), Ts, 'zoh');
G0 = c2d(tf(P.K, [P.J_col, P.C_col, P.K]), Ts, 'zoh');
H  = tf(mp.lead.num(:)', mp.lead.den(:)', Ts)^mp.lead.stages;
Lmap = mp.Kmax.value * H * G1;
[gmMap, pmMap, ~, wc] = margin(Lmap);

opt = pidtuneOptions('PhaseMargin', pmTarget, 'DesignFocus', 'balanced');
C = pidtune(G1, 'PIDF', wc, opt);
assert(strcmp(C.IFormula, 'ForwardEuler') && strcmp(C.DFormula, 'ForwardEuler'), 'unexpected discretization formula');
assert(C.Tf > Ts / 2, 'derivative filter Tf = %g s is not stable with Forward Euler (needs Tf > Ts/2)', C.Tf);
[gm1, pm1, ~, wc1] = margin(C * G1);
[gm0, pm0, ~, wc0] = margin(C * G0);
assert(pm1 >= pmTarget - 0.5 && pm0 >= pmTarget - 0.5, 'phase margin below %g deg (G1 %.1f, G0 %.1f)', pmTarget, pm1, pm0);

% ---- data/pid.json ----
out = struct();
out.x_note = ['Discrete PID (PIDF, Forward Euler) of the assist loop, Documents/PID/DieuKhien_PID.txt. Written by ' ...
    'Model/PID/script/tune_pid.m: pidtune on the linearized steering-column loop of the Map design (theta1 held, ' ...
    'ZOH at Ts_ctrl), phase margin >= 45 deg at the crossover of the Map loop at K_max.'];
out.Ts_ctrl  = struct('value', Ts, 'unit', 's', 'desc', 'ECU sample time, same as the Map and the RL agent');
out.Kp       = struct('value', C.Kp, 'unit', '-', 'desc', 'proportional gain');
out.Ki       = struct('value', C.Ki, 'unit', '1/s', 'desc', 'integral gain (Forward Euler)');
out.Kd       = struct('value', C.Kd, 'unit', 's', 'desc', 'derivative gain');
out.T_filt   = struct('value', C.Tf, 'unit', 's', 'desc', 'derivative filter time constant (Forward Euler, > Ts/2)');
out.design   = struct('crossover_rad_s', wc, 'phase_margin_target_deg', pmTarget, ...
    'pm_tire_deg', pm1, 'gm_tire', gm1, 'pm_saturated_deg', pm0, 'gm_saturated', gm0, ...
    'map_loop_pm_deg', pmMap, 'map_loop_gm', gmMap, 'k_r_Nm_per_rad', kr);
fid = fopen(fullfile(modelDir, 'data', 'pid.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(out, 'PrettyPrint', true));
fclose(fid);

% ---- Result/PID/Tuning ----
outDir = result_dir('PID', 'Tuning');
R = table(Ts, wc, wc / (2 * pi), C.Kp, C.Ki, C.Kd, C.Tf, pm1, gm1, wc1, pm0, gm0, wc0, pmMap, gmMap, ...
    'VariableNames', {'Ts_s', 'target_crossover_rad_s', 'target_crossover_Hz', 'Kp', 'Ki_1_per_s', 'Kd_s', 'T_filt_s', ...
    'PM_tire_deg', 'GM_tire', 'crossover_tire_rad_s', 'PM_saturated_deg', 'GM_saturated', 'crossover_saturated_rad_s', ...
    'Map_loop_PM_deg', 'Map_loop_GM'});
writetable(R, fullfile(outDir, 'PID_tuning_result.csv'));
f = figure('Visible', 'off', 'Position', [100 100 900 600]);
bode(Lmap, C * G1, C * G0, {1, pi / Ts}); grid on;
legend({sprintf('Map loop, K_v = %g, lead', mp.Kmax.value), 'PID loop, tire gripping (G_1)', 'PID loop, tire saturated (G_0)'}, ...
    'Location', 'southwest');
title(sprintf('Open loop at T_s = %g ms: Map PM %.1f deg, PID PM %.1f / %.1f deg', Ts * 1e3, pmMap, pm1, pm0));
exportgraphics(f, fullfile(outDir, 'PID_tuning_loop_bode.png'), 'Resolution', 130);
close(f);

fprintf(['tune_pid: crossover %.1f rad/s (Map loop at K_max: PM %.1f deg, GM %.2f)\n' ...
    '  Kp = %.4g, Ki = %.4g 1/s, Kd = %.4g s, T_filt = %.4g s\n' ...
    '  PID loop: tire gripping PM %.1f deg GM %.2f; tire saturated PM %.1f deg GM %.2f\n' ...
    '  wrote data/pid.json and %s\n'], wc, pmMap, gmMap, C.Kp, C.Ki, C.Kd, C.Tf, pm1, gm1, pm0, gm0, outDir);
end
