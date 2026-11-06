function R = pidlag_margins(Gj, w, d, Tdelay, gainMult)
%PIDLAG_MARGINS Linear stability margins of the PIDOpt / PIDLag loop over the 68 linearized Plants (design tool; the simulation gate of QuyChuan 5.2 stays calib_margin).
%
%   R = pidlag_margins(Gj, w, d)                    Gj, w from mappid_plants (68 plants x 1 slope; the plants are the same set the MapPID design used); d: Kp, Ki, Kd, Tf, lag (optional struct z1, p1)
%   R = pidlag_margins(Gj, w, d, Tdelay, gainMult)  Tdelay [s] (default 1 ms: sensor update + controller sample, as mappid_margins), gainMult (default 1)
%   Loop for plant G:   L(jw) = -gainMult H(jw) C(jw) Gm(jw) exp(-jw Tdelay) G(jw),   C = Kp + Ki/(jw) + Kd jw/(Tf jw + 1),   H = (1 + jw/z1)/(1 + jw/p1) (1 without lag),
%   Gm = motor 100 Hz. Same Nyquist and crossing logic as mappid_margins.m (this is its PID-only form with the lag acting on the whole PID).
%   R.stable, R.PM [deg] (smallest over all gain crossovers), R.GM (smallest over all phase crossovers), R.wc, R.HF = (p1/z1)(Kp + Kd/Tf) (high-frequency gain:
%   what the sensor noise is multiplied by), R.worst (plant with the smallest PM), R.PMmap (plants x 1).
if nargin < 4 || isempty(Tdelay), Tdelay = 1e-3; end
if nargin < 5 || isempty(gainMult), gainMult = 1; end
wm = 2 * pi * 100;
w = w(:); jw = 1i * w;
H = ones(size(w)); lagGain = 1;
if isfield(d, 'lag') && ~isempty(d.lag) && isfinite(d.lag.z1) && isfinite(d.lag.p1)
    H = (1 + jw / d.lag.z1) ./ (1 + jw / d.lag.p1); lagGain = d.lag.p1 / d.lag.z1;
end
C = H .* (d.Kp + d.Ki ./ jw + d.Kd * jw ./ (d.Tf * jw + 1));
Gm = wm ./ (jw + wm) .* exp(-jw * Tdelay);
nP = numel(Gj);
PMmap = Inf(nP, 1); GMmin = Inf; wcmax = 0; stable = true;
if all(abs(C) == 0), stable = false; end                      % an open loop has no crossing: treated as failing
for ip = 1:nP
    L = C .* (-gainMult * Gm .* Gj{ip});
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
R.HF = lagGain * (d.Kp + d.Kd / d.Tf);
end
