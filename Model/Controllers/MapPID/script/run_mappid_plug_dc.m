function T = run_mappid_plug_dc(stage)
%RUN_MAPPID_PLUG_DC Steps 4 (D) and 5 (C) of PhuongPhap_TimThamSo.txt 15.3. Nothing is re-selected: every row is reported as it comes.
%   'D': Map block locked to map.json, PID block = pid.json design (the stand-alone PID, not tuned for this Map).
%   'C': PID block = the design chosen by select_mappid_plug (data/mappid.json), Map block replaced by three Maps of Map/Calib_v2/Grid2:
%        (1) the first pick K 5.4772, g_min 0.7492; (2) K nearest 6.31 with g_min 0.7071; (3) among the pairs that passed e_rel
%        but failed calib_margin, the one with the smallest J. z, p, z1, p1 are taken from the csv rows.
%   Every row: mappid_eval at seed 30000 plus calib_margin at seed 30001. Output Calib_v2/PlugPlay/MapPID_CALIB_plug<D|C>_s30000.csv.
stage = upper(char(stage));
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = fullfile(result_dir('MapPID', 'Calib'), 'PlugPlay');
if ~exist(outDir, 'dir'), mkdir(outDir); end
outFile = fullfile(outDir, sprintf('MapPID_CALIB_plug%s_s30000.csv', stage));
xMap = mappid_plug_u0(modelDir);
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
loadFile = strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/');

switch stage
    case 'D'
        P = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); d = P.design;
        labels = {'D_pid_standalone'};
        X = [xMap, d.Kp, d.Ki, d.Kd, d.Tf];
    case 'C'
        M = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json'))); d = M.design;
        assert(isfield(d, 'rule') && contains(d.rule, 'plug-in'), 'mappid.json does not hold the plug-in design yet.');
        pidBlock = [d.Kp, d.Ki, d.Kd, d.Tf];
        gridDir = fullfile(result_dir('Map', 'Calib'), 'Grid2');
        G = readGrid(gridDir);
        rows = pickMaps(G);
        labels = rows.label; X = zeros(numel(labels), 9);
        for i = 1:numel(labels)
            X(i, :) = [rows.K(i), rows.z(i), rows.p(i) / rows.z(i), rows.z1(i), rows.p1(i) / rows.z1(i), pidBlock];
        end
    otherwise
        error('stage must be D or C.');
end

n = size(X, 1);
res = table('Size', [n 12], 'VariableTypes', [{'string'}, repmat({'double'}, 1, 11)], 'VariableNames', ...
    {'label','R_pct','S_Nm','J','erel_pct','PM_deg','GM','c1','c2','c3','c4','simulated'});
extra = nan(n, 4);   % ratio_gain, ratio_delay, margin_pass, TV
for i = 1:n
    x = X(i, :);
    o = mappid_eval(x, 30000, '');
    Simulink.sdi.clear;
    dd = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
        'lag', struct('z1', x(4), 'p1', x(4) * x(5)), 'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
    evalin('base', sprintf('run(''%s'');', loadFile));
    mg = calib_margin('Model_MapPID', 30001, mappid_variables(Cal, dd));
    Simulink.sdi.clear;
    res(i, :) = {string(labels{i}), o.R, o.S, o.R * o.S, o.erel, o.PM, o.GM, o.c(1), o.c(2), o.c(3), o.c(4), o.simulated};
    extra(i, :) = [mg.ratio_gain, mg.ratio_delay, double(mg.pass), o.TV];
    fprintf('plug%s %s: K %.5g R %.4f S %.5f J %.5f e_rel %.3f PM %.2f GM %.2f margin gain %.3f delay %.3f pass %d\n', ...
        stage, labels{i}, x(1), o.R, o.S, o.R * o.S, o.erel, o.PM, o.GM, mg.ratio_gain, mg.ratio_delay, mg.pass);
end
xs = array2table(X, 'VariableNames', {'x_K','x_z','x_p_over_z','x_z1','x_p1_over_z1','x_Kp','x_Ki','x_Kd','x_Tf'});
T = [res(:, 1), xs, res(:, 2:end), array2table(extra, 'VariableNames', {'ratio_gain','ratio_delay','margin_pass','TV'})];
writetable(T, outFile);
fprintf('run_mappid_plug_dc: wrote %s\n', outFile);
end

function G = readGrid(gridDir)
files = dir(fullfile(gridDir, 'Map_CALIB_grid2_w*_s00000.csv'));
G = table();
for k = 1:numel(files), G = [G; readtable(fullfile(files(k).folder, files(k).name))]; end %#ok<AGROW>
F = readtable(fullfile(gridDir, 'Map_CALIB_margin_failures_s00000.csv'));
G.ratio_gain_f = nan(height(G), 1); G.ratio_delay_f = nan(height(G), 1);
for i = 1:height(G)
    j = find(abs(F.K - G.K(i)) <= 1e-9 * max(1, G.K(i)) & abs(F.g_min - G.g_min(i)) <= 1e-9, 1);
    if ~isempty(j), G.ratio_gain_f(i) = F.ratio_gain(j); G.ratio_delay_f(i) = F.ratio_delay(j); end
end
[~, iu] = unique(round([G.K G.g_min], 10, 'significant'), 'rows', 'stable'); G = G(sort(iu), :);
end

function r = pickMaps(G)
simOK = G.simulated == 1 & G.c1 <= 0 & G.c2 <= 0 & G.c3 <= 0;
% (1) first pick of the Map frame: K 5.4772, g_min 0.7492
[~, i1] = min(abs(G.K - 5.4772) / 5.4772 + abs(G.g_min - 0.7492));
assert(abs(G.K(i1) - 5.4772) < 5e-4 && abs(G.g_min(i1) - 0.7492) < 5e-4, 'First-pick Map (K 5.4772, g_min 0.7492) not found in Grid2 csv.');
% (2) K nearest 6.31 at g_min 0.7071
c2 = find(simOK & abs(G.g_min - 1 / sqrt(2)) < 1e-6);
[~, k2] = min(abs(G.K(c2) - 6.31)); i2 = c2(k2);
% (3) passes e_rel (c4 <= 0) but fails calib_margin: smallest J
c3 = find(simOK & G.c4 <= 0 & isfinite(G.J));
assert(~isempty(c3), 'No Grid2 pair passes e_rel.');
[~, k3] = min(G.J(c3)); i3 = c3(k3);
idx = [i1; i2; i3];
r = struct('label', {{'C_map_first_pick'; 'C_map_K6p31_gmin0p7071'; 'C_map_erel_ok_margin_fail'}}, ...
    'K', G.K(idx), 'z', G.z(idx), 'p', G.p(idx), 'z1', G.z1(idx), 'p1', G.p1(idx));
fprintf('Grid2 Maps used: K = %s, g_min = %s\n', mat2str(G.K(idx)', 6), mat2str(G.g_min(idx)', 6));
end
