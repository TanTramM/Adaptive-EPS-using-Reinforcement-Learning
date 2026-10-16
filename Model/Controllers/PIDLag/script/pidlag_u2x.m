function x = pidlag_u2x(ctrl, u)
%PIDLAG_U2X Map the normalized optimisation variables u in [0,1]^n to the design variables x of pidlag_eval.
%   PIDOpt (n = 4): x = [Kp, Ki, Kd, Tf]
%   PIDLag (n = 6): x = [Kp, Ki, Kd, Tf, z1, p1/z1]
%   Bounds (same boxes as MapPID, DieuKhien_MapPIDLag.txt C2, D3): Kp 0-3 (linear), Ki 0.5-200 1/s (log), Kd 0-0.05 s (linear), Tf 1-20 ms (log),
%   lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; keeps p1 >= 3 rad/s; 1 = no lag, so the optimiser can switch the lag off).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
x = [3 * u(1), lg(0.5, 200, u(2)), 0.05 * u(3), lg(1e-3, 0.02, u(4))];
if strcmp(ctrl, 'PIDLag')
    z1 = lg(8, 120, u(5));
    qmin = max(0.1, 3 / z1);
    x = [x, z1, qmin + u(6) * (1 - qmin)];
end
end
