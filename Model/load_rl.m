%% load_rl.m
% Load everything needed to build/simulate the pure RL assist controller
% (Documents/RL/DieuKhien_RL.txt) and its closed loop (Model_RL_s.mdl):
%   1. data/rl.json -> base workspace:
%        rl_Ts          [s]   agent sample time
%        rl_obs_gain    [-]   1 ./ obs_scale (row vector, observation = signal .* rl_obs_gain)
%        rl_n_hist      [-]   samples kept per signal (current + previous)
%        rl_hist_stride [-]   spacing of the history samples in agent samples
%        rl_Ta_gain     [1/N.m] 1 / Ta_scale (previous assist torque observation)
%        rl_reward_par  [-]   [T_ref, w1, w2] of the step reward
%        rl_done_eT     [N.m] early-termination threshold on |e_T|
%        rl_use_agent   [-]   1: agent drives T_a, 0: T_a = 0
%        rl_I_decay     [-]   1 - Ts/I_tau: decay factor of the slow observation I (low-pass of the measured e_T)
%        rl_I_in        [-]   Ts/I_tau: input gain of I
%        rl_I_gain      [1/N.m] 1 / I_scale: normalization of I
%        rl_n_obs       [-]   length of the observation vector (7 signals x n_hist, previous T_a, I)
%   2. load_plant.m (plant parameters), load_ref.m (T_d,ref table and T_a,max(v)), load_sensors.m (Sensors variables,
%      default level 'none' = ideal sensors).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_rl.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);                             % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'rl.json')));

nSig = numel(raw.obs_signals.value);
assignin('base', 'rl_Ts',          raw.Ts_agent.value);
assignin('base', 'rl_obs_gain',    1 ./ raw.obs_scale.value(:)');
assignin('base', 'rl_n_hist',      raw.n_hist.value);
assignin('base', 'rl_hist_stride', raw.hist_stride.value);
assignin('base', 'rl_Ta_gain',     1 / raw.Ta_scale.value);
assignin('base', 'rl_reward_par',  [raw.reward.T_ref.value, raw.reward.w1.value, raw.reward.w2.value]);
assignin('base', 'rl_done_eT',     raw.done_eT.value);
assignin('base', 'rl_use_agent',   raw.use_agent.value);
assignin('base', 'rl_I_decay',     1 - raw.Ts_agent.value / raw.I_tau.value);
assignin('base', 'rl_I_in',        raw.Ts_agent.value / raw.I_tau.value);
assignin('base', 'rl_I_gain',      1 / raw.I_scale.value);
assignin('base', 'rl_n_obs',       nSig * raw.n_hist.value + 2);

fprintf('load_rl: %d signals x %d samples (%d agent samples apart) + previous T_a + slow e_T (tau %g s) = %d observations, Ts_agent = %g s, reward [T_ref w1 w2] = %s\n', ...
    nSig, raw.n_hist.value, raw.hist_stride.value, raw.I_tau.value, nSig * raw.n_hist.value + 2, raw.Ts_agent.value, ...
    mat2str([raw.reward.T_ref.value, raw.reward.w1.value, raw.reward.w2.value]));

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
run(fullfile(scriptDir, 'load_sensors.m'));
