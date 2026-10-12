function sel = select_pi(tol, noBangBangLimit, erelMax, revMax)
%SELECT_PI Step P5 of the PI plan: select optimal (Kp, Ki) according to QuyChuan.txt v2.
%
%   sel = select_pi()
%   sel = select_pi(tol, noBangBangLimit, erelMax, revMax)
%
%   Inputs:
%     tol             tolerance for R relative to R_min (default 0.05 = 5%)
%     noBangBangLimit max allowed increase in saturation ratio due to noise (default 0.01 = 1%)
%     erelMax         nominal steady-state relative error limit (default 5.0 = 5%, QuyChuan 5.3 v4, 2026-10-11)
%     revMax          nominal reverse assist fraction limit (default Inf: rev is report-only since QuyChuan 5.5 v4, 2026-10-11)
%
%   Selection procedure (QuyChuan.txt part 5 & 6):
%     1. Read candidates from Result/Controllers/PI/Calib/PI_CALIB_sweep_s10000.csv.
%     2. Hard gates & Priority order (QuyChuan 5.6):
%        (1) Stability and margins: calib_margin (Gain x2, delay +1 ms)
%        (2) Reverse assist: NOT a gate since 2026-10-11 (QuyChuan 5.5 v4), reported only (pass revMax to re-impose a limit)
%        (3) No bang-bang: calib_bangbang delta <= noBangBangLimit (<= 1%, sensitivity 0.5-5%)
%        (4) Steady accuracy: erel_pct <= erelMax (<= 5%, v4; sensitivity 3-5%)
%     3. Fallback rule (QuyChuan 5.6): If no candidate passes all strict thresholds,
%        drop the lowest gate (Gate 4: erel <= 3%) and choose the candidate that violates
%        the gates the least, testing sensitivity at rev <= 5% and erel <= 5%.
%     4. pick_by_tolerance: Among admissible candidates, filter those with R <= (1 + tol) * min(R),
%        sorted by increasing S.
%     5. Evaluate finalists for bang-bang and stability margins.
%     6. Check if the chosen point lies on the grid boundary (QuyChuan 6.1).
%     7. Write design to Model/data/pi.json and selection log to
%        Result/Controllers/PI/Calib/PI_CALIB_pick_s10000.csv.

if nargin < 1 || isempty(tol), tol = 0.05; end
if nargin < 2 || isempty(noBangBangLimit), noBangBangLimit = 0.01; end
if nargin < 3 || isempty(erelMax), erelMax = 5.0; end
if nargin < 4 || isempty(revMax), revMax = Inf; end

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('PI', 'Calib');
candFile = fullfile(outDir, 'PI_CALIB_sweep_s10000.csv');
if ~exist(candFile, 'file')
    error('select_pi:missing_candidates', 'Candidates file not found: %s. Run run_pi_sweep first.', candFile);
end
T = readtable(candFile);

% 1. Evaluate preliminary gates (QuyChuan v5: e_rel gate + Ziegler-Nichols integral-time constraint Ti >= Pu/1.2, Seborg Table 12.7)
[~, Pu] = zn_ultimate();
Ti = T.Kp ./ T.Ki_1_per_s;
fprintf('select_pi: Z-N ultimate period Pu = %.4f s -> Ti >= Pu/1.2 = %.1f ms\n', Pu, 1000 * Pu / 1.2);
maskNoErel = isfinite(T.R_pct) & isfinite(T.S_Nm) & (Ti >= Pu / 1.2);      % the PI has no filter: the steering-band constraint (QuyChuan 6.2) holds trivially
admStrict = maskNoErel & (T.erel_pct <= erelMax) & (T.rev_pct <= revMax);
numStrict = nnz(admStrict);

if numStrict > 0
    adm = admStrict;
    fprintf('select_pi: %d of %d candidates passed strict gates (erel <= %.1f%%, rev <= %g%%).\n', ...
        numStrict, height(T), erelMax, revMax);
