function report_map2_grid()
%REPORT_MAP2_GRID Report of the two-variable Map grid (PhuongPhap_TimThamSo.txt 14.9): counts, centre rules, chosen design, five seeds, Pareto figure.
%   Writes Result/Controllers/Map/Calib_v2/Grid2/Map_CALIB_grid2_report_s00000.csv (key,value) and Map_CALIB_grid2_safe_s00000.png.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
spec = map2_grid_spec(); od = spec.outDir;
files = dir(fullfile(od, 'Map_CALIB_grid2_w*_s00000.csv')); P = table();
for i = 1:numel(files), P = [P; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
[~, iu] = unique(round(table2array(P(:, 1:2)), 10, 'significant'), 'rows', 'stable'); P = P(sort(iu), :);
U = zeros(height(P), 2); for i = 1:height(P), U(i, :) = map2_x2u([P.K(i) P.g_min(i)]); end
isCoarse = all(abs(U * 12 - round(U * 12)) < 1e-6, 2);
sim = P.simulated == 1;
passE = sim & P.c4 <= 0; safe = sim & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0; passM = sim & P.pass_margin == 1;
kv = {};
kv(end+1, :) = {'pairs_total', height(P)};
kv(end+1, :) = {'pairs_coarse', nnz(isCoarse)};
kv(end+1, :) = {'pairs_fine_extra', nnz(~isCoarse)};
kv(end+1, :) = {'synthesis_failed', nnz(P.synth_ok == 0)};
kv(end+1, :) = {'linear_gate_failed', nnz(P.synth_ok == 1 & ~sim)};
kv(end+1, :) = {'simulated', nnz(sim)};
kv(end+1, :) = {'pass_e_rel', nnz(passE)};
kv(end+1, :) = {'pass_margin', nnz(passM)};
kv(end+1, :) = {'pass_e_rel_and_margin', nnz(passE & passM)};
kv(end+1, :) = {'safe_and_margin', nnz(safe & passM)};
% centre rules and final h from the worker logs
rules = '';
lf = dir(fullfile(fileparts(modelDir), 'scratch', 'jobs', 'map2_w1_try*.log'));
for i = 1:numel(lf)
    txt = fileread(fullfile(lf(i).folder, lf(i).name));
    L = regexp(txt, '\[grid2\] centre rule [^\n]*', 'match');
    rules = [rules, sprintf('%s | ', L{:})]; %#ok<AGROW>
    dn = regexp(txt, 'DONE worker[^\n]*', 'match'); if ~isempty(dn), kv(end+1, :) = {'worker1_done_line', dn{end}}; end %#ok<AGROW>
end
kv(end+1, :) = {'centre_rules_worker1', rules};

pk = readtable(fullfile(od, 'Map_CALIB_pick_s00000.csv')); c = pk(pk.chosen == 1, :);
x = [c.K, c.g_min];
kv(end+1, :) = {'chosen_K', c.K}; kv(end+1, :) = {'chosen_g_min', c.g_min};
kv(end+1, :) = {'chosen_z', c.z}; kv(end+1, :) = {'chosen_p', c.p}; kv(end+1, :) = {'chosen_z1', c.z1}; kv(end+1, :) = {'chosen_p1', c.p1};
kv(end+1, :) = {'chosen_R_pct', c.R_pct}; kv(end+1, :) = {'chosen_S_Nm', c.S_Nm}; kv(end+1, :) = {'chosen_J', c.R_pct * c.S_Nm};
kv(end+1, :) = {'chosen_TV', c.TV}; kv(end+1, :) = {'chosen_erel_pct', c.erel_pct}; kv(end+1, :) = {'chosen_PM_deg', c.PM_deg};
kv(end+1, :) = {'chosen_GM', c.GM}; kv(end+1, :) = {'chosen_HF', c.HF};
kv(end+1, :) = {'chosen_ratio_gain', c.ratio_gain}; kv(end+1, :) = {'chosen_ratio_delay', c.ratio_delay};
kv(end+1, :) = {'chosen_label', ternary(c.c4 <= 0, 'passes all gates', 'safe, fails e_rel')};
u = map2_x2u(x);
kv(end+1, :) = {'chosen_at_box_edge', strjoin(edgeFlags(u, x), ' ')};
% worst e_rel window of the chosen design (one more simulation, seed 0)
Cal = calibrate_map_cached(); assignin('base', 'Map_calibration_override', Cal);
run(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'));
d = map2_design_from_row(c, spec.jsonPath);
[~, m] = calib_run('Model_Map', 0, map_variables(Cal, d)); Simulink.sdi.clear;
[~, iw] = max(m.erelWin);
kv(end+1, :) = {'chosen_erel_window', m.erelLabel{iw}};
kv(end+1, :) = {'chosen_erel_signed_pct', m.erelSigned(iw)};
% five seeds
cf = fullfile(od, 'Map_CALIB_pareto_check_s00001-s00005.csv');
if isfile(cf)
    T = readtable(cf);
    h = T.seed >= 1 & T.seed <= 5 & abs(T.K - x(1)) <= 1e-9 * max(1, x(1)) & abs(T.g_min - x(2)) <= 1e-9;
    Jk = T.R_pct(h) .* T.S_Nm(h);
    kv(end+1, :) = {'five_seed_n', nnz(h)}; kv(end+1, :) = {'five_seed_J_mean', mean(Jk)}; kv(end+1, :) = {'five_seed_J_std', std(Jk)};
    kv(end+1, :) = {'five_seed_erel_max_pct', max(T.erel_pct(h))}; kv(end+1, :) = {'five_seed_erel_per_seed', mat2str(T.erel_pct(h)', 5)};
end
R = cell2table(cellfun(@toStr, kv, 'UniformOutput', false), 'VariableNames', {'key', 'value'});
writetable(R, fullfile(od, 'Map_CALIB_grid2_report_s00000.csv'));
disp(R);

% figure: R-S of the safe points (safety gates and calib_margin), coloured by e_rel
fig = figure('Visible', 'off', 'Color', 'w'); hold on; grid on; box on;
q = safe & passM;
scatter(P.S_Nm(q), P.R_pct(q), 28, P.erel_pct(q), 'filled'); cb = colorbar; ylabel(cb, 'e_{rel} max (%)');
scatter(c.S_Nm, c.R_pct, 110, 'r', '^', 'LineWidth', 1.5);
xlabel('S (N.m)'); ylabel('R (%)'); title('Map (K, g_{min}) grid: safe points, CALIB v2 seed 0');
exportgraphics(fig, fullfile(od, 'Map_CALIB_grid2_safe_s00000.png'), 'Resolution', 150); close(fig);
end

function d = map2_design_from_row(c, jsonPath)
J = jsondecode(fileread(jsonPath)); Ts0 = J.design.Ts0;
z1 = c.z1; p1 = c.p1; if ~isfinite(z1) || ~isfinite(p1), z1 = Inf; p1 = Inf; end
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', c.K, 'lead', struct('z', c.z, 'p', c.p), 'lag', struct('z1', z1, 'p1', p1));
end

function f = edgeFlags(u, x)
f = {};
if u(1) <= 1e-9, f{end+1} = 'K=1'; end
if u(1) >= 1 - 1e-9, f{end+1} = 'K=30'; end
if u(2) <= 1e-9, f{end+1} = 'g_min=0.707'; end
if u(2) >= 1 - 1e-9, f{end+1} = 'g_min=1 (lag off)'; end
if isempty(f), f = {'interior'}; end
end

function s = toStr(v)
if isnumeric(v), s = sprintf('%.10g', v); else, s = char(v); end
end

function r = ternary(c, a, b)
if c, r = a; else, r = b; end
end
