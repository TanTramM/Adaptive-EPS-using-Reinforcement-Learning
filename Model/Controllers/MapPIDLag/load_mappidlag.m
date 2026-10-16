%% load_mappidlag.m
% Base workspace variables of the MapPIDLag controller (MapPIDLag_Ts_ctrl, MapPIDLag_v_bp, MapPIDLag_Ts_bp, MapPIDLag_table for the Map branch;
% MapPIDLag_Kp, MapPIDLag_Ki, MapPIDLag_Kd, MapPIDLag_Tf, MapPIDLag_Kaw for the PID branch; MapPIDLag_H_num/den for the lag after the sum)
% and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator).
% The Map branch reads the calibration points and the dead zone from data/map.json (single source, no copy); data/mappidlag.json holds Ts_ctrl
% and, once chosen, the designs written by select_mappidlag.m: field design (MapPIDLag) and field pidlag.design (the PID + lag reference, K = 0).
% Before a design exists the PID gains are 0 and the table is the Map slope limit of map.json with no lag, so the block only reproduces the
% bare Map table (no lead-lag).
%
% Variant: set the base variable MapPIDLag_variant = 'PIDLag' BEFORE running this script to load the PID + lag design (K = 0) instead of the MapPIDLag
% design (the default). The model is the same; only the variable values differ.
%
% Usage: run this SCRIPT before building or simulating MapPIDLag / Model_MapPIDLag.
%   >> run('<Model>/Controllers/MapPIDLag/load_mappidlag.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/MapPIDLag/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

if ~exist('MapPIDLag_variant', 'var') || isempty(MapPIDLag_variant), MapPIDLag_variant = 'MapPIDLag'; end %#ok<NODEF>
[MapPIDLag_V, MapPIDLag_d, MapPIDLag_src] = mappidlag_design_variables(modelDir, MapPIDLag_variant);
MapPIDLag_fn = fieldnames(MapPIDLag_V);
for MapPIDLag_i = 1:numel(MapPIDLag_fn)
    assignin('base', MapPIDLag_fn{MapPIDLag_i}, MapPIDLag_V.(MapPIDLag_fn{MapPIDLag_i}));
end
fprintf('load_mappidlag (%s: %s): Kmax %g | lag z1 %g p1 %g | Kp %g Ki %g Kd %g Tf %g Kaw %g | Ts_ctrl %g ms\n', MapPIDLag_variant, MapPIDLag_src, ...
    MapPIDLag_d.Kmax, MapPIDLag_d.lag.z1, MapPIDLag_d.lag.p1, MapPIDLag_d.Kp, MapPIDLag_d.Ki, MapPIDLag_d.Kd, MapPIDLag_d.Tf, MapPIDLag_V.MapPIDLag_Kaw, ...
    1000 * MapPIDLag_d.Ts_ctrl);
clear MapPIDLag_V MapPIDLag_d MapPIDLag_src MapPIDLag_fn MapPIDLag_i modelDir
