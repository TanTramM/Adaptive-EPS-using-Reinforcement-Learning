%% load_pid.m
% Load everything needed to build/simulate the PID controller and its
% closed loop (Model_PID_s.mdl), in this order:
%   1. data/pid.json  -> Ts_ctrl and the PID gains Kp, Ki, Kd, T_filt
%      (Documents/PID/DieuKhien_PID.txt);
%   2. load_plant.m   -> plant parameters (data/params.json), which itself
%      calls load_derived.m (F_zf);
%   3. load_ref.m     -> reference data (data/ref.json).
%
% PID gains: written by Model/PID/script/tune_pid.m (pidtune on the
% linearized steering-column loop used for the Map design, phase margin
% >= 45 deg at the crossover of the Map loop). They are used as they are:
% the discrete PIDF of pidtune (Forward Euler) is exactly the controller
% built by build_pid.m. Ziegler-Nichols is no longer used (it fails at 1 ms).
%
% Assist limit and anti-windup: the controller saturates T_a at +-T_a,max(v), a 1-D table of Ref (data/ref.json field Ta_max, Documents/Ref/ref.txt section 1.5),
% loaded by load_ref.m as Tamax_v_bp_ms [m/s] and Tamax_table [N.m]; the back-calculation gain of the anti-windup is Kaw = 1/tau_I = Ki/Kp (tracking time constant = tau_I).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_pid.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'pid.json')));

for nm = {'Ts_ctrl', 'Kp', 'Ki', 'Kd', 'T_filt'}
    assignin('base', nm{1}, raw.(nm{1}).value);
end
tau_I = raw.Kp.value / raw.Ki.value;
Kaw   = 1 / tau_I;
assignin('base', 'tau_I', tau_I);
assignin('base', 'Kaw', Kaw);

fprintf('load_pid: pidtune gains (crossover %.4g rad/s, PM %.3g deg): Kp=%.4g, Ki=%.4g 1/s (tau_I=%.4g s), Kd=%.4g s, T_filt=%.4g s, Ts_ctrl=%.3g s\n', ...
    raw.design.crossover_rad_s, raw.design.pm_tire_deg, raw.Kp.value, raw.Ki.value, tau_I, raw.Kd.value, raw.T_filt.value, raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
