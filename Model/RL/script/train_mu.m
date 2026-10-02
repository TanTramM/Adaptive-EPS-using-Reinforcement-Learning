function train_mu(runName, ov)
%TRAIN_MU Step 1b of the experiment ladder (Documents/RL/DieuKhien_RL.txt section 2.4d): hold steering, mu drops during the episode.
%
%   train_mu('Bac1b_base')                            baseline: the current setup (gamma 0.999, absolute T_a, slow observation I)
%   train_mu('Bac1b_a_gamma099', struct('gamma', 0.99))
%   train_mu('Bac1b_c_noI', struct('I_off', true))
%
%   Why this test: with a fixed scenario (Bac1) a network can pass by remembering ONE constant T_a. Here the steering angle is held
%   (a_y target 0.25 g, 40 km/h, ramp 0.5 s) but mu drops from 0.8 to muAfter at a random time tMu in [1.5, 3] s; the torque T_a needed
%   to keep T_s = T_d,ref changes while the angle (and, at this a_y, almost a_y) does not, so only e_T tells the agent.
%   Training episodes (5 s): tMu uniform in [1.5, 3] s, muAfter uniform in [0.3, 0.8] with a HOLD-OUT band (0.42, 0.48) removed.
%   Ideal sensors (level none). After every ov.eval_every episodes (default 5) the policy alone (no exploration) plays two check
%   scenarios, tMu = 2 s: C1 muAfter 0.3 (inside the training range), C2 muAfter 0.45 (HOLD-OUT: never seen in training).
%   Metrics (true e_T, T_d,ref changes with a_y, so e_T is the right measure): mean e_T and mean T_a in the window before the drop
%   (1.5-2 s) and after it (4-5 s, 2 s after the drop).
%   PASS (written before the run): |mean e_T| below 0.1 N.m in both windows for C1 and C2, positive sensitivity (see below), and the
%   same at two consecutive checks. A policy with a constant T_a passes the "before" window only.
%   At the end, the sensitivity gain = dT_a/de_T of the final agent is measured on C1 (observation recorded at 1.8 s and 4.5 s, the
%   measured e_T entries shifted by +-0.5 N.m, total and history/I parts, as in diag_rl_agent.m); PID Kp = 16.48 for comparison.
%   Options (struct ov, all optional): gamma, I_off (rl_I_gain = 0), incremental (true: variant C, the agent outputs dT_a within +-rl_dTa_max
%   and T_a[k] = sat(T_a[k-1] + dT_a), model Model_RLinc_s; the sensitivity file then holds d(dT_a)/d(e_T) per agent step, to compare with
%   Ki*Ts = 0.27 of the PID), episodes (40), eval_every (5), seed (2).
%   Writes Result/RL/Bac1/<runName>/: RL_<runName>_progress_log.txt, _checks.csv, _episodes.csv, _traces.png, _sensitivity.csv, agent_ep<N>.mat.
%   Run first: load_rl.m (the base workspace parameters).

if nargin < 2, ov = struct(); end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script')); addpath(scriptDir);
cfg = jsondecode(fileread(fullfile(modelDir, 'data', 'rl.json')));
tr = cfg.train;
gammaUse = getOpt(ov, 'gamma', tr.gamma.value);
nEp = getOpt(ov, 'episodes', 40);
nEval = getOpt(ov, 'eval_every', 5);
rng(getOpt(ov, 'seed', 2));
tEnd = 5;

outDir = result_dir('RL', 'Bac1', runName);
fLog = fullfile(outDir, sprintf('RL_%s_progress_log.txt', runName));
fChk = fullfile(outDir, sprintf('RL_%s_checks.csv', runName));
fEp  = fullfile(outDir, sprintf('RL_%s_episodes.csv', runName));
fFig = fullfile(outDir, sprintf('RL_%s_traces.png', runName));
fSen = fullfile(outDir, sprintf('RL_%s_sensitivity.csv', runName));
for f = {fLog, fChk, fEp, fSen}
    if exist(f{1}, 'file'), delete(f{1}); end
