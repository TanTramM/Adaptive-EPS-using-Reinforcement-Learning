%% load_mapopt.m
% Base workspace variables of the MapOpt controller (MapOpt_Ts_ctrl, MapOpt_v_bp, MapOpt_Ts_bp, MapOpt_table, MapOpt_H_num/den) from data/mapopt.json
% (design written by select_mapopt.m; none yet = the Map design of map.json) and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator).
%
% Usage: run this SCRIPT before building or simulating MapOpt / Model_MapOpt.
%   >> run('<Model>/Controllers/MapOpt/load_mapopt.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[MapOpt_V, MapOpt_d, MapOpt_src] = mapopt_design_variables(modelDir);
MapOpt_fn = fieldnames(MapOpt_V);
for MapOpt_i = 1:numel(MapOpt_fn), assignin('base', MapOpt_fn{MapOpt_i}, MapOpt_V.(MapOpt_fn{MapOpt_i})); end
fprintf('load_mapopt (%s): Kmax %g, lead z %g p %g, lag %s | Ts_ctrl %g ms\n', MapOpt_src, MapOpt_d.Kmax, MapOpt_d.lead.z, MapOpt_d.lead.p, mat2str(isfield(MapOpt_d, 'lag')), 1000 * MapOpt_d.Ts_ctrl);
clear MapOpt_V MapOpt_d MapOpt_src MapOpt_fn MapOpt_i modelDir
