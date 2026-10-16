function make_paper_figures()
%MAKE_PAPER_FIGURES Result figures of the paper, drawn and exported by MATLAB from the result tables (not by another tool).
%
%   Fig3  CALIB Pareto plane (S, R) of Map, PI, PID: every simulated point, points failing the accuracy gate, Pareto front, selected point
%   Fig4  DRY   : T_s with T_ref, e_T with the scoring windows shaded, T_a; columns Map, PI, PID (seed 99999)
%   Fig5  SLIP  : same layout as Fig4
%   Fig6  e_T of the five scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE); columns Map, PI, PID (seed 99999)
%
%   Sources: Result/Controllers/<Ctrl>/Calib/<Ctrl>_CALIB_{sweep,fine,pick}_<seed>.csv,
%            Result/Controllers/<Ctrl>/Cases/<Ctrl>_<CASE>_sig_s99999.csv, scoring windows from make_cases.m.
%   Writes Figures/matlab/FigN.fig (the raw MATLAB figure), FigN.png (600 dpi) and FigN.pdf (vector); fonts Arial.
%   Usage (repo set up with setup_paths): make_paper_figures

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
repo = fileparts(modelDir);
outDir = fullfile(repo, 'Figures', 'matlab');
if ~isfolder(outDir), mkdir(outDir); end
set(0, 'DefaultAxesFontName', 'Arial', 'DefaultTextFontName', 'Arial', 'DefaultAxesFontSize', 9, 'DefaultTextInterpreter', 'tex', ...
    'DefaultAxesTickLabelInterpreter', 'tex', 'DefaultLegendInterpreter', 'tex');
ctrl = {'Map', 'PI', 'PID'};
col = [0.16 0.47 0.84; 0.80 0.60 0.00; 0.92 0.41 0.20];
ttl = {'(a) Assist map', '(b) PI', '(c) PID'};
rc = fullfile(repo, 'Result', 'Controllers');

fig3(rc, outDir, ctrl, col, ttl);
TC = make_cases();
sig = struct();
for k = 1:3
    for c = 1:numel(TC)
        sig.(ctrl{k}).(TC(c).tag) = readtable(fullfile(rc, ctrl{k}, 'Cases', sprintf('%s_%s_sig_s99999.csv', ctrl{k}, TC(c).tag)));
    end
end
figCase(sig, TC, 'DRY', 4, outDir, ctrl, col, ttl);
figCase(sig, TC, 'SLIP', 5, outDir, ctrl, col, ttl);
fig6(sig, TC, outDir, ctrl, col, ttl);
fprintf('make_paper_figures: written to %s\n', outDir);
end

% ----------------------------------------------------------------------------------------------------------------------
function fig3(rc, outDir, ctrl, col, ttl)
GATE = 5;
fig = newfig(7.2, 2.9);
d = cell(1, 3); sel = zeros(3, 2);
for k = 1:3
    c = fullfile(rc, ctrl{k}, 'Calib');
    switch ctrl{k}
        case 'Map'
            T = readtable(fullfile(c, 'Map_CALIB_sweep_s00000.csv')); R = T.R_pct; S = T.S_Nm; E = abs(T.erel_pct);
            P = readtable(fullfile(c, 'Map_CALIB_pick_s00000.csv')); P = P(P.admissible == 1, :); [~, i] = min(P.J); sel(k, :) = [P.S_Nm(i), P.R_pct(i)];
        case 'PI'
            T = [readtable(fullfile(c, 'PI_CALIB_sweep_s10000.csv')); readtable(fullfile(c, 'PI_CALIB_fine_s10000.csv'))];
            R = T.R_pct; S = T.S_Nm; E = abs(T.erel_pct);
            P = readtable(fullfile(c, 'PI_CALIB_pick_s10000.csv')); P = P(P.chosen == 1, :); sel(k, :) = [P.S_Nm(1), P.R_pct(1)];
        otherwise
            T = readtable(fullfile(c, 'PID_CALIB_sweep_s10000.csv')); R = T.R_pct; S = T.S_Nm; E = abs(T.erel_pct);
            P = readtable(fullfile(c, 'PID_CALIB_pick_s10000.csv')); P = P(P.chosen == 1, :); sel(k, :) = [P.S_Nm(1), P.R_pct(1)];
    end
    d{k} = [S R E];
