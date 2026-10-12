function M = run_cases(ctrlName, runSeed)
%RUN_CASES Run the standard test cases (make_cases.m) on one controller and save the results.
%
%   M = run_cases('Map')            % ideal sensors
%   M = run_cases('Map', 99999)     % noisy sensors, run seed 99999 (the scoring seed of the standard test cases)
%
%   Noise (Sensors subsystem, data/sensors.json, Documents/Sim/ThucTeHoa.txt): the seed is passed to the model per run
%   (sensor_noise_vars.m), so every controller sees the same noise sequence for the same seed. All metrics and plots use the TRUE
%   signals (log_T_s, log_e_T... come from the scoring Reference), not what the controller measured. The sensor mode is the token
%   <sens> in every file name (sensor_tag.m): 'ideal' (no seed) or 's<5 digits>' (noisy, e.g. s99999).
%
%   Runs Model_<ctrlName>.mdl (run load_<ctrl> and build the closed-loop model first). For every case <CASE> in DRY, RAMP, SLIP, WEAVE, EDGE:
%     Result/Controllers/<ctrlName>/Cases/<ctrlName>_<CASE>_sig_<sens>.csv    t, theta1, v, mu, a_y target, T_s, T_d_ref, e_T, T_a, a_y
%     Result/Controllers/<ctrlName>/Cases/<ctrlName>_<CASE>_resp_<sens>.png   3 panels: T_s vs T_d,ref | e_T with the scoring windows shaded | T_a
%   and one table Result/Controllers/<ctrlName>/Cases/<ctrlName>_metrics_<sens>.csv:
%     per case  : RMS e_T, max |e_T|, RMS T_a, max |T_a|, total variation of T_a per second (smoothness), S (RMS of T_a high-passed at 5 Hz),
%                 reverse assist (% of scored samples with |T_s| >= 0.5 N.m and T_a against T_s), peak |T_a| in % of T_a,max(v)
%     per window: mean e_T, mean T_d,ref and mean e_T / mean T_d,ref over the windows defined in make_cases.m
%   The first 2 s of each case are not scored (start from rest). make_cases() returns DRY, RAMP, SLIP, WEAVE and EDGE (RAMP and EDGE are report only).

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
if nargin < 2, runSeed = []; end
noiseVars = sensor_noise_vars(runSeed);
saveFigs = true;
sens = sensor_tag(runSeed);
outDir = result_dir(ctrlName, 'Cases');
mdl = ['Model_' ctrlName];

TC = make_cases();
TaMaxJ = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
rows = {};
for k = 1:numel(TC)
    S = TC(k);
    L = runCase(modelDir, mdl, S, noiseVars);
    w = L.t >= 2;
    dt = L.t(2) - L.t(1); a = dt / (1 / (2 * pi * 5) + dt);
    hp = L.T_a - filter(a, [1 -(1 - a)], L.T_a);
    TaMax = interp1(TaMaxJ.Ta_max.v_kmh(:), TaMaxJ.Ta_max.Ta_max_Nm(:), L.v * 3.6, 'linear', 'extrap');
    rows(end+1, :) = {S.tag, 'whole case', sqrt(mean(L.e_T(w).^2)), max(abs(L.e_T(w))), NaN, NaN, ...
        sqrt(mean(L.T_a(w).^2)), max(abs(L.T_a(w))), sum(abs(diff(L.T_a(w)))) / (L.t(end) - 2), ...
        sqrt(mean(hp(w).^2)), 100 * mean(abs(L.T_s(w)) >= 0.5 & L.T_a(w) .* L.T_s(w) < 0), 100 * max(abs(L.T_a(w)) ./ TaMax(w))}; %#ok<AGROW>
    for j = 1:numel(S.win)
        in = L.t >= S.win(j).t0 & L.t <= S.win(j).t1;
        e = mean(L.e_T(in)); Td = mean(abs(L.T_d_ref(in)));
        rows(end+1, :) = {S.tag, S.win(j).label, sqrt(mean(L.e_T(in).^2)), max(abs(L.e_T(in))), e, ...
            100 * e * sign(mean(L.T_d_ref(in))) / max(Td, eps), NaN, NaN, NaN, NaN, NaN, NaN}; %#ok<AGROW>
    end
    T = table(L.t, L.theta1, L.v, L.mu, L.ayTarget, L.T_s, L.T_d_ref, L.e_T, L.T_a, L.a_y, 'VariableNames', ...
        {'t', 'theta1_rad', 'v_mps', 'mu', 'a_y_target_g', 'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y'});
    writetable(T(1:10:end, :), fullfile(outDir, sprintf('%s_%s_sig_%s.csv', ctrlName, S.tag, sens)));
    if saveFigs
        plotCase(L, S, ctrlName, fullfile(outDir, sprintf('%s_%s_resp_%s.png', ctrlName, S.tag, sens)));
    end
    fprintf('run_cases: %s %s done (RMS e_T %.3f N.m)\n', ctrlName, S.tag, rows{end - numel(S.win), 3});
end
M = cell2table(rows, 'VariableNames', {'Case', 'Window', 'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'Mean_eT_Nm', ...
    'Mean_eT_signed_pct_of_Tdref', 'RMS_Ta_Nm', 'MaxAbs_Ta_Nm', 'TV_Ta_Nm_per_s', 'S_Nm', 'Rev_pct', 'Peak_Ta_pct_of_Tamax'});
writetable(M, fullfile(outDir, sprintf('%s_metrics_%s.csv', ctrlName, sens)));
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

%% ===================== 3-panel figure =====================
function plotCase(L, S, ctrlName, file)
    f = figure('Visible', 'off', 'Position', [50 50 1100 700]);
    tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s - %s', ctrlName, S.tag), 'FontWeight', 'bold');
    ax(1) = nexttile; plot(L.t, L.T_s, 'b', L.t, L.T_d_ref, 'r--', 'LineWidth', 1); grid on;
    ylabel('N.m'); legend('T_s', 'T_{d,ref}', 'Location', 'northeast'); title('T_s and T_{d,ref}');
    ax(2) = nexttile; plot(L.t, L.e_T, 'k', 'LineWidth', 1); grid on; hold on;
    for j = 1:numel(S.win)
        xregion(S.win(j).t0, S.win(j).t1, 'FaceColor', [0.85 0.9 1], 'FaceAlpha', 0.6);
    end
    ylabel('e_T [N.m]'); title('e_T = T_s - T_{d,ref} (shaded: scoring windows)');
    ax(3) = nexttile; plot(L.t, L.T_a, 'm', 'LineWidth', 1); grid on; ylabel('T_a [N.m]'); xlabel('t [s]'); title('Assist torque T_a');
    linkaxes(ax, 'x'); xlim(ax(1), [0 L.t(end)]);
    exportgraphics(f, file, 'Resolution', 130);
    close(f);
end
