%% load_mappid.m
% Base workspace variables of the MapPID controller (MapPID_Ts_ctrl, MapPID_v_bp, MapPID_Ts_bp, MapPID_table, MapPID_H_num/den for the Map branch;
% MapPID_Kp, MapPID_Ki, MapPID_Kd, MapPID_Tf, MapPID_Kaw for the PID branch) and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator).
% The Map branch reads the calibration points and the Map design (slope limit, lead, lag, dead zone) from data/map.json (single source, no copy);
% data/mappid.json holds Ts_ctrl and, once chosen, the design (Kmax, lead, lag, Kp, Ki, Kd, Tf) written by select_mappid.m. Before a design exists
% the PID gains are 0 and the Map design is the one of map.json, so MapPID behaves exactly like Map.
%
% Usage: run this SCRIPT before building or simulating MapPID / Model_MapPID.
%   >> run('<Model>/Controllers/MapPID/load_mappid.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/MapPID/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[MapPID_V, MapPID_d, MapPID_src] = mappid_design_variables(modelDir);
MapPID_fn = fieldnames(MapPID_V);
for MapPID_i = 1:numel(MapPID_fn)
    assignin('base', MapPID_fn{MapPID_i}, MapPID_V.(MapPID_fn{MapPID_i}));
end
if isfield(MapPID_d, 'lag') && ~isempty(MapPID_d.lag), MapPID_lag = sprintf('lag z1 %g p1 %g', MapPID_d.lag.z1, MapPID_d.lag.p1); else, MapPID_lag = 'no lag'; end
fprintf('load_mappid (%s): Kmax %g, lead z %g p %g, %s | Kp %g Ki %g Kd %g Tf %g Kaw %g | Ts_ctrl %g ms\n', MapPID_src, MapPID_d.Kmax, MapPID_d.lead.z, ...
    MapPID_d.lead.p, MapPID_lag, MapPID_d.Kp, MapPID_d.Ki, MapPID_d.Kd, MapPID_d.Tf, MapPID_V.MapPID_Kaw, 1000 * MapPID_d.Ts_ctrl);
clear MapPID_V MapPID_d MapPID_src MapPID_fn MapPID_i MapPID_lag modelDir
