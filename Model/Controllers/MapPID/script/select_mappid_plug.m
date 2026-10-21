function sel = select_mappid_plug(writeJson)
%SELECT_MAPPID_PLUG Select the PID block on the locked Map (PhuongPhap_TimThamSo.txt 15.3 step 3).
%   Same gates and rule as select_mappid_pareto (common select_pareto: PM 30, GM 2, e_rel 10 %, Pareto (R,S), J = R*S, 3 % tie by PM,
%   calib_margin, five report seeds 30001-30005) but reads only Calib_v2/PlugPlay. mappid.json is written only when writeJson is true,
%   after the caller has backed up the old file (the pipeline does it).
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = fullfile(result_dir('MapPID', 'Calib'), 'PlugPlay');
jsonPath = fullfile(modelDir, 'data', 'mappid.json');
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Ts0 = Jm.design.Ts0;
Cal = calibrate_map_cached();
vn = {'K','z','p_over_z','z1','p1_over_z1','Kp','Ki','Kd','Tf'};
spec = struct('name', 'MapPID', 'outDir', outDir, 'vn', {vn}, ...
    'seed0', 30000, 'seeds', 30001:30005, 'evalFcn', @mappid_eval, ...
    'marginFcn', @(x) marginGate(x, Cal, Ts0, modelDir), ...
    'toDesign', @(x) toDesign(x, Ts0), 'jsonPath', jsonPath, ...
    'PMfin', 30, 'GMfin', 2, 'erelMax', 10);
sel = select_pareto(spec, false);

d = sel.design;
q = rmfield(d, 'Ts_ctrl');
q.Kaw = q.Ki / (q.Kp + q.Kmax);
fprintf('Plug-in design: K %.6g, lead z %.6g p %.6g, lag z1 %.6g p1 %.6g | Kp %.6g Ki %.6g Kd %.6g Tf %.6g Kaw %.6g\n', ...
    q.Kmax, q.lead.z, q.lead.p, q.lag.z1, q.lag.p1, q.Kp, q.Ki, q.Kd, q.Tf, q.Kaw);
if writeJson
    J = jsondecode(fileread(jsonPath));
    if isfield(J, 'design') && ~isfield(J, 'design_pre_plug'), J.design_pre_plug = J.design; end
    q.rule = 'plug-in: Map block locked to map.json design, PID block (Kp, Ki, Kd, Tf) by the PID coarse-to-fine grid and box, feasible Pareto (R,S), J=R*S with 3% tie by maximum PM, e_max=10%, calib_margin; PhuongPhap_TimThamSo.txt 15; 2026-10-22';
    q.CALIB_R_pct = sel.R; q.CALIB_S_Nm = sel.S; q.CALIB_J = sel.J;
    q.CALIB_erel_pct = sel.erel; q.PM_deg = sel.PM; q.GM = sel.GM;
    q.CALIB_Jbar_5seed = sel.Jbar; q.CALIB_sigmaJ_5seed = sel.sigmaJ;
    q.CALIB_erel_max_5seed = max(sel.erelSeeds);
    q.margin_ratio_gain = sel.margin.ratio_gain; q.margin_ratio_delay = sel.margin.ratio_delay;
    q.n_grid_evaluations = sel.nEvaluated; q.n_grid_simulations = sel.nSimulated;
    q.n_grid_feasible = sel.nFeasible; q.n_pareto = sel.nPareto;
    q.search_seed = 30000; q.reporting_seeds = 30001:30005;
    q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(jsonPath, 'w'); assert(fid >= 0, 'Cannot write %s.', jsonPath);
    fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mappid_plug: design written to %s\n', jsonPath);
end
end

function d = toDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), ...
    'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
    'lag', struct('z1', x(4), 'p1', x(4) * x(5)), ...
    'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end

function M = marginGate(x, Cal, Ts0, modelDir)
loadFile = strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/');
evalin('base', sprintf('run(''%s'');', loadFile));
M = calib_margin('Model_MapPID', 30001, mappid_variables(Cal, toDesign(x, Ts0)));
Simulink.sdi.clear;
end