end
allok = cat(1, d{:}); allok = allok(allok(:, 3) <= GATE, :);
xl = [0.9 * min(allok(:, 1)), 1.1 * max(allok(:, 1))]; yl = [0.9 * min(allok(:, 2)), 1.05 * max(allok(:, 2))];
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:3
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    X = d{k}; bad = X(:, 3) > GATE; ok = ~bad;
    h1 = scatter(ax, X(bad, 1), min(X(bad, 2), yl(2)), 6, [0.77 0.77 0.77], 'filled');
    h2 = scatter(ax, X(ok, 1), X(ok, 2), 8, col(k, :), 'filled', 'MarkerFaceAlpha', 0.55);
    Y = sortrows(X(ok, 1:2), [1 2]); best = inf; keep = false(size(Y, 1), 1);
    for i = 1:size(Y, 1), if Y(i, 2) < best - 1e-12, keep(i) = true; best = Y(i, 2); end, end
    F = Y(keep, :); h3 = stairs(ax, F(:, 1), F(:, 2), 'k-', 'LineWidth', 1.1);
    h4 = plot(ax, sel(k, 1), sel(k, 2), 'p', 'MarkerSize', 11, 'MarkerFaceColor', [0.84 0.15 0.16], 'MarkerEdgeColor', 'k');
    set(ax, 'XScale', 'log', 'XLim', xl, 'YLim', yl, 'XTick', [0.15 0.2 0.3 0.4 0.6], 'XTickLabel', {'0.15', '0.2', '0.3', '0.4', '0.6'}, ...
        'XMinorTick', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off');
    xlabel(ax, '{\itS} [N\cdotm]'); if k == 1, ylabel(ax, '{\itR} [%]'); else, set(ax, 'YTickLabel', []); end
    title(ax, {ttl{k}, sprintf('%d configurations', size(X, 1))}, 'FontWeight', 'normal');
    legend(ax, [h1 h2 h3 h4], {sprintf('fails gate (%d)', nnz(bad)), sprintf('passes (%d)', nnz(ok)), 'Pareto front', 'selected'}, ...
        'Location', 'northeast', 'FontSize', 6.5, 'Box', 'on');
end
exportfig(fig, outDir, 'Fig3');
end

function figCase(sig, TC, name, num, outDir, ctrl, col, ttl)
ci = find(strcmp({TC.tag}, name)); W = TC(ci).win;
fig = newfig(7.2, 5.0);
tl = tiledlayout(fig, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
lim = zeros(3, 1);
for k = 1:3
    T = sig.(ctrl{k}).(name); w = T.t >= 2;
    lim(1) = max(lim(1), max([abs(T.T_s(w)); abs(T.T_d_ref(w))])); lim(2) = max(lim(2), max(abs(T.e_T(w)))); lim(3) = max(lim(3), max(abs(T.T_a(w))));
end
lim = 1.08 * lim;
for r = 1:3
    for k = 1:3
        T = sig.(ctrl{k}).(name); w = T.t >= 2; ax = nexttile(tl, (r - 1) * 3 + k); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        switch r
            case 1
                plot(ax, T.t(w), T.T_s(w), 'Color', col(k, :), 'LineWidth', 0.7); plot(ax, T.t(w), T.T_d_ref(w), 'k--', 'LineWidth', 0.8);
                if k == 1, ylabel(ax, '{\itT_s}, {\itT_{ref}} [N\cdotm]'); legend(ax, {'{\itT_s}', '{\itT_{ref}}'}, 'Location', 'southwest', 'FontSize', 6.5, 'NumColumns', 2); end
                title(ax, ttl{k}, 'FontWeight', 'bold');
            case 2
                for j = 1:numel(W), patch(ax, [W(j).t0 W(j).t1 W(j).t1 W(j).t0], lim(2) * [-1 -1 1 1], [0.80 0.86 0.94], 'EdgeColor', 'none'); end
                plot(ax, T.t(w), T.e_T(w), 'Color', col(k, :), 'LineWidth', 0.6); plot(ax, [0 T.t(end)], [0 0], 'k-', 'LineWidth', 0.4);
                if k == 1, ylabel(ax, '{\ite_T} [N\cdotm]'); end
            case 3
                plot(ax, T.t(w), T.T_a(w), 'Color', col(k, :), 'LineWidth', 0.5); xlabel(ax, '{\itt} [s]');
                if k == 1, ylabel(ax, '{\itT_a} [N\cdotm]'); end
        end
        set(ax, 'YLim', lim(r) * [-1 1], 'XLim', [0 T.t(end)]);
        if k > 1, set(ax, 'YTickLabel', []); end
        if r < 3, set(ax, 'XTickLabel', []); end
    end
end
exportfig(fig, outDir, sprintf('Fig%d', num));
end

function fig6(sig, TC, outDir, ctrl, col, ttl)
names = {'DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE'};
fig = newfig(7.2, 7.6);
tl = tiledlayout(fig, 5, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:5
    lim = 0;
    for k = 1:3, T = sig.(ctrl{k}).(names{i}); lim = max(lim, max(abs(T.e_T(T.t >= 2)))); end
    lim = 1.05 * lim;
    for k = 1:3
        T = sig.(ctrl{k}).(names{i}); w = T.t >= 2; ax = nexttile(tl, (i - 1) * 3 + k); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        plot(ax, T.t(w), T.e_T(w), 'Color', col(k, :), 'LineWidth', 0.5); plot(ax, [0 T.t(end)], [0 0], 'k-', 'LineWidth', 0.4);
        set(ax, 'YLim', lim * [-1 1], 'XLim', [0 T.t(end)]);
        if i == 1, title(ax, ttl{k}, 'FontWeight', 'bold'); end
        if k == 1, ylabel(ax, {names{i}, '{\ite_T} [N\cdotm]'}); else, set(ax, 'YTickLabel', []); end
        if i == 5, xlabel(ax, '{\itt} [s]'); else, set(ax, 'XTickLabel', []); end
    end
end
exportfig(fig, outDir, 'Fig6');
end

function fig = newfig(w, h)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', 'Position', [1 1 w h], 'PaperUnits', 'inches', 'PaperSize', [w h], 'PaperPosition', [0 0 w h]);
end

function exportfig(fig, outDir, name)
savefig(fig, fullfile(outDir, [name '.fig']));
exportgraphics(fig, fullfile(outDir, [name '.png']), 'Resolution', 600);
exportgraphics(fig, fullfile(outDir, [name '.pdf']), 'ContentType', 'vector');
close(fig);
end
