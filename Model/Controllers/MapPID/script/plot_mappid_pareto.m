function plot_mappid_pareto()
%PLOT_MAPPID_PARETO Pareto plane (S, R) on case CALIB of MapPID (every feasible design evaluated by the optimisation, seed 30000) against the swept
%   designs of Map (seed 00000), PI and PID (seed 10000) that pass e_rel <= 5 %, with the chosen design of each controller (star) and the
%   non-dominated front of each set (line). The seeds differ (each controller's own tuning seed, QuyChuan 3.3), so differences below about 1 % in R
%   or S are within the seed spread. Output: Result/Compare/Map_vs_PI_vs_PID_vs_MapPID/Map_vs_PI_vs_PID_vs_MapPID_CALIB_pareto_s00000-s30000.png
%   and the MapPID front as MapPID_CALIB_pareto_s30000.csv in Result/Controllers/MapPID/Calib/.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
cdir = result_dir('MapPID', 'Calib');
files = [dir(fullfile(cdir, 'MapPID_CALIB_opt*_s30000.csv')); dir(fullfile(cdir, 'MapPID_CALIB_ref*_s30000.csv')); dir(fullfile(cdir, 'MapPID_CALIB_nbr_s30000.csv'))];
X = table();
for i = 1:numel(files), X = [X; readtable(fullfile(cdir, files(i).name))]; end %#ok<AGROW>
X = X(X.simulated == 1 & X.c1 <= 0 & X.c2 <= 0 & X.c3 <= 0 & X.c4 <= 0, :);
sets = struct('name', {'Map', 'PI', 'PID', 'MapPID'}, 'R', [], 'S', [], 'col', {[0.165 0.471 0.839], [0.800 0.600 0.000], [0.922 0.408 0.204], [0.290 0.227 0.655]});
T = readtable(fullfile(result_dir('Map', 'Calib'), 'Map_CALIB_sweep_s00000.csv')); T = T(T.erel_pct <= 5, :); sets(1).R = T.R_pct; sets(1).S = T.S_Nm;
T = readtable(fullfile(result_dir('PI', 'Calib'), 'PI_CALIB_sweep_s10000.csv')); T = T(T.erel_pct <= 5, :); sets(2).R = T.R_pct; sets(2).S = T.S_Nm;
T = readtable(fullfile(result_dir('PID', 'Calib'), 'PID_CALIB_sweep_s10000.csv')); T = T(T.erel_pct <= 5, :); sets(3).R = T.R_pct; sets(3).S = T.S_Nm;
sets(4).R = X.R_pct; sets(4).S = X.S_Nm;
pick = struct();
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));    pick.Map = [J.design.CALIB_S_Nm, J.design.CALIB_R_pct];
J = jsondecode(fileread(fullfile(modelDir, 'data', 'pi.json')));     pick.PI = [J.design.CALIB_S_Nm, J.design.CALIB_R_pct];
J = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));    pick.PID = [J.design.CALIB_S_Nm, J.design.CALIB_R_pct];
J = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json'))); pick.MapPID = [J.design.CALIB_S_Nm, J.design.CALIB_R_pct];
fig = figure('Visible', 'off', 'Position', [100 100 860 600]); hold on;
h = gobjects(1, 4);
for k = 1:4
    scatter(sets(k).S, sets(k).R, 10, sets(k).col, 'filled', 'MarkerFaceAlpha', 0.35);
    [fs, fr] = front(sets(k).S, sets(k).R);
    h(k) = plot(fs, fr, '-', 'Color', sets(k).col, 'LineWidth', 1.8);
    p = pick.(sets(k).name);
    plot(p(1), p(2), 'p', 'MarkerSize', 16, 'MarkerFaceColor', sets(k).col, 'MarkerEdgeColor', 'k');
    if k == 4
        writetable(table(fs(:), fr(:), 'VariableNames', {'S_Nm', 'R_pct'}), fullfile(cdir, 'MapPID_CALIB_pareto_s30000.csv'));
    end
end
set(gca, 'XScale', 'log'); grid on; xlabel('S = RMS of T_a above 5 Hz [N.m] (log)'); ylabel('R [%]');
xl = xlim; xlim([max(xl(1), 0.03) min(xl(2), 3)]); ylim([0 60]);
legend(h, {'Map (seed 00000)', 'PI (seed 10000)', 'PID (seed 10000)', 'MapPID (seed 30000)'}, 'Location', 'northeast');
title('CALIB: designs that pass e_{rel} <= 5 %, non-dominated front (line), chosen design (star)');
odir = result_dir('Compare', 'Map_vs_PI_vs_PID_vs_MapPID');
exportgraphics(fig, fullfile(odir, 'Map_vs_PI_vs_PID_vs_MapPID_CALIB_pareto_s00000-s30000.png'), 'Resolution', 130); close(fig);
end

function [fs, fr] = front(S, R)
[S, i] = sort(S); R = R(i);
keep = false(size(S)); best = Inf;
for k = 1:numel(S)
    if R(k) < best, keep(k) = true; best = R(k); end
end
fs = S(keep); fr = R(keep);
end
