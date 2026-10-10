function TC = test_cases(which)
%TEST_CASES The two standard test cases used for EVERY controller (Map, PID, SMC, RL, ...).
%
%   TC(1) 'TC1_dry_calibration'  dry road (mu = 0.8), speeds 20, 40, 60, 80, 100 km/h in turn; at every speed the
%         lateral acceleration target steps 0.1 -> 0.2 -> 0.3 g (0.1 -> 0.15 -> 0.18 g at 20 km/h, where the Plant
%         is limited to about 0.2 g), each level held 5 s; turning direction alternates between speeds. Measures the
%         steady accuracy on the dry road (the design condition of the conventional map).
%   TC(2) 'TC2_road'  one continuous drive of 150 s: curves, slalom and lane change, speed changes 50 -> 80 -> 100
%         -> 60 km/h, and friction changes while cornering (0.8 -> 0.3 ramp, 0.3 -> 0.8 step, 0.8 -> 0.5 step, and
%         0.8 -> 0.4 during sine steering).
%
%   The driver is a steering-angle source (Documents/Plant/plant.txt section 1.4). The angle is controller
%   INDEPENDENT: theta1(t) = sgn(a*) * theta1_ss(v(t), |a*(t)|), where a*(t) is the target lateral acceleration and
%   theta1_ss is the angle that gives a* in steady state on the dry road with T_s = T_d,ref (ideal assist):
%   theta1_ss = n_st*delta_f + T_d,ref/K. When mu drops the driver keeps the same angle (he does not know mu).
%   All changes are smooth ramps (1 - cos) except the friction steps.
%
%   test_cases('TK') returns ONLY the design case TK (not part of the standard set, not run by run_test_cases.m): used by EVERY controller to
%   choose its parameters (Documents/Shared/QuyChuan.txt part 3). Dry road with one mu step block, speed blocks 20, 60, 100 km/h; windows named
%   static_* (steady cornering 0.1-0.4 g), sine_*, small_*, mu_drop/mu_rise (see buildTK). S.blk lists the blocks (speed, t0, t1).
%
%   Fields of TC(k): tag, name, t [s] (1 ms grid), theta1 [rad], v [m/s], mu [-], ayTarget [g],
%   win (struct array: label, t0, t1) = windows where the mean e_T is reported.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
P   = loadPlant(modelDir);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
thTab = steadyAngleTable(P, ref);

if nargin > 0 && strcmp(which, 'TK')
    TC = buildTK(thTab);
    return;
end
TC = [buildTC1(thTab), buildTC2(thTab), buildTC3(thTab), buildTC4(thTab), buildTC5(thTab), buildTC6(thTab)];
end

%% ===================== TC1: dry-road calibration staircase =============
function S = buildTC1(thTab)
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
            win(end+1) = struct('label', sprintf('v%d_ay%s', speeds(i), g2s(sgn * a)), 't0', t0 + 5, 't1', t0 + 6); %#ok<AGROW>
            t0 = t0 + 6;
        end
        ka = [ka; t0 + 1.5, 0]; %#ok<AGROW>
        t0 = t0 + 2;
        kv = [kv; t0, speeds(i)]; %#ok<AGROW>
        sgn = -sgn;
    end
    tEnd = t0 + 3;
    S = assemble('TC1_dry_calibration', 'TC1 kiểm tra hiệu chỉnh trên đường khô', tEnd, kv, ka, [0 0.8; tEnd 0.8], [], thTab, win);
end

%% ===================== TC2: one continuous road drive ==================
function S = buildTC2(thTab)
    tEnd = 150;
    % speed [t, km/h] (smooth between key points)
    kv = [0 50; 25 50; 35 80; 85 80; 100 100; 120 100; 130 60; tEnd 60];
    % target lateral acceleration [t, g] (smooth between key points); sine segments added below
    ka = [0 0; 3 0; 4.5 0.2; 13 0.2; 15 0; 35 0; 37 -0.25; 50 -0.25; 52 0; 65 0; 67 0.15; 78 0.15; 80 0;
          100 0; 102 -0.2; 116 -0.2; 118 0; tEnd 0];
    % friction [t, mu]: ramp 0.8 -> 0.3 while cornering, steps elsewhere
    kmu = [0 0.8; 42 0.8; 43 0.3; 71.999 0.3; 72 0.8; 107.999 0.8; 108 0.5; 124.999 0.5; 125 0.8;
           136.999 0.8; 137 0.4; tEnd 0.4];
    sines = [15 25 0.15 0.25;      % slalom on the dry road at 50 km/h: [t0 t1 amplitude(g) frequency(Hz)]
             57 61 0.10 0.25;      % lane change (one period) on mu = 0.3 at 80 km/h
             130 145 0.20 0.3];    % sine steering at 60 km/h, mu 0.8 -> 0.4 at 137 s
    win = struct('label', {'dry_curve_0p2g_v50', 'slalom_dry_v50', 'curve_0p25g_v80_before_mu_drop', ...
                           'curve_0p25g_v80_mu_0p3', 'lane_change_mu_0p3_v80', 'curve_0p15g_v80_mu_0p3', ...
                           'curve_0p15g_v80_after_mu_0p8', 'curve_0p2g_v100_before_mu_drop', ...
                           'curve_0p2g_v100_mu_0p5', 'sine_v60_mu_0p8', 'sine_v60_mu_0p4'}, ...
                 't0', {11, 17, 40, 48, 57, 70, 76, 106, 114, 131, 139}, ...
                 't1', {13, 25, 42, 50, 61, 72, 78, 108, 116, 137, 145});
    S = assemble('TC2_road', 'TC2 chạy đường thực tế', tEnd, kv, ka, kmu, sines, thTab, win);
