function make_paper_figures(which)
% MAKE_PAPER_FIGURES  Result figures of the paper (Sections 4 and 5), drawn from the csv files and written to Figures/new/main.
%
%   make_paper_figures()                    all five figures
%   make_paper_figures({'gates','pareto'})  a subset: 'gates', 'pareto', 'noise', 'windows', 'lane'
%
% Colour figures that stay readable in black-and-white print: every controller has its own colour AND its own marker shape, line style and
% lightness (Map: green, dotted, open circle; PID: orange, dashed, open square; MapPID: dark blue, solid, filled triangle); open and filled
% markers, dashed limit lines and pale bands carry the meaning that colour carries on screen.
%
%   Fig_Map_gates.png     Fig. 7  Map candidates against the slope limit K_max (static-accuracy gate and stability test)
%   Fig_Pareto.png        Fig. 8  fronts of the three controllers with curves of constant J = R*S and the selected designs
%   Fig_SSW_noise.png     Fig. 9  high-frequency assist torque in STEADY: RMS per 1 s interval against |T_ref|, and 1 s of straight driving
%   Fig_SSW_windows.png   Fig. 10 signed steady error of every window of STEADY and SLIP
%   Fig_SSW_lane.png      Fig. 11 double lane changes in WEAVE
%
% Sources: Result/Compare/Pareto_common/ParetoCommon_<Ctrl>_points_s99990-s99994.csv, ParetoCommon_select.csv;
%          Result/Compare/SSW_summary/SSW_windows_summary.csv, fullrate/<Ctrl>_<CASE>_full_s99987.csv (1 ms signals)

if nargin < 1, which = {'gates', 'pareto', 'noise', 'windows', 'lane'}; end
if ischar(which), which = {which}; end
scriptDir = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(fileparts(scriptDir)));
P.pc  = fullfile(repo, 'Result', 'Compare', 'Pareto_common');
P.ss  = fullfile(repo, 'Result', 'Compare', 'SSW_summary');
P.out = fullfile(repo, 'Figures', 'new', 'main');

set(groot, 'defaultAxesFontName', 'Times New Roman', 'defaultTextFontName', 'Times New Roman', 'defaultAxesFontSize', 9, ...
    'defaultAxesTickDir', 'in', 'defaultAxesLineWidth', 0.6, 'defaultAxesBox', 'on', 'defaultTextInterpreter', 'tex', ...
    'defaultAxesTickLabelInterpreter', 'tex', 'defaultLegendInterpreter', 'tex');

if any(strcmp(which, 'gates')),   fig_gates(P);   end
if any(strcmp(which, 'pareto')),  fig_pareto(P);  end
if any(strcmp(which, 'noise')),   fig_noise(P);   end
if any(strcmp(which, 'windows')), fig_windows(P); end
if any(strcmp(which, 'lane')),    fig_lane(P);    end
end

% ------------------------------------------------------------------------------------------------------------ helpers
function S = style()
blue = [0.05 0.25 0.60];
S.Map    = struct('c', [0.15 0.55 0.30], 'ls', ':',  'm', 'o', 'mfc', 'none', 'lw', 1.5);
S.PID    = struct('c', [0.85 0.33 0.05], 'ls', '--', 'm', 's', 'mfc', 'none', 'lw', 1.2);
S.MapPID = struct('c', blue,             'ls', '-',  'm', '^', 'mfc', blue,   'lw', 1.3);
end

function fig = newfig(w, h)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'inches', 'Position', [1 1 w h], 'PaperPositionMode', 'auto');
end

function save_fig(fig, P, name)
fn = fullfile(P.out, name);
exportgraphics(fig, fn, 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);
fprintf('wrote %s\n', fn);
end

function ax = newax(fig, pos)      % pos = [left bottom width height] in figure fractions
ax = axes(fig, 'Position', pos, 'NextPlot', 'add', 'Layer', 'top');
end

function figtext(fig, x, y, str, rot)   % text at figure fractions (an invisible full-figure axes carries it, so it can be rotated)
a = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', 'HitTest', 'off');
text(a, x, y, str, 'Units', 'normalized', 'Rotation', rot, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9);
end

function t = load_points(P, ctrl)
t = readtable(fullfile(P.pc, sprintf('ParetoCommon_%s_points_s99990-s99994.csv', ctrl)));
t = t(t.in_set == 1, :);
end

