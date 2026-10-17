function x = mapopt_u2x(u)
%MAPOPT_U2X Map the normalized optimisation variables u in [0,1]^5 to the five MapOpt design variables x = [K, z, p/z, z1, p1/z1] of mapopt_eval.
%   Bounds (DieuKhien_MapOpt.txt B1): K 0.1-16 (log; upper bound kept 16 by the user), lead z 5-500 rad/s (log), p/z from 1 to min(300, 3142/z) (log; 1 = no lead;
%   p <= pi/Ts = 3142 rad/s, the Nyquist frequency of 1 ms, so every u is realizable), lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; keeps
%   p1 >= 3 rad/s; 1 = no lag).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K  = lg(0.1, 16, u(1));
z  = lg(5, 500, u(2));
r  = lg(1, min(300, (pi / 1e-3) / z), u(3));
z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1);
q  = qmin + u(5) * (1 - qmin);
x = [K, z, r, z1, q];
end