end

%% ===================== TC3: mu drop while cornering hard at high speed ==
function S = buildTC3(thTab)
% Danger: the driver holds a hard-cornering angle (a_y = 0.35 g at 100 km/h, dry) and does not know the road
% turns wet; mu steps 0.8 -> 0.3 while still cornering, right when over-assist is most dangerous (grip lowest,
% front tire closest to saturation).
    tEnd = 20;
    kv  = [0 100; tEnd 100];
    ka  = [0 0; 1 0.35; tEnd 0.35];
    kmu = [0 0.8; 5 0.8; 5.001 0.3; tEnd 0.3];
    win = struct('label', {'before_mu_drop', 'after_mu_drop_steady'}, 't0', {4, 18}, 't1', {5, 20});
    S = assemble('TC3_mu_drop_hard_corner', 'TC3 mu giảm đột ngột khi đang cua gấp ở tốc độ cao', tEnd, kv, ka, kmu, [], thTab, win);
end

%% ===================== TC4: wet patch during a hard lane change =========
function S = buildTC4(thTab)
% Danger: a short, sharp water puddle / patch of ice (mu 0.8 -> 0.2 for 0.4 s) right at the moment of peak
% steering demand of a hard lane-change maneuver (one sine cycle, 0.2 g, 80 km/h).
    tEnd = 12;
    kv  = [0 80; tEnd 80];
    ka  = [0 0; tEnd 0];
    sines = [3 5.5 0.2 0.4];    % [t0 t1 amplitude(g) frequency(Hz)], one cycle
    kmu = [0 0.8; 3.799 0.8; 3.8 0.2; 4.199 0.2; 4.2 0.8; tEnd 0.8];
    win = struct('label', {'before', 'during_puddle', 'after_lane_change'}, 't0', {2, 3.8, 7}, 't1', {3, 4.2, 8});
    S = assemble('TC4_wet_patch_lane_change', 'TC4 vũng nước/băng khi đang chuyển làn gấp', tEnd, kv, ka, kmu, sines, thTab, win);
end

%% ===================== TC5: continuous sine steering, high speed, low mu ====
function S = buildTC5(thTab)
% Danger: sustained lane-keeping-like corrections at high speed on a very slippery road (mu = 0.2), amplitude
% (0.15 g) kept within a_y,max(100 km/h, 0.2) = 0.2 g so the target stays reachable.
    tEnd = 25;
    kv  = [0 100; tEnd 100];
    ka  = [0 0; tEnd 0];
    sines = [2 22 0.15 0.3];    % 20 s, about 6 cycles
    kmu = [0 0.2; tEnd 0.2];
    win = struct('label', {'sine_transient', 'sine_sustained'}, 't0', {2, 10}, 't1', {6, 22});
    S = assemble('TC5_sine_high_speed_low_mu', 'TC5 lái sin liên tục ở tốc độ cao trên mặt đường rất trơn', tEnd, kv, ka, kmu, sines, thTab, win);
end

%% ===================== TC6: mu increase mid-corner ======================
function S = buildTC6(thTab)
% Reverse direction of R/TC3: road dries up while cornering (mu 0.3 -> 0.8). Checks the controller does not
% react strangely (overshoot, oscillation) to a SUDDEN INCREASE in available grip, not just a decrease.
    tEnd = 15;
    kv  = [0 60; tEnd 60];
    ka  = [0 0; 1 0.15; tEnd 0.15];
    kmu = [0 0.3; 5 0.3; 5.001 0.8; tEnd 0.8];
    win = struct('label', {'before_mu_rise', 'after_mu_rise_steady'}, 't0', {4, 13}, 't1', {5, 15});
    S = assemble('TC6_mu_rise_mid_corner', 'TC6 mu tăng đột ngột giữa cua', tEnd, kv, ka, kmu, [], thTab, win);
end

