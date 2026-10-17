function [V, d, srcText] = mapopt_design_variables(modelDir)
%MAPOPT_DESIGN_VARIABLES Variables of the MapOpt block for the design currently stored (used by load_mapopt.m; a function so that no temporary leaks into the base
%   workspace). Calibration points and dead zone come from data/map.json; data/mapopt.json gives Ts_ctrl and, once chosen, the design (Kmax, lead, lag).
%   No design yet: the design of the old Map (map.json).
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
assert(isfield(Jm, 'design'), 'data/map.json has no design: MapOpt needs the calibration and the dead zone');
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'mapopt.json')));
q = Jm.design; srcText = 'no design yet: design of the old Map (map.json)';
if isfield(Jp, 'design'), q = Jp.design; srcText = 'design of mapopt.json'; end
d = struct('Ts_ctrl', Jp.Ts_ctrl, 'Ts0', Jm.design.Ts0, 'Kmax', q.Kmax, 'lead', q.lead, 'lag', q.lag);
V = mapopt_variables(calibrate_map_cached(), d);
end
