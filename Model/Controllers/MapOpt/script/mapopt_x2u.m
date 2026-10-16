function u = mapopt_x2u(x)
%MAPOPT_X2U Inverse of mapopt_u2x (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
qmin = max(0.1, 3 / x(4));
u = [x(1) / 16, il(5, 500, x(2)), il(1.2, min(300, (pi / 1e-3) / x(2)), x(3)), il(8, 120, x(4)), (x(5) - qmin) / (0.9 - qmin)];
u = min(max(u, 0), 1);
end
