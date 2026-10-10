function ok = test_tk()
%TEST_TK Test of the design case TK (test_cases('TK')) and of its scoring (tk_score.m, tk_block_scores.m). No controller, no Simulink model.
%
%   A) the case itself: grid, blocks, windows, targets of a_y, v, mu inside every window, reachability by the Plant, margin of the assist limit;
%   B) the scores on SYNTHETIC logged signals whose answers are known: R by group (equal weights, relative to T_d,ref), e_rel per window with
%      sign, reverse assist, S, TV, maxTa, and the per-block scores; every reference value is computed here with plain loops, not with the
%      code under test.
%   Self-contained: reads only data/plant_limits.json and data/ref.json for the reachability and margin checks.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths; addpath(scriptDir);

S = test_cases('TK');
nTot = 0; nBad = 0;

%% A) the case
fprintf('A) case TK\n');
t = S.t; dt = t(2) - t(1);
[nTot, nBad] = check(nTot, nBad, '1 ms grid, start at 0', abs(dt - 0.001) < 1e-12 && t(1) == 0 && all(abs(diff(t) - dt) < 1e-9), '');
[nTot, nBad] = check(nTot, nBad, 'length 117 s', abs(t(end) - 117) < 1e-9, sprintf('end %.3f', t(end)));
lab = {S.win.label}; nW = numel(S.win);
[nTot, nBad] = check(nTot, nBad, '19 windows', nW == 19, sprintf('%d', nW));
[nTot, nBad] = check(nTot, nBad, '11 static windows', nnz(startsWith(lab, 'static')) == 11, '');
[nTot, nBad] = check(nTot, nBad, '3 sine, 3 small, 2 mu windows', nnz(startsWith(lab, 'sine')) == 3 && nnz(startsWith(lab, 'small')) == 3 && nnz(startsWith(lab, 'mu')) == 2, '');
blk = S.blk;
[nTot, nBad] = check(nTot, nBad, '3 blocks 20 60 100 km/h tiling the case', numel(blk) == 3 && isequal([blk.speed], [20 60 100]) && blk(1).t0 == 0 && ...
      abs(blk(1).t1 - blk(2).t0) < 1e-12 && abs(blk(2).t1 - blk(3).t0) < 1e-12 && abs(blk(3).t1 - t(end)) < 1e-9, '');
t0 = [S.win.t0]; t1 = [S.win.t1];
[nTot, nBad] = check(nTot, nBad, 'windows start after the 2 s that are never scored', all(t0 >= 2), sprintf('min %.2f', min(t0)));
[nTot, nBad] = check(nTot, nBad, 'windows have positive length and sit inside the case', all(t1 > t0) && all(t1 <= t(end)), '');
inside = false(1, nW);
for j = 1:nW, inside(j) = any(t0(j) >= [blk.t0] & t1(j) <= [blk.t1]); end
[nTot, nBad] = check(nTot, nBad, 'every window lies inside one block', all(inside), '');
ord = sortrows([t0(:) t1(:)]);
[nTot, nBad] = check(nTot, nBad, 'no two windows overlap', all(ord(2:end, 1) >= ord(1:end-1, 2) - 1e-12), '');