%% ===================== TK: design case shared by every controller ========
function S = buildTK(thTab)
% Design case of QuyChuan.txt part 3. The speed blocks cover the range of the standard cases (20, 60, 100 km/h); a_y levels cover 0.1-0.4 g
% wherever the Plant reaches them (20 km/h: about 0.2 g). Dry road mu = 0.8 except the mu step in the 60 km/h block. Per block (T = start):
%   staircase   each level: 1 s transition + 3 s hold; window static_* = last 1 s of the hold (settled: slow integrators are not mistaken for
%               steady error)                                                               20 km/h: 0.1 0.15 0.18 g; 60, 100 km/h: 0.1 0.2 0.3 0.4 g
%   sine        1.5 s down to the base level, 1 s hold, then 4 cycles of 0.5 Hz; window sine_* skips the first 0.5 s     base 0.1 +-0.05 g (20 km/h), 0.2 +-0.1 g
%   small       around the same base: +0.03 g then -0.03 g steps (small lane corrections); window small_* = 6 s
%   mu step     60 km/h only: hold 0.3 g, mu 0.8 -> 0.6 (4 s) -> 0.8; windows mu_drop, mu_rise = the 2 s after each step (response, not steady)
% The first 2 s of the case are never scored; the 1 s straight run at the end of each block carries the speed change.
    speeds = [20 60 100];
    levels = {[0.1 0.15 0.18], [0.1 0.2 0.3 0.4], [0.1 0.2 0.3 0.4]};
    aBase  = [0.1 0.2 0.2];          % base level of the sine and small corrections [g]
    aSine  = [0.05 0.1 0.1];         % sine amplitude [g]
    aMu    = 0.3;                    % level held during the mu step [g]
    muLow  = 0.6;
    kv = [0 speeds(1)]; ka = [0 0]; sines = []; kmu = [0 0.8];
    win = struct('label', {}, 't0', {}, 't1', {});
    blk = struct('speed', {}, 't0', {}, 't1', {});
    T = 0;
    for i = 1:numel(speeds)
        v = speeds(i); lv = levels{i}; b = aBase(i);
        if i > 1, kv = [kv; T - 1, speeds(i-1); T, v]; end %#ok<AGROW>
        t = T + 1;
        for k = 1:numel(lv)                                  % staircase
            if k == 1, ka = [ka; t, 0]; end                  %#ok<AGROW>
            ka = [ka; t + 1, lv(k); t + 4, lv(k)]; %#ok<AGROW>
            win(end+1) = struct('label', sprintf('static_v%d_a%s', v, g2s(lv(k))), 't0', t + 3, 't1', t + 4); %#ok<AGROW>
            t = t + 4;
        end
        ka = [ka; t + 1.5, b; t + 2.5, b]; %#ok<AGROW>        % sine
        sines = [sines; t + 2.5, t + 10.5, aSine(i), 0.5]; %#ok<AGROW>
        win(end+1) = struct('label', sprintf('sine_v%d', v), 't0', t + 3, 't1', t + 10.5); %#ok<AGROW>
        f = t + 10.5;                                         % small corrections
        ka = [ka; f + 1, b; f + 2.5, b; f + 3, b + 0.03; f + 4.5, b + 0.03; f + 5, b - 0.03; f + 6.5, b - 0.03; f + 7.5, b]; %#ok<AGROW>
        win(end+1) = struct('label', sprintf('small_v%d', v), 't0', f + 1.5, 't1', f + 7.5); %#ok<AGROW>
        t = f + 7.5;
        if v == 60                                            % mu step block
            m1 = t + 3.0; m2 = m1 + 4;
            ka = [ka; t + 1, aMu; m2 + 3, aMu]; %#ok<AGROW>
            kmu = [kmu; m1, 0.8; m1 + 0.001, muLow; m2, muLow; m2 + 0.001, 0.8]; %#ok<AGROW>
            win(end+1) = struct('label', 'mu_drop', 't0', m1, 't1', m1 + 2); %#ok<AGROW>
            win(end+1) = struct('label', 'mu_rise', 't0', m2, 't1', m2 + 2); %#ok<AGROW>
            t = m2 + 3;
        end
        ka = [ka; t + 1, 0]; %#ok<AGROW>
        Tend = t + 2;                                         % 1 s straight carries the speed change
        blk(end+1) = struct('speed', v, 't0', T, 't1', Tend); %#ok<AGROW>
        T = Tend;
    end
    tEnd = T;
    kv = [kv; tEnd, speeds(end)];
    ka = [ka; tEnd, 0];
    kmu = [kmu; tEnd, 0.8];
    S = assemble('TK_design', 'TK ca thiết kế chung cho mọi bộ điều khiển (đường khô, một bậc mu)', tEnd, kv, ka, kmu, sines, thTab, win);
    S.blk = blk;
end

%% ===================== Common assembly =================================
function S = assemble(tag, name, tEnd, kv, ka, kmu, sines, thTab, win)
    t = (0:0.001:tEnd)';
    vK = smoothPath(kv, t);
    a  = smoothPath(ka, t);
    for i = 1:size(sines, 1)
        in = t >= sines(i, 1) & t <= sines(i, 2);
        a(in) = a(in) + sines(i, 3) * sin(2*pi*sines(i, 4) * (t(in) - sines(i, 1)));
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

function s = g2s(a)
    s = strrep(sprintf('%+.2fg', a), '.', 'p');
    s = strrep(strrep(s, '+', 'pos'), '-', 'neg');
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
