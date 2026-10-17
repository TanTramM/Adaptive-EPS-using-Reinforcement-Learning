function sel = select_pidopt(writeJson)
%SELECT_PIDOPT Stages 2-4 of the common method (Documents/Shared/KeHoach_ChonNhieuSeed.txt Phase 3), for PIDOpt (Kp, Ki, Kd, Tf; wide box pidopt_u2x), seeds 10000 (search) and 10001-10005 (choice).
%
%   sel = select_pidopt(true)    also writes the design to data/pidopt.json (field design; the previous design stays in design_1seed_box005)
%   Stage 2 TOP GROUP: pool every evaluation of the three chains (PIDOpt_CALIB_opt*_s10000.csv, _ref*_s10000.csv); keep the feasible ones at seed 10000 (simulated, e_rel <= 5 %, linear
%     PM >= 30 deg and GM >= 2, constraints c1-c4 <= 0); sort by J; the 20 best DISTINCT designs (at least 0.02 apart in one normalized variable u); written to PIDOpt_CALIB_top_s10000.csv.
%   Stage 3 CHOICE: each top design on CALIB at seeds 10001-10005 (20 x 5 = 100 runs, cached in PIDOpt_CALIB_best_s10001-s10005.csv, resumable): J_k = R_k S_k, mean J_bar, sample standard
%     deviation sigma_J (n - 1), maximum e_rel; gate: e_rel <= 5 % at EVERY seed; best = smallest J_bar; tie (J_bar within sigma_J of the smallest, Q4): the largest linear PM.
%   Stage 4 CHECK: calib_margin at seed 10001 (not passed: the next one), bang-bang (calib_bangbang), reverse assist, PM, GM, high-frequency gain, active bounds of the box, the rank at
%     seed 10000 and the rank correlation between J at seed 10000 and J_bar, the optimal region (top designs with J_bar within 5 % of the smallest); chain convergence (best J per run).
%   Seed 10000 is NOT in the mean (Q3). The common select_multiseed.m of the plan did not exist when this was written; its result must be cross-checked against this file when it does.
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('PIDOpt', 'Calib');
vn = {'Kp', 'Ki', 'Kd', 'Tf'}; seeds = 10001:10005; nTop = 20; PMfin = 30; GMfin = 2; Ts = 1e-3;
mdl = 'Model_PIDOpt';

%% stage 2: pool and top group
files = [dir(fullfile(outDir, 'PIDOpt_CALIB_opt*_s10000.csv')); dir(fullfile(outDir, 'PIDOpt_CALIB_ref*_s10000.csv'))];
P = table();
for i = 1:numel(files)
    T = readtable(fullfile(outDir, files(i).name));
    tok = regexp(files(i).name, 'PIDOpt_CALIB_(opt|ref)(\d+)_', 'tokens', 'once');
    T.stage = repmat(string(tok{1}), height(T), 1); T.run = repmat(str2double(tok{2}), height(T), 1);
    P = [P; T]; %#ok<AGROW>
end
nEval = height(P); nSim = nnz(P.simulated == 1);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0;
F = P(feas, :); F.Jv = F.R_pct .* F.S_Nm;
[~, iu] = unique(round(table2array(F(:, vn)), 8, 'significant'), 'rows', 'stable');
F = sortrows(F(iu, :), 'Jv');
Jstar = F.Jv(1);
runs = unique(F.run)'; bestRun = arrayfun(@(r) min(F.Jv(F.run == r)), runs);
fprintf('select_pidopt: stage 1 pooled %d evaluations (%d simulated), %d feasible distinct; J* %.4f (R %.3f %%, S %.4f); best J per run %s, %d of %d within 3 %%\n', ...
    nEval, nSim, height(F), Jstar, F.R_pct(1), F.S_Nm(1), mat2str(bestRun, 4), nnz(bestRun <= 1.03 * Jstar), numel(runs));
Fok = F(F.PM_deg >= PMfin & F.GM >= GMfin, :);
assert(height(Fok) > 0, 'no feasible design with PM >= %g and GM >= %g', PMfin, GMfin);
U = zeros(height(Fok), 4); for k = 1:height(Fok), U(k, :) = pidopt_x2u(table2array(Fok(k, vn))); end
keep = false(height(Fok), 1);
for k = 1:height(Fok)
    if nnz(keep) >= nTop, break; end
    if ~any(keep) || all(arrayfun(@(q) max(abs(U(k, :) - U(q, :))) >= 0.02, find(keep))), keep(k) = true; end
