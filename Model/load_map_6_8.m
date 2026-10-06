%% load_map_6_8.m
% Load everything needed to build/simulate the conventional EPS assist
% controller (baseline, Documents/Map_6_8/map.txt) and its closed loop
% (Model_Map_6_8_s.mdl), in this order:
%   1. data/map_6_8.json  -> written by Map/script/calibrate_map.m. Base workspace
%      variables:
%        Ts_ctrl       [s]   ECU sample time of the assist loop
%        map_v_bp      [m/s] speed breakpoints
%        map_Ts_bp     [N.m] |T_s| breakpoints
%        map_Ta_table  [N.m] torque map, rows = speed, columns = |T_s|
%        map_Tamax     [N.m] saturation T_a,max at map_v_bp (read from data/ref.json, field Ta_max)
%        map_lead_num, map_lead_den   lead stage of the low-speed tier (Tustin, Ts_ctrl)
%        map_lead_hi_num, map_lead_hi_den   lead stage of the high-speed tier
%        map_blend_v [m/s], map_blend_w [-]   weight of the high-speed lead versus speed (0 up to 60 km/h, 1 from 65 km/h)
%   2. load_plant.m   -> plant parameters (data/params.json) and load_derived.m;
%   3. load_ref.m     -> reference table T_d,ref (data/ref.json, fine table).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_map_6_8.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'map_6_8.json')));

assignin('base', 'Ts_ctrl',      raw.Ts_ctrl.value);
assignin('base', 'map_v_bp',     raw.v_breakpoints_kmh(:)'/3.6);
assignin('base', 'map_Ts_bp',    raw.Ts_breakpoints_Nm(:)');
assignin('base', 'map_Ta_table', raw.Ta_table_Nm);
rawRef = jsondecode(fileread(fullfile(scriptDir, 'data', 'ref.json')));
assert(isfield(rawRef, 'Ta_max') && isequal(rawRef.Ta_max.v_kmh(:)', raw.v_breakpoints_kmh(:)'), ...
    'data/ref.json Ta_max missing or speeds differ from the map - run Ref/script/make_ta_max.m');
assignin('base', 'map_Tamax',    rawRef.Ta_max.Ta_max_Nm(:)');   % assist limit of Ref (ref.txt section 1.5)
assignin('base', 'map_lead_num', raw.lead.num(:)');
assignin('base', 'map_lead_den', raw.lead.den(:)');
assignin('base', 'map_lead_hi_num', raw.lead_hi.num(:)');   % lead stage of the high-speed tier (v >= raw.blend_kmh(2))
assignin('base', 'map_lead_hi_den', raw.lead_hi.den(:)');
assignin('base', 'map_blend_v', [0, raw.blend_kmh(:)', 400] / 3.6);   % speed [m/s]; weight 0 = low-speed lead, 1 = high-speed lead
assignin('base', 'map_blend_w', [0, 0, 1, 1]);

fprintf(['load_map_6_8: torque map %d speeds x %d |T_s| points, dead band %.2g N.m, T_a,max %.2f-%.2f N.m, ' ...
    'lead low speed (K_max %g: zero %g, pole %g rad/s) / high speed (K_max %g: zero %g, pole %g rad/s), Ts_ctrl = %.3g s\n'], ...
    numel(raw.v_breakpoints_kmh), numel(raw.Ts_breakpoints_Nm), raw.Ts0.value, min(rawRef.Ta_max.Ta_max_Nm), max(rawRef.Ta_max.Ta_max_Nm), ...
    raw.lead.K_max, raw.lead.zero_rad_s, raw.lead.pole_rad_s, raw.lead_hi.K_max, raw.lead_hi.zero_rad_s, raw.lead_hi.pole_rad_s, raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
run(fullfile(scriptDir, 'load_actuator.m'));
