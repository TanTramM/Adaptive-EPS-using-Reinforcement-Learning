function C = make_cases(which)
%MAKE_CASES The scenario set shared by EVERY controller (Map, PI, PID, SMC, ISMC, RL, ...).
%
%   C = make_cases()          the scoring cases DREWS v3 [DRY, RAMP, SLIP, EDGE, WEAVE], each EXACTLY 100.000 s (2026-10-23, Documents/Shared/KeHoach_DREWS_v3.txt;
%                             struct array, run by run_cases.m). Every condition lies outside the grid of CALIB v2 (speeds 25, 35, 45, 55, 65, 75, 85, 95 km/h ...)
%   C = make_cases('DREWS_V2') the cases DREWS v2 (five cases of 60 s, 2026-10-22, locked in Documents/Shared/DREWS_v2_LOCKED.txt), kept to reproduce Cases_v2/
%   C = make_cases('DREWS_V1') the old five cases DREWS v1 (DRY 129 s, RAMP 308.6 s, SLIP 63 s, WEAVE 61 s, EDGE), kept to reproduce the old results (Cases/);
%                             the descriptions below are those of v1
%   C = make_cases('CALIB')   the calibration case CALIB v2 only (150 s, 2026-10-17; not a scoring case; every controller picks its parameters on it,
%                             Documents/Shared/QuyChuan.txt part 3; run by calib_run.m; the old 117 s case is CALIB v1, see QuyChuan change log)
%
%   DRY, SLIP, WEAVE are built from the segments of the old six cases TC1-TC6 (same speeds, a_y levels and mu values; nothing new).
%   EDGE (2026-10-11, the extreme region above 0.3 g) and RAMP (2026-10-11, speed changing while cornering) are REPORT ONLY: not a gate, not a score
%   in the pick of parameters. Short name of the set: DREWS = DRY, RAMP, SLIP, EDGE, WEAVE.
%   Each case asks ONE question; a case made of several scenes joins them with a straight gap (a_y -> 0 within 1.5 s, then speed and mu changed on
%   the straight; the speed change takes 0.2 s per km/h, at least 4 s, so the longitudinal acceleration stays within about 2.2 m/s^2).
%
%   DRY    mu = 0.8 constant. Steady cornering at 20, 40, 60, 80, 100 km/h, three a_y levels each, held 5 s (old TC1).
%          Question: on the dry road (the design condition of the conventional map) is the steady torque error near zero?
%          Main metric: max |e_rel| over the windows (QuyChuan 4.4).
%   RAMP   speed ramp while cornering (like braking or accelerating in a bend), dry road (mu 0.8), report only. Three scenes, a_y held at
%          lo 0.15 g, mid 0.225 g, hi 0.275 g (direction left, right, left): 100 km/h, a_y up in 4 s, 4 s hold, then speed down to v_min and back to
%          100 km/h at a mean 0.5 m/s^2 (the (1 - cos) blend gives a peak 0.79 m/s^2), then 4 s hold. v_min = lowest speed at which the level stays
%          below 98 % of the Plant limit (plant_limits.json, mu 0.8), rounded up to 0.5 km/h. Windows <scene>_dn and <scene>_up = the whole down and up ramp.
%          Question: with the speed changing, does the torque error stay small and the same in both directions (no friction hysteresis)?
%          Metrics: signed e_rel per window (dn and up reported separately, they do not cancel for a nonlinear controller), RMS e_T, S, TV.
%   SLIP   mu changes while cornering. Three scenes, in this order:
%            pud   80 km/h, one lane-change cycle 0.2 g, 0.4 Hz, a 0.4 s puddle (mu 0.2) at the peak (old TC4)
%            up    60 km/h, 0.15 g, mu 0.3 -> 0.8 at 5 s              (old TC6: road dries up)
%            down  100 km/h, 0.3 g, mu 0.8 -> 0.3 at 5 s               (old TC3: hard corner, road turns slippery; 0.35 g before 2026-10-11)
%          'down' stays LAST (the order of the 0.35 g version, where the target was above the new grip limit and the open-loop driver could not
%          recover; at 0.3 g the car stays stable, Map: a_y 0.27 g after the step, but the order was not changed).
%          Question: does the assist stay right (no over-assist, no overshoot) when grip changes? Main metric: signed e_rel after the change.
%   WEAVE  continuous steering at constant mu per scene, speed rising 50 -> 80 -> 100 km/h:
%            slal  50 km/h, mu 0.8, sine 0.15 g 0.25 Hz               (slalom, from old TC2)
%            lane  80 km/h, mu 0.3, one cycle 0.1 g 0.25 Hz           (lane change on slippery road, from old TC2)
%            ice   100 km/h, mu 0.2, sine 0.15 g 0.3 Hz, 20 s         (old TC5)
%          Question: does the controller track while steering and stay quiet? Main metric: RMS e_T in the windows, with S and TV.
%
%   EDGE   extreme region above 0.3 g on the dry road (mu 0.8), report only. Scenes in this order:
%            v40, v60, v100  hold 0.35 g then 0.4 g, 5 s each, window = last 1 s of each hold (as DRY); the direction alternates (left, right, left)
%            sine            60 km/h, base 0.2 g, amplitude 0.2 g (0 to 0.4 g), 0.25 Hz, 3 cycles; window = the 3 cycles without the first 0.5 s
%          Question: how do the controllers behave where the design table and the assist limit are tightest? Metrics: signed e_rel per window,
%          RMS e_T, S, TV, peak |T_a| relative to T_a,max(v), reverse assist (run_cases.m).
%
%   The driver is a steering-angle source (Documents/Thesis/plant.txt section 1.4). The angle is controller INDEPENDENT:
%   theta1(t) = sgn(a*) * theta1_ss(v(t), |a*(t)|), where a*(t) is the target lateral acceleration and theta1_ss is the angle that gives
%   a* in steady state on the dry road with T_s = T_d,ref (ideal assist): theta1_ss = n_st*delta_f + T_d,ref/K. When mu changes the
%   driver keeps the same angle (he does not know mu). All changes are smooth ramps (1 - cos) except the friction steps.
%
%   Fields of C(k): tag, name, t [s] (1 ms grid), theta1 [rad], v [m/s], mu [-], ayTarget [g],
%   win (struct array: label, t0, t1) = windows where the mean e_T is reported. CALIB also has blk (speed blocks: speed, t0, t1).
%   Window labels follow the naming rule of Tracking/CLAUDE.md (lower case, short; CALIB v2 uses static_*, trans_*, sine_*, mu_drop, mu_rise).

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
P   = loadPlant(modelDir);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
thTab = steadyAngleTable(P, ref);

if nargin > 0 && strcmp(which, 'CALIB')
    C = buildCALIB(thTab);
    return;
end
if nargin > 0 && strcmp(which, 'DREWS_V1')
    C = [buildDRY(thTab), buildRAMP(thTab, modelDir), buildSLIP(thTab), buildWEAVE(thTab), buildEDGE(thTab)];
    return;
end
if nargin > 0 && strcmp(which, 'DREWS_V2')
    C = [buildDRY2(thTab), buildRAMP2(thTab), buildSLIP2(thTab), buildEDGE2(thTab), buildWEAVE2(thTab)];
    for k = 1:numel(C)
        assert(abs(C(k).t(end) - 60) < 1e-9, 'DREWS v2: case %s is %.3f s, not 60 s', C(k).tag, C(k).t(end));
    end
    return;
end
if nargin > 0 && strcmp(which, 'SSW')
    C = [buildSTEADY(thTab), buildSLIPS(thTab), buildWEAVES(thTab)];
    for k = 1:numel(C)
        assert(abs(C(k).t(end) - 100) < 1e-9, 'SSW: case %s is %.3f s, not 100 s', C(k).tag, C(k).t(end));
    end
    return;