% targets inside the windows
PL = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
ayMax = @(vk, mu) interp2(PL.a_y.mu(:)', PL.a_y.v_kmh(:), PL.a_y.table, mu, vk, 'linear');
refJ = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
okTarget = true; okReach = true; msg = '';
for j = 1:nW
    in = t >= t0(j) & t <= t1(j);
    L0 = lab{j};
    vk = S.v(in) * 3.6; mu = S.mu(in); ay = S.ayTarget(in);
    kb = find(t0(j) >= [blk.t0] & t1(j) <= [blk.t1], 1);
    if max(abs(vk - blk(kb).speed)) > 1e-6, okTarget = false; msg = [msg ' v:' L0]; end %#ok<AGROW>
    if startsWith(L0, 'static')
        lv = parseLevel(L0);
        if max(abs(ay - lv)) > 1e-6 || max(abs(mu - 0.8)) > 1e-9, okTarget = false; msg = [msg ' static:' L0]; end %#ok<AGROW>
    elseif startsWith(L0, 'sine')
        if blk(kb).speed == 20, b = 0.1; A = 0.05; else, b = 0.2; A = 0.1; end
        if abs(max(ay) - (b + A)) > 2e-3 || abs(min(ay) - (b - A)) > 2e-3 || max(ay) > 0.3 + 1e-9, okTarget = false; msg = [msg ' sine:' L0]; end %#ok<AGROW>
    elseif startsWith(L0, 'small')
        if blk(kb).speed == 20, b = 0.1; else, b = 0.2; end
        if abs(max(ay) - (b + 0.03)) > 1e-3 || abs(min(ay) - (b - 0.03)) > 1e-3, okTarget = false; msg = [msg ' small:' L0]; end %#ok<AGROW>
    elseif strcmp(L0, 'mu_drop')
        if max(abs(ay - 0.3)) > 1e-6 || abs(mean(mu(S.t(in) > t0(j) + 0.01)) - 0.6) > 1e-9, okTarget = false; msg = [msg ' mu_drop']; end
    elseif strcmp(L0, 'mu_rise')
        if max(abs(ay - 0.3)) > 1e-6 || abs(mean(mu(S.t(in) > t0(j) + 0.01)) - 0.8) > 1e-9, okTarget = false; msg = [msg ' mu_rise']; end
    end
    lim = ayMax(vk, mu);
    if max(ay ./ lim) > 0.98, okReach = false; msg = [msg ' reach:' L0]; end %#ok<AGROW>
end
[nTot, nBad] = check(nTot, nBad, 'a_y, v, mu inside each window equal the design', okTarget, msg);
[nTot, nBad] = check(nTot, nBad, 'every target a_y is below 98 % of the Plant limit (plant_limits.json)', okReach, msg);
[nTot, nBad] = check(nTot, nBad, 'a_y target never above 0.4 g, speed within 20-100 km/h', max(abs(S.ayTarget)) <= 0.4 + 1e-9 && min(S.v) * 3.6 >= 20 - 1e-6 && max(S.v) * 3.6 <= 100 + 1e-6, '');
[nTot, nBad] = check(nTot, nBad, 'speed is smooth (no step above 1 km/h per ms)', max(abs(diff(S.v))) * 3.6 < 1, '');
[nTot, nBad] = check(nTot, nBad, 'a_y target is smooth (no step above 0.01 g per ms)', max(abs(diff(S.ayTarget))) < 0.01, '');
[nTot, nBad] = check(nTot, nBad, 'mu has exactly two steps', nnz(abs(diff(S.mu)) > 0.05) <= 2, '');
[nTot, nBad] = check(nTot, nBad, 'theta1 has the sign of the a_y target', all(sign(S.theta1(abs(S.ayTarget) > 1e-6)) == sign(S.ayTarget(abs(S.ayTarget) > 1e-6))), '');

% margin of the assist limit at the static levels: T_a,max = T_a,req(a_y,lim) + F (data/ref.json), so the 0.4 g levels (a_y,lim = 0.4 g from 30 km/h)
% have a margin of exactly F; the lower levels have more. A check, not information only: the limit must exceed the demand at 0.4 g.
Tr = refJ.Ta_max.Ta_req_Nm(:)'; Tm = refJ.Ta_max.Ta_max_Nm(:)'; vb = refJ.Ta_max.v_kmh(:)';
marg = interp1(vb, Tm - Tr, [60 100]);
[nTot, nBad] = check(nTot, nBad, 'assist limit exceeds the demand at 0.4 g by the margin F in the 60 and 100 km/h blocks', all(abs(marg - refJ.Ta_max.F_Nm) < 1e-9) && refJ.Ta_max.F_Nm > 0, sprintf('%g %g', marg));
fprintf('  info  T_a,max(60) = %.3f, T_a,max(100) = %.3f N.m, margin at 0.4 g = %.2f N.m (%.0f %% / %.0f %% of the limit)\n', ...
    interp1(vb, Tm, 60), interp1(vb, Tm, 100), refJ.Ta_max.F_Nm, 100 * marg(1) / interp1(vb, Tm, 60), 100 * marg(2) / interp1(vb, Tm, 100));

%% B) scores on synthetic signals
fprintf('B) scores on synthetic signals\n');
rng(1);
n = numel(t);
L.t = t;
L.T_d_ref = 1.5 + 0.5 * sin(2*pi*0.05*t);                 % positive, known
e = 0.02 * sin(2*pi*3*t);                                  % base error: zero mean over whole periods is not required, window means are computed
% give each window a distinct offset so that the answers differ by window
for j = 1:nW
    in = t >= t0(j) & t <= t1(j);
    e(in) = e(in) + 0.01 * j;
