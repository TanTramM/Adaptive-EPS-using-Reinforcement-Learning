function ok = test_calib()
%TEST_CALIB Test of the design case CALIB v2 (make_cases('CALIB')) and of its scoring (calib_score.m, calib_block_scores.m). No controller, no Simulink model.
%
%   A) the case itself: grid, length, blocks, windows (counts, order, no overlap), targets of a_y, v, mu inside every window, continuity of the sine start,
%      reachability by the Plant, smoothness, whole-second marks;
%   B) the scores on SYNTHETIC logged signals whose answers are known: R by group (geometric mean of static, dyn, mu with the 1 % floor), e_rel per window
%      with sign, reverse assist, S, TV, maxTa, and the per-block scores; every reference value is computed here with plain loops, not with the code under test.
%   Self-contained: reads only data/plant_limits.json for the reachability check.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths; addpath(scriptDir);

S = make_cases('CALIB');
nTot = 0; nBad = 0;
speeds = 20:10:100;

%% A) the case
fprintf('A) case CALIB v2\n');
t = S.t; dt = t(2) - t(1);
[nTot, nBad] = check(nTot, nBad, '1 ms grid, start at 0', abs(dt - 0.001) < 1e-12 && t(1) == 0 && all(abs(diff(t) - dt) < 1e-9), '');
[nTot, nBad] = check(nTot, nBad, 'length 140 s (round number)', abs(t(end) - 140) < 1e-9, sprintf('end %.3f', t(end)));
lab = {S.win.label}; nW = numel(S.win);
nStatic = nnz(startsWith(lab, 'static')); nTrans = nnz(startsWith(lab, 'trans')); nSine = nnz(startsWith(lab, 'sine')); nMu = nnz(startsWith(lab, 'mu'));
[nTot, nBad] = check(nTot, nBad, '68 windows: 26 static, 26 trans, 14 sine (40-100 km/h), 2 mu', nW == 68 && nStatic == 26 && nTrans == 26 && nSine == 14 && nMu == 2, sprintf('%d: %d %d %d %d', nW, nStatic, nTrans, nSine, nMu));
[nTot, nBad] = check(nTot, nBad, 'no window of the old case (ext_*, small_*)', ~any(startsWith(lab, 'ext')) && ~any(startsWith(lab, 'small')), '');
blk = S.blk;
[nTot, nBad] = check(nTot, nBad, 'nine blocks 20, 30, ..., 100 km/h tiling from 2 s', numel(blk) == 9 && isequal([blk.speed], speeds) && abs(blk(1).t0 - 2) < 1e-12 && ...
      all(abs([blk(1:end-1).t1] - [blk(2:end).t0]) < 1e-12) && blk(end).t1 <= t(end) - 2, '');
t0 = [S.win.t0]; t1 = [S.win.t1];
[nTot, nBad] = check(nTot, nBad, 'windows start after the 2 s that are never scored', all(t0 >= 2), sprintf('min %.2f', min(t0)));
[nTot, nBad] = check(nTot, nBad, 'windows have positive length and sit inside the case', all(t1 > t0) && all(t1 <= t(end)), '');
[nTot, nBad] = check(nTot, nBad, 'all window marks are whole seconds', all(abs(t0 - round(t0)) < 1e-9) && all(abs(t1 - round(t1)) < 1e-9), '');
inside = false(1, nW);
for j = 1:nW, inside(j) = any(t0(j) >= [blk.t0] - 1e-9 & t1(j) <= [blk.t1] + 1e-9); end
[nTot, nBad] = check(nTot, nBad, 'every window lies inside one block', all(inside), '');
ord = sortrows([t0(:) t1(:)]);
[nTot, nBad] = check(nTot, nBad, 'no two windows overlap', all(ord(2:end, 1) >= ord(1:end-1, 2) - 1e-12), '');
% each speed has static + trans for every level and the two sine windows; mu only at 60 km/h
okSet = true;
for b = 1:9
    v = speeds(b);
    ns = nnz(startsWith(lab, sprintf('static_v%d_', v))); nt = nnz(startsWith(lab, sprintf('trans_v%d_', v)));
    nl = 3 - (v == 20);
    hasSine = any(strcmp(lab, sprintf('sine_v%d_f0p5', v))) && any(strcmp(lab, sprintf('sine_v%d_f1', v)));
    if ns ~= nl || nt ~= nl || hasSine ~= (v >= 40), okSet = false; end
