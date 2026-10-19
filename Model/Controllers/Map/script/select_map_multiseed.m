function sel = select_map_multiseed(writeJson)
%SELECT_MAP_MULTISEED Stages 2-4 of the common method (KeHoach_ChonNhieuSeed.txt Part 3): the 20 best distinct designs of the search (seed 0), re-scored on seeds 1-5, chosen by the mean J, checked.
%
%   sel = select_map_multiseed(true)   also writes the design to data/map.json (the previous design is kept once in the field design_v1)
%   Uses Model/common/select_multiseed.m with the Map evaluation, the stability gate calib_margin on the selection seed 1 and the bang-bang report calib_bangbang (seeds 0 and 1).
%   Pool = Map_CALIB_opt<k>_s00000.csv and Map_CALIB_ref<k>_s00000.csv of Result/Controllers/Map/Calib_v2. Output files in the same folder.
if nargin < 1, writeJson = false; end
suffix = '';
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Calib');
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
files = poolFiles(outDir, suffix);
spec = struct('name', 'Map', 'outDir', outDir, 'poolFiles', {files}, 'vn', {{'K', 'z', 'p_over_z', 'z1', 'p1_over_z1'}}, ...
    'evalFcn', @map_opt_eval, 'x2u', @map_x2u, 'seed0', 0, 'seeds', 1:5, 'nTop', 20, 'PMfin', 30, 'GMfin', 2, 'erelMax', 10, ...
    'marginFcn', @(x) marginGate(x, Cal, Ts0), 'bangbangFcn', @(x) bangbang(x, Cal, Ts0));
sel = select_multiseed(spec);
[Gj, w] = map_opt_plants();
d = xToDesign(sel.x, Ts0);
Rl = map_opt_margins(Gj, w, d);
lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1));
noLead = sel.x(3) < 1.02; noLag = sel.x(5) > 0.98;
uc = map_x2u(sel.x); atB = find(uc < 0.005 | uc > 0.995);
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
    jf = fullfile(modelDir, 'data', 'map.json');
    J = jsondecode(fileread(jf));
    if ~isfield(J, 'design_v1'), J.design_v1 = J.design; end
    B = sel.bangbang;
    J.design = struct('Ts_ctrl', d.Ts_ctrl, 'Kmax', d.Kmax, 'Ts0', Ts0, 'lead', d.lead, 'lag', d.lag, ...
        'rule', ruleText(), ...
        'CALIB_J_mean_seeds_1_5', sel.Jbar, 'CALIB_J_sigma', sel.sigma, 'CALIB_J_per_seed', sel.Jseeds, 'CALIB_R_pct_mean', sel.Rbar, 'CALIB_S_Nm_mean', sel.Sbar, ...
        'CALIB_TV_mean', sel.TVbar, 'CALIB_rev_pct_mean', 100 * sel.revbar, 'CALIB_erel_max_pct', sel.erelMax, 'CALIB_J_search_seed0', sel.Jsearch, 'rank_at_seed0', sel.rank0, ...
        'rank_correlation', sel.rankCorr, 'PM_deg', Rl.PM, 'GM', Rl.GM, 'HF_gain', Rl.HF, 'lag_gain_2Hz', lagGain, 'no_lead', noLead, 'no_lag', noLag, ...
        'margin_ratio_gain', sel.margin.ratio_gain, 'margin_ratio_delay', sel.margin.ratio_delay, 'active', {active}, ...
        'n_region', sel.nRegion, 'n_pool', sel.nPool, 'search_seed', 0, 'selection_seeds', 1:5, 'map_source_date', Jm.design.date, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    if ~isempty(fieldnames(B)), J.design.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp); end
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_map_multiseed: design written to %s\n', jf);
end
end

function M = marginGate(x, Cal, Ts0)
d = xToDesign(x, Ts0);
M = calib_margin('Model_Map', 1, map_variables(Cal, d));
Simulink.sdi.clear;
end

function B = bangbang(x, Cal, Ts0)
d = xToDesign(x, Ts0);
B = calib_bangbang('Model_Map', 0, map_variables(Cal, d));
Simulink.sdi.clear;
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)));
end

function s = tf2s(b)
if b, s = 'present'; else, s = 'absent'; end
end

function f = poolFiles(dirName, suffix)
% search files of one run: Map_CALIB_opt<k><suffix>_s00000.csv and Map_CALIB_ref<k><suffix>_s00000.csv (exact suffix, so run 1 never picks up run 2)
L = dir(fullfile(dirName, 'Map_CALIB_*_s00000.csv'));
keep = ~cellfun(@isempty, regexp({L.name}, ['^Map_CALIB_opt\d+' suffix '_s00000\.csv$'], 'once'));
f = cellstr(fullfile(dirName, {L(keep).name}));
end

function s = ruleText()
s = 'min mean J = R*S over CALIB seeds 1-5 among the 20 best distinct designs of the search at seed 0 (surrogateopt x3 + patternsearch x3)';
s = [s '; CALIB v2, linear PM >= 30 deg and GM >= 2 applied during the search (2026-10-18)'];
end
