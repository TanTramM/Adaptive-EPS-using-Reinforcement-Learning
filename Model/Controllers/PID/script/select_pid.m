function sel = select_pid(finalSeed2)
%SELECT_PID Select (Kp, Ki, Kd, Tf) of the PID from PID_candidates_TK.csv by the shared rule of QuyChuan.txt v2 (same rule as select_pi.m).
%
%   sel = select_pid()          choose, write data/pid.json "design" (preliminary, used as the centre of the fine grid)
%   sel = select_pid(true)      same, then also run the second seed 10001 on the chosen point and store it in the design
%
%   Gates in the priority order of QuyChuan 5.6: (1) stability with margin (tk_margin), (2) reverse assist rev <= 1 %, (3) no bang-bang
%   (tk_bangbang, 1 %), (4) static accuracy e_rel <= 3 %. Rev and e_rel are read from the sweep table; margin and bang-bang are evaluated
%   by simulation on the finalists only (R within 5 % of the smallest admissible R, increasing S, pick_by_tolerance).
%   Fallback (QuyChuan 5.6): no point passes rev and e_rel strictly -> drop the lowest gate (e_rel) first, then rev, and take the points
%   that violate the gates the least (penalty = excess of rev and e_rel over their limits, each normalised by its limit, e_rel counted last).

if nargin < 1, finalSeed2 = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
TOL = 0.05; BB = 0.01; EREL = 3.0; REV = 1.0; NFIN = 8;

outDir = result_dir('PID', 'Sweep');
T = readtable(fullfile(outDir, 'PID_candidates_TK.csv'));
fin = isfinite(T.R_pct) & isfinite(T.S_Nm);
strict = fin & T.erel_pct <= EREL & T.rev_pct <= REV;
if any(strict)
    adm = strict; tier = 'strict (rev <= 1 %, e_rel <= 3 %)';
else
    % same fallback as select_pi.m (QuyChuan 5.6, sensitivity limits rev <= 5 %, e_rel <= 5 %), then least violation
    sens = fin & T.erel_pct <= 5.0 & T.rev_pct <= 5.0;
    if any(sens)
        adm = sens; tier = 'fallback: no point passes rev <= 1 % and e_rel <= 3 %; admissible = rev <= 5 % and e_rel <= 5 %';
    else
        pen = max(0, T.rev_pct - REV) / REV + max(0, T.erel_pct - EREL) / EREL;
        pen(~fin) = Inf;
        [~, o] = sort(pen); adm = false(height(T), 1); adm(o(1:min(10, nnz(fin)))) = true;
        tier = 'fallback: 10 points of least violation of rev and e_rel';
    end
end
fprintf('select_pid: %d candidates, admissible tier: %s (%d points)\n', height(T), tier, nnz(adm));
idx = pick_by_tolerance(T.R_pct, T.S_Nm, adm, TOL);
idx = idx(1:min(NFIN, numel(idx)));
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'PID', 'load_pid.m'), '\', '/')));
mdl = 'Model_PID';
if ~bdIsLoaded(mdl), load_system(mdl); end

rows = zeros(0, 14); pick = 0;
for k = 1:numel(idx)
    i = idx(k);
    vars = struct('PID_Kp', T.Kp(i), 'PID_Ki', T.Ki_1_per_s(i), 'PID_Kd', T.Kd_s(i), 'PID_Tf', T.Tf_s(i), 'PID_Kaw', T.Ki_1_per_s(i) / T.Kp(i));
    B = tk_bangbang(mdl, 10000, vars, BB);
    M = tk_margin(mdl, 10000, vars);
    rows(end+1, :) = [T.Kp(i) T.Ki_1_per_s(i) T.Kd_s(i) T.Tf_s(i) T.R_pct(i) T.S_Nm(i) T.TV_Nm_per_s(i) T.erel_pct(i) T.rev_pct(i) ...
        B.delta B.pass M.ratio_gain M.ratio_delay M.pass]; %#ok<AGROW>
    fprintf('  finalist %d: Kp %.3f Ki %.2f Kd %.4f Tf %.4f | R %.2f S %.4f TV %.1f erel %.2f rev %.2f | bb delta %.4f %d | margin %.2f %.2f %d\n', ...
        k, rows(end, 1:9), rows(end, 10), rows(end, 11), rows(end, 12), rows(end, 13), rows(end, 14));
    if pick == 0 && B.pass && M.pass, pick = k; end
