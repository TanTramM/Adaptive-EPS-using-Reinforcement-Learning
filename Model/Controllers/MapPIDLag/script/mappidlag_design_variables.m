function [V, d, srcText] = mappidlag_design_variables(modelDir, variant)
%MAPPIDLAG_DESIGN_VARIABLES Variables of the MapPIDLag block for the design currently stored (used by load_mappidlag.m; a function so that no
%   temporary leaks into the base workspace). The dead zone and the calibration points come from data/map.json; data/mappidlag.json gives Ts_ctrl and,
%   once chosen, the design (field design) and the PID + lag reference (field pidlag.design). variant: 'MapPIDLag' (default) or 'PIDLag' (K = 0).
%   No design yet: Kmax of map.json, PID gains 0, a lag that is the identity (z1 = p1).
if nargin < 2 || isempty(variant), variant = 'MapPIDLag'; end
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
assert(isfield(Jm, 'design'), 'data/map.json has no design: MapPIDLag needs the dead zone and the calibration');
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'mappidlag.json')));
d = struct('Ts_ctrl', Jp.Ts_ctrl, 'Ts0', Jm.design.Ts0, 'Kmax', Jm.design.Kmax, 'lag', struct('z1', 100, 'p1', 100), 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
q = [];
if strcmp(variant, 'MapPIDLag') && isfield(Jp, 'design'), q = Jp.design; end
if strcmp(variant, 'PIDLag') && isfield(Jp, 'pidlag') && isfield(Jp.pidlag, 'design'), q = Jp.pidlag.design; end
if ~isempty(q)
    d.Kmax = q.Kmax; d.lag = q.lag; d.Kp = q.Kp; d.Ki = q.Ki; d.Kd = q.Kd; d.Tf = q.Tf;
    srcText = ['design of mappidlag.json (' variant ')'];
else
    srcText = 'no design yet: Kmax of map.json, PID gains 0, no lag';
end
V = mappidlag_variables(calibrate_map_cached(), d);
end
