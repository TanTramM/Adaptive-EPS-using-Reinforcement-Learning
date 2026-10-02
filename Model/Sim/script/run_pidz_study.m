function G = run_pidz_study(seeds)
%RUN_PIDZ_STUDY PIDF with dead zones (Model_PIDZ_s): error dead zone dz_e and torque dead zone dz_Ts, several variants, sensor level 'high'.
%
%   G = run_pidz_study(90001:90002)
%
%   Run load_pidf first. Every variant sets dz_e and dz_Ts in the base workspace and runs TC1-TC6 for the seeds with run_test_cases('PIDZ',
%   'high', seed); the folder Result/PIDZ/TestCases_noise is then renamed Result/PIDZ/<variant>/ so every variant keeps its own results.
%   Writes Result/Compare/PIDF_dead_zone/PIDF_dead_zone_summary.csv (mean and std over the seeds, whole case and windows) and
%   PIDF_dead_zone_whole_case.png. The PIDF reference (5 seeds) is in Result/Compare/Map_vs_PID_vs_PIDF/.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(scriptDir);
if nargin < 1, seeds = 90001:90002; end
variants = {'V0_none', 0, 0; 'A_Ts0p3', 0, 0.3; 'B_e0p05', 0.05, 0; 'B_e0p10', 0.10, 0; 'B_e0p20', 0.20, 0; 'AB_Ts0p3_e0p10', 0.10, 0.3};
metrics = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
runs = table();
pzDir = result_dir('PIDZ');
for v = 1:size(variants, 1)
    assignin('base', 'dz_e', variants{v, 2});
    assignin('base', 'dz_Ts', variants{v, 3});
    for s = seeds
        t0 = tic;
        evalc('M = run_test_cases(''PIDZ'', ''high'', s);');
        M.Ctrl = repmat(variants(v, 1), height(M), 1);
        M.Level = repmat({'high'}, height(M), 1);
        M.Seed = repmat(s, height(M), 1);
        runs = [runs; M]; %#ok<AGROW>
        fprintf('run_pidz_study: %s seed %d done (%.0f s)\n', variants{v, 1}, s, toc(t0));
    end
    src = fullfile(pzDir, 'TestCases_noise');
    dst = fullfile(pzDir, variants{v, 1});
    if exist(dst, 'dir'), rmdir(dst, 's'); end
    movefile(src, dst);
end
mean0 = @(x) mean(x, 'omitnan');
std0  = @(x) std(x, 0, 'omitnan');
G = groupsummary(runs, {'Ctrl', 'Level', 'Case', 'Window'}, {mean0, std0}, metrics);
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun1_', 'mean_');
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun2_', 'std_');
outDir = result_dir('Compare', 'PIDF_dead_zone');
writetable(G, fullfile(outDir, 'PIDF_dead_zone_summary.csv'));

W = G(strcmp(G.Window, 'whole case'), :);
cases = unique(W.Case, 'stable');
tags = cellfun(@(c) c(1:3), cases, 'UniformOutput', false);
names = variants(:, 1);
f = figure('Visible', 'off', 'Position', [50 50 1200 800]);
items = {'RMS_eT_Nm', 'RMS e_T [N.m]'; 'TV_Ta_Nm_per_s', 'TV(T_a) [N.m/s]'};
for k = 1:2
    subplot(2, 1, k); hold on;
    mu = zeros(numel(cases), numel(names));
    for c = 1:numel(names)
        for i = 1:numel(cases)
            mu(i, c) = W.(['mean_' items{k, 1}])(strcmp(W.Ctrl, names{c}) & strcmp(W.Case, cases{i}));
        end
    end
    bar(mu);
    set(gca, 'XTick', 1:numel(cases), 'XTickLabel', tags, 'YScale', 'log'); grid on; ylabel(items{k, 2});
    legend(names, 'Location', 'northeastoutside', 'Interpreter', 'none');
    title(sprintf('%s (trục log, trung bình %d hạt giống)', items{k, 2}, numel(seeds)));
end
sgtitle('PIDF với vùng chết, toàn ca, cảm biến có nhiễu mức high', 'Interpreter', 'none');
exportgraphics(f, fullfile(outDir, 'PIDF_dead_zone_whole_case.png'), 'Resolution', 130);
close(f);
evalin('base', 'clear sc_theta1 sc_v sc_mu dz_e dz_Ts');
end
