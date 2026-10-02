%% load_map.m
% Load everything needed to build/simulate the conventional EPS assist
% controller (baseline, Documents/Map/map.txt) and its closed loop
% (Model_Map_s.mdl), in this order:
%   1. data/map.json  -> written by Map/script/calibrate_map.m. Base workspace
%      variables:
%        Ts_ctrl       [s]   ECU sample time of the assist loop
%        map_v_bp      [m/s] speed breakpoints
%        map_Ts_bp     [N.m] |T_s| breakpoints
%        map_Ta_table  [N.m] torque map, rows = speed, columns = |T_s|
%        map_Tamax     [N.m] saturation T_a,max at map_v_bp (read from data/ref.json, field Ta_max)
%        map_lead_num, map_lead_den   the discrete lead stage (Tustin, Ts_ctrl)
%   2. load_plant.m   -> plant parameters (data/params.json) and load_derived.m;
%   3. load_ref.m     -> reference table T_d,ref (data/ref.json, fine table).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_map.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'map.json')));

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

fprintf(['load_map: torque map %d speeds x %d |T_s| points, dead band %.2g N.m, max slope %g, ' ...
    'T_a,max %.2f-%.2f N.m, %d lead stage (zero %g, pole %g rad/s), Ts_ctrl = %.3g s\n'], ...
    numel(raw.v_breakpoints_kmh), numel(raw.Ts_breakpoints_Nm), raw.Ts0.value, raw.Kmax.value, ...
    min(rawRef.Ta_max.Ta_max_Nm), max(rawRef.Ta_max.Ta_max_Nm), raw.lead.stages, raw.lead.zero_rad_s, raw.lead.pole_rad_s, raw.Ts_ctrl.value);

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
