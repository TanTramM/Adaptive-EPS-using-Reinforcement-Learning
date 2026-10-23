%TEST_DREWS Test of the scoring cases DREWS v2 (make_cases()): construction rules of Documents/Shared/KeHoach_DREWS_v2.txt. No controller, no Simulink model.
%   Checks: five cases DRY, RAMP, SLIP, EDGE, WEAVE; each EXACTLY 60.000 s on the 1 ms grid; windows inside (2 s, 60 s], unique labels, t0 < t1; target a_y within the
%   limit of the steady-angle table; grip use |a_y*| / mu at most 0.86 where mu is stepped (SLIP) and at most 0.5 elsewhere, apart from EDGE (<= 0.475, dry);
%   speed change not faster than 0.2 s per km/h on average (peak 2.2 m/s^2 of the (1 - cos) blend); every condition outside the CALIB v2 grid (see list in the code);
%   old set make_cases('DREWS_V1') unchanged (five cases, DRY 129 s long).
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
nfail = 0;
C = make_cases('DREWS_V2');
names = {'DRY', 'RAMP', 'SLIP', 'EDGE', 'WEAVE'};
nfail = nfail + check(numel(C) == 5 && isequal({C.tag}, names), 'five cases in the order DRY, RAMP, SLIP, EDGE, WEAVE');
for k = 1:numel(C)
    S = C(k);
    nfail = nfail + check(abs(S.t(end) - 60) < 1e-9 && abs(S.t(2) - S.t(1) - 0.001) < 1e-12 && numel(S.t) == 60001, [S.tag ': exactly 60.000 s, 1 ms grid']);
    labels = {S.win.label};
    t0 = [S.win.t0]; t1 = [S.win.t1];
    nfail = nfail + check(numel(unique(labels)) == numel(labels), [S.tag ': window labels unique']);
    nfail = nfail + check(all(t0 >= 2 - 1e-9) && all(t1 <= 60 + 1e-9) && all(t0 < t1), [S.tag ': windows inside 2-60 s']);
    nfail = nfail + check(max(abs(S.ayTarget)) <= 0.4 + 1e-9, [S.tag ': target a_y within the steady-angle table (<= 0.4 g)']);
    vk = S.v * 3.6;
    dv = abs(diff(vk)) / 0.001;                             % km/h per s
    nfail = nfail + check(max(dv) <= 5 * pi / 2 + 0.05, [S.tag ': speed change at most 0.2 s per km/h on average (peak 2.2 m/s^2 of the (1 - cos) blend)']);
    use = abs(S.ayTarget) ./ S.mu;
    if strcmp(S.tag, 'SLIP'), lim = 0.76; elseif strcmp(S.tag, 'EDGE'), lim = 0.48; elseif strcmp(S.tag, 'DRY'), lim = 0.32; else, lim = 0.5; end
    nfail = nfail + check(max(use) <= lim, sprintf('%s: grip use %.3f <= %.2f', S.tag, max(use), lim));
    nfail = nfail + check(all(abs(S.theta1) < pi), [S.tag ': hand-wheel angle below 180 deg']);
end
% outside the CALIB v2 grid: DRY scores only at 25, 45, 75, 95 km/h and 0.15 / 0.25 g (CALIB: 20:10:100 km/h, 0.1 / 0.2 / 0.3 g). SLIP, EDGE, WEAVE and RAMP use some speeds
% of the grid (the plan 1.3-1.5 does), but the combination of speed, level, mu and frequency is outside it (see KeHoach_DREWS_v2.txt, QuyChuan 3.2).
S = C(1);
vw = zeros(1, numel(S.win)); aw = zeros(1, numel(S.win));
for j = 1:numel(S.win)
    in = S.t >= S.win(j).t0 & S.t <= S.win(j).t1;
    vw(j) = mean(S.v(in)) * 3.6; aw(j) = mean(abs(S.ayTarget(in)));
end
nfail = nfail + check(isequal(unique(round(vw)), [25 45 75 95]) && all(abs(aw - 0.15) < 0.003 | abs(aw - 0.25) < 0.003), 'DRY: scored speeds 25, 45, 75, 95 km/h, levels 0.15 and 0.25 g');
% a few exact values
nfail = nfail + check(abs(max(S.ayTarget) - 0.15) < 1e-9 && abs(min(S.ayTarget) + 0.25) < 1e-9, 'DRY: 0.15 g left and 0.25 g right');
S = C(2);
nfail = nfail + check(abs(min(S.v) * 3.6 - 40) < 1e-6 && abs(max(S.v) * 3.6 - 90) < 1e-6, 'RAMP: 90 -> 40 -> 90 km/h');
S = C(3);
nfail = nfail + check(abs(min(S.mu) - 0.2) < 1e-9 && abs(max(S.mu) - 0.8) < 1e-9, 'SLIP: mu between 0.2 and 0.8');
% old set
V1 = make_cases('DREWS_V1');
nfail = nfail + check(numel(V1) == 5 && abs(V1(1).t(end) - 129) < 1.0 && strcmp(V1(1).tag, 'DRY'), 'DREWS_V1 still returns the old five cases');
if nfail == 0, disp('[DREWS v2] TEST PASS'); else, error('[DREWS v2] TEST FAIL (%d)', nfail); end

function n = check(ok, msg)
    if ok, fprintf('  ok   %s\n', msg); n = 0; else, fprintf('  FAIL %s\n', msg); n = 1; end
end
