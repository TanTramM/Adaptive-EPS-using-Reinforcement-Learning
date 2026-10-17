function u = pidopt_x2u(x)
%PIDOPT_X2U Inverse of pidopt_u2x (clipped to the box; Kd = 0 gives u(3) = 0).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
if x(3) <= 0, u3 = 0; else, u3 = 0.01 + 0.99 * il(1e-4, 2, x(3)); end
u = [il(1e-3, 30, x(1)), il(0.1, 2000, x(2)), u3, il(1e-3, 0.0796, x(4))];
u = min(max(u, 0), 1);
end