end
if pick == 0, warning('select_pid:none', 'no finalist passed margin and bang-bang: taking the first (least violation)'); pick = 1; end
F = array2table(rows, 'VariableNames', {'Kp', 'Ki_1_per_s', 'Kd_s', 'Tf_s', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', ...
    'f_sat_delta', 'pass_no_bangbang', 'margin_ratio_gain', 'margin_ratio_delay', 'pass_margin'});
F.chosen = false(height(F), 1); F.chosen(pick) = true;
writetable(F, fullfile(outDir, 'PID_selection.csv'));
r = F(pick, :);

% grid boundary check (QuyChuan 6.1) on the coarse+fine table
edge = {'Kp', r.Kp, T.Kp; 'Ki', r.Ki_1_per_s, T.Ki_1_per_s; 'Kd', r.Kd_s, T.Kd_s; 'Tf', r.Tf_s, T.Tf_s};
for e = 1:size(edge, 1)
    v = edge{e, 3};
    if abs(edge{e, 2} - min(v)) < 1e-9 || abs(edge{e, 2} - max(v)) < 1e-9
        fprintf('select_pid: WARNING chosen %s = %g lies on the edge of the explored range (QuyChuan 6.1)\n', edge{e, 1}, edge{e, 2});
    end
end

sel = struct('Kp', r.Kp, 'Ki', r.Ki_1_per_s, 'Kd', r.Kd_s, 'Tf', r.Tf_s, 'Kaw', r.Ki_1_per_s / r.Kp, 'TK_R_pct', r.R_pct, 'TK_S_Nm', r.S_Nm, ...
    'TK_TV_Nm_per_s', r.TV_Nm_per_s, 'TK_erel_pct', r.erel_pct, 'TK_rev_pct', r.rev_pct, 'f_sat_delta', r.f_sat_delta, ...
    'margin_ratio_gain', r.margin_ratio_gain, 'margin_ratio_delay', r.margin_ratio_delay, 'tier', tier, 'design_seed', 10000);
if finalSeed2
    vars = struct('PID_Kp', sel.Kp, 'PID_Ki', sel.Ki, 'PID_Kd', sel.Kd, 'PID_Tf', sel.Tf, 'PID_Kaw', sel.Kaw);
    [~, m2] = tk_run(mdl, 10001, vars);
    sel.seed_10001_R_pct = m2.R; sel.seed_10001_S_Nm = m2.S; sel.seed_10001_TV_Nm_per_s = m2.TV; sel.seed_10001_erel_pct = m2.erel; sel.seed_10001_rev_pct = 100 * m2.rev;
    fprintf('select_pid: seed 10001: R %.2f S %.4f TV %.1f erel %.2f rev %.2f\n', m2.R, m2.S, m2.TV, m2.erel, 100 * m2.rev);
end
sel.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
jsonPath = fullfile(modelDir, 'data', 'pid.json');
J = jsondecode(fileread(jsonPath)); J.design = sel;
fid = fopen(jsonPath, 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
fprintf('select_pid: CHOSEN Kp %.3f Ki %.2f Kd %.4f Tf %.4f (R %.2f, S %.4f, TV %.1f, erel %.2f, rev %.2f); written to data/pid.json\n', ...
    sel.Kp, sel.Ki, sel.Kd, sel.Tf, sel.TK_R_pct, sel.TK_S_Nm, sel.TK_TV_Nm_per_s, sel.TK_erel_pct, sel.TK_rev_pct);
end
