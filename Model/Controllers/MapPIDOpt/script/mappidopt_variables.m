function V = mappidopt_variables(Cal, d)
%MAPPIDOPT_VARIABLES Base-workspace variables of the MapPIDOpt block (a copy of MapPID.mdl with the prefix MapPID_ renamed MapPIDOpt_) from a design d (struct) and the
%   calibration Cal: the variables of mappid_variables (Controllers/MapPID/script, reused) renamed. d fields as in mappid_variables (Ts_ctrl, Ts0, Kmax, lead, lag, Kp, Ki, Kd, Tf);
%   Kaw = Ki/(Kp + Kmax). Lead p = z and lag p1 = z1 give a compensator equal to 1; Kmax = 0 switches the Map branch off.
M = mappid_variables(Cal, d);
fn = fieldnames(M);
for i = 1:numel(fn)
    V.(['MapPIDOpt_' fn{i}(8:end)]) = M.(fn{i});          % MapPID_xxx -> MapPIDOpt_xxx
end
end