end
L.e_T = e; L.T_s = L.T_d_ref + e;
L.T_a = 3 * sin(2*pi*0.5*t) + 0.2 * sin(2*pi*20*t);
L.T_a_cmd = 1.1 * L.T_a + 0.05 * sin(2*pi*50*t);
% reverse assist on a known stretch: |T_s| >= 0.5 and T_a against T_s for 1500 scored samples
iRev = find(t >= 10, 1):find(t >= 10, 1) + 1499;
L.T_s(iRev) = 1.0; L.T_a(iRev) = -0.5; L.e_T = L.T_s - L.T_d_ref;
m = tk_score(L, S);

% reference by plain loops
e = L.e_T; dref = L.T_d_ref;
grpPre = {'static', 'sine', 'small', 'mu'}; Rg = zeros(1, 4);
for g = 1:4
    s2 = 0; sa = 0; c = 0;
    for j = 1:nW
        if startsWith(lab{j}, grpPre{g})
            for k = 1:n
                if t(k) >= t0(j) && t(k) <= t1(j), s2 = s2 + e(k)^2; sa = sa + abs(dref(k)); c = c + 1; end
            end
        end
    end
    Rg(g) = 100 * sqrt(s2 / c) / (sa / c);
end
[nTot, nBad] = check(nTot, nBad, 'R group errors (static, dyn, small, mu)', max(abs([m.Rg.static m.Rg.dyn m.Rg.small m.Rg.mu] - Rg)) < 1e-9, sprintf('%g vs %g', m.Rg.static, Rg(1)));
[nTot, nBad] = check(nTot, nBad, 'R = equal-weight mean of the four groups', abs(m.R - mean(Rg)) < 1e-9, '');
% equal weights: doubling the error of one group changes R by exactly Rg_g / 4
L2 = L; scale = 2;
for j = find(startsWith(lab, 'small')), in = t >= t0(j) & t <= t1(j); L2.e_T(in) = scale * L.e_T(in); L2.T_s(in) = L2.T_d_ref(in) + L2.e_T(in); end
m2 = tk_score(L2, S);
[nTot, nBad] = check(nTot, nBad, 'doubling the small-group error adds Rg_small / 4 to R', abs((m2.R - m.R) - Rg(3) / 4) < 1e-9, sprintf('%g vs %g', m2.R - m.R, Rg(3) / 4));
% e_rel per static window, signed
js = find(startsWith(lab, 'static')); er = zeros(1, numel(js));
for q = 1:numel(js)
    in = t >= t0(js(q)) & t <= t1(js(q));
    er(q) = 100 * mean(e(in)) / mean(abs(dref(in)));
