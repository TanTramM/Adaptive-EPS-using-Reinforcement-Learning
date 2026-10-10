function G = make_pair_comparisons(ctrlList, seeds)
%MAKE_PAIR_COMPARISONS Run the standard test cases with the full sensor chain and compare the controllers two at a time.
%
%   G = make_pair_comparisons({'Map', 'SMC'}, 99999)
%
%   Noisy sensors of the Sensors subsystem (data/sensors.json): white noise (std = one resolution step) + quantizer + update period of
%   every signal. Run load_<ctrl> of every controller in the list in the base workspace first.
%   Every controller is run ONCE per seed (run_test_cases(ctrl, seed), metrics on the TRUE signals, first 2 s not scored),
%   the seeds are averaged, then for every pair (A, B) of ctrlList, in list order, it writes to Result/Compare/<A>_vs_<B>/:
%     <A>_vs_<B>_noise_study_all_runs.csv    one row per controller, seed, case, window
%     <A>_vs_<B>_noise_study_summary.csv     mean and std over the seeds (same columns as run_noise_study.m)
%     <A>_vs_<B>_whole_case.png              RMS e_T and TV(T_a) per case, mean +- std over the seeds
%     <A>_vs_<B>_<case>_Ts_eT_Ta.png         per case: T_s with T_d,ref, e_T, T_a of the two controllers (first seed)
%   Documents/Sim/SoSanh.txt is written from these files.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); setup_paths;                              % result_dir
addpath(scriptDir);                             % run_test_cases, plot_compare_cases
if nargin < 2, seeds = 99999; end

metrics = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
runs = table();
for ci = 1:numel(ctrlList)
    for s = seeds
        t0 = tic;
        evalc('M = run_test_cases(ctrlList{ci}, s);');
        M.Ctrl = repmat(ctrlList(ci), height(M), 1);
        M.Seed = repmat(s, height(M), 1);
        runs = [runs; M]; %#ok<AGROW>
        fprintf('make_pair_comparisons: %s seed %d done (%.0f s)\n', ctrlList{ci}, s, toc(t0));
    end
end
mean0 = @(x) mean(x, 'omitnan');
std0  = @(x) std(x, 0, 'omitnan');
G = groupsummary(runs, {'Ctrl', 'Case', 'Window'}, {mean0, std0}, metrics);
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun1_', 'mean_');
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun2_', 'std_');

for a = 1:numel(ctrlList) - 1
    for b = a + 1:numel(ctrlList)
        pair = ctrlList([a b]);
        tag = strjoin(pair, '_vs_');
        outDir = result_dir('Compare', tag);
        writetable(runs(ismember(runs.Ctrl, pair), :), fullfile(outDir, [tag '_noise_study_all_runs.csv']));
        writetable(G(ismember(G.Ctrl, pair), :), fullfile(outDir, [tag '_noise_study_summary.csv']));
        wholeCaseBars(G, pair, seeds, fullfile(outDir, [tag '_whole_case.png']));
        plot_compare_cases(pair, seeds(1));
    end
end
evalin('base', 'clear sc_theta1 sc_v sc_mu');
end

function wholeCaseBars(G, pair, seeds, file)
    W = G(strcmp(G.Window, 'whole case') & ismember(G.Ctrl, pair), :);
    cases = unique(W.Case, 'stable');
    tags = cellfun(@(s) s(1:3), cases, 'UniformOutput', false);



    colors = [colorOf(pair{1}); colorOf(pair{2})];
    f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
    items = {'RMS_eT_Nm', 'RMS e_T [N.m]'; 'TV_Ta_Nm_per_s', 'TV(T_a) [N.m/s]'};
    for k = 1:2
        subplot(2, 1, k); hold on;
        mu = zeros(numel(cases), 2); sg = mu;
        for c = 1:2
            for i = 1:numel(cases)
                r = strcmp(W.Ctrl, pair{c}) & strcmp(W.Case, cases{i});
                mu(i, c) = W.(['mean_' items{k, 1}])(r);
                sg(i, c) = W.(['std_' items{k, 1}])(r);
            end
        end
        bh = bar(mu);
        for c = 1:2
            bh(c).FaceColor = colors(c, :);
            errorbar(bh(c).XEndPoints, mu(:, c), sg(:, c), 'k.', 'LineWidth', 1);
        end
        set(gca, 'XTick', 1:numel(cases), 'XTickLabel', tags, 'YScale', 'log'); grid on; ylabel(items{k, 1 + 0 * 1}); ylabel(items{k, 2});
        legend(pair, 'Location', 'northwest', 'Interpreter', 'none');
        title(sprintf('%s (trục log, trung bình +- độ lệch chuẩn qua %d hạt giống)', items{k, 2}, numel(seeds)));
    end
    sgtitle(sprintf('%s, toàn ca (bỏ 2 s đầu), cảm biến có nhiễu', strjoin(pair, ' vs ')), 'Interpreter', 'none');
    exportgraphics(f, file, 'Resolution', 130);
    close(f);
end

function rgb = colorOf(ctrl)
% same colors as plot_compare_cases.m
    switch ctrl
        case 'Map',    rgb = [0.165 0.471 0.839];
        case 'PID',    rgb = [0.922 0.408 0.204];
        case 'SMC',    rgb = [0.106 0.686 0.478];
        case 'ISMC', rgb = [0.910 0.482 0.643];   % magenta
        case 'SMC_KI', rgb = [0.910 0.482 0.643];
        case 'PIDF_DZ',   rgb = [0.290 0.227 0.655];   % #4a3aa7 violet
        case 'SMC_KI_DZ', rgb = [0.000 0.514 0.000];   % #008300 green
        otherwise,     rgb = [0.36 0.36 0.36];
    end
end
