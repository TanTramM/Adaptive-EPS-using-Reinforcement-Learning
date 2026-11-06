function x = map_u2x(u)
%MAP_OPT_U2X Map the normalized optimisation variables u in [0,1]^5 to the five Map design variables x = [K, z, p/z, z1, p1/z1] of map_opt_eval.
%   Bounds: K 5-16 (2026-10-18, PhuongPhap_TimThamSo.txt 13.2; with e_max 10 % the old 7 is no longer implied)  [earlier: K 7-16 (log; was 0.1-16 in the first attempt of 2026-10-18, which found no feasible design in 250 evaluations: on CALIB v2 e_rel <= 5 % needs K above about 8 (best seen: K 8.15, e_rel 5.27 %), so K below 7 is never feasible; the 255 evaluations stay in the csv), lead z 5-500 rad/s (log), p/z from 1 to min(300, 3142/z) (log; 1 = no lead;
%   p <= pi/Ts = 3142 rad/s, the Nyquist frequency of 1 ms, so every u is realizable), lag z1 8-120 rad/s (log), p1/z1 from max(0.1, 3/z1) to 1 (linear; keeps
%   p1 >= 3 rad/s; 1 = no lag).
u = min(max(u(:)', 0), 1);
lg = @(a, b, t) 10 .^ (log10(a) + t .* (log10(b) - log10(a)));
K  = lg(5, 16, u(1));
z  = lg(5, 500, u(2));
r  = lg(1, min(300, (pi / 1e-3) / z), u(3));
z1 = lg(8, 120, u(4));
qmin = max(0.1, 3 / z1);
q  = qmin + u(5) * (1 - qmin);
x = [K, z, r, z1, q];
end
