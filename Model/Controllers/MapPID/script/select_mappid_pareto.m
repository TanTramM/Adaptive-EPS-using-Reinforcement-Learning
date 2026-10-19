function sel = select_mappid_pareto(writeJson)
%SELECT_MAPPID_PARETO Select MapPID from all S1/S2 grid points (Section 13.5).
%   The common selector performs the gates, Pareto selection, tie rule,
%   calib_margin and five-seed report. This wrapper writes MapPID-specific
%   JSON because its anti-windup gain is Ki/(Kp+K), not the PID rule Ki/Kp.
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Calib');
jsonPath = fullfile(modelDir, 'data', 'mappid.json');
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Ts0 = Jm.design.Ts0;
Cal = calibrate_map_cached();
vn = {'K','z','p_over_z','z1','p1_over_z1','Kp','Ki','Kd','Tf'};
spec = struct('name', 'MapPID', 'outDir', outDir, 'vn', {vn}, ...
    'seed0', 30000, 'seeds', 30001:30005, 'evalFcn', @mappid_eval, ...
    'marginFcn', @(x) marginGate(x, Cal, Ts0), ...
    'toDesign', @(x) toDesign(x, Ts0), 'jsonPath', jsonPath, ...
    'PMfin', 30, 'GMfin', 2, 'erelMax', 10);
sel = select_pareto(spec, false);

% Report the two pre-registered starting regions separately.
sel.S1 = regionBest(outDir, 'S1');
sel.S2 = regionBest(outDir, 'S2');
gap = abs(sel.S1.J - sel.S2.J) / min(sel.S1.J, sel.S2.J);
sel.twoRegions = isfinite(gap) && gap >= 0.03;
fprintf('MapPID regions: S1 best J %.6g, S2 best J %.6g, relative gap %.2f %% => %s\n', ...
    sel.S1.J, sel.S2.J, 100 * gap, regionText(sel.twoRegions));

d = sel.design;
u = mappid_x2u(sel.x);
sel.noMap = sel.x(1) == 0;
sel.noLead = abs(sel.x(3) - 1) <= 1e-9;
sel.noLag = abs(sel.x(5) - 1) <= 1e-9;
sel.pidNearOff = u(6) <= 0.01 && u(7) <= 0.01 && u(8) == 0;
fprintf('Map branch %s; PID branch %s; lead %s; lag %s.\n', ...
    present(~sel.noMap), present(~sel.pidNearOff), present(~sel.noLead), present(~sel.noLag));

if writeJson
    J = jsondecode(fileread(jsonPath));
    if isfield(J, 'design') && ~isfield(J, 'design_emax5'), J.design_emax5 = J.design; end
    q = rmfield(d, 'Ts_ctrl');
    q.Kaw = q.Ki / (q.Kp + q.Kmax);
    q.rule = 'deterministic alternating-block coarse-to-fine grid from PID and Map starts, feasible Pareto (R,S), J=R*S with 3% tie by maximum PM, e_max=10%, calib_margin; 2026-10-19';
    q.CALIB_R_pct = sel.R; q.CALIB_S_Nm = sel.S; q.CALIB_J = sel.J;
    q.CALIB_erel_pct = sel.erel; q.PM_deg = sel.PM; q.GM = sel.GM;
    q.CALIB_Jbar_5seed = sel.Jbar; q.CALIB_sigmaJ_5seed = sel.sigmaJ;
    q.CALIB_erel_max_5seed = max(sel.erelSeeds);
    q.margin_ratio_gain = sel.margin.ratio_gain; q.margin_ratio_delay = sel.margin.ratio_delay;
    q.n_grid_evaluations = sel.nEvaluated; q.n_grid_simulations = sel.nSimulated;
    q.n_grid_feasible = sel.nFeasible; q.n_pareto = sel.nPareto;
    q.S1_best_J = sel.S1.J; q.S2_best_J = sel.S2.J; q.two_regions = sel.twoRegions;
    q.no_map_branch = sel.noMap; q.pid_near_off = sel.pidNearOff;
    q.no_lead = sel.noLead; q.no_lag = sel.noLag;
    q.search_seed = 30000; q.reporting_seeds = 30001:30005;
    q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(jsonPath, 'w'); assert(fid >= 0, 'Cannot write %s.', jsonPath);
    fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mappid_pareto: design written to %s\n', jsonPath);
end
end

function d = toDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), ...
    'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
    'lag', struct('z1', x(4), 'p1', x(4) * x(5)), ...
    'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end

function M = marginGate(x, Cal, Ts0)
M = calib_margin('Model_MapPID', 30001, mappid_variables(Cal, toDesign(x, Ts0)));
Simulink.sdi.clear;
end

function b = regionBest(outDir, prefix)
files = dir(fullfile(outDir, sprintf('MapPID_CALIB_%s*_w*_s30000.csv', prefix)));
T = table();
for k = 1:numel(files), T = [T; readtable(fullfile(files(k).folder, files(k).name))]; end %#ok<AGROW>
assert(~isempty(T), 'No MapPID grid rows found for %s.', prefix);
ok = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & isfinite(T.J);
if any(ok)
    Q = T(ok, :); [j, i] = min(Q.J); x = table2array(Q(i, 1:9));
else
    j = Inf; x = nan(1, 9);
end
b = struct('J', j, 'x', x);
end

function s = present(tf)
if tf, s = 'present'; else, s = 'absent'; end
end

function s = regionText(tf)
if tf, s = 'at least two regions'; else, s = 'no 3% separation'; end
end
