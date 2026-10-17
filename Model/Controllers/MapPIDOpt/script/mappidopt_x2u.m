function u = mappidopt_x2u(x)
%MAPPIDOPT_X2U Inverse of mappidopt_u2x: design variables x = [K, z, p/z, z1, p1/z1, Kp, Ki, Kd, Tf] -> normalized u in [0,1]^9 (clipped to the box; K = 0 or Kd = 0 give u = 0).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = zeros(1, 9);
if x(1) > 0, u(1) = 0.01 + 0.99 * il(0.1, 16, x(1)); end
u(2) = il(5, 500, x(2));
u(3) = il(1, min(300, (pi / 1e-3) / x(2)), x(3));
u(4) = il(8, 120, x(4));
qmin = max(0.1, 3 / x(4));
u(5) = (x(5) - qmin) / (1 - qmin);
u(6) = il(1e-3, 30, x(6));
u(7) = il(0.1, 2000, x(7));
if x(8) > 0, u(8) = 0.01 + 0.99 * il(1e-4, 2, x(8)); end
u(9) = il(1e-3, 0.0796, x(9));
u = min(max(u, 0), 1);
end
