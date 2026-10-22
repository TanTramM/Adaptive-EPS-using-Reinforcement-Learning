function out = compare_pareto_common(cmd, ctrls, varargin)
%COMPARE_PARETO_COMMON Re-evaluate the candidate sets of Map, PID and MapPID on the common seeds 99990-99994 and compare their Pareto fronts.
%   Plan: Documents/Shared/KeHoach_SoMatPareto.txt (rules 0(a)-0(g), written before any run; do not change them after seeing results).
%
%   compare_pareto_common('candidates', ctrls)                     build and print the candidate sets (0(a), 0(b))
%   compare_pareto_common('check', ctrls)                          checks of 2.3: counts, chosen point reproduced at its search seed, MapPID locked Map block
%   compare_pareto_common('run', ctrls, workerId, nWorkers[, phases])   phase 1 = candidates on the search-seed front, phase 2 = the rest (default [1 2]);
%                                                                  each worker takes the points with mod(k-1, nWorkers) == workerId-1 inside a phase
%   compare_pareto_common('margin', ctrls, workerId, nWorkers[, 'Mode', m, 'Rmax', r])   calib_margin (seed 99990) for the current front points that have no margin result yet (0(e));
%                                                                  Mode 'full' | 'safe' | 'both' (default) picks which front's pending points are run, Rmax (default Inf) skips points with R_tb above it;
%                                                                  the points are run in order of increasing R_tb. Order and scope only: the rule 0(e) and the front are unchanged;
%                                                                  'Rmin' skips points with R_tb below it; 'List' = csv (design columns) of fixed points to run instead of the pending ones (points that already
%                                                                  have a margin result are skipped, the split mod nWorkers is by position in the file)
%   compare_pareto_common('taillist', {'Map'}, rThreshold)         writes ParetoCommon_Map_tail_list.csv: safe-front points pending margin with R_tb > rThreshold (both machines split the same list)
%   compare_pareto_common('select', ctrls[, writeJson])            KeHoachMatlab.txt 10.1: final design on the margin-checked fronts; writes ParetoCommon_select.csv and _select_report.csv;
%                                                                  writeJson = true also backs up and rewrites data/<ctrl>.json (design_pre_pareto keeps the old design)
%   compare_pareto_common('front', ctrls)                          pure post-processing: 0(d), 0(e); writes points csv and ParetoCommon_fronts.csv; reports pending margins
%   compare_pareto_common('status', ctrls)                         progress counts
%   ctrls: cell array of 'Map', 'PID', 'MapPID'. Results in Result/Compare/Pareto_common/. Every evaluation is cached in the csv of its worker (resumable).
if nargin < 2 || isempty(ctrls), ctrls = {'Map', 'PID', 'MapPID'}; end
if ischar(ctrls), ctrls = {ctrls}; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
outDir = fullfile(result_dir('Compare', 'Pareto_common'));
if ~exist(outDir, 'dir'), mkdir(outDir); end
out = struct();
seeds = 99990:99994;
switch lower(cmd)
    case 'candidates'
        for c = 1:numel(ctrls)
            C = candidates(ctrls{c});
            fprintf('[%s] candidates %d, on search-seed front (phase 1) %d, phase 2 %d\n', ctrls{c}, height(C), nnz(C.phase == 1), nnz(C.phase == 2));
            out.(ctrls{c}) = C;
        end
    case 'check'
        checkAll(ctrls);
    case 'run'
        workerId = varargin{1}; nWorkers = varargin{2};
        phases = [1 2]; if numel(varargin) >= 3, phases = varargin{3}; end
        for ph = phases
            for c = 1:numel(ctrls)
                runPhase(ctrls{c}, ph, workerId, nWorkers, seeds, outDir);
            end
        end
    case 'margin'
        workerId = varargin{1}; nWorkers = varargin{2};
        opt = struct('Mode', 'both', 'Rmax', Inf, 'Rmin', 0, 'List', '');
        for k = 3:2:numel(varargin), opt.(varargin{k}) = varargin{k + 1}; end
        for c = 1:numel(ctrls), runMargins(ctrls{c}, workerId, nWorkers, seeds, outDir, opt); end
    case 'taillist'
        thr = 20; if ~isempty(varargin), thr = varargin{1}; end
        for c = 1:numel(ctrls), writeTailList(ctrls{c}, thr, seeds, outDir); end
    case 'select'
        wj = false; if ~isempty(varargin), wj = logical(varargin{1}); end
        out = selectFinal(ctrls, seeds, outDir, wj);
    case 'front'
        out = buildFronts(ctrls, seeds, outDir);
    case 'status'
        for c = 1:numel(ctrls)
            C = candidates(ctrls{c}); S = ctrlSpec(ctrls{c});
            n = 0; files = dir(fullfile(outDir, sprintf('ParetoCommon_%s_w*_s99990-s99994.csv', ctrls{c})));
            for i = 1:numel(files), T = readtable(fullfile(files(i).folder, files(i).name)); n = n + height(T); end
            fprintf('[%s] %d candidates, %d evaluations stored (needs %d)%s\n', ctrls{c}, height(C), n, numel(seeds) * height(C), S.note);
        end
    otherwise
        error('compare_pareto_common:cmd', 'Unknown command %s', cmd);
