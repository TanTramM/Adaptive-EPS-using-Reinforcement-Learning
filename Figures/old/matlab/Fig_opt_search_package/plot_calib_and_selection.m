function plot_calib_and_selection()
%PLOT_CALIB_AND_SELECTION  Two figures of the parameter-search method (written for Documents/Shared/PhuongPhap_TimThamSo.txt).
%   Fig_calib_case       the design case CALIB v2: speed, lateral-acceleration label and steering-wheel angle versus time, with the static windows (grey) and the two mu windows (darker grey)
%   Fig_selection_5seeds the choice stage for the PID: J = R*S of the 20 top designs at the five selection seeds, mean and standard deviation, and the selected design
%   Run from this folder:  >> plot_calib_and_selection      (needs the repository: Model/Sim/script/make_cases.m; the selection figure only needs data/)
here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(fileparts(here)));   % Figures/matlab/Fig_opt_search_package -> repo root
run(fullfile(repo, 'Model', 'setup_paths.m'));

%% CALIB case
S = make_cases('CALIB');
t = S.t; v = S.v * 3.6; th = S.theta1 * 180 / pi; ay = S.ayTarget;
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 7.2 4.4], 'Color', 'w');
set(f, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', 'DefaultAxesFontSize', 9);
pos = {[0.09 0.73 0.89 0.22], [0.09 0.42 0.89 0.22], [0.09 0.14 0.89 0.22]};
ax = gobjects(1, 3);
for k = 1:3, ax(k) = axes('Position', pos{k}); hold(ax(k), 'on'); end
isStatic = startsWith({S.win.label}, 'static_');
isMu = startsWith({S.win.label}, 'mu_');
for k = 1:3
    yl = {[10 110], [-0.05 0.35], [-1 1]};
    for q = find(isStatic), patch(ax(k), [S.win(q).t0 S.win(q).t1 S.win(q).t1 S.win(q).t0], [0 0 1 1] * 1e3 - 500, [0.8 0.8 0.8], 'EdgeColor', 'none'); end
    for q = find(isMu), patch(ax(k), [S.win(q).t0 S.win(q).t1 S.win(q).t1 S.win(q).t0], [0 0 1 1] * 1e3 - 500, [0.6 0.6 0.6], 'EdgeColor', 'none'); end
end
plot(ax(1), t, v, 'k-', 'LineWidth', 1.0);
plot(ax(2), t, ay, 'k-', 'LineWidth', 1.0);
plot(ax(3), t, th, 'k-', 'LineWidth', 0.8);
ylim(ax(1), [10 110]); ylim(ax(2), [-0.35 0.35]); ylim(ax(3), [min(th) * 1.1, max(th) * 1.1]);
ylabel(ax(1), 'v (km/h)'); ylabel(ax(2), 'a_y label (g)'); ylabel(ax(3), '\theta_1 (deg)');
xlabel(ax(3), 'Time (s)');
set(ax(1:2), 'XTickLabel', []);
for k = 1:3, xlim(ax(k), [0 t(end)]); set(ax(k), 'Box', 'on', 'TickDir', 'in', 'LineWidth', 0.6, 'Layer', 'top'); end
exportgraphics(f, fullfile(here, 'Fig_calib_case.png'), 'Resolution', 300);
exportgraphics(f, fullfile(here, 'Fig_calib_case.pdf'), 'ContentType', 'vector');
close(f);

%% choice stage, PID
P = readtable(fullfile(here, 'data', 'PID_CALIB_pick_ms.csv'));
n = height(P);
Jk = [P.J_s10001 P.J_s10002 P.J_s10003 P.J_s10004 P.J_s10005];
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 7.2 3.0], 'Color', 'w');
set(f, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', 'DefaultAxesFontSize', 9);
ax = axes('Position', [0.09 0.20 0.89 0.76]); hold(ax, 'on');
mk = {'o', 's', '^', 'v', 'd'};
for s = 1:5, hs(s) = plot(ax, 1:n, Jk(:, s), mk{s}, 'Color', 'k', 'MarkerSize', 3.5, 'LineWidth', 0.5); end %#ok<AGROW>
hb = errorbar(ax, (1:n) + 0.25, P.Jbar, P.sigmaJ, 'k+', 'MarkerSize', 6, 'LineWidth', 0.9, 'CapSize', 3);
c = find(P.chosen == 1, 1);
hc = plot(ax, c + 0.25, P.Jbar(c), 'p', 'MarkerSize', 11, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
xlim(ax, [0 n + 1]); ylim(ax, [2.35 2.78]); xticks(ax, 1:n);
xlabel(ax, 'Top-group design (ordered by J at the search seed)'); ylabel(ax, 'J = R\cdotS (% N\cdotm)');
legend(ax, [hs, hb, hc], {'seed 1', 'seed 2', 'seed 3', 'seed 4', 'seed 5', 'mean \pm std', 'selected'}, 'Location', 'northwest', 'Box', 'on', 'FontSize', 8, 'NumColumns', 2);
set(ax, 'Box', 'on', 'TickDir', 'in', 'LineWidth', 0.6, 'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.15);
exportgraphics(f, fullfile(here, 'Fig_selection_5seeds.png'), 'Resolution', 300);
exportgraphics(f, fullfile(here, 'Fig_selection_5seeds.pdf'), 'ContentType', 'vector');
close(f);
end
