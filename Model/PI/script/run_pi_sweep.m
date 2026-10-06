function R = run_pi_sweep(seeds, level)
%RUN_PI_SWEEP Choose the crossover frequency of the PI by sweeping it on the calibration case TK (response versus smoothness).
%
%   R = run_pi_sweep()                    every feasible row of Result/PI/Design/PI_design_grid.csv, seeds 91001:91003, level 'high'
%   R = run_pi_sweep(seeds, level)
%
%   Same protocol and the same metric definitions as Map/script/run_k_sweep.m (Documents/Map_6_8/map.txt section 2.5), so the two sweeps are
%   comparable: case TK (test_cases('TK'), dry road, 3 speeds), sensors of data/sensors.json at the given level, noise seeds 91001-91003
%   (outside the training range of RL and the scoring range 90001-90010), first 2 s not scored, all metrics on the TRUE signals:
%     R      RMS e_T over all scored windows of TK [N.m]            response
%     S      RMS of T_a high-passed at 5 Hz over the case [N.m]    smoothness; TV = total variation of T_a [N.m/s]
%     e_rel  steady accuracy |mean e_T| / mean |T_d,ref| over the hard-cornering windows [%], worst of the 3 speeds (reported only)
%   For every design point (Kp, Ki, Kaw = 1/Ti of design_pi.m) the closed loop Model_PI_s runs every seed. The Map in its final form
%   (two speed tiers, data/map.json) is run on the same case, level and seeds as the reference point.
%   Selection rule (fixed before looking at the results): among the points with R <= 1.02 * (smallest R of the sweep), the one with the
%   smallest S. The same rule applied to the single-K sweep of the Map (Result/Map_6_8/KSweep) is reported next to it.
%   Writes Result/PI/Sweep/: PI_sweep_all_runs.csv, PI_sweep_summary.csv, PI_sweep_selection.csv, PI_sweep_pareto.png. Returns the summary.
%   Run first: load_pi.m and build PID_s (build_pi.m) and Model_PI_s (build_closed_loop('PI')); Model_Map_6_8_s must exist.

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); addpath(fullfile(modelDir, 'Sim', 'script'));
if nargin < 1, seeds = 91001:91003; end
if nargin < 2, level = 'high'; end
outDir = result_dir('PI', 'Sweep');
D = readtable(fullfile(result_dir('PI', 'Design'), 'PI_design_grid.csv'));
D = D(D.feasible == 1, :);
S = test_cases('TK');
win = S.win;
isSteady = startsWith({win.label}, 'steady');

mdl = 'Model_PI_s';
if ~bdIsLoaded(mdl), load_system(fullfile(modelDir, [mdl '.mdl'])); end
rows = [];
for i = 1:height(D)
    for seed = seeds
        L = runTK(mdl, S, level, seed, struct('Kp', D.Kp(i), 'Ki', D.Ki_1_per_s(i), 'Kaw', D.Ki_1_per_s(i) / D.Kp(i)));
        m = metrics(L, win, isSteady);
        rows = [rows; D.wc_design_rad_s(i), seed, D.Kp(i), D.Ki_1_per_s(i), m.R, m.S, m.TV, m.erel, m.maxTa]; %#ok<AGROW>
        fprintf('run_pi_sweep: wc %g seed %d  Kp %.4g Ki %.4g  R %.3f  S %.4f  TV %.1f  e_rel %.2f%%\n', D.wc_design_rad_s(i), seed, D.Kp(i), ...
            D.Ki_1_per_s(i), m.R, m.S, m.TV, m.erel);
    end
end
all = array2table(rows, 'VariableNames', {'wc_design_rad_s', 'seed', 'Kp', 'Ki_1_per_s', 'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', ...
    'e_rel_pct', 'MaxAbs_Ta_Nm'});
writetable(all, fullfile(outDir, 'PI_sweep_all_runs.csv'));
G = groupsummary(all, 'wc_design_rad_s', {'mean', 'std'}, {'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', 'e_rel_pct'});
G.Kp = splitapply(@(x) x(1), all.Kp, findgroups(all.wc_design_rad_s));
G.Ki_1_per_s = splitapply(@(x) x(1), all.Ki_1_per_s, findgroups(all.wc_design_rad_s));
writetable(G, fullfile(outDir, 'PI_sweep_summary.csv'));

% ----- the Map in its final form on the same case, level and seeds (reference point) -----
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'load_map_6_8.m'), '\', '/')));
mapMdl = 'Model_Map_6_8_s';
if ~bdIsLoaded(mapMdl), load_system(fullfile(modelDir, [mapMdl '.mdl'])); end
mr = [];
for seed = seeds
    L = runTK(mapMdl, S, level, seed, struct());
    m = metrics(L, win, isSteady);
    mr = [mr; m.R, m.S, m.TV, m.erel]; %#ok<AGROW>
    fprintf('run_pi_sweep: Map (final) seed %d  R %.3f  S %.4f  TV %.1f  e_rel %.2f%%\n', seed, m.R, m.S, m.TV, m.erel);