end
end

% ---------------------------------------------------------------- specification of each controller
function S = ctrlSpec(name)
resRoot = result_dir('Map', 'Calib');   % Result/Controllers/Map/Calib_v2 (only used to find the Result root)
root = fileparts(fileparts(resRoot));  % Result/Controllers
S = struct('name', name, 'note', '');
switch name
    case 'Map'
        S.vn = {'K', 'g_min'};
        S.dir = fullfile(root, 'Map', 'Calib_v2', 'Grid2'); S.pattern = 'Map_CALIB_grid2_w*_s00000.csv'; S.seed0 = 0;
        S.pickFile = fullfile(S.dir, 'Map_CALIB_pick_s00000.csv');
        S.expected = 149;
        S.keep = @(P) P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0;
        S.eval = @(x, seed, csv) map2_eval(x, seed, csv);
    case 'PID'
        S.vn = {'Kp', 'Ki', 'Kd', 'Tf'};
        S.dir = fullfile(root, 'PID', 'Calib_v2'); S.pattern = 'PID_CALIB_grid_w*_s10000.csv'; S.seed0 = 10000;
        S.pickFile = fullfile(S.dir, 'PID_CALIB_pick_s10000.csv');
        S.expected = 168;
        S.keep = @(P) P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0;
        S.eval = @(x, seed, csv) pidlag_eval('PID', x, seed, csv);
    case 'MapPID'
        S.vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
        S.dir = fullfile(root, 'MapPID', 'Calib_v2', 'PlugPlay'); S.pattern = 'MapPID_CALIB_P1B1_w*_s30000.csv'; S.seed0 = 30000;
        S.pickFile = fullfile(S.dir, 'MapPID_CALIB_pick_s30000.csv');
        S.expected = 211;
        S.keep = @(P) P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0;
        S.eval = @(x, seed, csv) mappid_eval(x, seed, csv);
    otherwise
        error('compare_pareto_common:ctrl', 'Unknown controller %s', name);
end
end

