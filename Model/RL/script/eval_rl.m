function eval_rl(runName, levels, seeds)
%EVAL_RL Evaluate the best agent of a training run on the standard test cases, against Map and PID (same seeds).
%
%   eval_rl('Train1')
%   eval_rl('Train1', {'none'}, 90001)      quick check
%
%   Documents/RL/DieuKhien_RL.txt section 2.4a. Loads Result/RL/<runName>/agents/agent_best.mat (best validation cost), puts it
%   in the base workspace as rl_agent (exploration is not used in simulation), switches the early termination off and runs
%   run_noise_study({'RL'}, {'none', 'high'}, 90001:90005) (levels none and high only, user decision 2026-10-02): TC1-TC6 with the same sensor levels and test seeds as the Map
%   and PID study (Result/Compare/Map_vs_PID/Map_vs_PID_noise_study_summary.csv). Metrics on the TRUE signals.
%   Writes:
%     Result/RL/TestCases/ (figures and signals, level none) and Result/RL/TestCases_noise/ (by run_test_cases)
%     Result/Compare/Map_vs_PID_vs_RL/Map_vs_PID_vs_RL_noise_study_summary.csv   the three controllers in one table
%     Result/RL/<runName>/RL_<runName>_eval_summary.txt                          readable comparison table
%   Run first: load_rl.m (and load_map.m, load_pid.m are not needed: Map and PID results are read from the earlier study).

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir);
addpath(fullfile(modelDir, 'Sim', 'script'));
runDir = result_dir('RL', runName);
fLog = fullfile(runDir, sprintf('RL_%s_progress_log.txt', runName));
logLine(fLog, 'evaluation of %s: start', runName);
S = load(fullfile(runDir, 'agents', 'agent_best.mat'), 'agent');
assignin('base', 'rl_agent', S.agent);
assignin('base', 'rl_use_agent', 1);
assignin('base', 'rl_done_eT', 1e6);
if ~bdIsLoaded('Model_RL_s'), load_system(fullfile(modelDir, 'Model_RL_s.mdl')); end

if nargin < 2, levels = {'none', 'high'}; end
if nargin < 3, seeds = 90001:90005; end
try
    G = run_noise_study({'RL'}, levels, seeds);
catch ME
    logLine(fLog, 'evaluation ERROR: %s', ME.message);
    rethrow(ME);
end
mp = readtable(fullfile(result_dir('Compare', 'Map_vs_PID'), 'Map_vs_PID_noise_study_summary.csv'), 'TextType', 'char');
rl = readtable(fullfile(result_dir('Compare', 'RL'), 'RL_noise_study_summary.csv'), 'TextType', 'char');
all3 = [mp; rl(:, mp.Properties.VariableNames)];
outC = result_dir('Compare', 'Map_vs_PID_vs_RL');
writetable(all3, fullfile(outC, 'Map_vs_PID_vs_RL_noise_study_summary.csv'));

% ---- readable table ----
fS = fullfile(runDir, sprintf('RL_%s_eval_summary.txt', runName));
fid = fopen(fS, 'w');
fprintf(fid, 'Evaluation of %s (agent_best.mat) on TC1-TC6, metrics on TRUE signals, first 2 s excluded.\n', runName);
fprintf(fid, 'Levels none and low are deterministic (1 run); high = mean over seeds %d-%d. Map and PID from the earlier study, same seeds.\n\n', seeds(1), seeds(end));
cases = unique(all3.Case, 'stable');
for m = {'RMS_eT_Nm', 'TV_Ta_Nm_per_s', 'MaxAbs_eT_Nm', 'RMS_Ta_Nm'}
    fprintf(fid, '%s (whole case)\n', m{1});
    fprintf(fid, '%-30s', 'case');
    for lv = levels, for c = {'Map', 'PID', 'RL'}, fprintf(fid, '%14s', [c{1} '/' lv{1}]); end, end
    fprintf(fid, '\n');
    for i = 1:numel(cases)
        fprintf(fid, '%-30s', cases{i});
        for lv = levels
            for c = {'Map', 'PID', 'RL'}
                r = strcmp(all3.Ctrl, c{1}) & strcmp(all3.Level, lv{1}) & strcmp(all3.Case, cases{i}) & strcmp(all3.Window, 'whole case');
                if any(r), fprintf(fid, '%14.4g', all3.(['mean_' m{1}])(find(r, 1))); else, fprintf(fid, '%14s', '-'); end
            end
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\n');
end
fprintf(fid, 'Over-assist windows: mean e_T / mean |T_d,ref| [%%], negative = over-assist\n');
wins = {'TC2_road', 'curve_0p25g_v80_mu_0p3'; 'TC3_mu_drop_hard_corner', 'after_mu_drop_steady'; 'TC4_wet_patch_lane_change', 'during_puddle'; ...
        'TC5_sine_high_speed_low_mu', 'sine_sustained'};
for i = 1:size(wins, 1)
    fprintf(fid, '%-30s %-28s', wins{i, 1}, wins{i, 2});
    for lv = levels
        for c = {'Map', 'PID', 'RL'}
            r = strcmp(all3.Ctrl, c{1}) & strcmp(all3.Level, lv{1}) & strcmp(all3.Case, wins{i, 1}) & strcmp(all3.Window, wins{i, 2});
            if any(r), fprintf(fid, '%14.3g', all3.mean_Mean_eT_signed_pct_of_Tdref(find(r, 1))); else, fprintf(fid, '%14s', '-'); end
        end
    end
    fprintf(fid, '\n');
end
fclose(fid);
logLine(fLog, 'evaluation of %s: done, summary in %s', runName, fS);
end

function logLine(f, fmt, varargin)
    s = sprintf(['[%s] ' fmt], datestr(now, 'yyyy-mm-dd HH:MM:SS'), varargin{:}); %#ok<TNOW1,DATST>
    fid = fopen(f, 'a');
    fprintf(fid, '%s\n', s);
    fclose(fid);
    fprintf('%s\n', s);
end
