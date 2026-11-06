function x = pid_u2x(u)
%PID_U2X Normalized variables u in [0,1]^4 -> x = [Kp, Ki, Kd, Tf] of pidlag_eval('PID', ...) through the book parameters (K, Ti, Td, N).
%   Standard (ISA) form C(s) = K (1 + 1/(s Ti) + s Td/(1 + s Td/N)): Kp = K, Ki = K/Ti, Kd = K Td, Tf = Td/N (KeHoach_PID_Sach.txt 1, 2.3, 6.2).
%   Box (all log scale): K 0.01 - 30; Ti 2 ms - 10 s; Td 20 ms - 796 ms; N 8 - 20 (coarse levels u = 0, 1/3, 2/3, 1 give N = 8, 10.9, 14.7, 20).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K  = lg(0.01, 30, u(1));
Ti = lg(2e-3, 10, u(2));
Td = lg(0.02, 0.796, u(3));
N  = lg(8, 20, u(4));
x = [K, K / Ti, K * Td, Td / N];
end