function C = candidates(name)
%CANDIDATES Rule 0(a), 0(b): all points simulated through the controller's own selection gates at its search seed, duplicates removed.
S = ctrlSpec(name);
files = dir(fullfile(S.dir, S.pattern)); P = table();
for i = 1:numel(files), P = [P; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
P = P(P.seed == S.seed0, :);
[~, iu] = unique(round(table2array(P(:, S.vn)), 10, 'significant'), 'rows', 'stable'); P = P(sort(iu), :);
P = P(S.keep(P) & isfinite(P.R_pct) & isfinite(P.S_Nm), :);
C = P(:, S.vn);
C.R0 = P.R_pct; C.S0 = P.S_Nm; C.erel0 = P.erel_pct;
isF = true(height(C), 1);
for i = 1:height(C)
    dom = C.R0 <= C.R0(i) & C.S0 <= C.S0(i) & (C.R0 < C.R0(i) | C.S0 < C.S0(i)); dom(i) = false;
    isF(i) = ~any(dom);
end
C.phase = 2 - double(isF);          % phase 1: on the front at the search seed
C = sortrows(C, {'phase', 'R0'});   % deterministic order: phase 1 first, then by R0
end

function k = keyOf(X)
%KEYOF String key of design rows (9 significant digits: robust against the %.15g round trip of the csv writers).
k = strings(size(X, 1), 1);
for i = 1:size(X, 1), k(i) = join(string(arrayfun(@(v) sprintf('%.9g', v), X(i, :), 'UniformOutput', false)), '|'); end
end

% ---------------------------------------------------------------- run
function runPhase(name, phase, workerId, nWorkers, seeds, outDir)
%RUNPHASE Points of one phase, partitioned by their POSITION in the full phase list (stable when workers restart or nWorkers changes), complete points skipped.
%   Phase 2 runs only the points inside the noise band of the search-seed front (amendment A of 2026-10-22, see bandInfo) and needs phase 1 complete.
S = ctrlSpec(name); A = aggregate(name, seeds, outDir);
idx = find(A.phase == phase);
if phase == 2
    assert(all(A.complete(A.phase == 1)), 'compare_pareto_common:phase1', 'Phase 1 of %s is not complete: phase 2 needs its noise estimate.', name);
    idx = idx(A.in_set(idx));
end
pos = 1:numel(idx);
mine = idx(mod(pos - 1, nWorkers) == workerId - 1);
mine = mine(~A.complete(mine));
csv = fullfile(outDir, sprintf('ParetoCommon_%s_w%d_s99990-s99994.csv', name, workerId));
fprintf('[%s] phase %d worker %d/%d: %d points to do (of %d in the phase set)%s', name, phase, workerId, nWorkers, numel(mine), numel(idx), char(10));
for k = 1:numel(mine)
    x = table2array(A(mine(k), S.vn));
    for s = seeds
        o = S.eval(x, s, csv);
        if ~o.cached, fprintf('[%s] ph%d w%d %d/%d seed %d: R %.4g S %.4g erel %.4g%s', name, phase, workerId, k, numel(mine), s, o.R, o.S, o.erel, char(10)); end
    end
end
marker = fullfile(outDir, sprintf('ParetoCommon_%s_w%d_phase%d_done.txt', name, workerId, phase));
fid = fopen(marker, 'w'); fprintf(fid, '%s phase %d worker %d/%d done, %d points, %s%s', name, phase, workerId, nWorkers, numel(mine), char(datetime('now')), char(10)); fclose(fid);
fprintf('[%s] phase %d worker %d done%s', name, phase, workerId, char(10));
end

% ---------------------------------------------------------------- post-processing 0(d), 0(e)
function R = readEvals(name, seeds, outDir)
%READEVALS All stored evaluations of the common seeds of one controller (every worker file), first occurrence of (design, seed) kept.
S = ctrlSpec(name);
files = dir(fullfile(outDir, sprintf('ParetoCommon_%s_w*_s99990-s99994.csv', name))); R = table();
for i = 1:numel(files), R = [R; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
if isempty(R), return; end
R = R(ismember(R.seed, seeds), :);
k = keyOf(table2array(R(:, S.vn))) + "#" + string(R.seed);
[~, iu] = unique(k, 'stable'); R = R(iu, :);
end

function M = readMargins(name, outDir)
M = table();
files = dir(fullfile(outDir, sprintf('ParetoCommon_%s_margin_w*_s99990.csv', name)));
for i = 1:numel(files), M = [M; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
end

function A = aggregate(name, seeds, outDir)
%AGGREGATE One row per candidate: five-seed means, e_rel_max, gate flags (rule 0(c), 0(d)); margin columns left to the caller.
S = ctrlSpec(name); C = candidates(name); E = readEvals(name, seeds, outDir);
n = height(C);
A = C; A.Rtb = nan(n, 1); A.Stb = A.Rtb; A.TVtb = A.Rtb; A.Rsd = A.Rtb; A.Ssd = A.Rtb; A.erel_max = A.Rtb; A.PM = A.Rtb; A.GM = A.Rtb; A.nseeds = zeros(n, 1); A.valid = false(n, 1);
if ~isempty(E)
    kc = keyOf(table2array(C(:, S.vn))); ke = keyOf(table2array(E(:, S.vn)));
    for i = 1:n
        e = E(ke == kc(i), :);
        A.nseeds(i) = height(e);
        if height(e) == numel(seeds)
            A.Rtb(i) = mean(e.R_pct); A.Stb(i) = mean(e.S_Nm); A.TVtb(i) = mean(e.TV); A.Rsd(i) = std(e.R_pct); A.Ssd(i) = std(e.S_Nm); A.erel_max(i) = max(e.erel_pct); A.PM(i) = e.PM_deg(1); A.GM(i) = e.GM(1);   % linear margins do not depend on the seed
            A.valid(i) = all(isfinite(e.R_pct) & isfinite(e.S_Nm) & e.simulated == 1);
        end
    end
end
A.complete = A.nseeds == numel(seeds);
A.pass_erel = A.erel_max <= 10;                                        % 0(d): same definition for every controller
[A.in_set, A.sigR, A.sigS] = bandInfo(A);
A.alive_safe_all = A.complete & A.valid;                               % every evaluated point (sensitivity check only)
A.alive_full_all = A.alive_safe_all & A.pass_erel;
A.alive_safe = A.alive_safe_all & A.in_set;                            % 0(e)(i): linear gates (candidacy), noise-band set (amendment A) and, below, calib_margin
A.alive_full = A.alive_safe & A.pass_erel;                             % 0(e)(ii): plus e_rel
end

function [inSet, sigR, sigS] = bandInfo(A)
%BANDINFO Amendment A (2026-10-22), one mechanical rule for every controller, fixed before the phase-2 results.
%   sigR, sigS = median over the phase-1 points (front of the candidate set at the search seed) of std/mean of R and S over the five common seeds, per controller.
%   A phase-2 point is inside the set unless some phase-1 point f dominates it robustly: R0_f*(1+3*sigR) <= R0_p and S0_f*(1+3*sigS) <= S0_p.
%   Phase-1 points are always inside. Until every phase-1 point has its five seeds the noise is unknown: only phase 1 is inside.
n = height(A); inSet = A.phase == 1; sigR = nan(n, 1); sigS = nan(n, 1);
p1 = A.phase == 1;
if ~all(A.complete(p1)), return; end
sR = median(A.Rsd(p1) ./ A.Rtb(p1)); sS = median(A.Ssd(p1) ./ A.Stb(p1)); sigR(:) = sR; sigS(:) = sS;
F = A(p1, :);
for i = find(~p1)'
    robust = F.R0 * (1 + 3 * sR) <= A.R0(i) & F.S0 * (1 + 3 * sS) <= A.S0(i);
    inSet(i) = ~any(robust);
end
end

function F = paretoMask(R, S, alive)
F = false(numel(R), 1); ia = find(alive);
for q = 1:numel(ia)
    i = ia(q);
    dom = alive & R <= R(i) & S <= S(i) & (R < R(i) | S < S(i)); dom(i) = false;
    F(i) = ~any(dom);
end
end

function [front, marginFail, pending] = frontOf(A, alive)
%FRONTOF Rule 0(e): Pareto front of the live points; a front point that failed calib_margin is removed and the front recomputed until every front point has passed.
marginFail = false(height(A), 1);
while true
    F = paretoMask(A.Rtb, A.Stb, alive & ~marginFail);
    newFail = F & A.margin_done & ~A.margin_pass;
    if ~any(newFail), break; end
    marginFail = marginFail | newFail;
end
pending = F & ~A.margin_done;
front = F & ~pending;
end

function A = withMargins(A, name, S, outDir)
Mg = readMargins(name, outDir); n = height(A);
A.margin_done = false(n, 1); A.margin_pass = false(n, 1); A.ratio_gain = nan(n, 1); A.ratio_delay = nan(n, 1);
if isempty(Mg), return; end
kc = keyOf(table2array(A(:, S.vn))); km = keyOf(table2array(Mg(:, S.vn)));
for i = 1:n
    j = find(km == kc(i), 1, 'last');
    if ~isempty(j), A.margin_done(i) = true; A.margin_pass(i) = Mg.pass(j) == 1; A.ratio_gain(i) = Mg.ratio_gain(j); A.ratio_delay(i) = Mg.ratio_delay(j); end
end
end

function res = buildFronts(ctrls, seeds, outDir)
res = struct(); modes = {'safe', 'full'}; G = struct('safe', table(), 'full', table()); allPending = 0;
for c = 1:numel(ctrls)
    name = ctrls{c}; S = ctrlSpec(name);
    A = withMargins(aggregate(name, seeds, outDir), name, S, outDir); n = height(A);
    A.status_safe = repmat("dominated", n, 1); A.status_full = repmat("dominated", n, 1);
    r = struct('nCand', n, 'nIncomplete', nnz(~A.complete), 'nInvalid', nnz(A.complete & ~A.valid), 'nAliveSafe', nnz(A.alive_safe), 'nPassErel', nnz(A.alive_full));
    for m = 1:2
        mode = modes{m}; alive = A.(['alive_' mode]);
        [front, mfail, pending] = frontOf(A, alive);
        st = repmat("dominated", n, 1); st(~alive) = "not live";
        st(mfail) = "fails calib_margin"; st(pending) = "front (margin pending)"; st(front) = "front";
        A.(['status_' mode]) = st; A.(['front_' mode]) = front;
        r.(['nFront_' mode]) = nnz(front); r.(['nMarginFail_' mode]) = nnz(mfail); r.(['nPending_' mode]) = nnz(pending);
        allPending = allPending + nnz(pending);
        Fp = A(front, :);
        if ~isempty(Fp)
            d = strings(height(Fp), 1);
            for i = 1:height(Fp), d(i) = join(string(arrayfun(@(v) sprintf('%.9g', v), table2array(Fp(i, S.vn)), 'UniformOutput', false)), ';'); end
            g = Fp(:, {'Rtb', 'Stb', 'TVtb', 'Rsd', 'Ssd', 'erel_max', 'R0', 'S0', 'ratio_gain', 'ratio_delay'});
            g.ctrl = repmat(string(name), height(g), 1); g.design = d; g.vars = repmat(string(strjoin(S.vn, ';')), height(g), 1);
            G.(mode) = [G.(mode); sortrows(g, 'Rtb')];
        end
    end
    % sensitivity of the set rule: fronts over EVERY evaluated point versus the band set (pending margins count as front)
    for m = 1:2
        mode = modes{m};
        [fa, ~, pa] = frontOf(A, A.(['alive_' mode '_all'])); [fs, ~, ps] = frontOf(A, A.(['alive_' mode]));
        r.(['nFrontAllEval_' mode]) = nnz(fa | pa); r.(['nFrontDiff_' mode]) = nnz((fa | pa) ~= (fs | ps));
    end
    fprintf('[%s] band set: %d of %d candidates inside (sigR %.2g, sigS %.2g); front over all evaluated points differs in %d (safe) / %d (full) points%s', ...
        name, nnz(A.in_set), n, A.sigR(1), A.sigS(1), r.nFrontDiff_safe, r.nFrontDiff_full, char(10));
    writetable(A, fullfile(outDir, sprintf('ParetoCommon_%s_points_s99990-s99994.csv', name)));
    fprintf('[%s] candidates %d | incomplete %d | invalid %d | live %d | pass e_rel %d | safe: front %d, margin fails %d, pending %d | full: front %d, margin fails %d, pending %d\n', ...
        name, n, r.nIncomplete, r.nInvalid, r.nAliveSafe, r.nPassErel, r.nFront_safe, r.nMarginFail_safe, r.nPending_safe, r.nFront_full, r.nMarginFail_full, r.nPending_full);
    res.(name) = r;
end
for m = 1:2
    if ~isempty(G.(modes{m})), writetable(G.(modes{m}), fullfile(outDir, sprintf('ParetoCommon_fronts_%s.csv', modes{m}))); end
end
res.pending = allPending;
fprintf('front: %d margin results still pending\n', allPending);
end

% ---------------------------------------------------------------- margin 0(e)
function runMargins(name, workerId, nWorkers, seeds, outDir, opt)
S = ctrlSpec(name);
A = withMargins(aggregate(name, seeds, outDir), name, S, outDir);
need = false(height(A), 1);
modes = {'safe', 'full'}; if ~strcmp(opt.Mode, 'both'), modes = {opt.Mode}; end
for m = modes
    [~, ~, pending] = frontOf(A, A.(['alive_' m{1}]));
    need = need | pending;
end
if ~isempty(opt.List)
    % fixed list: the split is by position in the file (stable while results arrive); points that already have a margin result are dropped afterwards
    L = readtable(opt.List); kl = keyOf(table2array(L(:, S.vn))); kc = keyOf(table2array(A(:, S.vn)));
    lst = zeros(numel(kl), 1);
    for i = 1:numel(kl), j = find(kc == kl(i), 1); assert(~isempty(j), 'compare_pareto_common:list', 'List point %d is not a candidate of %s', i, name); lst(i) = j; end
    lst = lst(mod((1:numel(lst))' - 1, nWorkers) == workerId - 1);
    todo = lst(~A.margin_done(lst) & A.Rtb(lst) <= opt.Rmax & A.Rtb(lst) >= opt.Rmin);
else
    todo = find(need & A.Rtb <= opt.Rmax & A.Rtb >= opt.Rmin);
end
[~, ord] = sort(A.Rtb(todo)); todo = todo(ord);   % increasing R_tb: the cheap, low-R points first
if isempty(opt.List), mine = todo(mod((1:numel(todo)) - 1, nWorkers) == workerId - 1); else, mine = todo; end
fprintf('[%s] margin worker %d/%d: %d of %d pending front points\n', name, workerId, nWorkers, numel(mine), numel(todo));
csv = fullfile(outDir, sprintf('ParetoCommon_%s_margin_w%d_s99990.csv', name, workerId));
for k = 1:numel(mine)
    x = table2array(A(mine(k), S.vn));
    M = struct('pass', false, 'ratio_gain', Inf, 'ratio_delay', Inf);
    for attempt = 1:2                         % an Inf ratio can also be an execution error (calib_margin swallows exceptions): retry once
        M = marginOf(name, x, seeds(1));
        if isfinite(M.ratio_gain), break; end
    end
    row = array2table(x, 'VariableNames', S.vn); row.pass = double(M.pass); row.ratio_gain = M.ratio_gain; row.ratio_delay = M.ratio_delay;
    if exist(csv, 'file'), writetable(row, csv, 'WriteMode', 'append', 'WriteVariableNames', false); else, writetable(row, csv); end
    fprintf('[%s] margin %d/%d pass %d (gain %.3f, delay %.3f)\n', name, k, numel(mine), M.pass, M.ratio_gain, M.ratio_delay);
end
end

function M = marginOf(name, x, seed)
persistent loaded Cal Ts0
scriptDir = fileparts(mfilename('fullpath')); modelDir = fileparts(fileparts(scriptDir));
if isempty(loaded), loaded = struct(); end
switch name
    case 'Map'
        if isempty(Cal), Cal = calibrate_map_cached(); end
        if isempty(Ts0), Ts0 = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))).design.Ts0; end
        S = ctrlSpec('Map');
        % lead-lag synthesis is deterministic: re-derive z, p, z1, p1 from the stored evaluation (same as map2_eval)
        files = dir(fullfile(S.dir, S.pattern)); row = [];
        for i = 1:numel(files)
            T = readtable(fullfile(files(i).folder, files(i).name));
            hit = T.seed == 0 & abs(T.K - x(1)) <= 1e-9 * max(1, abs(x(1))) & abs(T.g_min - x(2)) <= 1e-9 * max(1, abs(x(2)));
            if any(hit), row = T(find(hit, 1), :); break; end
        end
        assert(~isempty(row), 'compare_pareto_common:noRow', 'Map pair not found in grid csv');
        z1 = row.z1; p1 = row.p1;                                   % Inf when the lag is off, as in map2_eval
        d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', row.z, 'p', row.p), 'lag', struct('z1', z1, 'p1', p1));
        if ~isfield(loaded, 'Map')
            assignin('base', 'Map_calibration_override', Cal);
            evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
            loaded.Map = true;
        end
        M = calib_margin('Model_Map', seed, map_variables(Cal, d));
    case 'PID'
        if ~isfield(loaded, 'PID')
            evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'PID', 'load_pid.m'), '\', '/')));
            loaded.PID = true;
        end
        d = struct('Ts_ctrl', 1e-3, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
        M = calib_margin('Model_PID', seed, pidlag_variables('PID', d));
    case 'MapPID'
        if isempty(Cal), Cal = calibrate_map_cached(); end
        if isempty(Ts0), Ts0 = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))).design.Ts0; end
        if ~isfield(loaded, 'MapPID')
            evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
            loaded.MapPID = true;
        end
        d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
            'lag', struct('z1', x(4), 'p1', x(4) * x(5)), 'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
        M = calib_margin('Model_MapPID', seed, mappid_variables(Cal, d));
