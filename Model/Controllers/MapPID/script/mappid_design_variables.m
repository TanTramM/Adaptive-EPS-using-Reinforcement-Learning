function [V, d, srcText] = mappid_design_variables(modelDir)
%MAPPID_DESIGN_VARIABLES Variables of the MapPID block for the design currently stored (used by load_mappid.m; a function so that no temporary
%   leaks into the base workspace). The Map branch (calibration points, dead zone, default slope limit, lead, lag) comes from data/map.json;
%   data/mappid.json gives Ts_ctrl and, once chosen, the design (Kmax, lead, lag, Kp, Ki, Kd, Tf). No design: Map design of map.json, PID gains 0.
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
assert(isfield(Jm, 'design'), 'data/map.json has no design: MapPID needs the Map design');
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json')));
d = struct('Ts_ctrl', Jp.Ts_ctrl, 'Ts0', Jm.design.Ts0, 'Kmax', Jm.design.Kmax, 'lead', Jm.design.lead, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
if isfield(Jm.design, 'lag'), d.lag = Jm.design.lag; end
if isfield(Jp, 'design')
    q = Jp.design;
    d.Kmax = q.Kmax; d.lead = q.lead; d.Kp = q.Kp; d.Ki = q.Ki; d.Kd = q.Kd; d.Tf = q.Tf;
    if isfield(q, 'lag'), d.lag = q.lag; elseif isfield(d, 'lag'), d = rmfield(d, 'lag'); end
    srcText = 'design of mappid.json';
else
    srcText = 'no design yet: Map design of map.json, PID gains 0';
end
V = mappid_variables(calibrate_map_cached(), d);
end
