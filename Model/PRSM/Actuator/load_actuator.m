%% load_actuator.m
% Base workspace variables of the Actuator block (Model/Actuator/script/build_actuator.m): motor_wm [rad/s] = 2*pi*fm, the corner
% frequency of the first-order lag Gm(s) = wm/(s + wm) (data/actuator.json), and the assist limit T_a,max(v) of the Ref
% (Tamax_v_bp_ms, Tamax_table, data/ref.json field Ta_max, through load_ref.m).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_actuator.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/PRSM/Actuator/)
addpath(modelDir); setup_paths;
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json')));
assignin('base', 'motor_wm', 2 * pi * raw.fm.value);
fprintf('load_actuator: motor lag wm = %.4g rad/s (%g Hz), tau_m = %.3g ms\n', 2 * pi * raw.fm.value, raw.fm.value, 1000 / (2 * pi * raw.fm.value));
load_ref;
