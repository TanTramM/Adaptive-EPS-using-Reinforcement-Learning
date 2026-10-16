function x = mapopt_u2x(u)
%MAPOPT_U2X Normalized variables u in [0,1]^5 -> x = [K, z, p/z, z1, p1/z1]. Same boxes as MapPID (mappid_u2x): K 0-16 (linear), lead z 5-500 rad/s (log),
%   p/z 1.2 to min(300, (pi/Ts)/z) (log), lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 0.9 (linear).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K = 16 * u(1); z = lg(5, 500, u(2)); r = lg(1.2, min(300, (pi / 1e-3) / z), u(3)); z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1); q = qmin + u(5) * (0.9 - qmin);
x = [K, z, r, z1, q];
end
