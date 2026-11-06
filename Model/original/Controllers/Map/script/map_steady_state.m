function S = map_steady_state(P, v, ay, mu)
%MAP_STEADY_STATE Steady cornering of the vehicle at speed v [m/s], lateral acceleration ay [m/s^2] (> 0) and friction mu.
%
%   S = map_steady_state(P, v, ay, mu)       P = map_params()
%
%   Independent of the Simulink Plant. Steady state: beta_dot = gamma_dot = 0 and a_y given, with the Magic Formula tires of Cluster 2:
%     (F_yf + F_yr)/(m v) = gamma,   l_f F_yf = l_r F_yr,   (F_yf + F_yr)/m = a_y
%   The last two equations give the axle forces directly from a_y (statics), and the first gives gamma = a_y/v, so the unknowns that remain
%   are the two tire slip angles. Each is found by inverting the Magic Formula of its axle (monotonic below the force peak):
%     F_yf = m a_y l_r/L,  F_yr = m a_y l_f/L,  alpha_f, alpha_r from F = MF(alpha)
%     alpha_f = delta_f - beta - l_f gamma/v,  alpha_r = -beta + l_r gamma/v   ->   beta, delta_f
%   The aligning (resisting) torque at the steering column is T_r = e_p/n_st * F_yf with the pneumatic trail
%     e_p = e_p0 - t_0 + max(0, t_0 - sgn(alpha_f) t_0 C_alpha_f tan(alpha_f)/(3 mu F_zf)).
%   Returns S.beta, S.gamma, S.delta_f [rad], S.alpha_f, S.alpha_r [rad], S.theta2 = n_st*delta_f [rad], S.Fyf, S.Fyr [N], S.T_r [N.m].
assert(ay > 0 && v > 0 && mu > 0, 'map_steady_state needs v, ay, mu > 0');
L = P.l_f + P.l_r;
Fyf = P.m * ay * P.l_r / L;
Fyr = P.m * ay * P.l_f / L;
gamma = ay / v;
alpha_f = invertMF(Fyf, mu * P.F_zf, P.C_alpha_f, P);
alpha_r = invertMF(Fyr, mu * P.F_zr, P.C_r, P);
beta    = P.l_r * gamma / v - alpha_r;
delta_f = alpha_f + beta + P.l_f * gamma / v;
e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3 * mu * P.F_zf));
Tr = e_p / P.n_st * Fyf;
S = struct('beta', beta, 'gamma', gamma, 'delta_f', delta_f, 'alpha_f', alpha_f, 'alpha_r', alpha_r, 'theta2', P.n_st * delta_f, ...
    'Fyf', Fyf, 'Fyr', Fyr, 'T_r', Tr);
end

function alpha = invertMF(F, D, Calpha, P)
% Slip angle alpha > 0 with MF(alpha) = F, on the rising branch (from 0 to the force peak).
    mf = @(a) D * sin(P.C * atan(Calpha / (P.C * D) * a - P.E * (Calpha / (P.C * D) * a - atan(Calpha / (P.C * D) * a))));
    [aPk, negFpk] = fminbnd(@(a) -mf(a), 0, 0.6);
    assert(F < -negFpk, 'axle force %.1f N exceeds the tire force peak %.1f N', F, -negFpk);
    alpha = fzero(@(a) mf(a) - F, [0, aPk]);
end
