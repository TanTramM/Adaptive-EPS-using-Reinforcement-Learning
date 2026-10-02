%% load_pidf_dz.m
% PIDF with the Map's torque dead zone (Model_PIDF_DZ_s.mdl): load_pidf.m, then dz_Ts = Ts0 of the Map (data/map.json), the torque
% below which T_a is zero, and dz_e = 0 (no error dead zone, see Documents/Sim/SoSanh_DieuChinh.txt).
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_pidf_dz.m')
scriptDir = fileparts(mfilename('fullpath'));   % Model/
run(fullfile(scriptDir, 'load_pidf.m'));
mpj = jsondecode(fileread(fullfile(scriptDir, 'data', 'map.json')));
assignin('base', 'dz_Ts', mpj.Ts0.value);
assignin('base', 'dz_e', 0);
fprintf('load_pidf_dz: torque dead zone dz_Ts = %.3g N.m (Map Ts0), error dead zone off\n', mpj.Ts0.value);
