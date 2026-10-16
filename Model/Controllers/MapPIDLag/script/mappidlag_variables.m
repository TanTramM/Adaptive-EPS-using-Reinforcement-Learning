function V = mappidlag_variables(Cal, d)
%MAPPIDLAG_VARIABLES Base-workspace variables of the MapPIDLag controller block from a design d (struct) and the calibration Cal (calibrate_map).
%
%   V = mappidlag_variables(Cal, d)
%   d.Ts_ctrl  controller sample time [s]           d.Ts0   dead zone edge [N.m]
%   d.Kmax     slope limit of the assist table       d.lag   struct z1, p1 [rad/s]: (s/z1 + 1)/(s/p1 + 1), p1 <= z1, applied to the SUM of the two branches
%   d.Kp, d.Ki [1/s], d.Kd [s], d.Tf [s]            PID branch (derivative of the measured T_s through a first-order filter Tf)
%   V.MapPIDLag_Ts_ctrl, V.MapPIDLag_v_bp [m/s], V.MapPIDLag_Ts_bp [N.m], V.MapPIDLag_table   Map branch (the table of map_variables, renamed; no lead-lag)
%   V.MapPIDLag_H_num, V.MapPIDLag_H_den   Tustin discretisation of the lag (first order, DC gain 1)
%   V.MapPIDLag_Kp, V.MapPIDLag_Ki, V.MapPIDLag_Kd, V.MapPIDLag_Tf, V.MapPIDLag_Kaw   PID branch; Kaw = Ki/(Kp + Kmax): back-calculation gain of the
%   TOTAL command taken AFTER the lag (DieuKhien_MapPIDLag.txt B2); Kaw = 0 when Ki = 0 or Kp + Kmax = 0.
%   The Map helper map_variables is reused for the table (it lives in Controllers/Map/script); its lead is set to 1 (z = p) and its transfer function is not used.
dm = struct('Ts_ctrl', d.Ts_ctrl, 'Ts0', d.Ts0, 'Kmax', d.Kmax, 'lead', struct('z', 100, 'p', 100));
M = map_variables(Cal, dm);
V.MapPIDLag_Ts_ctrl = M.Map_Ts_ctrl;
V.MapPIDLag_v_bp = M.Map_v_bp;
V.MapPIDLag_Ts_bp = M.Map_Ts_bp;
V.MapPIDLag_table = M.Map_table;
Hd = c2d(tf([1 / d.lag.z1 1], [1 / d.lag.p1 1]), d.Ts_ctrl, 'tustin');
[V.MapPIDLag_H_num, V.MapPIDLag_H_den] = tfdata(Hd, 'v');
V.MapPIDLag_Kp = d.Kp; V.MapPIDLag_Ki = d.Ki; V.MapPIDLag_Kd = d.Kd; V.MapPIDLag_Tf = d.Tf;
den = d.Kp + d.Kmax;
if d.Ki > 0 && den > 0, V.MapPIDLag_Kaw = d.Ki / den; else, V.MapPIDLag_Kaw = 0; end
end
