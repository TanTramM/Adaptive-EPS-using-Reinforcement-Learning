function x = map2_u2x(u)
%MAP2_U2X Normalized variables u in [0,1]^2 -> Map design variables x = [K, g_min] of the two-variable grid search
%   (PhuongPhap_TimThamSo.txt 14.1). Both on a log scale:
%   K     = 30^u(1)                                  1 to 30 [N.m per N.m], slope of the assist map
%   g_min = 10^(log10(1/sqrt(2)) * (1 - u(2)))       0.70711 (u = 0) to 1 (u = 1): lower bound of the lag gain at 2 Hz (1 = lag off, lead only)
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
x = [lg(1, 30, u(1)), lg(1 / sqrt(2), 1, u(2))];
end
