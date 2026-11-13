% Figures 2.4 and 2.5 of thesis chapter 2 (Documents/Thesis/luanvan.txt) -> Documents/Thesis/figures/.
%   Hinh_2_4_Fy_Tr_vs_alpha.png : lateral force F_yf and road-reaction torque T_r of the front axle against the slip angle, mu = 0.8, 0.5, 0.3
%                                 (formulas of Section 2.3, parameters read from Model/shared/data/params.json)
%   Hinh_2_5_Tref.png           : target torque T_ref(v, a_y) from the fine table of ref.json, with the published points of the coarse table
% Hinh_2_1 .. Hinh_2_3 are the drawings of the paper (see make_fig_thesis_ch2.py); Vietnamese labels are read from the UTF-8 file
% make_fig_thesis_ch2_labels.json so that this file stays ASCII.
%
% Run: matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_ch2.m')"

repoDir = fileparts(fileparts(mfilename('fullpath')));
dataDir = fullfile(repoDir, 'Model', 'shared', 'data');
outDir  = fullfile(repoDir, 'Documents', 'Thesis', 'figures');
lab = jsondecode(fileread(fullfile(repoDir, 'tools', 'make_fig_thesis_ch2_labels.json'), 'Encoding', 'UTF-8'));

P = jsondecode(fileread(fullfile(dataDir, 'params.json'), 'Encoding', 'UTF-8'));
c2 = P.cum2;
m = c2.m.value; lf = c2.l_f.value; lr = c2.l_r.value; g = c2.g.value;
Caf = c2.C_alpha_f.value; C = c2.C.value; E = c2.E.value;
nst = c2.n_st.value; ep0 = c2.e_p0.value; t0 = c2.t_0.value;
ec = ep0 - t0;
Fzf = m * g * lr / (lf + lr);

fyf   = @(al, mu) mu * Fzf .* sin(C * atan(Caf ./ (C * mu * Fzf) .* al - E * (Caf ./ (C * mu * Fzf) .* al - atan(Caf ./ (C * mu * Fzf) .* al))));
trail = @(al, mu) max(0, t0 - t0 * Caf * abs(tan(al)) / (3 * mu * Fzf));
tr    = @(al, mu) (ec + trail(al, mu)) / nst .* fyf(al, mu);

set(groot, 'defaultAxesFontSize', 12, 'defaultLegendFontSize', 11);

%% Figure 2.4: F_yf and T_r against the slip angle
mus = [0.8 0.5 0.3];
aDeg = linspace(0, 12, 1201);
a = deg2rad(aDeg);
fig = figure('Visible', 'off', 'Position', [100 100 1000 400]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile; hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
ax2 = nexttile; hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
co = get(groot, 'defaultAxesColorOrder');
yLab = [11.2 7.6 4.8];   % start heights of the rotated alpha_sl labels (chosen so that they do not cross the curves)
for k = 1:numel(mus)
    mu = mus(k);
    F = fyf(a, mu) / 1000;
    T = tr(a, mu);
    aslDeg = rad2deg(atan(3 * mu * Fzf / Caf));
    [Fpk, iF] = max(F); [Tpk, iT] = max(T);
    fprintf('mu=%.1f: alpha_sl=%.2f deg, F_peak=%.3f kN at %.2f deg, T_peak=%.2f N.m at %.2f deg\n', mu, aslDeg, Fpk, aDeg(iF), Tpk, aDeg(iT));
    plot(ax1, aDeg, F, 'Color', co(k, :), 'LineWidth', 1.8, 'DisplayName', sprintf('%s%.1f', lab.mu_label, mu));
    plot(ax2, aDeg, T, 'Color', co(k, :), 'LineWidth', 1.8, 'DisplayName', sprintf('%s%.1f', lab.mu_label, mu));
    xline(ax2, aslDeg, ':', 'Color', co(k, :), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    text(ax2, aslDeg + 0.12, yLab(k), sprintf('%s%.1f%s', lab.alpha_sl_label, aslDeg, char(176)), 'Color', co(k, :), 'FontSize', 11, 'Rotation', 90, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
end
xlabel(ax1, lab.alpha_xlabel); ylabel(ax1, lab.fy_ylabel); title(ax1, '(a)', 'FontWeight', 'normal');
xlabel(ax2, lab.alpha_xlabel); ylabel(ax2, lab.tr_ylabel); title(ax2, '(b)', 'FontWeight', 'normal');
xlim(ax1, [0 12]); xlim(ax2, [0 12]); ylim(ax1, [0 inf]); ylim(ax2, [0 inf]);
legend(ax1, 'Location', 'southeast'); legend(ax2, 'Location', 'northeast');
exportgraphics(fig, fullfile(outDir, 'Hinh_2_4_Fy_Tr_vs_alpha.png'), 'Resolution', 200);
close(fig);

%% Figure 2.5: target torque
R = jsondecode(fileread(fullfile(dataDir, 'ref.json'), 'Encoding', 'UTF-8'));
vf = R.fine.v_breakpoints_kmh(:)'; af = R.fine.ay_breakpoints_g(:);
tab = R.fine.table_Nm;                      % [a_y index][v index]
assert(isequal(size(tab), [numel(af) numel(vf)]));
vb = R.v_breakpoints_kmh(:)'; ab = R.ay_breakpoints_g(:);
tb = R.table_Nm;                            % [a_y][v] published points
fig = figure('Visible', 'off', 'Position', [100 100 760 500]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
for k = 1:numel(vb)
    j = find(abs(vf - vb(k)) < 1e-9);
    assert(isscalar(j));
    h = plot(ax, af, tab(:, j), 'LineWidth', 1.6, 'Color', co(mod(k - 1, size(co, 1)) + 1, :), 'DisplayName', sprintf('%d%s', vb(k), lab.kmh));
    plot(ax, ab, tb(:, k), 'o', 'Color', h.Color, 'MarkerSize', 7, 'HandleVisibility', 'off');
end
xlabel(ax, lab.ay_xlabel); ylabel(ax, lab.tref_ylabel);
xlim(ax, [0 0.45]); ylim(ax, [0 3.7]);
legend(ax, 'Location', 'southeast');
exportgraphics(fig, fullfile(outDir, 'Hinh_2_5_Tref.png'), 'Resolution', 200);
close(fig);
disp('make_fig_thesis_ch2: done');
