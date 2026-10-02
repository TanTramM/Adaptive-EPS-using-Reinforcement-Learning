function plot_compare_cases(ctrlList)
%PLOT_COMPARE_CASES One figure per test case: T_s (with T_d,ref), e_T and T_a of several controllers on the same axes.
%
%   plot_compare_cases({'Map', 'PID', 'SMC'})
%
%   Reads Result/<ctrl>/TestCases/<ctrl>_<case>_signals.csv written by run_test_cases.m (noise-free level) and writes
%     Result/Compare/<A>_vs_<B>_vs_.../<A>_vs_<B>_vs_..._<case>_Ts_eT_Ta.png
%   Each figure has 3 stacked charts, one line per controller (fixed colors, in the order of ctrlList):
%     1. T_s of every controller plus the reference T_d,ref (black dashed)   2. e_T = T_s - T_d,ref   3. T_a
%   The controllers must have been run on the same test_cases.m definition.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir
addpath(scriptDir);                             % test_cases

palette = [0.165 0.471 0.839;    % #2a78d6 blue   (series 1)
           0.922 0.408 0.204;    % #eb6834 orange (series 2)
           0.106 0.686 0.478;    % #1baf7a aqua   (series 3)
           0.910 0.482 0.643];   % #e87ba4 magenta (series 5)
assert(numel(ctrlList) <= size(palette, 1), 'at most %d controllers', size(palette, 1));
refColor = [0.043 0.043 0.043];  % text-primary ink for the reference
gridColor = [0.85 0.85 0.85];

tag = strjoin(ctrlList, '_vs_');
outDir = result_dir('Compare', tag);
TC = test_cases();
for k = 1:numel(TC)
    S = TC(k);
    D = cell(1, numel(ctrlList));
    for c = 1:numel(ctrlList)
        D{c} = readtable(fullfile(result_dir(ctrlList{c}, 'TestCases'), ...
            sprintf('%s_%s_signals.csv', ctrlList{c}, S.tag)));
    end
    f = figure('Visible', 'off', 'Position', [50 50 1200 900]);
    tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s - %s', strjoin(ctrlList, ' / '), S.name), 'FontWeight', 'bold');

    ax(1) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.T_s, 'Color', palette(c, :), 'LineWidth', 1.2);
    end
    plot(D{1}.t, D{1}.T_d_ref, '--', 'Color', refColor, 'LineWidth', 1.2);
    ylabel('N.m'); title('T_s và T_{d,ref}');
    legend([ctrlList, {'T_d,ref'}], 'Location', 'northeast', 'Interpreter', 'none');

    ax(2) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.e_T, 'Color', palette(c, :), 'LineWidth', 1.2);
    end
    ylabel('N.m'); title('e_T = T_s - T_{d,ref}');
    legend(ctrlList, 'Location', 'northeast', 'Interpreter', 'none');

    ax(3) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.T_a, 'Color', palette(c, :), 'LineWidth', 1.2);
    end
    ylabel('N.m'); xlabel('t [s]'); title('Mô-men trợ lực T_a');
    legend(ctrlList, 'Location', 'northeast', 'Interpreter', 'none');

    for a = ax
        grid(a, 'on'); a.GridColor = gridColor; a.GridAlpha = 1; a.Box = 'off';
    end
    linkaxes(ax, 'x'); xlim(ax(1), [0 D{1}.t(end)]);
    exportgraphics(f, fullfile(outDir, sprintf('%s_%s_Ts_eT_Ta.png', tag, S.tag)), 'Resolution', 130);
    close(f);
    fprintf('plot_compare_cases: %s done\n', S.tag);
end
fprintf('plot_compare_cases: written to %s\n', outDir);
end
