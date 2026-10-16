function V = pidlag_variables(ctrl, d)
%PIDLAG_VARIABLES Base-workspace variables of the PIDOpt / PIDLag controller block from a design d (struct).
%
%   V = pidlag_variables('PIDLag', d)       ctrl: 'PIDOpt' (no lag) or 'PIDLag'; variable names are prefixed <ctrl>_
%   d.Ts_ctrl  controller sample time [s]      d.Kp, d.Ki [1/s], d.Kd [s], d.Tf [s]   PID (derivative of the measured T_s through a first-order filter Tf)
%   d.lag      OPTIONAL struct z1, p1 [rad/s]  lag stage (s/z1 + 1)/(s/p1 + 1), p1 <= z1, DC gain 1, Tustin at Ts_ctrl; absent or empty = no lag (H = 1)
%   V.<ctrl>_Ts_ctrl, _Kp, _Ki, _Kd, _Tf, _Kaw (= Ki/Kp, back-calculation on the command AFTER the lag; 0 when Ki = 0 or Kp = 0), _H_num, _H_den
Ts = d.Ts_ctrl;
V.([ctrl '_Ts_ctrl']) = Ts;
V.([ctrl '_Kp']) = d.Kp; V.([ctrl '_Ki']) = d.Ki; V.([ctrl '_Kd']) = d.Kd; V.([ctrl '_Tf']) = d.Tf;
if d.Ki > 0 && d.Kp > 0, V.([ctrl '_Kaw']) = d.Ki / d.Kp; else, V.([ctrl '_Kaw']) = 0; end
if isfield(d, 'lag') && ~isempty(d.lag) && isfinite(d.lag.z1) && isfinite(d.lag.p1)
    a = 2 / Ts;                                    % Tustin: s -> a (1 - z^-1)/(1 + z^-1)
    num = [a / d.lag.z1 + 1, 1 - a / d.lag.z1] / (a / d.lag.p1 + 1);
    den = [1, (1 - a / d.lag.p1) / (a / d.lag.p1 + 1)];
else
    num = 1; den = 1;
end
V.([ctrl '_H_num']) = num; V.([ctrl '_H_den']) = den;
end
