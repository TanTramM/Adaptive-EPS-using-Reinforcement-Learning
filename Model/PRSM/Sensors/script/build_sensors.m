%% build_sensors.m
% Build the Sensors block of the closed loop as its own model Sensors.mdl, saved in Model/PRSM/Sensors/ (add_sensors.m in Sim/script draws it).
% One block for every controller: all the signals a sensor can measure go in, the measured values come out with the SAME name plus
% the suffix _meas; a controller wires the ones it reads and the rest end in Terminator blocks of the closed loop.
%
%   Sensors   In : T_s, theta1, theta2_dot, v, gamma, a_y   (TRUE values)
%             Out: T_s_meas, theta1_meas, theta2_dot_meas, v_meas, gamma_meas, a_y_meas
%
% Per signal: true -> + white noise -> Quantizer -> zero-order hold -> Switch (bypass when level 'none'), see add_sensors.m.
% Parameters (sensors_on, noise_var_*, noise_seed_*, sens_delta_*, sens_Tupd_*): run Model/load_sensors.m BEFORE building.
%
% Usage (run from this folder, Sensors/script/):
%   >> run('../../load_sensors.m')
%   >> build_sensors            % or build_sensors(true) to overwrite an existing Sensors.mdl (false: save as Sensors_1, ...)

function modelName = build_sensors(overwrite)
if nargin < 1, overwrite = false; end

scriptDir  = fileparts(mfilename('fullpath'));   % Sensors/script
sensorsDir = fileparts(scriptDir);               % Sensors/
modelDir   = fileparts(fileparts(sensorsDir));   % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(sensorsDir, 'Sensors', overwrite);
modelPath = fullfile(sensorsDir, [modelName '.mdl']);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);
add_sensors(modelName, {'T_s', 'theta1', 'theta2_dot', 'v', 'gamma', 'a_y'}, 50, 50);
save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);
end
