function T = measure_rl_cost(nRuns)
%MEASURE_RL_COST Wall-clock cost of simulating and training the RL environment (step 1 of Documents/RL/DieuKhien_RL.txt).
%
%   T = measure_rl_cost()        2 runs per configuration (the first includes compilation)
%
%   Configurations (30 s requested, the fixed rl_scenario scenario, ideal sensors):
%     Map baseline (Model_Map_s)                 reference: the controller with the cheapest loop
%     RL model, T_a = 0                          agent switched off (the agent block still evaluates its network)
%     RL model, untrained agent, normal mode     the agent drives T_a
%     RL model, untrained agent, accelerator     same, Simulink Accelerator mode
%     Training TD3, 3 episodes (max 2000 steps)  network updates included (normal mode)
%   The early-termination threshold rl_done_eT is raised to 1e6 N.m during the measurement, otherwise an untrained agent ends the
%   run after a fraction of a second (|e_T| > 10 N.m) and the timing would not describe full-length episodes. The simulated time of
%   every row is the time actually reached (last logged sample), not the requested one.
%   Result: Result/RL/Step1/RL_step1_timing.csv  Configuration, Mode, Run, Simulated_s, Wall_s, Wall_per_simulated_s.
%   Run first: run('<Model>/load_map.m') (Map reference) and then run('<Model>/load_rl.m'); the models must be built
%   (Model_RL_s is built by rl_env if missing).

if nargin < 1, nRuns = 2; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir);
tEnd = 30;
sc = rl_scenario(40, 0.774, 0.3, 12, tEnd);
rows = {};

% ---- Map baseline ----
mapName = 'Model_Map_s';
if ~bdIsLoaded(mapName), load_system(fullfile(modelDir, [mapName '.mdl'])); end
for r = 1:nRuns
    inM = Simulink.SimulationInput(mapName);
    inM = inM.setVariable('sc_theta1', [sc.t sc.theta1]);
    inM = inM.setVariable('sc_v', [sc.t sc.v]);
    inM = inM.setVariable('sc_mu', [sc.t sc.mu]);
    inM = inM.setModelParameter('StopTime', num2str(tEnd));
    t0 = tic; soM = sim(inM); w = toc(t0);
    tm = soM.get('log_T_s').Time(end);
    rows(end + 1, :) = {'Map baseline (Model_Map_s)', 'normal', r, tm, w, w / tm}; %#ok<AGROW>
    fprintf('Map baseline run %d: %.2f s wall for %.2f s simulated\n', r, w, tm);
end
close_system(mapName, 0);

% ---- RL model ----
[env, agent] = rl_env();
mdl = 'Model_RL_s';
doneOld = evalin('base', 'rl_done_eT');
assignin('base', 'rl_done_eT', 1e6);               % no early termination while timing
cleanupDone = onCleanup(@() assignin('base', 'rl_done_eT', doneOld)); %#ok<NASGU>
cfg = {'RL model, T_a = 0', 'normal', 0; 'RL model, untrained agent', 'normal', 1; 'RL model, untrained agent', 'accelerator', 1};
for c = 1:size(cfg, 1)
    for r = 1:nRuns
        inR = Simulink.SimulationInput(mdl);
        inR = inR.setVariable('sc_theta1', [sc.t sc.theta1]);
        inR = inR.setVariable('sc_v', [sc.t sc.v]);
        inR = inR.setVariable('sc_mu', [sc.t sc.mu]);
        inR = inR.setVariable('rl_use_agent', cfg{c, 3});
        inR = inR.setModelParameter('StopTime', num2str(tEnd), 'SimulationMode', cfg{c, 2});
        t0 = tic; soR = sim(inR); w = toc(t0);
        tm = soR.get('log_T_s').Time(end);
        rows(end + 1, :) = {cfg{c, 1}, cfg{c, 2}, r, tm, w, w / tm}; %#ok<AGROW>
        fprintf('%s (%s) run %d: %.2f s wall for %.2f s simulated\n', cfg{c, 1}, cfg{c, 2}, r, w, tm);
    end
end

% ---- training cost: network updates included ----
% Two training runs of 3 episodes, 2000 and 4000 steps each: the difference separates the cost per step from the start-up cost.
nEp = 3; stepsList = [2000 4000]; wTrain = zeros(1, 2); nDone = zeros(1, 2);
set_param(mdl, 'SimulationMode', 'normal');
for k = 1:2
    opts = rlTrainingOptions('MaxEpisodes', nEp, 'MaxStepsPerEpisode', stepsList(k), 'Plots', 'none', 'Verbose', false, ...
        'StopTrainingCriteria', 'EpisodeCount', 'StopTrainingValue', nEp);
    t0 = tic; stats = train(agent, env, opts); wTrain(k) = toc(t0);
    nDone(k) = sum(stats.EpisodeSteps);                 % steps actually run in this call
    simulated = nDone(k) * evalin('base', 'rl_Ts');
    rows(end + 1, :) = {sprintf('Training TD3, %d episodes x %d steps (%d steps done)', nEp, stepsList(k), nDone(k)), 'normal', 1, simulated, wTrain(k), wTrain(k) / simulated}; %#ok<AGROW>
    fprintf('Training %d: %.1f s wall for %d agent steps = %.1f s simulated (%.2f ms per step including start-up)\n', k, wTrain(k), nDone(k), simulated, 1e3 * wTrain(k) / nDone(k));
end
dSteps = nDone(2) - nDone(1); dWall = wTrain(2) - wTrain(1);
rows(end + 1, :) = {'Training TD3, marginal cost (difference of the two runs)', 'normal', 1, dSteps * evalin('base', 'rl_Ts'), dWall, dWall / (dSteps * evalin('base', 'rl_Ts'))};
fprintf('Training marginal: %.2f ms per agent step; start-up about %.1f s\n', 1e3 * dWall / dSteps, wTrain(1) - nDone(1) * dWall / dSteps);

T = cell2table(rows, 'VariableNames', {'Configuration', 'Mode', 'Run', 'Simulated_s', 'Wall_s', 'Wall_per_simulated_s'});
outDir = result_dir('RL', 'Step1');
writetable(T, fullfile(outDir, 'RL_step1_timing.csv'));
fprintf('Written: %s\n', fullfile(outDir, 'RL_step1_timing.csv'));
end
