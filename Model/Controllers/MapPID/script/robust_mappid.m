function T = robust_mappid()
%ROBUST_MAPPID O7 of DieuKhien_MapPID.txt (report only): linear stability margins of MapPID, Map and PID when one Plant parameter is off by +-20 %.
%   Parameters varied one at a time: torsion bar stiffness K, column inertia J_col, column damping C_col, front cornering stiffness C_alpha_f.
%   For each condition the 68 linearized Plants (17 speeds x 4 operating points, map_plant_lin with the modified parameters) and the 5 slopes are
%   rebuilt; the designs are those of data/mappid.json, data/map.json and data/pid.json. Output: Result/Controllers/MapPID/Design/MapPID_robust.csv
%   (one row per condition: PM, GM, stable of each controller).
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
Ji = jsondecode(fileread(fullfile(modelDir, 'data', 'pi.json'))); qi = Ji.design;
Jx = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json'))); assert(isfield(Jx, 'design'), 'mappid.json has no design yet');
dx = Jx.design;
D = {struct('Kmax', dx.Kmax, 'lead', dx.lead, 'lag', dx.lag, 'Kp', dx.Kp, 'Ki', dx.Ki, 'Kd', dx.Kd, 'Tf', dx.Tf), ...
     struct('Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005), ...
     struct('Kmax', 0, 'lead', dm.lead, 'lag', dm.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf), ...
     struct('Kmax', 0, 'lead', dm.lead, 'lag', dm.lag, 'Kp', qi.Kp, 'Ki', qi.Ki, 'Kd', 0, 'Tf', 0.005)};
names = {'MapPID', 'Map', 'PID', 'PI'};
P0 = map_params(); Cal = calibrate_map_cached(); ops = map_op_points();
w = logspace(-1, 5, 3000)';
cond = {'nominal', '', 1; 'K -20%', 'K', 0.8; 'K +20%', 'K', 1.2; 'J_col -20%', 'J_col', 0.8; 'J_col +20%', 'J_col', 1.2; ...
        'C_col -20%', 'C_col', 0.8; 'C_col +20%', 'C_col', 1.2; 'C_alpha_f -20%', 'C_alpha_f', 0.8; 'C_alpha_f +20%', 'C_alpha_f', 1.2};
rows = {};
for ic = 1:size(cond, 1)
    P = P0;
    if ~isempty(cond{ic, 2}), P.(cond{ic, 2}) = P0.(cond{ic, 2}) * cond{ic, 3}; end
    Gj = cell(numel(Cal.v_kmh) * size(ops, 1), 1); idx = 1;
    for iv = 1:numel(Cal.v_kmh)
        for i = 1:size(ops, 1)
            Gj{idx} = squeeze(freqresp(map_plant_lin(P, Cal.v_kmh(iv) / 3.6, ops(i, 1) * P.g, ops(i, 2)), w)); idx = idx + 1;
        end
    end
    r = {cond{ic, 1}};
    for k = 1:4
        R = mappid_margins(Gj, w, D{k});
        r = [r, {R.PM, R.GM, double(R.stable)}]; %#ok<AGROW>
    end
    rows(end + 1, :) = r; %#ok<AGROW>
    fprintf('robust_mappid: %-15s MapPID PM %.1f GM %.2f | Map PM %.1f GM %.2f | PID PM %.1f GM %.2f | PI PM %.1f GM %.2f\n', cond{ic, 1}, r{2}, r{3}, r{5}, r{6}, r{8}, r{9}, r{11}, r{12});
end
vn = {'condition'};
for k = 1:4, vn = [vn, {[names{k} '_PM_deg'], [names{k} '_GM'], [names{k} '_stable']}]; end %#ok<AGROW>
T = cell2table(rows, 'VariableNames', vn);
writetable(T, fullfile(result_dir('MapPID', 'Design'), 'MapPID_robust.csv'));
end
