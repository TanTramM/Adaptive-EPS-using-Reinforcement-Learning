function u = mappid_x2u(x)
%MAPPID_X2U Inverse of mappid_u2x: design variables x = [K, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf] -> normalized u in [0,1]^9 (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = zeros(1, 9);
u(1) = x(1) / 16;
u(2) = il(5, 500, x(2));
u(3) = il(1.2, min(300, (pi / 1e-3) / x(2)), x(3));
u(4) = il(8, 120, x(4));
qmin = max(0.1, 3 / x(4));
u(5) = (x(5) - qmin) / (0.9 - qmin);
u(6) = x(6) / 3;
u(7) = il(0.5, 200, x(7));
u(8) = x(8) / 0.05;
u(9) = il(1e-3, 0.02, x(9));
u = min(max(u, 0), 1);
end
