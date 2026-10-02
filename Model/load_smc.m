%% load_smc.m
% Load everything needed to build/simulate the SMC controller and its
% closed loop (Model_SMC_s.mdl), in this order:
%   1. data/smc.json  -> SMC design values (Ts_ctrl, lambda, tau_f, k_sw, Phi),
%      used exactly as chosen (Documents/SMC/DieuKhien_SMC.txt);
%   2. load_plant.m   -> plant parameters (data/params.json), which itself
%      calls load_derived.m (F_zf). The SMC also uses K, J_col, C_col from
%      here in its equivalent control;
%   3. load_ref.m     -> reference data and the assist limit T_a,max(v) (data/ref.json);
%   4. load_sensors.m -> sensor model of the closed loop (data/sensors.json, default level none = ideal).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_smc.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'smc.json')));

fn = fieldnames(raw);
fn = fn(~startsWith(fn, 'x_'));   % skip the "_note" field (jsondecode names it x_note)
for i = 1:numel(fn)
    assignin('base', fn{i}, raw.(fn{i}).value);
end

fprintf('load_smc: first-order SMC with sat boundary layer: lambda=%.4g 1/s, tau_f=%.3g s, k_sw=%.4g, Phi=%.4g, Ts_ctrl=%.3g s\n', ...
    raw.lambda.value, raw.tau_f.value, raw.k_sw.value, raw.Phi.value, raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