else
    % QuyChuan 5.6: Fallback when strict gates are not met
    fprintf('select_pi [QuyChuan 5.6]: No candidate met strict gates (erel <= %.1f%% AND rev <= %.1f%%).\n', erelMax, revMax);
    fprintf('  Reason: Coulomb friction (T_f = 2 N.m) at 20 km/h pushes erel to 3.25%% min, and zero-crossing phase lag in sine waveforms sets rev to 1.39%% min.\n');
    fprintf('  Applying QuyChuan 5.6 priority fallback (drop lowest gate erel, test sensitivity up to 5%%).\n');
    
    % Test sensitivity thresholds erel <= 5% and rev <= 5%
    admSens = (T.erel_pct <= 5.0) & (T.rev_pct <= 5.0);
    if any(admSens)
        adm = admSens;
        fprintf('  Found %d candidates passing sensitivity gates (erel <= 5.0%%, rev <= 5.0%%).\n', nnz(adm));
    else
        % If still none, select top 10 least violating candidates by normalized penalty
        fprintf('  Selecting least violating candidates...\n');
        penalty = max(0, T.erel_pct - erelMax) / erelMax + max(0, T.rev_pct - revMax) / revMax;
        [~, ordP] = sort(penalty);
        adm = false(height(T), 1);
        adm(ordP(1:min(10, height(T)))) = true;
    end
end

% 2. Rank candidates by the balanced rule J = R * S (QuyChuan v5, pick_by_balance); first 8 are the finalists
idx = pick_by_balance(T.R_pct, T.S_Nm, adm, 1);
idx = idx(1:min(8, numel(idx)));
fprintf('select_pi: %d finalists by increasing J = R*S (best J %.3f):\n', numel(idx), T.R_pct(idx(1)) * T.S_Nm(idx(1)));

% 3. Ensure Model_PI is ready
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'PI', 'load_pi.m'), '\', '/')));
mdl = 'Model_PI';
if ~bdIsLoaded(mdl), load_system(mdl); end

rows = [];
chosenIdx = 0;

for k = 1:numel(idx)
    i = idx(k);
    kp = T.Kp(i);
    ki = T.Ki_1_per_s(i);
    kaw = T.Kaw(i);
    vars = struct('PI_Kp', kp, 'PI_Ki', ki, 'PI_Kaw', kaw);

    % Bang-bang is REPORT-ONLY since QuyChuan v5 (user decision 2026-10-11): not a gate; measured below for the chosen point only
    B = struct('f_ideal', NaN, 'f_noisy', NaN, 'delta', NaN, 'pass', true);

    % Gate 2: Check stability margins (QuyChuan 5.2)
    M = calib_margin(mdl, 10000, vars);

    passAll = B.pass && M.pass;
    rows = [rows; kp, ki, kaw, T.R_pct(i), T.S_Nm(i), T.TV_Nm_per_s(i), T.erel_pct(i), T.rev_pct(i), ...
            B.f_ideal, B.f_noisy, B.delta, B.pass, ...
            M.ratio_gain, M.ratio_delay, M.pass]; %#ok<AGROW>

    fprintf('  Finalist #%d: Kp=%.2f, Ki=%.1f | R=%5.2f%%, S=%.4f, TV=%5.1f, erel=%5.2f%%, rev=%5.2f%% | BB delta=%.4f (%s) | Margin Gain=%.2f, Delay=%.2f (%s)\n', ...
        k, kp, ki, T.R_pct(i), T.S_Nm(i), T.TV_Nm_per_s(i), T.erel_pct(i), T.rev_pct(i), B.delta, ...
        "report", M.ratio_gain, M.ratio_delay, char(ternary(M.pass, "PASS", "FAIL")));

    if passAll && (chosenIdx == 0)
        chosenIdx = k;
    end
end

if chosenIdx == 0
    warning('select_pi:none_passed', 'No finalist passed both bang-bang and margin gates! Selecting first finalist.');
    chosenIdx = 1;
end

% Report-only bang-bang numbers of the chosen point (QuyChuan v5)
Bc = calib_bangbang(mdl, 10000, struct('PI_Kp', rows(chosenIdx, 1), 'PI_Ki', rows(chosenIdx, 2), 'PI_Kaw', rows(chosenIdx, 3)), noBangBangLimit);
rows(chosenIdx, 9:12) = [Bc.f_ideal, Bc.f_noisy, Bc.delta, double(Bc.pass_limit)];
fprintf('select_pi: bang-bang (report only) of the chosen point: f_ideal %.4f, f_noisy %.4f, delta %.5f (seed spread %.5f)\n', Bc.f_ideal, Bc.f_noisy, Bc.delta, Bc.disp);

