function Z = scan_pi_region()
%SCAN_PI_REGION Feasible region of the PI gains (Kp, Ki) of the PRSM assist loop, independent of the crossover parameterization of design_pi.m.
%
%   Z = scan_pi_region()
%
%   For a grid of (Kp, Ki) the loop C(z)*G(z) (design_pi.m: motor lag, ZOH at 1 ms, dry road and saturated tire) is checked against the same
%   conditions as the design: closed loop stable on both plants, phase margin >= 45 deg, gain margin >= 2. Purpose: show that the one-parameter
%   family of design_pi.m (crossover wc, smallest Ti) does not leave a much better PI outside it. For every Kp the largest feasible Ki is
%   reported (the integral gain sets the loop gain in the 0.2-2 Hz band where the steering command and the reference lie).
%   Writes Result/PI/Design/PI_feasible_region.csv (one row per grid point) and PI_feasible_region.png (region + the design_pi points).

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
Ts = 0.001; pmMin = 45; gmMin = 2;
outDir = result_dir('PI', 'Design');

p = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(p.(grp{1}));
    for i = 1:numel(fn), P.(fn{i}) = p.(grp{1}).(fn{i}).value; end
end
wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;
kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
Gm = tf(wm, [1 wm]);
G1 = c2d(tf(P.K, [P.J_col, P.C_col, P.K + kr]) * Gm, Ts, 'zoh');
G0 = c2d(tf(P.K, [P.J_col, P.C_col, P.K]) * Gm, Ts, 'zoh');

KpGrid = [0.01 0.02 0.04 0.06 0.08 0.1 0.12 0.15 0.18 0.2 0.25 0.3 0.35 0.4 0.5 0.6 0.8 1.0 1.5 2.0];
KiGrid = logspace(log10(0.5), log10(80), 70);
rows = [];
for Kp = KpGrid
    for Ki = KiGrid
        ok = true; pm = inf; gm = inf;
        for G = {G1, G0}
            C = tf([Kp, Ki * Ts - Kp], [1, -1], Ts);     % Kp + Ki*Ts/(z-1)
            L = C * G{1};
            if ~isstable(feedback(L, 1)), ok = false; pm = nan; gm = nan; break; end
            [g, q] = margin(L);
            pm = min(pm, q); gm = min(gm, g);
            ok = ok && q >= pmMin && g >= gmMin;
        end
        rows = [rows; Kp, Ki, ok, pm, gm]; %#ok<AGROW>
    end
end
Z = array2table(rows, 'VariableNames', {'Kp', 'Ki_1_per_s', 'feasible', 'min_PM_deg', 'min_GM'});
writetable(Z, fullfile(outDir, 'PI_feasible_region.csv'));

KiMax = nan(size(KpGrid));
for i = 1:numel(KpGrid)
    r = Z(Z.Kp == KpGrid(i) & Z.feasible == 1, :);
    if ~isempty(r), KiMax(i) = max(r.Ki_1_per_s); end
end
F = table(KpGrid(:), KiMax(:), 'VariableNames', {'Kp', 'Ki_max_feasible_1_per_s'});
writetable(F, fullfile(outDir, 'PI_feasible_Ki_max.csv'));
D = readtable(fullfile(outDir, 'PI_design_grid.csv'));
D = D(D.feasible == 1, :);

f = figure('Visible', 'off', 'Position', [50 50 1000 700]); hold on;
ok = Z.feasible == 1;
plot(Z.Kp(~ok), Z.Ki_1_per_s(~ok), '.', 'Color', [0.8 0.8 0.8], 'MarkerSize', 6, 'DisplayName', 'not feasible');
plot(Z.Kp(ok), Z.Ki_1_per_s(ok), '.', 'Color', [0.165 0.471 0.839], 'MarkerSize', 10, 'DisplayName', 'feasible: stable, PM >= 45 deg, GM >= 2, both plants');
plot(D.Kp, D.Ki_1_per_s, 'ro-', 'MarkerFaceColor', 'r', 'DisplayName', 'design\_pi.m (one point per crossover frequency)');
for i = 1:height(D), text(D.Kp(i) * 1.04, D.Ki_1_per_s(i) * 1.06, sprintf('%g', D.wc_design_rad_s(i)), 'Color', 'r'); end
set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; legend('Location', 'southwest');
xlabel('K_p'); ylabel('K_i [1/s]'); title('Feasible PI gains of the PRSM assist loop (labels: design crossover \omega_c [rad/s])');
exportgraphics(f, fullfile(outDir, 'PI_feasible_region.png'), 'Resolution', 130); close(f);
fprintf('scan_pi_region: %d of %d grid points feasible; largest feasible Ki %.3g 1/s at Kp %.3g\n', nnz(ok), height(Z), max(KiMax), KpGrid(find(KiMax == max(KiMax), 1)));
end
