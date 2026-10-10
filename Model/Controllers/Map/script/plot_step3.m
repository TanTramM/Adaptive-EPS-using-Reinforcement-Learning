function plot_step3(K_example)
%PLOT_STEP3 Generates figures for Step 3 in Result/Controllers/Map/Design/:
%   1. Map_step3_lead_design_vs_K.png: Lead parameters (z, p, HF, PM) vs slope limit K
%   2. Map_step3_loop_bode.png: Open-loop Bode plot (60 km/h) with and without lead for K_example
if nargin < 1, K_example = 6.75; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Design');

csvPath = fullfile(outDir, 'Map_stability_lead_sweep.csv');
if ~exist(csvPath, 'file')
    T = sweep_stability();
else
    T = readtable(csvPath);
end

% 1. Lead design vs K
okK = T.stable_lead_found == 1;
T_ok = T(okK, :);

f1 = figure('Visible', 'off', 'Position', [50 50 900 650]);
subplot(2, 1, 1); hold on; grid on;
plot(T_ok.K, T_ok.z_rad_s, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'DisplayName', 'z (điểm không)');
plot(T_ok.K, T_ok.p_rad_s, 'r-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'r', 'DisplayName', 'p (cực)');
set(gca, 'YScale', 'log');
ylabel('Tần số góc [rad/s]'); ylim([5 10000]); legend('Location', 'northwest');
title('Thông số khâu bù sớm pha lead (z, p) theo giới hạn độ dốc K', 'Interpreter', 'none');

subplot(2, 1, 2); hold on; grid on;
yyaxis left;
plot(T_ok.K, T_ok.HF_gain, 'm-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'm', 'DisplayName', 'Độ lợi cao tần HF = K \cdot p/z');
ylabel('Độ lợi tần số cao HF');
yyaxis right;
plot(T_ok.K, T_ok.PM_deg, 'g-d', 'LineWidth', 1.5, 'MarkerFaceColor', 'g', 'DisplayName', 'Dự trữ pha PM [độ]');
yline(45, 'k--', 'PM = 45^\circ', 'HandleVisibility', 'off');
ylabel('Dự trữ pha PM [độ]'); ylim([40 50]);
xlabel('Giới hạn độ dốc K');
title('Độ lợi cao tần (khuếch đại nhiễu) và dự trữ pha PM theo K', 'Interpreter', 'none');
exportgraphics(f1, fullfile(outDir, 'Map_step3_lead_design_vs_K.png'), 'Resolution', 130);
close(f1);

% 2. Open-loop Bode plot with and without lead at 60 km/h, 0.3 g, mu = 0.8
P = map_params();
v_ms = 60 / 3.6;
G = map_plant_lin(P, v_ms, 0.3 * P.g, 0.8);
w = logspace(0, 4, 3000)';
Gjw = squeeze(freqresp(G, w));
wm = 2 * pi * 100;
Gm = wm ./ (1i * w + wm);
delay = exp(-1i * w * 1e-3);

% Find lead parameters for K_example from table
row = find(abs(T_ok.K - K_example) < 1e-3, 1);
if isempty(row)
    z_lead = 59.82; p_lead = 1665.96;
else
    z_lead = T_ok.z_rad_s(row); p_lead = T_ok.p_rad_s(row);
end

% Uncompensated: H = 1
L_uncomp = -K_example * 1.0 .* Gm .* delay .* Gjw;
mag_u = 20 * log10(abs(L_uncomp));
ph_u = unwrap(angle(L_uncomp));
ph_u = rad2deg(ph_u - 2 * pi * round(ph_u(1) / (2 * pi)));

% Compensated: H = (s/z + 1)/(s/p + 1)
H_comp = (1i * w / z_lead + 1) ./ (1i * w / p_lead + 1);
L_comp = -K_example * H_comp .* Gm .* delay .* Gjw;
mag_c = 20 * log10(abs(L_comp));
ph_c = unwrap(angle(L_comp));
ph_c = rad2deg(ph_c - 2 * pi * round(ph_c(1) / (2 * pi)));

f2 = figure('Visible', 'off', 'Position', [50 50 900 650]);
subplot(2, 1, 1); hold on; grid on;
plot(w, mag_u, 'r--', 'LineWidth', 1.3, 'DisplayName', sprintf('Không bù (PM = -6.7^\\circ, mất ổn định)'));
plot(w, mag_c, 'b-', 'LineWidth', 1.5, 'DisplayName', sprintf('Có lead (z = %.1f, p = %.0f rad/s, PM = 45.2^\\circ)', z_lead, p_lead));
yline(0, 'k-', 'HandleVisibility', 'off');
ylabel('Độ lớn |L| [dB]'); set(gca, 'XScale', 'log'); xlim([1 2000]); ylim([-40 40]);
legend('Location', 'northeast');
title(sprintf('Biểu đồ Bode vòng hở L(s) tại 60 km/h (K = %g) - Độ lớn', K_example), 'Interpreter', 'none');

subplot(2, 1, 2); hold on; grid on;
plot(w, ph_u, 'r--', 'LineWidth', 1.3, 'DisplayName', 'Không bù');
plot(w, ph_c, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Có lead (sớm pha)');
yline(-180, 'k--', '-180^\circ', 'HandleVisibility', 'off');
ylabel('Góc pha [độ]'); set(gca, 'XScale', 'log'); xlim([1 2000]); ylim([-250 -60]);
xlabel('Tần số góc \omega [rad/s]'); legend('Location', 'northeast');
title('Biểu đồ Bode vòng hở L(s) - Góc pha và dự trữ pha PM', 'Interpreter', 'none');
exportgraphics(f2, fullfile(outDir, 'Map_step3_loop_bode.png'), 'Resolution', 130);
close(f2);

fprintf('plot_step3: generated 2 figures in %s\n', outDir);
end

