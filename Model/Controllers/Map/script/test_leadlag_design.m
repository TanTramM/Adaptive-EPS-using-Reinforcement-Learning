function ok = test_leadlag_design()
%TEST_LEADLAG_DESIGN Test of the lead-lag design tools (map_margins_batch.m, map_margins.m with lag, map_noise_gain.m with lag, design_leadlag.m).
%
%   A) map_margins_batch equals map_margins on many random lead-lag candidates, both plants, several slopes (stable, PM, GM, wc);
%   B) known values on the linearized Plant at 60 km/h (four operating points of map_op_points): no compensator at K = 6.75 is unstable (PM about -6.5 deg),
%      lead (59.82, 1666) at K = 6.75 gives PM 45.2 / GM 4.56, lead-lag (38.3, 952, 25, 8.75) at K = 10 gives PM 45.4 / GM 4.85 (computed independently
%      from the loop formula in this file, not from map_margins);
%   C) high-frequency gain and noise gain with a lag: K*(p/z)*(p1/z1), and the noise gain falls when the lag is added;
%   D) design_leadlag returns candidates that pass the gates when checked with map_margins, a lead-only mode, and a result no worse (10 %) than the known designs.
%   Self-contained apart from the Plant linearization. Prints "[test_leadlag_design] TEST PASS".
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths; addpath(scriptDir);

P   = map_params();
ops = map_op_points();
w   = logspace(-1, 5, 3000)';
Gj  = cell(1, size(ops, 1));
for i = 1:size(ops, 1)
    Gj{i} = squeeze(freqresp(map_plant_lin(P, 60 / 3.6, ops(i, 1) * P.g, ops(i, 2)), w));
end
nTot = 0; nBad = 0;

%% A) batch equals single
rng(7);
nC = 40;
z  = 10.^(log10(5) + rand(nC, 1) * 2);  p = z .* 10.^(log10(1.2) + rand(nC, 1) * 2.3);
z1 = 10.^(log10(8) + rand(nC, 1) * 1.2); p1 = z1 .* (0.1 + 0.8 * rand(nC, 1));
z1(1:5) = Inf; p1(1:5) = Inf; z(6) = Inf; p(6) = Inf;     % some without lag, one without lead
maxd = 0; nSame = 0; nAll = 0;
for ig = 1:2
    for k = [2 6.75 10]
        Rb = map_margins_batch(Gj{ig}, w, k, z, p, z1, p1);
        for c = 1:nC
            Rs = map_margins(Gj{ig}, w, k, z(c), p(c), [], z1(c), p1(c));
            nAll = nAll + 1;
            same = (Rb.stable(c) == (Rs.stable == 1)) && closeTo(Rb.PM(c), Rs.PM) && closeTo(Rb.GM(c), Rs.GM) && abs(Rb.wc(c) - Rs.wc) < 1e-9 * max(1, Rs.wc);
            nSame = nSame + same;
        end
    end
end
[nTot, nBad] = check(nTot, nBad, 'batch = single on 240 random (candidate, plant, slope) triples', nSame == nAll, sprintf('%d of %d equal', nSame, nAll));

%% B) known values, with the loop written here
wm = 2 * pi * 100;
loop = @(G, k, zz, pp, zz1, pp1) -k * (1 + 1i * w / zz) ./ (1 + 1i * w / pp) .* (1 + 1i * w / zz1) ./ (1 + 1i * w / pp1) .* (wm ./ (1i * w + wm)) .* exp(-1i * w * 1e-3) .* G;
pmOf = @(L) crossPM(w, L);
pm0 = zeros(1, 4); pm1 = pm0; pm2 = pm0;
for i = 1:4
    pm0(i) = pmOf(loop(Gj{i}, 6.75, 1e9, 1e9, 1e9, 1e9));
    pm1(i) = pmOf(loop(Gj{i}, 6.75, 59.82, 1665.96, 1e9, 1e9));
    pm2(i) = pmOf(loop(Gj{i}, 10, 38.3, 952, 25, 8.75));
end
[nTot, nBad] = check(nTot, nBad, 'no compensator K = 6.75: PM about -6.5 deg (unstable)', all(abs(pm0 + 6.55) < 0.4), sprintf('%s', num2str(pm0, '%.2f ')));
[nTot, nBad] = check(nTot, nBad, 'lead (59.82, 1666) K = 6.75: PM 45.2 deg', all(abs(pm1 - 45.2) < 0.3), sprintf('%s', num2str(pm1, '%.2f ')));
[nTot, nBad] = check(nTot, nBad, 'lead-lag (38.3, 952, 25, 8.75) K = 10: PM 45.4 deg', all(abs(pm2 - 45.4) < 0.3), sprintf('%s', num2str(pm2, '%.2f ')));
Rl = map_margins(Gj{2}, w, 6.75, 59.82, 1665.96);
Rll = map_margins(Gj{2}, w, 10, 38.3, 952, [], 25, 8.75);
[nTot, nBad] = check(nTot, nBad, 'GM 4.56 (lead) and 4.85 (lead-lag), all stable', abs(Rl.GM - 4.56) < 0.05 && abs(Rll.GM - 4.85) < 0.05 && Rl.stable == 1 && Rll.stable == 1, sprintf('%.2f %.2f', Rl.GM, Rll.GM));

