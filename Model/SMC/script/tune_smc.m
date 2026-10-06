function T = tune_smc(seeds)
%TUNE_SMC Choose lambda, G = k_sw/Phi and tau_f of the first-order SMC (no integral) in the PRSM loop; writes data/smc.json.
%
%   T = tune_smc()                 seeds 91001:91002
%
%   Same criterion as the map (Documents/Map_6_8/map.txt section 2.5), designed from the PRSM only:
%     1. Hard gate (linear analysis, analyze_smc.m): phase margin >= 45 deg of the loop command -> motor -> column -> T_s, theta2_dot for the
%        dry road and the very slippery road ([1] Sec. III.D). The steady accuracy |e_T| <= 3 % of T_d,ref in the everyday region (v >= 30 km/h,
%        0.1 g <= a_y <= 0.3 g) is the second hard gate of the map; it is checked and reported (field feasible_3pct) and the result decides
%        whether the traditional SMC can follow the same criterion (it cannot: see the stability map written to Result/SMC/Tuning).
%     2. Score of every candidate that passes the phase-margin gate: closed loop Model_SMC_s on the case TK (tk_run.m), sensors level
%        'high', noise seeds 91001...: R (response, includes the steady error) and S (smoothness: T_a above 5 Hz).
%     3. The Pareto front of (S, R) and its knee: both axes normalised to [0, 1] over the candidates, the knee is the front point farthest below
%        the line joining its two ends.
%   Fixed: k_sw = 150 rad/s^2 (larger than the lumped disturbance bound; only the width of the layer Phi = k_sw/G is tuned), Ts_ctrl = 1 ms.
%   tau_f is the time constant of the filtered derivative that estimates theta1_dot (part of the SMC structure; no extra measurement filter).
%   Needs Model_SMC_s (load_smc.m, build_smc.m, build_closed_loop('SMC') first). Writes Result/SMC/Tuning/*.

scriptDir = fileparts(mfilename('fullpath'));   % SMC/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script'));
if nargin < 1, seeds = 91001:91002; end
outDir = result_dir('SMC', 'Tuning');
mdl = 'Model_SMC_s';
src = jsondecode(fileread(fullfile(modelDir, 'data', 'smc.json')));
ksw = src.k_sw.value;

%% 1. stability / accuracy map over a fine grid (linear analysis only)
smc_stability_map(outDir);

%% 2. candidates and closed-loop scores
lamL = [30 60 100 150 250];  GL = [30 60 100 150 250 400];  tfL = [0.01 0.03 0.1];
rows = [];
for lam = lamL
    for G = GL
        a = analyze_smc(lam, G, 0.01);
        if a.PM_deg < 45, continue; end
        for tf_ = tfL
            an = analyze_smc(lam, G, tf_);
            sc = zeros(numel(seeds), 6);
            for q = 1:numel(seeds)
                [~, m] = tk_run(mdl, 'high', seeds(q), struct('lambda', lam, 'Phi', ksw / G, 'tau_f', tf_));
                sc(q, :) = [m.R, m.S, m.TV, m.erel, m.maxTa, m.Scmd];
            end
            mu = mean(sc, 1);
            rows = [rows; lam, G, tf_, ksw / G, a.PM_deg, a.GM, an.e_ss_pct, an.noise_std_Ta, an.noise_std_cmd, mu, std(sc(:, 1)), std(sc(:, 2))]; %#ok<AGROW>
            fprintf('tune_smc: lambda %g G %g tau_f %g  PM %.1f  R %.3f  S %.3f  TV %.0f  erel %.1f%%  Scmd %.2f\n', lam, G, tf_, a.PM_deg, mu(1), mu(2), mu(3), mu(4), mu(6));
        end
    end
end
names = {'lambda', 'G', 'tau_f', 'Phi', 'PM_deg', 'GM', 'e_ss_pct_pred', 'noise_std_Ta_pred', 'noise_std_cmd_pred', 'R_RMS_eT_Nm', ...
    'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', 'e_rel_pct', 'MaxAbs_Ta_Nm', 'S_HF_RMS_cmd_Nm', 'std_R', 'std_S'};
T = array2table(rows, 'VariableNames', names);

%% 3. reference: the design of the earlier SMC (lambda 300, G 1000, tau_f 10 ms), reported only
a0 = analyze_smc(300, 1000, 0.01);
sc0 = zeros(numel(seeds), 6);
for q = 1:numel(seeds)
    [~, m] = tk_run(mdl, 'high', seeds(q), struct('lambda', 300, 'Phi', ksw / 1000, 'tau_f', 0.01));
    sc0(q, :) = [m.R, m.S, m.TV, m.erel, m.maxTa, m.Scmd];
end
mu0 = mean(sc0, 1);
ref = table(300, 1000, 0.01, ksw / 1000, a0.PM_deg, a0.GM, a0.e_ss_pct, mu0(1), mu0(2), mu0(3), mu0(4), mu0(5), mu0(6), 'VariableNames', ...
    {'lambda', 'G', 'tau_f', 'Phi', 'PM_deg', 'GM', 'e_ss_pct_pred', 'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', 'e_rel_pct', 'MaxAbs_Ta_Nm', 'S_HF_RMS_cmd_Nm'});
writetable(ref, fullfile(outDir, 'SMC_reference_old_design.csv'));

%% 4. Pareto front and knee
R = T.R_RMS_eT_Nm;  S = T.S_HF_RMS_Ta_Nm;
nd = true(height(T), 1);
for i = 1:height(T)
    nd(i) = ~any(R <= R(i) & S <= S(i) & (R < R(i) | S < S(i)));
end
T.pareto = nd;
F = T(nd, :);  [~, o] = sort(F.S_HF_RMS_Ta_Nm);  F = F(o, :);
rn = (F.R_RMS_eT_Nm - min(F.R_RMS_eT_Nm)) / max(eps, range(F.R_RMS_eT_Nm));
sn = (F.S_HF_RMS_Ta_Nm - min(F.S_HF_RMS_Ta_Nm)) / max(eps, range(F.S_HF_RMS_Ta_Nm));
% distance below the line joining the first (smoothest) and last (best response) front points, in the normalised plane
p1 = [sn(1) rn(1)];  p2 = [sn(end) rn(end)];  d = zeros(height(F), 1);
for i = 1:height(F)
    d(i) = ((p2(1) - p1(1)) * (p1(2) - rn(i)) - (p1(1) - sn(i)) * (p2(2) - p1(2))) / norm(p2 - p1);
end
[~, kb] = max(d);
F.knee_distance = d;
T.knee = false(height(T), 1);
T.knee(T.lambda == F.lambda(kb) & T.G == F.G(kb) & T.tau_f == F.tau_f(kb)) = true;
writetable(T, fullfile(outDir, 'SMC_candidates_TK.csv'));
writetable(F, fullfile(outDir, 'SMC_pareto_front.csv'));
plotPareto(T, ref, fullfile(outDir, 'SMC_pareto.png'));
best = F(kb, :);
fprintf('tune_smc: knee lambda %g, G %g (Phi %.4g), tau_f %g: PM %.1f, R %.3f, S %.3f, e_ss(pred) %.1f %%\n', best.lambda, best.G, best.Phi, best.tau_f, best.PM_deg, best.R_RMS_eT_Nm, best.S_HF_RMS_Ta_Nm, best.e_ss_pct_pred);

%% 5. write data/smc.json (read by load_smc.m)
out = src;
out.x_note = ['First-order SMC with sat boundary layer, no integral, designed in the PRSM loop (Documents/SMC/DieuKhien_SMC.txt). lambda, Phi and tau_f chosen by ' ...
    'Model/SMC/script/tune_smc.m: phase margin >= 45 deg hard gate, knee of the Pareto front (R, S) on the case TK. Use the values as chosen in load_smc.m.'];
out.Ts_ctrl.desc = 'Sample time of the digital controller (ECU), ZOH at the inputs; same for every controller';  out.Ts_ctrl.ref = 'common sample time 1 ms';
out.k_sw.desc = 'Switching gain, larger than the lumped disturbance bound; fixed (only Phi = k_sw/G is tuned); in simulation 100 is enough, 150 chosen';  out.k_sw.ref = 'simulation';
out.lambda.value = best.lambda;  out.lambda.desc = 'Convergence rate of e_T on the sliding surface (bandwidth of the loop)';  out.lambda.ref = 'tune_smc.m';
out.tau_f.value = best.tau_f;    out.tau_f.desc = 'Time constant of the filtered derivative that estimates theta1_dot';  out.tau_f.ref = 'tune_smc.m';
out.Phi.value = best.Phi;        out.Phi.desc = sprintf('Boundary layer width = k_sw/G with G = %g 1/s', best.G);  out.Phi.ref = 'tune_smc.m';
out.x_design = struct('G_1_per_s', best.G, 'PM_deg', best.PM_deg, 'GM', best.GM, 'e_ss_pct_pred', best.e_ss_pct_pred, 'R_TK', best.R_RMS_eT_Nm, 'S_TK', best.S_HF_RMS_Ta_Nm);
fid = fopen(fullfile(modelDir, 'data', 'smc.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(out, 'PrettyPrint', true));
fclose(fid);
end

%% ===================== figures =====================
function plotPareto(T, ref, file)
    f = figure('Visible', 'off', 'Position', [100 100 950 650]); hold on; grid on; box on;
    cols = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478];
    tfs = unique(T.tau_f);
    for k = 1:numel(tfs)
        s = T.tau_f == tfs(k);
        scatter(T.S_HF_RMS_Ta_Nm(s), T.R_RMS_eT_Nm(s), 55, cols(k, :), 'filled', 'DisplayName', sprintf('\\tau_f = %g ms', 1000 * tfs(k)));
    end
    F = T(T.pareto, :);  [~, o] = sort(F.S_HF_RMS_Ta_Nm);  F = F(o, :);
    plot(F.S_HF_RMS_Ta_Nm, F.R_RMS_eT_Nm, 'k-', 'LineWidth', 1.4, 'DisplayName', 'mặt Pareto');
    k = T.knee;
    plot(T.S_HF_RMS_Ta_Nm(k), T.R_RMS_eT_Nm(k), 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'y', 'DisplayName', 'khuỷu (chọn)');
    plot(ref.S_HF_RMS_Ta_Nm, ref.R_RMS_eT_Nm, 'rx', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'bản cũ (\lambda 300, G 1000, PM \approx 0)');
    for i = 1:height(T)
        text(T.S_HF_RMS_Ta_Nm(i) * 1.02, T.R_RMS_eT_Nm(i), sprintf('%g/%g', T.lambda(i), T.G(i)), 'FontSize', 7);
    end
    set(gca, 'XScale', 'log', 'YScale', 'log');
    xlabel('S: RMS của T_a trên 5 Hz [N.m] (êm hơn về bên trái)'); ylabel('R: RMS e_T trên ca TK [N.m] (bám tốt hơn về phía dưới)');
    title('Ca TK, nhiễu mức cao: các bộ (\lambda/G) đạt PM \geq 45^o'); legend('Location', 'northeast');
    exportgraphics(f, file, 'Resolution', 130); close(f);
end