end
Top = Fok(keep, :); Utop = U(keep, :);
Top.rank_s10000 = (1:height(Top))';
nT = height(Top);
fprintf('stage 2: top group %d distinct designs (J at seed 10000 %.4f .. %.4f)\n', nT, Top.Jv(1), Top.Jv(end));
writetable(Top, fullfile(outDir, 'PIDOpt_CALIB_top_s10000.csv'));

%% stage 3: 5 choice seeds
bestFile = fullfile(outDir, 'PIDOpt_CALIB_best_s10001-s10005.csv');
Jk = nan(nT, numel(seeds)); Ek = Jk; TVk = Jk; REVk = Jk; Rk = Jk; Sk = Jk;
for i = 1:nT
    for s = 1:numel(seeds)
        o = pidlag_eval('PIDOpt', table2array(Top(i, vn)), seeds(s), bestFile);
        Jk(i, s) = o.R * o.S; Ek(i, s) = o.erel; TVk(i, s) = o.TV; REVk(i, s) = o.rev; Rk(i, s) = o.R; Sk(i, s) = o.S;
    end
end
Top.Jbar = mean(Jk, 2); Top.sigmaJ = std(Jk, 0, 2); Top.Rbar = mean(Rk, 2); Top.Sbar = mean(Sk, 2); Top.TVbar = mean(TVk, 2); Top.erel_max = max(Ek, [], 2); Top.rev_bar = mean(REVk, 2);
for s = 1:numel(seeds), Top.(sprintf('J_s%d', seeds(s))) = Jk(:, s); end
gate = Top.erel_max <= 5 & all(isfinite(Jk), 2);
assert(any(gate), 'no top design passes e_rel <= 5 %% at every choice seed');
Jg = Top.Jbar; Jg(~gate) = Inf;
[Jmin, im] = min(Jg);
tie = gate & (Top.Jbar - Jmin) <= Top.sigmaJ(im);                      % Q4: within the standard deviation of the smallest
order = (1:nT)';
cand = order(tie);
[~, ip] = sort(Top.PM_deg(cand), 'descend'); cand = cand(ip);          % ties: the largest linear PM first
rest = order(gate & ~tie); [~, ir] = sort(Top.Jbar(rest)); rest = rest(ir);
ranking = [cand; rest];
Top.tie_group = double(tie);
ranksJ0 = (1:nT)'; [~, o2] = sort(Top.Jbar); rb = zeros(nT, 1); rb(o2) = 1:nT;
rho = corrcoef(ranksJ0, rb); rho = rho(1, 2);                             % Spearman: both are ranks
region = nnz(gate & Top.Jbar <= 1.05 * Jmin);
fprintf('stage 3: J_bar smallest %.4f (sigma %.4f), %d designs tie, %d pass the e_rel gate, optimal region %d, rank correlation seed 10000 vs J_bar %.2f\n', Jmin, Top.sigmaJ(im), nnz(tie), nnz(gate), region, rho);
writetable(Top, fullfile(outDir, 'PIDOpt_CALIB_best_summary.csv'));

%% stage 4: check
[Gj, w] = mappid_plants();
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'PIDOpt', 'load_pidopt.m'), '\', '/')));
pick = 0;
for q = 1:numel(ranking)
    i = ranking(q);
    d = xToDesign(table2array(Top(i, vn)), Ts);
    M = calib_margin(mdl, seeds(1), pidlag_variables('PIDOpt', d));
    Simulink.sdi.clear;
    fprintf('    candidate %d (rank by rule %d): J_bar %.4f, calib_margin %d (ratios %.2f / %.2f)\n', i, q, Top.Jbar(i), M.pass, M.ratio_gain, M.ratio_delay);
    if M.pass, pick = i; pm = M; break; end
