function R = compare_controllers(ctrlNames)
%COMPARE_CONTROLLERS Run Model_<Controller>_s.mdl (Model/ folder) on the same scenarios and compare
%them (Documents/DieuKhien_PID.txt, DieuKhien_SMC.txt, DieuKhien_Map.txt, Blueprint section 1.5).
%
%   ctrlNames (optional cell array, default {'PID', 'SMC'}), e.g. {'Map', 'PID', 'SMC'}; the comparison
%   folder is Result/Compare/<A>_vs_<B>[_vs_<C>].
%
%   Run first: load_pid, load_smc and load_map for the controllers used (each also runs load_plant,
%   load_ref), then build_model_pid, build_model_smc and build_model_map (they create the Model_*_s.mdl).
%   Caution: find_ultimate_gain overwrites Kp, Ki, Kd in the base workspace only while it runs.
%
%   Scenarios (v = 20 m/s = 72 km/h, inside the range of Table 4 [7]):
%     S1 "hold + mu step": theta1 rises smoothly 0 -> 0.4 rad in 1 s, then
%        held; mu steps 0.8 -> 0.3 at t = 5 s (over-assist trigger).
%     S2 "sine steering + mu step": theta1 rises to 0.35 rad in 1 s, then
%        0.35 + 0.15*sin(2*pi*0.5*(t-2)) from t = 2 s; mu steps 0.8 -> 0.3
%        at t = 6.25 s. theta1 stays in 0.2..0.5 rad so a_y keeps one sign
%        and stays inside the table (no sign flip of T_d,ref).
%
%   Metrics on t >= 2 s (the start-up ramp is excluded: while a_y < 0.1 g
%   the Reference clips to the 0.1 g row, so T_d,ref jumps at a_y = 0):
%     RMS(e_T), max|e_T| after the mu step, recovery time after the mu
%     step (|e_T| stays below 0.1 N.m), RMS(T_a), max|T_a|, total
%     variation of T_a per second (smoothness / chattering indicator),
%     fraction of time with sign(T_a) ~= sign(T_s) (Blueprint 1.5
%     constraint, reported only - no saturation is applied).
%
%   Returns the metrics table R. Results are saved under <repo>/Result/:
%     Result/Compare/PID_vs_SMC/  comparison figure per scenario + metrics csv/mat
%     Result/PID/, Result/SMC/    signals csv + time-response figure per scenario,
%                                 and each controller's own metrics csv

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir, save_run_results

if nargin < 1
    ctrlNames = {'PID', 'SMC'};
end
cmpName   = strjoin(ctrlNames, '_vs_');         % e.g. PID_vs_SMC
cmpDir    = result_dir('Compare', cmpName);
scen = defineScenarios();
tol_rec = 0.1;   % N.m, recovery band

rows = {};
for si = 1:numel(scen)
    S = scen(si);
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    assignin('base', 'sc_v',      [S.t S.v]);
    fig = figure('Visible', 'off', 'Position', [100 100 500*numel(ctrlNames) 800]);
    for ci = 1:numel(ctrlNames)
        L = runClosedLoop(modelDir, ['Model_' ctrlNames{ci} '_s'], S.tEnd);
        m = computeMetrics(L, S.tStep, tol_rec);
        rows(end+1, :) = {S.tag, ctrlNames{ci}, m.rmsE, m.maxEafter, m.tRec, ...
            m.rmsTa, m.maxTa, m.tvTa, m.signViol, m.eEnd}; %#ok<AGROW>
        plotRun(fig, L, ci, numel(ctrlNames), ctrlNames{ci}, S);
        assert(all(isfinite(L.eT)), '%s/%s: e_T is not finite', S.tag, ctrlNames{ci});
        % result of ONE controller -> Result/<Controller>/
        save_run_results(ctrlNames{ci}, S.tag, ...
            struct('t', L.t, 'T_s', L.Ts, 'T_d_ref', L.Tref, 'e_T', L.eT, 'T_a', L.Ta, 'a_y', L.ay));
    end
    % comparison -> Result/Compare/PID_vs_SMC/
    exportgraphics(fig, fullfile(cmpDir, sprintf('%s_%s_time_response.png', cmpName, S.tag)), 'Resolution', 120);
    close(fig);
end
evalin('base', 'clear sc_theta1 sc_mu sc_v');

R = cell2table(rows, 'VariableNames', {'Scenario', 'Controller', 'RMS_eT', ...
    'MaxAbs_eT_after_step', 'Recovery_s', 'RMS_Ta', 'MaxAbs_Ta', 'TV_Ta_per_s', ...
    'SignViolation_frac', 'eT_end'});
