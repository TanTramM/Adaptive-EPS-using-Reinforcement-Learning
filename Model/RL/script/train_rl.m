function train_rl(runName, ov)
%TRAIN_RL Train the pure RL assist controller in chunks, writing every result to Result/RL/<runName> as it goes.
%
%   train_rl()            run 'Train2'
%   train_rl('Train2')
%   train_rl('Smoke', struct('max_steps', 4000, 'chunk_episodes', 1, 'steps_per_episode', 2000))   quick check of the loop
%
%   Documents/RL/DieuKhien_RL.txt, section 2.4a. Run first: run('<Model>/load_map_6_8.m'), run('<Model>/load_pid.m'),
%   run('<Model>/load_rl.m') (Map and PID give the reference on the validation episodes).
%   Loop (until the step or wall-clock budget of data/rl.json "train" is used):
%     1. train(agent, env) for chunk_episodes episodes; random training scenario and sensor seed each episode (rl_env 'train');
%        the experience buffer is kept between chunks;
%     2. run the two fixed validation episodes (rl_validation_scenarios) with the current policy (no exploration);
%     3. append to the files below and save the agents (last, and best by validation cost).
%   Curriculum (data/rl.json train.curriculum_stage1_episodes, ..._stage2_episodes): the training scenarios get harder with the
%   episodes done (stage 1 dry road, stage 2 mild friction changes, stage 3 full range; rl_scenario_random.m). The stage is passed
%   to the reset function through the base variable rl_stage, set before every chunk.
%   Validation cost per episode = mean over 1 ms samples (t >= 1 s) of (e_T/T_ref)^2 + w1*(dT_a)^2, i.e. minus the mean step
%   reward, computed on the TRUE e_T; it is reported as its two parts, tracking (e_T/T_ref)^2 and smoothness w1*(dT_a)^2, because
%   the Train1 diagnosis needed that split; RMS e_T and TV(T_a) are reported too. Map and PID are run once on the same episodes.
%   Files (all in Result/RL/<runName>/, written after EVERY chunk so a crash or a lost chat loses at most one chunk):
%     RL_<run>_progress_log.txt     human-readable log, one line per event
%     RL_<run>_episodes.csv         episode, chunk, reward, steps, wall_s, scenario seed info is not available from train()
%     RL_<run>_validation.csv       episode count, controller, validation episode, cost, RMS e_T, TV(T_a), max|T_a|, tracking part, smoothness part
%     RL_<run>_learning_curve.png   episode reward and validation cost vs episodes (Map and PID as reference lines)
%     agents/agent_last.mat, agents/agent_best.mat  (variable 'agent')

if nargin < 1, runName = 'Train2'; end
if nargin < 2, ov = struct(); end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir);
cfg = jsondecode(fileread(fullfile(modelDir, 'data', 'rl.json')));
tr = cfg.train;
for f = fieldnames(ov)'
    if isfield(tr, f{1}), tr.(f{1}).value = ov.(f{1}); end
end
outDir = result_dir('RL', runName);
agentDir = fullfile(outDir, 'agents');
if ~exist(agentDir, 'dir'), mkdir(agentDir); end
fLog = fullfile(outDir, sprintf('RL_%s_progress_log.txt', runName));
fEp  = fullfile(outDir, sprintf('RL_%s_episodes.csv', runName));
fVal = fullfile(outDir, sprintf('RL_%s_validation.csv', runName));
fFig = fullfile(outDir, sprintf('RL_%s_learning_curve.png', runName));
writeText(fEp,  'episode,chunk,reward,steps,wall_s\n', 'w');
writeText(fVal, 'episodes_done,controller,validation,cost,rms_eT_Nm,tv_Ta_Nm_per_s,max_abs_Ta_Nm,cost_track,cost_smooth\n', 'w');
writeText(fLog, '', 'w');
logLine(fLog, 'start %s: gamma %g, reward T_ref %g w1 %g w2 %g, episode %g s, budget %g h / %g steps, chunk %d episodes', runName, ...
    tr.gamma.value, cfg.reward.T_ref.value, cfg.reward.w1.value, cfg.reward.w2.value, cfg.episode_s.value, tr.max_hours.value, ...
    tr.max_steps.value, tr.chunk_episodes.value);

rng(tr.rng_seed.value);
T_ref = cfg.reward.T_ref.value; w1 = cfg.reward.w1.value;
V = rl_validation_scenarios();

