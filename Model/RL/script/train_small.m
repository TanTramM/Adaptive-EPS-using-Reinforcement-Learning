function train_small(runName, ov)
%TRAIN_SMALL Step 1 of the experiment ladder (Documents/RL/DieuKhien_RL.txt section 2.4d): the smallest problem, static error on a hold.
%
%   train_small('Bac1_base')                          baseline: the current setup (gamma 0.999, absolute T_a, slow observation I)
%   train_small('Bac1_a_gamma099', struct('gamma', 0.99))
%   train_small('Bac1_c_noI', struct('I_off', true))
%
%   ONE fixed scenario (hold steering for a_y = 0.2 g at 40 km/h, dry road all the time, steering ramps up in 0.5 s), ideal sensors
%   (level none), episodes of 4 s. After every ov.eval_every episodes the policy is played alone on the same scenario (no exploration)
%   and the true e_T is summarized in three windows (1-2 s, 2-3 s, 3-4 s: a drift shows as a change between windows). T_d,ref = 2.0 N.m.
%   PASS: |mean e_T| in 3-4 s below 0.1 N.m (Map 0.001, PID 0.012) and stable over the last checks.
%   Options (struct ov, all optional): gamma (discount; default from data/rl.json), I_off (set rl_I_gain = 0: the slow observation is
%   removed), episodes (30), eval_every (5), seed (2).
%   Writes Result/RL/Bac1/<runName>/: RL_<runName>_progress_log.txt, _checks.csv, _episodes.csv, _traces.png, agent_last.mat.
%   Run first: load_rl.m (the base workspace parameters).

if nargin < 2, ov = struct(); end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script')); addpath(scriptDir);
cfg = jsondecode(fileread(fullfile(modelDir, 'data', 'rl.json')));
tr = cfg.train;
gammaUse = getOpt(ov, 'gamma', tr.gamma.value);
nEp = getOpt(ov, 'episodes', 30);
nEval = getOpt(ov, 'eval_every', 5);
rng(getOpt(ov, 'seed', 2));

outDir = result_dir('RL', 'Bac1', runName);
fLog = fullfile(outDir, sprintf('RL_%s_progress_log.txt', runName));
fChk = fullfile(outDir, sprintf('RL_%s_checks.csv', runName));
fEp  = fullfile(outDir, sprintf('RL_%s_episodes.csv', runName));
fFig = fullfile(outDir, sprintf('RL_%s_traces.png', runName));
for f = {fLog, fChk, fEp}
    if exist(f{1}, 'file'), delete(f{1}); end
end
writeText(fChk, sprintf('episodes_done,mean_eT_1_2s,mean_eT_2_3s,mean_eT_3_4s,rms_eT_3_4s,mean_Ta_3_4s,max_abs_Ta,tv_Ta_Nm_per_s\n'), 'w');
writeText(fEp, sprintf('episode,reward,steps,wall_s\n'), 'w');

if getOpt(ov, 'I_off', false)
    iGain0 = evalin('base', 'rl_I_gain');
    assignin('base', 'rl_I_gain', 0);
    cleanupI = onCleanup(@() assignin('base', 'rl_I_gain', iGain0)); %#ok<NASGU>
end

% ---- scenario: hold 0.2 g at 40 km/h on the dry road ----
T = rl_angle_table();
t = (0:0.001:4)';
a = 0.2 * (1 - cos(pi * min(t / 0.5, 1))) / 2;
sc.t = t;
sc.theta1 = interp2(T.ay, T.v, T.th, min(a, T.ay(end)), 40 * ones(size(a)), 'linear');
sc.v = 40 / 3.6 * ones(size(t));
sc.mu = 0.8 * ones(size(t));