end
if nargin > 0 && strcmp(which, 'SLIP_V4')
    C = buildSLIP4(thTab);
    assert(abs(C.t(end) - 100) < 1e-9, 'SLIP v4: case is %.3f s, not 100 s', C.t(end));
    return;
end
C = [buildDRY3(thTab), buildRAMP3(thTab), buildSLIP3(thTab), buildEDGE3(thTab), buildWEAVE3(thTab)];
for k = 1:numel(C)
    assert(abs(C(k).t(end) - 100) < 1e-9, 'DREWS v3: case %s is %.3f s, not 100 s', C(k).tag, C(k).t(end));
end
end

%% ===================== DRY: steady cornering staircase on the dry road =============
function S = buildDRY(thTab)
    speeds = [20 40 60 80 100];
    levels = {[0.1 0.15 0.18], [0.1 0.2 0.3], [0.1 0.2 0.3], [0.1 0.2 0.3], [0.1 0.2 0.3]};
    kv = []; ka = []; win = struct('label', {}, 't0', {}, 't1', {});
    t0 = 0; sgn = 1;
    kv = [kv; 0, speeds(1)]; ka = [ka; 0, 0];
    for i = 1:numel(speeds)
        if i > 1                                        % change speed while driving straight
            kv = [kv; t0, speeds(i-1); t0 + 4, speeds(i)]; %#ok<AGROW>
            t0 = t0 + 4;
        end
        kv = [kv; t0, speeds(i)]; %#ok<AGROW>
        t0 = t0 + 2;                                    % straight
        ka = [ka; t0, 0]; %#ok<AGROW>
        for a = levels{i}
            ka = [ka; t0 + 1, sgn * a; t0 + 6, sgn * a]; %#ok<AGROW>
            win(end+1) = struct('label', dryLabel(speeds(i), a, sgn), 't0', t0 + 5, 't1', t0 + 6); %#ok<AGROW>
            t0 = t0 + 6;
        end
        ka = [ka; t0 + 1.5, 0]; %#ok<AGROW>
        t0 = t0 + 2;
        kv = [kv; t0, speeds(i)]; %#ok<AGROW>
        sgn = -sgn;
    end
    tEnd = t0 + 3;
    S = assemble('DRY', 'DRY: độ chính xác tĩnh trên đường khô', tEnd, kv, ka, [0 0.8; tEnd 0.8], [], thTab, win);
end

%% ===================== RAMP: speed ramp while cornering (report only) ================
function S = buildRAMP(thTab, modelDir)
    lev = [0.15 0.225 0.275]; names = {'lo', 'mid', 'hi'}; rate = 0.5;   % a_y levels [g], scene names, mean deceleration [m/s^2]
    PL = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
    lim = PL.a_y.table(:, end);                                % Plant limit at the highest mu column (0.8), one row per speed
    vg = PL.a_y.v_kmh(:);
    scenes = cell(1, numel(lev));
    for i = 1:numel(lev)
        vg_f = (20:0.1:100)';
        vmin = vg_f(find(interp1(vg, lim, vg_f, 'linear') >= lev(i) / 0.98, 1));
        vmin = ceil(vmin * 2) / 2;                              % up to 0.5 km/h
        T = (100 - vmin) / 3.6 / rate;                         % one way [s]
        t1 = 8; sg = 1 - 2 * mod(i - 1, 2);                    % left, right, left
        sc.tEnd = t1 + 2 * T + 4;
        sc.kv = [0 100; t1 100; t1 + T vmin; t1 + 2 * T 100; sc.tEnd 100];
        sc.ka = [0 0; 4 sg * lev(i); sc.tEnd sg * lev(i)];
        sc.kmu = [0 0.8; sc.tEnd 0.8]; sc.sines = zeros(0, 4);
        sc.win = struct('label', {[names{i} '_dn'], [names{i} '_up']}, 't0', {t1, t1 + T}, 't1', {t1 + T, t1 + 2 * T});
        scenes{i} = sc;
    end
    S = chain('RAMP', 'RAMP: đổi tốc độ khi đang cua', scenes, thTab);
end

%% ===================== SLIP: friction changes while cornering ==========================
function S = buildSLIP(thTab)
    % scene 'down' (old TC3): hard corner at 100 km/h, road turns slippery at 5 s
    d.tEnd = 20; d.kv = [0 100; 20 100]; d.ka = [0 0; 1 0.3; 20 0.3]; d.kmu = [0 0.8; 5 0.8; 5.001 0.3; 20 0.3]; d.sines = zeros(0, 4);
    d.win = struct('label', {'down_pre', 'down_post'}, 't0', {4, 18}, 't1', {5, 20});
    % scene 'pud' (old TC4): lane change at 80 km/h, 0.4 s puddle at the peak steering demand
    p.tEnd = 12; p.kv = [0 80; 12 80]; p.ka = [0 0; 12 0]; p.sines = [3 5.5 0.2 0.4];
    p.kmu = [0 0.8; 3.799 0.8; 3.8 0.2; 4.199 0.2; 4.2 0.8; 12 0.8];
    p.win = struct('label', {'pud_pre', 'pud_in', 'pud_post'}, 't0', {2, 3.8, 7}, 't1', {3, 4.2, 8});
    % scene 'up' (old TC6): road dries up at 5 s while cornering at 60 km/h
    u.tEnd = 15; u.kv = [0 60; 15 60]; u.ka = [0 0; 1 0.15; 15 0.15]; u.kmu = [0 0.3; 5 0.3; 5.001 0.8; 15 0.8]; u.sines = zeros(0, 4);
    u.win = struct('label', {'up_pre', 'up_post'}, 't0', {4, 13}, 't1', {5, 15});
    S = chain('SLIP', 'SLIP: hệ số bám đổi khi đang cua', {p, u, d}, thTab);
end

%% ===================== WEAVE: continuous steering ==========================
function S = buildWEAVE(thTab)
    % scene 'slal' (from old TC2): slalom on the dry road at 50 km/h, 2.5 cycles
    a.tEnd = 14; a.kv = [0 50; 14 50]; a.ka = [0 0; 14 0]; a.kmu = [0 0.8; 14 0.8]; a.sines = [2 12 0.15 0.25];
    a.win = struct('label', {'slal'}, 't0', {4}, 't1', {12});
    % scene 'lane' (from old TC2): one lane-change cycle on mu = 0.3 at 80 km/h
    l.tEnd = 8; l.kv = [0 80; 8 80]; l.ka = [0 0; 8 0]; l.kmu = [0 0.3; 8 0.3]; l.sines = [2 6 0.10 0.25];
    l.win = struct('label', {'lane'}, 't0', {2}, 't1', {6});
    % scene 'ice' (old TC5): sustained sine steering at 100 km/h on a very slippery road (target kept under the grip limit 0.2 g)
    c.tEnd = 25; c.kv = [0 100; 25 100]; c.ka = [0 0; 25 0]; c.kmu = [0 0.2; 25 0.2]; c.sines = [2 22 0.15 0.3];
    c.win = struct('label', {'ice_tr', 'ice_ss'}, 't0', {2, 10}, 't1', {6, 22});
    S = chain('WEAVE', 'WEAVE: lái liên tục (lượn, chuyển làn, mặt trơn)', {a, l, c}, thTab);
end

