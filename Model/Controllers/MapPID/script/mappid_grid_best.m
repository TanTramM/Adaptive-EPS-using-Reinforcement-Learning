function [uBest, xBest, rowBest] = mappid_grid_best(outDir, tag, seed)
%MAPPID_GRID_BEST Return the centre passed from one MapPID block scan to the next.
%   Feasible rows are ranked by J. If no row is feasible, the row with the
%   smallest sum of positive c1-c4 is returned, as required by Section 13.1.C.
pat = sprintf('MapPID_CALIB_%s_w*_s%05d.csv', tag, seed);
files = dir(fullfile(outDir, pat));
assert(~isempty(files), 'No grid files found for tag %s in %s.', tag, outDir);

T = table();
for k = 1:numel(files)
    q = readtable(fullfile(files(k).folder, files(k).name));
    if isempty(T), T = q; else, T = [T; q]; end %#ok<AGROW>
end
assert(~isempty(T), 'Grid files for tag %s contain no evaluations.', tag);

vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
cn = {'c1', 'c2', 'c3', 'c4'};
X = T{:, vn};
C = T{:, cn};
feasible = all(isfinite(C), 2) & all(C <= 1e-10, 2) & isfinite(T.J);
if any(feasible)
    ids = find(feasible);
    [~, j] = min(T.J(ids));
    idx = ids(j);
else
    violation = sum(max(C, 0), 2);
    violation(~all(isfinite(C), 2)) = Inf;
    [vmin, idx] = min(violation);
    assert(isfinite(vmin), 'Tag %s has no row with finite constraints.', tag);
end

xBest = X(idx, :);
uBest = mappid_x2u(xBest);
rowBest = T(idx, :);
end
