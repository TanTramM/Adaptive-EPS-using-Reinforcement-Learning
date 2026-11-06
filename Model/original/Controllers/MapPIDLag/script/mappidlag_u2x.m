function x = mappidlag_u2x(u)
%MAPPIDLAG_U2X Map the normalized optimisation variables u in [0,1]^7 to the seven MapPIDLag design variables x of mappidlag_eval:
%   x = [K, z1, p1/z1, Kp, Ki, Kd, Tf]. Bounds (DieuKhien_MapPIDLag.txt C2, the same as MapPID C2 without the lead): K 0-16 (linear), lag z1 8-120 rad/s
%   (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; keeps p1 >= 3 rad/s; 1 = no lag, so the optimiser can switch the lag off, as in PIDLag of the Linear frame), Kp 0-3 (linear), Ki 0.5-200 1/s (log), Kd 0-0.05 s (linear), Tf 1-20 ms (log).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K  = 16 * u(1);
z1 = lg(8, 120, u(2));
qmin = max(0.1, 3 / z1);
q  = qmin + u(3) * (1 - qmin);
Kp = 3 * u(4);
Ki = lg(0.5, 200, u(5));
Kd = 0.05 * u(6);
Tf = lg(1e-3, 0.02, u(7));
x = [K, z1, q, Kp, Ki, Kd, Tf];
end
