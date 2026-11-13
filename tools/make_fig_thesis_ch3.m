% Figures 3.2 and 3.3 and the numbers of Section 3.2 of thesis chapter 3 (Documents/Thesis/luanvan.txt).
%   Hinh_3_2_Map.png            : the assist map M(v,|T_s|) of the Map controller at three speeds, with the dry-road calibration points it was built from
%   Hinh_3_3_Static.png         : graphical solution of the static balance T_s + M(v,T_s) = T_r at 60 km/h and 0.3 g for mu = 0.8 and 0.35
%   ch3_map_slopes.csv          : per speed, the largest natural slope dT_a/dT_s of the calibration points in 0.1-0.3 g
%   ch3_static_example.csv      : the static example of Section 3.2 (Table 3.1)
%   ch3_numbers.csv             : the other numbers quoted in Sections 3.1-3.3 (noise level, jumps of T_ref, column period, ...)
% Everything is computed with the functions of the Map controller (calibrate_map, map_table, map_eval, map_steady_state) from Model/shared/data/*.json;
% nothing is typed by hand. Vietnamese labels are read from the UTF-8 file make_fig_thesis_ch3_labels.json so that this file stays ASCII.
% The block diagrams of the chapter are made by make_fig_thesis_ch3_diagrams.py.
%
% Run: matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_ch3.m')"

repoDir  = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoDir, 'Model');
dataDir  = fullfile(modelDir, 'shared', 'data');
outDir   = fullfile(repoDir, 'Documents', 'Thesis', 'figures');
addpath(fullfile(modelDir, 'shared')); setup_paths;
lab = jsondecode(fileread(fullfile(repoDir, 'tools', 'make_fig_thesis_ch3_labels.json'), 'Encoding', 'UTF-8'));

P   = map_params();
J   = jsondecode(fileread(fullfile(dataDir, 'map.json'), 'Encoding', 'UTF-8'));
d   = J.design;                                   % K_max, T_s0 of the selected design
ref = jsondecode(fileread(fullfile(dataDir, 'ref.json'), 'Encoding', 'UTF-8'));
Cal = calibrate_map(false);                       % dry-road calibration points; false = do not write any file
tref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ay, v, 'linear');
muDry = 0.8; muWet = 0.35;                        % 0.35 is the low friction of the CALIB friction change
fprintf('K_max = %.5f, T_s0 = %.3f N.m\n', d.Kmax, d.Ts0);

%% natural slopes
nv = numel(Cal.v_kmh);
slopeMax = zeros(nv, 1); ayLo = zeros(nv, 1); ayHi = zeros(nv, 1); nPts = zeros(nv, 1);
for iv = 1:nv
    ay = Cal.ay_g{iv}; sl = Cal.slope{iv};
    inBand = ay >= 0.1 - 1e-9 & ay <= 0.3 + 1e-9;
    slopeMax(iv) = max(sl(inBand));
    ayLo(iv) = ay(1); ayHi(iv) = ay(end); nPts(iv) = numel(ay);
end
T1 = table(Cal.v_kmh, nPts, ayLo, ayHi, slopeMax, repmat(d.Kmax, nv, 1), slopeMax > d.Kmax, ...
    'VariableNames', {'v_kmh', 'n_points', 'ay_min_g', 'ay_max_g', 'max_natural_slope_0p1_0p3g', 'Kmax', 'slope_exceeds_Kmax'});
writetable(T1, fullfile(outDir, 'ch3_map_slopes.csv'));
fprintf('natural slope in 0.1-0.3 g: min %.2f (v = %d km/h), max %.2f (v = %d km/h); exceeds K_max at %d of %d speeds\n', ...
    min(slopeMax), Cal.v_kmh(slopeMax == min(slopeMax)), max(slopeMax), Cal.v_kmh(slopeMax == max(slopeMax)), sum(slopeMax > d.Kmax), nv);

%% static example (Table 3.1): v = 60 km/h, a_y = 0.1, 0.2, 0.3 g, mu 0.8 -> 0.35
vEx = 60; ivEx = find(Cal.v_kmh == vEx);
Mex = map_table(Cal, ivEx, d.Kmax, d.Ts0);
ayEx = [0.1 0.2 0.3];
rows = struct('v_kmh', {}, 'ay_g', {}, 'Tref', {}, 'Tr_dry', {}, 'Tr_wet', {}, 'dTr', {}, 'Ts_dry', {}, 'Ts_wet', {}, 'dTs_exact', {}, ...
    's_dry', {}, 's_mean', {}, 'dTs_lin', {}, 'ratio_exact', {}, 'ratio_lin', {});
for k = 1:numel(ayEx)
    ay = ayEx(k);
    Tref = tref(vEx, ay);
    TrD = map_steady_state(P, vEx / 3.6, ay * P.g, muDry).T_r;
    TrW = map_steady_state(P, vEx / 3.6, ay * P.g, muWet).T_r;
    solve = @(Tr) fzero(@(x) x + map_eval(Mex, x) - Tr, [0, Tr]);   % T_s + M(T_s) = T_r has one root: both terms are nondecreasing
    TsD = solve(TrD); TsW = solve(TrW);
    h = 1e-5;
    sgn = sign(TsW - TsD);                      % T_s moves in this direction; the map has kinks, so take the slope on that side
    sDry = sgn * (map_eval(Mex, TsD + sgn * h) - map_eval(Mex, TsD)) / h;
    sMean = (map_eval(Mex, TsW) - map_eval(Mex, TsD)) / (TsW - TsD);
    dTr = TrW - TrD; dTs = TsW - TsD;
    rows(k) = struct('v_kmh', vEx, 'ay_g', ay, 'Tref', Tref, 'Tr_dry', TrD, 'Tr_wet', TrW, 'dTr', dTr, 'Ts_dry', TsD, 'Ts_wet', TsW, ...
        'dTs_exact', dTs, 's_dry', sDry, 's_mean', sMean, 'dTs_lin', dTr / (1 + sDry), 'ratio_exact', dTs / dTr, 'ratio_lin', 1 / (1 + sDry));
    % exact identity: dTs = dTr/(1 + s_mean), and 0 <= s_mean <= K_max
    assert(abs(dTs - dTr / (1 + sMean)) < 1e-9 && sMean >= -1e-9 && sMean <= d.Kmax + 1e-9);
end
T2 = struct2table(rows);
writetable(T2, fullfile(outDir, 'ch3_static_example.csv'));
disp(T2);

%% scalars quoted in the text (ch3_numbers.csv)
sens = jsondecode(fileread(fullfile(dataDir, 'sensors.json'), 'Encoding', 'UTF-8'));
dT   = sens.signals.T_s.resolution;               % quantisation step of T_s,m [N.m]; the noise std is set equal to one step (Table 2.3)
sigT = sqrt(dT^2 + dT^2 / 12);                    % noise plus quantisation error, std of T_s,m - T_s
% monotone rows of the map table (the text says the table does not decrease in |T_s| at all 17 speeds)
nMono = 0;
for iv = 1:nv
    Mi = map_table(Cal, iv, d.Kmax, d.Ts0);
    nMono = nMono + all(diff(Mi.Ta) >= -1e-12);
end
% jumps of T_ref caused by one quantisation step of the measured acceleration (0.01 g) and speed (1 km/h)
ayStepG = sens.signals.a_y.resolution / P.g;      % 0.01 g
ayAll = 0:0.001:(0.4 - ayStepG);
jumpAy = zeros(nv, 1);
for iv = 1:nv
    jumpAy(iv) = max(tref(Cal.v_kmh(iv), ayAll + ayStepG) - tref(Cal.v_kmh(iv), ayAll));
end
[vv, aa] = meshgrid(20:1:99, 0:0.005:0.4);
jumpV = max(max(abs(tref(vv + 1, aa) - tref(vv, aa))));
% column held by the driver: natural period and damping ratio of J_col*theta2'' + C_col*theta2' + K*theta2 = 0
colPeriod = 2 * pi * sqrt(P.J_col / P.K);
colZeta   = P.C_col / (2 * sqrt(P.K * P.J_col));
% where the slope limit bites: last calibration point at 60 km/h
Mlast = Mex.Ta(end); TaCalLast = Cal.Ta{ivEx}(end); ayLast = Cal.ay_g{ivEx}(end);
% what the static example needs: slope for |dTs| <= 0.05 N.m at 0.3 g, and the noise passed by the map
dTsTarget = 0.05;
sNeeded = abs(rows(3).dTr) / dTsTarget - 1;
% analytic dry-road static error of Map over the 26 static windows of CALIB (0.10 and 0.18 g at 20 km/h; 0.10, 0.20, 0.30 g at 30..100 km/h); friction ignored
erA = [];
for vA = 20:10:100
    if vA == 20, aysA = [0.10 0.18]; else, aysA = [0.10 0.20 0.30]; end
    ivA = find(Cal.v_kmh == vA); MA = map_table(Cal, ivA, d.Kmax, d.Ts0);
    for ayA = aysA
        TrefA = tref(vA, ayA); TrA = map_steady_state(P, vA / 3.6, ayA * P.g, muDry).T_r;
        TsA = fzero(@(x) x + map_eval(MA, x) - TrA, [0, TrA]);
        erA(end + 1) = 100 * abs(TsA - TrefA) / TrefA; %#ok<AGROW>
    end
end
names = {'Ts_noise_std_total_Nm'; 'Ts0_over_noise'; 'Tref_jump_ay_step_min_Nm'; 'Tref_jump_ay_step_max_Nm'; 'Tref_jump_v_step_max_Nm'; ...
    'jump_over_noise_min'; 'jump_over_noise_max'; 'column_period_s'; 'column_zeta'; 'map_rows_nondecreasing'; 'n_speeds'; ...
    'map_last_ay_g_60kmh'; 'map_last_M_Nm_60kmh'; 'map_last_Tacal_Nm_60kmh'; 'friction_shift_Nm'; ...
    's_needed_for_0p05'; 'noise_at_Kmax_Nm'; 'noise_at_s_needed_Nm'; 'slope_min'; 'slope_max'; 'Kmax'; 'static_erel_max_analytic_pct'; 'n_static_windows_analytic'};
vals = [sigT; d.Ts0 / sigT; min(jumpAy); max(jumpAy); jumpV; min(jumpAy) / sigT; max(jumpAy) / sigT; colPeriod; colZeta; nMono; nv; ...
    ayLast; Mlast; TaCalLast; P.T_f / (1 + d.Kmax); sNeeded; sigT * d.Kmax; sigT * sNeeded; min(slopeMax); max(slopeMax); d.Kmax; max(erA); numel(erA)];
T3 = table(names, vals, 'VariableNames', {'quantity', 'value'});
writetable(T3, fullfile(outDir, 'ch3_numbers.csv'));
disp(T3);

set(groot, 'defaultAxesFontSize', 12, 'defaultLegendFontSize', 10);
co = get(groot, 'defaultAxesColorOrder');

%% Figure 3.2: the assist map at three speeds
fig = figure('Visible', 'off', 'Position', [100 100 640 470]);
axA = axes(fig); hold(axA, 'on'); grid(axA, 'on'); box(axA, 'on');
speeds = [20 60 100];
tsGrid = linspace(0, 3.6, 3601)';
patch(axA, [0 d.Ts0 d.Ts0 0], [0 0 8 8], [0.88 0.88 0.88], 'EdgeColor', 'none', 'HandleVisibility', 'off');
hLine = gobjects(1, numel(speeds));
for k = 1:numel(speeds)
    iv = find(Cal.v_kmh == speeds(k));
    M = map_table(Cal, iv, d.Kmax, d.Ts0);
    hLine(k) = plot(axA, tsGrid, map_eval(M, tsGrid), 'Color', co(k, :), 'LineWidth', 1.8, 'DisplayName', sprintf('%d%s', speeds(k), lab.kmh));
    plot(axA, Cal.Ts{iv}, Cal.Ta{iv}, ':', 'Color', co(k, :), 'LineWidth', 1.6, 'HandleVisibility', 'off');
end
hA = plot(axA, NaN, NaN, 'k-', 'LineWidth', 1.4, 'DisplayName', lab.legend_map);
hB = plot(axA, NaN, NaN, 'k:', 'LineWidth', 1.6, 'DisplayName', lab.legend_cal);
text(axA, d.Ts0 / 2, 3.8, lab.dead_zone, 'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', [0.35 0.35 0.35]);
xlabel(axA, lab.ts_xlabel_abs); ylabel(axA, lab.ta_ylabel);
xlim(axA, [0 3.6]); ylim(axA, [0 8]);
legend(axA, [hLine hA hB], 'Location', 'northwest');
exportgraphics(fig, fullfile(outDir, 'Hinh_3_2_Map.png'), 'Resolution', 200);
close(fig);

%% Figure 3.3: graphical solution of T_s + M(v,T_s) = T_r, v = 60 km/h, a_y = 0.3 g
fig = figure('Visible', 'off', 'Position', [100 100 640 470]);
axB = axes(fig); hold(axB, 'on'); grid(axB, 'on'); box(axB, 'on');
r = rows(end);                                    % a_y = 0.3 g
x = linspace(2.3, 3.0, 701)';
c1 = co(1, :); c2 = co(2, :);
plot(axB, x, map_eval(Mex, x), 'Color', [0 0 0], 'LineWidth', 1.8, 'DisplayName', lab.legend_curve);
plot(axB, x, r.Tr_dry - x, '-', 'Color', c1, 'LineWidth', 1.6, 'DisplayName', sprintf('%s%.1f', lab.legend_line, muDry));
plot(axB, x, r.Tr_wet - x, '-', 'Color', c2, 'LineWidth', 1.6, 'DisplayName', sprintf('%s%.2f', lab.legend_line, muWet));
xline(axB, r.Tref, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');
text(axB, r.Tref + 0.01, 6.55, 'T_{ref}', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 11, 'Color', [0.3 0.3 0.3]);
plot(axB, r.Ts_dry, map_eval(Mex, r.Ts_dry), 'o', 'MarkerFaceColor', c1, 'MarkerEdgeColor', 'k', 'MarkerSize', 7, 'HandleVisibility', 'off');
plot(axB, r.Ts_wet, map_eval(Mex, r.Ts_wet), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', 'k', 'MarkerSize', 7, 'HandleVisibility', 'off');
yLow = 1.6;
plot(axB, [r.Ts_wet r.Ts_dry], [yLow yLow], 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
plot(axB, r.Ts_wet, yLow, 'k<', 'MarkerFaceColor', 'k', 'MarkerSize', 4, 'HandleVisibility', 'off');
plot(axB, r.Ts_dry, yLow, 'k>', 'MarkerFaceColor', 'k', 'MarkerSize', 4, 'HandleVisibility', 'off');
plot(axB, [r.Ts_wet r.Ts_wet], [yLow map_eval(Mex, r.Ts_wet)], ':', 'Color', c2, 'HandleVisibility', 'off');
plot(axB, [r.Ts_dry r.Ts_dry], [yLow map_eval(Mex, r.Ts_dry)], ':', 'Color', c1, 'HandleVisibility', 'off');
text(axB, (r.Ts_wet + r.Ts_dry) / 2, yLow + 0.12, sprintf('%s%.3f%s', lab.dTs_label, r.dTs_exact, lab.unit_Nm), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 1);
xA = 2.42;                                        % vertical arrow showing the drop of T_r at fixed T_s
yTop = r.Tr_dry - xA; yBot = r.Tr_wet - xA;
plot(axB, [xA xA], [yBot yTop], 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
plot(axB, xA, yBot, 'kv', 'MarkerFaceColor', 'k', 'MarkerSize', 4, 'HandleVisibility', 'off');
text(axB, xA + 0.02, (yTop + yBot) / 2, sprintf('%s%.3f%s', lab.dTr_label, r.dTr, lab.unit_Nm), 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 10.5);
xlabel(axB, lab.ts_xlabel); ylabel(axB, lab.ta_ylabel);
xlim(axB, [2.3 3.0]); ylim(axB, [1.5 6.8]);
legend(axB, 'Location', 'northwest');
exportgraphics(fig, fullfile(outDir, 'Hinh_3_3_Static.png'), 'Resolution', 200);
close(fig);
disp('make_fig_thesis_ch3: done');
