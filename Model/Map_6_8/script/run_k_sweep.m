function R = run_k_sweep(Ks, seeds, level)
%RUN_K_SWEEP Choose the map slope K_max by sweeping it on the calibration case TK (response versus smoothness).
%
%   R = run_k_sweep()                                     K_max = 3 4 5 6 7 8 9 10 12 15 18, seeds 91001:91003, level 'high'
%   R = run_k_sweep(Ks, seeds, level)
%
%   For every K_max: calibrate_map(K) gives the torque map and the lead stage (designed with the motor lag of the Actuator, PM >= 45 deg
%   over the whole map slope range, or infeasible), then the closed loop Model_Map_6_8_s (build it first with build_closed_loop('Map_6_8'), run
%   load_map_6_8.m first) runs the case TK (test_cases('TK'), dry road, 3 speeds) with the sensors of data/sensors.json at the given level
%   and every seed (noise seeds 91001... are outside the training range of RL (1-9999) and the scoring range of the pair comparisons
%   (90001-90010)). Per run, on the TRUE signals, first 2 s not scored:
%     R   response     RMS e_T over ALL scored windows of TK (hard cornering, sine, small corrections) [N.m]: the steady error at the top of the
%                      calibration range (where K_max limits the assist) and the dynamic error both count
%     S   smoothness   RMS of T_a high-passed at 5 Hz over the whole case [N.m] (the part of T_a that no driver command can explain:
%                      steering bandwidth is below 2 Hz), and the total variation of T_a [N.m/s]
%     e_rel  steady accuracy: |mean e_T| / mean |T_d,ref| over the hard-cornering windows [%], worst of the 3 speeds (reported only, flag e_rel <= 3 %;
%            not a gate: with the motor lag the 45 deg phase margin and 3 % cannot both be met, see the summary)
%   Gate: lead stage feasible (PM >= 45 deg over the whole slope range, [1] Sec. III.D). The sweep uses ONE K_max for every speed; the speed tiers
%   of the map (Documents/Map_6_8/map.txt section 2.5) are chosen from this sweep together with scan_k_by_speed.m.
%   Writes Result/Map_6_8/KSweep/: Map_k_sweep_summary.csv (mean and std over the seeds), Map_k_sweep_all_runs.csv, Map_k_sweep_pareto.png.
%   Returns the summary table.

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script'));
if nargin < 1, Ks = [3 4 5 6 7 8 9 10 12 15 18]; end
if nargin < 2, seeds = 91001:91003; end
if nargin < 3, level = 'high'; end
mdl = 'Model_Map_6_8_s';
S = test_cases('TK');
outDir = result_dir('Map_6_8', 'KSweep');
if ~bdIsLoaded(mdl), load_system(fullfile(modelDir, [mdl '.mdl'])); end

win = S.win;
isSteady = startsWith({win.label}, 'steady');
rows = [];
for ik = 1:numel(Ks)
    K = Ks(ik);
    cal = calibrate_map(K, '');
    for seed = seeds
        L = runTK(mdl, S, cal, level, seed);
        m = metrics(L, S, win, isSteady);
        rows = [rows; K, seed, cal.lead.min_phase_margin_deg, cal.lead.feasible, cal.lead.pole_rad_s / cal.lead.zero_rad_s, ...
            m.R, m.S, m.TV, m.erel, m.maxTa]; %#ok<AGROW>
        fprintf('run_k_sweep: K=%g seed %d  PM %.1f%s  R %.3f  S %.3f  TV %.0f  e_rel %.2f%%\n', K, seed, cal.lead.min_phase_margin_deg, ...
            ternary(cal.lead.feasible, '', ' (infeasible)'), m.R, m.S, m.TV, m.erel);
    end
end
all = array2table(rows, 'VariableNames', {'K_max', 'seed', 'PM_deg', 'feasible', 'lead_p_over_z', 'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', ...
    'TV_Ta_Nm_per_s', 'e_rel_pct', 'MaxAbs_Ta_Nm'});
