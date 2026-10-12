function m = pi_margins(Kp, Ki, Gd, Ts)
%PI_MARGINS Stability and margins of the discrete PI loop on a set of discretized plants.
%
%   m = pi_margins(Kp, Ki, {G1d, G0d}, Ts)
%   C(z) = Kp + Ki*Ts/(z - 1)   (Forward Euler integral, the same as the Discrete-Time Integrator in PI.mdl)
%   m.stable  1 if the closed loop is stable on every plant
%   m.PM, m.GM, m.Ms   per plant [PM deg: smallest over ALL gain crossovers (a second crossover after the resonance peak counts),
%                      GM: smallest gain factor (up or down) that reaches the -180 deg crossing, Ms = peak of the sensitivity 1/(1+L)]

C = tf([Kp, -(Kp - Ki * Ts)], [1 -1], Ts);
n = numel(Gd);
m = struct('stable', 1, 'PM', nan(1, n), 'GM', nan(1, n), 'Ms', nan(1, n));
for k = 1:n
    L = C * Gd{k};
    T = feedback(L, 1);
    st = isstable(T);
    m.stable = m.stable && st;
    if ~st, m.PM(k) = 0; m.GM(k) = 1; m.Ms(k) = Inf; continue; end
    a = allmargin(L);
    pm = abs(a.PhaseMargin); if isempty(pm), pm = Inf; end
    g = a.GainMargin;        if isempty(g), g = Inf; else, g = min(max(g, 1 ./ g)); end
    m.PM(k) = min(pm); m.GM(k) = g;
    m.Ms(k) = norm(feedback(1, L), Inf);
end
end

