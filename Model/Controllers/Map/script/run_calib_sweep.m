function T = run_calib_sweep(pairs, seed, compK, outCsv)
%RUN_CALIB_SWEEP Simulate the lead-lag Map on case CALIB for a list of (g_min, K) pairs (DieuKhien_Map.txt A8, B8; QuyChuan 6.1, 6.7).
%
%   T = run_calib_sweep(pairs)        pairs = N x 2 [g_min K]; g_min 1.0 = lead only (control variant); the compensator (z, p, z1, p1) of each pair
%                                     is read from Result/Controllers/Map/Design/Map_design_leadlag.csv (made by sweep_leadlag.m for that pair)
%   T = run_calib_sweep(pairs, seed)  seed = run seed of the noisy sensors (default 0 = Map's local seed 00000)
%   T = run_calib_sweep(pairs, seed, compK, outCsv)   BEYOND THE LINEAR LIMIT (QuyChuan 6.1 test): compK(i) = the K whose designed compensator is used for pair i
%                                     (the largest K with PM >= 45 of that level) while the table slope is pairs(i,2) > compK(i); NaN = same K; the
%                                     linear columns PM, GM, HF, noise are then NaN (they are not valid for the raised K); rows go to outCsv
%
%   Four CALIB simulations per pair, all with the SAME compensator and slope limit:
%     1. noisy sensors            R, S, TV, e_rel (per static window), e_ext, reverse assist (fraction, events, peak), command at the limit f_noisy
%     2. ideal sensors            f_ideal (no-bang-bang gate: delta = f_noisy - f_ideal)
%     3. actuator gain x 2        R_gain (margin gate: R_gain / R <= 2)
%     4. controller delay + 1 ms  R_delay (same gate)
%   One row per pair is appended to Result/Controllers/Map/Calib/Map_CALIB_sweep_s00000.csv as soon as it is finished (a rerun skips pairs already there).
%   Gates are NOT applied here: the file holds the measurements; the selection (select_map.m) applies them.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
if nargin < 2 || isempty(seed), seed = 0; end
if nargin < 3 || isempty(compK), compK = nan(size(pairs, 1), 1); end

designCsv = fullfile(result_dir('Map', 'Design'), 'Map_design_leadlag.csv');
if nargin < 4 || isempty(outCsv), outCsv = fullfile(result_dir('Map', 'Calib'), 'Map_CALIB_sweep_s00000.csv'); end
D = readtable(designCsv);

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
mdl = 'Model_Map';
if ~bdIsLoaded(mdl), load_system(mdl); end
Cal = calibrate_map_cached();
S = make_cases('CALIB');
bp = evalin('base', 'Tamax_v_bp_ms'); tb = evalin('base', 'Tamax_table');
lim = interp1(bp(:), tb(:), min(max(S.v, bp(1)), bp(end)), 'linear');
scored = S.t >= 2;

if exist(outCsv, 'file'), T = readtable(outCsv); else, T = table(); end
for ip = 1:size(pairs, 1)
    g = pairs(ip, 1); K = pairs(ip, 2);
    if ~isempty(T) && any(abs(T.g_min - g) < 1e-9 & abs(T.K - K) < 1e-9), continue; end
    Kc = compK(ip); if isnan(Kc), Kc = K; end
    id = find(abs(D.g_min - g) < 1e-9 & abs(D.K - Kc) < 1e-9 & D.ok == 1, 1);
    assert(~isempty(id), 'no designed compensator for g_min %g, K %g: run sweep_leadlag first', g, Kc);
    lin = ones(1, 5); if Kc ~= K, lin = nan(1, 5); end   % PM, GM, wc, HF, noise are valid only when the compensator was designed for this K
    d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', K, 'lead', struct('z', D.z(id), 'p', D.p(id)), ...
               'lag', struct('z1', D.z1(id), 'p1', D.p1(id)));
    vars = map_variables(Cal, d);
    t0 = tic;
    [L, m] = calib_run(mdl, seed, vars);                                  % 1. noisy
    fNoisy = mean(abs(L.T_a_cmd(scored)) >= 0.999 * lim(scored));
    [Li, ~] = calib_run(mdl, [], vars);                                   % 2. ideal
    fIdeal = mean(abs(Li.T_a_cmd(scored)) >= 0.999 * lim(scored));
    vg = vars; vg.act_gain_mult = 2; vg.ctrl_delay = 0;                   % 3. gain x 2
    [~, mg] = calib_run(mdl, seed, vg);
    vd = vars; vd.act_gain_mult = 1; vd.ctrl_delay = 0.001;               % 4. delay + 1 ms
    [~, md] = calib_run(mdl, seed, vd);

    % reverse assist events: |T_s| >= 0.5 N.m and T_a against T_s, scored samples
    rv = scored & abs(L.T_s) >= 0.5 & L.T_a .* L.T_s < 0;
    edges = diff([0; rv(:); 0]);
    nEv = sum(edges == 1);
    peak = 0; if any(rv), peak = max(abs(L.T_a(rv))); end

    row = table(g, K, D.z(id), D.p(id), D.z1(id), D.p1(id), D.PM_deg(id) * lin(1), D.GM(id) * lin(2), D.wc_rad_s(id) * lin(3), D.HF_gain(id) * lin(4), D.Ta_noise_std_Nm(id) * lin(5), ...
        m.R, m.S, m.Scmd, m.TV, m.maxTa, m.erel, 100 * m.rev, nEv, peak, ...
        m.Rg.static, m.Rg.dyn, m.Rg.mu, fIdeal, fNoisy, fNoisy - fIdeal, mg.R, md.R, mg.R / m.R, md.R / m.R, toc(t0), ...
        'VariableNames', {'g_min', 'K', 'z', 'p', 'z1', 'p1', 'PM_deg', 'GM', 'wc_rad_s', 'HF_gain', 'Ta_noise_lin_Nm', ...
        'R_pct', 'S_Nm', 'Scmd_Nm', 'TV_Nm_per_s', 'maxTa_Nm', 'erel_pct', 'rev_pct', 'rev_events', 'rev_peak_Nm', ...
        'Rg_static_pct', 'Rg_dyn_pct', 'Rg_mu_pct', 'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'R_gain_pct', 'R_delay_pct', ...
        'ratio_gain', 'ratio_delay', 'seconds'});
    row.comp_K = Kc;
    for k = 1:numel(m.erelWin), row.(sprintf('erel_%s', m.erelLabel{k})) = m.erelWin(k); end
    if ~isempty(T) && ~ismember('comp_K', T.Properties.VariableNames), T.comp_K = T.K; end   % files written before compK existed
    if isempty(T), T = row; else, T = [T; row]; end %#ok<AGROW>
    writetable(T, outCsv);
    fprintf('run_calib_sweep: g_min %.2f K %5.2f | R %6.2f %% S %.4f e_rel %6.2f %% rev %.2f %% (%d ev, peak %.2f) dBB %.4f gain x%.2f delay x%.2f | %.0f s\n', ...
        g, K, m.R, m.S, m.erel, 100 * m.rev, nEv, peak, fNoisy - fIdeal, mg.R / m.R, md.R / m.R, toc(t0));
end
end
