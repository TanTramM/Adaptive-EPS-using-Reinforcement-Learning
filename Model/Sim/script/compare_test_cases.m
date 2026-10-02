function T = compare_test_cases(ctrlA, ctrlB)
%COMPARE_TEST_CASES Side-by-side metrics of two controllers on the standard test cases (TC1-TC6).
%
%   T = compare_test_cases('Map', 'PID')
%
%   Reads Result/<ctrl>/TestCases/<ctrl>_test_case_metrics.csv written by run_test_cases.m for both controllers,
%   joins them on (Case, Window) and writes
%     Result/Compare/<A>_vs_<B>/<A>_vs_<B>_test_case_metrics.csv   every row, both controllers side by side
%     Result/Compare/<A>_vs_<B>/<A>_vs_<B>_whole_case.png          RMS e_T, max |e_T| and TV(T_a) per case (bars)
%     Result/Compare/<A>_vs_<B>/<A>_vs_<B>_over_assist_windows.png  signed mean e_T / mean |T_d,ref| in the windows
%                                                                    where the road gets slippery (negative = over-assist)
%   Both controllers must have been run on the same test_cases.m definition.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir
read = @(c) readtable(fullfile(result_dir(c, 'TestCases'), [c '_test_case_metrics.csv']), 'VariableNamingRule', 'preserve');
A = read(ctrlA);  B = read(ctrlB);
vars = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
A = renamevars(A, vars, strcat(vars, '_', ctrlA));
B = renamevars(B, vars, strcat(vars, '_', ctrlB));
T = outerjoin(A, B, 'Keys', {'Case', 'Window'}, 'MergeKeys', true);
outDir = result_dir('Compare', [ctrlA '_vs_' ctrlB]);
writetable(T, fullfile(outDir, [ctrlA '_vs_' ctrlB '_test_case_metrics.csv']));

% ---- whole-case bars ----
W = T(strcmp(T.Window, 'whole case'), :);
tags = cellfun(@(s) s(1:3), W.Case, 'UniformOutput', false);
f = figure('Visible', 'off', 'Position', [50 50 1300 420]);
items = {'RMS_eT_Nm', 'RMS e_T [N.m]'; 'MaxAbs_eT_Nm', 'max |e_T| [N.m]'; 'TV_Ta_Nm_per_s', 'TV(T_a) [N.m/s]'};
for k = 1:3
    subplot(1, 3, k);
    bar([W.([items{k, 1} '_' ctrlA]), W.([items{k, 1} '_' ctrlB])]);
    set(gca, 'XTickLabel', tags); grid on; ylabel(items{k, 2}); legend({ctrlA, ctrlB}, 'Location', 'northwest');
    title(items{k, 2});
end
sgtitle(sprintf('%s vs %s, whole case (first 2 s excluded)', ctrlA, ctrlB));
exportgraphics(f, fullfile(outDir, [ctrlA '_vs_' ctrlB '_whole_case.png']), 'Resolution', 130);
close(f);

% ---- over-assist windows (road slippery, steady) ----
wins = {'TC2_road', 'curve_0p25g_v80_mu_0p3'; 'TC2_road', 'curve_0p15g_v80_mu_0p3'; 'TC2_road', 'curve_0p2g_v100_mu_0p5'; ...
        'TC3_mu_drop_hard_corner', 'after_mu_drop_steady'; 'TC4_wet_patch_lane_change', 'during_puddle'};
vals = zeros(size(wins, 1), 2); lbl = cell(size(wins, 1), 1);
for i = 1:size(wins, 1)
    r = strcmp(T.Case, wins{i, 1}) & strcmp(T.Window, wins{i, 2});
    vals(i, :) = [T.(['Mean_eT_signed_pct_of_Tdref_' ctrlA])(r), T.(['Mean_eT_signed_pct_of_Tdref_' ctrlB])(r)];
    lbl{i} = [wins{i, 1}(1:3) ' ' strrep(wins{i, 2}, '_', ' ')];
end
f = figure('Visible', 'off', 'Position', [50 50 1000 460]);
bar(vals); grid on; set(gca, 'XTickLabel', lbl, 'TickLabelInterpreter', 'none'); xtickangle(20);
ylabel('mean e_T / mean |T_{d,ref}| [%]  (negative = over-assist)'); legend({ctrlA, ctrlB}, 'Location', 'southeast');
title(sprintf('Over-assist on slippery road: %s vs %s', ctrlA, ctrlB));
exportgraphics(f, fullfile(outDir, [ctrlA '_vs_' ctrlB '_over_assist_windows.png']), 'Resolution', 130);
close(f);
fprintf('compare_test_cases: written to %s\n', outDir);
end
