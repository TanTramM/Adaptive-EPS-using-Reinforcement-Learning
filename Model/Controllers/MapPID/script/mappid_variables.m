function V = mappid_variables(Cal, d)
%MAPPID_VARIABLES Base-workspace variables of the MapPID controller block from a design d (struct) and the calibration Cal (calibrate_map).
%
%   V = mappid_variables(Cal, d)
%   d.Ts_ctrl  controller sample time [s]           d.Ts0   dead zone edge [N.m]
%   d.Kmax     slope limit of the assist table       d.lead  struct z, p [rad/s]       d.lag  struct z1, p1 [rad/s] (optional, as in map_variables)
%   d.Kp, d.Ki [1/s], d.Kd [s], d.Tf [s]            PID branch (derivative of the measured T_s through a first-order filter Tf)
%   V.MapPID_Ts_ctrl, V.MapPID_v_bp [m/s], V.MapPID_Ts_bp [N.m], V.MapPID_table, V.MapPID_H_num/den   Map branch (same as map_variables, renamed)
%   V.MapPID_Kp, V.MapPID_Ki, V.MapPID_Kd, V.MapPID_Tf, V.MapPID_Kaw   PID branch; Kaw = 1/sqrt(Ti*Td) = sqrt(Ki/Kd).
%   Anti-windup still tracks the TOTAL-command saturation error. Kaw depends only on the PID branch and is zero when Ki or Kd is zero.
%   The Map helper map_variables is reused (it lives in Controllers/Map/script; reuse reported in the notes file).
M = map_variables(Cal, rmfield_safe(d));
fn = fieldnames(M);
for i = 1:numel(fn)
    V.(['MapPID_' fn{i}(5:end)]) = M.(fn{i});          % Map_xxx -> MapPID_xxx
end
V.MapPID_Kp = d.Kp; V.MapPID_Ki = d.Ki; V.MapPID_Kd = d.Kd; V.MapPID_Tf = d.Tf;
if d.Ki > 0 && d.Kd > 0, V.MapPID_Kaw = sqrt(d.Ki / d.Kd); else, V.MapPID_Kaw = 0; end
end

function d = rmfield_safe(d)
% map_variables reads only Ts_ctrl, Ts0, Kmax, lead, lag
keep = {'Ts_ctrl', 'Ts0', 'Kmax', 'lead', 'lag'};
f = fieldnames(d);
for i = 1:numel(f)
    if ~any(strcmp(f{i}, keep)), d = rmfield(d, f{i}); end
end
end
