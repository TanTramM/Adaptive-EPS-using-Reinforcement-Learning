function x = pid_u2x(u)
%PID_U2X Normalized variables u in [0,1]^4 -> x = [Kp, Ki, Kd, Tf] of pidlag_eval('PID', ...): the WIDE box of the common method (DieuKhien_MapOpt.txt B1, DieuKhien_MapPID.txt G3, G10):
%   Kp 1e-3 - 30 (log), Ki 0.1 - 2000 1/s (log), Kd 0 or 1e-4 - 2 s (u(3) below 0.01 gives Kd = 0, otherwise log), Tf 1 ms - 79.6 ms (log; 1 ms = controller period,
%   79.6 ms = the steering-band limit of QuyChuan 6.2).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
Kp = lg(1e-3, 30, u(1));
Ki = lg(0.1, 2000, u(2));
if u(3) < 0.01, Kd = 0; else, Kd = lg(1e-4, 2, (u(3) - 0.01) / 0.99); end
Tf = lg(1e-3, 0.0796, u(4));
x = [Kp, Ki, Kd, Tf];
end
