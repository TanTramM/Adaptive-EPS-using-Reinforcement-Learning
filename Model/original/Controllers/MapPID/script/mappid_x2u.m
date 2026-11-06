function u = mappid_x2u(x)
%MAPPID_X2U Inverse of mappid_u2x. The PID columns are first converted from (Kp,Ki,Kd,Tf) to (K,Ti,Td,N).
x = x(:)';
il = @(a, b, v) (log10(v) - log10(a)) ./ (log10(b) - log10(a));
u = zeros(1, 9);
if x(1) > 0, u(1) = 0.01 + 0.99 * il(0.1, 16, x(1)); end
u(2) = il(5, 500, x(2));
u(3) = il(1, min(300, (pi / 1e-3) / x(2)), x(3));
u(4) = il(8, 120, x(4));
qmin = max(0.1, 3 / x(4));
u(5) = (x(5) - qmin) / (1 - qmin);
K = x(6); Ti = K / x(7); Td = x(8) / K; N = Td / x(9);
u(6) = il(0.01, 30, K);
u(7) = il(0.002, 10, Ti);
u(8) = il(0.020, 0.796, Td);
u(9) = il(8, 20, N);
u = min(max(u, 0), 1);
end
