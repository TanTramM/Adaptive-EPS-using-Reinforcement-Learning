function plot_opt_search()
%PLOT_OPT_SEARCH  The two stages of the parameter search of the PID on CALIB v2, one figure each (data/ folder, three independent chains).
%   Fig_surrogateopt   global search, evaluations 1-250 of each chain
%       (a) best J = R*S found so far versus the evaluation number;  (b) every design in the (S, R) plane
%   Fig_patternsearch  local search started from the best feasible design of the global search of the same chain (evaluations after 250)
%       (a) J of each evaluated design and the best so far, versus the evaluation number counted from the start of the local search;  (b) the designs in the (S, R) plane
%   Black and white by design: chains differ by line style and marker. Light dots = designs violating a constraint (inside the window shown).
%   Run from this folder:  >> plot_opt_search      Writes Fig_surrogateopt.png/.pdf and Fig_patternsearch.png/.pdf next to this file.
here = fileparts(mfilename('fullpath'));
dat = fullfile(here, 'data');
nm = 'PID';
ls = {'-', '--', '-.'};  mk = {'o', 's', '^'};
for k = 1:3
    o{k} = readtable(fullfile(dat, sprintf('%s_CALIB_opt%d_s10000.csv', nm, k))); %#ok<AGROW>
    r{k} = readtable(fullfile(dat, sprintf('%s_CALIB_ref%d_s10000.csv', nm, k))); %#ok<AGROW>
end
top = readtable(fullfile(dat, sprintf('%s_CALIB_top_s10000.csv', nm)));
pick = readtable(fullfile(dat, sprintf('%s_CALIB_pick_ms.csv', nm)));
pick = pick(pick.chosen == 1, :);

% ---- global search (surrogateopt)
[f, axa, axb] = newfig();
hl = gobjects(1, 3); hm = gobjects(1, 3);
for k = 1:3
    a = o{k};
    best = cummin(finiteJ(a.J)); best(~isfinite(best)) = NaN;
    idx = find(isfinite(best));
    hl(k) = plot(axa, idx, best(idx), ls{k}, 'Color', 'k', 'LineWidth', 0.9, 'Marker', mk{k}, 'MarkerSize', 4, 'MarkerIndices', 1:15:numel(idx), 'MarkerFaceColor', 'w');
    ok = isfinite(a.J);
    plot(axb, a.S_Nm(~ok & a.simulated == 1), a.R_pct(~ok & a.simulated == 1), '.', 'Color', [0.75 0.75 0.75], 'MarkerSize', 6);
    hm(k) = plot(axb, a.S_Nm(ok), a.R_pct(ok), mk{k}, 'Color', 'k', 'MarkerSize', 4, 'LineWidth', 0.5);
end
xlim(axa, [0 250]); ylim(axa, [2.4 3.0]);
xlabel(axa, {'Evaluation number', '(a)'}); ylabel(axa, 'Best J = R\cdotS (% N\cdotm)');
legend(axa, hl, {'Chain 1', 'Chain 2', 'Chain 3'}, 'Location', 'northeast', 'Box', 'on', 'FontSize', 8);
xlim(axb, [0.4 1.6]); ylim(axb, [2 9]);
xlabel(axb, {'S (N\cdotm)', '(b)'}); ylabel(axb, 'R (%)');
legend(axb, hm, {'Chain 1', 'Chain 2', 'Chain 3'}, 'Location', 'northeast', 'Box', 'on', 'FontSize', 8);
save_fig(f, here, 'Fig_surrogateopt');

% ---- local search (patternsearch)
[f, axa, axb] = newfig();
hl = gobjects(1, 3); hm = gobjects(1, 3);
for k = 1:3
    a = r{k};
    n = (1:height(a))';
    J = finiteJ(a.J);
    best = cummin(J); best(~isfinite(best)) = NaN;
    plot(axa, n(isfinite(J)), J(isfinite(J)), mk{k}, 'Color', 'k', 'MarkerSize', 4, 'LineWidth', 0.5);
    hl(k) = stairs(axa, n(isfinite(best)), best(isfinite(best)), ls{k}, 'Color', 'k', 'LineWidth', 1.0);
    ok = isfinite(a.J);
    plot(axb, a.S_Nm(~ok & a.simulated == 1), a.R_pct(~ok & a.simulated == 1), '.', 'Color', [0.75 0.75 0.75], 'MarkerSize', 6);
    hm(k) = plot(axb, a.S_Nm(ok), a.R_pct(ok), mk{k}, 'Color', 'k', 'MarkerSize', 4, 'LineWidth', 0.5);
end
h2 = plot(axb, pick.S_Nm(1), pick.R_pct(1), 'p', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
xlim(axa, [0 60]); ylim(axa, [2.45 2.80]);
xlabel(axa, {'Evaluation number of the local search', '(a)'}); ylabel(axa, 'J = R\cdotS (% N\cdotm)');
legend(axa, hl, {'Chain 1', 'Chain 2', 'Chain 3'}, 'Location', 'northeast', 'Box', 'on', 'FontSize', 8);
xlim(axb, [0.7 1.55]); ylim(axb, [2.2 4.3]);
xlabel(axb, {'S (N\cdotm)', '(b)'}); ylabel(axb, 'R (%)');
legend(axb, [hm h2], {'Chain 1', 'Chain 2', 'Chain 3', 'Selected'}, 'Location', 'northeast', 'Box', 'on', 'FontSize', 8);
save_fig(f, here, 'Fig_patternsearch');
end

function J = finiteJ(J)
J(~isfinite(J)) = inf;
end

function [f, axa, axb] = newfig()
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 7.2 3.0], 'Color', 'w');
set(f, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', 'DefaultAxesFontSize', 9);
axa = axes('Position', [0.085 0.20 0.40 0.76]); hold(axa, 'on');
axb = axes('Position', [0.585 0.20 0.395 0.76]); hold(axb, 'on');
end

function save_fig(f, here, name)
for ax = findall(f, 'Type', 'axes')', set(ax, 'Box', 'on', 'TickDir', 'in', 'LineWidth', 0.6, 'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.15); end
exportgraphics(f, fullfile(here, [name '.png']), 'Resolution', 300);
exportgraphics(f, fullfile(here, [name '.pdf']), 'ContentType', 'vector');
close(f);
end