writetable(all, fullfile(outDir, 'Map_k_sweep_all_runs.csv'));
G = groupsummary(all, 'K_max', {'mean', 'std'}, {'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', 'e_rel_pct'});
G.PM_deg = splitapply(@(x) x(1), all.PM_deg, findgroups(all.K_max));
G.feasible = splitapply(@(x) x(1), all.feasible, findgroups(all.K_max));
G.lead_p_over_z = splitapply(@(x) x(1), all.lead_p_over_z, findgroups(all.K_max));
G.pass = G.feasible == 1;
G.erel_ok = G.mean_e_rel_pct <= 3;
writetable(G, fullfile(outDir, 'Map_k_sweep_summary.csv'));

fprintf('\nK_max with PM >= 45 deg: %s ; with e_rel <= 3 %%: %s\n', mat2str(G.K_max(G.pass)'), mat2str(G.K_max(G.erel_ok)'));

plotPareto(G, fullfile(outDir, 'Map_k_sweep_pareto.png'));
R = G;
end

%% ===================== one run =====================
function L = runTK(mdl, S, cal, level, seed)
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_v',      [S.t S.v]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    V = sensor_noise_vars(level, seed);
    fn = fieldnames(V);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, V.(fn{k})); end
    in = in.setVariable('map_Ta_table', cal.Ta_table_Nm);
    in = in.setVariable('map_lead_num', cal.lead.num(:)');
    in = in.setVariable('map_lead_den', cal.lead.den(:)');
    in = in.setVariable('map_lead_hi_num', cal.lead.num(:)');   % one K_max for every speed: same lead stage in both tiers
    in = in.setVariable('map_lead_hi_den', cal.lead.den(:)');
    so = sim(in);
    L.t = S.t;
    for nm = {'T_s', 'T_d_ref', 'e_T', 'T_a'}
        ts = so.get(['log_' nm{1}]);
        [tu, iu] = unique(ts.Time, 'last');
        L.(nm{1}) = interp1(tu, squeeze(ts.Data(iu)), S.t, 'linear', 'extrap');
    end
end

function m = metrics(L, S, win, isSteady)
    w = L.t >= 2;
    inResp = false(size(L.t));
    for j = 1:numel(win), inResp = inResp | (L.t >= win(j).t0 & L.t <= win(j).t1); end
    m.R = sqrt(mean(L.e_T(inResp).^2));
    dt = L.t(2) - L.t(1);
    a = dt / (1 / (2 * pi * 5) + dt);
    lp = filter(a, [1 -(1 - a)], L.T_a);
    hp = L.T_a - lp;
    m.S = sqrt(mean(hp(w).^2));
    m.TV = sum(abs(diff(L.T_a(w)))) / (L.t(end) - 2);
    m.maxTa = max(abs(L.T_a(w)));
    er = zeros(1, nnz(isSteady));
    k = 0;
    for j = find(isSteady)
        k = k + 1;
        in = L.t >= win(j).t0 & L.t <= win(j).t1;
        er(k) = 100 * abs(mean(L.e_T(in))) / max(mean(abs(L.T_d_ref(in))), eps);
    end
    m.erel = max(er);
end

function r = ternary(c, a, b)
    if c, r = a; else, r = b; end
end

%% ===================== figures =====================
function plotPareto(G, file)
    f = figure('Visible', 'off', 'Position', [50 50 1000 700]); hold on;
    for i = 1:height(G)
        if G.pass(i), c = [0.165 0.471 0.839]; mk = 'o'; else, c = [0.6 0.6 0.6]; mk = 's'; end
        errorbar(G.mean_S_HF_RMS_Ta_Nm(i), G.mean_R_RMS_eT_Nm(i), G.std_R_RMS_eT_Nm(i), G.std_R_RMS_eT_Nm(i), G.std_S_HF_RMS_Ta_Nm(i), ...
            G.std_S_HF_RMS_Ta_Nm(i), mk, 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 8);
        text(G.mean_S_HF_RMS_Ta_Nm(i) * 1.03, G.mean_R_RMS_eT_Nm(i) * 1.03, sprintf('K=%g', G.K_max(i)));
    end
    set(gca, 'XScale', 'log', 'YScale', 'log'); grid on;
    xlabel('S: RMS of T_a above 5 Hz [N.m]  (smoother to the left)'); ylabel('R: RMS e_T over all scored windows [N.m]  (better down)');
    title('Case TK: response versus smoothness (blue = PM >= 45 deg, grey = PM < 45 deg)');
    exportgraphics(f, file, 'Resolution', 130); close(f);
end
