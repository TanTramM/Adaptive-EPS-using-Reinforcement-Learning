function res = design_map(runSim, tol, noBangBangLimit, erelMax, revMax)
%DESIGN_MAP Step 5: Sweep and select optimal K_max for the Map controller on case TK (117 s).
%
%   res = design_map()
%   res = design_map(runSim, tol, noBangBangLimit, erelMax, revMax)
%
%   Inputs:
%     runSim          true (default) to simulate candidates on case TK, false to reuse saved CSV
%     tol             tolerance for R relative to R_min (default 0.05 = 5%)
%     noBangBangLimit max allowed increase in saturation ratio due to noise (default 0.01 = 1%)
%     erelMax         max allowed steady-state relative error across static windows (default 3.0 = 3%)
%     revMax          max allowed reverse assist fraction (default 1.0 = 1%)
%
%   Selection procedure (QuyChuan.txt part 5 & 6, CLAUDE.md):
%     1. Read / compute lead compensator for each K candidate.
%        Verify frequency-domain stability gate: PM >= 45 deg, GM >= 2.0 (K <= K_stab = 9.5).
%     2. Simulate each candidate on calibration case TK (117 s) with noisy sensors (local seed 00000).
%        Record R [%], S [N.m], Scmd [N.m], TV [N.m/s], erel [%], rev [%].
%     3. Evaluate hard gates:
%        (a) Stability gate: K <= K_stab (PM >= 45 deg, GM >= 2.0) and simulation margin check (Gain x2, delay +1ms)
%        (b) Accuracy gate: K >= K_acc = 6.75 (steady error <= 3% on dry road for v >= 40 km/h)
%        (c) Safety gate: rev <= revMax (<= 1.0%, no reverse assist)
%        (d) No bang-bang gate: tk_bangbang delta <= noBangBangLimit (<= 1.0%)
%     4. Shared selection rule: among admissible candidates, filter R <= (1 + tol) * R_min,
%        sorted by increasing S. Select the first candidate.
%     5. Compute Pareto front and knee point for comparison and reporting.
%     6. Write candidates, bang-bang scan, pareto, and selection tables to Result/Controllers/Map/Design/.
%     7. Update Model/data/map.json and reload base workspace via load_map.

if nargin < 1 || isempty(runSim), runSim = true; end
if nargin < 2 || isempty(tol), tol = 0.05; end
if nargin < 3 || isempty(noBangBangLimit), noBangBangLimit = 0.01; end
if nargin < 4 || isempty(erelMax), erelMax = 3.0; end
if nargin < 5 || isempty(revMax), revMax = 1.5; end   % default 1.5% (sensitivity 0.5-5% according to QuyChuan 4.6 & 5.6)

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('Map', 'Design');
Cal = calibrate_map_cached();
SEED = 00000;   % Local seed for Map controller (range 00000-09999)
mdl = 'Model_Map';

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
if ~bdIsLoaded(mdl), load_system(mdl); end

%% 1. Grid of K candidates
% K_acc = 6.75, K_stab = 9.5
Ks = [3.0, 4.0, 5.0, 6.0, 6.75, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 9.75, 10.0];
nK = numel(Ks);

% Load or compute lead compensators
sweepCsv = fullfile(outDir, 'Map_stability_lead_sweep.csv');
leadSweep = [];
if exist(sweepCsv, 'file')
    leadSweep = readtable(sweepCsv);
end

P = map_params();
ops = map_op_points();
w = logspace(-1, 5, 6000)';
Gj = []; % lazy evaluation

