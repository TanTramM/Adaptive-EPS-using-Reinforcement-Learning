function export_map_results()
%EXPORT_MAP_RESULTS Figures and tables of the conventional EPS assist controller (baseline) for
%Documents/Map_6_8/map.txt, saved in Result/Map_6_8/.
%
%   1. Map_assist_curves_by_speed.png            torque map T_a(|T_s|) per speed with the calibration pairs
%   2. Map_phase_margin_vs_map_slope.png (+csv)  phase margin of the linearized loop vs map slope Kv:
%                                                10 ms and 1 ms without compensator, 1 ms with the lead stage
%   3. Map_dry_road_steady_error.png (+csv)      steady e_T = T_s - T_d,ref at mu = 0.8 vs a_y, designed map
%                                                (curve) and, for comparison, the linear map with dead band of [4]
%   4. TestCases/Map_TC<n>_*, Map_test_case_metrics.csv
%                                                closed loop (Model_Map_6_8_s) on the standard test cases TC1-TC6 shared
%                                                by every controller (Sim/script/test_cases.m, run_test_cases.m)
%   5. Map_over_assist_vs_lateral_accel.png (+csv) over-assist caused by mu: steady (e_T,after - e_T,before)/T_d,ref
%                                                after mu drops (0.8 -> 0.5, 0.8 -> 0.3) with the steering wheel
%                                                angle held, vs a_y before the drop (e_T,before = dry-road error)
%
%   Run first: >> run('<Model>/load_map_6_8.m'), build_map, build_closed_loop('Map_6_8') (Model_Map_6_8_s.mdl must exist).

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
outDir = result_dir('Map_6_8', 'Calibration');
oaDir  = result_dir('Map_6_8', 'OverAssist');
warning('off', 'Control:analysis:MarginUnstable');

mp  = jsondecode(fileread(fullfile(modelDir, 'data', 'map_6_8.json')));
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
P   = loadPlant(modelDir);
vBp = mp.v_breakpoints_kmh(:)';  tsBp = mp.Ts_breakpoints_Nm(:)';  tab = mp.Ta_table_Nm;
Ts0 = mp.Ts0.value;
tdref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ...
    min(max(ay, 0), 0.4), min(max(v, 20), 100), 'linear');
Mstat = @(v, Ts) sign(Ts) .* interp2(tsBp, vBp, tab, min(abs(Ts), tsBp(end)), min(max(v, 20), 100), 'linear');
speeds = [20 40 60 80 100];
col = lines(numel(speeds));

%% 1. assist curves
f = figure('Visible', 'off', 'Position', [100 100 760 480]); hold on; grid on; box on;
for i = 1:numel(speeds)
    j = find(vBp == speeds(i));
    plot(tsBp, tab(j, :), '-', 'Color', col(i, :), 'LineWidth', 1.6, 'DisplayName', sprintf('%d km/h', speeds(i)));
    c = mp.calibration(j);
    k = 1:4:numel(c.Ts_Nm);
    plot(c.Ts_Nm(k), c.Ta_Nm(k), 'o', 'Color', col(i, :), 'MarkerSize', 4, 'HandleVisibility', 'off');
end
xline(Ts0, '--k', 'HandleVisibility', 'off');
text(Ts0 + 0.05, 0.4, sprintf('vÃ¹ng cháº¿t %.1f N.m', Ts0), 'FontSize', 9);
xlim([0 4]); xlabel('|T_s| [N.m]'); ylabel('T_a [N.m]');
title('Báº£n Ä‘á»“ trá»£ lá»±c theo váº­n tá»‘c (Ä‘Æ°á»ng) vÃ  cáº·p hiá»‡u chá»‰nh á»Ÿ \mu = 0.8 (Ä‘iá»ƒm)');
legend('Location', 'southeast');
exportgraphics(f, fullfile(outDir, 'Map_assist_curves_by_speed.png'), 'Resolution', 150); close(f);