%% ===================== EDGE: extreme region above 0.3 g (report only) ================
function S = buildEDGE(thTab)
    speeds = [40 60 100]; lev = [0.35 0.4];
    scenes = cell(1, numel(speeds) + 1);
    for i = 1:numel(speeds)
        sg = 1 - 2 * mod(i - 1, 2);                        % left, right, left
        sc.tEnd = 15; sc.kv = [0 speeds(i); 15 speeds(i)];
        sc.ka = [0 0; 1 sg * lev(1); 6 sg * lev(1); 7 sg * lev(2); 12 sg * lev(2); 13.5 0];
        sc.kmu = [0 0.8; 15 0.8]; sc.sines = zeros(0, 4);
        sc.win = struct('label', {dryLabel(speeds(i), lev(1), sg), dryLabel(speeds(i), lev(2), sg)}, 't0', {5, 11}, 't1', {6, 12});
        scenes{i} = sc;
    end
    n.tEnd = 16; n.kv = [0 60; 16 60]; n.ka = [0 0; 1.5 0.2; 14.5 0.2; 16 0]; n.kmu = [0 0.8; 16 0.8]; n.sines = [2.5 14.5 0.2 0.25];
    n.win = struct('label', {'sine'}, 't0', {3}, 't1', {14.5});
    scenes{end} = n;
    S = chain('EDGE', 'EDGE: vùng cực trên 0.3 g (chỉ báo cáo)', scenes, thTab);
end

%% ===================== DREWS v2 (2026-10-22): five scoring cases of EXACTLY 60 s each =====================
% Plan and reasons: Documents/Shared/KeHoach_DREWS_v2.txt. Every condition lies outside the CALIB v2 grid (speeds 20:10:100, levels 0.1/0.2/0.3 g, mu 0.8/0.35,
% 0.5 and 1 Hz); the only exception is RAMP at 0.2 g (a level of the CALIB staircase, but with the speed moving continuously between 90 and 40 km/h, which CALIB never does).
% The driver is the same open-loop steering-angle source as in v1. a_y > 0 is a left turn. Window labels follow Tracking/CLAUDE.md.

%% DRY v2: steady error at speeds and levels NOT used to pick the parameters (dry road, mu 0.8)
function S = buildDRY2(thTab)
    speeds = [25 45 75 95]; gapDt = [4 6 4];                    % block speeds [km/h]; straight speed change between blocks [s] (0.2 s per km/h, at least 4 s)
    kv = [0 speeds(1)]; ka = [0 0]; win = struct('label', {}, 't0', {}, 't1', {});
    tb = 2;                                                     % 2 s of straight at the start (never scored)
    for i = 1:numel(speeds)
        v = speeds(i);
        % block of 11 s: 0.15 g left (enter 1 s, settle 2 s, window 1 s), back to 0 in 1.5 s, 0.25 g right (same), back to 0 in 1.5 s
        ka = [ka; tb, 0; tb + 1, 0.15; tb + 4, 0.15; tb + 5.5, 0; tb + 6.5, -0.25; tb + 9.5, -0.25; tb + 11, 0]; %#ok<AGROW>
        win(end+1) = struct('label', dryLabel(v, 0.15, 1), 't0', tb + 3, 't1', tb + 4); %#ok<AGROW>
        win(end+1) = struct('label', dryLabel(v, 0.25, -1), 't0', tb + 8.5, 't1', tb + 9.5); %#ok<AGROW>
        kv = [kv; tb, v; tb + 11, v]; %#ok<AGROW>
        tb = tb + 11;
        if i < numel(speeds)
            kv = [kv; tb + gapDt(i), speeds(i+1)]; %#ok<AGROW>
            tb = tb + gapDt(i);
        end
    end
    tEnd = 60;                                                  % tb = 60 here: 2 + 4*11 + 14
    assert(abs(tb - tEnd) < 1e-9, 'DRY v2 timeline is %g s', tb);
    S = assemble('DRY', 'DRY v2: độ chính xác tĩnh ở tốc độ và mức ngoài lưới CALIB', tEnd, kv, ka, [0 0.8; tEnd 0.8], zeros(0, 4), thTab, win);
end

%% RAMP v2: the set-point follows the speed while cornering at constant a_y (dry road)
function S = buildRAMP2(thTab)
    kv = [0 90; 7 90; 27 40; 31 40; 51 90; 58 90; 60 90];       % 90 -> 40 -> 90 km/h, 20 s each way ((1 - cos) blend, peak 1.1 m/s^2)
    ka = [0 0; 3 0; 4 0.2; 58 0.2; 60 0];                       % 0.2 g left from 3-4 s on
    win = struct('label', {'mid_h1', 'mid_dn', 'mid_h2', 'mid_up', 'mid_h3'}, 't0', {5, 7, 28, 31, 53}, 't1', {7, 27, 31, 51, 58});
    S = assemble('RAMP', 'RAMP v2: bám khi giá trị đặt đổi liên tục theo tốc độ', 60, kv, ka, [0 0.8; 60 0.8], zeros(0, 4), thTab, win);
end

%% SLIP v2: lighter hand when mu drops, heavier hand and recovery when mu rises (three scenes joined by straight gaps; scenes 46 s + gaps 14 s)
function S = buildSLIP2(thTab)
    % scene 'drop' 70 km/h, 0.2 g left, mu 0.8 -> 0.5 at 6 s (held to the end of the scene and the first 2 s of the gap); grip use 0.40
    d.tEnd = 16; d.kv = [0 70; 16 70]; d.ka = [0 0; 1 0.2; 16 0.2]; d.kmu = [0 0.8; 6 0.8; 6.001 0.5; 16 0.5]; d.sines = zeros(0, 4);
    d.win = struct('label', {'drop_pre', 'drop_in', 'drop_rec'}, 't0', {5, 6, 6}, 't1', {6, 8, 12});
    % scene 'pud' 85 km/h, 0.15 g right, puddle mu 0.2 for 1 s at 6 s then back to 0.8; grip use 0.75 during the puddle
    p.tEnd = 14; p.kv = [0 85; 14 85]; p.ka = [0 0; 1 -0.15; 14 -0.15]; p.kmu = [0 0.8; 6 0.8; 6.001 0.2; 7 0.2; 7.001 0.8; 14 0.8]; p.sines = zeros(0, 4);
    p.win = struct('label', {'pud_pre', 'pud_in', 'pud_rec'}, 't0', {5, 6, 6}, 't1', {6, 8, 12});
    % scene 'rise' 55 km/h, 0.2 g left, mu 0.4 -> 0.8 at 6 s, held 10 s; grip use 0.50 before the step
    r.tEnd = 16; r.kv = [0 55; 16 55]; r.ka = [0 0; 1 0.2; 16 0.2]; r.kmu = [0 0.4; 6 0.4; 6.001 0.8; 16 0.8]; r.sines = zeros(0, 4);
    r.win = struct('label', {'rise_pre', 'rise_in', 'rise_rec'}, 't0', {5, 6, 6}, 't1', {6, 8, 12});
    S = chain('SLIP', 'SLIP v2: trợ lực khi hệ số bám đổi (giảm, vũng nước, tăng)', {d, p, r}, thTab);
end

%% EDGE v2: near the assist limit, above the design range 0.3 g (dry road; outside the design range, the three controllers meet the saturation)
function S = buildEDGE2(thTab)
    % scenes 'e50' and 'e80': 0.35 g for 5 s then 0.38 g for 5 s (windows = last second of each hold); the third scene 'e65': fast entry to 0.35 g in 0.5 s
    a.tEnd = 16; a.kv = [0 50; 16 50]; a.ka = [0 0; 1 0.35; 6 0.35; 7 0.38; 12 0.38; 14 0; 16 0];
    a.kmu = [0 0.8; 16 0.8]; a.sines = zeros(0, 4);
    a.win = struct('label', {dryLabel(50, 0.35, 1), dryLabel(50, 0.38, 1)}, 't0', {5, 11}, 't1', {6, 12});
    b.tEnd = 16; b.kv = [0 80; 16 80]; b.ka = [0 0; 1 -0.35; 6 -0.35; 7 -0.38; 12 -0.38; 14 0; 16 0];
    b.kmu = [0 0.8; 16 0.8]; b.sines = zeros(0, 4);
    b.win = struct('label', {dryLabel(80, 0.35, -1), dryLabel(80, 0.38, -1)}, 't0', {5, 11}, 't1', {6, 12});
    c.tEnd = 14; c.kv = [0 65; 14 65]; c.ka = [0 0; 2 0; 2.5 0.35; 6.5 0.35; 8 0; 14 0];
    c.kmu = [0 0.8; 14 0.8]; c.sines = zeros(0, 4);
    c.win = struct('label', {'v65in', dryLabel(65, 0.35, 1)}, 't0', {2.5, 5.5}, 't1', {4.5, 6.5});
    S = chain('EDGE', 'EDGE v2: gần giới hạn trợ lực, trên 0.3 g', {a, b, c}, thTab);
