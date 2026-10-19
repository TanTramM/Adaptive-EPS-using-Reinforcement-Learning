function plot_rbf_toy()
%PLOT_RBF_TOY  One-variable example of the cubic radial basis function with a linear tail used by surrogateopt (step 2 of the search method).
%   Three measured points (u, F) = (0.2, 3.0), (0.5, 2.0), (0.9, 2.5). The surrogate s(u) = sum_i lambda_i |u - u_i|^3 + c1 u + c0 passes through them;
%   the figure also shows the three cubic "bumps" lambda_i |u - u_i|^3 and the linear tail c1 u + c0 whose sum is s(u).
%   Run from this folder:  >> plot_rbf_toy      Writes Fig_rbf_toy.png and .pdf next to this file.
here = fileparts(mfilename('fullpath'));
ui = [0.2 0.5 0.9]; Fi = [3.0 2.0 2.5];
r = abs(ui' - ui) .^ 3;
A = [r, ui', ones(3, 1); ui, 0, 0; ones(1, 3), 0, 0];
sol = A \ [Fi'; 0; 0];
lam = sol(1:3)'; c1 = sol(4); c0 = sol(5);
u = linspace(0, 1, 501);
bump = zeros(3, numel(u));
for i = 1:3, bump(i, :) = lam(i) * abs(u - ui(i)) .^ 3; end
tail = c1 * u + c0;
s = sum(bump, 1) + tail;
[smin, k] = min(s);

f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 7.2 3.0], 'Color', 'w');
set(f, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', 'DefaultAxesFontSize', 9);
axa = axes('Position', [0.08 0.20 0.40 0.76]); hold(axa, 'on');
axb = axes('Position', [0.58 0.20 0.40 0.76]); hold(axb, 'on');
h1 = plot(axa, u, s, 'k-', 'LineWidth', 1.2);
h2 = plot(axa, ui, Fi, 'ko', 'MarkerSize', 6, 'MarkerFaceColor', 'w', 'LineWidth', 1.0);
h3 = plot(axa, u(k), smin, 'k^', 'MarkerSize', 7, 'MarkerFaceColor', 'k');
xlabel(axa, {'u', '(a)'}); ylabel(axa, 'F');
legend(axa, [h2 h1 h3], {'measured points', 's(u)', 'minimum of s(u)'}, 'Location', 'north', 'Box', 'on', 'FontSize', 8);
xlim(axa, [0 1]); ylim(axa, [1.5 4]);
ls = {'--', ':', '-.'};
for i = 1:3, plot(axb, u, bump(i, :), ls{i}, 'Color', 'k', 'LineWidth', 1.0); end
plot(axb, u, tail, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
plot(axb, u, s, 'k-', 'LineWidth', 1.2);
xlabel(axb, {'u', '(b)'}); ylabel(axb, 'terms of s(u)');
legend(axb, {'\lambda_1|u-u_1|^3', '\lambda_2|u-u_2|^3', '\lambda_3|u-u_3|^3', 'c_1u+c_0', 's(u) = sum'}, 'Location', 'north', 'Box', 'on', 'FontSize', 8);
xlim(axb, [0 1]); ylim(axb, [-3 6]);
for ax = [axa axb], set(ax, 'Box', 'on', 'TickDir', 'in', 'LineWidth', 0.6, 'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.15); end
exportgraphics(f, fullfile(here, 'Fig_rbf_toy.png'), 'Resolution', 300);
exportgraphics(f, fullfile(here, 'Fig_rbf_toy.pdf'), 'ContentType', 'vector');
close(f);
fprintf('lambda = %s, c1 = %.4f, c0 = %.4f, min s = %.4f at u = %.3f\n', mat2str(lam, 5), c1, c0, smin, u(k));
for t = 0:0.1:1, fprintf('s(%.1f) = %.3f\n', t, interp1(u, s, t)); end
end
