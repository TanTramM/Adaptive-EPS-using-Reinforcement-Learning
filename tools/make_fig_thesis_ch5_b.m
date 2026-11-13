% Figures 5.6 to 5.9 of thesis chapter 5 (sections 5.6 to 5.8); run through make_fig_thesis_ch5.m, which supplies the variables
% repoDir, outDir, lab, co, colr, ctrls, sel and want.
%   Hinh_5_6_WeaveGap.png : MapPID against PID per window of WEAVE, five seeds: RMS of e_T, amplitude ratio and delay of T_s
%                           (Result/Compare/PID_vs_MapPID/PID_vs_MapPID_WEAVE_windows_5seeds.csv)
%   Hinh_5_7_WeaveZoom.png: the window sw1p5 (period 0.667 s) of WEAVE, seed 99999: T_ref and T_s, e_T, the two branches of MapPID, T_a
%                           (Result/Controllers/PID/Cases_ssw_1ms and Result/Controllers/MapPID/Cases_ssw_branch)
%   Hinh_5_8_Robust.png   : section 5.7 (added with that section)
%   Hinh_5_9_VDB.png      : section 5.8 (added with that section)
pvm = fullfile(repoDir, 'Result', 'Compare', 'PID_vs_MapPID');

%% Figure 5.6: gap per window
if want('why')
    A = readtable(fullfile(pvm, 'PID_vs_MapPID_WEAVE_windows_5seeds.csv'));
    wins = {'ctr', 'lane1', 'lane2', 'sw0p3', 'sw0p8', 'sw1p5', 'mu3'};
    idx = cellfun(@(w) find(strcmp(A.window, w)), wins);
    vals = {A.gap_RMS_pct_mean(idx), A.dAmp_pct_mean(idx), A.dDelay_ms_mean(idx)};
    sds  = {A.gap_RMS_pct_std(idx),  A.dAmp_pct_std(idx),  A.dDelay_ms_std(idx)};
    titl = {lab.gap_panel, lab.damp_panel, lab.delay_panel};
    fig = figure('Visible', 'off', 'Position', [100 100 1100 420]);
    tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for p = 1:3
        ax = nexttile(tl, p); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        bar(ax, 1:7, vals{p}, 0.6, 'FaceColor', colr{3}, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
        errorbar(ax, 1:7, vals{p}, sds{p}, 'k', 'LineStyle', 'none', 'LineWidth', 1.0, 'CapSize', 5);
        yline(ax, 0, 'k-', 'LineWidth', 0.8);
        set(ax, 'XTick', 1:7, 'XTickLabel', lab.win_labels, 'XTickLabelRotation', 40);
        xlim(ax, [0.4 7.6]);
        title(ax, titl{p}, 'FontWeight', 'normal');
    end
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_6_WeaveGap.png'), 'Resolution', 200);
    close(fig);

    %% Figure 5.7: zoom on the 0.667 s window
    P = readtable(fullfile(repoDir, 'Result', 'Controllers', 'PID', 'Cases_ssw_1ms', 'PID_WEAVE_sig1ms_s99999.csv'));
    B = readtable(fullfile(repoDir, 'Result', 'Controllers', 'MapPID', 'Cases_ssw_branch', 'MapPID_WEAVE_branch_s99999.csv'));
    xr = [59.0 61.0];
    mP = P.t >= xr(1) & P.t <= xr(2); mB = B.t >= xr(1) & B.t <= xr(2);
    uPID = B.u_P + B.u_I + B.u_D;
    fig = figure('Visible', 'off', 'Position', [100 100 1000 780]);
    tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    h1 = plot(ax1, B.t(mB), B.T_d_ref(mB), '--', 'Color', refCol, 'LineWidth', 1.2, 'DisplayName', lab.legend_Tref);
    h2 = plot(ax1, P.t(mP), P.T_s(mP), '-', 'Color', colr{2}, 'LineWidth', 1.0, 'DisplayName', 'PID');
    h3 = plot(ax1, B.t(mB), B.T_s(mB), '-', 'Color', colr{3}, 'LineWidth', 1.0, 'DisplayName', 'MapPID');
    ylabel(ax1, 'T_s (N{\cdot}m)'); xlim(ax1, xr); set(ax1, 'XTickLabel', []);
    lgd = legend(ax1, [h1 h2 h3], 'Orientation', 'horizontal'); lgd.Layout.Tile = 'north';
    ax2 = nexttile(tl); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    plot(ax2, P.t(mP), P.e_T(mP), '-', 'Color', colr{2}, 'LineWidth', 1.0);
    plot(ax2, B.t(mB), B.e_T(mB), '-', 'Color', colr{3}, 'LineWidth', 1.0);
    ylabel(ax2, lab.eT_ylabel); xlim(ax2, xr); set(ax2, 'XTickLabel', []);
    ax3 = nexttile(tl); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
    plot(ax3, B.t(mB), B.u_map(mB), '-', 'Color', co(1, :), 'LineWidth', 1.0, 'DisplayName', lab.umap);
    plot(ax3, B.t(mB), uPID(mB), '-', 'Color', co(4, :), 'LineWidth', 1.0, 'DisplayName', lab.uPID);
    ylabel(ax3, lab.u_ylabel); xlim(ax3, xr); set(ax3, 'XTickLabel', []);
    legend(ax3, 'Location', 'northeast', 'Orientation', 'horizontal', 'Box', 'off');
    ax4 = nexttile(tl); hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');
    plot(ax4, P.t(mP), P.T_a(mP), '-', 'Color', colr{2}, 'LineWidth', 1.0);
    plot(ax4, B.t(mB), B.T_a(mB), '-', 'Color', colr{3}, 'LineWidth', 1.0);
    ylabel(ax4, lab.Ta_ylabel); xlim(ax4, xr); xlabel(ax4, lab.t_xlabel);
    linkaxes([ax1 ax2 ax3 ax4], 'x');
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_7_WeaveZoom.png'), 'Resolution', 200);
    close(fig);
end

%% Figure 5.8: change of E_RMS when one parameter group moves by -20 % and +20 % (seed 99999, Result/Compare/Robust/Robust_summary_s99999.csv)
if want('robust')
    R = readtable(fullfile(repoDir, 'Result', 'Compare', 'Robust', 'Robust_summary_s99999.csv'));
    groups = {'Tf', 'Jcol', 'Ccol', 'Mass', 'Calpha', 'Trail', 'Caster', 'Motor'};
    cs3 = {'STEADY', 'SLIP', 'WEAVE'}; off = [-0.27 0 0.27];
    xl = {[-40 45], [-52 85], [-14 14]};
    fig = figure('Visible', 'off', 'Position', [100 100 1100 520]);
    tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    hh = gobjects(1, 5);
    for k = 1:3
        ax = nexttile(tl, k); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); if k == 1, ax1 = ax; end
        for g = 1:numel(groups)
            for q = 1:3
                sel_p = strcmp(R.Variant, [groups{g} 'p20']) & strcmp(R.Ctrl, ctrls{q}) & strcmp(R.Case, cs3{k});
                sel_m = strcmp(R.Variant, [groups{g} 'm20']) & strcmp(R.Ctrl, ctrls{q}) & strcmp(R.Case, cs3{k});
                xp = R.dE_pct(sel_p); xm = R.dE_pct(sel_m); y = g + off(q);
                plot(ax, [xm xp], [y y], '-', 'Color', colr{q}, 'LineWidth', 1.4, 'HandleVisibility', 'off');
                plot(ax, xp, y, 'o', 'Color', colr{q}, 'MarkerFaceColor', colr{q}, 'MarkerSize', 6, 'HandleVisibility', 'off');
                plot(ax, xm, y, 'o', 'Color', colr{q}, 'MarkerFaceColor', 'w', 'MarkerSize', 6, 'HandleVisibility', 'off');
            end
        end
        xline(ax, 0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        set(ax, 'YDir', 'reverse', 'YTick', 1:numel(groups), 'YTickLabel', lab.group_labels, 'YLim', [0.5 numel(groups) + 0.5]);
        if k > 1, set(ax, 'YTickLabel', []); end
        xlim(ax, xl{k}); xlabel(ax, lab.dE_xlabel);
        title(ax, cs3{k}, 'FontWeight', 'bold');
        if k == 1
            for q = 1:3, hh(q) = plot(ax, NaN, NaN, '-o', 'Color', colr{q}, 'MarkerFaceColor', colr{q}, 'LineWidth', 1.4, 'DisplayName', ctrls{q}); end
            hh(4) = plot(ax, NaN, NaN, 'o', 'Color', [0.35 0.35 0.35], 'MarkerFaceColor', [0.35 0.35 0.35], 'LineStyle', 'none', 'DisplayName', lab.legend_p20);
            hh(5) = plot(ax, NaN, NaN, 'o', 'Color', [0.35 0.35 0.35], 'MarkerFaceColor', 'w', 'LineStyle', 'none', 'DisplayName', lab.legend_m20);
        end
    end
    lgd = legend(ax1, hh, 'Orientation', 'horizontal', 'NumColumns', 5); lgd.Layout.Tile = 'south';
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_8_Robust.png'), 'Resolution', 200);
    close(fig);
end

%% Figure 5.9: change of E_RMS when the Plant blocks are replaced by Vehicle Dynamics Blockset blocks (seed 99999)
if want('vdb')
    S = readtable(fullfile(repoDir, 'Model', 'VDB', 'temp_test', 'Summary', 'VDB_body_summary_s99999.csv'));   % columns: variant, controller, case, RMS_eT_Nm, S_Nm, dRMS_eT_pct, dS_pct
    vars = {'VDBBody', 'VDBTireBody', 'VDBTireLag', 'VDBTireLagBody'};
    cs3 = {'STEADY', 'SLIP', 'WEAVE'};
    fig = figure('Visible', 'off', 'Position', [100 100 1100 440]);
    tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    for k = 1:3
        ax = nexttile(tl, k); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        Y = nan(numel(vars), 3);
        for v = 1:numel(vars)
            for q = 1:3
                m = strcmp(S{:, 1}, vars{v}) & strcmp(S{:, 2}, ctrls{q}) & strcmp(S{:, 3}, cs3{k});
                Y(v, q) = S{m, 6};
            end
        end
        b = bar(ax, Y, 0.8, 'grouped');
        for q = 1:3, b(q).FaceColor = colr{q}; b(q).EdgeColor = 'none'; b(q).DisplayName = ctrls{q}; end
        yline(ax, 0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        set(ax, 'XTick', 1:numel(vars), 'XTickLabel', lab.vdb_labels, 'XTickLabelRotation', 25);
        ylim(ax, [-9 6]);
        title(ax, cs3{k}, 'FontWeight', 'bold');
        if k == 1, ylabel(ax, lab.dE_vdb_ylabel); legend(ax, 'Location', 'southwest'); else, set(ax, 'YTickLabel', []); end
    end
    exportgraphics(fig, fullfile(outDir, 'Hinh_5_9_VDB.png'), 'Resolution', 200);
    close(fig);
end
