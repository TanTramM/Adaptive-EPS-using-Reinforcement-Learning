%% load_mapopt.m
% Base workspace variables of the MapOpt controller (MapOpt_Ts_ctrl, MapOpt_v_bp, MapOpt_Ts_bp, MapOpt_table, MapOpt_H_num/den) and the PRSM variables
% (Plant, Ref, Sensors, AssistLimit, Actuator). MapOpt = the Map structure (copy of Map.mdl with the variable prefix Map_ renamed MapOpt_) whose five parameters
% (slope limit K, lead z and p, lag z1 and p1) are chosen by simultaneous optimisation (DieuKhien_MapOpt.txt). The calibration points and the dead zone come from
% data/map.json (single source); data/mapopt.json holds Ts_ctrl and, once chosen, the design written by select_mapopt.m. Before a design exists the values
% are the design of the old Map (map.json), so MapOpt then reproduces Map.
%
% Usage: run this SCRIPT before building or simulating MapOpt / Model_MapOpt.
%   >> run('<Model>/Controllers/MapOpt/load_mapopt.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/MapOpt/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[MapOpt_V, MapOpt_d, MapOpt_src] = mapopt_design_variables(modelDir);
MapOpt_fn = fieldnames(MapOpt_V);
for MapOpt_i = 1:numel(MapOpt_fn)
    assignin('base', MapOpt_fn{MapOpt_i}, MapOpt_V.(MapOpt_fn{MapOpt_i}));
end
fprintf('load_mapopt (%s): Kmax %g | lead z %g p %g | lag z1 %g p1 %g | Ts_ctrl %g ms\n', MapOpt_src, MapOpt_d.Kmax, MapOpt_d.lead.z, MapOpt_d.lead.p, ...
    MapOpt_d.lag.z1, MapOpt_d.lag.p1, 1000 * MapOpt_d.Ts_ctrl);
clear MapOpt_V MapOpt_d MapOpt_src MapOpt_fn MapOpt_i modelDir
