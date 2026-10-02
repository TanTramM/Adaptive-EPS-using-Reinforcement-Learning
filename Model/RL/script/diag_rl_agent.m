function diag_rl_agent(runName, agentFiles)
%DIAG_RL_AGENT Diagnostic of saved agents on the HOLD validation episodes (Documents/RL/DieuKhien_RL.txt section 2.4b).
%
%   diag_rl_agent('Train2', {'agent_stage1_best', 'agent_stage1_last'})
%
%   Question checked: does the agent UNDER-assist (smooth T_a that stays below the needed level, steady e_T that is never removed)?
%   For every agent file, and for Map and PID as reference, on validation episodes V(1) and V(3) (hold steering, mu drop at 5 s,
%   sensor level 'high', same seeds as the validation in train_rl.m):
%     1. time response T_a, T_s vs T_d_ref, e_T (true signals), one figure per episode;
%     2. window means before (3-5 s) and after (8-10 s) the mu drop: mean T_a, mean e_T;
%     3. local sensitivity of the policy to the error: the observation is recorded at t = 4 s and 9 s, the MEASURED e_T entries
%        (every history sample and the slow observation I) are shifted by +-0.5 N.m and the change of the action is read:
%        gain = dT_a / de_T [N.m per N.m], also split into the history part and the I part. For comparison, PID has Kp = 16.48 (plus the integral that removes the steady error).
%   Writes Result/RL/<runName>/Diagnostics/: RL_<runName>_diag_<episode>.png, RL_<runName>_diag_windows.csv,
%   RL_<runName>_diag_sensitivity.csv. Run first: load_map.m, load_pid.m, load_rl.m.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script'));
runDir = result_dir('RL', runName);
outDir = result_dir('RL', runName, 'Diagnostics');
V = rl_validation_scenarios();
V = V([1 3]);
gain = evalin('base', 'rl_obs_gain'); nHist = evalin('base', 'rl_n_hist'); Igain = evalin('base', 'rl_I_gain');
nSig = numel(gain);

rl_env();                                              % creates rl_agent so the RL model compiles
mdl = 'Model_RL_s';
if ~bdIsLoaded(mdl), load_system(fullfile(modelDir, [mdl '.mdl'])); end
rlSub = [mdl '/Model_RL/RL'];
add_block('simulink/Sinks/To Workspace', [rlSub '/Tap_obs'], 'VariableName', 'tap_obs', 'SaveFormat', 'Structure With Time');
add_line(rlSub, 'Cat_obs/1', 'Tap_obs/1');             % temporary tap on the observation (model closed without saving)
cleanup = onCleanup(@() close_system(mdl, 0));

names = [{'Map', 'PID'}, agentFiles];
win = {'before_3_5s', [3 5]; 'after_8_10s', [8 10]};
fW = fopen(fullfile(outDir, sprintf('RL_%s_diag_windows.csv', runName)), 'w');
fprintf(fW, 'episode,controller,window,mean_Ta_Nm,mean_eT_Nm,rms_eT_Nm,mean_Ts_Nm,mean_Td_ref_Nm\n');
fS = fopen(fullfile(outDir, sprintf('RL_%s_diag_sensitivity.csv', runName)), 'w');
fprintf(fS, 'episode,agent,t_s,action_Nm,action_eT_plus0p5_Nm,action_eT_minus0p5_Nm,gain_dTa_deT,gain_history_only,gain_I_only\n');