%% 2. phase margin vs map slope (with the motor lag of the Actuator block)
kr = mp.lead.k_r_Nm_per_rad;
wm = mp.lead.motor_wm_rad_s;
Gc = tf(P.K, [P.J_col, P.C_col, P.K + kr]) * tf(wm, [1 wm]);
HLo = tf(mp.lead.num(:)', mp.lead.den(:)', mp.Ts_ctrl.value);       % lead of the low-speed tier (K_max of the low speeds)
HHi = tf(mp.lead_hi.num(:)', mp.lead_hi.den(:)', mp.Ts_ctrl.value); % lead of the high-speed tier
KloT = mp.lead.K_max;  KhiT = mp.lead_hi.K_max;
Kvs = linspace(0.5, KloT, 40);
pm = nan(numel(Kvs), 4); st = false(numel(Kvs), 4);
cases = {c2d(Gc, 0.01, 'zoh'), c2d(Gc, 0.001, 'zoh'), HLo * c2d(Gc, 0.001, 'zoh'), HHi * c2d(Gc, 0.001, 'zoh')};
for i = 1:numel(Kvs)
    for c = 1:4
        if c == 4 && Kvs(i) > KhiT, continue; end      % the high-speed lead is only used up to its own K_max
        L = Kvs(i) * cases{c};
        [~, pm(i, c)] = margin(L);
        st(i, c) = isstable(feedback(L, 1));
    end
end
f = figure('Visible', 'off', 'Position', [100 100 760 440]); hold on; grid on; box on;
lbl = {'T_{ctl} = 10 ms, khÃ´ng bÃ¹', 'T_{ctl} = 1 ms, khÃ´ng bÃ¹', sprintf('1 ms, lead váº­n tá»‘c tháº¥p (K_{max} = %g)', KloT), ...
       sprintf('1 ms, lead váº­n tá»‘c cao (K_{max} = %g)', KhiT)};
sty = {'-r', '-b', '-k', '--m'};
for c = 1:4
    plot(Kvs, pm(:, c), sty{c}, 'LineWidth', 1.6, 'DisplayName', lbl{c});
end
yline(45, '--', '45^o', 'HandleVisibility', 'off'); yline(0, ':k', 'HandleVisibility', 'off');
xlabel('Äá»™ dá»‘c báº£n Ä‘á»“ K_v = dT_a/dT_s'); ylabel('Äá»™ dá»± trá»¯ pha [Ä‘á»™]');
title('Äá»™ dá»± trá»¯ pha cá»§a vÃ²ng trá»£ lá»±c tuyáº¿n tÃ­nh hÃ³a, cÃ³ motor (trá»¥c lÃ¡i Ä‘ang trÆ°á»£t, khÃ´ng ma sÃ¡t)');
legend('Location', 'southwest');
exportgraphics(f, fullfile(outDir, 'Map_phase_margin_vs_map_slope.png'), 'Resolution', 150); close(f);
writetable(array2table([Kvs(:) pm st], 'VariableNames', {'Kv', 'PM_10ms_nocomp_deg', 'PM_1ms_nocomp_deg', ...
    'PM_1ms_lead_low_deg', 'PM_1ms_lead_high_deg', 'stable_10ms_nocomp', 'stable_1ms_nocomp', 'stable_1ms_lead_low', 'stable_1ms_lead_high'}), ...
    fullfile(outDir, 'Map_phase_margin_vs_map_slope.csv'));
kStab10 = Kvs(find(~st(:, 1), 1));
fprintf('2. 10 ms without compensator: first unstable slope %.2f; 1 ms without: min PM %.1f deg; lead K_max %g: min PM %.1f deg; lead K_max %g: min PM %.1f deg\n', ...
    kStab10, min(pm(:, 2)), KloT, min(pm(:, 3)), KhiT, min(pm(:, 4), [], 'omitnan'));

%% 3. dry-road steady error (designed curve vs linear map of [4])
rows = [];
for j = 1:numel(vBp)
    v = vBp(j);
    ayL = ref.Ta_max.a_y_lim_g(j);
    ays = unique([0.02:0.01:ayL, ayL]);
    z = [0; 0; 0.001];
    TaTop = ref.Ta_max.Ta_max_Nm(j); TsTop = ref.Ta_max.T_d_ref_top_Nm(j); KvLin = TaTop / (TsTop - Ts0);
    Mlin = @(Ts) min(max(Ts - Ts0, 0) * KvLin, TaTop);
    for i = 1:numel(ays)
        [Tr, z] = roadTorque(P, v / 3.6, ays(i) * P.g, 0.8, z);
        Td = tdref(v, ays(i));
        TsC = fzero(@(x) x + Mstat(v, x) - Tr, [0 Tr]);
        TsL = fzero(@(x) x + Mlin(x) - Tr, [0 Tr]);
        rows(end+1, :) = [v, ays(i), Tr, Td, TsC, TsC - Td, TsL, TsL - Td]; %#ok<AGROW>
    end