%% C) high-frequency gain and noise gain
[nTot, nBad] = check(nTot, nBad, 'HF gain K*(p/z)*(p1/z1) = 10*(952/38.3)*(8.75/25) = 87.0', abs(Rll.HF - 10 * (952 / 38.3) * (8.75 / 25)) < 1e-9 && abs(Rll.HF - 87.0) < 0.1, sprintf('%.2f', Rll.HF));
[nTot, nBad] = check(nTot, nBad, 'lead K = 6.75: HF gain 6.75*1665.96/59.82 = 188.0', abs(Rl.HF - 6.75 * 1665.96 / 59.82) < 1e-9, sprintf('%.2f', Rl.HF));
g0 = map_noise_gain(10, 38.3, 952);
g1 = map_noise_gain(10, 38.3, 952, [], 25, 8.75);
[nTot, nBad] = check(nTot, nBad, 'noise gain falls when the lag is added (same K and lead)', g1 < 0.6 * g0 && g1 > 0, sprintf('%.3f -> %.3f', g0, g1));

%% D) design_leadlag
t0 = tic;
D = design_leadlag(Gj, w, 6.75, false);
[nTot, nBad] = check(nTot, nBad, 'lead-only K = 6.75: found, HF no worse than the known lead (188.0) by more than 10 %', D.ok == 1 && D.HF <= 1.1 * 188.0 && isinf(D.z1) && isinf(D.p1), sprintf('z %.1f p %.0f HF %.1f (%d tried, %.1f s)', D.z, D.p, D.HF, D.nTried, toc(t0)));
Rv = map_margins(Gj{1}, w, 6.75, D.z, D.p);
okAll = true;
for ig = 1:4
    for k = 6.75 * [0.25 0.5 0.75 1]
        R = map_margins(Gj{ig}, w, k, D.z, D.p);
        okAll = okAll && R.stable == 1 && R.PM >= 45 - 1e-9 && R.GM >= 2 - 1e-9;
    end
end
[nTot, nBad] = check(nTot, nBad, 'the chosen lead passes the gates on all plants and slopes (map_margins)', okAll && Rv.stable == 1, '');
t0 = tic;
D2 = design_leadlag(Gj, w, 10, true);
[nTot, nBad] = check(nTot, nBad, 'lead-lag K = 10: found, HF no worse than the known lead-lag (87.0) by more than 10 %', D2.ok == 1 && D2.HF <= 1.1 * 87.0, sprintf('z %.1f p %.0f z1 %.1f p1 %.2f HF %.1f (%d tried, %.1f s)', D2.z, D2.p, D2.z1, D2.p1, D2.HF, D2.nTried, toc(t0)));
okAll = true;
for ig = 1:4
    for k = 10 * [0.25 0.5 0.75 1]
        R = map_margins(Gj{ig}, w, k, D2.z, D2.p, [], D2.z1, D2.p1);
        okAll = okAll && R.stable == 1 && R.PM >= 45 - 1e-9 && R.GM >= 2 - 1e-9;
    end
end
[nTot, nBad] = check(nTot, nBad, 'the chosen lead-lag passes the gates on all plants and slopes (map_margins)', okAll, '');
[nTot, nBad] = check(nTot, nBad, 'bounds respected: p <= 3142 rad/s, p1 >= 3 rad/s, p1 < z1', D2.p <= pi / 1e-3 + 1e-6 && D2.p1 >= 3 - 1e-9 && D2.p1 < D2.z1, '');
D3 = design_leadlag(Gj, w, 14, false);
[nTot, nBad] = check(nTot, nBad, 'lead only, K = 14 (above the stability limit of one lead): no feasible candidate', D3.ok == 0, sprintf('feasible coarse %d', D3.nCoarse));
% NOTE: lead-lag WITHOUT a bound on the lag strength stays feasible even at K = 30 (the lag sits on the grid bound q = 0.1, p1 = 3 rad/s and cuts the mid-band gain
% about 10 times); that is why design_leadlag takes bandGain = [minimum lag gain, 12.57 rad/s] (DieuKhien_Map.txt, log B, 2026-10-11).

ok = (nBad == 0);
if ok
    fprintf('[test_leadlag_design] TEST PASS (%d checks)\n', nTot);
else
    fprintf('[test_leadlag_design] TEST FAIL (%d of %d checks failed)\n', nBad, nTot);
end
end

function tf = closeTo(a, b)
tf = (isinf(a) && isinf(b)) || abs(a - b) <= 1e-8 * max(1, abs(b));
end

function pm = crossPM(w, L)
% phase margin at the highest gain crossover, written independently of map_margins (first crossing from the top)
mag = abs(L); ph = unwrap(angle(L)); ph = ph - 2 * pi * round(ph(1) / (2 * pi));
s = mag - 1; idx = find(s(1:end-1) .* s(2:end) < 0);
if isempty(idx), pm = Inf; return; end
j = idx(end); f = s(j) / (s(j) - s(j+1));
pm = 180 + rad2deg(ph(j) + f * (ph(j+1) - ph(j)));
end

function [nTot, nBad] = check(nTot, nBad, name, cond, info)
nTot = nTot + 1;
if cond
    fprintf('  ok    %s %s\n', name, info);
else
    nBad = nBad + 1;
    fprintf('  FAIL  %s %s\n', name, info);
end
end