end

%% WEAVE v2: continuous steering outside the 0.5 and 1 Hz of CALIB (scenes 48 s + gaps 12 s)
function S = buildWEAVE2(thTab)
    % scene 'ctr' 100 km/h: gentle weaving about the centre, 0.05 g at 0.2 Hz, 4 cycles (20 s); small T_d,ref compared with the dead zone of the Map
    a.tEnd = 22; a.kv = [0 100; 22 100]; a.ka = [0 0; 22 0]; a.kmu = [0 0.8; 22 0.8]; a.sines = [2 22 0.05 0.2];
    a.win = struct('label', {'ctr'}, 't0', {3}, 't1', {22});
    % scene 'dlc' 80 km/h: double lane change, 0.25 g at 0.6 Hz, 2 cycles (3.33 s), straight padding to the end of the scene
    l.tEnd = 12; l.kv = [0 80; 12 80]; l.ka = [0 0; 12 0]; l.kmu = [0 0.8; 12 0.8]; l.sines = [2 2+2/0.6 0.25 0.6];
    l.win = struct('label', {'dlc'}, 't0', {2}, 't1', {2 + 2/0.6});
    % scene 'mu3' 60 km/h on mu 0.3: weaving 0.15 g at 0.75 Hz, 5 cycles (6.67 s); grip use 0.5
    c.tEnd = 14; c.kv = [0 60; 14 60]; c.ka = [0 0; 14 0]; c.kmu = [0 0.3; 14 0.3]; c.sines = [2 2+5/0.75 0.15 0.75];
    c.win = struct('label', {'mu3'}, 't0', {2.5}, 't1', {2 + 5/0.75});
    S = chain('WEAVE', 'WEAVE v2: lái liên tục (quanh tâm, đổi làn kép, mặt trơn)', {a, l, c}, thTab);
end


%% ===================== DREWS v3 (2026-10-23): five scoring cases of EXACTLY 100 s each =====================
% Plan and reasons: Documents/Shared/KeHoach_DREWS_v3.txt. Same questions as v2, longer cases (more windows, more speeds), and a SLIP built to show the loss of
% tracking of a controller without error feedback when mu drops (the static probe scratch/probe_map_mu.m: the loss grows with the grip use a_y/mu, 4-5 % of
% T_d,ref at 0.83-0.86). Window labels: SLIP windows <scene>_ref are the same scene on mu 0.8 (reference for the signed error difference Delta).

%% DRY v3: six speeds outside the CALIB grid, blocks of 12 s (left level, crossing, right level, back to 0), windows of 2 s
function S = buildDRY3(thTab)
    speeds = [25 35 45 55 75 95]; ayL = [0.15 0.15 0.15 0.15 0.15 0.15]; ayR = [0.22 0.22 0.25 0.25 0.25 0.25];   % 25 km/h: Plant limit 0.31 g, 35 km/h: 0.585 g
    kv = [0 speeds(1)]; ka = [0 0]; win = struct('label', {}, 't0', {}, 't1', {});
    tb = 2;                                                     % 2 s of straight at the start (never scored)
    for i = 1:numel(speeds)
        v = speeds(i);
        % block of 12 s: left level (ramp 1 s, settle 2 s, window 2 s), crossing to the right level in 2 s, settle 2 s, window 2 s, back to 0 in 1 s
        ka = [ka; tb, 0; tb + 1, ayL(i); tb + 5, ayL(i); tb + 7, -ayR(i); tb + 11, -ayR(i); tb + 12, 0]; %#ok<AGROW>
        win(end+1) = struct('label', dryLabel(v, ayL(i), 1), 't0', tb + 3, 't1', tb + 5); %#ok<AGROW>
        win(end+1) = struct('label', dryLabel(v, ayR(i), -1), 't0', tb + 9, 't1', tb + 11); %#ok<AGROW>
        kv = [kv; tb, v; tb + 12, v]; %#ok<AGROW>
        tb = tb + 12;
        if i < numel(speeds)
            dt = max(4, 0.2 * abs(speeds(i+1) - v));            % straight speed change between blocks
            kv = [kv; tb + dt, speeds(i+1)]; %#ok<AGROW>
            tb = tb + dt;
        end
    end
    tEnd = 100;
    assert(tb <= tEnd - 2, 'DRY v3 timeline is %g s', tb);
    S = assemble('DRY', 'DRY v3: độ chính xác tĩnh ở tốc độ và mức ngoài lưới CALIB', tEnd, kv, ka, [0 0.8; tEnd 0.8], zeros(0, 4), thTab, win);
end

%% RAMP v3: set-point follows the speed while cornering; scene A slow (0.18 g, 95-45-95 km/h, 20 s each way), scene B fast (0.25 g, 85-45-85 km/h, 10 s each way)
function S = buildRAMP3(thTab)
    a.tEnd = 59; a.kv = [0 95; 7 95; 27 45; 31 45; 51 95; 59 95]; a.ka = [0 0; 3 0; 4 0.18; 55 0.18; 57 0]; a.kmu = [0 0.8; 59 0.8]; a.sines = zeros(0, 4);
    a.win = struct('label', {'slow_h1', 'slow_dn', 'slow_h2', 'slow_up', 'slow_h3'}, 't0', {5, 7, 28, 31, 52}, 't1', {7, 27, 31, 51, 55});
    b.tEnd = 35; b.kv = [0 85; 5 85; 15 45; 19 45; 29 85; 35 85]; b.ka = [0 0; 2 0; 3 -0.25; 32 -0.25; 33.5 0]; b.kmu = [0 0.8; 35 0.8]; b.sines = zeros(0, 4);
    b.win = struct('label', {'fast_h1', 'fast_dn', 'fast_h2', 'fast_up', 'fast_h3'}, 't0', {3.5, 5, 16, 19, 30}, 't1', {5, 15, 19, 29, 32});
    S = chain('RAMP', 'RAMP v3: bám khi giá trị đặt đổi liên tục theo tốc độ (chậm và nhanh)', {a, b}, thTab);
end

%% SLIP v3: loss of tracking when mu drops, steady state at high grip use (>= 0.8): staircase, slow ramp, puddle (scenes 39.5 + 33 + 13 s + straight gaps)
function S = buildSLIP3(thTab)
    % scene 'stair' 60 km/h, 0.27 g left: mu 0.8 (reference window), then 0.6, 0.45, 0.38, 0.32 held 6 s each (grip use 0.84 at 0.32), back to 0.8 at 31 s
    a.tEnd = 39.5; a.kv = [0 60; 39.5 60]; a.ka = [0 0; 1 0.27; 38 0.27; 39.5 0];
    a.kmu = [0 0.8; 7 0.8; 7.001 0.6; 13 0.6; 13.001 0.45; 19 0.45; 19.001 0.38; 25 0.38; 25.001 0.32; 31 0.32; 31.001 0.8; 39.5 0.8]; a.sines = zeros(0, 4);
    a.win = struct('label', {'stair_ref', 'stair_m0p6', 'stair_m0p45', 'stair_m0p38', 'stair_m0p32', 'stair_in', 'stair_rec'}, ...
        't0', {5, 11, 17, 23, 29, 31, 31}, 't1', {7, 13, 19, 25, 31, 33, 37});
    % scene 'ramp' 80 km/h, 0.24 g right: mu 0.8 -> 0.29 over 16 s (slow, almost static; grip use 0.83 at the end), hold 5 s, back to 0.8 in 4 s
    b.tEnd = 33; b.kv = [0 80; 33 80]; b.ka = [0 0; 1 -0.24; 31 -0.24; 32 0];
    b.kmu = [0 0.8; 5 0.8; 21 0.29; 26 0.29; 30 0.8; 33 0.8]; b.sines = zeros(0, 4);
    b.win = struct('label', {'ramp_ref', 'ramp_dn', 'ramp_lo', 'ramp_up'}, 't0', {3, 5, 24, 26}, 't1', {5, 21, 26, 30});
    % scene 'pud' 90 km/h, 0.2 g left: puddle mu 0.25 for 1.5 s (grip use 0.8) at 5 s
    c.tEnd = 13; c.kv = [0 90; 13 90]; c.ka = [0 0; 1 0.2; 11.5 0.2; 12.5 0]; c.kmu = [0 0.8; 5 0.8; 5.001 0.25; 6.5 0.25; 6.501 0.8; 13 0.8]; c.sines = zeros(0, 4);
    c.win = struct('label', {'pud_ref', 'pud_in', 'pud_rec'}, 't0', {3, 5, 5}, 't1', {5, 7, 11});
    S = fit100('SLIP', 'SLIP v3: mất bám khi hệ số bám giảm (bậc, dốc chậm, vũng nước)', {a, b, c}, thTab);
