function test_model_rl_s()
%TEST_MODEL_RL_S Wiring check of Model_RL_s.mdl with the agent switched off (T_a = 0).
%
%   With rl_use_agent = 0 the closed loop is the open-loop plant, whose steady state is known:
%   T_s = T_r (Documents/Plant/plant.txt Eq. (6) with T_a = 0). The scenario (rl_scenario) holds a steering
%   angle that gives a_y = 0.2 g at 40 km/h on the dry road, then mu steps 0.8 -> 0.3 at 12 s.
%   Checks, against a steady-state solution computed INDEPENDENTLY here from data/params.json (ideal sensors):
%     (1) T_s before and after the mu step (plant, reference and logging wired correctly);
%     (2) T_a is exactly 0 (switch and limit wired correctly);
%     (3) e_T = T_s - T_d_ref at every logged sample (reference wired correctly);
%     (4) the logged reward equals -(e_T/T_ref)^2 at the agent samples (reward block wired correctly).
%   Then with sensor level 'high' (agent still off), checked on a temporary tap of the observation:
%     (5) the agent sees the MEASURED T_s (a multiple of the sensor step, different from the true T_s);
%     (6) the history samples are rl_hist_stride agent samples apart and the observation has 7*n_hist + 2 elements;
%     (7) the reward is computed on the TRUE e_T;
%     (8) the slow observation I (last element) is the first-order low-pass of the observed (measured) e_T, computed independently here.
%   Run first: run('<Model>/load_rl.m'); the agent is created here only so the model compiles.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
mdl = 'Model_RL_s';

P = readPlant(modelDir);
v = 40 / 3.6;
z0 = fsolve(@(z) resAy(P, z, v, 0.8, 0.2 * P.g), [0; 0; 0.3], optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13));
th1 = z0(3) + Tr(P, z0, v, 0.8) / P.K;                    % theta1 = theta2 + T_s/K with T_s = T_r
TsBefore = Tr(P, z0, v, 0.8);
z1 = fsolve(@(z) resHold(P, z, v, 0.3, th1), z0, optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13));
TsAfter = P.K * (th1 - z1(3));

rl_env();                                                 % agent in the base workspace (model compiles)
sc = rl_scenario(40, th1, 0.3, 12, 30);
in = Simulink.SimulationInput(mdl);
in = in.setVariable('sc_theta1', [sc.t sc.theta1]);
in = in.setVariable('sc_v', [sc.t sc.v]);
in = in.setVariable('sc_mu', [sc.t sc.mu]);
in = in.setVariable('rl_use_agent', 0);
in = in.setModelParameter('StopTime', '30');
so = sim(in);

Ts  = so.get('log_T_s'); Td = so.get('log_T_d_ref'); eT = so.get('log_e_T');
Ta  = so.get('log_T_a'); rw = so.get('log_reward');
mb = mean(Ts.Data(Ts.Time > 11.5 & Ts.Time < 12));
ma = mean(Ts.Data(Ts.Time > 29.5));
assert(abs(mb - TsBefore) < 1e-3, '(1) T_s before the mu step %.5f, independent %.5f', mb, TsBefore);
assert(abs(ma - TsAfter) < 1e-3, '(1) T_s after the mu step %.5f, independent %.5f', ma, TsAfter);
assert(max(abs(Ta.Data(:))) == 0, '(2) T_a is not zero with the agent switched off');
assert(max(abs(eT.Data(:) - (Ts.Data(:) - Td.Data(:)))) < 1e-9, '(3) e_T ~= T_s - T_d_ref');
par = evalin('base', 'rl_reward_par');
tk = (1:1:29000)' * 1e-3;                                 % agent samples, away from the ends
eTk = interp1(eT.Time, squeeze(eT.Data), tk, 'previous');
rwk = interp1(rw.Time, squeeze(rw.Data), tk, 'previous');
errR = max(abs(rwk - (-(eTk / par(1)).^2)));
assert(errR < 1e-2, '(4) reward differs from -(e_T/T_ref)^2: max err %.3g', errR);

