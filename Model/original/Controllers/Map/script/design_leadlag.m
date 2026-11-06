function D = design_leadlag(Gj, w, K, useLag, bandGain, ext)
%DESIGN_LEADLAG Best lead (z, p) and lag (z1, p1) for a Map slope limit K over linearized plants (Documents/Notes/Controllers/DieuKhien_Map.txt A3-A4, A8).
%
%   D = design_leadlag(Gj, w, K)            lead-lag     (z, p, z1, p1)
%   D = design_leadlag(Gj, w, K, false)     lead only    (z1 = p1 = Inf), same lead grid, for the comparison variant
%     Gj = cell array of frequency responses squeeze(freqresp(G, w)) (one per operating plant), w = grid [rad/s] (column)
%   Gates (hard, all plants in Gj, slopes k = K*[0.25 0.5 0.75 1]): closed loop stable (Nyquist), PM >= 45 deg at all gain crossovers, GM >= 2.
%   Among the candidates passing, returns the one with the SMALLEST high-frequency gain  K*(p/z)*(p1/z1); ties go to the larger PM.
%   Two stages (QuyChuan 6.1): a coarse grid over wide bounds, then a fine grid (4 times finer) around the best coarse candidate.
%   Bounds (A4): lead z 5-500 rad/s, p/z 1.2-300 with p <= pi/1 ms = 3142 rad/s; lag z1 8-120 rad/s, p1/z1 0.1-0.9 with p1 >= 3 rad/s.
%   D.ok (0/1), D.z D.p D.z1 D.p1 [rad/s], D.PM D.GM D.wc [rad/s], D.HF, D.nCoarse D.nFine (candidates passing in each stage),
%   D.nTried (candidates examined, both stages), D.HFcoarse D.HFfine (best HF of each stage; the fine/coarse ratio is the resolution check),
%   D.atBound (struct of 0/1 flags: the coarse best sits on a bound of the grid; the bound must then be widened).
if nargin < 4, useLag = true; end
if nargin < 5, bandGain = [0 12.57]; end   % [minimum lag gain, frequency of the driver band edge (2 Hz) in rad/s]; 0 = no constraint
if nargin < 6, ext = struct(); end             % optional wider lag bounds (QuyChuan 6.1 extension step): fields qLim [min max] of p1/z1, p1Min [rad/s]
Ts = 1e-3; pMax = pi / Ts; p1Min = 3; if isfield(ext, "p1Min"), p1Min = ext.p1Min; end
zLim = [5 500]; rLim = [1.2 300]; z1Lim = [8 120]; qLim = [0.1 0.9];
if isfield(ext, "qLim"), qLim = ext.qLim; end
nz = 24; nr = 25; nz1 = 8; nq = 6; nFine = 9;
kset = K * [0.25 0.5 0.75 1];
order = hardestFirst(Gj, w, K);

% ---------------- coarse stage
zs = logspace(log10(zLim(1)), log10(zLim(2)), nz);
rs = logspace(log10(rLim(1)), log10(rLim(2)), nr);
if useLag
    z1s = logspace(log10(z1Lim(1)), log10(z1Lim(2)), nz1);
    qs = linspace(qLim(1), qLim(2), nq);
else
    z1s = Inf; qs = 1;
end
C = grid4(zs, rs, z1s, qs, useLag, pMax, p1Min, bandGain);
[feas, PM, GM, wc] = scan(Gj, w, kset, order, C);
D = struct('ok', 0, 'z', NaN, 'p', NaN, 'z1', NaN, 'p1', NaN, 'PM', NaN, 'GM', NaN, 'wc', NaN, 'HF', Inf, ...
    'nCoarse', nnz(feas), 'nFine', 0, 'nTried', numel(C.z), 'HFcoarse', Inf, 'HFfine', Inf, ...
    'atBound', struct('z', 0, 'r', 0, 'z1', 0, 'q1', 0, 'p', 0, 'p1', 0));
if ~any(feas), return; end
[ib, hfc] = pick(K, C, feas, PM);
D.HFcoarse = hfc;
D.atBound = bounds(C, ib, zs, rs, z1s, qs, useLag, pMax, p1Min);

% ---------------- fine stage around the best coarse candidate
fz = (zLim(2) / zLim(1))^(1 / (nz - 1)); fr = (rLim(2) / rLim(1))^(1 / (nr - 1));
zf = logspace(log10(C.z(ib) / fz), log10(C.z(ib) * fz), nFine);
rf = logspace(log10(C.r(ib) / fr), log10(C.r(ib) * fr), nFine);
if useLag
    fz1 = (z1Lim(2) / z1Lim(1))^(1 / (nz1 - 1)); dq = (qLim(2) - qLim(1)) / (nq - 1);
    z1f = logspace(log10(C.z1(ib) / fz1), log10(C.z1(ib) * fz1), nFine);
    qf = linspace(C.q(ib) - dq, C.q(ib) + dq, nFine);
    qf = qf(qf > 0.02 & qf < 0.98);
else
    z1f = Inf; qf = 1;