end
[nTot, nBad] = check(nTot, nBad, 'per speed: static and trans per level (2 at 20 km/h, else 3), sine at 0.5 and 1 Hz from 40 km/h only', okSet, '');

% targets inside the windows
PL = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
ayMax = @(vk, mu) interp2(PL.a_y.mu(:)', PL.a_y.v_kmh(:), PL.a_y.table, mu, vk, 'linear');
okTarget = true; msg = '';
for j = 1:nW
    in = t >= t0(j) & t <= t1(j);
    L0 = lab{j};
    vk = S.v(in) * 3.6; mu = S.mu(in); ay = S.ayTarget(in);
    kb = find(t0(j) >= [blk.t0] - 1e-9 & t1(j) <= [blk.t1] + 1e-9, 1);
    vb = blk(kb).speed;
    if startsWith(L0, 'static') || startsWith(L0, 'trans')
        if max(abs(vk - vb)) > 1e-6, okTarget = false; msg = [msg ' v:' L0]; end %#ok<AGROW>
    end
    if startsWith(L0, 'static')
        lv = parseLevel(L0);
        if max(abs(ay - lv)) > 1e-6 || max(abs(mu - 0.8)) > 1e-9, okTarget = false; msg = [msg ' static:' L0]; end %#ok<AGROW>
    elseif startsWith(L0, 'sine')
        top = 0.3 - 0.12 * (vb == 20);                       % amplitude of the 0.5 Hz tone = top level of the staircase (0.18 g at 20 km/h)
        if endsWith(L0, 'f0p5'), A = top; else, A = top / 2; end
        if abs(max(abs(ay)) - A) > 2e-3 || max(abs(mu - 0.8)) > 1e-9, okTarget = false; msg = [msg ' sine:' L0]; end %#ok<AGROW>
        if abs(vk(end) - vk(1)) < 0.1 && vb < 100, okTarget = false; msg = [msg ' speed not rising:' L0]; end %#ok<AGROW>
    elseif strcmp(L0, 'mu_drop')
        if max(abs(ay - 0.3)) > 1e-6 || abs(mean(mu(S.t(in) > t0(j) + 0.01)) - 0.35) > 1e-9, okTarget = false; msg = [msg ' mu_drop']; end
    elseif strcmp(L0, 'mu_rise')
        if max(abs(ay - 0.3)) > 1e-6 || abs(mean(mu(S.t(in) > t0(j) + 0.01)) - 0.8) > 1e-9, okTarget = false; msg = [msg ' mu_rise']; end
    end
end
[nTot, nBad] = check(nTot, nBad, 'a_y, v, mu inside each window equal the design', okTarget, msg);
% sine segments: cosine starts at the top level (continuity), tones end at 0 crossings
okCont = true;
for b = 3:9
    jj = find(strcmp(lab, sprintf('sine_v%d_f0p5', speeds(b))), 1);
    k0 = round(t0(jj) / dt) + 1;                              % first sample of the cosine
    top = 0.3 - 0.12 * (speeds(b) == 20);
    if abs(S.ayTarget(k0) - top) > 2e-3 || abs(S.ayTarget(k0 - 1) - top) > 2e-3, okCont = false; end
    kS = k0 + 6000;                                           % end of the 6 s sine segment: a_y back at 0
    if abs(S.ayTarget(kS)) > 2e-3, okCont = false; end
    if any(abs(S.ayTarget(k0 + (0:2500:5000)) ) > top + 1e-3), okCont = false; end
end
[nTot, nBad] = check(nTot, nBad, 'the cosine starts at the top level of the staircase and each sine segment ends at a_y = 0', okCont, '');
lim = ayMax(S.v * 3.6, S.mu);
okReach = max(abs(S.ayTarget) ./ lim) <= 0.90 + 1e-9;
[nTot, nBad] = check(nTot, nBad, 'every target a_y is below 90 % of the Plant limit (plant_limits.json)', okReach, sprintf('%.3f', max(abs(S.ayTarget) ./ lim)));
[nTot, nBad] = check(nTot, nBad, 'a_y target never above 0.3 g, speed within 20-100 km/h', max(abs(S.ayTarget)) <= 0.3 + 1e-9 && min(S.v) * 3.6 >= 20 - 1e-6 && max(S.v) * 3.6 <= 100 + 1e-6, '');
[nTot, nBad] = check(nTot, nBad, 'speed rises 10 km/h per block in <= 1.5 m/s^2 (peak) and never falls', max(abs(diff(S.v))) / dt <= 1.5 && all(diff(S.v) >= -1e-12), sprintf('%.3f', max(abs(diff(S.v))) / dt));
[nTot, nBad] = check(nTot, nBad, 'a_y target is smooth (no step above 0.002 g per ms, peak rate below 1 g/s)', max(abs(diff(S.ayTarget))) < 0.002 && max(abs(diff(S.ayTarget))) / dt < 1.0, '');
[nTot, nBad] = check(nTot, nBad, 'mu has exactly two steps', nnz(abs(diff(S.mu)) > 0.05) == 2, '');
[nTot, nBad] = check(nTot, nBad, 'theta1 has the sign of the a_y target', all(sign(S.theta1(abs(S.ayTarget) > 1e-6)) == sign(S.ayTarget(abs(S.ayTarget) > 1e-6))), '');
[nTot, nBad] = check(nTot, nBad, 'a_y reaches both signs in every sine block (40-100 km/h)', all(arrayfun(@(b) any(S.ayTarget(round(blk(b).t0/dt)+1:round(blk(b).t1/dt)+1) < -0.05), 3:9)), '');

%% B) scores on synthetic signals
fprintf('B) scores on synthetic signals\n');
rng(1);
n = numel(t);
L.t = t;
L.T_d_ref = 1.5 + 0.5 * sin(2*pi*0.05*t);                 % positive, known
e = 0.02 * sin(2*pi*3*t);
for j = 1:nW
    in = t >= t0(j) & t <= t1(j);
    e(in) = e(in) + 0.01 * j;
