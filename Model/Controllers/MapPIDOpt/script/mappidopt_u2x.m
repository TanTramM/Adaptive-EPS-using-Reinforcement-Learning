function x = mappidopt_u2x(u)
%MAPPIDOPT_U2X Map the normalized optimisation variables u in [0,1]^9 to the nine MapPIDOpt design variables x of mappidopt_eval:
%   x = [K, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf]. WIDE box of the common method (DieuKhien_MapPID.txt H3; same as MapOpt and PIDOpt):
%   K 0 or 0.1-16 (u below 0.01 gives K = 0, the Map branch off; otherwise log; upper bound 16 kept), lead z 5-500 rad/s (log), p/z from 1 to min(300, (pi/Ts)/z) (log; 1 = no lead;
%   p <= pi/Ts = 3142 rad/s), lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; 1 = no lag; keeps p1 >= 3 rad/s), Kp 1e-3-30 (log), Ki 0.1-2000 1/s (log),
%   Kd 0 or 1e-4-2 s (u below 0.01 gives Kd = 0, otherwise log), Tf 1 ms - 79.6 ms (log; 1 ms = controller period, 79.6 ms = the steering-band limit of QuyChuan 6.2).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
if u(1) < 0.01, K = 0; else, K = lg(0.1, 16, (u(1) - 0.01) / 0.99); end
z  = lg(5, 500, u(2));
r  = lg(1, min(300, (pi / 1e-3) / z), u(3));
z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1);
q  = qmin + u(5) * (1 - qmin);
Kp = lg(1e-3, 30, u(6));
Ki = lg(0.1, 2000, u(7));
if u(8) < 0.01, Kd = 0; else, Kd = lg(1e-4, 2, (u(8) - 0.01) / 0.99); end
Tf = lg(1e-3, 0.0796, u(9));
x = [K, z, r, z1, q, Kp, Ki, Kd, Tf];
end
