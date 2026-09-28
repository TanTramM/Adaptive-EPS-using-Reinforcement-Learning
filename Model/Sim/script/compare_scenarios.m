function R = compare_scenarios(ctrlNames, vKmh, ayTarget)
%COMPARE_SCENARIOS Run several controllers on the SAME scenarios at several speeds and compare them.
%
%   R = compare_scenarios(ctrlNames, vKmh, ayTarget)
%     ctrlNames  cell array, default {'Map', 'PID', 'SMC'}
%     vKmh       speeds [km/h], default [40 60 80 100]
%     ayTarget   lateral acceleration [g] of the held steering angle at mu = 0.8, default 0.2
%
%   For every speed the held steering angle theta1_hold gives a_y = ayTarget at mu = 0.8 with e_T = 0
%   (plain-MATLAB steady state of the small-angle Plant, theta1 = n_st*delta_f + T_d,ref/K), so the
%   controller starts from a consistent operating point. Three scenarios per speed (t >= 2 s is scored):
%     S1  hold: theta1 rises smoothly 0 -> theta1_hold in 1 s and is held; mu 0.8 -> 0.3 at t = 5 s
%         (over-assist trigger), tEnd = 10 s.
%     S2  sine: theta1 rises to theta1_hold in 1 s, then theta1_hold*(1 + 0.3*sin(2*pi*0.5*(t-2)))
%         from t = 2 s; mu 0.8 -> 0.3 at t = 6.25 s, tEnd = 12 s.
%     S3  hold, reverse step: like S1 but mu 0.3 -> 0.8 at t = 5 s (theta1_hold computed at mu = 0.8).
%   With ayTarget = 0.2 g the peak a_y stays below mu*g = 0.294 g at mu = 0.3 (Documents/Boundaries.txt).
%
%   Metrics as in compare_controllers.m (RMS e_T, max|e_T| after the step, recovery time, RMS/max T_a,
%   total variation of T_a, sign violation). Results: Result/<Controller>/ (signals + figure per run) and
%   Result/Compare/<A>_vs_<B>_vs_<C>/ (figure per scenario, <name>_multi_speed_metrics.csv/.mat).
%
%   Run first: load_pid, load_smc, load_map (each runs load_plant, load_ref) and build the closed-loop
%   models (Model_*_s.mdl).

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);

if nargin < 1 || isempty(ctrlNames), ctrlNames = {'Map', 'PID', 'SMC'}; end
if nargin < 2 || isempty(vKmh),      vKmh = [40 60 80 100]; end
if nargin < 3 || isempty(ayTarget),  ayTarget = 0.2; end

cmpName = strjoin(ctrlNames, '_vs_');
cmpDir  = result_dir('Compare', cmpName);
tolRec  = 0.1;   % N.m, recovery band

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
P.Iz = raw.cum3.Iz.value;
P.F_zf = P.m * P.g * P.l_r / (P.l_f + P.l_r);
P.F_zr = P.m * P.g * P.l_f / (P.l_f + P.l_r);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));

rows = {};
for v = vKmh
    th0 = operatingTheta1(P, ref, v/3.6, ayTarget, 0.8);
    fprintf('compare_scenarios: v = %d km/h, theta1_hold = %.4f rad (a_y = %.2f g at mu = 0.8)\n', v, th0, ayTarget);
    scen = defineScenarios(v, th0);
    for si = 1:numel(scen)
        S = scen(si);
        assignin('base', 'sc_theta1', [S.t S.theta1]);
        assignin('base', 'sc_mu',     [S.t S.mu]);
        assignin('base', 'sc_v',      [S.t S.v]);
        fig = figure('Visible', 'off', 'Position', [100 100 500*numel(ctrlNames) 800]);
        for ci = 1:numel(ctrlNames)
            L = runClosedLoop(modelDir, ['Model_' ctrlNames{ci} '_s'], S.tEnd);
            m = computeMetrics(L, S.tStep, tolRec);
            rows(end+1, :) = {S.tag, S.kind, v, ctrlNames{ci}, m.rmsE, m.maxEafter, m.tRec, ...
                m.rmsTa, m.maxTa, m.tvTa, m.signViol, m.eEnd}; %#ok<AGROW>
            plotRun(fig, L, ci, numel(ctrlNames), ctrlNames{ci}, S);
            assert(all(isfinite(L.eT)), '%s/%s: e_T is not finite', S.tag, ctrlNames{ci});
            save_run_results(ctrlNames{ci}, S.tag, ...
                struct('t', L.t, 'T_s', L.Ts, 'T_d_ref', L.Tref, 'e_T', L.eT, 'T_a', L.Ta, 'a_y', L.ay));
        end
        exportgraphics(fig, fullfile(cmpDir, sprintf('%s_%s_time_response.png', cmpName, S.tag)), 'Resolution', 120);
        close(fig);
    end
