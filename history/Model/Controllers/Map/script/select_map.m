function R = select_map(writeJson, erelMax)
%SELECT_MAP Gates and selection rule of QuyChuan v5 on the measured (g_min, K) pairs of run_calib_sweep.m (main table and the beyond-the-linear-limit tables).
%
%   R = select_map()            report only
%   R = select_map(true)        also: run the bang-bang report on the chosen point (two noisy seeds 0 and 1) and write the design to data/map.json
%   R = select_map(false, erelMax)   other e_rel limit (sensitivity 3 and 10 %)
%   Gates (QuyChuan 5.6, v5): (0) band constraint (6.2): the lag stage keeps |H_lag(j 2 pi 2 Hz)| >= 1/sqrt(2) (-3 dB; steering band 0.2-2 Hz); (1) stability with margin: calib_margin (gain x2 and delay +1 ms, the numeric-free instability criterion of 9.4), pre-screened by
%   the ratios R_gain/R, R_delay/R <= 2 stored in the table; (2) static accuracy e_rel <= 5 %. Bang-bang (5.4) and reverse assist (5.5) are REPORT ONLY.
%   Selection (6.2, 9.5): minimize J = R * S (pick_by_balance, a = 1) among the admissible pairs; the first of the J-ordered list that passes calib_margin is chosen.
%   Sensitivity printed: a = 0.5 and a = 2, and the former rule (R within 5 % of the smallest R, then the smallest S).
%   The lead-only control variant (g_min = 1.0) is selected by the same rule on its own rows.
%   Output R: struct with T (all pairs, J and gate flags), chosen, control (table rows).
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
if nargin < 1 || isempty(writeJson), writeJson = false; end
if nargin < 2 || isempty(erelMax), erelMax = 5.0; end
calibDir = result_dir('Map', 'Calib');