end

%% SLIP v4 (2026-10-23, user request): the road loses grip WHILE cornering and the target a_y stays at or above the new grip (grip use >= 0.9, as the
% scene 'down' of v1), so the front tyre slides and the pneumatic trail collapses; designed after seeing the v3 results (the user waived that rule).
function S = buildSLIP4(thTab)
    % scene 'stair' 60 km/h, 0.3 g right: mu 0.8 (reference), then 0.5, 0.4, 0.33, 0.28, 0.24 held 5 s each (target grip use 0.6, 0.75, 0.91, 1.07, 1.25),
    % back to 0.8
    b.tEnd = 40.5; b.kv = [0 60; 40.5 60]; b.ka = [0 0; 1 -0.3; 39 -0.3; 40.5 0];
    b.kmu = [0 0.8; 7 0.8; 7.001 0.5; 12 0.5; 12.001 0.4; 17 0.4; 17.001 0.33; 22 0.33; 22.001 0.28; 27 0.28; 27.001 0.24; 32 0.24; 32.001 0.8; 40.5 0.8];
    b.sines = zeros(0, 4);
    b.win = struct('label', {'stair_ref', 'stair_m0p5', 'stair_m0p4', 'stair_m0p33', 'stair_m0p28', 'stair_m0p24', 'stair_rec'}, ...
        't0', {5, 10, 15, 20, 25, 30, 32}, 't1', {7, 12, 17, 22, 27, 32, 38});
    % scene 'pud' 80 km/h, 0.25 g left: puddle mu 0.2 for 2 s at 5 s (target grip use 1.25)
    c.tEnd = 12; c.kv = [0 80; 12 80]; c.ka = [0 0; 1 0.25; 10.5 0.25; 11.5 0]; c.kmu = [0 0.8; 5 0.8; 5.001 0.2; 7 0.2; 7.001 0.8; 12 0.8]; c.sines = zeros(0, 4);
    c.win = struct('label', {'pud_ref', 'pud_in', 'pud_rec'}, 't0', {3, 5, 7}, 't1', {5, 7, 10});
    % scene 'lane' (as 'pud' of v1): 80 km/h, two identical lane-change cycles 0.2 g at 0.4 Hz; the first on the dry road (reference), the second
    % through a puddle mu 0.2 for 0.4 s just after the peak steering demand (same phase as v1: 0.8-1.2 s into the cycle; target grip use 1.0)
    l.tEnd = 11; l.kv = [0 80; 11 80]; l.ka = [0 0; 11 0]; l.sines = [1 3.5 0.2 0.4; 5.5 8 0.2 0.4];
    l.kmu = [0 0.8; 6.3 0.8; 6.301 0.2; 6.7 0.2; 6.701 0.8; 11 0.8];
    l.win = struct('label', {'lane_ref', 'lane_in', 'lane_rec'}, 't0', {1.8, 6.3, 6.7}, 't1', {2.2, 6.7, 10});
    % scene 'drop' (as 'down' of v1): 100 km/h, 0.3 g left, mu 0.8 -> 0.3 at 6 s (target grip use 1.0), held 6.5 s
    a.tEnd = 14; a.kv = [0 100; 14 100]; a.ka = [0 0; 1.5 0.3; 12.5 0.3; 14 0];
    a.kmu = [0 0.8; 6 0.8; 6.001 0.3; 14 0.3]; a.sines = zeros(0, 4);
    a.win = struct('label', {'drop_ref', 'drop_in', 'drop_lo'}, 't0', {4, 6, 9}, 't1', {6, 8, 12});
    S = fit100('SLIP', 'SLIP v4: mất bám khi đang cua và khi chuyển làn, mức dùng bám >= 0.9 sau khi mu giảm', {b, c, l, a}, thTab);
end

%% ===================== SSW (2026-10-23, user decision): three cases STEADY, SLIP, WEAVE of EXACTLY 100 s each =====================
% Replace the five DREWS cases (they all gave the same ranking). Plan: Documents/Shared/KeHoach_SSW.txt. Designed AFTER seeing the DREWS v3 and SLIP v4
% results (the user waived that rule). Same open-loop driver and window conventions as DREWS v3.

%% STEADY = DRY + EDGE: steady cornering on the dry road from light to near the limit
function S = buildSTEADY(thTab)
    speeds = [25 45 65 85];
    lev = {[0.15 -0.25], [0.15 -0.25 0.35], [-0.15 0.25 -0.35], [0.15 -0.25 0.38]};   % signed levels [g], a_y > 0 = left; 25 km/h: Plant limit 0.31 g
    kv = [0 speeds(1)]; ka = [0 0]; win = struct('label', {}, 't0', {}, 't1', {});
    tb = 2;                                                     % 2 s of straight at the start (never scored)
    for i = 1:numel(speeds)
        v = speeds(i);
        for a = lev{i}
            % level of 7 s: ramp 1 s, hold 4 s (window = last 1 s), back to 0 in 1 s, 1 s straight
            ka = [ka; tb, 0; tb + 1, a; tb + 5, a; tb + 6, 0]; %#ok<AGROW>
            win(end+1) = struct('label', dryLabel(v, abs(a), sign(a)), 't0', tb + 4, 't1', tb + 5); %#ok<AGROW>
            tb = tb + 7;
        end
        kv = [kv; tb, v]; %#ok<AGROW>
        if i < numel(speeds)
            dt = max(4, 0.2 * abs(speeds(i+1) - v));            % straight speed change between blocks
            kv = [kv; tb + dt, speeds(i+1)]; %#ok<AGROW>
            tb = tb + dt;
        end
    end
    tEnd = 100;
    assert(tb <= tEnd - 2, 'STEADY timeline is %g s', tb);
    S = assemble('STEADY', 'STEADY: cua giữ đều trên đường khô, từ nhẹ tới gần giới hạn', tEnd, kv, ka, [0 0.8; tEnd 0.8], zeros(0, 4), thTab, win);
end

