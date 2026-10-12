function sel = select_smc()
%SELECT_SMC Select (lambda, Phi, Tf) of the SMC-sat from SMC_CALIB_sweep_s20000.csv by the shared rule of QuyChuan.txt v2 (same rule as select_pid.m).
%
%   sel = select_smc()   choose and write data/smc.json "design"
%
%   Gate order of QuyChuan 5.6: (1) stability with margin (calib_margin), (2) reverse assist rev <= 1 %, (3) no bang-bang (calib_bangbang, 1 %),
%   (4) static accuracy e_rel <= 5 %. Rev and e_rel are read from the sweep table; margin and bang-bang are evaluated by simulation on the
%   finalists (R within 5 % of the smallest admissible R, increasing S, pick_by_tolerance). Fallback as in select_pid: drop e_rel first, then rev.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
TOL = 0.05; BB = 0.01; EREL = 5.0; REV = 1.0; NFIN = 8; SEED = 20000;

outDir = result_dir('SMC', 'Calib');
T = readtable(fullfile(outDir, 'SMC_CALIB_sweep_s20000.csv'));
fin = isfinite(T.R_pct) & isfinite(T.S_Nm);
strict = fin & T.erel_pct <= EREL & T.rev_pct <= REV;
if any(strict)
    adm = strict; tier = 'strict (rev <= 1 %, e_rel <= 5 %)';
else
    revOk = fin & T.rev_pct <= REV;
    if any(revOk)
        adm = revOk; tier = 'fallback: e_rel gate dropped, rev <= 1 % kept';
    else
        pen = max(0, T.rev_pct - REV) / REV + 0.1 * max(0, T.erel_pct - EREL) / EREL;
        pen(~fin) = Inf;
        [~, o] = sort(pen); adm = false(height(T), 1); adm(o(1:min(10, nnz(fin)))) = true;
        tier = 'fallback: least violation of rev (e_rel weighted 0.1)';
    end
end
fprintf('select_smc: %d candidates, admissible tier: %s (%d points)\n', height(T), tier, nnz(adm));
idx = pick_by_tolerance(T.R_pct, T.S_Nm, adm, TOL);
idx = idx(1:min(NFIN, numel(idx)));
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'SMC', 'load_smc.m'), '\', '/')));
mdl = 'Model_SMC';
if ~bdIsLoaded(mdl), load_system(mdl); end

rows = zeros(0, 13); pick = 0;
for k = 1:numel(idx)
    i = idx(k);
    vars = struct('SMC_lambda', T.lambda_rad_s(i), 'SMC_Phi', T.Phi_Nm_s(i), 'SMC_Tf', T.Tf_s(i));
    B = calib_bangbang(mdl, SEED, vars, BB);
    M = calib_margin(mdl, SEED, vars);
    rows(end+1, :) = [T.lambda_rad_s(i) T.Phi_Nm_s(i) T.Tf_s(i) T.R_pct(i) T.S_Nm(i) T.TV_Nm_per_s(i) T.erel_pct(i) T.rev_pct(i) ...
        B.delta B.pass M.ratio_gain M.ratio_delay M.pass]; %#ok<AGROW>
    fprintf('  finalist %d: lambda %.1f Phi %.2f Tf %.3f | R %.2f S %.4f TV %.1f erel %.2f rev %.2f | bb delta %.4f %d | margin %.2f %.2f %d\n', ...
        k, rows(end, 1:8), rows(end, 9), rows(end, 10), rows(end, 11), rows(end, 12), rows(end, 13));
    if pick == 0 && B.pass && M.pass, pick = k; end
end
if pick == 0, warning('select_smc:none', 'no finalist passed margin and bang-bang: taking the first (least violation)'); pick = 1; end
F = array2table(rows, 'VariableNames', {'lambda_rad_s', 'Phi_Nm_s', 'Tf_s', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', ...
    'f_sat_delta', 'pass_no_bangbang', 'margin_ratio_gain', 'margin_ratio_delay', 'pass_margin'});
F.chosen = false(height(F), 1); F.chosen(pick) = true;
writetable(F, fullfile(outDir, 'SMC_CALIB_pick_s20000.csv'));
r = F(pick, :);

edge = {'lambda', r.lambda_rad_s, T.lambda_rad_s; 'Phi', r.Phi_Nm_s, T.Phi_Nm_s; 'Tf', r.Tf_s, T.Tf_s};
for e = 1:size(edge, 1)
    v = edge{e, 3};
    if abs(edge{e, 2} - min(v)) < 1e-9 || abs(edge{e, 2} - max(v)) < 1e-9
        fprintf('select_smc: WARNING chosen %s = %g lies on the edge of the explored range (QuyChuan 6.1)\n', edge{e, 1}, edge{e, 2});
    end
end

sel = struct('lambda', r.lambda_rad_s, 'Phi', r.Phi_Nm_s, 'Tf', r.Tf_s, 'CALIB_R_pct', r.R_pct, 'CALIB_S_Nm', r.S_Nm, ...
    'CALIB_TV_Nm_per_s', r.TV_Nm_per_s, 'CALIB_erel_pct', r.erel_pct, 'CALIB_rev_pct', r.rev_pct, 'f_sat_delta', r.f_sat_delta, ...
    'margin_ratio_gain', r.margin_ratio_gain, 'margin_ratio_delay', r.margin_ratio_delay, 'tier', tier, 'design_seed', SEED);
sel.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
jsonPath = fullfile(modelDir, 'data', 'smc.json');
J = jsondecode(fileread(jsonPath)); J.design = sel;
fid = fopen(jsonPath, 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
fprintf('select_smc: CHOSEN lambda %.1f Phi %.2f Tf %.3f (R %.2f, S %.4f, TV %.1f, erel %.2f, rev %.2f); written to data/smc.json\n', ...
    sel.lambda, sel.Phi, sel.Tf, sel.CALIB_R_pct, sel.CALIB_S_Nm, sel.CALIB_TV_Nm_per_s, sel.CALIB_erel_pct, sel.CALIB_rev_pct);
end