end
T3 = array2table(rows, 'VariableNames', {'v_kmh', 'a_y_g', 'T_r_Nm', 'T_d_ref_Nm', 'T_s_map_Nm', 'e_T_map_Nm', ...
    'T_s_linear_Nm', 'e_T_linear_Nm'});
writetable(T3, fullfile(outDir, 'Map_dry_road_steady_error.csv'));
f = figure('Visible', 'off', 'Position', [100 100 900 420]);
for p = 1:2
    subplot(1, 2, p); hold on; grid on; box on;
    for i = 1:numel(speeds)
        s = rows(:, 1) == speeds(i);
        plot(rows(s, 2), rows(s, 4 + 2*p), '-', 'Color', col(i, :), 'LineWidth', 1.5, 'DisplayName', sprintf('%d km/h', speeds(i)));
    end
    xline(0.1, ':k', 'HandleVisibility', 'off'); yline(0, '-k', 'HandleVisibility', 'off');
    xlabel('a_y [g]'); ylabel('e_T = T_s - T_{d,ref} [N.m]'); ylim([-1.6 1]);
    if p == 1, title('Báº£n Ä‘á»“ thiáº¿t káº¿ (Ä‘Æ°á»ng cong)'); else, title('Báº£n Ä‘á»“ tuyáº¿n tÃ­nh cÃ³ vÃ¹ng cháº¿t [4]'); end
    if p == 1, legend('Location', 'southeast'); end
end
exportgraphics(f, fullfile(outDir, 'Map_dry_road_steady_error.png'), 'Resolution', 150); close(f);
in1 = rows(:, 2) >= 0.1 - 1e-9 & rows(:, 2) <= 0.3 + 1e-9;
lo = rows(:, 2) < 0.1 - 1e-9;  hi = rows(:, 2) > 0.3 + 1e-9;
fprintf(['3. dry road: designed map |e_T| <= %.3f N.m for 0.1-0.3 g; below 0.1 g from %.3f to %.3f N.m; ' ...
    'above 0.3 g from %.3f to %.3f N.m; linear map min %.3f N.m\n'], max(abs(rows(in1, 6))), ...
    min(rows(lo, 6)), max(rows(lo, 6)), min(rows(hi, 6)), max(rows(hi, 6)), min(rows(:, 8)));

%% 4. closed loop: the two standard test cases shared by every controller (Sim/script/test_cases.m)
addpath(fullfile(modelDir, 'Sim', 'script'));
disp(run_test_cases('Map_6_8'));

%% 5. over-assist of the map vs lateral acceleration (steady state, angle held, mu drops from 0.8)
ayList = 0.05:0.025:0.3;  muAfter = [0.5 0.3];  vList = [40 60 100];
rows5 = [];
for v = vList
    for ay0 = ayList
        th = holdAngle(P, v, ay0, Mstat);
        [~, z] = roadTorque(P, v / 3.6, ay0 * P.g, 0.8, [0; 0; 0.001]);
        x0 = [z(1); z(2); P.n_st * z(3)];
        [xb, okb] = closedSteady(P, th, v, 0.8, Mstat, x0);
        assert(okb, 'no dry-road steady state at %g km/h, %g g', v, ay0);
        [Fyf, Fyr] = tire(P, xb(3), xb(1), xb(2), v / 3.6, 0.8);
        eb = P.K * (th - xb(3)) - tdref(v, (Fyf + Fyr) / P.m / P.g);
        for mu = muAfter
            [x, ok] = closedSteady(P, th, v, mu, Mstat, xb);
            if ~ok, rows5(end+1, :) = [v, ay0, eb, mu, nan(1, 6)]; continue; end %#ok<AGROW>
            [Fyf, Fyr, Tr] = tire(P, x(3), x(1), x(2), v / 3.6, mu);
            Ts = P.K * (th - x(3)); ay = (Fyf + Fyr) / P.m / P.g; Td = tdref(v, ay);
            rows5(end+1, :) = [v, ay0, eb, mu, ay, Tr, Ts, Td, Ts - Td, 100 * (Ts - Td - eb) / Td]; %#ok<AGROW>
        end
    end
