function vdb_body_config(blk, P, v0)
%VDB_BODY_CONFIG Common configuration of the VDB body 'Vehicle Body 3DOF Single Track' used by every Plant_VDB test (night plan N1, item R9).
%   vdb_body_config(blk, P, v0)
%   P : struct with fields m, a (= l_f), b (= l_r), Iz;  v0 : initial longitudinal speed, m/s.
%   Velocity mode (the speed is an input), no aerodynamic force (Cd = Cl = 0), no wind, no mu mode, no body lateral compliance (sigmaMode off,
%   Cy = 0), external force and moment on (the tire forces enter through FExt and MExt, signs as found in check_vdb_signs, R8).
    set_param(blk, 'trackMode', 'Single (bicycle)');
    set_param(blk, 'inputMode', 'External longitudinal velocity');
    set_param(blk, 'frontSteerMode', 'on'); set_param(blk, 'rearSteerMode', 'off');
    set_param(blk, 'windMode', 'off'); set_param(blk, 'muMode', 'off'); set_param(blk, 'sigmaMode', 'off');
    set_param(blk, 'extFMode', 'on'); set_param(blk, 'extMMode', 'on');
    vals = {'m', P.m; 'a', P.a; 'b', P.b; 'Izz', P.Iz; 'Cy_f', 0; 'Cy_r', 0; 'Cd', 0; 'Cl', 0; ...
            'xdot_o', v0; 'ydot_o', 0; 'r_o', 0; 'psi_o', 0; 'X_o', 0; 'Y_o', 0};
    for i = 1:size(vals, 1), set_param(blk, vals{i, 1}, num2str(vals{i, 2}, 12)); end
    % Aerodynamic side force Cs(beta_w), yaw moment Cym(beta_w) and pitch moment Cpm are NOT switched off by Cd = Cl = 0: their default tables are non-zero and
    % add a destabilising yaw moment that grows with the body slip (found 2026-11-06 in the SLIP stop at 69.4 s, plan 10.9). Zero tables of the same length as beta_w.
    nBeta = numel(eval(get_param(blk, 'beta_w')));
    set_param(blk, 'Cs', mat2str(zeros(1, nBeta)), 'Cym', mat2str(zeros(1, nBeta)), 'Cpm', '0');
end
