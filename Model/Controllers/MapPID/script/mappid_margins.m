function R = mappid_margins(Gj, w, d, Tdelay, gainMult)
%MAPPID_MARGINS Linear stability margins of the MapPID loop over all linearized Plants and all Map slopes (design tool, QuyChuan 5.2 keeps the
%   simulation gate; PM and GM here are the design requirement of the Map compensator, extended with the PID branch).
%
%   R = mappid_margins(Gj, w, d)                    Gj, w from mappid_plants; d: Kmax, lead (z, p), lag (z1, p1; optional), Kp, Ki, Kd, Tf
%   R = mappid_margins(Gj, w, d, Tdelay, gainMult)  Tdelay [s] (default 1 ms: sensor update 1 ms + controller sample 1 ms, as map_margins), gainMult (default 1)
%   Loop for plant G and slope k:   L(jw) = -gainMult [k H(jw) + C(jw)] Gm(jw) exp(-jw Tdelay) G(jw)
%     H = lead x lag (Map branch only), Gm = motor 100 Hz, C(jw) = Kp + Ki/(jw) + Kd jw/(Tf jw + 1) (PID branch, continuous approximation of the 1 ms
%     discrete PID, the same treatment as the lead-lag of map_margins), slopes k = Kmax x {0, 0.25, 0.5, 0.75, 1} (k = 0: T_s in the dead zone or
%     on a flat part of the table, only the PID acts; nothing to check when the PID is 0 too).
%   R.stable (all loops stable by the Nyquist winding), R.PM [deg] (smallest over all gain crossovers), R.GM (smallest over all phase crossovers),
%   R.wc [rad/s] (highest gain crossover), R.HF = Kmax (p/z)(p1/z1) + Kp + Kd/Tf (high-frequency gain: what the sensor noise is multiplied by),
%   R.worst = index of the plant with the smallest PM, R.PMmap (plants x slopes matrix of PM).
if nargin < 4 || isempty(Tdelay), Tdelay = 1e-3; end
if nargin < 5 || isempty(gainMult), gainMult = 1; end
wm = 2 * pi * 100;
w = w(:); jw = 1i * w;
H = (1 + jw / d.lead.z) ./ (1 + jw / d.lead.p);
hasLag = isfield(d, 'lag') && ~isempty(d.lag) && isfinite(d.lag.z1) && isfinite(d.lag.p1);
lagGain = 1;
if hasLag, H = H .* (1 + jw / d.lag.z1) ./ (1 + jw / d.lag.p1); lagGain = d.lag.p1 / d.lag.z1; end
C = d.Kp + d.Ki ./ jw + d.Kd * jw ./ (d.Tf * jw + 1);
kset = d.Kmax * [0 0.25 0.5 0.75 1];
if d.Kmax == 0, kset = 0; end
Gm = wm ./ (jw + wm) .* exp(-jw * Tdelay);
nP = numel(Gj); nK = numel(kset);
PMmap = Inf(nP, nK); GMmin = Inf; wcmax = 0; stable = true;
for ip = 1:nP
    base = -gainMult * Gm .* Gj{ip};
    L = (kset .* H + C) .* base;                 % Nw x nK
    if all(abs(L(:)) == 0), continue; end
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
R.HF = d.Kmax * (d.lead.p / d.lead.z) * lagGain + d.Kp + d.Kd / d.Tf;
end
