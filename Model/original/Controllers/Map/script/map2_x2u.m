function u = map2_x2u(x)
%MAP2_X2U Inverse of map2_u2x: x = [K, g_min] -> u in [0,1]^2 (clipped to the box).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = [il(1, 30, x(1)), il(1 / sqrt(2), 1, x(2))];
u = min(max(u, 0), 1);
end
