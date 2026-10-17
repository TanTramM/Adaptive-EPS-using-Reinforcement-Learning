function u = mapopt_x2u(x)
%MAPOPT_X2U Inverse of mapopt_u2x: design variables x = [K, z, p/z, z1, p1/z1] -> normalized u in [0,1]^5 (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = zeros(1, 5);
u(1) = il(0.1, 16, x(1));
u(2) = il(5, 500, x(2));
u(3) = il(1, min(300, (pi / 1e-3) / x(2)), x(3));
u(4) = il(8, 120, x(4));
qmin = max(0.1, 3 / x(4));
u(5) = (x(5) - qmin) / (1 - qmin);
u = min(max(u, 0), 1);
end
