function M = run_test_cases(ctrlName, level, runSeed)
%RUN_TEST_CASES Run the standard test cases (test_cases.m) on one controller and save the results.
%
%   M = run_test_cases('Map_6_8')      % also 'PID', 'SMC', 'SMC_KI', ...
%   M = run_test_cases('PID', 'high', 90003)   % with sensor noise: level 'none' | 'high', one noise seed
%
%   Noise (Sensors subsystem, data/sensors.json, Documents/Sim/ThucTeHoa.txt): the level and seed are passed to the model per run
%   (sensor_noise_vars.m), so every controller sees the same noise sequence for the same seed. All metrics and plots use the TRUE
%   signals (log_T_s, log_e_T... come from the scoring Reference), not what the controller measured. A noisy run is saved in
%   Result/<ctrl>/TestCases_noise/<level>_seed<seed>/ (figures only for the default seed); no argument = no noise, folder TestCases.
%
%   Runs Model_<ctrlName>_s.mdl (run load_<ctrl> and build the closed-loop model first). For every case:
%     Result/<ctrlName>/TestCases/<ctrlName>_<case>_signals.csv        t, theta1, v, mu, a_y target, T_s, T_d_ref, e_T, T_a, a_y
%     Result/<ctrlName>/TestCases/<ctrlName>_<case>_time_response.png  6 panels: T_s vs T_d,ref | e_T | T_a | theta1 | mu | v
%   and one table Result/<ctrlName>/TestCases/<ctrlName>_test_case_metrics.csv:
%     per case  : RMS e_T, max |e_T|, RMS T_a, max |T_a|, total variation of T_a per second (smoothness)
%     per window: mean e_T, mean T_d,ref and mean e_T / mean T_d,ref over the windows defined in test_cases.m
%   The first 2 s of each case are not scored (start from rest).

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
if nargin < 2, level = 'none'; end
defaultSeed = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json'))).seeds.default_run_seed;
if nargin < 3, runSeed = defaultSeed; end
noiseVars = sensor_noise_vars(level, runSeed);
saveFigs = true;
if strcmp(level, 'none')
    outDir = result_dir(ctrlName, 'TestCases');
else
    outDir = result_dir(ctrlName, 'TestCases_noise', sprintf('%s_seed%d', level, runSeed));
    saveFigs = (runSeed == defaultSeed);
end
mdl = ['Model_' ctrlName '_s'];

TC = test_cases();
rows = {};
for k = 1:numel(TC)
    S = TC(k);
    L = runCase(modelDir, mdl, S, noiseVars);
    w = L.t >= 2;
    rows(end+1, :) = {S.tag, 'whole case', sqrt(mean(L.e_T(w).^2)), max(abs(L.e_T(w))), NaN, NaN, ...
        sqrt(mean(L.T_a(w).^2)), max(abs(L.T_a(w))), sum(abs(diff(L.T_a(w)))) / (L.t(end) - 2)}; %#ok<AGROW>
    for j = 1:numel(S.win)
        in = L.t >= S.win(j).t0 & L.t <= S.win(j).t1;
        e = mean(L.e_T(in)); Td = mean(abs(L.T_d_ref(in)));
        rows(end+1, :) = {S.tag, S.win(j).label, sqrt(mean(L.e_T(in).^2)), max(abs(L.e_T(in))), e, ...
            100 * e * sign(mean(L.T_d_ref(in))) / max(Td, eps), NaN, NaN, NaN}; %#ok<AGROW>
    end
    T = table(L.t, L.theta1, L.v, L.mu, L.ayTarget, L.T_s, L.T_d_ref, L.e_T, L.T_a, L.a_y, 'VariableNames', ...
        {'t', 'theta1_rad', 'v_mps', 'mu', 'a_y_target_g', 'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y'});
    writetable(T(1:10:end, :), fullfile(outDir, sprintf('%s_%s_signals.csv', ctrlName, S.tag)));
    if saveFigs
        plotCase(L, S, ctrlName, fullfile(outDir, sprintf('%s_%s_time_response.png', ctrlName, S.tag)));
    end
    fprintf('run_test_cases: %s %s done (RMS e_T %.3f N.m)\n', ctrlName, S.tag, rows{end - numel(S.win), 3});
end
M = cell2table(rows, 'VariableNames', {'Case', 'Window', 'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_Nm', ...
    'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s'});
writetable(M, fullfile(outDir, sprintf('%s_test_case_metrics.csv', ctrlName)));
evalin('base', 'clear sc_theta1 sc_v sc_mu');
end

%% ===================== one case =====================
function L = runCase(modelDir, mdl, S, noiseVars)
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_v',      [S.t S.v]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    if ~bdIsLoaded(mdl), load_system(mdl); end
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    fn = fieldnames(noiseVars);
    for k = 1:numel(fn)
        in = in.setVariable(fn{k}, noiseVars.(fn{k}));
    end
    so = sim(in);
    L.t = S.t; L.theta1 = S.theta1; L.v = S.v; L.mu = S.mu; L.ayTarget = S.ayTarget;
    names = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y'};
    for i = 1:numel(names)
        ts = so.get(['log_' names{i}]);
        [tu, iu] = unique(ts.Time, 'last');
        method = 'linear';
        if strcmp(names{i}, 'T_a'), method = 'previous'; end   % held between controller samples
        L.(names{i}) = interp1(tu, squeeze(ts.Data(iu)), S.t, method, 'extrap');
    end
end

%% ===================== 6-panel figure =====================
function plotCase(L, S, ctrlName, file)
    f = figure('Visible', 'off', 'Position', [50 50 1100 1250]);
    tl = tiledlayout(6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s - %s', ctrlName, S.name), 'FontWeight', 'bold');
    ax(1) = nexttile; plot(L.t, L.T_s, 'b', L.t, L.T_d_ref, 'r--', 'LineWidth', 1); grid on;
    ylabel('N.m'); legend('T_s', 'T_{d,ref}', 'Location', 'northeast'); title('T_s và T_{d,ref}');
    ax(2) = nexttile; plot(L.t, L.e_T, 'k', 'LineWidth', 1); grid on; hold on;
    for j = 1:numel(S.win)
        xregion(S.win(j).t0, S.win(j).t1, 'FaceColor', [0.85 0.9 1], 'FaceAlpha', 0.6);
    end
    ylabel('e_T [N.m]'); title('e_T = T_s - T_{d,ref} (vùng tô: cửa sổ tính chỉ tiêu)');
    ax(3) = nexttile; plot(L.t, L.T_a, 'm', 'LineWidth', 1); grid on; ylabel('T_a [N.m]'); title('Mô-men trợ lực T_a');
    ax(4) = nexttile; plot(L.t, rad2deg(L.theta1), 'Color', [0 0.5 0], 'LineWidth', 1); grid on;
    ylabel('\theta_1 [độ]'); title('Góc vô-lăng \theta_1');
    ax(5) = nexttile; plot(L.t, L.mu, 'Color', [0.8 0.4 0], 'LineWidth', 1.2); grid on; ylim([0 1]);
    ylabel('\mu'); title('Hệ số bám \mu');
    ax(6) = nexttile; plot(L.t, L.v * 3.6, 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2); grid on;
    ylabel('v [km/h]'); xlabel('t [s]'); title('Vận tốc v');
    linkaxes(ax, 'x'); xlim(ax(1), [0 L.t(end)]);
    exportgraphics(f, file, 'Resolution', 130);
    close(f);
end
