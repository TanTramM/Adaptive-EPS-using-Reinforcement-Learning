function S = smc_stability_map(outDir)
%SMC_STABILITY_MAP Phase margin, steady error and noise of the SMC (no integral) over a fine (lambda, G) grid; linear analysis only.
%
%   S = smc_stability_map()          writes Result/SMC/Tuning/SMC_stability_map.csv and SMC_stability_map.png
%
%   Grid: 26 values of lambda (20-1000 1/s) times 30 values of G = k_sw/Phi (20-1800 1/s). For every point analyze_smc.m gives the phase
%   margin (negative = unstable or only conditionally stable, GM < 1), the steady error of the everyday region (v >= 30 km/h, a_y <= 0.3 g)
%   and the noise of T_a for tau_f = 10 ms. The two hard conditions of the map are PM >= 45 deg and a steady error <= 3 %: S counts the grid
%   points that meet each and both. Returns S.n_pm, S.n_err, S.n_both, S.n_total, S.max_lambda_G_pm45, S.min_lambda_G_err3.

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
addpath(modelDir);
if nargin < 1, outDir = result_dir('SMC', 'Tuning'); end
lamF = round(logspace(log10(20), log10(1000), 26));
GF   = round(logspace(log10(20), log10(1800), 30));
PMm = nan(numel(GF), numel(lamF)); Em = PMm; Nm = PMm;
for i = 1:numel(GF)
    for j = 1:numel(lamF)
        a = analyze_smc(lamF(j), GF(i), 0.01);
        PMm(i, j) = a.PM_deg;  Em(i, j) = a.e_ss_pct;  Nm(i, j) = a.noise_std_Ta;
    end
end
[LL, GG] = meshgrid(lamF, GF);    % same layout as PMm: rows = G, columns = lambda
writetable(array2table([GG(:), LL(:), PMm(:), Em(:), Nm(:)], 'VariableNames', {'G', 'lambda', 'PM_deg', 'e_ss_pct', 'noise_std_Ta_tau10ms'}), ...
    fullfile(outDir, 'SMC_stability_map.csv'));
okPM = PMm >= 45;  okE = Em <= 3;
S.n_pm = nnz(okPM);  S.n_err = nnz(okE);  S.n_both = nnz(okPM & okE);  S.n_total = numel(PMm);
S.max_lambda_G_pm45 = max(LL(okPM) .* GG(okPM));
S.min_lambda_G_err3 = min(LL(okE) .* GG(okE));
fprintf('smc_stability_map: PM >= 45 deg: %d, error <= 3 %%: %d, both: %d of %d; largest lambda*G with PM >= 45: %.3g, smallest with error <= 3 %%: %.3g\n', ...
    S.n_pm, S.n_err, S.n_both, S.n_total, S.max_lambda_G_pm45, S.min_lambda_G_err3);

f = figure('Visible', 'off', 'Position', [100 100 900 620]); hold on; box on;
contourf(LL, GG, max(PMm, -10), [-10 0 20 45 70 90], 'LineColor', [0.5 0.5 0.5]); colormap(parula(5)); cb = colorbar; cb.Label.String = 'Độ dự trữ pha [độ]';
contour(LL, GG, PMm, [45 45], 'LineWidth', 2.4, 'Color', 'k');
contour(LL, GG, Em, [3 3], 'LineWidth', 2.4, 'Color', 'r', 'LineStyle', '--');
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('\lambda [1/s]'); ylabel('G = k_{sw}/\Phi [1/s]');
plot(300, 1000, 'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 12);
text(310, 1100, 'bản thiết kế ban đầu', 'FontWeight', 'bold');
title('SMC không tích phân: vùng PM \geq 45^o (đường đen) và vùng sai số \leq 3 % (bên trên đường đỏ nét đứt)');
exportgraphics(f, fullfile(outDir, 'SMC_stability_map.png'), 'Resolution', 130); close(f);
end
