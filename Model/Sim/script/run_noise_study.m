function G = run_noise_study(ctrlList, levels, seeds)
%RUN_NOISE_STUDY Run the standard test cases with sensor noise for several controllers, noise levels and seeds; report mean and std.
%
%   G = run_noise_study({'Map', 'PID'}, {'none', 'low', 'high'}, 90001:90005)
%
%   For every controller, noise level and seed it calls run_test_cases(ctrl, level, seed) (metrics on the TRUE signals, see there),
%   then averages every metric over the seeds (levels 'none' and 'low' have no noise, so they are deterministic and run once). Every controller gets the SAME seeds,
%   so the same noise sequence (paired comparison). Seeds: tests use data/sensors.json seeds.test_range (90001-90010), never the
%   training range used by RL. Writes to Result/Compare/<A>_vs_<B>/ (names joined by _vs_):
%     <names>_noise_study_all_runs.csv   one row per controller, level, seed, case, window
%     <names>_noise_study_summary.csv    mean and std over seeds per controller, level, case, window
%     <names>_noise_study_whole_case.png RMS e_T and TV(T_a) per case, mean +- std, one column per noise level
%   Documents/Sim/ThucTeHoa.txt Mục 0 and 1.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir);
jr = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
assert(all(seeds >= jr.seeds.test_range(1) & seeds <= jr.seeds.test_range(2)), 'seeds must be inside the test range %s', mat2str(jr.seeds.test_range));

metrics = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
runs = table();
for c = 1:numel(ctrlList)
    for l = 1:numel(levels)
        sd = seeds;
        if any(strcmp(levels{l}, {'none', 'low'})), sd = seeds(1); end
        for s = sd
            t0 = tic;
            evalc('M = run_test_cases(ctrlList{c}, levels{l}, s);');
            M.Ctrl = repmat(ctrlList(c), height(M), 1);
            M.Level = repmat(levels(l), height(M), 1);
            M.Seed = repmat(s, height(M), 1);
            runs = [runs; M]; %#ok<AGROW>
            fprintf('run_noise_study: %s level %s seed %d done (%.0f s)\n', ctrlList{c}, levels{l}, s, toc(t0));
        end
    end
end

mean0 = @(x) mean(x, 'omitnan');
std0  = @(x) std(x, 0, 'omitnan');
G = groupsummary(runs, {'Ctrl', 'Level', 'Case', 'Window'}, {mean0, std0}, metrics);
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun1_', 'mean_');
G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun2_', 'std_');
tag = strjoin(ctrlList, '_vs_');
outDir = result_dir('Compare', tag);
writetable(runs, fullfile(outDir, [tag '_noise_study_all_runs.csv']));
writetable(G, fullfile(outDir, [tag '_noise_study_summary.csv']));

% ---- whole-case bars: rows = RMS e_T, TV(T_a); columns = noise levels ----
W = G(strcmp(G.Window, 'whole case'), :);
cases = unique(W.Case, 'stable');
tags = cellfun(@(s) s(1:3), cases, 'UniformOutput', false);
f = figure('Visible', 'off', 'Position', [50 50 450 * numel(levels) 700]);
items = {'RMS_eT_Nm', 'RMS e_T [N.m]'; 'TV_Ta_Nm_per_s', 'TV(T_a) [N.m/s]'};
for k = 1:2
    for l = 1:numel(levels)
        subplot(2, numel(levels), (k - 1) * numel(levels) + l); hold on;
        mu = zeros(numel(cases), numel(ctrlList)); sg = mu;
        for c = 1:numel(ctrlList)
            for i = 1:numel(cases)
                r = strcmp(W.Ctrl, ctrlList{c}) & strcmp(W.Level, levels{l}) & strcmp(W.Case, cases{i});
                mu(i, c) = W.(['mean_' items{k, 1}])(r);
                sg(i, c) = W.(['std_' items{k, 1}])(r);
            end
        end
        b = bar(mu);
        for c = 1:numel(ctrlList)
            errorbar(b(c).XEndPoints, mu(:, c), sg(:, c), 'k.', 'LineWidth', 1);
        end
        set(gca, 'XTick', 1:numel(cases), 'XTickLabel', tags); grid on; ylabel(items{k, 2});
        title(sprintf('noise: %s', levels{l}));
        if k == 1 && l == 1, legend(ctrlList, 'Location', 'northwest'); end
    end
end
sgtitle(sprintf('%s, whole case, mean +- std over %d seeds', strrep(tag, '_', ' '), numel(seeds)));
exportgraphics(f, fullfile(outDir, [tag '_noise_study_whole_case.png']), 'Resolution', 130);
close(f);
fprintf('run_noise_study: written to %s\n', outDir);
end
