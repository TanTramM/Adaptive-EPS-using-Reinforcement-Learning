function plot_calibration(Cal)
%PLOT_CALIBRATION Figures of the dry-road calibration points (calibrate_map.m).
%   Writes to Result/Controllers/Map/Design/:
%     Map_calibration_Ta_vs_Ts.png        T_a,cal against T_s,cal at 5 speeds (the points the assist map passes through)
%     Map_calibration_natural_slope.png   natural slope dT_a/dT_s against a_y at the same speeds
if nargin < 1, Cal = calibrate_map(); end
outDir = result_dir('Map', 'Design');
col = [0.12 0.35 0.75; 0.85 0.33 0.10; 0.10 0.60 0.40; 0.55 0.25 0.65; 0.45 0.45 0.45];
spd = [20 40 60 80 100];

f = figure('Visible', 'off', 'Position', [50 50 900 600]); hold on; grid on;
for k = 1:numel(spd)
    i = find(Cal.v_kmh == spd(k));
    plot(Cal.Ts{i}, Cal.Ta{i}, '.-', 'Color', col(k, :), 'MarkerSize', 7, 'DisplayName', sprintf('%d km/h', spd(k)));
    yline(Cal.Ta_max(i), ':', 'Color', col(k, :), 'HandleVisibility', 'off');
end
xlabel('T_{s,cal} = T_{d,ref} [N.m]'); ylabel('T_{a,cal} [N.m]'); legend('Location', 'northwest');
title('Điểm hiệu chỉnh trên đường khô (\mu = 0.8), a_y từ 0.1 g; đường chấm: T_{a,max}(v) = T_{a,req} + F');
exportgraphics(f, fullfile(outDir, 'Map_calibration_Ta_vs_Ts.png'), 'Resolution', 130); close(f);

f = figure('Visible', 'off', 'Position', [50 50 900 600]); hold on; grid on;
for k = 1:numel(spd)
    i = find(Cal.v_kmh == spd(k));
    plot(Cal.ay_g{i}(2:end), Cal.slope{i}(2:end), '-', 'Color', col(k, :), 'LineWidth', 1.2, 'DisplayName', sprintf('%d km/h', spd(k)));
end
set(gca, 'YScale', 'log'); xlabel('a_y [g]'); ylabel('độ dốc tự nhiên dT_a/dT_s'); legend('Location', 'northwest');
title('Độ dốc bản đồ cần có để đi qua mọi điểm hiệu chỉnh');
exportgraphics(f, fullfile(outDir, 'Map_calibration_natural_slope.png'), 'Resolution', 130); close(f);
end
