%% run_overnight.m
% Unattended run of an RL training (Documents/RL/DieuKhien_RL.txt sections 2.4a, 2.4b): train, then evaluate. Default run: Train2.
% Started as an independent MATLAB process (it survives the end of the chat session):
%   matlab -batch "run('<Model>/RL/script/run_overnight.m')"
% Every result is written to Result/RL/<run name>/ as it goes (train_rl.m). The evaluation step runs only if eval_rl.m exists
% when training ends (it is looked up at that moment).

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(scriptDir);
addpath(fullfile(modelDir, 'Sim', 'script'));
addpath(modelDir);
run(fullfile(modelDir, 'load_map.m'));
run(fullfile(modelDir, 'load_pid.m'));
run(fullfile(modelDir, 'load_rl.m'));
if ~exist('run_name', 'var'), run_name = 'Train2'; end   % define run_name before running this script to use another name
train_rl(run_name);
if exist('eval_rl', 'file') == 2
    eval_rl(run_name);
else
    fprintf('run_overnight: eval_rl.m not found, evaluation skipped\n');
end