end
writeText(fChk, sprintf('episodes_done,check,mean_eT_before,mean_eT_after,mean_Ta_before,mean_Ta_after,rms_eT_after,max_abs_Ta\n'), 'w');
writeText(fEp, sprintf('episode,reward,steps,wall_s\n'), 'w');

if getOpt(ov, 'incremental', false)
    assignin('base', 'rl_incremental', 1);
    cleanupInc = onCleanup(@() assignin('base', 'rl_incremental', 0)); %#ok<NASGU>
end
if getOpt(ov, 'I_off', false)
    iGain0 = evalin('base', 'rl_I_gain');
    assignin('base', 'rl_I_gain', 0);
    cleanupI = onCleanup(@() assignin('base', 'rl_I_gain', iGain0)); %#ok<NASGU>
end

T = rl_angle_table();
checks = {makeScenario(T, tEnd, 2, 0.3), makeScenario(T, tEnd, 2, 0.45)};
checkName = {'C1_mu0p3_seen_range', 'C2_mu0p45_holdout'};

[env, agent] = rl_env([], 'fixed');
agent.AgentOptions.DiscountFactor = gammaUse;
agent.AgentOptions.ResetExperienceBufferBeforeTraining = false;
env.ResetFcn = @(in) trainReset(in, T, tEnd);
assignin('base', 'rl_done_eT', 1e6);
nStep = round(tEnd / 0.001);
opts = rlTrainingOptions('MaxEpisodes', nEval, 'MaxStepsPerEpisode', nStep, 'Plots', 'none', 'Verbose', false, ...
    'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nEval);
logLine(fLog, 'Bac1b %s: %s, gamma %.4g, slow observation I %s, %d episodes of %d steps, check every %d episodes, seed %d; mu drop at tMu in [1.5, 3] s to muAfter in [0.3, 0.8] without (0.42, 0.48)', ...
    runName, ternary(getOpt(ov, 'incremental', false), 'INCREMENTAL action (variant C)', 'absolute action'), gammaUse, ternary(getOpt(ov, 'I_off', false), 'REMOVED', 'kept'), nEp, nStep, nEval, getOpt(ov, 'seed', 2));

traces = cell(0, 2);
[M, trc] = runChecks(agent, checks);
traces(end + 1, :) = trc; %#ok<AGROW>
writeChecks(fChk, 0, checkName, M);
logLine(fLog, 'untrained: %s', summary(checkName, M));

tStart = tic; done = 0; passCount = 0;
while done < nEp
    stats = train(agent, env, opts);
    r = stats.EpisodeReward(:); n = stats.EpisodeSteps(:);
    for e = 1:numel(r)
        writeText(fEp, sprintf('%d,%.6g,%d,%.1f\n', done + e, r(e), n(e), toc(tStart)), 'a');
    end
    done = done + numel(r);
    [M, trc] = runChecks(agent, checks);
    traces(end + 1, :) = trc; %#ok<AGROW>
    writeChecks(fChk, done, checkName, M);
    save(fullfile(outDir, sprintf('agent_ep%d.mat', done)), 'agent');
    ok = all(abs([M.eB, M.eA]) < 0.1);
    passCount = ternary(ok, passCount + 1, 0);
    logLine(fLog, 'episodes %d (%.0f s, %.2f ms/step): episode reward mean %.4g; %s%s', done, toc(tStart), 1e3 * toc(tStart) / (done * nStep), mean(r), ...
        summary(checkName, M), ternary(ok, sprintf('  [ALL |e_T| < 0.1; consecutive %d]', passCount), ''));
    plotTraces(fFig, traces, nEval, runName);
end
logLine(fLog, 'training end: %d episodes, %.1f min; consecutive passing checks at the end: %d (PASS needs 2 and positive sensitivity)', done, toc(tStart) / 60, passCount);

% ---- sensitivity of the final agent on C1 ----
try
    sensitivity(agent, checks{1}, fSen);
    logLine(fLog, 'sensitivity written to %s', fSen);
catch ME
    logLine(fLog, 'sensitivity ERROR: %s', ME.message);
end
end

function sc = makeScenario(T, tEnd, tMu, muAfter)
    t = (0:0.001:tEnd)';
    a = 0.25 * (1 - cos(pi * min(t / 0.5, 1))) / 2;
    sc.t = t;
    sc.theta1 = interp2(T.ay, T.v, T.th, min(a, T.ay(end)), 40 * ones(size(a)), 'linear');
    sc.v = 40 / 3.6 * ones(size(t));
    sc.mu = 0.8 - (0.8 - muAfter) * (t >= tMu);
    sc.tMu = tMu; sc.muAfter = muAfter;
end

function in = trainReset(in, T, tEnd)
    tMu = 1.5 + 1.5 * rand;
    muAfter = 0.3 + 0.5 * rand;
    while abs(muAfter - 0.45) < 0.03, muAfter = 0.3 + 0.5 * rand; end   % hold-out band (0.42, 0.48)
    sc = makeScenario(T, tEnd, tMu, muAfter);
    in = applyScenario(in, sc);
end

function in = applyScenario(in, sc)
    in = in.setVariable('sc_theta1', [sc.t sc.theta1]);
    in = in.setVariable('sc_v',      [sc.t sc.v]);
    in = in.setVariable('sc_mu',     [sc.t sc.mu]);
    in = in.setModelParameter('StopTime', sprintf('%.15g', sc.t(end)));
end

function [M, trc] = runChecks(agent, checks)
    assignin('base', 'rl_agent', agent);
    M = struct('eB', {}, 'eA', {}, 'taB', {}, 'taA', {}, 'rmsA', {}, 'maxTa', {});
    trc = cell(1, 2);
    for k = 1:numel(checks)
        sc = checks{k};
        in = Simulink.SimulationInput(rlModel());
        in = applyScenario(in, sc);
        in = in.setVariable('rl_use_agent', 1);
        so = sim(in);
        t = sc.t;
        eT = rs(so.get('log_e_T'), t, 'linear');
        Ta = rs(so.get('log_T_a'), t, 'previous');
        wB = t >= 1.5 & t < 2; wA = t >= 4;
        M(k).eB = mean(eT(wB)); M(k).eA = mean(eT(wA));
        M(k).taB = mean(Ta(wB)); M(k).taA = mean(Ta(wA));
        M(k).rmsA = sqrt(mean(eT(wA).^2)); M(k).maxTa = max(abs(Ta(t >= 1)));
        trc{k} = struct('t', t, 'eT', eT, 'Ta', Ta);
    end
end

function s = summary(names, M)
    parts = cell(1, numel(M));
    for k = 1:numel(M)
        parts{k} = sprintf('%s: e_T before %.3f after %.3f, T_a before %.3f after %.3f, max|T_a| %.2f', names{k}(1:2), M(k).eB, M(k).eA, M(k).taB, M(k).taA, M(k).maxTa);
    end
    s = strjoin(parts, ' | ');
end

function writeChecks(f, done, names, M)
    for k = 1:numel(M)
        writeText(f, sprintf('%d,%s,%.5f,%.5f,%.5f,%.5f,%.5f,%.4f\n', done, names{k}, M(k).eB, M(k).eA, M(k).taB, M(k).taA, M(k).rmsA, M(k).maxTa), 'a');
    end
end

function sensitivity(agent, sc, fSen)
    mdl = rlModel();
    gain = evalin('base', 'rl_obs_gain'); nHist = evalin('base', 'rl_n_hist'); Igain = evalin('base', 'rl_I_gain');
    nSig = numel(gain);
    rlSub = [mdl '/Model_RL/RL'];
    add_block('simulink/Sinks/To Workspace', [rlSub '/Tap_obs'], 'VariableName', 'tap_obs', 'SaveFormat', 'Structure With Time');
    add_line(rlSub, 'Cat_obs/1', 'Tap_obs/1');                % temporary tap on the observation
    assignin('base', 'rl_agent', agent);
    in = Simulink.SimulationInput(mdl);
    in = applyScenario(in, sc);
    in = in.setVariable('rl_use_agent', 1);
    so = sim(in);
    delete_line(rlSub, 'Cat_obs/1', 'Tap_obs/1');
    delete_block([rlSub '/Tap_obs']);
    tap = so.get('tap_obs');
    Ob = squeeze(tap.signals.values); if size(Ob, 1) ~= numel(tap.time), Ob = Ob'; end
    iE = 1 + nSig * (0:nHist - 1);                            % e_T entries of every history sample
    writeText(fSen, sprintf('t_s,action_Nm,gain_total,gain_history_only,gain_I_only\n'), 'w');
    for tq = [1.8 4.5]
        o = Ob(find(tap.time <= tq, 1, 'last'), :)';
        a0 = act(agent, o);
        op = o; op(iE) = op(iE) + 0.5 * gain(1); op(end) = op(end) + 0.5 * Igain;
        om = o; om(iE) = om(iE) - 0.5 * gain(1); om(end) = om(end) - 0.5 * Igain;
        oh = o; oh(iE) = oh(iE) + 0.5 * gain(1); ol = o; ol(iE) = ol(iE) - 0.5 * gain(1);
        gH = act(agent, oh) - act(agent, ol);
        oh = o; oh(end) = oh(end) + 0.5 * Igain; ol = o; ol(end) = ol(end) - 0.5 * Igain;
        gI = act(agent, oh) - act(agent, ol);
        writeText(fSen, sprintf('%g,%.4f,%.3f,%.3f,%.3f\n', tq, a0, act(agent, op) - act(agent, om), gH, gI), 'a');
    end
end

function a = act(agent, o)
    a = getAction(agent, {o});
    a = double(a{1});
end

function y = rs(ts, t, method)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), t, method, 'extrap');
end