files = {'Map_CALIB_sweep_s00000.csv', 'Map_CALIB_sweepbeyondA_s00000.csv', 'Map_CALIB_sweepbeyondB_s00000.csv'};
T = table();
for k = 1:numel(files)
    f = fullfile(calibDir, files{k});
    if ~exist(f, 'file'), continue; end
    X = readtable(f);
    if ~ismember('comp_K', X.Properties.VariableNames), X.comp_K = X.K; end
    X = X(:, {'g_min', 'K', 'comp_K', 'z', 'p', 'z1', 'p1', 'PM_deg', 'GM', 'R_pct', 'S_Nm', 'Scmd_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', 'rev_events', 'rev_peak_Nm', ...
        'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'ratio_gain', 'ratio_delay'});
    if isempty(T), T = X; else, T = [T; X]; end %#ok<AGROW>
end
[~, iu] = unique(round(1000 * [T.g_min T.K]), 'rows', 'stable'); T = T(iu, :);

T.J = T.R_pct .* T.S_Nm;
T.g_screen = T.ratio_gain <= 2 & T.ratio_delay <= 2;
T.g_acc = T.erel_pct <= erelMax;
w2 = 2 * pi * 2;                                % 2 Hz, upper edge of the driver band (Nguyen 2025)
T.lag_gain_2Hz = ones(height(T), 1);
hasLag = isfinite(T.z1);
T.lag_gain_2Hz(hasLag) = sqrt((1 + (w2 ./ T.z1(hasLag)).^2) ./ (1 + (w2 ./ T.p1(hasLag)).^2));
T.g_band = T.lag_gain_2Hz >= 1 / sqrt(2) - 1e-9;   % the lag stage must not cut the steering band by more than 3 dB (QuyChuan 6.2)
T.admissible = T.g_screen & T.g_acc & T.g_band;
fprintf('select_map: %d distinct pairs; pass the margin screen %d, e_rel <= %g %% %d, band (lag gain at 2 Hz >= 0.707) %d; admissible %d\n', ...
    height(T), sum(T.g_screen), erelMax, sum(T.g_acc), sum(T.g_band), sum(T.admissible));

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
mdl = 'Model_Map'; if ~bdIsLoaded(mdl), load_system(mdl); end
Cal = calibrate_map_cached();

R = struct('T', T, 'chosen', [], 'control', []);
for variant = {'all', 'lead-only'}
    sel = T.admissible;
    if strcmp(variant{1}, 'lead-only'), sel = sel & T.g_min == 1; end
    if ~any(sel), fprintf('select_map [%s]: no admissible pair\n', variant{1}); continue; end
    idx = pick_by_balance(T.R_pct, T.S_Nm, sel, 1);
    chosen = 0;
    for k = 1:min(5, numel(idx))
        c = T(idx(k), :);
        M = calib_margin(mdl, 0, map_vars(Cal, c));
        fprintf('  J rank %d: g_min %.2f K %.2f J %.3f margin %d\n', k, c.g_min, c.K, c.J, M.pass);
        if M.pass, chosen = idx(k); break; end
    end
    if chosen == 0, warning('select_map:margin', 'no J-ranked finalist passed calib_margin; taking rank 1'); chosen = idx(1); end
    c = T(chosen, :);
    fprintf('select_map [%s]: CHOSEN g_min %.2f K %.2f | lead z %.2f p %.2f lag z1 %.2f p1 %.2f | R %.2f %% S %.4f TV %.1f J %.3f e_rel %.2f %% rev %.2f %% dBB %.4f\n', ...
        variant{1}, c.g_min, c.K, c.z, c.p, c.z1, c.p1, c.R_pct, c.S_Nm, c.TV_Nm_per_s, c.J, c.erel_pct, c.rev_pct, c.f_sat_delta);
    if strcmp(variant{1}, 'all')      % sensitivity: the choice without the band constraint (what J alone would give)
        sNb = T.g_screen & T.g_acc;
        iNb = pick_by_balance(T.R_pct, T.S_Nm, sNb, 1);
        fprintf('  sensitivity without the band constraint (J alone): g_min %.2f K %.2f (R %.2f %%, S %.4f, J %.3f)\n', ...
            T.g_min(iNb(1)), T.K(iNb(1)), T.R_pct(iNb(1)), T.S_Nm(iNb(1)), T.J(iNb(1)));
    end
    for a = [0.5 2]
        i2 = pick_by_balance(T.R_pct, T.S_Nm, sel, a);
        fprintf('  sensitivity a = %g: g_min %.2f K %.2f (R %.2f %%, S %.4f)\n', a, T.g_min(i2(1)), T.K(i2(1)), T.R_pct(i2(1)), T.S_Nm(i2(1)));
    end
    i3 = pick_by_tolerance(T.R_pct, T.S_Nm, sel, 0.05);
    fprintf('  former rule (R within 5 %%, then S): g_min %.2f K %.2f (R %.2f %%, S %.4f)\n', T.g_min(i3(1)), T.K(i3(1)), T.R_pct(i3(1)), T.S_Nm(i3(1)));
    if strcmp(variant{1}, 'all'), R.chosen = c; else, R.control = c; end
end
writetable(T, fullfile(calibDir, 'Map_CALIB_pick_s00000.csv'));

if writeJson && ~isempty(R.chosen)
    c = R.chosen;
    B = calib_bangbang(mdl, 0, map_vars(Cal, c));     % report only (QuyChuan 5.4): seeds 0 and 1
    fprintf('select_map: bang-bang report f_ideal %.4f f_noisy %.4f f_noisy2 %.4f delta %.4f spread %.4f\n', B.f_ideal, B.f_noisy, B.f_noisy2, B.delta, B.disp);
    jsonPath = fullfile(modelDir, 'data', 'map.json');
    J = jsondecode(fileread(jsonPath));
    d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', c.K, 'g_min', c.g_min, 'lead', struct('z', c.z, 'p', c.p), 'PM_deg', c.PM_deg, 'GM', c.GM);
    if isfinite(c.z1), d.lag = struct('z1', c.z1, 'p1', c.p1); end
    d.rule = 'J = R*S with lag gain at 2 Hz >= 0.707 (QuyChuan v5)'; d.CALIB_J = c.J; d.lag_gain_2Hz = c.lag_gain_2Hz;
    d.CALIB_R_pct = c.R_pct; d.CALIB_S_Nm = c.S_Nm; d.CALIB_TV_Nm_per_s = c.TV_Nm_per_s; d.CALIB_erel_pct = c.erel_pct; d.CALIB_rev_pct = c.rev_pct;
    d.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'f_noisy2', B.f_noisy2, 'delta', B.delta, 'spread', B.disp);
    d.margin_ratio_gain = c.ratio_gain; d.margin_ratio_delay = c.ratio_delay;
    d.design_seed = 0; d.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = d;
    fid = fopen(jsonPath, 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_map: wrote design to %s\n', jsonPath);
end
end

function v = map_vars(Cal, c)
% base-workspace variables of one table row (compensator and slope limit)
d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', c.K, 'lead', struct('z', c.z, 'p', c.p), 'lag', struct('z1', c.z1, 'p1', c.p1));
v = map_variables(Cal, d);
end
