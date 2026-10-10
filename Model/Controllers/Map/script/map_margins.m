function R = map_margins(Gjw, w, k, z, p, Tdelay)
%MAP_MARGINS Stability margins of the Map loop from the frequency response of the linearized Plant (fast, no model objects).
%
%   R = map_margins(Gjw, w, k, z, p)    Gjw = squeeze(freqresp(G, w)) at grid w [rad/s], k = map slope, lead (z, p) [rad/s]
%   L(jw) = -k * H(jw) * Gm(jw) * exp(-j*w*Tdelay) * Gjw   (exact delay; Tdelay default 1 ms: sensor update 1 ms + controller sample 1 ms)
%   R.stable  1 if closed loop is stable (via Nyquist winding number)
%   R.PM      smallest phase margin over ALL gain crossovers |L| = 1 [deg] (Inf if |L| < 1 everywhere)
%   R.GM      smallest gain margin over all phase crossovers (phase = -180 deg)
%   R.wc      highest gain crossover frequency [rad/s] (0 if none)
%   R.HF      high-frequency gain of lead times k: k*p/z
if nargin < 6, Tdelay = 1e-3; end
wm = 2 * pi * 100;
if isinf(z)
    H = ones(size(w));
else
    H = (1i * w / z + 1) ./ (1i * w / p + 1);
end
L = -k * H .* (wm ./ (1i * w + wm)) .* exp(-1i * w * Tdelay) .* Gjw;
ph = unwrap(angle(L));
ph = ph - 2 * pi * round(ph(1) / (2 * pi));       % L(0) > 0: start phase near 0
mag = abs(L);
R.HF = k * (1 + (~isinf(z)) * (p / z - 1));
phw = unwrap(angle(1 + L));
R.stable = double(abs(phw(end) - phw(1)) < pi && mag(end) < 0.5);

s = mag - 1;
idx = find(s(1:end-1) .* s(2:end) < 0);
if isempty(idx)
    R.PM = Inf;
    R.wc = 0;
else
    pm = zeros(size(idx));
    for i = 1:numel(idx)
        f = s(idx(i)) / (s(idx(i)) - s(idx(i) + 1));
        phc = ph(idx(i)) + f * (ph(idx(i) + 1) - ph(idx(i)));
        pm(i) = 180 + rad2deg(phc);
    end
    R.PM = min(pm);
    R.wc = w(idx(end));
end

q = ph + pi;
jj = find(q(1:end-1) .* q(2:end) < 0);
jj = unique([jj; find((ph(1:end-1) + 3 * pi) .* (ph(2:end) + 3 * pi) < 0)]);
if isempty(jj)
    R.GM = Inf;
else
    gm = zeros(size(jj));
    for i = 1:numel(jj)
        gm(i) = 1 / (0.5 * mag(jj(i)) + 0.5 * mag(jj(i) + 1));
    end
    R.GM = min(gm);
end
end

