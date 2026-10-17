function [V, d, srcText] = mappidopt_design_variables(modelDir)
%MAPPIDOPT_DESIGN_VARIABLES Variables of the MapPIDOpt block for the design currently stored (used by load_mappidopt.m; a function so that no temporary leaks into the base
%   workspace). Dead zone and calibration points come from data/map.json; data/mappidopt.json gives Ts_ctrl and, once chosen, the design. No design yet: the design of
%   MapPID (data/mappid.json), so MapPIDOpt then reproduces MapPID.
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Jo = jsondecode(fileread(fullfile(modelDir, 'data', 'mappidopt.json')));
Jx = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json')));
q = Jx.design; srcText = 'no design yet: design of MapPID (mappid.json)';
if isfield(Jo, 'design'), q = Jo.design; srcText = 'design of mappidopt.json'; end
d = struct('Ts_ctrl', Jo.Ts_ctrl, 'Ts0', Jm.design.Ts0, 'Kmax', q.Kmax, 'lead', q.lead, 'lag', q.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
V = mappidopt_variables(calibrate_map_cached(), d);
end
