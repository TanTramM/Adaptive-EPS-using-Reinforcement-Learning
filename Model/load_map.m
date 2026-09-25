%% load_map.m
% Load everything needed to build/simulate the static EPS map controller and
% its closed loop (Model_Map_s.mdl), in this order:
%   1. data/map.json  -> Ts_ctrl and the assist table, written by
%      Map/script/calibrate_map.m (Documents/DieuKhien_Map.txt). Base workspace
%      variables: Ts_ctrl [s], map_v_bp [m/s] (speed breakpoints), map_Ts_bp
%      [N.m] (|T_s| breakpoints), map_Ta_table [N.m] (rows = speed, columns = |T_s|);
%   2. load_plant.m   -> plant parameters (data/params.json), which itself
%      calls load_derived.m (F_zf, F_zr);
%   3. load_ref.m     -> Table 4 reference data (data/ref.json).
%
% The map has no tuning parameters: the table is the calibration itself.
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_map.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'map.json')));

assignin('base', 'Ts_ctrl',      raw.Ts_ctrl.value);
assignin('base', 'map_v_bp',     raw.v_breakpoints_kmh(:)'/3.6);
assignin('base', 'map_Ts_bp',    raw.Ts_breakpoints_Nm(:)');
assignin('base', 'map_Ta_table', raw.Ta_table_Nm);

fprintf('load_map: static assist map, %d speeds (%g-%g km/h) x %d |T_s| breakpoints, T_a,max = %s N.m, Ts_ctrl=%.3g s\n', ...
    numel(raw.v_breakpoints_kmh), raw.v_breakpoints_kmh(1), raw.v_breakpoints_kmh(end), numel(raw.Ts_breakpoints_Nm), ...
    mat2str(round(raw.Ta_table_Nm(:, end)', 2)), raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
