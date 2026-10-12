function T = scan_pid_stability()
%SCAN_PID_STABILITY Linear stability boundary of the PID under the stress of QuyChuan 5.2 on the (Kp, Ki) plane, for several (Kd, Tf).
%
%   T = scan_pid_stability()
%
%   Same linear test as the filter of run_pid_sweep.m (pid_stress_stable): discrete PID
%   C(z) = Kp + Ki Ts/(z-1) + b (z-1)/(z-a), a = Tf/(Tf+Ts), b = Kd/(Tf+Ts), on both linear plants of pi_plant_lin
%   (dry k_r and saturated tire k_r = 0), 1 ms zero-order hold, one extra sample of delay and loop gain x2.
%   The PI boundary (Kd = 0) is the PI_stability_boundary.csv of identify_plant.m; this scan shows how far the derivative
%   term moves it, so that the Ki range of the PID sweep comes from the PID itself and not from the PI (QuyChuan 6.1).
%
%   For every (Kd, Tf, Kp): max_Ki_contig = largest Ki such that every grid Ki from the smallest up to it is stable
%   (the usable range), max_Ki_any = largest stable Ki anywhere on the grid (0 when none).
%
%   Output: Result/Controllers/PID/Design/PID_stability_boundary.csv and .png

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

Ts = 0.001;
kpGrid = [0.25:0.25:3, 3.5:0.5:6, 7:1:12];
kiGrid = [0.5:0.5:10, 12:2:40, 45:5:100, 120:20:300];
kdGrid = [0 0.01 0.02 0.03 0.04];
tfGrid = [0.0025 0.0035 0.005 0.01];

[G1c, G0c] = pi_plant_lin();
z = tf('z', Ts);
Gd = {c2d(G1c, Ts, 'zoh'), c2d(G0c, Ts, 'zoh')};

rows = zeros(0, 5);
for kd = kdGrid
    tfList = tfGrid; if kd == 0, tfList = tfGrid(1); end      % Tf has no effect without the derivative term
    for tf_ = tfList
        a = tf_ / (tf_ + Ts); b = kd / (tf_ + Ts);
        D = b * (z - 1) / (z - a);
        for kp = kpGrid
            st = false(size(kiGrid));
            for j = 1:numel(kiGrid)
                C = kp + kiGrid(j) * Ts / (z - 1) + D;
                st(j) = isstable(feedback(2 * (1 / z) * C * Gd{1}, 1)) && isstable(feedback(2 * (1 / z) * C * Gd{2}, 1));
            end
            iFirstBad = find(~st, 1);
            if isempty(iFirstBad), kiContig = kiGrid(end); elseif iFirstBad == 1, kiContig = 0; else, kiContig = kiGrid(iFirstBad - 1); end
            kiAny = 0; if any(st), kiAny = max(kiGrid(st)); end
            rows(end+1, :) = [kd tf_ kp kiContig kiAny]; %#ok<AGROW>
        end
        r = rows(rows(:, 1) == kd & rows(:, 2) == tf_, :);
        fprintf('scan_pid_stability: Kd %.3f Tf %.4f | Kp_max %.3f | Ki_max(Kp 1.5) %.1f | Ki_max(Kp 3) %.1f | Ki_max overall %.1f\n', kd, tf_, ...
            max([0; r(r(:, 4) > 0, 3)]), r(abs(r(:, 3) - 1.5) < 1e-9, 4), r(abs(r(:, 3) - 3) < 1e-9, 4), max(r(:, 4)));
    end
end
T = array2table(rows, 'VariableNames', {'Kd_s', 'Tf_s', 'Kp', 'max_Ki_contig', 'max_Ki_any'});
outDir = result_dir('PID', 'Design');
writetable(T, fullfile(outDir, 'PID_stability_boundary.csv'));

f = figure('Visible', 'off', 'Position', [100 100 900 560]); hold on; grid on;
cols = lines(numel(kdGrid));
for ik = 1:numel(kdGrid)
    tfList = tfGrid; if kdGrid(ik) == 0, tfList = tfGrid(1); end
    sty = {'-', '--', ':', '-.'};
    for it = 1:numel(tfList)
        r = rows(rows(:, 1) == kdGrid(ik) & rows(:, 2) == tfList(it), :);
        if kdGrid(ik) == 0, lab = 'Kd = 0 (PI)'; else, lab = sprintf('Kd %.2f, Tf %.1f ms', kdGrid(ik), 1000 * tfList(it)); end
        plot(r(:, 3), r(:, 4), sty{it}, 'Color', cols(ik, :), 'LineWidth', 1.4, 'DisplayName', lab);
    end
end
xlabel('Kp [N.m/(N.m)]'); ylabel('largest stable Ki [1/s] (contiguous from 0.5)');
title('PID linear stability boundary under stress (gain x2, +1 ms delay, dry and saturated tire)');
legend('Location', 'eastoutside', 'FontSize', 7);
exportgraphics(f, fullfile(outDir, 'PID_stability_boundary.png'), 'Resolution', 130); close(f);
fprintf('scan_pid_stability: written %s\n', fullfile(outDir, 'PID_stability_boundary.csv'));
end
