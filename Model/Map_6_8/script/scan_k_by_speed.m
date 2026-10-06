function T = scan_k_by_speed(Ks)
%SCAN_K_BY_SPEED Steady error of the map on the dry road versus speed for several K_max, one lead stage each; basis of the speed tiers.
%
%   T = scan_k_by_speed()           K_max = 6 8 10 12 18
%
%   For every K_max (one value for all speeds, calibrate_map(K,'')): the lead stage with the best high-frequency gain that gives
%   PM >= 45 deg over Kv in (0, K_max] with the motor lag (PM and GM of the best stage are reported even when 45 deg is not reached), and
%   for every speed the largest steady error |T_s - T_d,ref| / T_d,ref [%] over the calibration points with 0.1 g <= a_y <= 0.3 g (dry
%   road, steady state: T_s + M(v, T_s) = T_d,ref + T_a,cal). Also the largest natural slope of the calibration curve (equation (11) of
%   Documents/Map_6_8/map.txt) in the same range, i.e. the K_max needed to follow every calibration point at that speed.
%   Writes Result/Map_6_8/KSweep/Map_error_by_speed_and_K.csv (long format) and Map_error_by_speed_and_K.png.

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
if nargin < 1, Ks = [6 8 10 12 18]; end
outDir = result_dir('Map_6_8', 'KSweep');
vs = 20:5:100;
rows = [];
need = zeros(size(vs));
for Km = Ks
    c = calibrate_map(Km, '');
    tab = c.Ta_table_Nm; tsBp = c.Ts_breakpoints_Nm;
    for j = 1:numel(vs)
        cj = c.calibration(j);
        sel = cj.ay_g >= 0.1 - 1e-9 & cj.ay_g <= 0.3 + 1e-9;
        worst = 0;
        for i = find(sel)
            Td = cj.Ts_Nm(i); Tr = Td + cj.Ta_Nm(i);
            Ts = fzero(@(x) x + interp1(tsBp, tab(j, :), min(max(x, 0), tsBp(end)), 'linear') - Tr, [0 Tr]);
            worst = max(worst, 100 * abs(Ts - Td) / Td);
        end
        sl = diff(cj.Ta_Nm) ./ diff(cj.Ts_Nm);
        mid = (cj.ay_g(1:end-1) + cj.ay_g(2:end)) / 2;
        need(j) = max(sl(mid >= 0.1 - 1e-9 & mid <= 0.3 + 1e-9));
        rows = [rows; Km, vs(j), worst, need(j), c.lead.min_phase_margin_deg, c.lead.min_gain_margin, ...
            c.lead.pole_rad_s / c.lead.zero_rad_s, c.lead.zero_rad_s, c.lead.pole_rad_s]; %#ok<AGROW>
    end
end
T = array2table(rows, 'VariableNames', {'K_max', 'v_kmh', 'max_error_pct_0p1_to_0p3g', 'natural_slope_needed', 'PM_deg', 'GM', ...
    'lead_p_over_z', 'lead_z_rad_s', 'lead_p_rad_s'});
writetable(T, fullfile(outDir, 'Map_error_by_speed_and_K.csv'));

f = figure('Visible', 'off', 'Position', [100 100 900 600]);
subplot(2, 1, 1); hold on; grid on; box on;
for Km = Ks
    s = T.K_max == Km;
    plot(T.v_kmh(s), T.max_error_pct_0p1_to_0p3g(s), '-o', 'LineWidth', 1.4, 'MarkerSize', 4, ...
        'DisplayName', sprintf('K_{max} = %g (PM %.1f^o)', Km, T.PM_deg(find(s, 1))));
end
yline(3, '--k', '3 %', 'HandleVisibility', 'off');
ylabel('Sai số xác lập lớn nhất [%]'); title('Đường khô, 0.1 g đến 0.3 g: sai số xác lập của bản đồ theo vận tốc'); legend('Location', 'northeast');
ylim([0 14]);
subplot(2, 1, 2); hold on; grid on; box on;
s = T.K_max == Ks(1);
plot(T.v_kmh(s), T.natural_slope_needed(s), '-s', 'LineWidth', 1.4, 'Color', [0.2 0.2 0.2]);
for Km = [6 8]
    yline(Km, ':', sprintf('K_{max} = %g', Km));
end
xlabel('Vận tốc [km/h]'); ylabel('Độ dốc tự nhiên lớn nhất'); title('Độ dốc cần để đi qua mọi điểm hiệu chỉnh trong 0.1 g đến 0.3 g');
exportgraphics(f, fullfile(outDir, 'Map_error_by_speed_and_K.png'), 'Resolution', 130); close(f);
fprintf('scan_k_by_speed: wrote %s\n', outDir);
end