end
mapFinal = mean(mr, 1);
writetable(table(mapFinal(1), mapFinal(2), mapFinal(3), mapFinal(4), 'VariableNames', {'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm', 'TV_Ta_Nm_per_s', 'e_rel_pct'}), ...
    fullfile(outDir, 'Map_final_TK_reference.csv'));

% ----- selection (rule fixed in advance) -----
sel = selectPoint(G.wc_design_rad_s, G.mean_R_RMS_eT_Nm, G.mean_S_HF_RMS_Ta_Nm);
mk = readtable(fullfile(result_dir('Map_6_8', 'KSweep'), 'Map_k_sweep_summary.csv'));
mk = mk(mk.pass == 1, :);
selMap = selectPoint(mk.K_max, mk.mean_R_RMS_eT_Nm, mk.mean_S_HF_RMS_Ta_Nm);
T = table({'PI'; 'Map (single K, PM >= 45)'}, [G.wc_design_rad_s(sel); mk.K_max(selMap)], [G.mean_R_RMS_eT_Nm(sel); mk.mean_R_RMS_eT_Nm(selMap)], ...
    [G.mean_S_HF_RMS_Ta_Nm(sel); mk.mean_S_HF_RMS_Ta_Nm(selMap)], 'VariableNames', {'controller', 'selected_parameter', 'R_RMS_eT_Nm', 'S_HF_RMS_Ta_Nm'});
writetable(T, fullfile(outDir, 'PI_sweep_selection.csv'));
fprintf('run_pi_sweep: selected PI wc = %g rad/s (R %.3f, S %.4f); same rule on the Map sweep: K_max = %g (R %.3f, S %.4f); Map final: R %.3f, S %.4f\n', ...
    G.wc_design_rad_s(sel), G.mean_R_RMS_eT_Nm(sel), G.mean_S_HF_RMS_Ta_Nm(sel), mk.K_max(selMap), mk.mean_R_RMS_eT_Nm(selMap), ...
    mk.mean_S_HF_RMS_Ta_Nm(selMap), mapFinal(1), mapFinal(2));

plotPareto(G, mk, mapFinal, fullfile(outDir, 'PI_sweep_pareto.png'));
evalin('base', 'clear sc_theta1 sc_v sc_mu');
R = G;
end

function i = selectPoint(par, R, S)
    ok = R <= 1.02 * min(R);
    idx = find(ok);
    [~, k] = min(S(idx));
    i = idx(k);
end

%% ===================== one run =====================
function L = runTK(mdl, S, level, seed, vars)
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_v',      [S.t S.v]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    V = sensor_noise_vars(level, seed);
    fn = fieldnames(V);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, V.(fn{k})); end
    fn = fieldnames(vars);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, vars.(fn{k})); end
    so = sim(in);
    L.t = S.t;
    for nm = {'T_s', 'T_d_ref', 'e_T', 'T_a'}
        ts = so.get(['log_' nm{1}]);
        [tu, iu] = unique(ts.Time, 'last');
        L.(nm{1}) = interp1(tu, squeeze(ts.Data(iu)), S.t, 'linear', 'extrap');
    end
end

% same definitions as Map/script/run_k_sweep.m
function m = metrics(L, win, isSteady)
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

%% ===================== figure =====================
function plotPareto(G, mk, mapFinal, file)
    f = figure('Visible', 'off', 'Position', [50 50 1000 700]); hold on;
    errorbar(G.mean_S_HF_RMS_Ta_Nm, G.mean_R_RMS_eT_Nm, G.std_R_RMS_eT_Nm, G.std_R_RMS_eT_Nm, G.std_S_HF_RMS_Ta_Nm, G.std_S_HF_RMS_Ta_Nm, ...
        'o-', 'Color', [0.165 0.471 0.839], 'MarkerFaceColor', [0.165 0.471 0.839], 'DisplayName', 'PI (label: design \omega_c [rad/s])');
    for i = 1:height(G), text(G.mean_S_HF_RMS_Ta_Nm(i) * 1.03, G.mean_R_RMS_eT_Nm(i) * 1.03, sprintf('%g', G.wc_design_rad_s(i))); end
    plot(mk.mean_S_HF_RMS_Ta_Nm, mk.mean_R_RMS_eT_Nm, 's--', 'Color', [0.85 0.33 0.1], 'MarkerFaceColor', [0.85 0.33 0.1], 'DisplayName', 'Map, single K_{max} (label: K_{max})');
    for i = 1:height(mk), text(mk.mean_S_HF_RMS_Ta_Nm(i) * 1.03, mk.mean_R_RMS_eT_Nm(i) * 1.03, sprintf('K=%g', mk.K_max(i))); end
    plot(mapFinal(2), mapFinal(1), 'p', 'Color', [0.1 0.1 0.1], 'MarkerFaceColor', [0.1 0.1 0.1], 'MarkerSize', 14, 'DisplayName', 'Map, final (two tiers)');
    set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; legend('Location', 'best');
    xlabel('S: RMS of T_a above 5 Hz [N.m]  (smoother to the left)'); ylabel('R: RMS e_T over all scored windows [N.m]  (better down)');
    title('Case TK: response versus smoothness, PI and Map');
    exportgraphics(f, file, 'Resolution', 130); close(f);
end
