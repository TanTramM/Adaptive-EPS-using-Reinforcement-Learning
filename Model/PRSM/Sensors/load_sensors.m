%% load_sensors.m
% Put the Sensors subsystem variables (sensors_on, noise_var_*, noise_seed_*, sens_delta_*, sens_Tupd_*) in the base workspace.
% Default: ideal sensors (chain bypassed), so every closed-loop model runs exactly as without sensors unless a script asks for them.
% Define the base variable noise_run_seed (a number, e.g. 99999) BEFORE running this script to get the sensor chain with noise by hand;
% test scripts instead pass the values per run with SimulationInput.setVariable (see run_test_cases.m).
% Sources: data/sensors.json, Documents/Notes/PRSM/ThucTeHoa.txt Mục 1.

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/PRSM/Sensors/)
addpath(modelDir); setup_paths;
seed = [];
if evalin('base', 'exist(''noise_run_seed'', ''var'')'), seed = evalin('base', 'noise_run_seed'); end
V = sensor_noise_vars(seed);
fn = fieldnames(V);
for i = 1:numel(fn)
    assignin('base', fn{i}, V.(fn{i}));
end
if isempty(seed), modeStr = 'ideal'; else, modeStr = sprintf('noise seed %05d', seed); end
fprintf('load_sensors: %s (sensors_on = %d; a_y step %.3g m/s^2 updated every %.3g s, T_s step %.3g N.m every %.3g s)\n', ...
    modeStr, V.sensors_on, V.sens_delta_a_y, V.sens_Tupd_a_y, V.sens_delta_T_s, V.sens_Tupd_T_s);
