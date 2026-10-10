function plot_step5()
%PLOT_STEP5 Step 5: Plot Pareto front (R, S) and performance metrics vs K for the Map controller.
%
%   Generates:
%     1. Result/Controllers/Map/Design/Map_step5_pareto_TK.png
%     2. Result/Controllers/Map/Design/Map_step5_metrics_vs_K.png

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('Map', 'Design');
candFile = fullfile(outDir, 'Map_candidates_TK.csv');
paretoFile = fullfile(outDir, 'Map_pareto.csv');
selFile = fullfile(outDir, 'Map_selection.csv');

if ~exist(paretoFile, 'file') || ~exist(selFile, 'file')
    error('plot_step5:missing_files', 'Required result files not found in %s. Run design_map first.', outDir);
end

P = readtable(paretoFile);
S = readtable(selFile);
C = readtable(candFile);

chosenRow = S(S.chosen == true, :);
if isempty(chosenRow), chosenRow = S(1, :); end

%% 1. Figure 1: Pareto front (R, S) on case TK
fig1 = figure('Name', 'Map_step5_pareto_TK', 'Color', 'w', 'Position', [100, 100, 850, 600]);
ax1 = axes('Parent', fig1);
hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');

% Flags as logical
adm = logical(P.admissible);
inadm = ~adm;

% Inadmissible points
if any(inadm)
    scatter(ax1, P.R_pct(inadm), P.S_Nm(inadm), 60, [0.6 0.6 0.6], 'x', 'LineWidth', 1.5, ...
        'DisplayName', 'Bị loại (cổng cứng: ổn định, chính xác, an toàn, bang-bang)');
    for i = find(inadm)'
        if isfinite(P.R_pct(i)) && isfinite(P.S_Nm(i))
            text(ax1, P.R_pct(i), P.S_Nm(i), sprintf('  K=%.2f', P.K(i)), ...
                'FontSize', 8, 'Color', [0.5 0.5 0.5], 'VerticalAlignment', 'bottom');
        end
    end
end

% Admissible points
scatter(ax1, P.R_pct(adm), P.S_Nm(adm), 70, [0.15 0.45 0.85], 'o', 'filled', ...
    'DisplayName', 'Hợp lệ (thỏa 4 cổng cứng)');
for i = find(adm)'
    text(ax1, P.R_pct(i), P.S_Nm(i), sprintf('  K=%.2f', P.K(i)), ...
        'FontSize', 8.5, 'Color', [0.1 0.3 0.7], 'VerticalAlignment', 'bottom');
end

% Pareto front curve
frontRows = P(logical(P.on_front), :);
frontRows = sortrows(frontRows, 'R_pct');
if height(frontRows) >= 2
    plot(ax1, frontRows.R_pct, frontRows.S_Nm, '--', 'Color', [0.8 0.3 0.1], 'LineWidth', 1.8, ...
        'DisplayName', 'Ranh giới Pareto (R, S)');
end

% Tolerance boundary 5%
Rmin = min(P.R_pct(adm));
Rtol = 1.05 * Rmin;
yl = get(ax1, 'YLim');
plot(ax1, [Rtol, Rtol], [0, 2], ':', 'Color', [0.7 0.1 0.1], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Dung sai 5%%: R <= %.2f%%', Rtol));

% Finalists
scatter(ax1, S.R_pct, S.S_Nm, 110, [0.9 0.6 0.0], 'd', 'LineWidth', 1.8, ...
    'DisplayName', 'Nhóm chung kết (R \\le 1.05 R_{min})');

% Chosen point
scatter(ax1, chosenRow.R_pct, chosenRow.S_Nm, 220, [0.85 0.1 0.1], 'p', 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Điểm chọn tối ưu (K=%.2f, R=%.2f%%, S=%.4f N.m)', ...
    chosenRow.K, chosenRow.R_pct, chosenRow.S_Nm));

