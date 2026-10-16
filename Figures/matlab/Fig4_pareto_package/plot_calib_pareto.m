% PLOT_CALIB_PARETO  Fig. 4 of the paper: tracking-noise trade-off on the CALIB case.
%   Each panel shows every simulated parameter set of one controller in the (S, R) plane
%     S = RMS of the high-pass filtered (> 5 Hz) assist torque [N.m]   (noise level)
%     R = RMS of the torque tracking error e_T [%]                      (tracking error)
%   grey points fail the steady-state accuracy gate (|e_rel| > 5 %), coloured points pass,
%   the black staircase is the Pareto front of the passing points, the star is the selected design.
%   Data: the CSV files in the folder "data" next to this script.   Output: Fig4_pareto.png / .pdf / .fig
clear; clc;
here = fileparts(mfilename('fullpath'));
dataDir = fullfile(here, 'data');
GATE = 5;                                   % accuracy gate on |e_rel| [%]
name = {'Map', 'PI', 'PID'};
col = [0.16 0.47 0.84; 0.80 0.60 0.00; 0.92 0.41 0.20];
ttl = {'(a) Assist map', '(b) PI', '(c) PID'};

d = cell(1, 3); sel = zeros(3, 2);
for k = 1:3
    switch name{k}
        case 'Map'
            T = readtable(fullfile(dataDir, 'Map_CALIB_sweep_s00000.csv'));
            P = readtable(fullfile(dataDir, 'Map_CALIB_pick_s00000.csv'));
            P = P(P.admissible == 1, :); [~, i] = min(P.J);                 % selected = smallest J = R*S among admissible
            sel(k, :) = [P.S_Nm(i), P.R_pct(i)];
        case 'PI'
            T = [readtable(fullfile(dataDir, 'PI_CALIB_sweep_s10000.csv')); readtable(fullfile(dataDir, 'PI_CALIB_fine_s10000.csv'))];
            P = readtable(fullfile(dataDir, 'PI_CALIB_pick_s10000.csv')); P = P(P.chosen == 1, :);
            sel(k, :) = [P.S_Nm(1), P.R_pct(1)];
        case 'PID'
            T = readtable(fullfile(dataDir, 'PID_CALIB_sweep_s10000.csv'));
            P = readtable(fullfile(dataDir, 'PID_CALIB_pick_s10000.csv')); P = P(P.chosen == 1, :);
            sel(k, :) = [P.S_Nm(1), P.R_pct(1)];
    end
    d{k} = [T.S_Nm, T.R_pct, abs(T.erel_pct)];
end

allok = cat(1, d{:}); allok = allok(allok(:, 3) <= GATE, :);
xl = [0.9 * min(allok(:, 1)), 1.1 * max(allok(:, 1))];
yl = [0.9 * min(allok(:, 2)), 1.05 * max(allok(:, 2))];

fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 7.2 2.9]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:3
    ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    X = d{k}; bad = X(:, 3) > GATE; ok = ~bad;
    h1 = scatter(ax, X(bad, 1), min(X(bad, 2), yl(2)), 6, [0.77 0.77 0.77], 'filled');
    h2 = scatter(ax, X(ok, 1), X(ok, 2), 8, col(k, :), 'filled', 'MarkerFaceAlpha', 0.55);
    % Pareto front of the passing points: scan by increasing S and keep the points that lower R
    Y = sortrows(X(ok, 1:2), [1 2]); best = inf; keep = false(size(Y, 1), 1);
    for i = 1:size(Y, 1)
        if Y(i, 2) < best - 1e-12, keep(i) = true; best = Y(i, 2); end
    end
    F = Y(keep, :);
    h3 = stairs(ax, F(:, 1), F(:, 2), 'k-', 'LineWidth', 1.1);
    h4 = plot(ax, sel(k, 1), sel(k, 2), 'p', 'MarkerSize', 11, 'MarkerFaceColor', [0.84 0.15 0.16], 'MarkerEdgeColor', 'k');
    set(ax, 'XScale', 'log', 'XLim', xl, 'YLim', yl, 'XTick', [0.15 0.2 0.3 0.4 0.6], ...
        'XTickLabel', {'0.15', '0.2', '0.3', '0.4', '0.6'}, 'XMinorTick', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off', ...
        'FontName', 'Arial', 'FontSize', 9);
    xlabel(ax, '{\itS} [N\cdotm]');
    if k == 1, ylabel(ax, '{\itR} [%]'); else, set(ax, 'YTickLabel', []); end
    title(ax, {ttl{k}, sprintf('%d configurations', size(X, 1))}, 'FontWeight', 'normal');
    legend(ax, [h1 h2 h3 h4], {sprintf('fails gate (%d)', nnz(bad)), sprintf('passes (%d)', nnz(ok)), 'Pareto front', 'selected'}, ...
        'Location', 'northeast', 'FontSize', 6.5, 'Box', 'on');
end
savefig(fig, fullfile(here, 'Fig4_pareto.fig'));
exportgraphics(fig, fullfile(here, 'Fig4_pareto.png'), 'Resolution', 600);
exportgraphics(fig, fullfile(here, 'Fig4_pareto.pdf'), 'ContentType', 'vector');
