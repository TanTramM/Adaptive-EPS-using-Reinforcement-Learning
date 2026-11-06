function R = map_margins_batch(Gjw, w, k, z, p, z1, p1, Tdelay)
%MAP_MARGINS_BATCH Stability margins of the Map loop for MANY compensators at once (same definitions as map_margins.m, vectorized).
%
%   R = map_margins_batch(Gjw, w, k, z, p, z1, p1)      Gjw = squeeze(freqresp(G, w)) (column), w column [rad/s], k = map slope,
%                                                       z, p, z1, p1 = column vectors [rad/s] of the candidates (Inf: stage absent)
%   Per candidate: H(jw) = (jw/z + 1)/(jw/p + 1) * (jw/z1 + 1)/(jw/p1 + 1),  L(jw) = -k H Gm exp(-jw Tdelay) Gjw  (Tdelay default 1 ms)
%   R.stable (logical), R.PM [deg] (smallest over all gain crossovers, Inf if none), R.GM (smallest over phase crossovers, Inf if none),
%   R.wc [rad/s] (highest gain crossover, 0 if none): one entry per candidate. Memory grows with numel(z) x numel(w); call in chunks.
if nargin < 8 || isempty(Tdelay), Tdelay = 1e-3; end
wm = 2 * pi * 100;
w = w(:); Gjw = Gjw(:);
z = z(:); p = p(:); z1 = z1(:); p1 = p1(:);
jw = 1i * w.';                                           % 1 x Nw
H = (1 + jw ./ z) ./ (1 + jw ./ p);                      % Nc x Nw (z = Inf or p = Inf gives 1 for the lead)
H = H .* (1 + jw ./ z1) ./ (1 + jw ./ p1);
base = -k * (wm ./ (1i * w + wm)) .* exp(-1i * w * Tdelay) .* Gjw;   % Nw x 1
L = H .* base.';
mag = abs(L);
ph = unwrap(angle(L), [], 2);
ph = ph - 2 * pi * round(ph(:, 1) / (2 * pi));           % L(0) > 0: start phase near 0
phw = unwrap(angle(1 + L), [], 2);
R.stable = abs(phw(:, end) - phw(:, 1)) < pi & mag(:, end) < 0.5;

s = mag - 1;
s1 = s(:, 1:end-1); s2 = s(:, 2:end);
cross = s1 .* s2 < 0;
f = s1 ./ (s1 - s2);
phc = ph(:, 1:end-1) + f .* (ph(:, 2:end) - ph(:, 1:end-1));
pm = 180 + rad2deg(phc);
pm(~cross) = Inf;
R.PM = min(pm, [], 2);
wcm = cross .* w(1:end-1).';
R.wc = max(wcm, [], 2);

q = ph + pi;
jj = (q(:, 1:end-1) .* q(:, 2:end) < 0) | ((ph(:, 1:end-1) + 3 * pi) .* (ph(:, 2:end) + 3 * pi) < 0);
gm = 1 ./ (0.5 * mag(:, 1:end-1) + 0.5 * mag(:, 2:end));
gm(~jj) = Inf;
R.GM = min(gm, [], 2);
end