[env, agent] = rl_env([], 'fixed');
agent.AgentOptions.DiscountFactor = gammaUse;
agent.AgentOptions.ResetExperienceBufferBeforeTraining = false;
env.ResetFcn = @(in) applyScenario(in, sc);
assignin('base', 'rl_done_eT', 1e6);
opts = rlTrainingOptions('MaxEpisodes', nEval, 'MaxStepsPerEpisode', numel(t) - 1, 'Plots', 'none', 'Verbose', false, ...
    'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nEval);
logLine(fLog, 'Bac1 %s: gamma %.4g, slow observation I %s, %d episodes of %d steps, check every %d episodes, seed %d', runName, gammaUse, ...
    ternary(getOpt(ov, 'I_off', false), 'REMOVED', 'kept'), nEp, numel(t) - 1, nEval, getOpt(ov, 'seed', 2));

traces = {};
[m, tr0] = check(agent, sc);
traces{end + 1} = tr0; %#ok<AGROW>
writeCheck(fChk, 0, m);
logLine(fLog, 'untrained: mean e_T (1-2, 2-3, 3-4 s) %.3f, %.3f, %.3f N.m, RMS e_T 3-4 s %.3f, mean T_a %.3f N.m', m.w1, m.w2, m.w3, m.rms3, m.meanTa3);

tStart = tic; done = 0;
while done < nEp
    stats = train(agent, env, opts);
    r = stats.EpisodeReward(:); n = stats.EpisodeSteps(:);
    for e = 1:numel(r)
        writeText(fEp, sprintf('%d,%.6g,%d,%.1f\n', done + e, r(e), n(e), toc(tStart)), 'a');
    end
    done = done + numel(r);
    [m, trc] = check(agent, sc);
    traces{end + 1} = trc; %#ok<AGROW>
    writeCheck(fChk, done, m);
    save(fullfile(outDir, 'agent_last.mat'), 'agent');
    logLine(fLog, 'episodes %d (%.0f s, %.2f ms/step): episode reward mean %.4g; mean e_T (1-2, 2-3, 3-4 s) %.3f, %.3f, %.3f N.m, RMS e_T 3-4 s %.3f, mean T_a %.3f N.m, max|T_a| %.2f%s', ...
        done, toc(tStart), 1e3 * toc(tStart) / (done * (numel(t) - 1)), mean(r), m.w1, m.w2, m.w3, m.rms3, m.meanTa3, m.maxTa, ...
        ternary(abs(m.w3) < 0.1, '  [|e_T| < 0.1: pass level]', ''));
    plotTraces(fFig, traces, nEval, runName);
end
logLine(fLog, 'end: %d episodes, %.1f min; last mean e_T 3-4 s %.3f N.m (%s)', done, toc(tStart) / 60, m.w3, ternary(abs(m.w3) < 0.1, 'PASS', 'NOT passed'));
end

function [m, trc] = check(agent, sc)
    assignin('base', 'rl_agent', agent);
    in = Simulink.SimulationInput('Model_RL_s');
    in = applyScenario(in, sc);
    in = in.setVariable('rl_use_agent', 1);
    so = sim(in);
    t = sc.t;
    eT = rs(so.get('log_e_T'), t, 'linear');
    Ta = rs(so.get('log_T_a'), t, 'previous');
    m.w1 = mean(eT(t >= 1 & t < 2)); m.w2 = mean(eT(t >= 2 & t < 3)); m.w3 = mean(eT(t >= 3));
    m.rms3 = sqrt(mean(eT(t >= 3).^2)); m.meanTa3 = mean(Ta(t >= 3)); m.maxTa = max(abs(Ta(t >= 1)));
    m.tv = sum(abs(diff(Ta(t >= 1)))) / (t(end) - 1);
    trc.t = t; trc.eT = eT; trc.Ta = Ta;
end

function y = rs(ts, t, method)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), t, method, 'extrap');
end

function in = applyScenario(in, sc)
    in = in.setVariable('sc_theta1', [sc.t sc.theta1]);
    in = in.setVariable('sc_v',      [sc.t sc.v]);
    in = in.setVariable('sc_mu',     [sc.t sc.mu]);
    in = in.setModelParameter('StopTime', sprintf('%.15g', sc.t(end)));
end

function writeCheck(f, done, m)
    writeText(f, sprintf('%d,%.5f,%.5f,%.5f,%.5f,%.5f,%.4f,%.2f\n', done, m.w1, m.w2, m.w3, m.rms3, m.meanTa3, m.maxTa, m.tv), 'a');
end

function plotTraces(f, traces, nEval, runName)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 700]);
    col = parula(numel(traces) + 1);
    subplot(2, 1, 1); hold on;
    for k = 1:numel(traces), plot(traces{k}.t, traces{k}.eT, 'Color', col(k, :)); end
    grid on; ylabel('e_T (true) [N.m]');
    title(sprintf('%s: e_T of the policy after 0, %d, %d ... episodes (dark to light)', strrep(runName, '_', '\_'), nEval, 2 * nEval));
    subplot(2, 1, 2); hold on;
    for k = 1:numel(traces), plot(traces{k}.t, traces{k}.Ta, 'Color', col(k, :)); end
    grid on; ylabel('T_a [N.m]'); xlabel('t [s]');
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
