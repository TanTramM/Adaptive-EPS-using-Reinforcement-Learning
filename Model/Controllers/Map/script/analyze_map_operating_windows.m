function [T, Q] = analyze_map_operating_windows()
%ANALYZE_MAP_OPERATING_WINDOWS Diagnose CALIB v2 windows for representative Map designs.
%
%   This is a diagnostic only.  It does not modify map.json, the grid CSVs,
%   the Pareto cache, or any selection gate.  The provisional normal-driving
%   region is defined before inspecting the simulation values: dry-road
%   CALIB windows at 30--90 km/h.  It contains 54 of the 68 CALIB windows
%   (79.4 %); the 20 km/h, 100 km/h and friction-step windows remain in the
%   report as boundary/robustness evidence.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('Map', 'Calib');
detailPath = fullfile(outDir, 'Map_CALIB_window_diagnosis_s00000.csv');
summaryPath = fullfile(outDir, 'Map_CALIB_window_diagnosis_summary_s00000.csv');

Cal = calibrate_map_cached();
assignin('base', 'Map_calibration_override', Cal);
run(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'));
S = make_cases('CALIB');

% These points were selected before inspecting window-level values: the
% lowest-K cached finalist, the nominal-J leader, a nearby finite-stress
% finalist, and the lowest finite gain-stress ratio in the cached scan.
C = candidates();
rows = struct('candidate', {}, 'condition', {}, 'K', {}, 'z', {}, ...
    'p_over_z', {}, 'z1', {}, 'p1_over_z1', {}, 'window', {}, ...
    'group', {}, 'speed_kmh', {}, 'ay_g', {}, 'normal80', {}, ...
    'rms_e_Nm', {}, 'mean_e_Nm', {}, 'mean_Tdref_Nm', {}, ...
    'signed_erel_pct', {}, 'abs_erel_pct', {}, 'R_total_pct', {}, 'S_total_Nm', {});
for i = 1:numel(C)
    V = map_variables(Cal, C(i).design);
    for stress = 0:1
        W = V;
        if stress == 0
            condition = 'nominal'; W.act_gain_mult = 1; W.ctrl_delay = 0;
        else
            condition = 'gain_x2'; W.act_gain_mult = 2; W.ctrl_delay = 0;
        end
        [L, m] = calib_run('Model_Map', 0, W);
        for j = 1:numel(S.win)
            win = S.win(j);
            in = L.t >= win.t0 & L.t <= win.t1;
            [speed, ay, group, normal80] = classifyWindow(win.label);
            r = struct();
            r.candidate = C(i).name;
            r.condition = condition;
            r.K = C(i).design.Kmax;
            r.z = C(i).design.lead.z;
            r.p_over_z = C(i).design.lead.p / C(i).design.lead.z;
            r.z1 = C(i).design.lag.z1;
            r.p1_over_z1 = C(i).design.lag.p1 / C(i).design.lag.z1;
            r.window = win.label;
            r.group = group;
            r.speed_kmh = speed;
            r.ay_g = ay;
            r.normal80 = normal80;
            r.rms_e_Nm = sqrt(mean(L.e_T(in).^2));
            r.mean_e_Nm = mean(L.e_T(in));
            r.mean_Tdref_Nm = mean(abs(L.T_d_ref(in)));
            r.signed_erel_pct = 100 * r.mean_e_Nm / max(r.mean_Tdref_Nm, eps);
            r.abs_erel_pct = abs(r.signed_erel_pct);
            r.R_total_pct = m.R;
            r.S_total_Nm = m.S;
            rows(end + 1) = r; %#ok<AGROW>
        end
    end
end
T = struct2table(rows);
writetable(T, detailPath);

regions = {'normal80', 'boundary'};
qrows = struct('candidate', {}, 'condition', {}, 'region', {}, 'windows', {}, ...
    'rms_e_Nm', {}, 'max_abs_erel_pct', {}, 'mean_abs_erel_pct', {});
for i = 1:numel(C)
    for stress = 0:1
        condition = 'nominal'; if stress, condition = 'gain_x2'; end
        for k = 1:numel(regions)
            isNormal = strcmp(regions{k}, 'normal80');
            ix = strcmp(T.candidate, C(i).name) & strcmp(T.condition, condition) & T.normal80 == isNormal;
            q = struct(); q.candidate = C(i).name; q.condition = condition; q.region = regions{k};
            q.windows = nnz(ix);
            q.rms_e_Nm = sqrt(mean(T.rms_e_Nm(ix).^2));
            q.max_abs_erel_pct = max(T.abs_erel_pct(ix));
            q.mean_abs_erel_pct = mean(T.abs_erel_pct(ix));
            qrows(end + 1) = q; %#ok<AGROW>
        end
    end
end
Q = struct2table(qrows);
writetable(Q, summaryPath);
fprintf('MAP_WINDOW_DIAGNOSIS_DONE: %s\n', detailPath);
end

function C = candidates()
C(1) = makeCandidate('low_K_cached', 8.11800214942, 107.721734502, 22.0179048421, 10.0253049509, 0.649621383824);
C(2) = makeCandidate('nominal_J_leader', 8.94427191002, 107.721734502, 15.4948654616, 11.2228044161, 0.603127801789);
C(3) = makeCandidate('K9_finite_stress', 8.94427191002, 50.0000000002, 62.8318530715, 12.5633424198, 0.873131659551);
C(4) = makeCandidate('minimum_gain_ratio', 16, 23.207944168, 135.367123897, 48.6576159646, 0.4);
end

function C = makeCandidate(name, K, z, pOverZ, z1, p1OverZ1)
C.name = name;
C.design = struct('Ts_ctrl', 1e-3, 'Ts0', 0.3, 'Kmax', K, ...
    'lead', struct('z', z, 'p', z * pOverZ), ...
    'lag', struct('z1', z1, 'p1', z1 * p1OverZ1));
end

function [speed, ay, group, normal80] = classifyWindow(label)
if startsWith(label, 'static'), group = 'static';
elseif startsWith(label, 'trans') || startsWith(label, 'sine'), group = 'dyn';
else, group = 'mu'; end
speed = 60; ay = 0.3;
tok = regexp(label, '_v(\d+)_', 'tokens', 'once');
if ~isempty(tok), speed = str2double(tok{1}); end
tok = regexp(label, '_a(?:pos|neg)(\d+p\d+)g$', 'tokens', 'once');
if ~isempty(tok), ay = str2double(strrep(tok{1}, 'p', '.')); end
normal80 = speed >= 30 && speed <= 90 && ~startsWith(label, 'mu');
end
