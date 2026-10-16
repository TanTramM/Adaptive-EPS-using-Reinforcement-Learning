function u = mappidlag_x2u(x)
%MAPPIDLAG_X2U Inverse of mappidlag_u2x: design variables x = [K, z1, p1/z1, Kp, Ki, Kd, Tf] -> normalized u in [0,1]^7 (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = zeros(1, 7);
u(1) = x(1) / 16;
u(2) = il(8, 120, x(2));
qmin = max(0.1, 3 / x(2));
u(3) = (x(3) - qmin) / (1 - qmin);
u(4) = x(4) / 3;
u(5) = il(0.5, 200, x(5));
u(6) = x(6) / 0.05;
u(7) = il(1e-3, 0.02, x(7));
u = min(max(u, 0), 1);
end
