function sel = select_multiseed(spec)
%SELECT_MULTISEED Stages 2-4 of the common selection method (Documents/Shared/KeHoach_ChonNhieuSeed.txt Part 3): from the evaluations of the search (seed x0000)
%   take the 20 best DISTINCT designs, re-score each on the five selection seeds x0001-x0005, choose by the MEAN J, check the chosen design. Shared by every controller.
%
%   sel = select_multiseed(spec)   spec is a struct with the fields
%     name         controller name (file names)            outDir      folder for the csv files (result_dir(<ctrl>, 'Calib'))
%     poolFiles    cell array of the search csv files (stage 1: surrogateopt and patternsearch of all runs; mapopt_eval format)
%     vn           cell array of the design variable column names (the first columns of the csv)
%     evalFcn      @(x, seed, csvFile) -> struct with J, R, S, TV, erel, rev, PM, GM, simulated   (a design already in csvFile for that seed is not simulated again)
%     x2u          @(x) -> normalized variables in [0,1] (distinctness is measured on them)
%     seed0        search seed (not used in the mean)      seeds   selection seeds (default seed0 + 1 : seed0 + 5)
%     nTop         number of designs kept (default 20)     minDist  distinctness in normalized units (default 0.02)
%     PMfin, GMfin final linear requirement (default 30 deg, 2)      erelMax  accuracy gate at EVERY selection seed (default 5 %)
%     marginFcn    @(x) -> struct(pass, ratio_gain, ratio_delay)   the simulation stability gate (calib_margin) for one design, run on the chosen design
%     bangbangFcn  @(x) -> struct (reported, optional)
%   Rules (written in advance): pool = designs simulated and feasible at the search seed (c1..c4 <= 0) with linear PM >= PMfin and GM >= GMfin, sorted by J; distinct =
%   greedy, at least minDist apart (max over the normalized variables); each of the nTop designs is run on every selection seed; gate: erel <= erelMax at every seed;
%   score: Jbar = mean over the seeds of R_k S_k (the search seed is NOT used), sigma = sample standard deviation; best = smallest Jbar; tie: designs whose Jbar differs
%   from the best by less than sigma of the best are equal, take the one with the largest linear PM; then marginFcn on the chosen design, the next one in the order if it fails.
%   Files in outDir: <name>_CALIB_top_s<seed0>.csv, <name>_CALIB_best_s<first>-s<last>.csv (all rows), <name>_CALIB_pick_ms.csv (the table of the nTop designs).
%   Output sel: x, Jbar, sigma, per-seed vectors, PM, GM, HF, margin, bangbang, rank at the search seed, rank correlation, region, nPool, nTop.
if ~isfield(spec, 'seeds') || isempty(spec.seeds), spec.seeds = spec.seed0 + (1:5); end
if ~isfield(spec, 'nTop'), spec.nTop = 20; end
if ~isfield(spec, 'minDist'), spec.minDist = 0.02; end
if ~isfield(spec, 'PMfin'), spec.PMfin = 30; end
if ~isfield(spec, 'GMfin'), spec.GMfin = 2; end
if ~isfield(spec, 'erelMax'), spec.erelMax = 5; end
vn = spec.vn; nv = numel(vn); ns = numel(spec.seeds);

%% pool of the search
P = table();
for i = 1:numel(spec.poolFiles)
    if isfile(spec.poolFiles{i}), P = [P; readtable(spec.poolFiles{i})]; end %#ok<AGROW>
end
P = P(P.seed == spec.seed0, :);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0 & isfinite(P.J) & P.PM_deg >= spec.PMfin & P.GM >= spec.GMfin;
F = P(feas, :); F.Jv = F.R_pct .* F.S_Nm;
F = sortrows(F, 'Jv');
[~, iu] = unique(round(table2array(F(:, vn)), 6, 'significant'), 'rows', 'stable'); F = F(sort(iu), :);   % identical designs (start of patternsearch)
fprintf('select_multiseed(%s): %d evaluations at seed %d, %d feasible with PM >= %g and GM >= %g\n', spec.name, height(P), spec.seed0, height(F), spec.PMfin, spec.GMfin);
assert(height(F) > 0, 'select_multiseed: no feasible design');

%% stage 2: top group of distinct designs
keep = false(height(F), 1); U = zeros(0, nv);
for i = 1:height(F)
    u = spec.x2u(table2array(F(i, vn)));
    if isempty(U) || min(max(abs(U - u), [], 2)) >= spec.minDist
        keep(i) = true; U(end + 1, :) = u; %#ok<AGROW>
    end
    if nnz(keep) >= spec.nTop, break; end
end
top = F(keep, :);
nT = height(top);
top.rank0 = (1:nT)';
writetable(top, fullfile(spec.outDir, sprintf('%s_CALIB_top_s%05d.csv', spec.name, spec.seed0)));
fprintf('stage 2: %d distinct designs kept (J at the search seed %.4f .. %.4f)\n', nT, top.Jv(1), top.Jv(end));

