function [V, d, srcText] = pidlag_design_variables(ctrl, modelDir)
%PIDLAG_DESIGN_VARIABLES Variables of the PIDOpt / PIDLag block for the design stored in data/<ctrl lower case>.json (used by load_pidopt.m, load_pidlag.m).
%   No design yet: all gains 0 (open loop), Tf = 5 ms, no lag.
J = jsondecode(fileread(fullfile(modelDir, 'data', [lower(ctrl) '.json'])));
d = struct('Ts_ctrl', J.Ts_ctrl, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
if isfield(J, 'design')
    q = J.design; d.Kp = q.Kp; d.Ki = q.Ki; d.Kd = q.Kd; d.Tf = q.Tf;
    if isfield(q, 'lag'), d.lag = q.lag; end
    srcText = ['design of ' lower(ctrl) '.json'];
else
    srcText = 'no design yet: all gains 0';
end
V = pidlag_variables(ctrl, d);
end