end
Simulink.sdi.clear;
end

% ---------------------------------------------------------------- checks of 2.3
function checkAll(ctrls)
ok = true;
for c = 1:numel(ctrls)
    name = ctrls{c}; S = ctrlSpec(name); C = candidates(name);
    fprintf('[%s] (i) candidates: %d (expected %d)\n', name, height(C), S.expected);
    ok = ok & height(C) == S.expected;
    % (ii) the chosen point rerun at its search seed WITHOUT cache must reproduce the grid csv row
    Pk = readtable(S.pickFile); r = Pk(Pk.chosen == 1, :);
    x = table2array(r(:, S.vn));
    o = S.eval(x, S.seed0, '');
    relR = abs(o.R - r.R_pct) / abs(r.R_pct); relS = abs(o.S - r.S_Nm) / abs(r.S_Nm);
    fprintf('[%s] (ii) chosen point rerun at seed %d: R %.10g vs %.10g (rel %.2e), S %.10g vs %.10g (rel %.2e)\n', name, S.seed0, o.R, r.R_pct, relR, o.S, r.S_Nm, relS);
    ok = ok & relR < 1e-6 & relS < 1e-6;
    if strcmp(name, 'MapPID')
        scriptDir = fileparts(mfilename('fullpath')); modelDir = fileparts(fileparts(scriptDir));
        [~, xMap] = mappid_plug_u0(modelDir);                        % asserts the round trip of the locked Map
        X = table2array(C(:, S.vn(1:5)));
        dev = max(abs(X - xMap) ./ max(abs(xMap), eps), [], 'all');
        fprintf('[MapPID] (iii) Map block of every candidate equals map.json design: max relative deviation %.2e\n', dev);
        ok = ok & dev < 1e-6;
    end
