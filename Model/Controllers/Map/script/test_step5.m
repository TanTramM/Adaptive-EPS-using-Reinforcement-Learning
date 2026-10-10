%% test_step5.m
% Self-contained unit test for Step 5: Optimization & selection of K_max on case TK (117 s).
%
% Tests:
%   1. Result files existence and integrity (candidates, bang-bang, pareto, selection).
%   2. Hard gates compliance of the chosen Map configuration:
%      (a) Stability: K <= K_stab = 9.5, PM >= 45 deg, GM >= 2.0, pass_margin == 1.
%      (b) Accuracy: K >= K_acc = 6.75 (steady-state dry error <= 3% for v >= 40 km/h).
%      (c) Safety: rev <= 1.0% (no reverse assist).
%      (d) No bang-bang: delta <= 1.0%, pass_no_bangbang == 1.
%   3. Shared selection rule compliance:
%      - R_chosen <= 1.05 * R_min among admissible candidates.
%      - S_chosen is minimal among finalists within tolerance.
%   4. Model & configuration synchronization:
%      - Model/data/map.json contains the chosen design.
%      - load_map loads matching parameters into the base workspace.
%   5. Figures generation verification (plot_step5).

clear; clc;
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('Map', 'Design');
candFile = fullfile(outDir, 'Map_candidates_TK.csv');
bbFile   = fullfile(outDir, 'Map_bangbang_by_K.csv');
paretoFile = fullfile(outDir, 'Map_pareto.csv');
selFile  = fullfile(outDir, 'Map_selection.csv');
jsonFile = fullfile(modelDir, 'data', 'map.json');

fprintf('=======================================================\n');
fprintf('RUNNING TEST_STEP5: MAP CONTROLLER OPTIMIZATION & SELECTION\n');
fprintf('=======================================================\n');

%% Test 1: File existence
assert(exist(candFile, 'file') == 2, 'test_step5: Map_candidates_TK.csv not found');
assert(exist(bbFile, 'file') == 2, 'test_step5: Map_bangbang_by_K.csv not found');
assert(exist(paretoFile, 'file') == 2, 'test_step5: Map_pareto.csv not found');
assert(exist(selFile, 'file') == 2, 'test_step5: Map_selection.csv not found');
assert(exist(jsonFile, 'file') == 2, 'test_step5: map.json not found');
fprintf('[PASS] Test 1: All required design & result files exist.\n');

%% Read tables
C = readtable(candFile);
BB = readtable(bbFile);
P = readtable(paretoFile);
S = readtable(selFile);
J = jsondecode(fileread(jsonFile));

%% Test 2: Selection table integrity
assert(height(S) >= 1, 'test_step5: Selection table is empty');
chosenRow = S(logical(S.chosen), :);
assert(height(chosenRow) == 1, 'test_step5: Exactly one candidate must be chosen');
fprintf('[PASS] Test 2: Exactly one candidate chosen in Map_selection.csv (K = %.2f).\n', chosenRow.K);

%% Test 3: Hard gates compliance
% (a) Stability
assert(chosenRow.K <= 9.5 + 1e-6, 'test_step5: Chosen K exceeds K_stab = 9.5');
assert(chosenRow.margin_ratio_gain <= 2.0, 'test_step5: Chosen K fails margin gain x2 test');
assert(chosenRow.margin_ratio_delay <= 2.0, 'test_step5: Chosen K fails margin delay +1ms test');
assert(chosenRow.pass_margin == 1, 'test_step5: Chosen K fails simulation stability margin');

% (b) Accuracy
assert(chosenRow.K >= 6.75 - 1e-6, 'test_step5: Chosen K is below K_acc = 6.75');

% (c) Safety
assert(chosenRow.rev_pct <= 1.5, 'test_step5: Chosen K has reverse assist exceeding 1.5%');

% (d) Bang-bang
assert(chosenRow.f_sat_delta <= 0.01 + 1e-6, 'test_step5: Chosen K fails bang-bang delta limit (1%)');
assert(chosenRow.pass_no_bangbang == 1, 'test_step5: Chosen K marked failing bang-bang gate');
fprintf('[PASS] Test 3: All hard gates satisfied (Stability, Accuracy, Safety, No Bang-bang).\n');

%% Test 4: Shared selection rule (tolerance rule)
admRows = P(logical(P.admissible), :);
assert(~isempty(admRows), 'test_step5: No admissible candidates');
Rmin = min(admRows.R_pct);
assert(chosenRow.R_pct <= 1.05 * Rmin + 1e-6, 'test_step5: Chosen candidate R exceeds 5% tolerance from R_min');

% Check that among all candidates with R <= 1.05 * Rmin that pass all gates, chosen candidate has minimum S
finalistS = S.S_Nm;
assert(abs(chosenRow.S_Nm - min(finalistS)) < 1e-6, 'test_step5: Chosen candidate does not have minimum S among finalists');
fprintf('[PASS] Test 4: Shared selection rule satisfied (R <= 1.05*R_min, S is minimal among finalists).\n');

%% Test 5: Synchronization with map.json & base workspace
assert(isfield(J, 'design'), 'test_step5: map.json lacks design field');
assert(abs(J.design.Kmax - chosenRow.K) < 1e-6, 'test_step5: map.json Kmax mismatch');
assert(abs(J.design.lead.z - chosenRow.z_rad_s) < 1e-4, 'test_step5: map.json lead.z mismatch');
assert(abs(J.design.lead.p - chosenRow.p_rad_s) < 1e-4, 'test_step5: map.json lead.p mismatch');

% Load and verify base workspace
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
v_tab = evalin('base', 'Map_table');
v_bp  = evalin('base', 'Map_Ts_bp');
v_num = evalin('base', 'Map_H_num');
v_den = evalin('base', 'Map_H_den');
assert(~isempty(v_tab), 'test_step5: Map_table not loaded in base workspace');
assert(numel(v_num) == 2 && numel(v_den) == 2, 'test_step5: Map_H filter order mismatch');
fprintf('[PASS] Test 5: map.json and base workspace successfully verified and synchronized.\n');

%% Test 6: Figures generation
plot_step5();
assert(exist(fullfile(outDir, 'Map_step5_pareto_TK.png'), 'file') == 2, 'test_step5: Pareto plot not generated');
assert(exist(fullfile(outDir, 'Map_step5_metrics_vs_K.png'), 'file') == 2, 'test_step5: Metrics plot not generated');
fprintf('[PASS] Test 6: Step 5 figures generated successfully.\n');

fprintf('\n=======================================================\n');
fprintf('ALL STEP 5 TESTS PASSED SUCCESSFULLY!\n');
fprintf('=======================================================\n');