xlabel(ax1, 'Sai số bám R [%] (nhỏ hơn tốt hơn)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel(ax1, 'Độ êm dịu S [N.m] (RMS tần số cao, nhỏ hơn tốt hơn)', 'FontSize', 11, 'FontWeight', 'bold');
title(ax1, sprintf('Mặt phẳng Pareto (R, S) và Điểm chọn tối ưu của Bộ điều khiển Map (Ca TK 117s)\nK_{acc} = 6.75, K_{stab} = 9.5, K_{opt} = %.2f', ...
    chosenRow.K), 'FontSize', 12, 'FontWeight', 'bold');

legend(ax1, 'Location', 'northeast', 'FontSize', 9);
xlim(ax1, [min(P.R_pct(adm))*0.95, max(P.R_pct(P.R_pct < 100))*1.08]);
ylim(ax1, [min(P.S_Nm(adm))*0.85, max(P.S_Nm(P.S_Nm < 5))*1.15]);

outFig1 = fullfile(outDir, 'Map_step5_pareto_TK.png');
exportgraphics(fig1, outFig1, 'Resolution', 300);
close(fig1);
fprintf('plot_step5: Saved %s\n', outFig1);

%% 2. Figure 2: Metrics vs K
validK = C(isfinite(C.R_pct) & C.K <= 9.5, :);
validK = sortrows(validK, 'K');

fig2 = figure('Name', 'Map_step5_metrics_vs_K', 'Color', 'w', 'Position', [150, 150, 950, 750]);

% Subplot 1: R and erel
ax2_1 = subplot(3, 1, 1, 'Parent', fig2);
hold(ax2_1, 'on'); grid(ax2_1, 'on'); box(ax2_1, 'on');
plot(ax2_1, validK.K, validK.R_pct, '-o', 'Color', [0.15 0.45 0.85], 'LineWidth', 1.8, 'MarkerFaceColor', [0.15 0.45 0.85], 'DisplayName', 'R [%] (tổng thể ca TK)');
plot(ax2_1, validK.K, validK.erel_pct, '-s', 'Color', [0.85 0.35 0.15], 'LineWidth', 1.8, 'MarkerFaceColor', [0.85 0.35 0.15], 'DisplayName', 'e_{rel} [%] (sai số tĩnh lớn nhất)');
xline(ax2_1, 6.75, '--r', 'K_{acc} = 6.75', 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
xline(ax2_1, 9.5, '--m', 'K_{stab} = 9.5', 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
xline(ax2_1, chosenRow.K, '-g', sprintf('K_{opt} = %.2f', chosenRow.K), 'LineWidth', 2);
ylabel(ax2_1, 'Sai số [%]', 'FontWeight', 'bold');
title(ax2_1, 'Đặc tính Hiệu năng và Ổn định của Map Controller theo Độ dốc K_{max}', 'FontWeight', 'bold', 'FontSize', 12);
legend(ax2_1, 'Location', 'northeast');

% Subplot 2: S and TV
ax2_2 = subplot(3, 1, 2, 'Parent', fig2);
yyaxis(ax2_2, 'left');
plot(ax2_2, validK.K, validK.S_Nm, '-^', 'LineWidth', 1.8, 'DisplayName', 'S [N.m] (độ rung giật)');
ylabel(ax2_2, 'S [N.m]', 'FontWeight', 'bold');
yyaxis(ax2_2, 'right');
plot(ax2_2, validK.K, validK.TV_Nm_per_s, '-v', 'LineWidth', 1.8, 'DisplayName', 'TV [N.m/s] (biến thiên mô-men)');
ylabel(ax2_2, 'TV [N.m/s]', 'FontWeight', 'bold');
grid(ax2_2, 'on'); box(ax2_2, 'on');
xline(ax2_2, chosenRow.K, '-g', sprintf('K_{opt} = %.2f', chosenRow.K), 'LineWidth', 2);
legend(ax2_2, 'Location', 'northwest');

% Subplot 3: Lead compensator parameters (z, p, PM)
ax2_3 = subplot(3, 1, 3, 'Parent', fig2);
yyaxis(ax2_3, 'left');
semilogy(ax2_3, validK.K, validK.z_rad_s, '-o', 'LineWidth', 1.5, 'DisplayName', 'Zero z [rad/s]');
hold(ax2_3, 'on');
semilogy(ax2_3, validK.K, validK.p_rad_s, '-s', 'LineWidth', 1.5, 'DisplayName', 'Cực p [rad/s]');
ylabel(ax2_3, 'Tần số [rad/s] (log scale)', 'FontWeight', 'bold');
yyaxis(ax2_3, 'right');
plot(ax2_3, validK.K, validK.PM_deg, '-d', 'Color', [0.4 0.7 0.2], 'LineWidth', 1.8, 'DisplayName', 'PM [deg] (>= 45 deg)');
ylabel(ax2_3, 'Độ dự trữ pha PM [^\circ]', 'FontWeight', 'bold');
ylim(ax2_3, [40, 50]);
grid(ax2_3, 'on'); box(ax2_3, 'on');
xlabel(ax2_3, 'Hệ số độ dốc trợ lực K_{max} [N.m/(N.m)]', 'FontWeight', 'bold');
xline(ax2_3, chosenRow.K, '-g', sprintf('K_{opt} = %.2f', chosenRow.K), 'LineWidth', 2);
legend(ax2_3, 'Location', 'northwest');

outFig2 = fullfile(outDir, 'Map_step5_metrics_vs_K.png');
exportgraphics(fig2, outFig2, 'Resolution', 300);
close(fig2);
fprintf('plot_step5: Saved %s\n', outFig2);
end

