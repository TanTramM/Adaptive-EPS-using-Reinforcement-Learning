function sel = select_mappid(writeJson)
%SELECT_MAPPID Stages 2-4 of the common method (KeHoach_ChonNhieuSeed.txt Part 3; DieuKhien_MapPID.txt H5): the 20 best distinct designs of the search (seed 30000),
%   re-scored on seeds 30001-30005, chosen by the mean J, checked (calib_margin on seed 30001, bang-bang, degeneracy of lead, lag and Map branch).
%
%   sel = select_mappid(true)   also writes the design to data/mappid.json
%   Uses Model/common/select_multiseed.m. Output files in Result/Controllers/MapPID/Calib/: MapPID_CALIB_top_s30000.csv, _best_s30001-s30005.csv, _pick_ms.csv.
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Calib');
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
a = dir(fullfile(outDir, 'MapPID_CALIB_opt*_s30000.csv'));   % surrogateopt rows only (no patternsearch, COMMON decision 2026-10-18)
files = cellfun(@(n) fullfile(outDir, n), {a.name}, 'UniformOutput', false);
vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
spec = struct('name', 'MapPID', 'outDir', outDir, 'poolFiles', {files}, 'vn', {vn}, ...
    'evalFcn', @mappid_eval, 'x2u', @mappid_x2u, 'seed0', 30000, 'seeds', 30001:30005, 'nTop', 20, 'PMfin', 30, 'GMfin', 2, 'erelMax', 5, ...
    'marginFcn', @(x) marginGate(x, Cal, Ts0), 'bangbangFcn', @(x) bangbang(x, Cal, Ts0));
sel = select_multiseed(spec);
[Gj, w] = mappid_plants();
d = xToDesign(sel.x, Ts0);
Rl = mappid_margins(Gj, w, d);
lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1));
noMap = sel.x(1) == 0; noLead = sel.x(3) < 1.02; noLag = sel.x(5) > 0.98;
uc = mappid_x2u(sel.x); atB = find(uc < 0.005 | uc > 0.995);
active = {};
if lagGain < 0.72, active{end + 1} = 'steering band (lag gain at 2 Hz near 0.707)'; end
if Rl.PM < 32, active{end + 1} = 'final linear PM near 30 deg'; end
if Rl.GM < 2.1, active{end + 1} = 'final linear GM near 2'; end
for k = atB
    if (k == 1 && noMap) || (k == 8 && sel.x(8) == 0), continue; end   % K = 0 and Kd = 0 are chosen values, not walls
    active{end + 1} = sprintf('box bound of %s', vn{k}); %#ok<AGROW>
end
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('Map branch %s, lead %s, lag %s; PM %.1f GM %.2f HF %.2f; lag gain 2 Hz %.3f; active: %s\n', pr(~noMap), pr(~noLead), pr(~noLag), Rl.PM, Rl.GM, Rl.HF, lagGain, strjoin(active, '; '));
sel.design = d; sel.active = active; sel.noMap = noMap; sel.noLead = noLead; sel.noLag = noLag; sel.lagGain2Hz = lagGain; sel.PMlin = Rl.PM; sel.GMlin = Rl.GM; sel.HF = Rl.HF;
if writeJson
    jf = fullfile(modelDir, 'data', 'mappid.json');
    J = jsondecode(fileread(jf)); B = sel.bangbang;
    Kaw = 0; if d.Ki > 0 && d.Kp + d.Kmax > 0, Kaw = d.Ki / (d.Kp + d.Kmax); end
    J.design = struct('Kmax', d.Kmax, 'Ts0', Ts0, 'lead', d.lead, 'lag', d.lag, 'Kp', d.Kp, 'Ki', d.Ki, 'Kd', d.Kd, 'Tf', d.Tf, 'Kaw', Kaw, ...
        'rule', 'min mean J = R*S over CALIB seeds 30001-30005 among the 20 best distinct designs of the search at seed 30000 (surrogateopt x3 + patternsearch x3, wide box, PM >= 30, GM >= 2 in the search)', ...
        'CALIB_J_mean', sel.Jbar, 'CALIB_J_sigma', sel.sigma, 'CALIB_J_per_seed', sel.Jseeds, 'CALIB_R_pct_mean', sel.Rbar, 'CALIB_S_Nm_mean', sel.Sbar, 'CALIB_TV_mean', sel.TVbar, ...
        'CALIB_rev_pct_mean', 100 * sel.revbar, 'CALIB_erel_max_pct', sel.erelMax, 'CALIB_J_search_seed', sel.Jsearch, 'rank_at_search_seed', sel.rank0, 'rank_correlation', sel.rankCorr, ...
        'PM_deg', Rl.PM, 'GM', Rl.GM, 'HF_gain', Rl.HF, 'lag_gain_2Hz', lagGain, 'no_map_branch', noMap, 'no_lead', noLead, 'no_lag', noLag, ...
        'margin_ratio_gain', sel.margin.ratio_gain, 'margin_ratio_delay', sel.margin.ratio_delay, 'active', {active}, 'n_region', sel.nRegion, 'n_pool', sel.nPool, 'n_top', sel.nTop, ...
        'search_seed', 30000, 'selection_seeds', 30001:30005, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    if ~isempty(fieldnames(B)), J.design.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp); end
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mappid: design written to %s\n', jf);
end
end

function M = marginGate(x, Cal, Ts0)
M = calib_margin('Model_MapPID', 30001, mappid_variables(Cal, xToDesign(x, Ts0)));
Simulink.sdi.clear;
end

function B = bangbang(x, Cal, Ts0)
B = calib_bangbang('Model_MapPID', 30000, mappid_variables(Cal, xToDesign(x, Ts0)));
Simulink.sdi.clear;
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)), ...
    'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end

function s = pr(b)
if b, s = 'present'; else, s = 'absent'; end
end
