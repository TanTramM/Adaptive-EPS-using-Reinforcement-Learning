function R = map_opt_margins(Gj, w, d, Tdelay, gainMult)
%MAP_OPT_MARGINS Linear stability margins of the Map loop (no PID) over all linearized Plants and the Map slopes k = Kmax x {0.25, 0.5, 0.75, 1}.
%
%   R = map_opt_margins(Gj, w, d)   Gj, w from map_opt_plants; d: Kmax, lead (z, p), lag (z1, p1)
%   Loop for plant G and slope k:   L(jw) = -gainMult k H(jw) Gm(jw) exp(-jw Tdelay) G(jw),   H = lead x lag, Gm = motor 100 Hz, Tdelay default 1 ms
%   (same definition as map_margins.m and, with Kp = Ki = Kd = 0, as mappid_margins.m: Map alone PM 45.292 deg, GM 5.674 for the old design).
%   R.stable, R.PM [deg] (smallest over all gain crossovers), R.GM (smallest over all phase crossovers), R.wc [rad/s], R.HF = Kmax (p/z)(p1/z1) (high-frequency gain),
%   R.worst = index of the plant with the smallest PM, R.PMmap (plants x slopes).
if nargin < 4 || isempty(Tdelay), Tdelay = 1e-3; end
if nargin < 5 || isempty(gainMult), gainMult = 1; end
wm = 2 * pi * 100;
w = w(:); jw = 1i * w;
H = (1 + jw / d.lead.z) ./ (1 + jw / d.lead.p) .* (1 + jw / d.lag.z1) ./ (1 + jw / d.lag.p1);
kset = d.Kmax * [0.25 0.5 0.75 1];
Gm = wm ./ (jw + wm) .* exp(-jw * Tdelay);
nP = numel(Gj); nK = numel(kset);
PMmap = Inf(nP, nK); GMmin = Inf; wcmax = 0; stable = true;
for ip = 1:nP
    base = -gainMult * Gm .* Gj{ip};
    L = (kset .* H) .* base;                     % Nw x nK
    mag = abs(L);
    ph = unwrap(angle(L), [], 1);
    ph = ph - 2 * pi * round(ph(1, :) / (2 * pi));
    phw = unwrap(angle(1 + L), [], 1);
    st = abs(phw(end, :) - phw(1, :)) < pi & mag(end, :) < 0.5;
    stable = stable && all(st);
    s = mag - 1; s1 = s(1:end-1, :); s2 = s(2:end, :);
    cross = s1 .* s2 < 0;
    f = s1 ./ (s1 - s2);
    phc = ph(1:end-1, :) + f .* (ph(2:end, :) - ph(1:end-1, :));
    pm = 180 + rad2deg(phc); pm(~cross) = Inf;
    PMmap(ip, :) = min(pm, [], 1);
    wcm = cross .* w(1:end-1); wcmax = max(wcmax, max(wcm(:)));
    q = ph + pi;
    jj = (q(1:end-1, :) .* q(2:end, :) < 0) | ((ph(1:end-1, :) + 3 * pi) .* (ph(2:end, :) + 3 * pi) < 0);
    gm = 1 ./ (0.5 * mag(1:end-1, :) + 0.5 * mag(2:end, :)); gm(~jj) = Inf;
    GMmin = min(GMmin, min(gm(:)));
end
R.stable = stable; R.PMmap = PMmap;
[R.PM, R.worst] = min(min(PMmap, [], 2));
R.GM = GMmin; R.wc = wcmax;
R.HF = d.Kmax * (d.lead.p / d.lead.z) * (d.lag.p1 / d.lag.z1);
end
