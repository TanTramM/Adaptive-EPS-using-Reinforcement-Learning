function u = pid_x2u(x)
%PID_X2U Inverse of pid_u2x (clipped to the box): x = [Kp, Ki, Kd, Tf] -> K = Kp, Ti = Kp/Ki, Td = Kd/Kp, N = Td/Tf -> u.
x = x(:)';
K = x(1); Ti = x(1) / x(2); Td = x(3) / x(1); N = Td / x(4);
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = [il(0.01, 30, K), il(2e-3, 10, Ti), il(0.02, 0.796, Td), il(8, 20, N)];
u = min(max(u, 0), 1);
end
