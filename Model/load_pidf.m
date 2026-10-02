%% load_pidf.m
% Load everything needed to build/simulate the PIDF controller (PID with a stronger derivative filter) and its
% closed loop (Model_PIDF_s.mdl), in this order:
%   1. data/pidf.json  -> Ts_ctrl and the PID gains Kp, Ki, Kd, T_filt
%      (Documents/Sim/SoSanh.txt);
%   2. load_plant.m   -> plant parameters (data/params.json), which itself
%      calls load_derived.m (F_zf);
%   3. load_ref.m     -> reference data (data/ref.json).
%
% PIDF gains: written by Model/PID/script/tune_pidf.m (same crossover and phase margin 45 deg as the Map, derivative filter
% chosen so that the noise gain does not exceed the Map's). The controller structure is the one of build_pid.m, so the PID block
% (PID/PID_s.mdl) is reused: Model_PIDF_s.mdl is Model_PID_s.mdl saved under another name (PID/script/build_model_pidf.m).
%
% Assist limit and anti-windup: the controller saturates T_a at +-T_a,max(v), a 1-D table of Ref (data/ref.json field Ta_max, Documents/Ref/ref.txt section 1.5),
% loaded by load_ref.m as Tamax_v_bp_ms [m/s] and Tamax_table [N.m]; the back-calculation gain of the anti-windup is Kaw = 1/tau_I = Ki/Kp (tracking time constant = tau_I).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_pidf.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'pidf.json')));

for nm = {'Ts_ctrl', 'Kp', 'Ki', 'Kd', 'T_filt'}
    assignin('base', nm{1}, raw.(nm{1}).value);
end
tau_I = raw.Kp.value / raw.Ki.value;
Kaw   = 1 / tau_I;
assignin('base', 'tau_I', tau_I);
assignin('base', 'Kaw', Kaw);

fprintf('load_pidf: PIDF gains (crossover %.4g rad/s, PM %.3g deg): Kp=%.4g, Ki=%.4g 1/s (tau_I=%.4g s), Kd=%.4g s, T_filt=%.4g s, Ts_ctrl=%.3g s\n', ...
    raw.design.crossover_rad_s, raw.design.pm_tire_deg, raw.Kp.value, raw.Ki.value, tau_I, raw.Kd.value, raw.T_filt.value, raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
