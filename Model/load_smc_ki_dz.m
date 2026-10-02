%% load_smc_ki_dz.m
% Integral SMC with a wider boundary layer and the Map's torque dead zone (Model_SMC_KI_DZ_s.mdl): values of data/smc_ki_dz.json
% (written by SMC_KI/script/tune_smc_ki_dz.m), plant, reference, sensors, and dz_Ts = Ts0 of the Map (data/map.json).
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_smc_ki_dz.m')
scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'smc_ki_dz.json')));
for nm = {'Ts_ctrl', 'lambda', 'tau_f', 'k_sw', 'k_I', 'Phi'}
    assignin('base', nm{1}, raw.(nm{1}).value);
end
mpj = jsondecode(fileread(fullfile(scriptDir, 'data', 'map.json')));
assignin('base', 'dz_Ts', mpj.Ts0.value);
fprintf('load_smc_ki_dz: lambda=%.4g, tau_f=%.3g, k_sw=%.4g, Phi=%.4g, k_I=%.4g, dz_Ts=%.3g N.m\n', raw.lambda.value, ...
    raw.tau_f.value, raw.k_sw.value, raw.Phi.value, raw.k_I.value, mpj.Ts0.value);
run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