disp(R);
writetable(R, fullfile(cmpDir, [cmpName '_scenario_metrics.csv']));
save(fullfile(cmpDir, [cmpName '_scenario_metrics.mat']), 'R');
for ci = 1:numel(ctrlNames)   % the same metrics, one controller only -> its own folder
    Rc = R(strcmp(R.Controller, ctrlNames{ci}), :);
    writetable(Rc, fullfile(result_dir(ctrlNames{ci}), [ctrlNames{ci} '_scenario_metrics.csv']));
end
end

%% ===================== Scenarios ======================================
function scen = defineScenarios()
    dt = 1e-3;
    ramp = @(t, A) A*(1 - cos(pi*min(t, 1)))/2;          % smooth 0 -> A in 1 s

    t = (0:dt:10)';
    s1.name = 'S1'; s1.tag = 'S1_hold_angle_mu_step'; s1.t = t; s1.tEnd = 10; s1.tStep = 5;
    s1.theta1 = ramp(t, 0.4);
    s1.mu = 0.8 - 0.5*(t >= 5);
    s1.v = 20*ones(size(t));

    t = (0:dt:12)';
    s2.name = 'S2'; s2.tag = 'S2_sine_steering_mu_step'; s2.t = t; s2.tEnd = 12; s2.tStep = 6.25;
    s2.theta1 = ramp(t, 0.35) + 0.15*sin(2*pi*0.5*(t - 2)).*(t >= 2);
    s2.mu = 0.8 - 0.5*(t >= 6.25);
    s2.v = 20*ones(size(t));

    scen = [s1, s2];
end

%% ===================== One closed-loop run ============================
function L = runClosedLoop(modelDir, modelName, tEnd)
% Runs Model_<Controller>_s.mdl (Model/ folder) directly: it reads the
% scenario from the base-workspace matrices sc_theta1, sc_v, sc_mu and
% writes log_T_s, log_T_d_ref, log_e_T, log_T_a, log_a_y. StopTime is set
% in memory only (the model is closed without saving).
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(fullfile(modelDir, [modelName '.mdl']));
    set_param(modelName, 'StopTime', sprintf('%.15g', tEnd));
    so = sim(Simulink.SimulationInput(modelName));
    close_system(modelName, 0);

    ts = so.get('log_T_a');
    tg = (0:0.001:tEnd)';   % common uniform grid for the metrics
    L.t   = tg;
    L.Ta  = resampleHold(ts, tg);
    L.Ts  = resampleLin(so.get('log_T_s'), tg);
    L.Tref= resampleLin(so.get('log_T_d_ref'), tg);
    L.eT  = resampleLin(so.get('log_e_T'), tg);
    L.ay  = resampleLin(so.get('log_a_y'), tg);
end

function y = resampleLin(ts, tg)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), tg, 'linear', 'extrap');
end

function y = resampleHold(ts, tg)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), tg, 'previous', 'extrap');
end

%% ===================== Metrics ========================================
function m = computeMetrics(L, tStep, tolRec)
    w  = L.t >= 2;
    wa = L.t >= tStep;
    m.rmsE      = sqrt(mean(L.eT(w).^2));
    m.maxEafter = max(abs(L.eT(wa)));
    idx = find(wa & abs(L.eT) >= tolRec, 1, 'last');
    if isempty(idx)
        m.tRec = 0;
    elseif idx == numel(L.t)
        m.tRec = NaN;   % never recovers inside the window
    else
        m.tRec = L.t(idx) - tStep;
    end
    m.rmsTa    = sqrt(mean(L.Ta(w).^2));
    m.maxTa    = max(abs(L.Ta(w)));
    dTa        = diff(L.Ta(w));
    m.tvTa     = sum(abs(dTa)) / (L.t(end) - 2);
    m.signViol = mean(sign(L.Ta(w)) ~= sign(L.Ts(w)) & abs(L.Ta(w)) > 1e-6);
    m.eEnd     = L.eT(end);
end

%% ===================== Plot ===========================================
function plotRun(fig, L, ci, nc, name, S)
    figure(fig);
    subplot(3, nc, ci);
    plot(L.t, L.Ts, 'b', L.t, L.Tref, 'r--'); grid on;
    xline(S.tStep, 'k:'); ylabel('N.m'); title([S.name ' ' name ': T_s (blue) vs T_{d,ref} (red)']);
    subplot(3, nc, nc + ci);
    plot(L.t, L.eT, 'k'); grid on; xline(S.tStep, 'k:'); ylabel('e_T [N.m]');
    ylim([-2 2]); title('e_T = T_s - T_{d,ref}');
    subplot(3, nc, 2*nc + ci);
    plot(L.t, L.Ta, 'm'); grid on; xline(S.tStep, 'k:'); ylabel('T_a [N.m]'); xlabel('t [s]');
    title('T_a');
end