%% SLIP (SSW) = RAMP + SLIP: conditions change while cornering (speed, then friction)
function S = buildSLIPS(thTab)
    % scene 'ramp' 0.2 g left: 90 -> 45 -> 90 km/h, 13 s each way, 3 s hold at 45 km/h
    r.tEnd = 36.5; r.kv = [0 90; 4 90; 17 45; 20 45; 33 90; 36.5 90]; r.ka = [0 0; 1 0.2; 35 0.2; 36.5 0]; r.kmu = [0 0.8; 36.5 0.8]; r.sines = zeros(0, 4);
    r.win = struct('label', {'ramp_hi', 'ramp_dn', 'ramp_lo', 'ramp_up'}, 't0', {3, 5, 18, 21}, 't1', {4, 17, 20, 33});
    % scene 'stair' 60 km/h, 0.3 g right: mu 0.8 (reference), 0.5, 0.33, 0.24 held 5 s each (target grip use 0.6, 0.91, 1.25), back to 0.8
    b.tEnd = 29.5; b.kv = [0 60; 29.5 60]; b.ka = [0 0; 1 -0.3; 28 -0.3; 29.5 0];
    b.kmu = [0 0.8; 7 0.8; 7.001 0.5; 12 0.5; 12.001 0.33; 17 0.33; 17.001 0.24; 22 0.24; 22.001 0.8; 29.5 0.8]; b.sines = zeros(0, 4);
    b.win = struct('label', {'stair_ref', 'stair_m0p5', 'stair_m0p33', 'stair_m0p24', 'stair_rec'}, 't0', {5, 10, 15, 20, 22}, 't1', {7, 12, 17, 22, 28});
    % scene 'pud' 80 km/h, 0.25 g left: puddle mu 0.2 for 2 s at 5 s (target grip use 1.25)
    c.tEnd = 12; c.kv = [0 80; 12 80]; c.ka = [0 0; 1 0.25; 10.5 0.25; 11.5 0]; c.kmu = [0 0.8; 5 0.8; 5.001 0.2; 7 0.2; 7.001 0.8; 12 0.8]; c.sines = zeros(0, 4);
    c.win = struct('label', {'pud_ref', 'pud_in', 'pud_rec'}, 't0', {3, 5, 7}, 't1', {5, 7, 10});
    S = fit100('SLIP', 'SLIP (SSW): đang cua mà tốc độ hoặc hệ số bám đổi', {r, b, c}, thTab);
end

%% WEAVE (SSW): continuous steering, including a lane change through a puddle (as 'pud' of v1)
function S = buildWEAVES(thTab)
    % scene 'ctr' 95 km/h: gentle weaving about the centre, 0.05 g at 0.2 Hz, 4 cycles (20 s); small T_d,ref compared with the dead zone of the Map
    a.tEnd = 23; a.kv = [0 95; 23 95]; a.ka = [0 0; 23 0]; a.kmu = [0 0.8; 23 0.8]; a.sines = [2 22 0.05 0.2];
    a.win = struct('label', {'ctr'}, 't0', {3}, 't1', {22});
    % scene 'lane' 80 km/h: two identical lane changes 0.2 g at 0.4 Hz, the first on the dry road (reference), the second through a puddle mu 0.2 for
    % 0.4 s just after the peak steering demand (0.8-1.2 s into the cycle, as v1)
    l.tEnd = 11; l.kv = [0 80; 11 80]; l.ka = [0 0; 11 0]; l.sines = [1 3.5 0.2 0.4; 5.5 8 0.2 0.4];
    l.kmu = [0 0.8; 6.3 0.8; 6.301 0.2; 6.7 0.2; 6.701 0.8; 11 0.8];
    l.win = struct('label', {'lane_ref', 'lane_in', 'lane_rec'}, 't0', {1.8, 6.3, 6.7}, 't1', {2.2, 6.7, 10});
    % scene 'sw' 70 km/h: stepped-frequency sine 0.1 g at 0.3 Hz (2 cycles), 0.8 Hz (3 cycles), 1.5 Hz (5 cycles); each segment ends at a zero crossing
    t1 = 2 + 2/0.3; t2 = t1 + 3/0.8; t3 = t2 + 5/1.5;
    s.tEnd = ceil(t3 + 2); s.kv = [0 70; s.tEnd 70]; s.ka = [0 0; s.tEnd 0]; s.kmu = [0 0.8; s.tEnd 0.8];
    s.sines = [2 t1 0.1 0.3; t1 t2 0.1 0.8; t2 t3 0.1 1.5];
    s.win = struct('label', {'sw0p3', 'sw0p8', 'sw1p5'}, 't0', {2, t1, t2}, 't1', {t1, t2, t3});
    % scene 'mu3' 60 km/h on mu 0.3: weaving 0.15 g at 0.75 Hz, 8 cycles (10.7 s); grip use 0.5
    c.tEnd = 14.5; c.kv = [0 60; 14.5 60]; c.ka = [0 0; 14.5 0]; c.kmu = [0 0.3; 14.5 0.3]; c.sines = [2 2+8/0.75 0.15 0.75];
    c.win = struct('label', {'mu3'}, 't0', {2.5}, 't1', {2 + 8/0.75});
    S = fit100('WEAVE', 'WEAVE (SSW): lái liên tục (quanh tâm, chuyển làn qua vũng nước, quét tần số, mặt trơn)', {a, l, s, c}, thTab);
end

%% EDGE v3: near the assist limit, above 0.3 g (dry road): holds 0.35 g then 0.38 g at 45, 65, 85 km/h, fast entries to 0.35 g at 55 and 75 km/h
function S = buildEDGE3(thTab)
    speeds = [45 55 65 75 85]; scenes = cell(1, numel(speeds));
    for i = 1:numel(speeds)
        sg = 1 - 2 * mod(i - 1, 2);                             % left, right, left, right, left
        sc = struct();
        if mod(i, 2) == 1
            sc.tEnd = 17; sc.kv = [0 speeds(i); 17 speeds(i)]; sc.kmu = [0 0.8; 17 0.8]; sc.sines = zeros(0, 4);
            sc.ka = [0 0; 1 sg * 0.35; 7 sg * 0.35; 8 sg * 0.38; 14 sg * 0.38; 15.5 0];
            sc.win = struct('label', {dryLabel(speeds(i), 0.35, sg), dryLabel(speeds(i), 0.38, sg)}, 't0', {6, 13}, 't1', {7, 14});
        else
            sc.tEnd = 10; sc.kv = [0 speeds(i); 10 speeds(i)]; sc.kmu = [0 0.8; 10 0.8]; sc.sines = zeros(0, 4);
            sc.ka = [0 0; 2 0; 2.5 sg * 0.35; 6.5 sg * 0.35; 8 0];
            sc.win = struct('label', {sprintf('v%din', speeds(i)), dryLabel(speeds(i), 0.35, sg)}, 't0', {2.5, 5.5}, 't1', {4.5, 6.5});
        end
        scenes{i} = sc;
    end
    S = fit100('EDGE', 'EDGE v3: gần giới hạn trợ lực, trên 0.3 g', scenes, thTab);
end