% ---- reference: Map and PID on the validation episodes ----
ref = struct('Map_6_8', [], 'PID', []);
for c = {'Map_6_8', 'PID'}
    for k = 1:numel(V)
        m = runValidation(['Model_' c{1} '_s'], V(k), T_ref, w1, struct());
        ref.(c{1})(k) = m.cost;
        writeText(fVal, sprintf('0,%s,%s,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n', c{1}, V(k).name, m.cost, m.rms, m.tv, m.maxTa, m.track, m.jerk), 'a');
        logLine(fLog, 'reference %s on %s: cost %.4g (tracking %.3g + smoothness %.3g), RMS e_T %.4f N.m, TV(T_a) %.1f N.m/s, max|T_a| %.2f N.m', c{1}, V(k).name, m.cost, m.track, m.jerk, m.rms, m.tv, m.maxTa);
    end
end

% ---- agent and environment ----
assignin('base', 'rl_stage', 1);                      % curriculum stage read by the training reset function (rl_env.m)
[env, agent] = rl_env([], 'train');
agent.AgentOptions.ResetExperienceBufferBeforeTraining = false;
logLine(fLog, 'agent: TD3, actor %d learnables, critic %d learnables; exploration OU, stationary std %.3g -> %.3g N.m', ...
    countLearnables(getActor(agent)), countLearnables(getCritic(agent)), tr.noise_std_start.value, tr.noise_std_min.value);
nStep = round(cfg.episode_s.value / evalin('base', 'rl_Ts'));
if isfield(ov, 'steps_per_episode'), nStep = ov.steps_per_episode; end
opts = rlTrainingOptions('MaxEpisodes', tr.chunk_episodes.value, 'MaxStepsPerEpisode', nStep, 'Plots', 'none', ...
    'Verbose', false, 'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', tr.chunk_episodes.value);

valHist = zeros(0, 1 + 2 * numel(V));   % [episodes, cost per validation episode, rms per validation episode]
m0 = validateAgent(agent, V, T_ref, w1);
valHist(end + 1, :) = [0, [m0.cost], [m0.rms]];
for k = 1:numel(V)
    writeText(fVal, sprintf('0,RL,%s,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n', V(k).name, m0(k).cost, m0(k).rms, m0(k).tv, m0(k).maxTa, m0(k).track, m0(k).jerk), 'a');
end
logLine(fLog, 'untrained agent: validation cost %s (Map %s, PID %s)', mat2str([m0.cost], 4), mat2str(ref.Map, 4), mat2str(ref.PID, 4));
bestCost = sum([m0.cost]);
save(fullfile(agentDir, 'agent_best.mat'), 'agent');

epReward = []; tStart = tic; steps = 0; chunk = 0; trialDone = false; lastStage = 0;
s1 = tr.curriculum_stage1_episodes.value; s2 = tr.curriculum_stage2_episodes.value;
while steps < tr.max_steps.value && toc(tStart) < 3600 * tr.max_hours.value
    chunk = chunk + 1;
    tc = tic;
    stage = 1 + (numel(epReward) >= s1) + (numel(epReward) >= s1 + s2);
    assignin('base', 'rl_stage', stage);
    if stage ~= lastStage
        logLine(fLog, 'curriculum: stage %d from episode %d (stage 1 dry road, 2 mild friction changes, 3 full range)', stage, numel(epReward) + 1);
        lastStage = stage;
    end
    try
        stats = train(agent, env, opts);
    catch ME
        logLine(fLog, 'ERROR in train() at chunk %d: %s', chunk, ME.message);
        break;
    end
    r = stats.EpisodeReward(:); n = stats.EpisodeSteps(:);
    for e = 1:numel(r)
        writeText(fEp, sprintf('%d,%d,%.6g,%d,%.1f\n', numel(epReward) + e, chunk, r(e), n(e), toc(tStart)), 'a');
    end
    epReward = [epReward; r]; %#ok<AGROW>
    steps = steps + sum(n);
    m = validateAgent(agent, V, T_ref, w1);
    valHist(end + 1, :) = [numel(epReward), [m.cost], [m.rms]]; %#ok<AGROW>
    for k = 1:numel(V)
        writeText(fVal, sprintf('%d,RL,%s,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n', numel(epReward), V(k).name, m(k).cost, m(k).rms, m(k).tv, m(k).maxTa, m(k).track, m(k).jerk), 'a');
    end
    save(fullfile(agentDir, 'agent_last.mat'), 'agent');
    tag = '';
    if sum([m.cost]) < bestCost
        bestCost = sum([m.cost]);
        save(fullfile(agentDir, 'agent_best.mat'), 'agent');
        tag = ' (new best)';
    end
    logLine(fLog, ['chunk %d (stage %d): episodes %d, steps %d, %.0f s (%.2f ms/step); episode reward mean %.4g; validation cost %s (tracking %s + smoothness %s), ' ...
        'RMS e_T %s N.m, TV(T_a) %s N.m/s%s'], chunk, stage, numel(epReward), steps, toc(tc), 1e3 * toc(tc) / sum(n), mean(r), mat2str([m.cost], 4), ...
        mat2str([m.track], 3), mat2str([m.jerk], 3), mat2str([m.rms], 3), mat2str([m.tv], 4), tag);
    plotCurve(fFig, epReward, valHist, ref, V, runName);
    if ~trialDone && numel(epReward) >= tr.trial_episodes.value
        trialDone = true;
        improved = sum(valHist(end, 2:1 + numel(V))) < sum(valHist(1, 2:1 + numel(V)));
        logLine(fLog, 'TRIAL CHECK after %d episodes: validation cost %s -> %s, %s; training continues to the budget either way (the night would be idle otherwise)', ...
            numel(epReward), mat2str(valHist(1, 2:1 + numel(V)), 4), mat2str(valHist(end, 2:1 + numel(V)), 4), ...
            ternary(improved, 'IMPROVED', 'NOT improved'));
    end
