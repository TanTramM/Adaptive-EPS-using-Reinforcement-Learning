function [V, d, srcText] = mapopt_design_variables(modelDir)
%MAPOPT_DESIGN_VARIABLES Variables of the MapOpt block for the design stored in data/mapopt.json (used by load_mapopt.m). The calibration points come from
%   data/map.json (data). No design yet: the Map design of map.json (so MapOpt equals Map: the check of test_mapopt).
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Jo = jsondecode(fileread(fullfile(modelDir, 'data', 'mapopt.json')));
dm = Jm.design;
d = struct('Ts_ctrl', Jo.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', dm.Kmax, 'lead', dm.lead);
if isfield(dm, 'lag'), d.lag = dm.lag; end
srcText = 'no design yet: Map design of map.json';
if isfield(Jo, 'design')
    q = Jo.design; d.Ts0 = q.Ts0; d.Kmax = q.Kmax; d.lead = q.lead;
    if isfield(q, 'lag'), d.lag = q.lag; elseif isfield(d, 'lag'), d = rmfield(d, 'lag'); end
    srcText = 'design of mapopt.json';
end
V = mapopt_variables(calibrate_map_cached(), d);
end
