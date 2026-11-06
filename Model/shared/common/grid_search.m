function summary = grid_search(spec, workerId, nWorkers)
%GRID_SEARCH Deterministic coarse-to-fine grid search shared by controllers.
%   summary = grid_search(spec, workerId, nWorkers)
%   Required spec fields: name, n, u2x, evalFcn, seed, outDir, tag, free,
%   u0, hStart, coarse. Each worker writes its own CSV and synchronizes with
%   the other workers after every grid layer. Existing rows are reused.

validateSpec(spec, workerId, nWorkers);
if ~exist(spec.outDir, 'dir'), mkdir(spec.outDir); end
csvFile = fullfile(spec.outDir, sprintf('%s_CALIB_%s_w%d_s%05d.csv', ...
    spec.name, spec.tag, workerId, spec.seed));
free = spec.free(:)';
u0 = min(max(spec.u0(:)', 0), 1);
maxFine = 6;
h = spec.hStart;
fineCount = 0;
seenX = zeros(0, spec.n);       % completed layers only; prevents a cross-worker race at layer boundaries
% Optional spec fields (defaults reproduce the original PID behaviour): coarseLevels = u levels of the coarse grid,
% centerFcn = @(T, spec) -> x of the fine-grid centre (T = rows of the finished layers).
coarseLevels = [0 1/3 2/3 1];
if isfield(spec, 'coarseLevels'), coarseLevels = spec.coarseLevels(:)'; end

center = u0;
if spec.coarse
    U = makeGrid(u0, free, coarseLevels);
    runLayer(U, 'coarse', NaN);
    center = pickCenter(rowsForPoints(readRunRows(), seenX));
end
while fineCount < maxFine && h >= 0.02
    oldCenter = center;
    U = makeLocalGrid(oldCenter, free, h);
    fineCount = fineCount + 1;
    runLayer(U, sprintf('fine%d', fineCount), h);
    center = pickCenter(rowsForPoints(readRunRows(), seenX));
    if sameU(center, oldCenter), h = h / 2; end
end

T = readRunRows();
[nSim, nFeas, bestJ, bestX] = stats(T);
summary = struct('nEvaluated', height(T), 'nSimulated', nSim, ...
    'nFeasible', nFeas, 'bestJ', bestJ, 'bestX', bestX, ...
    'nFine', fineCount, 'hFinal', h, 'centerU', center);
fprintf('[%s] DONE worker %d/%d: evaluated %d, simulated %d, feasible %d, best J %.6g, fine layers %d, final h %.6g\n', ...
    spec.tag, workerId, nWorkers, height(T), nSim, nFeas, bestJ, fineCount, h);

    function runLayer(U, kind, hNow)
        U = unique(round(U, 12), 'rows', 'stable');
        X = zeros(size(U, 1), spec.n);
        for ii = 1:size(U, 1), X(ii, :) = spec.u2x(U(ii, :)); end
        X = unique(round(X, 12, 'significant'), 'rows', 'stable');
        seenX = unique([seenX; X], 'rows', 'stable');
        Tnow = readRunRows();
        todo = ~rowsPresent(X, Tnow);
        idx = find(todo);
        mine = idx(mod(idx - 1, nWorkers) + 1 == workerId);
        for jj = mine(:)'
            spec.evalFcn(X(jj, :), spec.seed, csvFile);
        end
        while true
            Tall = readRunRows();
            if all(rowsPresent(X, Tall)), break; end
            pause(30);
        end
        [ls, lf, lj, lx] = statsForPoints(readRunRows(), X);
        if isnan(hNow), hs = '-'; else, hs = sprintf('%.6g', hNow); end
        fprintf('[%s] %s h=%s points=%d simulated=%d feasible=%d bestJ=%.6g center=%s\n', ...
            spec.tag, kind, hs, size(X, 1), ls, lf, lj, mat2str(lx, 5));
    end

    function T = readRunRows()
        files = dir(fullfile(spec.outDir, sprintf('%s_CALIB_%s_w*_s%05d.csv', ...
            spec.name, spec.tag, spec.seed)));
        T = table();
        for kk = 1:numel(files)
            try
                Q = readtable(fullfile(files(kk).folder, files(kk).name));
                if width(Q) >= spec.n, T = [T; Q]; end %#ok<AGROW>
            catch
                % Another worker may be appending. Retry on the next poll.
            end
        end
        if ~isempty(T)
            [~, ia] = unique(round(table2array(T(:, 1:spec.n)), 10, 'significant'), 'rows', 'stable');
            T = T(sort(ia), :);
        end
    end

    function c = pickCenter(T)
        if isfield(spec, 'centerFcn') && ~isempty(spec.centerFcn)
            c = min(max(spec.x2u(spec.centerFcn(T, spec)), 0), 1);
        else
            c = bestCenter(T);
        end
    end

    function c = bestCenter(T)
        assert(~isempty(T), 'grid_search:noRows', 'No evaluated point is available to define a fine-grid centre.');
        feas = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & isfinite(T.J);
        if any(feas)
            Q = T(feas, :); [~, ib] = min(Q.J);
        else
            viol = max(T.c1, 0) + max(T.c2, 0) + max(T.c3, 0) + max(T.c4, 0);
            viol(~isfinite(viol)) = Inf; [~, ib] = min(viol); Q = T;
        end
        c = min(max(spec.x2u(table2array(Q(ib, 1:spec.n))), 0), 1);
    end
end

function validateSpec(s, workerId, nWorkers)
req = {'name','n','u2x','x2u','evalFcn','seed','outDir','tag','free','u0','hStart','coarse'};
for i = 1:numel(req), assert(isfield(s, req{i}), 'grid_search:spec', 'Missing spec.%s', req{i}); end
assert(workerId >= 1 && workerId <= nWorkers && fix(workerId) == workerId, 'Invalid workerId.');
assert(numel(s.u0) == s.n && all(ismember(s.free, 1:s.n)), 'Invalid u0 or free-variable list.');
end

function U = makeGrid(u0, free, values)
args = repmat({values}, 1, numel(free)); grids = cell(size(args));
[grids{:}] = ndgrid(args{:});
U = repmat(u0, numel(grids{1}), 1);
for i = 1:numel(free), U(:, free(i)) = grids{i}(:); end
end

function U = makeLocalGrid(center, free, h)
values = cell(1, numel(free));
for i = 1:numel(free), values{i} = unique(min(max(center(free(i)) + [-h 0 h], 0), 1), 'stable'); end
grids = cell(size(values)); [grids{:}] = ndgrid(values{:});
U = repmat(center, numel(grids{1}), 1);
for i = 1:numel(free), U(:, free(i)) = grids{i}(:); end
end

function yes = rowsPresent(X, T)
yes = false(size(X, 1), 1); if isempty(T), return; end
Y = table2array(T(:, 1:size(X, 2)));
for i = 1:size(X, 1)
    tol = 1e-9 .* max(1, abs(X(i, :)));
    yes(i) = any(all(abs(Y - X(i, :)) <= tol, 2));
end
end

function tf = sameU(a, b)
tf = max(abs(a - b)) <= 1e-12;
end

function [nSim, nFeas, bestJ, bestX] = stats(T)
nSim = nnz(T.simulated == 1);
feas = T.simulated == 1 & T.c1 <= 0 & T.c2 <= 0 & T.c3 <= 0 & T.c4 <= 0 & isfinite(T.J);
nFeas = nnz(feas); bestJ = Inf; bestX = nan(1, 0);
if nFeas > 0, Q = T(feas, :); [bestJ, i] = min(Q.J); bestX = table2array(Q(i, 1:find(strcmp(Q.Properties.VariableNames, 'seed')) - 1)); end
end

function [nSim, nFeas, bestJ, bestX] = statsForPoints(T, X)
[nSim, nFeas, bestJ, bestX] = stats(rowsForPoints(T, X));
end

function Q = rowsForPoints(T, X)
mask = false(height(T), 1);
if isempty(T) || isempty(X), Q = T(mask, :); return; end
Y = table2array(T(:, 1:size(X, 2)));
for i = 1:size(X, 1)
    tol = 1e-9 .* max(1, abs(X(i, :)));
    mask = mask | all(abs(Y - X(i, :)) <= tol, 2);
end
Q = T(mask, :);
end