end
[nTot, nBad] = check(nTot, nBad, 'e_rel per static window, signed, in the order of the labels', max(abs(m.erelSigned - er)) < 1e-9 && isequal(m.erelLabel, lab(js)), '');
[nTot, nBad] = check(nTot, nBad, 'e_rel = largest absolute window value', abs(m.erel - max(abs(er))) < 1e-9, '');
% reverse assist
w = t >= 2; nReal = 0;
for k = 1:n, if w(k) && abs(L.T_s(k)) >= 0.5 && L.T_a(k) * L.T_s(k) < 0, nReal = nReal + 1; end, end
[nTot, nBad] = check(nTot, nBad, 'reverse assist fraction', abs(m.rev - nReal / nnz(w)) < 1e-12 && nReal >= 1500, sprintf('%g vs %g', m.rev, nReal / nnz(w)));
% S, TV, maxTa
a = dt / (1 / (2*pi*5) + dt); lp = 0; s2 = 0; sc2 = 0; lc = 0; c = 0; tv = 0; mx = 0;
for k = 1:n
    lp = lp + a * (L.T_a(k) - lp); lc = lc + a * (L.T_a_cmd(k) - lc);
    if w(k)
        s2 = s2 + (L.T_a(k) - lp)^2; sc2 = sc2 + (L.T_a_cmd(k) - lc)^2; c = c + 1; mx = max(mx, abs(L.T_a(k)));
        if k > 1 && w(k-1), tv = tv + abs(L.T_a(k) - L.T_a(k-1)); end
    end
end
[nTot, nBad] = check(nTot, nBad, 'S, Scmd (RMS of T_a high-passed at 5 Hz, from 2 s)', abs(m.S - sqrt(s2 / c)) < 1e-9 && abs(m.Scmd - sqrt(sc2 / c)) < 1e-9, sprintf('%g vs %g', m.S, sqrt(s2 / c)));
[nTot, nBad] = check(nTot, nBad, 'TV = total variation per second over the scored time', abs(m.TV - tv / (t(end) - 2)) < 1e-9, sprintf('%g vs %g', m.TV, tv / (t(end) - 2)));
[nTot, nBad] = check(nTot, nBad, 'maxTa', abs(m.maxTa - mx) < 1e-12, '');

% per-block scores
sb = tk_block_scores(L, S, [20 60 100]);
okB = true;
for b = 1:3
    T0 = blk(b).t0; T1 = blk(b).t1; Rb = [];
    for g = 1:4
        s2 = 0; sa = 0; c = 0;
        for j = 1:nW
            if startsWith(lab{j}, grpPre{g}) && t0(j) >= T0 && t1(j) <= T1
                for k = 1:n, if t(k) >= t0(j) && t(k) <= t1(j), s2 = s2 + e(k)^2; sa = sa + abs(dref(k)); c = c + 1; end, end
            end
        end
        if c > 0, Rb(end+1) = 100 * sqrt(s2 / c) / (sa / c); end %#ok<AGROW>
    end
    erb = [];
    for j = 1:nW
        if startsWith(lab{j}, 'static') && t0(j) >= T0 && t1(j) <= T1
            in = t >= t0(j) & t <= t1(j); erb(end+1) = 100 * abs(mean(e(in))) / mean(abs(dref(in))); end %#ok<AGROW>
    end
    if abs(sb.R(b) - mean(Rb)) > 1e-9 || abs(sb.erel(b) - max(erb)) > 1e-9, okB = false; end
end
[nTot, nBad] = check(nTot, nBad, 'block scores R (groups present in the block) and e_rel', okB, '');
jm = find(startsWith(lab, 'mu'));
[nTot, nBad] = check(nTot, nBad, 'the mu windows lie in the 60 km/h block only', all(t0(jm) >= blk(2).t0 & t1(jm) <= blk(2).t1), '');

ok = nBad == 0;
fprintf('test_tk: %d checks, %d failed -> %s\n', nTot, nBad, ternary(ok, 'PASS', 'FAIL'));
end

function [nTot, nBad] = check(nTot, nBad, name, cond, info)
    nTot = nTot + 1;
    if ~cond, nBad = nBad + 1; fprintf('  FAIL  %s  %s\n', name, info); else, fprintf('  ok    %s\n', name); end
end

function lv = parseLevel(label)
% 'static_v60_apos0p20g' -> 0.20
    tok = regexp(label, 'a(pos|neg)(\d)p(\d+)g', 'tokens', 'once');
    lv = str2double([tok{2} '.' tok{3}]); if strcmp(tok{1}, 'neg'), lv = -lv; end
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