for k = 1:numel(V)
    R = struct();
    for c = 1:numel(names)
        nm = names{c};
        if any(strcmp(nm, {'Map', 'PID'}))
            [R(c).t, R(c).Ta, R(c).Ts, R(c).Td, R(c).eT] = runOne(['Model_' nm '_s'], V(k), struct());
        else
            S = load(fullfile(runDir, 'agents', [nm '.mat']), 'agent');
            assignin('base', 'rl_agent', S.agent);
            [R(c).t, R(c).Ta, R(c).Ts, R(c).Td, R(c).eT, so] = runOne(mdl, V(k), struct('rl_use_agent', 1, 'rl_done_eT', 1e6));
            tap = so.get('tap_obs');
            Ob = squeeze(tap.signals.values); if size(Ob, 1) ~= numel(tap.time), Ob = Ob'; end
            iE = 1 + nSig * (0:nHist - 1);                % e_T entries of every history sample
            for tq = [4 9]
                o = Ob(find(tap.time <= tq, 1, 'last'), :)';
                a0 = act(S.agent, o);
                op = o; op(iE) = op(iE) + 0.5 * gain(1); op(end) = op(end) + 0.5 * Igain;
                om = o; om(iE) = om(iE) - 0.5 * gain(1); om(end) = om(end) - 0.5 * Igain;
                ap = act(S.agent, op); am = act(S.agent, om);
                oh = o; oh(iE) = oh(iE) + 0.5 * gain(1); ol = o; ol(iE) = ol(iE) - 0.5 * gain(1);   % history samples only
                gH = act(S.agent, oh) - act(S.agent, ol);
                oh = o; oh(end) = oh(end) + 0.5 * Igain; ol = o; ol(end) = ol(end) - 0.5 * Igain;   % slow observation I only
                gI = act(S.agent, oh) - act(S.agent, ol);
                fprintf(fS, '%s,%s,%g,%.4f,%.4f,%.4f,%.3f,%.3f,%.3f\n', V(k).name, nm, tq, a0, ap, am, ap - am, gH, gI);
            end
        end
        for w = 1:size(win, 1)
            u = R(c).t >= win{w, 2}(1) & R(c).t <= win{w, 2}(2);
            fprintf(fW, '%s,%s,%s,%.4f,%.4f,%.4f,%.4f,%.4f\n', V(k).name, nm, win{w, 1}, mean(R(c).Ta(u)), mean(R(c).eT(u)), ...
                sqrt(mean(R(c).eT(u).^2)), mean(R(c).Ts(u)), mean(R(c).Td(u)));
        end
    end
    plotEpisode(fullfile(outDir, sprintf('RL_%s_diag_%s.png', runName, V(k).name)), R, names, V(k).name);
end
fclose(fW); fclose(fS);
fprintf('diag_rl_agent: results in %s\n', outDir);
end

function a = act(agent, o)
    a = getAction(agent, {o});
    a = double(a{1});
end

function [t, Ta, Ts, Td, eT, so] = runOne(mdl, Vk, extra)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('sc_theta1', [Vk.sc.t Vk.sc.theta1]);
    in = in.setVariable('sc_v', [Vk.sc.t Vk.sc.v]);
    in = in.setVariable('sc_mu', [Vk.sc.t Vk.sc.mu]);
    in = in.setModelParameter('StopTime', sprintf('%.15g', Vk.sc.t(end)));
    S = sensor_noise_vars('high', Vk.seed);
    fn = fieldnames(S);
    for i = 1:numel(fn), in = in.setVariable(fn{i}, S.(fn{i})); end
    fn = fieldnames(extra);
    for i = 1:numel(fn), in = in.setVariable(fn{i}, extra.(fn{i})); end
    so = sim(in);
    t = (0:1e-3:Vk.sc.t(end))';
    Ta = rs(so.get('log_T_a'), t, 'previous');
    Ts = rs(so.get('log_T_s'), t, 'linear');
    Td = rs(so.get('log_T_d_ref'), t, 'linear');
    eT = rs(so.get('log_e_T'), t, 'linear');
end

function y = rs(ts, t, method)
    y = interp1(ts.Time, squeeze(ts.Data), t, method, 'extrap');
end

function plotEpisode(f, R, names, ttl)
    fig = figure('Visible', 'off', 'Position', [100 100 1100 850]);
    col = lines(numel(names));
    subplot(3, 1, 1); hold on;
    for c = 1:numel(names), plot(R(c).t, R(c).Ta, 'Color', col(c, :)); end
    grid on; ylabel('T_a [N.m]'); title(strrep(ttl, '_', '\_')); legend(strrep(names, '_', '\_'), 'Location', 'best');
    subplot(3, 1, 2); hold on;
    for c = 1:numel(names), plot(R(c).t, R(c).Ts, 'Color', col(c, :)); end
    plot(R(2).t, R(2).Td, 'k--'); grid on; ylabel('T_s, T_{d,ref} (dashed) [N.m]');
    subplot(3, 1, 3); hold on;
    for c = 1:numel(names), plot(R(c).t, R(c).eT, 'Color', col(c, :)); end
    grid on; ylabel('e_T [N.m]'); xlabel('t [s]');
    exportgraphics(fig, f, 'Resolution', 120); close(fig);
end