end
if ok, fprintf('[compare_pareto_common] CHECK PASS\n'); else, fprintf('[compare_pareto_common] CHECK FAIL\n'); end
end

% ---------------------------------------------------------------- tail list and final selection (KeHoachMatlab.txt 10.1, 10.2)
function writeTailList(name, thr, seeds, outDir)
%WRITETAILLIST Safe-front points that still wait for calib_margin and have R_tb above thr, in increasing R_tb: the fixed list both machines split.
S = ctrlSpec(name); A = withMargins(aggregate(name, seeds, outDir), name, S, outDir);
[~, ~, pending] = frontOf(A, A.alive_safe);
T = A(pending & A.Rtb > thr, :); T = sortrows(T, 'Rtb');
L = T(:, [S.vn, {'Rtb', 'Stb'}]);
f = fullfile(outDir, sprintf('ParetoCommon_%s_tail_list.csv', name)); writetable(L, f);
fprintf('[%s] tail list: %d points with R_tb > %g (pending safe-front margins) written to %s\n', name, height(L), thr, f);
end

function k = pickJ(A, mask)
%PICKJ Rule 10.1.3: smallest J = R_tb x S_tb on the mask; points within 3 % of it tie, the largest linear PM wins.
idx = find(mask); J = A.Rtb .* A.Stb;
if isempty(idx), k = 0; return; end
tie = idx(J(idx) <= 1.03 * min(J(idx)));
[~, q] = max(A.PM(tie)); k = tie(q);
end

