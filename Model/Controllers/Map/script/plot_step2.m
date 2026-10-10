function plot_step2(K_example)
%PLOT_STEP2 Generates Step 2 figures in Result/Controllers/Map/Design/:
%   1. Map_step2_assist_curves.png: M(v, |T_s|) assist curves vs calibration points (5 speeds)
%   2. Map_step2_dry_error.png: Dry-road steady-state error (% of T_d,ref) vs a_y for K_example
%   3. Map_step2_K_accuracy.png: K_acc(v) across all speeds
if nargin < 1, K_example = 6.75; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Design');

Cal = calibrate_map_cached();
spd = [20, 40, 60, 80, 100];
col = [0.12 0.35 0.75; 0.85 0.33 0.10; 0.10 0.60 0.40; 0.55 0.25 0.65; 0.45 0.45 0.45];

% 1. Assist curves M(v, |T_s|)
f1 = figure('Visible', 'off', 'Position', [50 50 900 600]); hold on; grid on;
for i = 1:numel(spd)
    iv = find(Cal.v_kmh == spd(i));
    M = map_table(Cal, iv, K_example, 0.3);
    plot(Cal.Ts{iv}, Cal.Ta{iv}, '.', 'Color', col(i, :), 'MarkerSize', 8, 'HandleVisibility', 'off');
    plot(M.Ts, M.Ta, '-', 'Color', col(i, :), 'LineWidth', 1.5, 'DisplayName', sprintf('%d km/h', spd(i)));
end
xlabel('|T_s| [N.m]'); ylabel('T_a [N.m]'); xlim([0 4]); legend('Location', 'northwest');
title(sprintf('Bản đồ trợ lực M(v, |T_s|) (đường liền, K = %g) và điểm hiệu chỉnh (chấm)', K_example), 'Interpreter', 'none');
exportgraphics(f1, fullfile(outDir, 'Map_step2_assist_curves.png'), 'Resolution', 130);
close(f1);

% 2. Dry-road steady error
f2 = figure('Visible', 'off', 'Position', [50 50 900 600]); hold on; grid on;
patch([0.1 0.3 0.3 0.1], [-3 -3 3 3], [0.9 0.95 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.7, 'HandleVisibility', 'off');
for i = 1:numel(spd)
    iv = find(Cal.v_kmh == spd(i));
    E = map_dry_error(Cal, iv, K_example, 0.3);
    plot(E.ay_g, E.pct, '-', 'Color', col(i, :), 'LineWidth', 1.4, 'DisplayName', sprintf('%d km/h', spd(i)));
end
yline(0, 'k--', 'HandleVisibility', 'off');
xlabel('a_y [g]'); ylabel('e_T / T_{d,ref} [%]'); ylim([-3.5 10]); legend('Location', 'northeast');
title(sprintf('Sai số xác lập e_T trên đường khô với K = %g (vùng xanh: a_y từ 0.1 đến 0.3 g, sai số trong 3 %%)', K_example), 'Interpreter', 'none');
exportgraphics(f2, fullfile(outDir, 'Map_step2_dry_error.png'), 'Resolution', 130);
close(f2);

% 3. K_acc vs speed
csvPath = fullfile(outDir, 'Map_K_for_accuracy.csv');
if ~exist(csvPath, 'file')
    A = map_k_accuracy(3, 0.3);
else
    A = readtable(csvPath);
end
f3 = figure('Visible', 'off', 'Position', [50 50 900 520]); hold on; grid on;
if istable(A)
    plot(A.v_kmh, A.Kmin_for_accuracy, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'DisplayName', 'K_acc(v) (sai số <= 3%)');
else
    plot(A.v_kmh, A.Kmin, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'DisplayName', 'K_acc(v) (sai số <= 3%)');
end
yline(K_example, 'r--', sprintf('K = %g', K_example), 'LineWidth', 1.2, 'DisplayName', sprintf('K ví dụ (%g)', K_example));
xlabel('Vận tốc v [km/h]'); ylabel('Độ dốc K_acc'); ylim([0 15]); legend('Location', 'northeast');
title('Độ dốc tối thiểu K_acc(v) để đạt sai số xác lập <= 3% trong dải 0.1 - 0.3 g', 'Interpreter', 'none');
exportgraphics(f3, fullfile(outDir, 'Map_step2_K_accuracy.png'), 'Resolution', 130);
close(f3);

fprintf('plot_step2: generated 3 figures in %s\n', outDir);
end