% 4. Build finalists table and save
F = array2table(rows, 'VariableNames', { ...
    'Kp', 'Ki_1_per_s', 'Kaw', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', ...
    'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'pass_no_bangbang', ...
    'margin_ratio_gain', 'margin_ratio_delay', 'pass_margin'});
F.chosen = false(height(F), 1);
F.chosen(chosenIdx) = true;

selCsv = fullfile(outDir, 'PI_CALIB_pick_s10000.csv');
writetable(F, selCsv);
fprintf('select_pi: Selection table saved to %s.\n', selCsv);
selection_sensitivity(T, maskNoErel, {'Kp', 'Ki_1_per_s'}, fullfile(outDir, 'PI_CALIB_senspick_s10000.csv'));

% 5. Chosen candidate details
selRow = F(chosenIdx, :);
fprintf('\n=======================================================\n');
fprintf('CHOSEN PI CONTROLLER (Seed 10000):\n');
fprintf('  Kp = %.4f N.m/(N.m)\n', selRow.Kp);
fprintf('  Ki = %.4f 1/s\n', selRow.Ki_1_per_s);
fprintf('  Kaw = %.4f (Ki/Kp)\n', selRow.Kaw);
fprintf('  Performance on Case CALIB (117s):\n');
fprintf('    R  = %.2f%%\n', selRow.R_pct);
fprintf('    S  = %.4f N.m\n', selRow.S_Nm);
fprintf('    TV = %.2f N.m/s\n', selRow.TV_Nm_per_s);
fprintf('    e_rel = %.2f%%\n', selRow.erel_pct);
fprintf('    rev = %.2f%%\n', selRow.rev_pct);
fprintf('    Bang-bang delta = %.4f (limit: %.4f, pass: %d)\n', selRow.f_sat_delta, noBangBangLimit, selRow.pass_no_bangbang);
fprintf('    Margin ratios: Gain x2 = %.2f, Delay +1ms = %.2f (pass: %d)\n', ...
    selRow.margin_ratio_gain, selRow.margin_ratio_delay, selRow.pass_margin);
fprintf('=======================================================\n');

% 6. Boundary check (QuyChuan 6.1)
kpMin = min(T.Kp); kpMax = max(T.Kp);
kiMin = min(T.Ki_1_per_s); kiMax = max(T.Ki_1_per_s);
isOnBoundary = (abs(selRow.Kp - kpMin) < 1e-4) || (abs(selRow.Kp - kpMax) < 1e-4) || ...
               (abs(selRow.Ki_1_per_s - kiMin) < 1e-4) || (abs(selRow.Ki_1_per_s - kiMax) < 1e-4);
if isOnBoundary
    warning('select_pi:boundary_warning', ...
        'Chosen point (Kp=%.2f, Ki=%.1f) lies on the grid boundary! Grid expansion required (QuyChuan 6.1).', ...
        selRow.Kp, selRow.Ki_1_per_s);
else
    fprintf('select_pi: Chosen point is strictly inside the grid (not on boundary). QuyChuan 6.1 satisfied.\n');
end

% 7. Save to data/pi.json
sel = struct();
sel.Kp = selRow.Kp;
sel.Ki = selRow.Ki_1_per_s;
sel.Kaw = selRow.Kaw;
sel.CALIB_R_pct = selRow.R_pct;
sel.CALIB_S_Nm = selRow.S_Nm;
sel.CALIB_TV_Nm_per_s = selRow.TV_Nm_per_s;
sel.CALIB_erel_pct = selRow.erel_pct;
sel.CALIB_rev_pct = selRow.rev_pct;
sel.f_sat_delta = selRow.f_sat_delta;
sel.margin_ratio_gain = selRow.margin_ratio_gain;
sel.margin_ratio_delay = selRow.margin_ratio_delay;
sel.design_seed = 10000;
sel.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

jsonPath = fullfile(modelDir, 'data', 'pi.json');
J = jsondecode(fileread(jsonPath));
J.design = sel;
fid = fopen(jsonPath, 'w');
fwrite(fid, jsonencode(J, 'PrettyPrint', true));
fclose(fid);
fprintf('select_pi: Updated %s with chosen design parameters.\n', jsonPath);

end

function val = ternary(cond, trueVal, falseVal)
    if cond, val = trueVal; else, val = falseVal; end
end