function res = selectFinal(ctrls, seeds, outDir, writeJson)
scriptDir = fileparts(mfilename('fullpath')); modelDir = fileparts(fileparts(scriptDir));
Tsel = table(); Trep = table(); res = struct();
for c = 1:numel(ctrls)
    name = ctrls{c}; S = ctrlSpec(name);
    A = withMargins(aggregate(name, seeds, outDir), name, S, outDir); n = height(A);
    [frS, mfS, pS] = frontOf(A, A.alive_safe); [frF, mfF, pF] = frontOf(A, A.alive_full);
    assert(~any(pS) && ~any(pF), 'compare_pareto_common:pending', '[%s] %d safe and %d full front points still wait for calib_margin', name, nnz(pS), nnz(pF));
    if any(frF), face = 'full'; mask = frF; other = frS; note = ''; else, face = 'safe'; mask = frS; other = frF; note = 'safe, fails e_rel'; end
    k = pickJ(A, mask); assert(k > 0, 'compare_pareto_common:empty', '[%s] both fronts are empty', name);
    J = A.Rtb .* A.Stb;
    dstr = @(i) join(string(arrayfun(@(v) sprintf('%.9g', v), table2array(A(i, S.vn)), 'UniformOutput', false)), ';');
    Pk = readtable(S.pickFile); xo = table2array(Pk(Pk.chosen == 1, S.vn)); ko = find(keyOf(table2array(A(:, S.vn))) == keyOf(xo), 1);
    kOther = pickJ(A, other);
    ir = find(mask); kRule = ir(pick_by_tolerance(A.Rtb(ir), A.Stb(ir), true(numel(ir), 1), 0.05)); kRule = kRule(1);
    kinds = {'chosen', 'min_J_other_face', 'old_temp_point', 'old_rule_5pct'}; ks = [k, kOther, ko, kRule];
    for q = 1:4
        i = ks(q); if isempty(i) || i == 0, continue; end
        r = table(string(name), string(kinds{q}), string(face), A.Rtb(i), A.Stb(i), J(i), A.PM(i), frS(i), frF(i), A.in_set(i), A.pass_erel(i), dstr(i), ...
            'VariableNames', {'ctrl', 'kind', 'face_used', 'Rtb', 'Stb', 'J', 'PM_deg', 'on_safe_front', 'on_full_front', 'in_set', 'pass_erel', 'design'});
        Trep = [Trep; r]; %#ok<AGROW>
    end
    s = table(string(name), string(face), string(note), n, nnz(A.in_set), nnz(A.alive_full), nnz(frS), nnz(frF), nnz(mfS), nnz(mfF), A.Rtb(k), A.Stb(k), J(k), A.Rsd(k), A.Ssd(k), A.erel_max(k), A.PM(k), A.GM(k), ...
        A.ratio_gain(k), A.ratio_delay(k), dstr(k), 'VariableNames', {'ctrl', 'face_used', 'label', 'n_cand', 'n_in_set', 'n_pass_erel', 'n_front_safe', 'n_front_full', ...
        'n_margin_fail_safe', 'n_margin_fail_full', 'Rtb', 'Stb', 'J', 'Rsd', 'Ssd', 'erel_max', 'PM_deg', 'GM', 'ratio_gain', 'ratio_delay', 'design'});
    Tsel = [Tsel; s]; %#ok<AGROW>
    fprintf('[%s] final: face %s %s | R_tb %.5g S_tb %.5g J %.5g PM %.2f | design %s\n', name, face, note, A.Rtb(k), A.Stb(k), J(k), A.PM(k), dstr(k));
    fprintf('[%s]   old temp point: R_tb %.5g S_tb %.5g J %.5g, on safe front %d, on full front %d | other face min J %.5g | old 5%% rule on this face: R_tb %.5g S_tb %.5g\n', ...
        name, A.Rtb(ko), A.Stb(ko), J(ko), frS(ko), frF(ko), iff(kOther > 0, J(max(kOther, 1))), A.Rtb(kRule), A.Stb(kRule));
    res.(name) = struct('x', table2array(A(k, S.vn)), 'row', A(k, :), 'face', face, 'note', note);