function plotTraces(f, traces, nEval, runName)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 800]);
    col = parula(size(traces, 1) + 1);
    names = {'C1 mu 0.8 -> 0.3 at 2 s', 'C2 mu 0.8 -> 0.45 at 2 s (hold-out)'};
    for c = 1:2
        subplot(2, 2, c); hold on;
        for k = 1:size(traces, 1), plot(traces{k, c}.t, traces{k, c}.eT, 'Color', col(k, :)); end
        grid on; ylabel('e_T (true) [N.m]'); title(names{c});
        subplot(2, 2, 2 + c); hold on;
        for k = 1:size(traces, 1), plot(traces{k, c}.t, traces{k, c}.Ta, 'Color', col(k, :)); end
        grid on; ylabel('T_a [N.m]'); xlabel('t [s]');
    end
    sgtitle(sprintf('%s: policy after 0, %d, %d ... episodes (dark to light)', strrep(runName, '_', '\_'), nEval, 2 * nEval));
    exportgraphics(fig, f, 'Resolution', 120); close(fig);
end

function v = getOpt(ov, name, default)
    if isfield(ov, name), v = ov.(name); else, v = default; end
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end

function writeText(f, s, mode)
    fid = fopen(f, mode);
    fprintf(fid, '%s', s);
    fclose(fid);
end

function logLine(f, fmt, varargin)
    s = sprintf(['[%s] ' fmt], datestr(now, 'yyyy-mm-dd HH:MM:SS'), varargin{:}); %#ok<TNOW1,DATST>
    fid = fopen(f, 'a');
    fprintf(fid, '%s\n', s);
    fclose(fid);
    fprintf('%s\n', s);
end

function m = rlModel()
    if evalin('base', 'exist(''rl_incremental'', ''var'') && rl_incremental == 1'), m = 'Model_RLinc_s'; else, m = 'Model_RL_s'; end
end