end
F = grid4(zf, rf, z1f, qf, useLag, pMax, p1Min, bandGain);
[feasF, PMF, GMF, wcF] = scan(Gj, w, kset, order, F);
D.nTried = D.nTried + numel(F.z);
D.nFine = nnz(feasF);
Pk = pickAll(K, C, feas, PM, GM, wc, F, feasF, PMF, GMF, wcF);
D.ok = 1; D.z = Pk.z; D.p = Pk.p; D.z1 = Pk.z1; D.p1 = Pk.p1; D.PM = Pk.PM; D.GM = Pk.GM; D.wc = Pk.wc; D.HF = Pk.HF;
D.HFfine = Pk.HFfine;
end

%% ----------------------------------------------------------------------------------------------------------------
function order = hardestFirst(Gj, w, K)
% plants ordered by the phase margin of one reference lead at slope K, smallest first (speed only; the result does not depend on the order)
pm = zeros(numel(Gj), 1);
for i = 1:numel(Gj)
    R = map_margins(Gj{i}, w, K, 59.82, 1665.96);
    pm(i) = R.PM;
    if ~isfinite(pm(i)), pm(i) = 1e3; end
end
[~, order] = sort(pm, 'ascend');
end

function C = grid4(zs, rs, z1s, qs, useLag, pMax, p1Min, bandGain)
[Z, Rr, Z1, Q] = ndgrid(zs, rs, z1s, qs);
C.z = Z(:); C.r = Rr(:); C.z1 = Z1(:); C.q = Q(:);
C.p = C.z .* C.r;
if useLag, C.p1 = C.z1 .* C.q; else, C.p1 = Inf(size(C.z)); C.z1 = Inf(size(C.z)); end
keep = C.p <= pMax;
if useLag, keep = keep & C.p1 >= p1Min; end
if useLag && bandGain(1) > 0
    wb = bandGain(2);
    lagGain = abs((1 + 1i * wb ./ C.z1) ./ (1 + 1i * wb ./ C.p1));
    keep = keep & lagGain >= bandGain(1);
end
fn = fieldnames(C);
for i = 1:numel(fn), C.(fn{i}) = C.(fn{i})(keep); end
end

function [feas, PMmin, GMmin, wcTop] = scan(Gj, w, kset, order, C)
n = numel(C.z); chunk = 400;
alive = true(n, 1); PMmin = Inf(n, 1); GMmin = Inf(n, 1); wcTop = zeros(n, 1);
for ig = order(:)'
    for ik = numel(kset):-1:1                                  % highest slope first: rejects most candidates quickly
        idx = find(alive);
        for a = 1:chunk:numel(idx)
            c = idx(a:min(a + chunk - 1, numel(idx)));
            R = map_margins_batch(Gj{ig}, w, kset(ik), C.z(c), C.p(c), C.z1(c), C.p1(c));
            ok = R.stable & R.PM >= 45 & R.GM >= 2;
            alive(c(~ok)) = false;
            co = c(ok);
            PMmin(co) = min(PMmin(co), R.PM(ok));
            GMmin(co) = min(GMmin(co), R.GM(ok));
            if ik == numel(kset), wcTop(co) = max(wcTop(co), R.wc(ok)); end
        end
    end
end
feas = alive;
end

function hf = hfgain(K, C)
lagf = C.p1 ./ C.z1; lagf(isinf(C.p1)) = 1;
hf = K * (C.p ./ C.z) .* lagf;
end

function [ib, hf0] = pick(K, C, feas, PM)
hf = hfgain(K, C); hf(~feas) = Inf;
m = min(hf); cand = find(feas & abs(hf - m) < 1e-9 * max(1, m));
[~, j] = max(PM(cand)); ib = cand(j); hf0 = m;
end

function Pk = pickAll(K, C, feas, PM, GM, wc, F, feasF, PMF, GMF, wcF)
hc = hfgain(K, C); hc(~feas) = Inf;
hF = hfgain(K, F); hF(~feasF) = Inf;
Pk.HFfine = min(hF);
al.z = [C.z; F.z]; al.p = [C.p; F.p]; al.z1 = [C.z1; F.z1]; al.p1 = [C.p1; F.p1];
h = [hc; hF]; pm = [PM; PMF]; gm = [GM; GMF]; w_ = [wc; wcF];
m = min(h); cand = find(abs(h - m) < 1e-9 * max(1, m));
[~, j] = max(pm(cand)); i = cand(j);
Pk.z = al.z(i); Pk.p = al.p(i); Pk.z1 = al.z1(i); Pk.p1 = al.p1(i); Pk.PM = pm(i); Pk.GM = gm(i); Pk.wc = w_(i); Pk.HF = h(i);
end

function B = bounds(C, ib, zs, rs, z1s, qs, useLag, pMax, p1Min)
tol = 1e-9;
B.z = double(abs(C.z(ib) - zs(1)) < tol * zs(1) || abs(C.z(ib) - zs(end)) < tol * zs(end));
B.r = double(abs(C.r(ib) - rs(1)) < tol * rs(1) || abs(C.r(ib) - rs(end)) < tol * rs(end));
B.p = double(C.p(ib) > 0.97 * pMax);
if useLag
    B.z1 = double(abs(C.z1(ib) - z1s(1)) < tol * z1s(1) || abs(C.z1(ib) - z1s(end)) < tol * z1s(end));
    B.q1 = double(abs(C.q(ib) - qs(1)) < tol || abs(C.q(ib) - qs(end)) < tol);
    B.p1 = double(C.p1(ib) < 1.03 * p1Min);
else
    B.z1 = 0; B.q1 = 0; B.p1 = 0;
end
end