end
evalin('base', 'clear sc_theta1 sc_mu sc_v');

R = cell2table(rows, 'VariableNames', {'Scenario', 'Kind', 'v_kmh', 'Controller', 'RMS_eT', ...
    'MaxAbs_eT_after_step', 'Recovery_s', 'RMS_Ta', 'MaxAbs_Ta', 'TV_Ta_per_s', 'SignViolation_frac', 'eT_end'});
writetable(R, fullfile(cmpDir, [cmpName '_multi_speed_metrics.csv']));
save(fullfile(cmpDir, [cmpName '_multi_speed_metrics.mat']), 'R');
disp(R);
end

%% ===================== Scenarios ======================================
function scen = defineScenarios(v, th0)
    dt = 1e-3;
    ramp = @(t) (1 - cos(pi*min(t, 1)))/2;   % smooth 0 -> 1 in 1 s
    vtag = sprintf('v%d', v);

    t = (0:dt:10)';
    s1.kind = 'S1'; s1.name = sprintf('S1 v=%d', v); s1.tag = ['S1_hold_mu_0p8_to_0p3_' vtag];
    s1.t = t; s1.tEnd = 10; s1.tStep = 5;
    s1.theta1 = th0*ramp(t); s1.mu = 0.8 - 0.5*(t >= 5); s1.v = (v/3.6)*ones(size(t));

    t = (0:dt:12)';
    s2.kind = 'S2'; s2.name = sprintf('S2 v=%d', v); s2.tag = ['S2_sine_mu_0p8_to_0p3_' vtag];
    s2.t = t; s2.tEnd = 12; s2.tStep = 6.25;
    s2.theta1 = th0*ramp(t).*(1 + 0.3*sin(2*pi*0.5*(t - 2)).*(t >= 2));
    s2.mu = 0.8 - 0.5*(t >= 6.25); s2.v = (v/3.6)*ones(size(t));

    t = (0:dt:10)';
    s3.kind = 'S3'; s3.name = sprintf('S3 v=%d', v); s3.tag = ['S3_hold_mu_0p3_to_0p8_' vtag];
    s3.t = t; s3.tEnd = 10; s3.tStep = 5;
    s3.theta1 = th0*ramp(t); s3.mu = 0.3 + 0.5*(t >= 5); s3.v = (v/3.6)*ones(size(t));

    scen = [s1, s2, s3];
end

%% ===================== One closed-loop run ============================
function L = runClosedLoop(modelDir, modelName, tEnd)
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(fullfile(modelDir, [modelName '.mdl']));
    set_param(modelName, 'StopTime', sprintf('%.15g', tEnd));
    so = sim(Simulink.SimulationInput(modelName));
    close_system(modelName, 0);

    ts = so.get('log_T_a');
    tg = (0:0.001:tEnd)';
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
    m.tvTa     = sum(abs(diff(L.Ta(w)))) / (L.t(end) - 2);
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

%% ===================== Operating point (plain MATLAB, no Simulink) =======
function theta1 = operatingTheta1(P, ref, v, ayG, mu)
% theta1 that gives lateral acceleration ayG (in g) with e_T = 0: theta1 = n_st*delta_f + T_d,ref/K, with delta_f from
% the steady state of the small-angle Plant (continuation on a_y).
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    z = [0.001; 0.01; 0.001];   % [beta; gamma; delta_f]
    for a = unique([0.01:0.01:ayG, ayG])
        F = @(z) [ (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / (P.m * v) - z(2);
                   (P.l_f * fyf(z, v, P, mu) - P.l_r * fyr(z, v, P, mu)) / P.Iz;
                   (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / P.m - a * 9.81 ];
        [z, ~, flag] = fsolve(F, z, opt);
        assert(flag > 0, 'no steady state at v = %g m/s, mu = %g, a_y = %g g', v, mu, a);
    end
    vBp = ref.v_breakpoints_kmh(:)';
    aBp = ref.ay_breakpoints_g(:);
    Tdref = interp2(vBp, aBp, ref.table_Nm, min(max(v*3.6, vBp(1)), vBp(end)), min(max(ayG, aBp(1)), aBp(end)), 'linear');
    theta1 = P.n_st * z(3) + Tdref / P.K;
end

function F = magicFormula(P, alpha, mu, Fz, Calpha)
    D = mu * Fz;
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function F = fyf(z, v, P, mu)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    F = magicFormula(P, alpha_f, mu, P.F_zf, P.C_alpha_f);
end

function F = fyr(z, v, P, mu)
    alpha_r = -z(1) + P.l_r * z(2) / v;
    F = magicFormula(P, alpha_r, mu, P.F_zr, P.C_r);
end
