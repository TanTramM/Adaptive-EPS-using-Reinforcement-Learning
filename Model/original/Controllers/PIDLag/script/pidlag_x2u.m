function u = pidlag_x2u(ctrl, x)
%PIDLAG_X2U Inverse of pidlag_u2x: design variables x -> normalized u in [0,1]^n (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = [x(1) / 3, il(0.5, 200, x(2)), x(3) / 0.05, il(1e-3, 0.02, x(4))];
if strcmp(ctrl, 'PIDLag')
    qmin = max(0.1, 3 / x(5));
    u = [u, il(8, 120, x(5)), (x(6) - qmin) / (1 - qmin)];
end
u = min(max(u, 0), 1);
end
