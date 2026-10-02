function [env, agent, obsInfo, actInfo] = rl_env(agent, mode)
%RL_ENV Observation/action specifications, agent and Simulink environment of the pure RL controller.
%
%   [env, agent, obsInfo, actInfo] = rl_env()                 new untrained TD3 agent, fixed scenario (wiring checks)
%   [env, agent, obsInfo, actInfo] = rl_env(agent)            given agent, fixed scenario
%   [env, agent, obsInfo, actInfo] = rl_env(agent, 'train')   training resets: a NEW random scenario (rl_scenario_random, of the
%                                                             curriculum stage in the base variable rl_stage) and a NEW sensor
%                                                             noise seed every episode
%
%   Run load_rl.m first (base workspace parameters). The agent is also stored in the base workspace as
%   rl_agent, because the RL Agent block of Model_RL_s.mdl reads it from there; Model_RL_s.mdl is built
%   (build_model_rl.m) if it does not exist yet. Documents/RL/DieuKhien_RL.txt, sections 2.1, 2.1a and 2.4a.
%
%   Observation: rl_n_obs x 1 (normalized signals with history, previous T_a). Action: T_a [N.m] within
%   +-max T_a,max(v); the model limits it again to +-T_a,max(v) at the current speed.
%   New agent: TD3 of the Reinforcement Learning Toolbox, default networks with 64 hidden units, options from the "train"
%   block of data/rl.json (discount, learning rates, mini-batch, buffer, Ornstein-Uhlenbeck exploration noise).
%   Training resets draw the scenario seed and the sensor seed from the MATLAB random generator, inside the training
%   range of data/sensors.json (1-9999); the sensor level of training episodes is 'high'.

if nargin < 2, mode = 'fixed'; end
scriptDir = fileparts(mfilename('fullpath'));   % RL/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
mdl = 'Model_RL_s';
cfg = jsondecode(fileread(fullfile(modelDir, 'data', 'rl.json')));
tr = cfg.train;

nObs  = evalin('base', 'rl_n_obs');
TaLim = max(evalin('base', 'Tamax_table'));
Ts    = evalin('base', 'rl_Ts');
obsInfo = rlNumericSpec([nObs 1]);
obsInfo.Name = 'observation';
actInfo = rlNumericSpec([1 1], 'LowerLimit', -TaLim, 'UpperLimit', TaLim);
actInfo.Name = 'T_a';

if nargin < 1 || isempty(agent)
    initOpts  = rlAgentInitializationOptions('NumHiddenUnit', 64);
    agentOpts = rlTD3AgentOptions('SampleTime', Ts, 'DiscountFactor', tr.gamma.value, ...
        'MiniBatchSize', tr.minibatch.value, 'ExperienceBufferLength', tr.buffer.value);
    agentOpts.ActorOptimizerOptions  = rlOptimizerOptions('LearnRate', tr.actor_lr.value, 'GradientThreshold', tr.grad_threshold.value);
    agentOpts.CriticOptimizerOptions = rlOptimizerOptions('LearnRate', tr.critic_lr.value, 'GradientThreshold', tr.grad_threshold.value);
    % Ornstein-Uhlenbeck exploration: x[k+1] = x[k] + theta*(0 - x[k])*Ts + sigma*sqrt(Ts)*n[k], stationary std = sigma/sqrt(2*theta),
    % correlation time 1/theta; sigma decays per step by (1 - d) down to its minimum
    theta = 1 / tr.noise_corr_time_s.value;
    d = log(tr.noise_std_start.value / tr.noise_std_min.value) / tr.noise_decay_steps.value;
    ou = rl.option.OrnsteinUhlenbeckActionNoise;
    ou.MeanAttractionConstant = theta;
    ou.StandardDeviation = tr.noise_std_start.value * sqrt(2 * theta);
    ou.StandardDeviationMin = tr.noise_std_min.value * sqrt(2 * theta);
    ou.StandardDeviationDecayRate = d;
    agentOpts.ExplorationModel = ou;
    agent = rlTD3Agent(obsInfo, actInfo, initOpts, agentOpts);
end
assignin('base', 'rl_agent', agent);

if ~exist(fullfile(modelDir, [mdl '.mdl']), 'file')
    run(fullfile(scriptDir, 'build_model_rl.m'));
end
if ~bdIsLoaded(mdl)
    load_system(fullfile(modelDir, [mdl '.mdl']));
end
env = rlSimulinkEnv(mdl, [mdl '/Model_RL/RL/RL Agent'], obsInfo, actInfo);
switch mode
    case 'fixed'
        env.ResetFcn = @(in) applyScenario(in, rl_scenario());
    case 'train'
        rng0 = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json'))).seeds.train_range;
        epLen = cfg.episode_s.value;
        env.ResetFcn = @(in) trainReset(in, rng0, epLen);   % the curriculum stage is read from the base variable rl_stage at every reset
    otherwise
        error('rl_env: unknown mode %s', mode);
end
end

function in = applyScenario(in, sc)
    in = in.setVariable('sc_theta1', [sc.t sc.theta1]);
    in = in.setVariable('sc_v',      [sc.t sc.v]);
    in = in.setVariable('sc_mu',     [sc.t sc.mu]);
    in = in.setModelParameter('StopTime', sprintf('%.15g', sc.t(end)));
end

function in = trainReset(in, seedRange, epLen)
    stage = 3;
    if evalin('base', 'exist(''rl_stage'', ''var'')'), stage = evalin('base', 'rl_stage'); end
    sc = rl_scenario_random(randi(seedRange), epLen, stage);
    in = applyScenario(in, sc);
    V = sensor_noise_vars('high', randi(seedRange));
    fn = fieldnames(V);
    for k = 1:numel(fn)
        in = in.setVariable(fn{k}, V.(fn{k}));
    end
end