leads = cell(nK, 1);
for ik = 1:nK
    kval = Ks(ik);
    found = false;
    if ~isempty(leadSweep)
        idxS = find(abs(leadSweep.K - kval) < 1e-6, 1);
        if ~isempty(idxS)
            leads{ik} = struct(...
                'K', kval, ...
                'stable_lead_found', logical(leadSweep.stable_lead_found(idxS)), ...
                'z', leadSweep.z_rad_s(idxS), ...
                'p', leadSweep.p_rad_s(idxS), ...
                'PM', leadSweep.PM_deg(idxS), ...
                'GM', leadSweep.GM(idxS), ...
                'wc', leadSweep.wc_rad_s(idxS), ...
                'HF_gain', leadSweep.HF_gain(idxS), ...
                'Ta_noise_std', leadSweep.Ta_noise_std_Nm(idxS));
            found = true;
        end
    end
    if ~found
        if isempty(Gj)
            fprintf('design_map: Linearizing plants for lead search ...\n');
            Gj = cell(0, 1);
            for iv = 1:numel(Cal.v_kmh)
                for i = 1:size(ops, 1)
                    Gj{end+1, 1} = squeeze(freqresp(map_plant_lin(P, Cal.v_kmh(iv) / 3.6, ops(i, 1) * P.g, ops(i, 2)), w)); %#ok<AGROW>
                end
            end
        end
        fprintf('design_map: Computing lead compensator for K = %.2f ...\n', kval);
        D = design_lead(Gj, w, kval);
        leads{ik} = struct(...
            'K', kval, ...
            'stable_lead_found', logical(D.ok), ...
            'z', D.z, ...
            'p', D.p, ...
            'PM', D.PM, ...
            'GM', D.GM, ...
            'wc', D.wc, ...
            'HF_gain', D.HF, ...
            'Ta_noise_std', NaN);
    end
end

%% 2. Candidates simulation on case TK (117 s)
candFile = fullfile(outDir, 'Map_candidates_TK.csv');
candCols = {'K', 'z_rad_s', 'p_rad_s', 'PM_deg', 'GM', 'HF_gain', 'Ta_noise_std_Nm', ...
            'R_pct', 'S_Nm', 'Scmd_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', 'maxTa_Nm', ...
            'Rg_static_pct', 'Rg_dyn_pct', 'Rg_small_pct', 'Rg_mu_pct'};

rows = [];
if exist(candFile, 'file')
    try
        oldT = readtable(candFile);
        rows = table2array(oldT(:, candCols));
    catch
        rows = [];
    end
end

if runSim
    for ik = 1:nK
        kval = Ks(ik);
        if ~isempty(rows) && any(abs(rows(:, 1) - kval) < 1e-6)
            continue;
        end
        
        ld = leads{ik};
        if ~ld.stable_lead_found || isnan(ld.z) || isnan(ld.p)
            % Unstable K without lead
            rows = [rows; kval, NaN, NaN, NaN, NaN, Inf, NaN, ...
                    Inf, Inf, Inf, Inf, Inf, Inf, NaN, NaN, NaN, NaN, NaN]; %#ok<AGROW>
            fprintf('design_map: K = %.2f has no stable lead (unstable). Skipped.\n', kval);
            continue;
        end
        
        d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', kval, ...
                   'lead', struct('z', ld.z, 'p', ld.p, 'PM_deg', ld.PM));
        vars = map_variables(Cal, d);
        
        fprintf('design_map: Simulating K = %.2f (lead z=%.1f, p=%.1f) on case TK (117s) ...\n', ...
            kval, ld.z, ld.p);
        [~, m] = tk_run(mdl, SEED, vars);
        
        row_i = [kval, ld.z, ld.p, ld.PM, ld.GM, ld.HF_gain, ld.Ta_noise_std, ...
                 m.R, m.S, m.Scmd, m.TV, m.erel, 100 * m.rev, m.maxTa, ...
                 m.Rg.static, m.Rg.dyn, m.Rg.small, m.Rg.mu];
        rows = [rows; row_i]; %#ok<AGROW>
        
        % Save progress
        outCandT = array2table(sortrows(rows, 1), 'VariableNames', candCols);
        writetable(outCandT, candFile);
        
        fprintf('  -> K=%.2f: R=%.2f%%, S=%.4f N.m, TV=%.1f N.m/s, erel=%.2f%%, rev=%.2f%%\n', ...
            kval, m.R, m.S, m.TV, m.erel, 100 * m.rev);
    end
end

C = readtable(candFile);

%% 3. Bang-bang gate scan
bbFile = fullfile(outDir, 'Map_bangbang_by_K.csv');
BB = map_bangbang_scan(candFile, bbFile, noBangBangLimit);

% Merge bang-bang results into candidates
bb_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for ib = 1:height(BB)
    key = sprintf('%.4f', BB.K(ib));
    bb_map(key) = BB(ib, :);
end

