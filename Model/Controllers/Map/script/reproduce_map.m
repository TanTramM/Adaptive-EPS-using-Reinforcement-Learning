function reproduce_map(stages)
%REPRODUCE_MAP Rebuild every Map result of the paper step by step (QuyChuan v5). Each stage is resumable: rows already in the csv files are skipped.
%
%   reproduce_map            all stages 1-6 (about 5 hours on a desktop PC; stage 2 about 3 h, stage 3-4 about 1.5 h, stage 6 a few minutes)
%   reproduce_map(2)         one stage;  reproduce_map([1 5])  several
%   Stage 1  calibration table of the dry road (979 points) and the static accuracy study       -> Design/Map_calibration_points.csv, Map_K_for_accuracy_5pct.csv, Map_step2_*.png
%   Stage 2  lead-lag design (z, p, z1, p1) for every (g_min, K) of the grid, 68 linear plants   -> Design/Map_design_leadlag.csv
%   Stage 3  CALIB simulations of the 61 (g_min, K) pairs (4 runs per pair)                       -> Calib/Map_CALIB_sweep_s00000.csv
%   Stage 4  CALIB simulations beyond the linear limit (12 pairs, compensator kept)              -> Calib/Map_CALIB_sweepbeyondA/B_s00000.csv
%   Stage 5  gates, J = R*S with the 2 Hz band constraint, bang-bang report, write map.json      -> Calib/Map_CALIB_pick_s00000.csv, data/map.json (design)
%   Stage 6  the five scoring cases DRY, RAMP, SLIP, WEAVE, EDGE with the chosen point (seed 0)   -> Cases/Map_*_s00000.*
%   The text, tables and figures of the chapter are made afterwards by tools/build_map_txt.py (Python).
%   A fresh run needs an empty Result/ folder; to redo a stage delete its csv file.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
if nargin < 1 || isempty(stages), stages = 1:6; end
calibDir = result_dir('Map', 'CalibV1');      % reproduces the CALIB v1 results of the paper (old method)
tStart = tic;

if any(stages == 1)
    fprintf('\n[reproduce_map] STAGE 1: calibration table and static accuracy\n');
    calibrate_map();                 % also writes Design/Map_calibration_points.csv
    plot_step2();                    % K_acc(v) at 5 %, assist curves, dry-road error (K of map.json)
end

if any(stages == 2)
    fprintf('\n[reproduce_map] STAGE 2: lead-lag design (resumable)\n');
    sweep_leadlag([1.0 0.9 0.8 0.7 0.6], [5:0.5:10 11:30]);   % K step 0.5 up to 10, then 1; each level stops at its first infeasible K
    sweep_leadlag([0.75 0.65], [8 9 10]);
    sweep_leadlag(0.6, 5.75);
    sweep_leadlag([0.5 0.4], [5 5.5 5.75 6 7 8 10]);
    sweep_leadlag(0.3, [5 5.5 5.75 5.8 6 6.5 7 8 10]);
    sweep_leadlag(0.25, [5.8 6 6.5 7 8], struct('qLim', [0.05 0.9]));   % deepest level: lag ratio bound widened to 0.05
end

pairs = [ ...
    1.00 6; 1.00 7; 1.00 8; ...
    0.90 6; 0.90 7; 0.90 8; 0.90 9; 0.90 10; ...
    0.80 6; 0.80 7; 0.80 8; 0.80 9; 0.80 10; 0.80 12; ...
    0.75 8; 0.75 9; 0.75 10; ...
    0.70 5.5; 0.70 6; 0.70 7; 0.70 7.5; 0.70 8; 0.70 8.5; 0.70 9; 0.70 10; 0.70 12; 0.70 14; ...
    0.65 8; 0.65 9; 0.65 10; ...
    0.60 5; 0.60 5.5; 0.60 5.75; 0.60 6; 0.60 7; 0.60 8; 0.60 9; 0.60 10; 0.60 12; 0.60 14; 0.60 16; ...
    0.50 5.75; 0.50 6; 0.50 7; 0.50 8; 0.50 10; ...
    0.40 6; 0.40 7; 0.40 8; 0.40 10; ...
    0.30 5.8; 0.30 6; 0.30 6.5; 0.30 7; 0.30 8; 0.30 10; ...
    0.25 5.8; 0.25 6; 0.25 6.5; 0.25 7; 0.25 8];

if any(stages == 3)
    fprintf('\n[reproduce_map] STAGE 3: CALIB simulations, %d pairs x 4 runs (resumable)\n', size(pairs, 1));
    run_calib_sweep(pairs, 0);
end

if any(stages == 4)
    fprintf('\n[reproduce_map] STAGE 4: beyond the linear limit (compensator of the largest feasible K, larger table slope)\n');
    A = [1.0 10; 1.0 12; 1.0 16; 1.0 20; 1.0 30; 1.0 40];         % compensator of K = 8 (lead only)
    run_calib_sweep(A, 0, 8 * ones(size(A, 1), 1), fullfile(calibDir, 'Map_CALIB_sweepbeyondA_s00000.csv'));
    B = [0.7 16; 0.7 20; 0.7 30; 0.7 40; 0.6 20; 0.6 30];          % compensator of K = 14 (g_min 0.7) and K = 16 (g_min 0.6)
    run_calib_sweep(B, 0, [14; 14; 14; 14; 16; 16], fullfile(calibDir, 'Map_CALIB_sweepbeyondB_s00000.csv'));
end

if any(stages == 5)
    fprintf('\n[reproduce_map] STAGE 5: gates and selection (report), then write map.json\n');
    select_map();                    % report only
    select_map(true);                % bang-bang report (two noisy seeds), writes design into data/map.json
end

if any(stages == 6)
    fprintf('\n[reproduce_map] STAGE 6: five scoring cases with the chosen point, seed 00000\n');
    evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
    run_cases('Map', 0, 'V1');   % DREWS v1 reproduction
end
fprintf('\n[reproduce_map] done in %.1f min\n', toc(tStart) / 60);
end
