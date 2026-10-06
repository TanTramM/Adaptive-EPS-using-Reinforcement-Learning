function T = analyze_pi_windows(seed, wcSens)
%ANALYZE_PI_WINDOWS Error of the PI and of the Map in every scored window of the case TK (where does R come from).
%
%   T = analyze_pi_windows()               seed 91001, sensor level 'high', sensitivity check at wc = 6 rad/s
%   T = analyze_pi_windows(seed, wcSens)
%
%   Runs on TK (Documents/Map_6_8/map.txt section 2.5), all with the sensors at level 'high':
%     1. the PI of data/pi_2k.json (the design chosen by run_pi_sweep.m);
%     2. the PI of the design grid at wcSens with the smallest a (a = 0.1, the one of the sweep);
%     3. the same crossover with the proportional part raised to the largest value that still meets PM >= 45 deg and GM >= 2 on both plants
%        (a = a_max_feasible of Result/PI_2K/Design/PI_design_grid.csv): rows 2 and 3 show how little R depends on Kp;
%     4. the Map in its final form (data/map.json).
%   For every window: RMS e_T, mean e_T and RMS T_d,ref on the TRUE signals. Writes Result/PI_2K/Sweep/PI_TK_window_errors.csv.
%   Run first: load_pi_2k.m, load_map_6_8.m.

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script'));
if nargin < 1, seed = 91001; end
if nargin < 2, wcSens = 6; end
S = test_cases('TK');
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
D = readtable(fullfile(result_dir('PI_2K', 'Design'), 'PI_design_grid.csv'));
r = D(abs(D.wc_design_rad_s - wcSens) < 1e-9, :);
Ts = 0.001;
p = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(p.(grp{1}));
    for i = 1:numel(fn), P.(fn{i}) = p.(grp{1}).(fn{i}).value; end
end
wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;
kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
G1 = c2d(tf(P.K, [P.J_col, P.C_col, P.K + kr]) * tf(wm, [1 wm]), Ts, 'zoh');
g1 = abs(squeeze(freqresp(G1, wcSens))); z = exp(1j * wcSens * Ts);
Ti3 = r.a_max_feasible * 1 / wcSens; Kp3 = 1 / (g1 * abs(1 + (Ts / Ti3) / (z - 1)));
Kp1 = raw.Kp.value; Ki1 = raw.Ki.value;
cfg = {sprintf('PI of pid.json (wc %g rad/s: Kp %.3g, Ki %.3g)', raw.design.wc_design_rad_s, Kp1, Ki1), 'Model_PI_2K_s', struct('Kp', Kp1, 'Ki', Ki1, 'Kaw', Ki1 / Kp1); ...
       sprintf('PI wc %g rad/s, a = %.3g (Kp %.3g, Ki %.3g)', wcSens, r.a_wcTi, r.Kp, r.Ki_1_per_s), 'Model_PI_2K_s', struct('Kp', r.Kp, 'Ki', r.Ki_1_per_s, 'Kaw', r.Ki_1_per_s / r.Kp); ...
       sprintf('PI wc %g rad/s, a = %.3g (Kp %.3g, Ki %.3g)', wcSens, r.a_max_feasible, Kp3, Kp3 / Ti3), 'Model_PI_2K_s', struct('Kp', Kp3, 'Ki', Kp3 / Ti3, 'Kaw', 1 / Ti3); ...
       'Map (final)', 'Model_Map_6_8_s', struct()};
rows = {};
for k = 1:size(cfg, 1)
    mdl = cfg{k, 2};
    if ~bdIsLoaded(mdl), load_system(fullfile(modelDir, [mdl '.mdl'])); end
    assignin('base', 'sc_theta1', [S.t S.theta1]); assignin('base', 'sc_v', [S.t S.v]); assignin('base', 'sc_mu', [S.t S.mu]);
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    V = sensor_noise_vars('high', seed); fn = fieldnames(V);
    for q = 1:numel(fn), in = in.setVariable(fn{q}, V.(fn{q})); end
    v2 = cfg{k, 3}; fn = fieldnames(v2);
    for q = 1:numel(fn), in = in.setVariable(fn{q}, v2.(fn{q})); end
    so = sim(in);
    eT = rs(so.get('log_e_T'), S.t); Td = rs(so.get('log_T_d_ref'), S.t);
    inResp = false(size(S.t));
    for j = 1:numel(S.win)
        w = S.t >= S.win(j).t0 & S.t <= S.win(j).t1; inResp = inResp | w;
        rows(end + 1, :) = {cfg{k, 1}, S.win(j).label, sqrt(mean(eT(w).^2)), mean(eT(w)), sqrt(mean(Td(w).^2))}; %#ok<AGROW>
    end
    rows(end + 1, :) = {cfg{k, 1}, 'R (all windows)', sqrt(mean(eT(inResp).^2)), NaN, NaN}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'controller', 'window', 'RMS_eT_Nm', 'mean_eT_Nm', 'RMS_Tdref_Nm'});
writetable(T, fullfile(result_dir('PI_2K', 'Sweep'), 'PI_TK_window_errors.csv'));
evalin('base', 'clear sc_theta1 sc_v sc_mu');
fprintf('analyze_pi_windows: wrote Result/PI_2K/Sweep/PI_TK_window_errors.csv\n');
end

function y = rs(ts, t)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), t, 'linear', 'extrap');
end