% ------------------------------------------------------------------------------------------------------------ Fig. 7
function fig_gates(P)
S = style();
d = readtable(fullfile(P.pc, 'ParetoCommon_Map_points_s99990-s99994.csv'));
d = d(d.in_set == 1 & d.margin_done == 1, :);
st = d.margin_pass == 1;
kst = max(d.K(st));
kun = min(d.K(~st & d.pass_erel == 1));
cs = S.MapPID.c; cu = S.PID.c; band = [1 0.93 0.65];
fig = newfig(6.3, 2.7);
ax1 = newax(fig, [0.095 0.18 0.385 0.64]);
ax2 = newax(fig, [0.60 0.18 0.385 0.64]);
for ax = [ax1 ax2]
    patch(ax, [kst kun kun kst], [0.001 0.001 1000 1000], band, 'EdgeColor', 'none');
end
plot(ax1, d.K(st), d.erel_max(st), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', cs, 'MarkerEdgeColor', cs);
plot(ax1, d.K(~st), d.erel_max(~st), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', cu, 'LineWidth', 1.0);
yline(ax1, 10, '--', 'Color', 'k', 'LineWidth', 0.9);
text(ax1, 11.4, 11.3, 'gate 10 %', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 8);
set(ax1, 'YScale', 'log', 'YLim', [3 400], 'YTick', [5 10 20 50 100 200], 'YTickLabel', {'5','10','20','50','100','200'}, 'XLim', [0.5 11.6], 'XTick', [1 3 5 7 9 11]);
ylabel(ax1, 'max |{\ite}_{rel}| (%)'); xlabel(ax1, '{\itK}_{max}');
plot(ax2, d.K(st), d.ratio_gain(st), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', cs, 'MarkerEdgeColor', cs);
plot(ax2, d.K(~st), d.ratio_gain(~st), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', cu, 'LineWidth', 1.0);
yline(ax2, 2, '--', 'Color', 'k', 'LineWidth', 0.9);
text(ax2, 0.8, 2.08, 'limit 2', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'FontSize', 8);
set(ax2, 'YLim', [0 4], 'XLim', [0.5 11.6], 'XTick', [1 3 5 7 9 11]);
ylabel(ax2, '{\itR}_{2\timesgain} / {\itR}'); xlabel(ax2, '{\itK}_{max}');
h1 = plot(ax1, nan, nan, 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', cs, 'MarkerEdgeColor', cs);
h2 = plot(ax1, nan, nan, 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', cu, 'LineWidth', 1.0);
h3 = patch(ax1, nan, nan, band, 'EdgeColor', 'none');
lg = legend(ax1, [h1 h2 h3], {'passes the stability test', 'fails the stability test', 'between the largest stable and the smallest accurate slope'}, ...
    'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 7.5);
lg.Units = 'normalized'; lg.Position = [0.03 0.895 0.95 0.09];
text(ax1, 0.97, 0.95, '(a)', 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 9);
text(ax2, 0.03, 0.95, '(b)', 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
save_fig(fig, P, 'Fig_Map_gates.png');
end

% ------------------------------------------------------------------------------------------------------------ Fig. 8
function fig_pareto(P)
S = style();
sel = readtable(fullfile(P.pc, 'ParetoCommon_select.csv'));
face = struct('Map', 'safe', 'PID', 'full', 'MapPID', 'full');
fig = newfig(6.3, 3.5);
ax = newax(fig, [0.085 0.14 0.895 0.84]);
XMIN = 2; XMAX = 130; YMAX = 1.45;
rr = logspace(log10(XMIN), log10(XMAX), 300);
for J = [2 3 5 10 20 50]
    plot(ax, rr, J ./ rr, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.6);
    xl = J / (YMAX - 0.10);
    if J >= 5
        text(ax, xl * 1.04, YMAX - 0.10, sprintf('{\\itJ} = %g', J), 'FontSize', 7, 'Color', [0.4 0.4 0.4], 'VerticalAlignment', 'middle');
    else                                      % J = 2, 3 leave through the left edge: label below the curve, in the empty lower region
        xb = 9 - 2 * (J - 2);
        text(ax, xb, J / xb - 0.06, sprintf('{\\itJ} = %g', J), 'FontSize', 7, 'Color', [0.4 0.4 0.4], 'VerticalAlignment', 'middle');
    end
end
ctrls = {'Map', 'PID', 'MapPID'};
for k = 1:3
    c = ctrls{k}; s = S.(c);
    d = load_points(P, c);
    plot(ax, d.Rtb, d.Stb, '.', 'Color', [0.65 0.65 0.65], 'MarkerSize', 4);
    f = d(d.(['front_' face.(c)]) == 1, :);
    [~, o] = sort(f.Rtb); f = f(o, :);
    plot(ax, f.Rtb, f.Stb, 'Color', s.c, 'LineStyle', s.ls, 'LineWidth', s.lw, 'Marker', s.m, 'MarkerSize', 4.5, ...
        'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c);
end
lab = struct('MapPID', [2.15 0.30], 'PID', [4.6 1.12], 'Map', [24 0.78]);
for k = [3 2 1]
    c = ctrls{k};
    r = sel(strcmp(sel.ctrl, c), :);
    x = r.Rtb; y = r.Stb; p = lab.(c);
    plot(ax, [x p(1)], [y p(2)], '-', 'Color', 'k', 'LineWidth', 0.6);
    text(ax, p(1), p(2), sprintf('%s\n{\\itR} = %.2f %%, {\\itS} = %.2f N\\cdotm', c, x, y), 'FontSize', 7.5, ...
        'BackgroundColor', 'w', 'Margin', 1, 'VerticalAlignment', 'middle');
    plot(ax, x, y, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', 'k', 'LineWidth', 0.9);
end
set(ax, 'XScale', 'log', 'XLim', [XMIN XMAX], 'YLim', [0 YMAX], 'XTick', [2 3 5 10 20 50 100], 'XTickLabel', {'2','3','5','10','20','50','100'}, ...
    'XMinorTick', 'off');
xlabel(ax, '{\itR} (%)'); ylabel(ax, '{\itS} (N\cdotm)');
h = gobjects(1, 4);
names = {'Map, stability-only front', 'PID, all-gates front', 'MapPID, all-gates front'};
for k = 1:3
    s = S.(ctrls{k});
    h(k) = plot(ax, nan, nan, 'Color', s.c, 'LineStyle', s.ls, 'LineWidth', s.lw, 'Marker', s.m, 'MarkerSize', 4.5, 'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c);
end
h(4) = plot(ax, nan, nan, '.', 'Color', [0.65 0.65 0.65], 'MarkerSize', 5);
lg = legend(ax, h, [names {'candidates'}], 'Location', 'northeast', 'Box', 'off', 'FontSize', 7.5);
lg.Units = 'normalized'; lg.Position(1:2) = [0.69 0.62];
save_fig(fig, P, 'Fig_Pareto.png');
end

% ------------------------------------------------------------------------------------------------------------ Fig. 9
function fig_noise(P)
S = style();
ctrls = {'Map', 'PID', 'MapPID'};
D = struct();
for k = 1:3
    D.(ctrls{k}) = readtable(fullfile(P.ss, 'fullrate', sprintf('%s_STEADY_full_s99987.csv', ctrls{k})));
end
fig = newfig(6.3, 5.8);
ax = newax(fig, [0.115 0.585 0.865 0.395]);
for k = 1:3
    c = ctrls{k}; d = D.(c); s = S.(c);
    keep = d.t >= 2 & d.t < 100;
    kk = floor(d.t(keep) - 2) + 1;
    x = accumarray(kk, abs(d.T_d_ref(keep)), [], @mean);
    y = accumarray(kk, d.T_a_hp5(keep), [], @(v) sqrt(mean(v .^ 2)));
    plot(ax, x, y, s.m, 'Color', s.c, 'MarkerSize', 4.5, 'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c, 'LineWidth', 0.8);
end
set(ax, 'XLim', [0 3.6], 'YLim', [0 1.35], 'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1, 'Layer', 'top');
xlabel(ax, 'Mean |{\itT}_{ref}| in the 1 s interval (N\cdotm)');
ylabel(ax, 'RMS of {\itT}_{a} - {\itF}_{5}({\itT}_{a}) (N\cdotm)');
plot(ax, [0.06 0.45], [0.66 1.08], '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);
text(ax, 0.45, 1.30, sprintf('straight driving\n(torque near zero)'), 'FontSize', 8, 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'Margin', 1);
plot(ax, [3.0 2.8], [0.45 0.82], '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);
text(ax, 2.55, 0.86, 'held turns', 'FontSize', 8, 'VerticalAlignment', 'bottom');
h = gobjects(1, 3);
for k = 1:3
    s = S.(ctrls{k});
    h(k) = plot(ax, nan, nan, s.m, 'Color', s.c, 'MarkerSize', 5, 'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c, 'LineWidth', 0.8);
end
legend(ax, h, ctrls, 'Location', 'northeast', 'Box', 'off', 'FontSize', 8);
% 1 s of straight driving, one row per controller
t0 = 92; t1 = 93; yl = 3;
rowh = 0.105; gap = 0.047; b0 = 0.075;
for k = 1:3
    c = ctrls{k}; d = D.(c); s = S.(c);
    a = newax(fig, [0.115, b0 + (3 - k) * (rowh + gap), 0.865, rowh]);
    m = d.t >= t0 & d.t <= t1;
    plot(a, d.t(m), d.T_a_hp5(m), 'Color', s.c, 'LineWidth', 0.6);
    yline(a, 0, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.4);
    set(a, 'XLim', [t0 t1], 'YLim', [-yl yl], 'YTick', [-2.5 0 2.5]);
    ylabel(a, c, 'Color', s.c, 'FontWeight', 'bold');
    rms = sqrt(mean(d.T_a_hp5(m) .^ 2));
    text(a, 0.99, 0.88, sprintf('RMS %.2f', rms), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 8, ...
        'BackgroundColor', 'w', 'Margin', 1);
    if k < 3, set(a, 'XTickLabel', []); else, xlabel(a, 'Time (s), straight driving at 85 km/h'); end
end
figtext(fig, 0.022, 0.235, '{\itT}_{a} - {\itF}_{5}({\itT}_{a}) (N\cdotm)', 90);
save_fig(fig, P, 'Fig_SSW_noise.png');
end

% ------------------------------------------------------------------------------------------------------------ Fig. 10
function fig_windows(P)
S = style();
t = readtable(fullfile(P.ss, 'SSW_windows_summary.csv'));
t = t(strcmp(t.Group, 'common'), :);
val = 'Mean_eT_signed_pct_of_Tdref_mean';
ctrls = {'Map', 'PID', 'MapPID'};
st_w = unique(t.Window(strcmp(t.Case, 'STEADY')), 'stable');
sl_w = {'ramp_dn', 'ramp_up', 'stair_m0p5', 'stair_m0p33', 'stair_m0p24', 'pud_in'};
sl_l = {sprintf('speed\ndown'), sprintf('speed\nup'), sprintf('\\mu\n0.5'), sprintf('\\mu\n0.33'), sprintf('\\mu\n0.24'), sprintf('puddle\n\\mu 0.2')};
st_l = cell(size(st_w));
for i = 1:numel(st_w)
    w = st_w{i};
    vk = w(2:strfind(w, 'a') - 1);
    a = strrep(w(strfind(w, 'a') + 1:end - 1), 'p', '.');
    st_l{i} = sprintf('%s\n%s', vk, a);
end
fig = newfig(6.3, 3.3);
ax1 = newax(fig, [0.095 0.235 0.60 0.64]);
ax2 = newax(fig, [0.705 0.235 0.285 0.64]);
off = struct('Map', -0.22, 'PID', 0, 'MapPID', 0.22);
cases = {ax1, 'STEADY', st_w, st_l; ax2, 'SLIP', sl_w, sl_l};
for q = 1:2
    ax = cases{q, 1}; cs = cases{q, 2}; wins = cases{q, 3}; labs = cases{q, 4};
    n = numel(wins);
    patch(ax, [-0.6 n - 0.4 n - 0.4 -0.6], [-10 -10 10 10], [0.88 0.93 0.98], 'EdgeColor', 'none');
    yline(ax, 0, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
    for i = 1:n - 1, xline(ax, i - 0.5, '-', 'Color', [0.88 0.88 0.88], 'LineWidth', 0.4); end
    for k = 1:3
        c = ctrls{k}; s = S.(c);
        y = nan(1, n);
        for i = 1:n
            r = t(strcmp(t.Case, cs) & strcmp(t.Window, wins{i}) & strcmp(t.Ctrl, c), :);
            if ~isempty(r), y(i) = r.(val)(1); end
        end
        plot(ax, (0:n - 1) + off.(c), y, s.m, 'Color', s.c, 'MarkerSize', 5, 'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c, 'LineWidth', 0.9);
    end
    set(ax, 'XLim', [-0.6 n - 0.4], 'YLim', [-20 36], 'XTick', 0:n - 1, 'XTickLabel', [], 'FontSize', 7.5);
    for i = 1:n                                   % two-line tick labels, written by hand
        text(ax, (i - 1 + 0.6) / (n + 0.2 - 0.0), -0.025, labs{i}, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', 7.5, 'Clipping', 'off');
    end
end
set(ax2, 'YTickLabel', []);
ylabel(ax1, 'Signed steady error (% of {\itT}_{ref})', 'FontSize', 9);
text(ax1, 0.5, -0.20, 'STEADY: speed (km/h) / target lateral acceleration (g)', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8, 'Clipping', 'off');
text(ax2, 0.5, -0.20, 'SLIP: scene', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8, 'Clipping', 'off');
text(ax1, 0.015, 0.97, '(a)', 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
text(ax2, 0.03, 0.97, '(b)', 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
text(ax1, 10.45, 10.6, '+10 %', 'FontSize', 7, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [0.35 0.35 0.35]);
text(ax1, 10.45, -10.6, '-10 %', 'FontSize', 7, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Color', [0.35 0.35 0.35]);
h = gobjects(1, 3);
for k = 1:3
    s = S.(ctrls{k});
    h(k) = plot(ax1, nan, nan, s.m, 'Color', s.c, 'MarkerSize', 5, 'MarkerFaceColor', s.mfc, 'MarkerEdgeColor', s.c, 'LineWidth', 0.9);
end
lg = legend(ax1, h, ctrls, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 8);
lg.Units = 'normalized'; lg.Position = [0.30 0.915 0.4 0.07];
save_fig(fig, P, 'Fig_SSW_windows.png');
end

% ------------------------------------------------------------------------------------------------------------ Fig. 11
function fig_lane(P)
S = style();
ctrls = {'Map', 'PID', 'MapPID'};
D = struct();
for k = 1:3
    D.(ctrls{k}) = readtable(fullfile(P.ss, 'fullrate', sprintf('%s_WEAVE_full_s99987.csv', ctrls{k})));
end
t0 = 29.5; t1 = 38.5; band = [1 0.93 0.65];
fig = newfig(6.3, 5.0);
ax = newax(fig, [0.10 0.545 0.885 0.375]);
rows = cell(1, 3);
for k = 1:3
    rows{k} = newax(fig, [0.10, 0.075 + (3 - k) * 0.155, 0.885, 0.135]);
end
for a = [{ax} rows]
    patch(a{1}, [35.3 35.7 35.7 35.3], [-100 -100 100 100], band, 'EdgeColor', 'none');
    yline(a{1}, 0, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.4);
end
ref = D.PID; m = ref.t >= t0 & ref.t <= t1;
plot(ax, ref.t(m), ref.T_d_ref(m), '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 3.2);
for k = 1:3
    c = ctrls{k}; d = D.(c); s = S.(c);
    m = d.t >= t0 & d.t <= t1;
    plot(ax, d.t(m), d.T_s(m), 'Color', s.c, 'LineStyle', s.ls, 'LineWidth', s.lw);
end
set(ax, 'XLim', [t0 t1], 'YLim', [-3.6 4.1], 'XTickLabel', []);
ylabel(ax, '{\itT}_{s} (N\cdotm)');
text(ax, 31.25, 3.95, 'dry road', 'FontSize', 7.5, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
text(ax, 35.8, 3.95, 'puddle, \mu = 0.2', 'FontSize', 7.5, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
h = gobjects(1, 4);
h(1) = plot(ax, nan, nan, '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 3.2);
for k = 1:3
    s = S.(ctrls{k});
    h(k + 1) = plot(ax, nan, nan, 'Color', s.c, 'LineStyle', s.ls, 'LineWidth', s.lw);
end
lg = legend(ax, h, {'{\itT}_{ref}', 'Map', 'PID', 'MapPID'}, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 8);
lg.Units = 'normalized'; lg.Position = [0.22 0.925 0.6 0.07];
ym = 0;
for k = 1:3
    d = D.(ctrls{k}); m = d.t >= t0 & d.t <= t1; ym = max(ym, max(abs(d.T_a(m))));
end
ym = ceil(ym);
for k = 1:3
    c = ctrls{k}; d = D.(c); s = S.(c); a = rows{k};
    m = d.t >= t0 & d.t <= t1;
    plot(a, d.t(m), d.T_a(m), 'Color', s.c, 'LineWidth', 0.7);
    set(a, 'XLim', [t0 t1], 'YLim', [-ym ym], 'YTick', [-5 0 5], 'FontSize', 8);
    ylabel(a, c, 'Color', s.c, 'FontWeight', 'bold', 'FontSize', 8.5);
    if k < 3, set(a, 'XTickLabel', []); else, xlabel(a, 'Time (s)'); end
end
figtext(fig, 0.02, 0.27, '{\itT}_{a} (N\cdotm)', 90);
text(ax, 0.012, 0.95, '(a)', 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
text(rows{1}, 0.012, 0.9, '(b)', 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
save_fig(fig, P, 'Fig_SSW_lane.png');
end
