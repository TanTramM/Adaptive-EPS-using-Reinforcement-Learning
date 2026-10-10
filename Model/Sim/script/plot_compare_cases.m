function plot_compare_cases(ctrlList, runSeed)
%PLOT_COMPARE_CASES One figure per test case: T_s (with T_d,ref), e_T and T_a of several controllers on the same axes.
%
%   plot_compare_cases({'Map', 'PI', 'SMC'}, 99999)   % runSeed [] (default) = ideal sensors, a number = that noise seed
%
%   Reads the signal files written by run_test_cases(ctrl, runSeed) (Result/Controllers/<ctrl>/TestCases for ideal sensors, else
%   Result/Controllers/<ctrl>/TestCases_noise/seed_<5 digits>/; the signals are the TRUE ones, scored by the scoring Reference) and writes
%     Result/Compare/<A>_vs_<B>_vs_.../<A>_vs_<B>_vs_..._<case>_Ts_eT_Ta.png
%   Each figure has 3 stacked charts, one line per controller (fixed colors, in the order of ctrlList):
%     1. T_s of every controller plus the reference T_d,ref (black dashed)   2. e_T = T_s - T_d,ref   3. T_a
%   The controllers must have been run on the same test_cases.m definition.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); setup_paths;                              % result_dir
addpath(scriptDir);                             % test_cases
if nargin < 2, runSeed = []; end
noiseNote = '';
if ~isempty(runSeed), noiseNote = sprintf(' (cảm biến có nhiễu, seed %05d)', runSeed); end

% one fixed color per controller (color follows the entity, not its position in the list)
col = zeros(numel(ctrlList), 3);
for c = 1:numel(ctrlList), col(c, :) = colorOf(ctrlList{c}); end
refColor = [0.043 0.043 0.043];  % text-primary ink for the reference
gridColor = [0.85 0.85 0.85];

tag = strjoin(ctrlList, '_vs_');
outDir = result_dir('Compare', tag);
TC = test_cases();
for k = 1:numel(TC)
    S = TC(k);
    D = cell(1, numel(ctrlList));
    for c = 1:numel(ctrlList)
        D{c} = readtable(fullfile(srcDir(ctrlList{c}, runSeed), ...
            sprintf('%s_%s_signals.csv', ctrlList{c}, S.tag)));
    end
    f = figure('Visible', 'off', 'Position', [50 50 1200 900]);
    tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s - %s%s', strjoin(ctrlList, ' / '), S.name, noiseNote), 'FontWeight', 'bold', 'Interpreter', 'none');

    ax(1) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.T_s, 'Color', col(c, :), 'LineWidth', 1.2);
    end
    plot(D{1}.t, D{1}.T_d_ref, '--', 'Color', refColor, 'LineWidth', 1.2);
    ylabel('N.m'); title('T_s và T_{d,ref}');
    legend([ctrlList, {'T_d,ref'}], 'Location', 'northeast', 'Interpreter', 'none');

    ax(2) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.e_T, 'Color', col(c, :), 'LineWidth', 1.2);
    end
    ylabel('N.m'); title('e_T = T_s - T_{d,ref}');
    legend(ctrlList, 'Location', 'northeast', 'Interpreter', 'none');

    ax(3) = nexttile; hold on;
    for c = 1:numel(ctrlList)
        plot(D{c}.t, D{c}.T_a, 'Color', col(c, :), 'LineWidth', 1.2);
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

function d = srcDir(ctrl, runSeed)
    if isempty(runSeed)
        d = result_dir(ctrl, 'TestCases');
    else
        d = result_dir(ctrl, 'TestCases_noise', sprintf('seed_%05d', runSeed));
    end
end

function rgb = colorOf(ctrl)
    switch ctrl
        case 'Map',    rgb = [0.165 0.471 0.839];   % #2a78d6 blue
        case 'PI',     rgb = [0.800 0.600 0.000];   % #cc9900 gold
        case 'PI_2K',  rgb = [0.106 0.686 0.478];   % #1baf7a aqua
        case 'PID',    rgb = [0.922 0.408 0.204];   % #eb6834 orange
        case 'SMC',    rgb = [0.106 0.686 0.478];   % #1baf7a aqua
        case 'ISMC', rgb = [0.910 0.482 0.643];   % magenta
        case 'SMC_KI', rgb = [0.910 0.482 0.643];   % #e87ba4 magenta
        case 'PIDF_DZ',   rgb = [0.290 0.227 0.655];   % #4a3aa7 violet
        case 'SMC_KI_DZ', rgb = [0.000 0.514 0.000];   % #008300 green
        case 'PIDF',   rgb = [0.290 0.227 0.655];   % #4a3aa7 violet
        otherwise,     rgb = [0.36 0.36 0.36];
    end
end
