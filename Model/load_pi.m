% load_pi.m
% Load everything needed to build/simulate the PI controller (Kd = 0) and its closed loop (Model_PI_s.mdl), in this order:
%   1. data/pi.json     -> Ts_ctrl and the gains Kp, Ki (Documents/PI/pi.txt); Kaw = 1/Ti = Ki/Kp (back-calculation anti-windup,
%                           tracking time constant = Ti). Written by PI/script/select_pi.m from the sweep of PI/script/run_pi_sweep.m.
%   2. load_plant.m      -> plant parameters (data/params.json), which itself calls load_derived.m (F_zf);
%   3. load_ref.m        -> reference data (data/ref.json): T_d,ref table of the Reference block inside the controller;
%   4. load_sensors.m    -> Sensors block variables (default: ideal sensors);
%   5. load_actuator.m   -> motor lag and assist limit T_a,max(v) of the Actuator block.
%
% The controller has no assist limit and no motor: both are in the Actuator block (Model/Actuator/).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_pi.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'pi.json')));

for nm = {'Ts_ctrl', 'Kp', 'Ki'}
    assignin('base', nm{1}, raw.(nm{1}).value);
end
tau_I = raw.Kp.value ./ raw.Ki.value;
assignin('base', 'tau_I', tau_I);
assignin('base', 'Kaw', 1 ./ tau_I);

fprintf('load_pi: PI (wc %.4g rad/s): Kp = %.4g, Ki = %.4g 1/s\n', ...
    raw.design.wc_design_rad_s, raw.Kp.value, raw.Ki.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
run(fullfile(scriptDir, 'load_actuator.m'));
