%% load_plant.m
% Read raw parameters from data/params.json (Clusters 1+2+3) straight into
% the base workspace so Simulink models (Plant/*.mdl) can reference them
% directly by variable name.
%
% Cluster 1 parameters (K, J_col, C_col, T_f, c) are the raw parameters used
% directly by the model (system-identification method of [1] Lee et al.
% 2018, see Documents/Cum1_CEPS.txt) - no lumped symbols are computed here.
% Algebraic quantities of Cluster 2/3 (delta_f, alpha_f, F_yf, T_r,
% beta_dot, gamma_dot, ...) are computed inside Simulink blocks every
% simulation step, not precomputed here - EXCEPT quantities that are
% time-invariant for a given parameter set (see load_derived.m, called at
% the end of this script).
%
% Usage: run this SCRIPT (not a function) BEFORE building/simulating any
% model under Plant/, since the variables it creates must live in the base
% workspace. Works from any current working directory (uses the script's
% own absolute path).

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'params.json')));

%% ===================== CLUSTER 1 - STEERING COLUMN =====================
p1 = raw.cum1;
fn = fieldnames(p1);
for i = 1:numel(fn)
    assignin('base', fn{i}, p1.(fn{i}).value);
end

%% ===================== CLUSTER 2 - PACEJKA TIRES =====================
p2 = raw.cum2;
fn = fieldnames(p2);
for i = 1:numel(fn)
    assignin('base', fn{i}, p2.(fn{i}).value);
end

%% ===================== CLUSTER 3 - 2-DOF VEHICLE BODY =====================
% m, l_f, l_r already loaded from Cluster 2 (reused, not redefined - see
% "_cum3_reused_from_cum2" in params.json). Only Iz is loaded here.
p3 = raw.cum3;
fn = fieldnames(p3);
for i = 1:numel(fn)
    assignin('base', fn{i}, p3.(fn{i}).value);
end

fprintf('Loaded plant parameters (data/params.json): Cluster1 [%s], Cluster2 [%s], Cluster3 [%s] (+ m,l_f,l_r reused from Cluster2)\n', ...
    strjoin(fieldnames(raw.cum1), ', '), strjoin(fieldnames(raw.cum2), ', '), strjoin(fieldnames(raw.cum3), ', '));

%% ===================== DERIVED QUANTITIES (time-invariant) =====================
% See load_derived.m - computes F_zf once, instead of recomputing it every
% Simulink simulation step.
run(fullfile(scriptDir, 'load_derived.m'));
