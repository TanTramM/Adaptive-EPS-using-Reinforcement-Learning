function G = map_plant_lin(P, v, ay, mu)
%MAP_PLANT_LIN Linearized Plant from the assist T_a to the sensor torque T_s at one operating point (v [m/s], a_y [m/s^2], friction mu).
%
%   G = map_plant_lin(P, v, ay, mu)       state-space model, input T_a, output T_s, states [theta2; theta2_dot; beta; gamma]
%
%   Operating point = steady cornering (map_steady_state.m). Linearization by central differences of the Plant equations:
%     J_col*theta2_ddot = T_a - T_r + K*(theta1 - theta2) - C_col*theta2_dot       (Cum1 Eq.(2),(3); theta1 held: driver holds the angle)
%     beta_dot  = (F_yf + F_yr)/(m*v) - gamma ,   gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz      (Cum3 Eq.(4),(5))
%   with F_yf, F_yr, T_r of the Magic Formula tires (Cum2). The Coulomb friction T_f*tanh(c*theta2_dot) is NOT linearized (its slope at rest is
%   enormous and only adds damping once the column moves): the linear model has viscous damping C_col only, which is the conservative case.
%   T_s = K*(theta1 - theta2), so the DC gain of G is about -1 (more assist, less T_s). The loop gain uses -G.
S = map_steady_state(P, v, ay, mu);
x0 = [S.theta2; 0; S.beta; S.gamma];
f = @(x, Ta) dyn(P, x, Ta, v, mu);
A = zeros(4);
for j = 1:4
    h = 1e-6 * max(1, abs(x0(j)));
    dx = zeros(4, 1); dx(j) = h;
    A(:, j) = (f(x0 + dx, 0) - f(x0 - dx, 0)) / (2 * h);
end
B = [0; 1 / P.J_col; 0; 0];
C = [-P.K, 0, 0, 0];
G = ss(A, B, C, 0);
end

function xd = dyn(P, x, Ta, v, mu)
    th2 = x(1); w = x(2); beta = x(3); gamma = x(4);
    delta_f = th2 / P.n_st;
    alpha_f = delta_f - beta - P.l_f * gamma / v;
    alpha_r = -beta + P.l_r * gamma / v;
    Fyf = mf(P, alpha_f, mu * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, mu * P.F_zr, P.C_r);
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3 * mu * P.F_zf));
    Tr = e_p / P.n_st * Fyf;
    theta1 = 0;   % T_s = K*(theta1 - theta2); only increments matter, so theta1 is a constant that does not change A
    Ts = P.K * (theta1 - th2);
    xd = [w; (Ta - Tr + Ts - P.C_col * w) / P.J_col; (Fyf + Fyr) / (P.m * v) - gamma; (P.l_f * Fyf - P.l_r * Fyr) / P.Iz];
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

