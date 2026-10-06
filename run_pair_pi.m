try
    cd Model/Sim/script
    
    ctrlList = {'PI_2K', 'PI'};
    seeds = 90001:90005;
    
    metrics = {'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'};
    runs = table();
    
    for ci = 1:numel(ctrlList)
        % Ensure any previously open models are closed to prevent variable collision
        bdclose('all');
        
        evalc(sprintf('run(''../../load_%s.m'');', lower(ctrlList{ci})));
        for s = seeds
            t0 = tic;
            evalc('M = run_test_cases(ctrlList{ci}, ''high'', s);');
            M.Ctrl = repmat(ctrlList(ci), height(M), 1);
            M.Level = repmat({'high'}, height(M), 1);
            M.Seed = repmat(s, height(M), 1);
            runs = [runs; M]; %#ok<AGROW>
            fprintf('run_pair_pi: %s seed %d done (%.0f s)\n', ctrlList{ci}, s, toc(t0));
        end
    end
    
    bdclose('all');
    
    mean0 = @(x) mean(x, 'omitnan');
    std0  = @(x) std(x, 0, 'omitnan');
    G = groupsummary(runs, {'Ctrl', 'Level', 'Case', 'Window'}, {mean0, std0}, metrics);
    G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun1_', 'mean_');
    G.Properties.VariableNames = regexprep(G.Properties.VariableNames, '^fun2_', 'std_');

    pair = {'PI_2K', 'PI'};
    tag = strjoin(pair, '_vs_');
    outDir = result_dir('Compare', tag);
    writetable(runs(ismember(runs.Ctrl, pair), :), fullfile(outDir, [tag '_noise_study_all_runs.csv']));
    writetable(G(ismember(G.Ctrl, pair), :), fullfile(outDir, [tag '_noise_study_summary.csv']));
    wholeCaseBars(G, pair, seeds, fullfile(outDir, [tag '_whole_case.png']));
    
    plot_compare_cases(pair, 'high', seeds(1));

    disp('SUCCESS');
    exit(0);
catch ME
    disp(ME.message);
    exit(1);
end
