function x = mappid_u2x(u)
%MAPPID_U2X Map the normalized optimisation variables u in [0,1]^9 to the nine MapPID design variables x of mappid_eval:
%   x = [Kmap, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf]. The locked Map branch keeps its existing box. The four free PID coordinates are
%   the standard-form parameters (K, Ti, Td, N), mapped to the existing columns by Kp=K, Ki=K/Ti, Kd=K*Td, Tf=Td/N:
%   K 0 or 0.1-16 (u below 0.01 gives K = 0, the Map branch off; otherwise log; upper bound 16 kept), lead z 5-500 rad/s (log), p/z from 1 to min(300, (pi/Ts)/z) (log; 1 = no lead;
%   p <= pi/Ts = 3142 rad/s), lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; 1 = no lag; keeps p1 >= 3 rad/s).
%   PID box (KeHoach_PID_Sach.txt 2.3): K 0.01-30, Ti 0.002-10 s, Td 0.020-0.796 s, N 8-20, all logarithmic.
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
if u(1) < 0.01, Kmap = 0; else, Kmap = lg(0.1, 16, (u(1) - 0.01) / 0.99); end
z  = lg(5, 500, u(2));
r  = lg(1, min(300, (pi / 1e-3) / z), u(3));
z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1);
q  = qmin + u(5) * (1 - qmin);
K = lg(0.01, 30, u(6));
Ti = lg(0.002, 10, u(7));
Td = lg(0.020, 0.796, u(8));
N = lg(8, 20, u(9));
Kp = K; Ki = K / Ti; Kd = K * Td; Tf = Td / N;
x = [Kmap, z, r, z1, q, Kp, Ki, Kd, Tf];
end
