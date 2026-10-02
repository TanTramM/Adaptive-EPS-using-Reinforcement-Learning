%% load_sensors.m
% Put the Sensors subsystem variables (sensors_on, noise_var_*, noise_seed_*, sens_delta_*, sens_Tupd_*) in the base workspace.
% Default: level 'none' = ideal sensors (chain bypassed), so every closed-loop model runs exactly as without sensors unless a
% script asks for them. Define the base variable noise_level ('low' or 'high') and noise_run_seed BEFORE running this script to get
% the sensor chain by hand; test scripts instead pass the values per run with SimulationInput.setVariable (see run_test_cases.m).
% Levels and sources: data/sensors.json, Documents/Sim/ThucTeHoa.txt Mục 1.

lvl = 'none';
if evalin('base', 'exist(''noise_level'', ''var'')'), lvl = evalin('base', 'noise_level'); end
seed = [];
if evalin('base', 'exist(''noise_run_seed'', ''var'')'), seed = evalin('base', 'noise_run_seed'); end
if isempty(seed), V = sensor_noise_vars(lvl); else, V = sensor_noise_vars(lvl, seed); end
fn = fieldnames(V);
for i = 1:numel(fn)
    assignin('base', fn{i}, V.(fn{i}));
end
fprintf('load_sensors: sensor level = %s (sensors_on = %d; a_y step %.3g m/s^2 updated every %.3g s, T_s step %.3g N.m every %.3g s)\n', ...
    lvl, V.sensors_on, V.sens_delta_a_y, V.sens_Tupd_a_y, V.sens_delta_T_s, V.sens_Tupd_T_s);
