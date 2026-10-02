function V = sensor_noise_vars(level, runSeed)
%SENSOR_NOISE_VARS Variables of the Sensors subsystem for one sensor level and one noise seed.
%
%   V = sensor_noise_vars('none' | 'low' | 'high', runSeed)
%
%   Returns a struct whose fields are the base-workspace variables read by the Sensors subsystem (add_sensors.m):
%     sensors_on          0 = ideal sensor (chain bypassed, measured = true), 1 = quantizer + hold + noise chain
%     noise_var_<signal>  variance of the white noise added before the quantizer
%     noise_seed_<signal> seed of that noise = 10*runSeed + index
%     sens_delta_<signal> quantizer step (resolution of the sensor)
%     sens_Tupd_<signal>  update period of the signal seen by the ECU (zero-order hold)
%   Levels (data/sensors.json, Documents/Sim/ThucTeHoa.txt Mục 1): none = ideal; low = quantizer + update period, no noise;
%   high = low + white noise, std = sigma_high if given, else one resolution step.
%   Used by load_sensors.m (defaults) and by run_test_cases.m (one value set per run, passed with
%   Simulink.SimulationInput.setVariable, so every controller sees the same noise for the same seed).

modelDir = fileparts(mfilename('fullpath'));
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
if nargin < 1, level = 'none'; end
if nargin < 2, runSeed = raw.seeds.default_run_seed; end
assert(any(strcmp(level, {'none', 'low', 'high'})), 'sensor level must be none, low or high, got %s', level);

V = struct();
V.sensors_on = double(~strcmp(level, 'none'));
names = fieldnames(raw.signals);
for i = 1:numel(names)
    s = raw.signals.(names{i});
    sigma = 0;
    if strcmp(level, 'high')
        if isfield(s, 'sigma_high'), sigma = s.sigma_high; else, sigma = s.resolution; end
    end
    V.(['noise_var_' names{i}])  = sigma^2;
    V.(['noise_seed_' names{i}]) = 10 * runSeed + s.index;
    V.(['sens_delta_' names{i}]) = s.resolution;
    V.(['sens_Tupd_' names{i}])  = s.update_period;
end
end
