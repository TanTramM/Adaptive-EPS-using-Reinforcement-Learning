% Figures 4.1 and 4.2 and the numbers of thesis chapter 4 (Documents/Thesis/luanvan.txt).
%   Hinh_4_1_CALIB.png     : the CALIB sequence (140 s): speed, friction coefficient and steering-wheel angle, with the 68 scoring windows
%                            (Result/Compare/CALIB_profile/CALIB_profile.csv and CALIB_windows.csv)
%   Hinh_4_2_Pareto.png    : common-seed Pareto fronts of Map, PID and MapPID (Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv);
%                            the selected designs are read from the 'design' field of Model/shared/data/map.json, pid.json, mappid.json
%   ch4_numbers.csv        : counts per group of windows, candidates and fronts (Table 4.3), and the profile numbers quoted in the text
%   ch4_selected.csv       : the selected designs (Tables 4.4 and 4.5)
% Nothing is typed by hand. Vietnamese labels come from the UTF-8 file make_fig_thesis_ch4_labels.json so that this file stays ASCII.
% (The paper's Fig. 7 was drawn by tools/make_fig_section4.py with matplotlib; the thesis redraws it here in MATLAB.)
%
% Run: matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_ch4.m')"

repoDir = fileparts(fileparts(mfilename('fullpath')));
resDir  = fullfile(repoDir, 'Result', 'Compare');
dataDir = fullfile(repoDir, 'Model', 'shared', 'data');
outDir  = fullfile(repoDir, 'Documents', 'Thesis', 'figures');
lab = jsondecode(fileread(fullfile(repoDir, 'tools', 'make_fig_thesis_ch4_labels.json'), 'Encoding', 'UTF-8'));
set(groot, 'defaultAxesFontSize', 12, 'defaultLegendFontSize', 10);
co = get(groot, 'defaultAxesColorOrder');

%% CALIB profile
P = readtable(fullfile(resDir, 'CALIB_profile', 'CALIB_profile.csv'));
W = readtable(fullfile(resDir, 'CALIB_profile', 'CALIB_windows.csv'));
grp = regexprep(W.label, '_.*$', '');                         % static, trans, sine, mu
isStatic = strcmp(grp, 'static'); isDyn = strcmp(grp, 'trans') | strcmp(grp, 'sine'); isMu = strcmp(grp, 'mu');
dur = W.t1 - W.t0;
fprintf('CALIB: %.0f s, %d windows (static %d, entry %d, sine %d, mu %d); durations static %g s, entry %g s, sine %g s, mu %g s\n', ...
    max(P.t), height(W), sum(isStatic), sum(strcmp(grp, 'trans')), sum(strcmp(grp, 'sine')), sum(isMu), ...
    sum(dur(isStatic)), sum(dur(strcmp(grp, 'trans'))), sum(dur(strcmp(grp, 'sine'))), sum(dur(isMu)));

fig = figure('Visible', 'off', 'Position', [100 100 900 650]);
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile; plot(ax1, P.t, P.v_kmh, 'LineWidth', 1.5); grid(ax1, 'on'); box(ax1, 'on');
ylabel(ax1, lab.v_ylabel); xlim(ax1, [0 140]); ylim(ax1, [0 110]); set(ax1, 'XTickLabel', []);
ax2 = nexttile; plot(ax2, P.t, P.mu, 'LineWidth', 1.5); grid(ax2, 'on'); box(ax2, 'on');
ylabel(ax2, lab.mu_ylabel); xlim(ax2, [0 140]); ylim(ax2, [0.3 0.85]); set(ax2, 'XTickLabel', []);
ax3 = nexttile; hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
yl = [-80 160];
colWin = {co(1, :), co(2, :), co(3, :)};
masks = {isStatic, isDyn, isMu};
for k = 1:3
    idx = find(masks{k});
    for j = idx'
        patch(ax3, [W.t0(j) W.t1(j) W.t1(j) W.t0(j)], [yl(1) yl(1) yl(2) yl(2)], colWin{k}, 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end
plot(ax3, P.t, P.theta1_deg, 'k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
h1 = patch(ax3, NaN, NaN, colWin{1}, 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', lab.legend_static);
h2 = patch(ax3, NaN, NaN, colWin{2}, 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', lab.legend_dyn);
h3 = patch(ax3, NaN, NaN, colWin{3}, 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', lab.legend_mu);
ylabel(ax3, lab.th_ylabel); xlabel(ax3, lab.t_xlabel); xlim(ax3, [0 140]); ylim(ax3, yl);
lgd = legend(ax3, [h1 h2 h3], 'NumColumns', 3); lgd.Layout.Tile = 'south';       % legend below the three panels so that it hides no data
linkaxes([ax1 ax2 ax3], 'x');
exportgraphics(fig, fullfile(outDir, 'Hinh_4_1_CALIB.png'), 'Resolution', 200);
close(fig);

%% Pareto fronts and the selected designs
ctrls = {'Map', 'PID', 'MapPID'};
mark = {'s', '^', 'o'};
colr = {co(1, :), co(2, :), co(5, :)};
sel = struct();
for k = 1:3
    J = jsondecode(fileread(fullfile(dataDir, [lower(ctrls{k}) '.json']), 'Encoding', 'UTF-8'));
    sel.(ctrls{k}) = J.design;
end
rows = struct('ctrl', {}, 'n_simulated', {}, 'n_common_set', {}, 'n_pass_erel', {}, 'n_front_safe', {}, 'n_front_full', {}, 'Smin_full_Rle3', {}, 'Smin_full_Rle6', {});
fig = figure('Visible', 'off', 'Position', [100 100 760 540]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); set(ax, 'XScale', 'log');
for k = 1:3
    D = readtable(fullfile(resDir, 'Pareto_common', sprintf('ParetoCommon_%s_points_s99990-s99994.csv', ctrls{k})));
    S = D(D.in_set == 1, :);
    Ff = S(S.front_full == 1, :); sm3 = NaN; sm6 = NaN;
    if any(Ff.Rtb <= 3), sm3 = min(Ff.Stb(Ff.Rtb <= 3)); end
    if any(Ff.Rtb <= 6), sm6 = min(Ff.Stb(Ff.Rtb <= 6)); end
    rows(k) = struct('ctrl', ctrls{k}, 'n_simulated', height(D), 'n_common_set', height(S), 'n_pass_erel', sum(S.pass_erel == 1), ...
        'n_front_safe', sum(S.front_safe == 1), 'n_front_full', sum(S.front_full == 1), 'Smin_full_Rle3', sm3, 'Smin_full_Rle6', sm6);
    keys = {'front_safe', 'front_full'}; filled = [false true];
    for q = 1:2
        F = S(S.(keys{q}) == 1, :);
        if isempty(F), continue; end
        F = sortrows(F, 'Rtb');
        plot(ax, F.Rtb, F.Stb, '-', 'Color', colr{k}, 'LineWidth', 1.1, 'HandleVisibility', 'off');
        if filled(q), fc = colr{k}; else, fc = 'w'; end
        plot(ax, F.Rtb, F.Stb, mark{k}, 'Color', colr{k}, 'MarkerFaceColor', fc, 'MarkerSize', 7, 'LineStyle', 'none', 'HandleVisibility', 'off');
    end
    plot(ax, sel.(ctrls{k}).CALIB_common_Rtb, sel.(ctrls{k}).CALIB_common_Stb, 'o', 'Color', 'k', 'MarkerSize', 15, 'LineWidth', 1.5, 'HandleVisibility', 'off');
end
hl = gobjects(1, 6);
for k = 1:3
    hl(k) = plot(ax, NaN, NaN, ['-' mark{k}], 'Color', colr{k}, 'MarkerFaceColor', colr{k}, 'LineWidth', 1.1, 'MarkerSize', 7, 'DisplayName', ctrls{k});
end
hl(4) = plot(ax, NaN, NaN, 'o', 'Color', [0.35 0.35 0.35], 'MarkerFaceColor', 'w', 'MarkerSize', 7, 'LineStyle', 'none', 'DisplayName', lab.legend_safe);
hl(5) = plot(ax, NaN, NaN, 'o', 'Color', [0.35 0.35 0.35], 'MarkerFaceColor', [0.35 0.35 0.35], 'MarkerSize', 7, 'LineStyle', 'none', 'DisplayName', lab.legend_full);
hl(6) = plot(ax, NaN, NaN, 'o', 'Color', 'k', 'MarkerSize', 12, 'LineWidth', 1.5, 'LineStyle', 'none', 'DisplayName', lab.legend_selected);
xlabel(ax, lab.R_xlabel, 'Interpreter', 'latex'); ylabel(ax, lab.S_ylabel, 'Interpreter', 'latex');   % ar is not in MATLAB's TeX subset
xlim(ax, [2 200]); ylim(ax, [0 1.3]); set(ax, 'XTick', [2 5 10 20 50 100], 'XTickLabel', {'2', '5', '10', '20', '50', '100'});
legend(ax, hl, 'Location', 'northeast');
exportgraphics(fig, fullfile(outDir, 'Hinh_4_2_Pareto.png'), 'Resolution', 200);
close(fig);
T = struct2table(rows);
writetable(T, fullfile(outDir, 'ch4_numbers.csv'));
disp(T);

%% selected designs (Tables 4.4 and 4.5): times in ms
names = {'Kmax', 'Ts0_Nm', 'tau1_in_ms', 'tau1_out_ms', 'tau2_in_ms', 'tau2_out_ms', 'Kp', 'Ti_ms', 'Td_ms', 'N', 'Ki_per_s', 'Kd_s', 'tauf_ms', 'Kaw_per_s', ...
    'R_bar_pct', 'S_bar_Nm', 'J', 'erel_max_pct', 'rho_gain', 'rho_delay'};
vals = nan(numel(names), 3);
for k = 1:3
    d = sel.(ctrls{k});
    if isfield(d, 'lead')
        vals(1, k) = d.Kmax; vals(2, k) = d.Ts0;
        vals(3, k) = 1000 / d.lead.z; vals(4, k) = 1000 / d.lead.p; vals(5, k) = 1000 / d.lag.z1; vals(6, k) = 1000 / d.lag.p1;
    end
    if isfield(d, 'Ti')
        vals(7, k) = d.K; vals(8, k) = 1000 * d.Ti; vals(9, k) = 1000 * d.Td; vals(10, k) = d.N;
        vals(11, k) = d.Ki; vals(12, k) = d.Kd; vals(13, k) = 1000 * d.Tf; vals(14, k) = d.Kaw;
    end
    vals(15, k) = d.CALIB_common_Rtb; vals(16, k) = d.CALIB_common_Stb; vals(17, k) = d.CALIB_common_J; vals(18, k) = d.CALIB_common_erel_max;
    vals(19, k) = d.margin_ratio_gain; vals(20, k) = d.margin_ratio_delay;
end
T2 = array2table(vals, 'VariableNames', ctrls, 'RowNames', names);
writetable(T2, fullfile(outDir, 'ch4_selected.csv'), 'WriteRowNames', true);
disp(T2);
disp('make_fig_thesis_ch4: done');