end
L.e_T = e; L.T_s = L.T_d_ref + e;
L.T_a = 3 * sin(2*pi*0.5*t) + 0.2 * sin(2*pi*20*t);
L.T_a_cmd = 1.1 * L.T_a + 0.05 * sin(2*pi*50*t);
iRev = find(t >= 10, 1):find(t >= 10, 1) + 1499;
L.T_s(iRev) = 1.0; L.T_a(iRev) = -0.5; L.e_T = L.T_s - L.T_d_ref;
m = calib_score(L, S);

e = L.e_T; dref = L.T_d_ref;
grpPre = {{'static'}, {'trans', 'sine'}, {'mu'}}; Rg = zeros(1, 3);
for g = 1:3
    s2 = 0; sa = 0; c = 0;
    jg = find(cellfun(@(l) any(cellfun(@(p) startsWith(l, p), grpPre{g})), lab));
    for k = 1:n                                               % a sample that lies in two windows of the group (end of one block = start of the next) counts once
        if any(t(k) >= t0(jg) & t(k) <= t1(jg)), s2 = s2 + e(k)^2; sa = sa + abs(dref(k)); c = c + 1; end
    end
    Rg(g) = 100 * sqrt(s2 / c) / (sa / c);
end
[nTot, nBad] = check(nTot, nBad, 'R group errors (static, dyn, mu)', max(abs([m.Rg.static m.Rg.dyn m.Rg.mu] - Rg)) < 1e-9, sprintf('%g vs %g', m.Rg.static, Rg(1)));
[nTot, nBad] = check(nTot, nBad, 'R = geometric mean of the three groups (floor 1 %)', abs(m.R - (prod(max(Rg, 1)))^(1/3)) < 1e-9, sprintf('%g vs %g', m.R, (prod(max(Rg, 1)))^(1/3)));
% equal weights in the logarithm: doubling the error inside the mu windows doubles the mu-group error (the two boundary samples that these windows share with
% neighbouring windows are not scaled, hence the tolerance) and R follows the geometric mean of the changed groups
L2 = L;
for j = find(startsWith(lab, 'mu')), in = t >= t0(j) & t <= t1(j); L2.e_T(in) = 2 * L.e_T(in); L2.T_s(in) = L2.T_d_ref(in) + L2.e_T(in); end
m2 = calib_score(L2, S);
[nTot, nBad] = check(nTot, nBad, 'doubling the mu-window error doubles the mu group and R is the geometric mean of the changed groups', ...
    abs(m2.Rg.mu / m.Rg.mu - 2) < 2e-3 && abs(m2.R - prod(max([m2.Rg.static m2.Rg.dyn m2.Rg.mu], 1))^(1/3)) < 1e-9 && min(Rg) > 1, sprintf('%g', m2.Rg.mu / m.Rg.mu));
