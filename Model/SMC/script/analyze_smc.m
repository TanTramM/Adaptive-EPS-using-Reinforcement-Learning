function A = analyze_smc(lambda, G, tau_f)
%ANALYZE_SMC Linear analysis of the first-order SMC (no integral) inside its boundary layer, in the PRSM loop. No simulation needed.
%
%   A = analyze_smc(lambda, G, tau_f)
%
%   Inside the boundary layer |s| < Phi the control law (build_smc.m) is linear, with G = k_sw/Phi [1/s]:
%       T_a = a1*T_s + a2*theta2_dot + a3*theta1_dot_hat - (J_col*G*lambda/K)*T_d,ref
%       a1 = -1 + J_col*G*lambda/K,  a2 = C_col - J_col*lambda - J_col*G,  a3 = J_col*(lambda + G)
%   (T_eq = -T_s + C_col*theta2_dot + J_col*lambda*(theta1_dot_hat - theta2_dot), u_sw = G*s, s = theta2_dot - theta1_dot_hat - (lambda/K)*e_T).
%   The loop seen by the controller (theta1 held) is: command -> motor lag Gm(s) = wm/(s + wm) -> steering column
%       J*theta2_ddot = K*(theta1 - theta2) + T_a - C*theta2_dot - k_r*theta2        (sliding column, no dry friction; Documents/Map_6_8/map.txt (13))
%   with outputs T_s = K*(theta1 - theta2) and theta2_dot, discretised with the zero-order hold at Ts = 1 ms. k_r is the road stiffness
%   (dry road) and 0 (very slippery road): the worst of the two is reported. Fields of A:
%       PM_deg, GM        smallest phase margin [deg] / gain margin [-] of the loop over the two k_r (negative PM = unstable or GM < 1)
%       stable            0/1 (0 = unstable or conditionally stable, GM < 1)
%       e_ss_pct          steady error at the worst point of the everyday region (v >= 30 km/h, 0.1 g <= a_y <= 0.3 g) [% of T_d,ref]:
%                         e_T,ss = K*T_r/(J_col*G*lambda) (steady state: theta2_dot = 0, s = -(lambda/K)*e_T inside the layer, so no dry
%                         friction and no integral), T_r and T_d,ref from the calibration pairs of data/map.json (T_r = T_s,cal + T_a,cal)
%       e_ss_pct_all      the same over all speeds (20-100 km/h)
%       noise_std_Ta      standard deviation of the applied T_a produced by the white sensor noise (T_s, theta2_dot, theta1 of
%                         data/sensors.json: std = sqrt(resolution^2 + resolution^2/12)), closed loop, dry road [N.m]
%       noise_std_cmd     the same for the controller command before the motor [N.m]
%       gain_T_s, gain_th2dot, gain_th1   open-loop gain of the three noise channels to the command [N.m per unit]

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
K = raw.cum1.K.value; J = raw.cum1.J_col.value; C = raw.cum1.C_col.value;
kr = raw.cum2.e_p0.value * raw.cum2.C_alpha_f.value / raw.cum2.n_st.value^2;
wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;
T = jsondecode(fileread(fullfile(modelDir, 'data', 'smc.json'))).Ts_ctrl.value;
sj = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json'))).signals;
sg = @(s) sqrt(s.resolution^2 + s.resolution^2 / 12);
sd = [sg(sj.T_s), sg(sj.theta2_dot), sg(sj.theta1)];

a1 = -1 + J * G * lambda / K;  a2 = C - J * lambda - J * G;  a3 = J * (lambda + G);

pm = inf; gm = inf; stable = true;
warning('off', 'Control:analysis:MarginUnstable');
for krr = [kr 0]
    A0 = [0 1 0; -(K + krr)/J, -C/J, 1/J; 0 0 -wm];  B0 = [0; 0; wm];
    Pd = c2d(ss(A0, B0, [-K 0 0; 0 1 0], 0), T, 'zoh');
    Lg = -(a1 * Pd(1) + a2 * Pd(2));
    cl = isstable(feedback(Lg, 1));
    [g, p] = margin(Lg);
    if ~cl || g < 1, p = -abs(p); stable = false; end   % unstable, or stable only thanks to a high gain (GM < 1: a gain reduction, e.g. saturation, destabilises it)
    pm = min(pm, p);  gm = min(gm, g);
end

% closed-loop noise (dry road), states [theta2; theta2_dot; motor; x_f]
A0 = [0 1 0; -(K + kr)/J, -C/J, 1/J; 0 0 -wm];  B0 = [0; 0; wm];
sys = c2d(ss(A0, B0, eye(3), 0), T, 'zoh');  Ad = sys.A;  Bd = sys.B;
Acl = zeros(4);  Acl(1:3, 1:3) = Ad + Bd * (a1 * [-K 0 0] + a2 * [0 1 0]);  Acl(1:3, 4) = -Bd * a3 / tau_f;  Acl(4, 4) = 1 - T / tau_f;
Bn = zeros(4, 3);  Bn(1:3, :) = [Bd * a1, Bd * a2, Bd * a3 / tau_f];  Bn(4, 3) = T / tau_f;
if max(abs(eig(Acl))) < 1
    Sx = dlyap(Acl, Bn * diag(sd.^2) * Bn');
    urow = [a1 * [-K 0 0] + a2 * [0 1 0], -a3 / tau_f];
    A.noise_std_Ta = sqrt(Sx(3, 3));
    A.noise_std_cmd = sqrt(urow * Sx * urow' + sd(1)^2 * a1^2 + sd(2)^2 * a2^2 + sd(3)^2 * (a3 / tau_f)^2);
else
    A.noise_std_Ta = NaN;  A.noise_std_cmd = NaN;
end

% steady error over the calibration pairs
mp = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
eAll = 0; eNorm = 0;
for j = 1:numel(mp.v_breakpoints_kmh)
    c = mp.calibration(j);
    sel = c.ay_g >= 0.1 - 1e-9 & c.ay_g <= 0.3 + 1e-9;
    Td = c.Ts_Nm(sel);  Tr = Td + c.Ta_Nm(sel);
    e = 100 * K * Tr ./ (J * G * lambda) ./ Td;
    eAll = max(eAll, max(e));
    if mp.v_breakpoints_kmh(j) >= 30, eNorm = max(eNorm, max(e)); end
end

A.lambda = lambda;  A.G = G;  A.tau_f = tau_f;
A.PM_deg = pm;  A.GM = gm;  A.stable = double(stable);
A.e_ss_pct = eNorm;  A.e_ss_pct_all = eAll;
A.gain_T_s = abs(a1);  A.gain_th2dot = abs(a2);  A.gain_th1 = abs(a3 / tau_f);
end