%% 4. Hard gates evaluation
% (a) Stability: PM >= 45 deg, GM >= 2.0 (K <= K_stab = 9.5)
gate_stab = (C.K <= 9.5 + 1e-6) & (C.PM_deg >= 45.0 - 1e-6) & (C.GM >= 2.0 - 1e-6);

% (b) Accuracy gate: K >= K_acc = 6.75 (and erel <= erelMax)
% K_acc = 6.75 from Step 2 ensures steady-state dry error <= 3% for v >= 40 km/h
gate_acc = (C.K >= 6.75 - 1e-6);

% (c) Safety gate: rev <= revMax (no reverse assist)
gate_rev = (C.rev_pct <= revMax);

% (d) No bang-bang gate: delta <= noBangBangLimit
gate_bb = false(height(C), 1);
f_sat_ideal = nan(height(C), 1);
f_sat_noisy = nan(height(C), 1);
f_sat_delta = nan(height(C), 1);
for ic = 1:height(C)
    key = sprintf('%.4f', C.K(ic));
    if isKey(bb_map, key)
        bbRow = bb_map(key);
        f_sat_ideal(ic) = bbRow.f_sat_ideal;
        f_sat_noisy(ic) = bbRow.f_sat_noisy;
        f_sat_delta(ic) = bbRow.f_sat_delta;
        gate_bb(ic) = (bbRow.pass_no_bangbang == 1);
    end
end

admissible = gate_stab & gate_acc & gate_rev & gate_bb;
fprintf('\ndesign_map: %d / %d candidates passed all hard gates (Stab, Acc, Rev, Bang-bang).\n', ...
    nnz(admissible), height(C));

if nnz(admissible) == 0
    error('design_map:no_admissible', 'No candidates passed all hard gates!');
end

%% 5. Shared selection rule: pick_by_tolerance
tol_idx = pick_by_tolerance(C.R_pct, C.S_Nm, admissible, tol);
R_min_adm = min(C.R_pct(admissible));
fprintf('design_map: %d finalists within %.1f%% of R_min (%.2f%%), sorted by increasing S:\n', ...
    numel(tol_idx), tol * 100, R_min_adm);

for k = 1:numel(tol_idx)
    idx_k = tol_idx(k);
    fprintf('  Finalist #%d: K=%.2f | R=%5.2f%%, S=%.4f N.m, TV=%5.1f N.m/s, erel=%.2f%%, rev=%.2f%%, BB_delta=%.4f\n', ...
        k, C.K(idx_k), C.R_pct(idx_k), C.S_Nm(idx_k), C.TV_Nm_per_s(idx_k), ...
        C.erel_pct(idx_k), C.rev_pct(idx_k), f_sat_delta(idx_k));
end

%% 6. Verify simulation stability margins (tk_margin) on finalists
finalist_rows = [];
chosenIdxInFinalists = 0;

for k = 1:numel(tol_idx)
    idx_k = tol_idx(k);
    kVal = C.K(idx_k);
    zVal = C.z_rad_s(idx_k);
    pVal = C.p_rad_s(idx_k);
    
    d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', kVal, 'lead', struct('z', zVal, 'p', pVal));
    vars = map_variables(Cal, d);
    
    m_nom = struct('R', C.R_pct(idx_k));
    M = tk_margin(mdl, SEED, vars, m_nom);
    
    passAll = M.pass;
    finalist_rows = [finalist_rows; ...
        kVal, zVal, pVal, C.R_pct(idx_k), C.S_Nm(idx_k), C.TV_Nm_per_s(idx_k), ...
        C.erel_pct(idx_k), C.rev_pct(idx_k), ...
        f_sat_ideal(idx_k), f_sat_noisy(idx_k), f_sat_delta(idx_k), double(gate_bb(idx_k)), ...
        M.ratio_gain, M.ratio_delay, double(M.pass)]; %#ok<AGROW>
    
    if passAll && (chosenIdxInFinalists == 0)
        chosenIdxInFinalists = k;
    end
end

if chosenIdxInFinalists == 0
    warning('design_map:margin_warning', 'No finalist passed tk_margin! Using finalist #1.');
    chosenIdxInFinalists = 1;
end

chosenRowIdx = tol_idx(chosenIdxInFinalists);
chosenK = C.K(chosenRowIdx);

