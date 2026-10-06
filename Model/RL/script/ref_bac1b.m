function ref_bac1b(agentRuns)
%REF_BAC1B Reference of Map and PID on the two check scenarios of step 1b (Documents/RL/DieuKhien_RL.txt section 2.4d).
%
%   ref_bac1b()                                            Map and PID only
%   ref_bac1b({'Bac1b_base', 'Bac1b_a_gamma099'})          plus the agent after 40 episodes of these step-1b runs
%
%   Same check scenarios as train_mu.m: hold steering for a_y = 0.25 g at 40 km/h (ramp 0.5 s), mu 0.8 -> 0.3 (C1) or 0.45 (C2)
%   at 2 s, 5 s long. Sensor levels 'none' and 'high' (the two levels kept by the user on 2026-10-02; 'low' is no longer used),
%   seed 80001 for 'high' (validation range). Questions answered:
%     1. transient 0-0.5 s: peak |e_T| and time at the T_a,max limit (is the agent's 2.7 N.m peak set by the limit?);
%     2. windows before (1.5-2 s) and after (4-5 s) the mu drop: mean e_T and mean T_a (over-assist of the Map after the drop);
%     3. smoothness and bang-bang indicators from 1 s: TV(T_a), std of T_a, share of samples with |T_a| >= 95% of T_a,max,
%        share of 1 ms steps with |dT_a| > 1 N.m, 99th percentile of |dT_a| per step.
%   Writes Result/RL/Bac1/Reference/: RL_Bac1b_reference_metrics.csv, RL_Bac1b_reference_<check>_<level>.png.
%   Run first: load_map_6_8.m, load_pid.m, load_rl.m.

if nargin < 1, agentRuns = {}; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script')); addpath(scriptDir);
outDir = result_dir('RL', 'Bac1', 'Reference');
T = rl_angle_table();
checks = {makeScenario(T, 5, 2, 0.3), makeScenario(T, 5, 2, 0.45)};
checkName = {'C1_mu0p3', 'C2_mu0p45'};
levels = {'none', 'high'};
TaLim = interp1(evalin('base', 'Tamax_v_bp_ms'), evalin('base', 'Tamax_table'), 40 / 3.6);

ctrl = [{'Map_6_8', 'PID'}, agentRuns];
fM = fopen(fullfile(outDir, 'RL_Bac1b_reference_metrics.csv'), 'w');
fprintf(fM, 'check,level,controller,peak_abs_eT_0_1s,time_at_limit_0_1s,mean_eT_before,mean_eT_after,mean_Ta_before,mean_Ta_after,tv_Ta_Nm_per_s,std_Ta_after1s,frac_near_limit_after1s,frac_jump_over1Nm_after1s,p99_abs_dTa_after1s\n');
needRL = ~isempty(agentRuns);
if needRL
    rl_env();                                                   % creates rl_agent so the RL model compiles
end
for c = 1:numel(checks)
    for l = 1:numel(levels)
        R = struct('t', {}, 'eT', {}, 'Ta', {});
        for k = 1:numel(ctrl)
            if any(strcmp(ctrl{k}, {'Map_6_8', 'PID'}))
                mdl = ['Model_' ctrl{k} '_s']; extra = struct();
            else
                S = load(fullfile(result_dir('RL', 'Bac1', ctrl{k}), 'agent_ep40.mat'), 'agent');
                assignin('base', 'rl_agent', S.agent);
                mdl = 'Model_RL_s'; extra = struct('rl_use_agent', 1, 'rl_done_eT', 1e6);
            end
            [t, eT, Ta] = runOne(mdl, checks{c}, levels{l}, extra);
            R(k).t = t; R(k).eT = eT; R(k).Ta = Ta;
            w0 = t < 1; wB = t >= 1.5 & t < 2; wA = t >= 4;
            w1 = t >= 1; dTa = abs(diff(Ta(w1)));                 % bang-bang indicators after the steering ramp
            fprintf(fM, '%s,%s,%s,%.4f,%.4f,%.5f,%.5f,%.5f,%.5f,%.2f,%.4f,%.4f,%.4f,%.4f\n', checkName{c}, levels{l}, ctrl{k}, max(abs(eT(w0))), ...
                0.001 * sum(abs(Ta(w0)) >= TaLim - 1e-6), mean(eT(wB)), mean(eT(wA)), mean(Ta(wB)), mean(Ta(wA)), ...
                sum(dTa) / (t(end) - 1), std(Ta(w1)), mean(abs(Ta(w1)) >= 0.95 * TaLim), mean(dTa > 1), prctile(dTa, 99));
        end
        plotOne(fullfile(outDir, sprintf('RL_Bac1b_reference_%s_%s.png', checkName{c}, levels{l})), R, ctrl, ...
            sprintf('%s, sensors %s', checkName{c}, levels{l}), TaLim);
    end
end
fclose(fM);
fprintf('ref_bac1b: results in %s\n', outDir);
end

function sc = makeScenario(T, tEnd, tMu, muAfter)   % same as train_mu.m
    t = (0:0.001:tEnd)';
    a = 0.25 * (1 - cos(pi * min(t / 0.5, 1))) / 2;
    sc.t = t;
    sc.theta1 = interp2(T.ay, T.v, T.th, min(a, T.ay(end)), 40 * ones(size(a)), 'linear');
    sc.v = 40 / 3.6 * ones(size(t));
    sc.mu = 0.8 - (0.8 - muAfter) * (t >= tMu);
end

function [t, eT, Ta] = runOne(mdl, sc, level, extra)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('sc_theta1', [sc.t sc.theta1]);
    in = in.setVariable('sc_v', [sc.t sc.v]);
    in = in.setVariable('sc_mu', [sc.t sc.mu]);
    in = in.setModelParameter('StopTime', sprintf('%.15g', sc.t(end)));
    V = sensor_noise_vars(level, 80001);
    fn = fieldnames(V);
    for i = 1:numel(fn), in = in.setVariable(fn{i}, V.(fn{i})); end
    fn = fieldnames(extra);
    for i = 1:numel(fn), in = in.setVariable(fn{i}, extra.(fn{i})); end
    so = sim(in);
    t = sc.t;
    eT = rs(so.get('log_e_T'), t, 'linear');
    Ta = rs(so.get('log_T_a'), t, 'previous');
end

function y = rs(ts, t, method)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), t, method, 'extrap');
end

function plotOne(f, R, names, ttl, TaLim)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 700]);
    col = lines(numel(names));
    subplot(2, 1, 1); hold on;
    for k = 1:numel(names), plot(R(k).t, R(k).eT, 'Color', col(k, :)); end
    grid on; ylabel('e_T (true) [N.m]'); title(strrep(ttl, '_', '\_')); legend(strrep(names, '_', '\_'), 'Location', 'best');
    subplot(2, 1, 2); hold on;
    for k = 1:numel(names), plot(R(k).t, R(k).Ta, 'Color', col(k, :)); end
    yline(TaLim, 'k--'); grid on; ylabel('T_a [N.m] (dashed: T_{a,max})'); xlabel('t [s]');
    exportgraphics(fig, f, 'Resolution', 120); close(fig);
end
