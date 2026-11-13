function plot_robust()
%PLOT_ROBUST Figures of KeHoach_DoBenThamSo.txt section 6, read from Robust_summary_s99999.csv and the run_cases csv (run summarize_robust('tables') first).
%   Robust_tornado_<CASE>_s99999.png   Delta E_RMS (%) per parameter group, +20 % (solid) and -20 % (light), Map, PID, MapPID
%   Robust_bias_STEADY_s99999.png      epsilon_w of the STEADY windows, nom (black) and every variant (grey), one panel per controller
%   Robust_worst_<CASE>_resp_s99999.png T_s and T_d,ref of the variant with the largest |Delta E_RMS| of Map, Map and MapPID overlaid
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
repoDir = fileparts(modelDir);
addpath(fullfile(modelDir, 'shared')); setup_paths;
rootDir = fullfile(repoDir, 'Result', 'Compare', 'Robust');
tag = 's99999';
T = readtable(fullfile(rootDir, sprintf('Robust_summary_%s.csv', tag)), 'VariableNamingRule', 'preserve');
ctrls = {'Map', 'PID', 'MapPID'}; cases = {'STEADY', 'SLIP', 'WEAVE'};
col = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
groups = robust_variants('groups');

for c = 1:numel(cases)
    f = figure('Visible', 'off', 'Position', [50 50 900 600]); hold on;
    h = gobjects(1, 3);
    for g = 1:numel(groups)
        for i = 1:numel(ctrls)
            y = g + (i - 2) * 0.25;
            a = T.dE_pct(strcmp(T.Variant, [groups{g} 'p20']) & strcmp(T.Ctrl, ctrls{i}) & strcmp(T.Case, cases{c}));
            b = T.dE_pct(strcmp(T.Variant, [groups{g} 'm20']) & strcmp(T.Ctrl, ctrls{i}) & strcmp(T.Case, cases{c}));
            barh(y, a, 0.11, 'FaceColor', col(i, :), 'EdgeColor', 'none');
            h(i) = barh(y - 0.11, b, 0.11, 'FaceColor', col(i, :), 'FaceAlpha', 0.4, 'EdgeColor', 'none');
        end
    end
    set(gca, 'YTick', 1:numel(groups), 'YTickLabel', groups, 'YDir', 'reverse'); grid on; box on;
    xlabel('\Delta E_{RMS} (%)  (solid: +20 %, light: -20 %)'); title(sprintf('Robustness, case %s, seed 99999', cases{c}));
    legend(h, ctrls, 'Location', 'best');
    exportgraphics(f, fullfile(rootDir, sprintf('Robust_tornado_%s_%s.png', cases{c}, tag)), 'Resolution', 130); close(f);
end

% bias of the STEADY windows
names = robust_variants();
f = figure('Visible', 'off', 'Position', [50 50 1100 700]);
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); title(tl, 'epsilon_w of the STEADY windows (% of T_{d,ref}; negative = lighter hand)');
for i = 1:numel(ctrls)
    nexttile; hold on; grid on;
    for k = 1:numel(names)
        M = readtable(fullfile(rootDir, names{k}, sprintf('%s_metrics_%s.csv', ctrls{i}, tag)), 'VariableNamingRule', 'preserve');
        w = strcmp(M.Case, 'STEADY') & ~strcmp(M.Window, 'whole case') & isfinite(M.Mean_eT_signed_pct_of_Tdref);
        if strcmp(names{k}, 'nom'), plot(M.Mean_eT_signed_pct_of_Tdref(w), 'k-o', 'LineWidth', 1.8); else, plot(M.Mean_eT_signed_pct_of_Tdref(w), '-', 'Color', [0.65 0.65 0.65]); end
    end
    ylabel([ctrls{i} ' (%)']); if i == 3, xlabel('window index (STEADY)'); end
end
exportgraphics(f, fullfile(rootDir, sprintf('Robust_bias_STEADY_%s.png', tag)), 'Resolution', 130); close(f);

% worst variant of Map per case (rule fixed in advance: largest |Delta E_RMS| of Map)
for c = 1:numel(cases)
    m = strcmp(T.Ctrl, 'Map') & strcmp(T.Case, cases{c}) & ~strcmp(T.Variant, 'nom');
    V = T.Variant(m); d = abs(T.dE_pct(m)); [~, j] = max(d); wv = V{j};
    f = figure('Visible', 'off', 'Position', [50 50 1100 450]); hold on; grid on;
    for i = [1 3]
        S = readtable(fullfile(rootDir, wv, sprintf('%s_%s_sig_%s.csv', ctrls{i}, cases{c}, tag)), 'VariableNamingRule', 'preserve');
        plot(S.t, S.T_s, 'Color', col(i, :), 'DisplayName', [ctrls{i} ' T_s']);
        if i == 1, plot(S.t, S.T_d_ref, 'k--', 'DisplayName', 'T_{d,ref}'); end
    end
    xlabel('t (s)'); ylabel('N.m'); legend('Location', 'best');
    title(sprintf('%s: variant %s (largest |\\Delta E_{RMS}| of Map, %+.1f %%)', cases{c}, wv, T.dE_pct(strcmp(T.Variant, wv) & strcmp(T.Ctrl, 'Map') & strcmp(T.Case, cases{c}))));
    exportgraphics(f, fullfile(rootDir, sprintf('Robust_worst_%s_resp_%s.png', cases{c}, tag)), 'Resolution', 130); close(f);
end
end