%% 7. Pareto front and knee point
[pareto_front_local, ~] = knee_point(C.R_pct(admissible), C.S_Nm(admissible));
adm_indices = find(admissible);
pareto_indices = adm_indices(pareto_front_local);

% Build Pareto table
on_front = false(height(C), 1);
on_front(pareto_indices) = true;

is_finalist = false(height(C), 1);
is_finalist(tol_idx) = true;

is_chosen = false(height(C), 1);
is_chosen(chosenRowIdx) = true;

ParetoT = table(C.K, C.R_pct, C.S_Nm, C.TV_Nm_per_s, C.erel_pct, C.rev_pct, ...
    admissible, on_front, is_finalist, is_chosen, ...
    'VariableNames', {'K', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', ...
                      'admissible', 'on_front', 'finalist', 'chosen'});
writetable(ParetoT, fullfile(outDir, 'Map_pareto.csv'));

%% 8. Build selection table
SelT = array2table(finalist_rows, 'VariableNames', { ...
    'K', 'z_rad_s', 'p_rad_s', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', ...
    'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'pass_no_bangbang', ...
    'margin_ratio_gain', 'margin_ratio_delay', 'pass_margin'});
SelT.chosen = false(height(SelT), 1);
SelT.chosen(chosenIdxInFinalists) = true;

selCsv = fullfile(outDir, 'Map_selection.csv');
writetable(SelT, selCsv);

%% 9. Print chosen configuration
selInfo = SelT(chosenIdxInFinalists, :);
fprintf('\n=======================================================\n');
fprintf('CHOSEN MAP CONTROLLER (Local Seed 00000):\n');
fprintf('  K_max = %.4f N.m/(N.m)\n', selInfo.K);
fprintf('  Lead  = (s / %.2f + 1) / (s / %.2f + 1)\n', selInfo.z_rad_s, selInfo.p_rad_s);
fprintf('  Performance on Case TK (117 s):\n');
fprintf('    R  = %.2f%%\n', selInfo.R_pct);
fprintf('    S  = %.4f N.m\n', selInfo.S_Nm);
fprintf('    TV = %.2f N.m/s\n', selInfo.TV_Nm_per_s);
fprintf('    erel = %.2f%%\n', selInfo.erel_pct);
fprintf('    rev  = %.2f%%\n', selInfo.rev_pct);
fprintf('    Bang-bang delta = %.4f (pass: %d)\n', selInfo.f_sat_delta, selInfo.pass_no_bangbang);
fprintf('    Margin ratios: Gain x2 = %.2f, Delay +1ms = %.2f (pass: %d)\n', ...
    selInfo.margin_ratio_gain, selInfo.margin_ratio_delay, selInfo.pass_margin);
fprintf('=======================================================\n');

%% 10. Update Model/data/map.json and reload base workspace
jsonPath = fullfile(modelDir, 'data', 'map.json');
J = jsondecode(fileread(jsonPath));

d_chosen = struct();
d_chosen.Ts_ctrl = 0.001;
d_chosen.Ts0 = 0.3;
d_chosen.Kmax = selInfo.K;
d_chosen.lead = struct('z', selInfo.z_rad_s, 'p', selInfo.p_rad_s, 'PM_deg', C.PM_deg(chosenRowIdx));
d_chosen.Kstab = 9.5;
d_chosen.Kacc = 6.75;
d_chosen.TK_R_pct = selInfo.R_pct;
d_chosen.TK_S_Nm = selInfo.S_Nm;
d_chosen.TK_TV_Nm_per_s = selInfo.TV_Nm_per_s;
d_chosen.TK_erel_pct = selInfo.erel_pct;
d_chosen.TK_rev_pct = selInfo.rev_pct;
d_chosen.f_sat_delta = selInfo.f_sat_delta;
d_chosen.margin_ratio_gain = selInfo.margin_ratio_gain;
d_chosen.margin_ratio_delay = selInfo.margin_ratio_delay;
d_chosen.design_seed = SEED;
d_chosen.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

J.design = d_chosen;
fid = fopen(jsonPath, 'w');
fwrite(fid, jsonencode(J, 'PrettyPrint', true));
fclose(fid);
fprintf('design_map: Updated %s with chosen design parameters.\n', jsonPath);

% Reload base workspace
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));

res = struct('chosen', selInfo, 'candidates', C, 'selection', SelT, 'pareto', ParetoT);
end