%% WEAVE v3: continuous steering outside the 0.5 and 1 Hz of CALIB: centre weaving, two double lane changes, stepped-frequency sine, weaving on mu 0.3
function S = buildWEAVE3(thTab)
    % scene 'ctr' 95 km/h: gentle weaving about the centre, 0.05 g at 0.2 Hz, 4 cycles (20 s); small T_d,ref compared with the dead zone of the Map
    a.tEnd = 23; a.kv = [0 95; 23 95]; a.ka = [0 0; 23 0]; a.kmu = [0 0.8; 23 0.8]; a.sines = [2 22 0.05 0.2];
    a.win = struct('label', {'ctr'}, 't0', {3}, 't1', {22});
    % scenes 'dlc90' and 'dlc75': double lane change, 0.25 g at 0.6 Hz, 2 cycles (3.33 s)
    l1.tEnd = 8.5; l1.kv = [0 90; 8.5 90]; l1.ka = [0 0; 8.5 0]; l1.kmu = [0 0.8; 8.5 0.8]; l1.sines = [2 2+2/0.6 0.25 0.6];
    l1.win = struct('label', {'dlc90'}, 't0', {2}, 't1', {2 + 2/0.6});
    l2.tEnd = 8.5; l2.kv = [0 75; 8.5 75]; l2.ka = [0 0; 8.5 0]; l2.kmu = [0 0.8; 8.5 0.8]; l2.sines = [2 2+2/0.6 0.25 0.6];
    l2.win = struct('label', {'dlc75'}, 't0', {2}, 't1', {2 + 2/0.6});
    % scene 'sw' 70 km/h: stepped-frequency sine 0.1 g at 0.3 Hz (2 cycles), 0.8 Hz (3 cycles), 1.5 Hz (5 cycles); each segment ends at a zero crossing
    t1 = 2 + 2/0.3; t2 = t1 + 3/0.8; t3 = t2 + 5/1.5;
    s.tEnd = ceil(t3 + 2); s.kv = [0 70; s.tEnd 70]; s.ka = [0 0; s.tEnd 0]; s.kmu = [0 0.8; s.tEnd 0.8];
    s.sines = [2 t1 0.1 0.3; t1 t2 0.1 0.8; t2 t3 0.1 1.5];
    s.win = struct('label', {'sw0p3', 'sw0p8', 'sw1p5'}, 't0', {2, t1, t2}, 't1', {t1, t2, t3});
    % scene 'mu3' 60 km/h on mu 0.3: weaving 0.15 g at 0.75 Hz, 8 cycles (10.7 s); grip use 0.5
    c.tEnd = 14.5; c.kv = [0 60; 14.5 60]; c.ka = [0 0; 14.5 0]; c.kmu = [0 0.3; 14.5 0.3]; c.sines = [2 2+8/0.75 0.15 0.75];
    c.win = struct('label', {'mu3'}, 't0', {2.5}, 't1', {2 + 8/0.75});
    S = fit100('WEAVE', 'WEAVE v3: lái liên tục (quanh tâm, đổi làn kép, quét tần số, mặt trơn)', {a, l1, l2, s, c}, thTab);
end

function S = fit100(tag, name, scenes, thTab)
% Join the scenes with chain() and pad the last scene with straight driving so that the case is EXACTLY 100 s (at least 2 s of padding).
    S = chain(tag, name, scenes, thTab);
    pad = 100 - S.t(end);
    assert(pad >= 2 - 1e-9, '%s v3: scenes and gaps take %.3f s, no room for 2 s of straight tail', tag, S.t(end));
    sc = scenes{end}; tNew = sc.tEnd + pad;
    sc.kv = [sc.kv; tNew sc.kv(end, 2)]; sc.ka = [sc.ka; tNew 0]; sc.kmu = [sc.kmu; tNew sc.kmu(end, 2)]; sc.tEnd = tNew;
    scenes{end} = sc;
    S = chain(tag, name, scenes, thTab);
end

%% ===================== CALIB: calibration case shared by every controller ========
function S = buildCALIB(thTab)
% Calibration case CALIB v2 (2026-10-17, QuyChuan.txt part 3; replaces the 117 s case with 20/60/100 km/h blocks). ONE continuous case, speed rising
% 20, 30, ..., 100 km/h (nine blocks). Every segment exposes one mechanism of the controllers (reasons: Tracking/historychat_testcase.md, entries 6-9):
%   staircase  levels 0.1, 0.2, 0.3 g held in turn, one direction, going up (20 km/h: 0.10, 0.18 g, 90 % of the 0.2 g that the Plant reaches there).
%              Each level 3 s: 1 s ramp, 1 s to settle, 1 s window. Windows: static_* = the last 1 s (steady error: e_rel gate and group 'static');
%              trans_* = ramp + first second (transient: group 'dyn'). This is the angle-step test of the EPS literature (steady torque after a step).
%   sine       only from 40 km/h up (below it the open-loop driver needs 80-140 deg of hand wheel, T_s is dominated by the inertia of the column and
%              e_T is 170-560 % of T_d,ref for every controller: measured 2026-10-17, the sine says nothing about the controller there).
%              Starts at the top level of the staircase as a cosine (continuous, no return to 0), 0.5 Hz, 1.25 cycles, amplitude = top level, ends
%              at the zero crossing; then a sine at 1 Hz, 3.5 cycles, amplitude top/2 (same peak a_y rate), ends at 0. It crosses 0 (dead zone of
%              the map, change of sign of the assist) and exercises the lag, lead and D terms that 0.5 Hz alone hardly shows. Windows: sine_v<v>_f0p5 =
%              the first full cycle (2 s from the peak), sine_v<v>_f1 = 3 full cycles (3 s from 0.5 s after the start); group 'dyn'.
%              The speed rises by 10 km/h DURING the sine (6 s, 0.46 m/s^2 mean), so the sine doubles as the speed change to the next block;
%              v in the label is the speed at the start of the sine. Below 40 km/h the staircase is followed by 3 s of straight with the speed change.
%   mu step    60 km/h only, inside the top level 0.3 g (the deepest step the open-loop driver can follow: the grip use stays at 86 %): mu 0.8 -> 0.35 for 6 s ->
%              0.8, held another 4 s; windows mu_drop, mu_rise = the 2 s after each step. Map alone (no feedback) loses 6.9 % of T_d,ref there (measured).
%   lead 2 s straight at 20 km/h and a straight tail; the first 2 s of the case are never scored.
% The driver is open loop: theta1 follows the target a_y through the steady angle table (a_y only labels the angle). Window labels, lower case:
% static_v<v>_a<g>, trans_v<v>_a<g>, sine_v<v>_f0p5 / _f1, mu_drop, mu_rise. Blocks: S.blk (speed, t0, t1) = the staircase and the sine of one speed.
    speeds = 20:10:100;
    tLead = 2; tLvl = 3; tSin = 6; tSwitch = 3; vSineMin = 40; tMuLow = 6; tMuHold = 4; muLow = 0.35; aMuLevel = 0.3; vMu = 60;
    tTotal = 140;                                           % total length [s]: round number; the straight tail makes up the rest
    kv = [0 speeds(1)]; ka = [0 0]; kmu = [0 0.8]; sines = zeros(0, 6);
    win = struct('label', {}, 't0', {}, 't1', {});
    blk = struct('speed', {}, 't0', {}, 't1', {});
    T = tLead; ka = [ka; T 0];
    for i = 1:numel(speeds)
        v = speeds(i);
        if v == 20, lv = [0.10 0.18]; else, lv = [0.1 0.2 0.3]; end
        Tb = T; t = T;
        for k = 1:numel(lv)
            if v == vMu && abs(lv(k) - aMuLevel) < 1e-9
                m1 = t + 3; m2 = m1 + tMuLow; d = 3 + tMuLow + tMuHold;
                kmu = [kmu; m1, 0.8; m1 + 0.001, muLow; m2, muLow; m2 + 0.001, 0.8]; %#ok<AGROW>
                win(end+1) = struct('label', 'mu_drop', 't0', m1, 't1', m1 + 2); %#ok<AGROW>
                win(end+1) = struct('label', 'mu_rise', 't0', m2, 't1', m2 + 2); %#ok<AGROW>
            else
                d = tLvl;
            end
            ka = [ka; t + 1, lv(k); t + d, lv(k)]; %#ok<AGROW>
            win(end+1) = struct('label', sprintf('trans_v%d_a%s', v, g2s(lv(k))), 't0', t, 't1', t + 2); %#ok<AGROW>
            win(end+1) = struct('label', sprintf('static_v%d_a%s', v, g2s(lv(k))), 't0', t + 2, 't1', t + 3); %#ok<AGROW>
            t = t + d;
        end
        top = lv(end); s0 = t;
        kv = [kv; s0, v]; %#ok<AGROW>
        if v >= vSineMin
            dBlk = tSin;
            ka = [ka; s0 + dBlk, 0]; %#ok<AGROW>
            sines = [sines; s0, s0 + 2.5, top, 0.5, pi/2, 1; s0 + 2.5, s0 + tSin, top / 2, 1, 0, 1]; %#ok<AGROW>
            win(end+1) = struct('label', sprintf('sine_v%d_f0p5', v), 't0', s0, 't1', s0 + 2); %#ok<AGROW>
            win(end+1) = struct('label', sprintf('sine_v%d_f1', v), 't0', s0 + 3, 't1', s0 + tSin); %#ok<AGROW>
        else
            dBlk = tSwitch;                                 % no sine: a_y back to 0 in 1 s, straight until the speed has changed
            ka = [ka; s0 + 1, 0; s0 + dBlk, 0]; %#ok<AGROW>
        end
        if i < numel(speeds), kv = [kv; s0 + dBlk, speeds(i+1)]; else, kv = [kv; s0 + dBlk, v]; end %#ok<AGROW>
        T = s0 + dBlk;
        blk(end+1) = struct('speed', v, 't0', Tb, 't1', T); %#ok<AGROW>
    end
    assert(tTotal - T >= 2, 'CALIB v2: no room for a tail of at least 2 s');
    tEnd = tTotal;
    kv = [kv; tEnd, speeds(end)]; ka = [ka; tEnd, 0]; kmu = [kmu; tEnd, 0.8];
    S = assemble('CALIB', 'CALIB v2: parameter-selection case shared by every controller (20-100 km/h step 10, a_y staircase, sine through 0, mu step)', tEnd, kv, ka, kmu, sines, thTab, win);
    S.blk = blk;
