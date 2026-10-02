function G = compare_pidf(seeds)
%COMPARE_PIDF Run the PIDF (PID with a stronger derivative filter) on TC1-TC6 with the sensor level 'high' and compare with Map and PID.
%
%   G = compare_pidf(90001:90005)
%
%   Run load_pidf first (base workspace). Map and PID are NOT run again: their rows are read from
%   Result/Compare/Map_vs_PID/Map_vs_PID_noise_study_summary.csv (written by make_pair_comparisons.m, same seeds, same test cases).
%   Writes to Result/Compare/Map_vs_PID_vs_PIDF/ (the files of Map vs PID and of PID are left untouched):
%     Map_vs_PID_vs_PIDF_noise_study_summary.csv   mean and std over the seeds, three controllers
%     Map_vs_PID_vs_PIDF_whole_case.png            RMS e_T and TV(T_a) per case
%     Map_vs_PID_vs_PIDF_<case>_Ts_eT_Ta.png       per case, first seed
%   The PIDF runs are saved by run_test_cases in Result/PIDF/TestCases_noise/high_seed<seed>/.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(scriptDir);
if nargin < 1, seeds = 90001:90005; end
metrics = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
runs = table();
for s = seeds
    t0 = tic;
    evalc('M = run_test_cases(''PIDF'', ''high'', s);');
    M.Ctrl = repmat({'PIDF'}, height(M), 1);
    M.Level = repmat({'high'}, height(M), 1);
    M.Seed = repmat(s, height(M), 1);
    runs = [runs; M]; %#ok<AGROW>
    fprintf('compare_pidf: PIDF seed %d done (%.0f s)\n', s, toc(t0));
end
mean0 = @(x) mean(x, 'omitnan');
std0  = @(x) std(x, 0, 'omitnan');
Gp = groupsummary(runs, {'Ctrl', 'Level', 'Case', 'Window'}, {mean0, std0}, metrics);
Gp.Properties.VariableNames = regexprep(Gp.Properties.VariableNames, '^fun1_', 'mean_');
Gp.Properties.VariableNames = regexprep(Gp.Properties.VariableNames, '^fun2_', 'std_');
old = readtable(fullfile(result_dir('Compare', 'Map_vs_PID'), 'Map_vs_PID_noise_study_summary.csv'), 'TextType', 'char');
G = [old; Gp(:, old.Properties.VariableNames)];
ctrls = {'Map', 'PID', 'PIDF'};
tag = strjoin(ctrls, '_vs_');
outDir = result_dir('Compare', tag);
writetable(G, fullfile(outDir, [tag '_noise_study_summary.csv']));

W = G(strcmp(G.Window, 'whole case'), :);
cases = unique(W.Case, 'stable');
tags = cellfun(@(c) c(1:3), cases, 'UniformOutput', false);
cols = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.290 0.227 0.655];
f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
items = {'RMS_eT_Nm', 'RMS e_T [N.m]'; 'TV_Ta_Nm_per_s', 'TV(T_a) [N.m/s]'};
for k = 1:2
    subplot(2, 1, k); hold on;
    mu = zeros(numel(cases), 3); sg = mu;
    for c = 1:3
        for i = 1:numel(cases)
            r = strcmp(W.Ctrl, ctrls{c}) & strcmp(W.Case, cases{i});
            mu(i, c) = W.(['mean_' items{k, 1}])(r);
            sg(i, c) = W.(['std_' items{k, 1}])(r);
        end
    end
    bh = bar(mu);
    for c = 1:3
        bh(c).FaceColor = cols(c, :);
        errorbar(bh(c).XEndPoints, mu(:, c), sg(:, c), 'k.', 'LineWidth', 1);
    end
    set(gca, 'XTick', 1:numel(cases), 'XTickLabel', tags, 'YScale', 'log'); grid on; ylabel(items{k, 2});
    legend(ctrls, 'Location', 'northwest');
    title(sprintf('%s (trục log, trung bình +- độ lệch chuẩn qua %d hạt giống)', items{k, 2}, numel(seeds)));
end
sgtitle('Map, PID (pidtune) và PIDF (lọc vi phân mạnh hơn), toàn ca, cảm biến có nhiễu mức high');
exportgraphics(f, fullfile(outDir, [tag '_whole_case.png']), 'Resolution', 130);
close(f);
plot_compare_cases(ctrls, 'high', seeds(1));
evalin('base', 'clear sc_theta1 sc_v sc_mu');
end
