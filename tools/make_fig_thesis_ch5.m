% Figures of thesis chapter 5 (Documents/Thesis/luanvan.txt), drawn in MATLAB from the result files; nothing is typed by hand.
%   Hinh_5_1_Profile.png : the three evaluation sequences STEADY, SLIP, WEAVE (speed, friction coefficient, prescribed steering-wheel angle, scoring windows)
%   Hinh_5_2_STEADY.png, Hinh_5_3_SLIP.png, Hinh_5_4_WEAVE.png : torsion-bar torque T_s and target T_ref of Map, PID and MapPID, seed 99999,
%                          whole sequence (left) and one enlarged event (right)
%   Hinh_5_5_Seeds.png   : E_RMS and S of PID and MapPID for the five seeds 99995-99999
%   (sections 5.6 to 5.8 add more figures to this file: Hinh_5_6 ... Hinh_5_9)
% Vietnamese labels come from the UTF-8 file make_fig_thesis_ch5_labels.json so that this file stays ASCII.
% (The paper's Figs. 8-14 were drawn by tools/make_fig_section5.py with matplotlib; the thesis redraws them here in MATLAB and adds PID to the time plots.)
%
% Run all:      matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_ch5.m')"
% Run one part: matlab -softwareopengl -batch "sel='seeds'; run('<repo>\tools\make_fig_thesis_ch5.m')"   (sel: prof, steady, slip, weave, seeds, why, robust, vdb)

if ~exist('sel', 'var'), sel = 'all'; end
want = @(k) any(strcmp(sel, {'all', k}));
repoDir = fileparts(fileparts(mfilename('fullpath')));
ctrlDir = fullfile(repoDir, 'Result', 'Controllers');
outDir  = fullfile(repoDir, 'Documents', 'Thesis', 'figures');
lab = jsondecode(fileread(fullfile(repoDir, 'tools', 'make_fig_thesis_ch5_labels.json'), 'Encoding', 'UTF-8'));
set(groot, 'defaultAxesFontSize', 10, 'defaultLegendFontSize', 9);
co = get(groot, 'defaultAxesColorOrder');
ctrls = {'Map', 'PID', 'MapPID'};
colr  = {co(1, :), co(2, :), co(5, :)};
cases = {'STEADY', 'SLIP', 'WEAVE'};
seedMain = 99999;
refCol = [0.25 0.25 0.25];
shade  = [0.85 0.85 0.85];

%% Figure 5.1: the three sequences
if want('prof')
    W = readtable(fullfile(repoDir, 'Result', 'Compare', 'SSW_summary', 'SSW_windows.csv'));
    fig = figure('Visible', 'off', 'Position', [100 100 1100 640]);
    tl = tiledlayout(fig, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for c = 1:3
        S = loadsig('MapPID', cases{c}, seedMain, ctrlDir);
        ax1 = nexttile(tl, c);     plot(ax1, S.t, S.v_mps * 3.6, 'LineWidth', 1.3, 'Color', co(1, :));
        grid(ax1, 'on'); box(ax1, 'on'); xlim(ax1, [0 100]); ylim(ax1, [0 100]); set(ax1, 'XTickLabel', []);
        title(ax1, cases{c}, 'FontWeight', 'bold');
        if c == 1, ylabel(ax1, lab.v_ylabel); else, set(ax1, 'YTickLabel', []); end
        ax2 = nexttile(tl, 3 + c); plot(ax2, S.t, S.mu, 'LineWidth', 1.3, 'Color', co(1, :));
        grid(ax2, 'on'); box(ax2, 'on'); xlim(ax2, [0 100]); ylim(ax2, [0 1]); set(ax2, 'XTickLabel', []);
        if c == 1, ylabel(ax2, lab.mu_ylabel); else, set(ax2, 'YTickLabel', []); end
        ax3 = nexttile(tl, 6 + c); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
        th = rad2deg(S.theta1_rad); yl = niceLim(th);
        Wc = W(strcmp(W{:, 4}, cases{c}), :);                    % column 4 is 'case', a MATLAB keyword, so it is addressed by position
        for j = 1:height(Wc)
            patch(ax3, [Wc.t0(j) Wc.t1(j) Wc.t1(j) Wc.t0(j)], [yl(1) yl(1) yl(2) yl(2)], shade, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        plot(ax3, S.t, th, 'LineWidth', 1.0, 'Color', 'k', 'HandleVisibility', 'off');
        xlim(ax3, [0 100]); ylim(ax3, yl);
        xlabel(ax3, lab.t_xlabel);
        ylabel(ax3, lab.th_ylabel);
        if c == 1
            hw = patch(ax3, NaN, NaN, shade, 'EdgeColor', 'none', 'DisplayName', lab.legend_win);
        end
        fprintf('%s: %d windows, v %.0f-%.0f km/h, mu %.2f-%.2f, theta1 %.1f..%.1f deg\n', cases{c}, height(Wc), min(S.v_mps) * 3.6, max(S.v_mps) * 3.6, min(S.mu), max(S.mu), min(th), max(th));
    end
    lgd = legend(ax3, hw, 'Orientation', 'horizontal'); lgd.Layout.Tile = 'south';       % legend below the whole layout so that it hides no data
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_1_Profile.png'), 'Resolution', 200);
    close(fig);
end

%% Figures 5.2 to 5.4: time responses of the three controllers
zoomWin = struct('STEADY', [33 42], 'SLIP', [83 91], 'WEAVE', [33 39]);
figNum  = struct('STEADY', 2, 'SLIP', 3, 'WEAVE', 4);
for k = 1:3
    cs = cases{k};
    if ~want(lower(cs)), continue; end
    D = cell(1, 3);
    for q = 1:3, D{q} = loadsig(ctrls{q}, cs, seedMain, ctrlDir); end
    zw = zoomWin.(cs);
    fig = figure('Visible', 'off', 'Position', [100 100 1100 700]);
    tl = tiledlayout(fig, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for q = 1:3
        for side = 1:2
            if side == 1, ax = nexttile(tl, (q - 1) * 3 + 1, [1 2]); xr = [0 100]; else, ax = nexttile(tl, (q - 1) * 3 + 3); xr = zw; end
            hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
            S = D{q};
            % common vertical range of the three controllers in the visible part
            lo = inf; hi = -inf;
            for p = 1:3
                m = D{p}.t >= xr(1) & D{p}.t <= xr(2);
                lo = min([lo; D{p}.T_s(m); D{p}.T_d_ref(m)]); hi = max([hi; D{p}.T_s(m); D{p}.T_d_ref(m)]);
            end
            pad = 0.06 * (hi - lo); yl = [lo - pad, hi + pad];
            lowMu = S.mu < 0.79;
            if any(lowMu)
                d = diff([0; lowMu(:); 0]); i0 = find(d == 1); i1 = find(d == -1) - 1;
                for j = 1:numel(i0)
                    patch(ax, [S.t(i0(j)) S.t(i1(j)) S.t(i1(j)) S.t(i0(j))], [yl(1) yl(1) yl(2) yl(2)], shade, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                end
            end
            hr = plot(ax, S.t, S.T_d_ref, '--', 'Color', refCol, 'LineWidth', 1.1, 'DisplayName', lab.legend_Tref);
            hs = plot(ax, S.t, S.T_s, '-', 'Color', colr{q}, 'LineWidth', 1.0, 'DisplayName', lab.legend_Ts);
            xlim(ax, xr); ylim(ax, yl);
            if side == 1
                text(ax, 0.008, 0.90, ctrls{q}, 'Units', 'normalized', 'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 1);
                xline(ax, zw(1), ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off'); xline(ax, zw(2), ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
                if q == 1, title(ax, lab.panel_all, 'FontWeight', 'normal'); end
            else
                if q == 1, title(ax, lab.panel_zoom, 'FontWeight', 'normal'); end
            end
            if q < 3, set(ax, 'XTickLabel', []); end
            if q == 1 && side == 1, axFirst = ax; hFirst = [hr hs]; end
        end
    end
    lgd = legend(axFirst, hFirst, 'Orientation', 'horizontal'); lgd.Layout.Tile = 'north';   % legend above the layout so that it hides no data
    tl.XLabel.String = lab.t_xlabel; tl.YLabel.String = lab.T_ylabel;
    exportgraphics(fig, fullfile(outDir, sprintf('Hinh_5_%d_%s.png', figNum.(cs), cs)), 'Resolution', 200);
    close(fig);
end

%% Figure 5.5: five seeds
if want('seeds')
    seeds = 99995:99999;
    fig = figure('Visible', 'off', 'Position', [100 100 1100 600]);
    tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    mk = {'^', 'o'}; ce = {'PID', 'MapPID'}; cc = {colr{2}, colr{3}};
    for row = 1:2
        for c = 1:3
            ax = nexttile(tl, (row - 1) * 3 + c); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
            for q = 1:2
                v = nan(1, 5);
                for i = 1:5
                    T = readtable(fullfile(ctrlDir, ce{q}, 'Cases_ssw', sprintf('%s_metrics_s%05d.csv', ce{q}, seeds(i))));
                    r = T(strcmp(T.Case, cases{c}) & strcmp(T.Window, 'whole case'), :);
                    if row == 1, v(i) = r.RMS_eT_Nm; else, v(i) = r.S_Nm; end
                end
                plot(ax, 1:5, v, ['-' mk{q}], 'Color', cc{q}, 'MarkerFaceColor', cc{q}, 'LineWidth', 1.1, 'MarkerSize', 6, 'DisplayName', ce{q});
            end
            xlim(ax, [0.5 5.5]); set(ax, 'XTick', 1:5, 'XTickLabel', arrayfun(@(s) sprintf('%d', s - 99990), seeds, 'UniformOutput', false));
            if row == 1, title(ax, cases{c}, 'FontWeight', 'bold'); end
            if c == 1, if row == 1, ylabel(ax, lab.E_ylabel); else, ylabel(ax, lab.S_ylabel); end, end
            if row == 2, xlabel(ax, [lab.seed_xlabel ' 9999x']); end
            if row == 1 && c == 1, legend(ax, 'Location', 'best'); end
        end
    end
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_5_Seeds.png'), 'Resolution', 200);
    close(fig);
end

fileB = fullfile(repoDir, 'tools', 'make_fig_thesis_ch5_b.m');      % sections 5.6 to 5.8, added when those sections are written
if exist(fileB, 'file') && any(strcmp(sel, {'all', 'why', 'robust', 'vdb'})), run(fileB); end
disp('make_fig_thesis_ch5: done');

%% local functions
function S = loadsig(ctrl, cs, seed, ctrlDir)
    S = readtable(fullfile(ctrlDir, ctrl, 'Cases_ssw', sprintf('%s_%s_sig_s%05d.csv', ctrl, cs, seed)));
end

function yl = niceLim(x)
    lo = min(x); hi = max(x); span = max(hi - lo, 1);
    step = 10^floor(log10(span));
    yl = [floor((lo - 0.05 * span) / step) * step, ceil((hi + 0.05 * span) / step) * step];
end
