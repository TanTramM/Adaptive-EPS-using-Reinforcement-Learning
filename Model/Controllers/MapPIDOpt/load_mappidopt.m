%% load_mappidopt.m
% Base workspace variables of the MapPIDOpt controller (MapPIDOpt_Ts_ctrl, _v_bp, _Ts_bp, _table, _H_num, _H_den for the Map branch; MapPIDOpt_Kp, _Ki, _Kd, _Tf, _Kaw for the PID
% branch) and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator). MapPIDOpt = MapPID.mdl with the variable prefix MapPID_ renamed MapPIDOpt_, its nine parameters
% chosen by the common method (search seed 30000, choice on seeds 30001-30005; DieuKhien_MapPID.txt Part H). Design from data/mappidopt.json; before one exists, the design of
% MapPID (mappid.json), so MapPIDOpt then reproduces MapPID.
%
% Usage: run this SCRIPT before building or simulating MapPIDOpt / Model_MapPIDOpt.
%   >> run('<Model>/Controllers/MapPIDOpt/load_mappidopt.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/MapPIDOpt/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[MapPIDOpt_V, MapPIDOpt_d, MapPIDOpt_src] = mappidopt_design_variables(modelDir);
MapPIDOpt_fn = fieldnames(MapPIDOpt_V);
for MapPIDOpt_i = 1:numel(MapPIDOpt_fn)
    assignin('base', MapPIDOpt_fn{MapPIDOpt_i}, MapPIDOpt_V.(MapPIDOpt_fn{MapPIDOpt_i}));
end
fprintf('load_mappidopt (%s): Kmax %g | lead z %g p %g | lag z1 %g p1 %g | Kp %g Ki %g Kd %g Tf %g | Ts_ctrl %g ms\n', MapPIDOpt_src, MapPIDOpt_d.Kmax, MapPIDOpt_d.lead.z, ...
    MapPIDOpt_d.lead.p, MapPIDOpt_d.lag.z1, MapPIDOpt_d.lag.p1, MapPIDOpt_d.Kp, MapPIDOpt_d.Ki, MapPIDOpt_d.Kd, MapPIDOpt_d.Tf, 1000 * MapPIDOpt_d.Ts_ctrl);
clear MapPIDOpt_V MapPIDOpt_d MapPIDOpt_src MapPIDOpt_fn MapPIDOpt_i modelDir