%% ----- (5)-(7) sensors: what the agent sees, history spacing, what the reward uses (level 'high', agent off) -----
if ~bdIsLoaded(mdl), load_system(fullfile(modelDir, [mdl '.mdl'])); end
rlSub = [mdl '/Model_RL/RL'];
add_block('simulink/Sinks/To Workspace', [rlSub '/Tap_obs'], 'VariableName', 'tap_obs', 'SaveFormat', 'Structure With Time');
add_line(rlSub, 'Cat_obs/1', 'Tap_obs/1');                % temporary tap on the observation (model is closed without saving)
V = sensor_noise_vars('high', 90001);
in2 = Simulink.SimulationInput(mdl);
in2 = in2.setVariable('sc_theta1', [sc.t sc.theta1]);
in2 = in2.setVariable('sc_v', [sc.t sc.v]);
in2 = in2.setVariable('sc_mu', [sc.t sc.mu]);
in2 = in2.setVariable('rl_use_agent', 0);
in2 = in2.setModelParameter('StopTime', '30');
fn = fieldnames(V);
for k = 1:numel(fn), in2 = in2.setVariable(fn{k}, V.(fn{k})); end
so2 = sim(in2);
tap = so2.get('tap_obs');
Ob = squeeze(tap.signals.values); if size(Ob, 1) ~= numel(tap.time), Ob = Ob'; end
gain = evalin('base', 'rl_obs_gain'); D = evalin('base', 'rl_hist_stride'); nHist = evalin('base', 'rl_n_hist');
TsMeas = so2.get('log_T_s_meas'); TsTrue = so2.get('log_T_s'); eTt = so2.get('log_e_T'); rw2 = so2.get('log_reward');
tt = tap.time; use = tt > 2 & tt < 29;
obsTs = Ob(use, 2) / gain(2);                              % T_s as the agent sees it (2nd signal of the observation)
mRef = interp1(TsMeas.Time, squeeze(TsMeas.Data), tt(use), 'previous');
tRef = interp1(TsTrue.Time, squeeze(TsTrue.Data), tt(use), 'previous');
assert(max(abs(obsTs - mRef)) < 1e-9, '(5) the agent does not see the MEASURED T_s (max diff %.3g)', max(abs(obsTs - mRef)));
assert(max(abs(obsTs - tRef)) > 1e-3, '(5) measured T_s equals the true T_s at level high');
assert(max(abs(obsTs / 0.01 - round(obsTs / 0.01))) < 1e-6, '(5) observed T_s is not a multiple of the sensor step');
kk = find(tt > 2 & tt < 29); kk = kk(kk > D);
assert(max(abs(Ob(kk, 7 + 2) - Ob(kk - D, 2))) < 1e-12, '(6) history sample is not the value D = %d agent samples earlier', D);
assert(size(Ob, 2) == 7 * nHist + 2, '(6) observation length %d, expected %d', size(Ob, 2), 7 * nHist + 2);
% (8) slow observation: I[k+1] = (1 - a) I[k] + a e_T[k] with a = Ts/tau, observed I[k] = value BEFORE the update with e_T[k]
raw0 = jsondecode(fileread(fullfile(modelDir, 'data', 'rl.json')));
aI = raw0.Ts_agent.value / raw0.I_tau.value;
eObs = Ob(:, 1) / gain(1);                                   % measured e_T as the agent sees it (first signal of the observation)
Iref = [0; filter(aI, [1, -(1 - aI)], eObs(1:end - 1))];     % filter(b, a, x): y[k] = (1 - aI) y[k-1] + aI x[k]
Iobs = Ob(:, end) / evalin('base', 'rl_I_gain');
assert(max(abs(Iobs(use) - Iref(use))) < 1e-6, '(8) slow observation differs from the independent low-pass: max diff %.3g', max(abs(Iobs(use) - Iref(use))));
eTk2 = interp1(eTt.Time, squeeze(eTt.Data), tk, 'previous');
rwk2 = interp1(rw2.Time, squeeze(rw2.Data), tk, 'previous');
errR2 = max(abs(rwk2 - (-(eTk2 / par(1)).^2)));
assert(errR2 < 1e-2, '(7) reward differs from -(e_T_true/T_ref)^2 at level high: max err %.3g', errR2);
close_system(mdl, 0);

fprintf(['[%s] TEST PASS: T_a = 0; T_s before mu step %.4f (independent %.4f), after %.4f (independent %.4f), drop %.3f N.m; ' ...
    'e_T = T_s - T_d_ref; reward = -(e_T/T_ref)^2 (max err %.2g); level high: agent sees measured T_s (quantized), history %d agent samples apart, ' ...
    '%d observations, slow e_T observation matches the independent low-pass, reward on true e_T (max err %.2g)\n'], mdl, mb, TsBefore, ma, TsAfter, mb - ma, errR, D, size(Ob, 2), errR2);
end

%% ===================== independent steady state (plain MATLAB) =====================
function P = readPlant(modelDir)
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    P = struct();
    for grp = {'cum1', 'cum2'}
        fn = fieldnames(raw.(grp{1}));
        for i = 1:numel(fn)
            P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
        end
    end
    P.F_zf = P.m * P.g * P.l_r / (P.l_f + P.l_r);
    P.F_zr = P.m * P.g * P.l_f / (P.l_f + P.l_r);
end

function [Fyf, Fyr, af] = forces(P, z, v, mu)          % z = [beta; gamma; theta2]
    af = z(3) / P.n_st - z(1) - P.l_f * z(2) / v;
    ar = -z(1) + P.l_r * z(2) / v;
    Fyf = mf(P, af, mu * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, ar, mu * P.F_zr, P.C_r);
end

function T = Tr(P, z, v, mu)
    [Fyf, ~, af] = forces(P, z, v, mu);
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(af) * P.t_0 * P.C_alpha_f * tan(af) / (3 * mu * P.F_zf));
    T = e_p / P.n_st * Fyf;
end

function r = resAy(P, z, v, mu, ay)                     % steady state at a given lateral acceleration
    [Fyf, Fyr] = forces(P, z, v, mu);
    r = [(Fyf + Fyr) / (P.m * v) - z(2); P.l_f * Fyf - P.l_r * Fyr; (Fyf + Fyr) / P.m - ay];
end

function r = resHold(P, z, v, mu, th1)                  % steady state with theta1 held, T_a = 0
    [Fyf, Fyr] = forces(P, z, v, mu);
    r = [(Fyf + Fyr) / (P.m * v) - z(2); P.l_f * Fyf - P.l_r * Fyr; P.K * (th1 - z(3)) - Tr(P, z, v, mu)];
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end