% floor: a group far below 1 % counts as 1 %
L3 = L;
for j = find(startsWith(lab, 'static')), in = t >= t0(j) & t <= t1(j); L3.e_T(in) = 1e-6 * L.e_T(in); L3.T_s(in) = L3.T_d_ref(in) + L3.e_T(in); end
m3 = calib_score(L3, S);
g3 = [m3.Rg.static m3.Rg.dyn m3.Rg.mu];
[nTot, nBad] = check(nTot, nBad, 'a group error below 1 % counts as 1 % (floor)', g3(1) < 1 && abs(m3.R - prod(max(g3, 1))^(1/3)) < 1e-9 && m3.R > prod(g3)^(1/3), sprintf('%g', m3.R));
% e_rel per static window, signed
js = find(startsWith(lab, 'static')); er = zeros(1, numel(js));
for q = 1:numel(js)
    in = t >= t0(js(q)) & t <= t1(js(q));
    er(q) = 100 * mean(e(in)) / mean(abs(dref(in)));
end
[nTot, nBad] = check(nTot, nBad, 'e_rel per static window, signed, in the order of the labels', max(abs(m.erelSigned - er)) < 1e-9 && isequal(m.erelLabel, lab(js)), '');
[nTot, nBad] = check(nTot, nBad, 'e_rel = largest absolute window value', abs(m.erel - max(abs(er))) < 1e-9, '');
[nTot, nBad] = check(nTot, nBad, 'no extreme-region windows (eext fields empty)', isempty(m.eextLabel) && isempty(m.eextSigned), '');
w = t >= 2; nReal = 0;
for k = 1:n, if w(k) && abs(L.T_s(k)) >= 0.5 && L.T_a(k) * L.T_s(k) < 0, nReal = nReal + 1; end, end
[nTot, nBad] = check(nTot, nBad, 'reverse assist fraction', abs(m.rev - nReal / nnz(w)) < 1e-12 && nReal >= 1500, sprintf('%g vs %g', m.rev, nReal / nnz(w)));
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
sb = calib_block_scores(L, S, speeds);
okB = true;
for b = 1:9
    T0 = blk(b).t0; T1 = blk(b).t1; Rb = [];
    for g = 1:3
        s2 = 0; sa = 0; c = 0;
        jg = find(cellfun(@(l) any(cellfun(@(p) startsWith(l, p), grpPre{g})), lab) & t0 >= T0 - 1e-9 & t1 <= T1 + 1e-9);
        if ~isempty(jg)
            for k = 1:n, if any(t(k) >= t0(jg) & t(k) <= t1(jg)), s2 = s2 + e(k)^2; sa = sa + abs(dref(k)); c = c + 1; end, end
        end
        if c > 0, Rb(end+1) = 100 * sqrt(s2 / c) / (sa / c); end %#ok<AGROW>
    end
    erb = [];
    for j = 1:nW
        if startsWith(lab{j}, 'static') && t0(j) >= T0 - 1e-9 && t1(j) <= T1 + 1e-9
            in = t >= t0(j) & t <= t1(j); erb(end+1) = 100 * abs(mean(e(in))) / mean(abs(dref(in))); end %#ok<AGROW>
    end
    if abs(sb.R(b) - prod(max(Rb, 1))^(1/numel(Rb))) > 1e-9 || abs(sb.erel(b) - max(erb)) > 1e-9, okB = false; end
end
[nTot, nBad] = check(nTot, nBad, 'block scores R (geometric mean of the groups present in the block) and e_rel, nine blocks', okB, '');
jm = find(startsWith(lab, 'mu'));
[nTot, nBad] = check(nTot, nBad, 'the mu windows lie in the 60 km/h block only', all(t0(jm) >= blk(5).t0 & t1(jm) <= blk(5).t1), '');

ok = nBad == 0;
fprintf('test_calib: %d checks, %d failed -> %s\n', nTot, nBad, ternary(ok, 'PASS', 'FAIL'));
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
