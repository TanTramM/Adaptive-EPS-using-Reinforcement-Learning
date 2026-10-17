function sel = select_mapopt(writeJson, suffix)
%SELECT_MAPOPT Stages 2-4 of DieuKhien_MapOpt.txt (C2-C4): the 20 best distinct designs of the search (seed 0), re-scored on seeds 1-5, chosen by the mean J, checked.
%
%   sel = select_mapopt(true)   also writes the design to data/mapopt.json
%   sel = select_mapopt(true, 'b')   RUN 2 (DieuKhien_MapOpt.txt Part M): pool = the files ...opt<k>b, ...ref<k>b of Calib plus the run-1 files of Calib_run1 (filtered by PM >= 30,
%   GM >= 2); the run-1 design is kept in the json field design_run1 (written once); run-1 Calib and Cases must have been moved to Calib_run1 and Cases_run1 beforehand.
%   Uses Model/common/select_multiseed.m (the common rules, KeHoach_ChonNhieuSeed.txt Part 3) with the MapOpt evaluation, the stability gate calib_margin on the
%   selection seed 1 and the bang-bang report calib_bangbang (seeds 0 and 1). Output files in Result/Controllers/MapOpt/Calib/.
if nargin < 1, writeJson = false; end
if nargin < 2, suffix = ''; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapOpt', 'load_mapopt.m'), '\', '/')));
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
files = poolFiles(outDir, suffix);
if ~isempty(suffix), files = [files, poolFiles(fullfile(fileparts(outDir), 'Calib_run1'), '')]; end
spec = struct('name', 'MapOpt', 'outDir', outDir, 'poolFiles', {files}, 'vn', {{'K', 'z', 'p_over_z', 'z1', 'p1_over_z1'}}, ...
    'evalFcn', @mapopt_eval, 'x2u', @mapopt_x2u, 'seed0', 0, 'seeds', 1:5, 'nTop', 20, 'PMfin', 30, 'GMfin', 2, 'erelMax', 5, ...
    'marginFcn', @(x) marginGate(x, Cal, Ts0), 'bangbangFcn', @(x) bangbang(x, Cal, Ts0));
sel = select_multiseed(spec);
[Gj, w] = mapopt_plants();
d = xToDesign(sel.x, Ts0);
Rl = mapopt_margins(Gj, w, d);
lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1));
noLead = sel.x(3) < 1.02; noLag = sel.x(5) > 0.98;
uc = mapopt_x2u(sel.x); atB = find(uc < 0.005 | uc > 0.995);
vn = spec.vn;
active = {};
if lagGain < 0.72, active{end + 1} = 'steering band (lag gain at 2 Hz near 0.707)'; end
if Rl.PM < 32, active{end + 1} = 'final linear PM near 30 deg'; end
if Rl.GM < 2.1, active{end + 1} = 'final linear GM near 2'; end
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('lead %s, lag %s; PM %.1f GM %.2f HF %.2f; lag gain 2 Hz %.3f; active: %s\n', tf2s(~noLead), tf2s(~noLag), Rl.PM, Rl.GM, Rl.HF, lagGain, strjoin(active, '; '));
sel.design = d; sel.active = active; sel.noLead = noLead; sel.noLag = noLag; sel.lagGain2Hz = lagGain; sel.PMlin = Rl.PM; sel.GMlin = Rl.GM; sel.HF = Rl.HF;
if writeJson
    jf = fullfile(modelDir, 'data', 'mapopt.json');
    J = jsondecode(fileread(jf));
    if ~isempty(suffix) && ~isfield(J, 'design_run1'), J.design_run1 = J.design; end
    B = sel.bangbang;
    J.design = struct('Kmax', d.Kmax, 'Ts0', Ts0, 'lead', d.lead, 'lag', d.lag, ...
        'rule', ruleText(suffix), ...
        'CALIB_J_mean_seeds_1_5', sel.Jbar, 'CALIB_J_sigma', sel.sigma, 'CALIB_J_per_seed', sel.Jseeds, 'CALIB_R_pct_mean', sel.Rbar, 'CALIB_S_Nm_mean', sel.Sbar, ...
        'CALIB_TV_mean', sel.TVbar, 'CALIB_rev_pct_mean', 100 * sel.revbar, 'CALIB_erel_max_pct', sel.erelMax, 'CALIB_J_search_seed0', sel.Jsearch, 'rank_at_seed0', sel.rank0, ...
        'rank_correlation', sel.rankCorr, 'PM_deg', Rl.PM, 'GM', Rl.GM, 'HF_gain', Rl.HF, 'lag_gain_2Hz', lagGain, 'no_lead', noLead, 'no_lag', noLag, ...
        'margin_ratio_gain', sel.margin.ratio_gain, 'margin_ratio_delay', sel.margin.ratio_delay, 'active', {active}, ...
        'n_region', sel.nRegion, 'n_pool', sel.nPool, 'search_seed', 0, 'selection_seeds', 1:5, 'map_source_date', Jm.design.date, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    if ~isempty(fieldnames(B)), J.design.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp); end
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mapopt: design written to %s\n', jf);
end
end

function M = marginGate(x, Cal, Ts0)
d = xToDesign(x, Ts0);
M = calib_margin('Model_MapOpt', 1, mapopt_variables(Cal, d));
Simulink.sdi.clear;
end

function B = bangbang(x, Cal, Ts0)
d = xToDesign(x, Ts0);
B = calib_bangbang('Model_MapOpt', 0, mapopt_variables(Cal, d));
Simulink.sdi.clear;
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)));
end

function s = tf2s(b)
if b, s = 'present'; else, s = 'absent'; end
end

function f = poolFiles(dirName, suffix)
% search files of one run: MapOpt_CALIB_opt<k><suffix>_s00000.csv and MapOpt_CALIB_ref<k><suffix>_s00000.csv (exact suffix, so run 1 never picks up run 2)
L = dir(fullfile(dirName, 'MapOpt_CALIB_*_s00000.csv'));
keep = ~cellfun(@isempty, regexp({L.name}, ['^MapOpt_CALIB_(opt|ref)\d+' suffix '_s00000\.csv$'], 'once'));
f = cellstr(fullfile(dirName, {L(keep).name}));
end

function s = ruleText(suffix)
s = 'min mean J = R*S over CALIB seeds 1-5 among the 20 best distinct designs of the search at seed 0 (surrogateopt x3 + patternsearch x3)';
if ~isempty(suffix)
    s = [s '; run 2 (2026-10-17): linear PM >= 30 deg and GM >= 2 applied during the search, start points from run 1'];
end
end