end
writetable(Tsel, fullfile(outDir, 'ParetoCommon_select.csv')); writetable(Trep, fullfile(outDir, 'ParetoCommon_select_report.csv'));
if writeJson
    bdir = 'C:/Users/Admin/Desktop/Adaptive-EPS_backup_2026-10-23_json_truoc_pareto';
    if ~exist(bdir, 'dir'), mkdir(bdir); end
    for c = 1:numel(ctrls)
        jf = fullfile(modelDir, 'data', [lower(ctrls{c}) '.json']);
        if ~exist(fullfile(bdir, [lower(ctrls{c}) '.json']), 'file'), copyfile(jf, bdir); end
    end
    for c = 1:numel(ctrls), writeDesignJson(ctrls{c}, res.(ctrls{c}), modelDir); end
end
end

function d = designOf(name, x, modelDir)
%DESIGNOF Design struct built by the function each controller already uses for its own selection.
switch name
    case 'Map',    sp = map2_grid_spec(); d = sp.toDesign(x);
    case 'PID',    sp = pid_grid_spec(); d = sp.toDesign(x);
    case 'MapPID'
        Ts0 = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))).design.Ts0;
        d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
            'lag', struct('z1', x(4), 'p1', x(4) * x(5)), 'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end
end

function writeDesignJson(name, r, modelDir)
jsonPath = fullfile(modelDir, 'data', [lower(name) '.json']);
q = designOf(name, r.x, modelDir); a = r.row;
if ~strcmp(name, 'Map'), q = rmfield(q, 'Ts_ctrl'); end          % Map's load_map needs Ts_ctrl in the design
if strcmp(name, 'PID'), q.Kaw = q.Ki / q.Kp; end
if strcmp(name, 'MapPID'), q.Kaw = q.Ki / (q.Kp + q.Kmax); end
q.rule = 'final design on the common-seed (99990-99994) margin-checked front: J = R_tb x S_tb minimum, 3 % tie by maximum PM; KeHoachMatlab.txt 10.1; 2026-10-23';
if ~isempty(r.note), q.x_design_note = r.note; end
q.CALIB_common_Rtb = a.Rtb; q.CALIB_common_Stb = a.Stb; q.CALIB_common_J = a.Rtb * a.Stb; q.CALIB_common_erel_max = a.erel_max; q.CALIB_common_face = r.face;
q.CALIB_R_pct = a.R0; q.CALIB_S_Nm = a.S0; q.CALIB_J = a.R0 * a.S0; q.CALIB_erel_pct = a.erel0;   % scores at the controller's own search seed
q.PM_deg = a.PM; q.GM = a.GM; q.margin_ratio_gain = a.ratio_gain; q.margin_ratio_delay = a.ratio_delay;
q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
J = jsondecode(fileread(jsonPath));
if isfield(J, 'design') && ~isfield(J, 'design_pre_pareto'), J.design_pre_pareto = J.design; end
J.design = q;
fid = fopen(jsonPath, 'w'); assert(fid >= 0, 'Cannot write %s', jsonPath);
fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
fprintf('[%s] design written to %s\n', name, jsonPath);
end

function v = iff(c, x)
%IFF Value x when c, NaN otherwise (console report of an empty front).
if c, v = x; else, v = NaN; end
end
