%% load_actuator.m
% Base workspace variables of the Actuator block (Model/PRSM/Actuator/script/build_actuator.m): motor_wm [rad/s] = 2*pi*fm, the corner
% frequency of the first-order lag Gm(s) = wm/(s + wm) (data/actuator.json). The assist limit T_a,max(v) is NOT here any more: it belongs
% to the AssistLimit block (PRSM/AssistLimit/load_assistlimit.m).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/PRSM/Actuator/load_actuator.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/PRSM/Actuator/)
addpath(modelDir); setup_paths;
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json')));
assignin('base', 'motor_wm', 2 * pi * raw.fm.value);
assignin('base', 'act_gain_mult', 1);
assignin('base', 'ctrl_delay', 0);
fprintf('load_actuator: motor lag wm = %.4g rad/s (%g Hz), tau_m = %.3g ms; act_gain_mult = 1, ctrl_delay = 0 s\n', 2 * pi * raw.fm.value, raw.fm.value, 1000 / (2 * pi * raw.fm.value));