end
T5 = array2table(rows5, 'VariableNames', {'v_kmh', 'a_y_before_g', 'e_T_before_Nm', 'mu_after', 'a_y_after_g', ...
    'T_r_after_Nm', 'T_s_after_Nm', 'T_d_ref_after_Nm', 'e_T_after_Nm', 'over_assist_pct'});
writetable(T5, fullfile(oaDir, 'Map_over_assist_vs_lateral_accel.csv'));
f = figure('Visible', 'off', 'Position', [100 100 900 420]);
for p = 1:2
    subplot(1, 2, p); hold on; grid on; box on;
    for i = 1:numel(vList)
        s = rows5(:, 1) == vList(i) & rows5(:, 4) == muAfter(p);
        plot(rows5(s, 2), rows5(s, 10), '-o', 'LineWidth', 1.5, 'MarkerSize', 4, ...
            'DisplayName', sprintf('%d km/h', vList(i)));
    end
    yline(0, '-k', 'HandleVisibility', 'off');
    xlabel('a_y trÆ°á»›c khi \mu giáº£m [g]'); ylabel('(e_{T,sau} - e_{T,trÆ°á»›c}) / T_{d,ref} [%]');
    title(sprintf('\\mu: 0.8 \\rightarrow %.1f, giá»¯ gÃ³c vÃ´-lÄƒng', muAfter(p)));
    if p == 1, legend('Location', 'southwest'); end
end
exportgraphics(f, fullfile(oaDir, 'Map_over_assist_vs_lateral_accel.png'), 'Resolution', 150); close(f);
disp(T5(T5.v_kmh == 60, :));
fprintf('Results written to %s (Calibration), %s (OverAssist), %s (TestCases)\n', outDir, oaDir, result_dir('Map_6_8', 'TestCases'));
end

function [x, ok] = closedSteady(P, th, vKmh, mu, Mstat, x0)
% steady state of the plant with the map in the loop, steering wheel angle th held; x = [beta; gamma; theta2]
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-12, 'StepTolerance', 1e-12);
    v = vKmh / 3.6;
    fun = @(x) closedRes(P, x, th, v, vKmh, mu, Mstat);
    [x, ~, flag] = fsolve(fun, x0, opt);
    ok = flag > 0 && norm(fun(x)) < 1e-8;
end

function r = closedRes(P, x, th, v, vKmh, mu, Mstat)
    [Fyf, Fyr, Tr] = tire(P, x(3), x(1), x(2), v, mu);
    Ts = P.K * (th - x(3));
    r = [(Fyf + Fyr) / (P.m * v) - x(2); (P.l_f * Fyf - P.l_r * Fyr) / P.Iz; Tr - Mstat(vKmh, Ts) - Ts];
end

function [Fyf, Fyr, Tr] = tire(P, theta2, beta, gamma, v, mu)
    delta_f = theta2 / P.n_st;
    alpha_f = delta_f - beta - P.l_f * gamma / v;
    alpha_r = -beta + P.l_r * gamma / v;
    Fyf = mf(P, alpha_f, mu * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, mu * P.F_zr, P.C_r);
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    Tr = e_p / P.n_st * Fyf;
end

%% ===================== helpers =====================
function th = holdAngle(P, vKmh, ayG, Mstat)
% steering wheel angle that gives a_y = ayG on the dry road in steady state with the map in the loop
    [Tr, z] = roadTorque(P, vKmh / 3.6, ayG * P.g, 0.8, [0; 0; 0.001]);
    Ts = fzero(@(x) x + Mstat(vKmh, x) - Tr, [0 Tr]);
    th = P.n_st * z(3) + Ts / P.K;
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

function [Tr, z] = roadTorque(P, v, ay, mu, z0)
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    [z, ~, flag] = fsolve(@(z) res(P, z, v, mu, ay), z0, opt);
    assert(flag > 0, 'no steady state at v = %g m/s, a_y = %g m/s^2', v, ay);
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    Tr = e_p / P.n_st * mf(P, alpha_f, mu * P.F_zf, P.C_alpha_f);
end

function r = res(P, z, v, mu, ay)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    alpha_r = -z(1) + P.l_r * z(2) / v;
    Fyf = mf(P, alpha_f, mu * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, mu * P.F_zr, P.C_r);
    r = [(Fyf + Fyr) / (P.m * v) - z(2); P.l_f * Fyf - P.l_r * Fyr; (Fyf + Fyr) / P.m - ay];
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end
