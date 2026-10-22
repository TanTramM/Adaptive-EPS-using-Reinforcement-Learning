function out = compare_pareto_common(cmd, ctrls, varargin)
%COMPARE_PARETO_COMMON Re-evaluate the candidate sets of Map, PID and MapPID on the common seeds 99990-99994 and compare their Pareto fronts.
%   Plan: Documents/Shared/KeHoach_SoMatPareto.txt (rules 0(a)-0(g), written before any run; do not change them after seeing results).
%
%   compare_pareto_common('candidates', ctrls)                     build and print the candidate sets (0(a), 0(b))
%   compare_pareto_common('check', ctrls)                          checks of 2.3: counts, chosen point reproduced at its search seed, MapPID locked Map block
%   compare_pareto_common('run', ctrls, workerId, nWorkers[, phases])   phase 1 = candidates on the search-seed front, phase 2 = the rest (default [1 2]);
%                                                                  each worker takes the points with mod(k-1, nWorkers) == workerId-1 inside a phase
%   compare_pareto_common('margin', ctrls, workerId, nWorkers)     calib_margin (seed 99990) for the current front points that have no margin result yet (0(e))
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
        for c = 1:numel(ctrls), runMargins(ctrls{c}, workerId, nWorkers, seeds, outDir); end
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
S = ctrlSpec(name); C = candidates(name);
idx = find(C.phase == phase);
mine = idx(mod((1:numel(idx)) - 1, nWorkers) == workerId - 1);
csv = fullfile(outDir, sprintf('ParetoCommon_%s_w%d_s99990-s99994.csv', name, workerId));
fprintf('[%s] phase %d worker %d/%d: %d of %d points\n', name, phase, workerId, nWorkers, numel(mine), numel(idx));
for k = 1:numel(mine)
    x = table2array(C(mine(k), S.vn));
    for s = seeds
        o = S.eval(x, s, csv);
        if ~o.cached, fprintf('[%s] ph%d w%d %d/%d seed %d: R %.4g S %.4g erel %.4g\n', name, phase, workerId, k, numel(mine), s, o.R, o.S, o.erel); end
    end
end
marker = fullfile(outDir, sprintf('ParetoCommon_%s_w%d_phase%d_done.txt', name, workerId, phase));
fid = fopen(marker, 'w'); fprintf(fid, '%s phase %d worker %d/%d done, %d points, %s\n', name, phase, workerId, nWorkers, numel(mine), char(datetime('now'))); fclose(fid);
fprintf('[%s] phase %d worker %d done\n', name, phase, workerId);
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
A = C; A.Rtb = nan(n, 1); A.Stb = A.Rtb; A.TVtb = A.Rtb; A.Rsd = A.Rtb; A.Ssd = A.Rtb; A.erel_max = A.Rtb; A.nseeds = zeros(n, 1); A.valid = false(n, 1);
if ~isempty(E)
    kc = keyOf(table2array(C(:, S.vn))); ke = keyOf(table2array(E(:, S.vn)));
    for i = 1:n
        e = E(ke == kc(i), :);
        A.nseeds(i) = height(e);
        if height(e) == numel(seeds)
            A.Rtb(i) = mean(e.R_pct); A.Stb(i) = mean(e.S_Nm); A.TVtb(i) = mean(e.TV); A.Rsd(i) = std(e.R_pct); A.Ssd(i) = std(e.S_Nm); A.erel_max(i) = max(e.erel_pct);
            A.valid(i) = all(isfinite(e.R_pct) & isfinite(e.S_Nm) & e.simulated == 1);
        end
    end
end
A.complete = A.nseeds == numel(seeds);
A.pass_erel = A.erel_max <= 10;                                        % 0(d): same definition for every controller
A.alive_safe = A.complete & A.valid;                                   % 0(e)(i): linear gates (candidacy) and, below, calib_margin
A.alive_full = A.alive_safe & A.pass_erel;                             % 0(e)(ii): plus e_rel
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
function runMargins(name, workerId, nWorkers, seeds, outDir)
S = ctrlSpec(name);
A = withMargins(aggregate(name, seeds, outDir), name, S, outDir);
need = false(height(A), 1);
for m = {'safe', 'full'}
    [~, ~, pending] = frontOf(A, A.(['alive_' m{1}]));
    need = need | pending;
end
todo = find(need);
mine = todo(mod((1:numel(todo)) - 1, nWorkers) == workerId - 1);
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