end

%% ===================== Common assembly =================================
function S = chain(tag, name, scenes, thTab)
% Join scenes (fields tEnd, kv, ka, kmu, sines, win in scene time) into one case. Between two scenes, a straight gap: a_y goes to 0 (1.5 s), the speed
% changes to the next scene's speed (from 1 s into the gap, 0.2 s per km/h but at least 4 s) and mu steps to the next scene's first value (2 s into the gap).
    kv = zeros(0, 2); ka = zeros(0, 2); kmu = zeros(0, 2); sines = zeros(0, 4);
    win = struct('label', {}, 't0', {}, 't1', {});
    off = 0;
    for i = 1:numel(scenes)
        sc = scenes{i};
        if i > 1
            E = off;                                          % end of the previous scene = start of the gap
            dt = max(4, 0.2 * abs(sc.kv(1, 2) - kv(end, 2)));   % duration of the speed change [s]
            gap = 2 + dt;
            ka  = [ka;  E + 1.5, 0];                          %#ok<AGROW>
            kv  = [kv;  E + 1, kv(end, 2); E + 1 + dt, sc.kv(1, 2)];   %#ok<AGROW>
            kmu = [kmu; E + 2, kmu(end, 2); E + 2.001, sc.kmu(1, 2)]; %#ok<AGROW>
            off = E + gap;                                    % start of this scene
        end
        kv = [kv; sc.kv(:, 1) + off, sc.kv(:, 2)];           %#ok<AGROW>
        ka = [ka; sc.ka(:, 1) + off, sc.ka(:, 2)];           %#ok<AGROW>
        kmu = [kmu; sc.kmu(:, 1) + off, sc.kmu(:, 2)];       %#ok<AGROW>
        if ~isempty(sc.sines)
            sines = [sines; sc.sines(:, 1) + off, sc.sines(:, 2) + off, sc.sines(:, 3:4)]; %#ok<AGROW>
        end
        for j = 1:numel(sc.win)
            win(end+1) = struct('label', sc.win(j).label, 't0', sc.win(j).t0 + off, 't1', sc.win(j).t1 + off); %#ok<AGROW>
        end
        off = off + sc.tEnd;                                  % end of this scene
        if i == numel(scenes), tEnd = off; end
    end
    S = assemble(tag, name, tEnd, kv, ka, kmu, sines, thTab, win);
end

function S = assemble(tag, name, tEnd, kv, ka, kmu, sines, thTab, win)
    t = (0:0.001:tEnd)';
    vK = smoothPath(kv, t);
    a  = smoothPath(ka, t);
    for i = 1:size(sines, 1)
        % sines(i, :) = [t0 t1 amplitude f_Hz] (added to the path) or [t0 t1 amplitude f_Hz phase mode]: mode 1 REPLACES the path in [t0, t1) by
        % amplitude * sin(2 pi f (t - t0) + phase), so that a segment can start from a given value (a cosine from the top level of a staircase)
        if size(sines, 2) >= 6 && sines(i, 6) == 1
            in = t >= sines(i, 1) & t < sines(i, 2);
            a(in) = sines(i, 3) * sin(2*pi*sines(i, 4) * (t(in) - sines(i, 1)) + sines(i, 5));
        else
            in = t >= sines(i, 1) & t <= sines(i, 2);
            a(in) = a(in) + sines(i, 3) * sin(2*pi*sines(i, 4) * (t(in) - sines(i, 1)));
        end
    end
    mu = interp1(kmu(:, 1), kmu(:, 2), t, 'linear');
    theta1 = sign(a) .* interp2(thTab.ay, thTab.v, thTab.th, min(abs(a), thTab.ay(end)), min(max(vK, 20), 100), 'linear');
    S.tag = tag; S.name = name; S.t = t; S.theta1 = theta1; S.v = vK / 3.6; S.mu = mu; S.ayTarget = a; S.win = win;
end

function y = smoothPath(k, t)
% piecewise path through key points [t, value]; each segment is a (1 - cos)/2 blend (zero slope at key points)
    y = zeros(size(t));
    for i = 1:size(k, 1) - 1
        in = t >= k(i, 1) & t <= k(i+1, 1);
        s = (t(in) - k(i, 1)) / max(k(i+1, 1) - k(i, 1), eps);
        y(in) = k(i, 2) + (k(i+1, 2) - k(i, 2)) * (1 - cos(pi * s)) / 2;
    end
    y(t > k(end, 1)) = k(end, 2);
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end

function s = g2s(a)
    s = strrep(sprintf('%+.2fg', a), '.', 'p');
    s = strrep(strrep(s, '+', 'pos'), '-', 'neg');
end

function s = dryLabel(v, a, sgn)
% DRY window label: v<km/h>a<g with p for the dot><l|r> (sgn > 0 = left), e.g. v40a0p2r
    dirs = 'rl';
    s = sprintf('v%da%s%s', v, strrep(sprintf('%g', a), '.', 'p'), dirs((sgn > 0) + 1));
end

%% ===================== Steady steering angle table (dry road, ideal assist) ============
function T = steadyAngleTable(P, ref)
    T.v  = (20:5:100)';
    T.ay = 0:0.01:0.4;
    T.th = zeros(numel(T.v), numel(T.ay));
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    for i = 1:numel(T.v)
        v = T.v(i) / 3.6; z = [0; 0; 0];
        for j = 2:numel(T.ay)
            ay = T.ay(j) * P.g;
            [z, ~, flag] = fsolve(@(z) res(P, z, v, ay), z, opt);
            assert(flag > 0, 'no dry-road steady state at %g km/h, %g g', T.v(i), T.ay(j));
            Td = interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', T.ay(j), T.v(i), 'linear');
            T.th(i, j) = P.n_st * z(3) + Td / P.K;
        end
    end
end

function r = res(P, z, v, ay)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    alpha_r = -z(1) + P.l_r * z(2) / v;
    Fyf = mf(P, alpha_f, 0.8 * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, 0.8 * P.F_zr, P.C_r);
    r = [(Fyf + Fyr) / (P.m * v) - z(2); P.l_f * Fyf - P.l_r * Fyr; (Fyf + Fyr) / P.m - ay];
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function P = loadPlant(modelDir)
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    P = struct();
    for grp = {'cum1', 'cum2'}
        fn = fieldnames(raw.(grp{1}));
        for i = 1:numel(fn)
            P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
        end
    end
    P.Iz = raw.cum3.Iz.value;
    L = P.l_f + P.l_r;
    P.F_zf = P.m * P.g * P.l_r / L;
    P.F_zr = P.m * P.g * P.l_f / L;
end