end
assert(pick > 0, 'no candidate passes calib_margin');
c = Top(pick, :); x = table2array(c(1, vn)); d = xToDesign(x, Ts);
Rl = pidlag_margins(Gj, w, d);
B = calib_bangbang(mdl, 10000, pidlag_variables('PIDOpt', d));
Simulink.sdi.clear;
uc = pidopt_x2u(x); atB = find(uc < 0.005 | uc > 0.995);
active = {};
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if Rl.PM < PMfin + 2, active{end + 1} = sprintf('final linear PM near %g deg', PMfin); end
if Rl.GM < GMfin + 0.1, active{end + 1} = sprintf('final linear GM near %g', GMfin); end
if isempty(active), active = {'none (interior optimum)'}; end
% box-boundary rule (DieuKhien_MapPID.txt G9): fraction of the optimal-region designs (J within 5 % of J*, all seeds-10000 feasible designs) within 5 % of a box edge, per variable
Rg = F(F.Jv <= 1.05 * Jstar, :); Ur = zeros(height(Rg), 4); for k = 1:height(Rg), Ur(k, :) = pidopt_x2u(table2array(Rg(k, vn))); end
edgeFrac = [mean(Ur < 0.05); mean(Ur > 0.95)];
fprintf('stage 4: CHOSEN design %d (rank %d at seed 10000): Kp %.4g Ki %.4g Kd %.4g Tf %.4g | J_bar %.4f +- %.4f, e_rel max %.2f %%, PM %.1f GM %.2f HF %.1f, margin ratios %.2f / %.2f\n', ...
    pick, c.rank_s10000, x, c.Jbar, c.sigmaJ, c.erel_max, Rl.PM, Rl.GM, Rl.HF, pm.ratio_gain, pm.ratio_delay);
fprintf('    bang-bang f_ideal %.4f f_noisy %.4f delta %.4f spread %.4f | rev %.2f %% | active: %s\n', B.f_ideal, B.f_noisy, B.delta, B.disp, c.rev_bar, strjoin(active, '; '));
fprintf('    box edges, share of optimal-region designs (J within 5 %% of J*, n = %d) in the 5 %% next to the lower / upper edge:\n      lower %s\n      upper %s\n', height(Rg), mat2str(edgeFrac(1, :), 2), mat2str(edgeFrac(2, :), 2));
sel = struct('x', x, 'design', d, 'Jbar', c.Jbar, 'sigmaJ', c.sigmaJ, 'Rbar', c.Rbar, 'Sbar', c.Sbar, 'erel_max', c.erel_max, 'PM', Rl.PM, 'GM', Rl.GM, 'HF', Rl.HF, ...
    'bangbang', B, 'rho', rho, 'region', region, 'nTie', nnz(tie), 'bestPerRun', bestRun, 'edgeFrac', edgeFrac, 'active', {active}, 'pick', pick);
Top.chosen = double((1:nT)' == pick);
writetable(Top, fullfile(outDir, 'PIDOpt_CALIB_pick_ms.csv'));
if writeJson
    jf = fullfile(modelDir, 'data', 'pidopt.json');
    J = jsondecode(fileread(jf));
    q = struct('Kp', d.Kp, 'Ki', d.Ki, 'Kd', d.Kd, 'Tf', d.Tf);
    q.Kaw = ifelse(d.Ki > 0 && d.Kp > 0, d.Ki / d.Kp, 0);
    q.rule = 'common method 2026-10-16: search at seed 10000 (surrogateopt x3 + patternsearch x3, wide box), top 20, choice by J_bar over seeds 10001-10005 (e_rel <= 5 % at every seed), calib_margin';
    q.CALIB_Jbar = c.Jbar; q.CALIB_sigmaJ = c.sigmaJ; q.CALIB_Rbar_pct = c.Rbar; q.CALIB_Sbar_Nm = c.Sbar; q.CALIB_TVbar_Nm_per_s = c.TVbar; q.CALIB_erel_max_pct = c.erel_max; q.CALIB_rev_bar_pct = c.rev_bar;
    q.J_seed10000 = c.Jv; q.rank_seed10000 = c.rank_s10000; q.rank_correlation = rho; q.PM_deg = Rl.PM; q.GM = Rl.GM; q.HF_gain = Rl.HF;
    q.margin_ratio_gain = pm.ratio_gain; q.margin_ratio_delay = pm.ratio_delay;
    q.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp);
    q.n_evaluations_stage1 = nEval; q.n_simulations_stage1 = nSim; q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_pidopt: design written to %s\n', jf);
end
end

function d = xToDesign(x, Ts)
d = struct('Ts_ctrl', Ts, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