end
logLine(fLog, 'end: %d episodes, %d steps, %.2f h; best validation cost (sum) %.4g (Map %.4g, PID %.4g)', numel(epReward), steps, ...
    toc(tStart) / 3600, bestCost, sum(ref.Map), sum(ref.PID));
end

%% ===================== validation =====================
function m = validateAgent(agent, V, T_ref, w1)
    assignin('base', 'rl_agent', agent);
    for k = 1:numel(V)
        m(k) = runValidation('Model_RL_s', V(k), T_ref, w1, struct('rl_use_agent', 1, 'rl_done_eT', 1e6)); %#ok<AGROW>
    end
end

function m = runValidation(mdl, Vk, T_ref, w1, extra)
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
    eT = resample1(so.get('log_e_T'), t, 'linear');
    Ta = resample1(so.get('log_T_a'), t, 'previous');
    w = t >= 1;
    dTa = [0; diff(Ta)];
    m.track = mean((eT(w) / T_ref).^2);
    m.jerk = mean(w1 * dTa(w).^2);
    m.cost = m.track + m.jerk;
    m.rms = sqrt(mean(eT(w).^2));
    m.tv = sum(abs(diff(Ta(w)))) / (t(end) - 1);
    m.maxTa = max(abs(Ta(w)));
end

function y = resample1(ts, t, method)
    [tu, iu] = unique(ts.Time, 'last');
    y = interp1(tu, squeeze(ts.Data(iu)), t, method, 'extrap');
end

%% ===================== files =====================
function writeText(f, s, mode)
    fid = fopen(f, mode);
    fprintf(fid, '%s', sprintf(s));
    fclose(fid);
end

function logLine(f, fmt, varargin)
    s = sprintf(['[%s] ' fmt], datestr(now, 'yyyy-mm-dd HH:MM:SS'), varargin{:}); %#ok<TNOW1,DATST>
    fid = fopen(f, 'a');
    fprintf(fid, '%s\n', s);
    fclose(fid);
    fprintf('%s\n', s);
end

function plotCurve(f, epReward, valHist, ref, V, runName)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 700]);
    subplot(2, 1, 1);
    plot(epReward, '.', 'Color', [0.6 0.6 0.6]); hold on;
    if numel(epReward) >= 5, plot(movmean(epReward, 10), 'b', 'LineWidth', 1.5); end
    grid on; xlabel('episode'); ylabel('episode reward'); title(sprintf('%s: training episodes (dots) and 10-episode mean', runName));
    subplot(2, 1, 2); hold on;
    col = lines(numel(V));
    for k = 1:numel(V)
        plot(valHist(:, 1), valHist(:, 1 + k), '-o', 'Color', col(k, :), 'DisplayName', ['RL ' strrep(V(k).name, '_', ' ')]);
        yline(ref.Map(k), '--', 'Color', col(k, :), 'DisplayName', ['Map ' strrep(V(k).name, '_', ' ')]);
        yline(ref.PID(k), ':', 'Color', col(k, :), 'LineWidth', 1.5, 'DisplayName', ['PID ' strrep(V(k).name, '_', ' ')]);
    end
    set(gca, 'YScale', 'log'); grid on; xlabel('episodes trained'); ylabel('validation cost (lower is better)');
    legend('Location', 'northeast');
    exportgraphics(fig, f, 'Resolution', 110);
    close(fig);
end

function n = countLearnables(rep)
% rep may be an array (TD3 has two critics): count every element
    n = 0;
    for i = 1:numel(rep)
        p = getLearnableParameters(rep(i));
        n = n + sum(cellfun(@numel, p));
    end
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