%% stage 3: the selection seeds
bestFile = fullfile(spec.outDir, sprintf('%s_CALIB_best_s%05d-s%05d.csv', spec.name, spec.seeds(1), spec.seeds(end)));
Jk = nan(nT, ns); Rk = Jk; Sk = Jk; Ek = Jk; TVk = Jk; REVk = Jk;
for i = 1:nT
    x = table2array(top(i, vn));
    for k = 1:ns
        o = spec.evalFcn(x, spec.seeds(k), bestFile);
        Jk(i, k) = o.R * o.S; Rk(i, k) = o.R; Sk(i, k) = o.S; Ek(i, k) = o.erel; TVk(i, k) = o.TV; REVk(i, k) = o.rev;
    end
    fprintf('  design %2d/%d: J search %.4f, mean over seeds %.4f (sigma %.4f), max e_rel %.2f %%\n', i, nT, top.Jv(i), mean(Jk(i, :)), std(Jk(i, :)), max(Ek(i, :)));
end
top.Jbar = mean(Jk, 2); top.sigma = std(Jk, 0, 2); top.Rbar = mean(Rk, 2); top.Sbar = mean(Sk, 2); top.TVbar = mean(TVk, 2); top.revbar = mean(REVk, 2);
top.erelMax = max(Ek, [], 2); top.gate = top.erelMax <= spec.erelMax;
for k = 1:ns, top.(sprintf('J_s%d', spec.seeds(k))) = Jk(:, k); end

%% choice with the tie rule, then the stability gate
ok = find(top.gate);
assert(~isempty(ok), 'select_multiseed: no design passes the accuracy gate at every selection seed');
[~, io] = sort(top.Jbar(ok)); order = ok(io);
b = order(1);
tie = order(top.Jbar(order) - top.Jbar(b) < top.sigma(b));
[~, ip] = max(top.PM_deg(tie)); chosen = tie(ip);
order = [chosen; order(order ~= chosen)];
pick = 0; M = struct('pass', false, 'ratio_gain', NaN, 'ratio_delay', NaN);
top.margin_pass = nan(nT, 1);
for j = 1:numel(order)
    i = order(j);
    M = spec.marginFcn(table2array(top(i, vn)));
    top.margin_pass(i) = M.pass;
    if M.pass, pick = i; break; end
    fprintf('  design %d fails the stability gate (ratios %.2f / %.2f), next\n', i, M.ratio_gain, M.ratio_delay);
end
assert(pick > 0, 'select_multiseed: no candidate passes the stability gate');
c = top(pick, :);
B = struct();
if isfield(spec, 'bangbangFcn') && ~isempty(spec.bangbangFcn), B = spec.bangbangFcn(table2array(c(1, vn))); end

%% reports: selection effect and region
r0 = tiedrankLocal(top.Jv); r1 = tiedrankLocal(top.Jbar);
rc = corrcoef(r0, r1); rankCorr = rc(1, 2);
region = top(top.gate & top.Jbar <= 1.05 * min(top.Jbar(top.gate)), :);
writetable(top, fullfile(spec.outDir, sprintf('%s_CALIB_pick_ms.csv', spec.name)));
fprintf('chosen: design %d (rank %d at the search seed): Jbar %.4f +- %.4f, Rbar %.2f %%, Sbar %.4f, max e_rel %.2f %%, PM %.1f, GM %.2f, margin ratios %.2f / %.2f\n', ...
    pick, c.rank0, c.Jbar, c.sigma, c.Rbar, c.Sbar, c.erelMax, c.PM_deg, c.GM, M.ratio_gain, M.ratio_delay);
fprintf('rank correlation search seed vs mean of %d seeds: %.2f; region (Jbar within 5 %%): %d designs; tie group size %d\n', ns, rankCorr, height(region), numel(tie));
sel = struct('x', table2array(c(1, vn)), 'Jbar', c.Jbar, 'sigma', c.sigma, 'Jseeds', Jk(pick, :), 'Rbar', c.Rbar, 'Sbar', c.Sbar, 'TVbar', c.TVbar, 'revbar', c.revbar, ...
    'erelMax', c.erelMax, 'PM', c.PM_deg, 'GM', c.GM, 'HF', c.HF, 'Jsearch', c.Jv, 'rank0', c.rank0, 'margin', M, 'bangbang', B, 'rankCorr', rankCorr, ...
    'nRegion', height(region), 'nTie', numel(tie), 'nPool', height(F), 'nTop', nT, 'top', top);
end

function r = tiedrankLocal(v)
% rank 1 = smallest, ties get the mean rank (the Statistics Toolbox tiedrank is not required)
[s, i] = sort(v(:)); r = zeros(size(s)); k = 1;
while k <= numel(s)
    j = k; while j < numel(s) && s(j + 1) == s(k), j = j + 1; end
    r(i(k:j)) = mean(k:j); k = j + 1;
end
end
