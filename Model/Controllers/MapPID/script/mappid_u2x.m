function x = mappid_u2x(u)
%MAPPID_U2X Map the normalized optimisation variables u in [0,1]^9 to the nine MapPID design variables x of mappid_eval:
%   x = [K, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf]. Bounds (DieuKhien_MapPID.txt C2): K 0-16 (linear), lead z 5-500 rad/s (log), p/z 1.2 to min(300, (pi/Ts)/z)
%   (log; the upper end keeps p <= pi/Ts = 3142 rad/s, the Nyquist frequency of 1 ms, so every u is realizable), lag z1 8-120 rad/s (log),
%   p1/z1 from max(0.1, 3/z1) to 0.9 (linear; keeps p1 >= 3 rad/s), Kp 0-3 (linear), Ki 0.5-200 1/s (log), Kd 0-0.05 s (linear), Tf 1-20 ms (log).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K  = 16 * u(1);
z  = lg(5, 500, u(2));
r  = lg(1.2, min(300, (pi / 1e-3) / z), u(3));
z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1);
q  = qmin + u(5) * (0.9 - qmin);
Kp = 3 * u(6);
Ki = lg(0.5, 200, u(7));
Kd = 0.05 * u(8);
Tf = lg(1e-3, 0.02, u(9));
x = [K, z, r, z1, q, Kp, Ki, Kd, Tf];
end
