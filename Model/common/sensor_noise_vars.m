function V = sensor_noise_vars(runSeed)
%SENSOR_NOISE_VARS Variables of the Sensors subsystem for ideal sensors or for one noise seed.
%
%   V = sensor_noise_vars()          ideal sensors (also runSeed = [])
%   V = sensor_noise_vars(99999)     quantizer + update period + white noise generated from run seed 99999
%
%   Returns a struct whose fields are the base-workspace variables read by the Sensors subsystem (add_sensors.m):
%     sensors_on          0 = ideal sensor (chain bypassed, measured = true), 1 = quantizer + hold + noise chain
%     noise_var_<signal>  variance of the white noise added before the quantizer
%     noise_seed_<signal> seed of that noise = 10*runSeed + index
%     sens_delta_<signal> quantizer step (resolution of the sensor)
%     sens_Tupd_<signal>  update period of the signal seen by the ECU (zero-order hold)
%   Noise std = sigma_noise of the signal if given, else one resolution step (data/sensors.json, Documents/Notes/PRSM/ThucTeHoa.txt).
%   Seed ranges: Map 0-9999, PI 10000-19999, SMC 20000-29999; the scoring seed of the standard test cases is 99999 for every controller.
%   Used by load_sensors.m (defaults) and by run_test_cases.m / tk_run.m (one value set per run, passed with
%   Simulink.SimulationInput.setVariable, so every controller sees the same noise for the same seed).

modelDir = fileparts(fileparts(mfilename('fullpath')));   % Model/
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
if nargin < 1, runSeed = []; end
noisy = ~isempty(runSeed);
if noisy, assert(isscalar(runSeed) && runSeed >= 0 && runSeed == fix(runSeed) && runSeed <= 99999, 'run seed must be an integer in 0..99999'); end

V = struct();
V.sensors_on = double(noisy);
names = fieldnames(raw.signals);
for i = 1:numel(names)
    s = raw.signals.(names{i});
    sigma = 0;
    if noisy
        if isfield(s, 'sigma_noise'), sigma = s.sigma_noise; else, sigma = s.resolution; end
    end
    seedUsed = 0; if noisy, seedUsed = runSeed; end
    V.(['noise_var_' names{i}])  = sigma^2;
    V.(['noise_seed_' names{i}]) = 10 * seedUsed + s.index;
    V.(['sens_delta_' names{i}]) = s.resolution;
    V.(['sens_Tupd_' names{i}])  = s.update_period;
end
end
