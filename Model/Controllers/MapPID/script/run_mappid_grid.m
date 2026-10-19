function summary = run_mappid_grid(startName, workerId, nWorkers)
%RUN_MAPPID_GRID Alternating block-grid search for one MapPID starting point.
%   run_mappid_grid('S1', workerId, 3) scans A,B,A,B,A,B.
%   run_mappid_grid('S2', workerId, 3) scans B,A,B,A,B,A.
%   It stops after two consecutive scans that retain the incoming centre, or
%   after six block scans. grid_search supplies the within-scan barriers.
if nargin < 2, workerId = 1; end
if nargin < 3, nWorkers = 1; end
assert(workerId >= 1 && workerId <= nWorkers && workerId == floor(workerId));
startName = upper(char(startName));

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
assert(exist('grid_search', 'file') == 2, ...
    'Model/common/grid_search.m is missing; Section 13.1 must finish first.');

outDir = result_dir('MapPID', 'Calib');
u0 = mappid_grid_start(startName, modelDir);
if strcmp(startName, 'S1')
    blocks = {'A', 'B', 'A', 'B', 'A', 'B'};
else
    blocks = {'B', 'A', 'B', 'A', 'B', 'A'};
end

unchanged = 0;
rows = cell(0, 1);
for stage = 1:6
    block = blocks{stage};
    tag = sprintf('%s%s%d', startName, block, ceil(stage / 2));
    if block == 'A', free = 1:5; else, free = 6:9; end
    coarse = stage <= 2;
    if coarse, hStart = 1 / 6; else, hStart = 1 / 12; end
    spec = struct('name', 'MapPID', 'n', 9, 'u2x', @mappid_u2x, 'x2u', @mappid_x2u, ...
        'evalFcn', @mappid_eval, 'seed', 30000, 'outDir', outDir, ...
        'tag', tag, 'free', free, 'u0', u0, 'hStart', hStart, 'coarse', coarse);
    grid_search(spec, workerId, nWorkers);

    [uNext, xNext, rowBest] = mappid_grid_best(outDir, tag, 30000);
    rows{end + 1, 1} = rowBest; %#ok<AGROW>
    same = max(abs(uNext - u0)) <= 1e-10;
    if same, unchanged = unchanged + 1; else, unchanged = 0; end
    u0 = uNext;
    if workerId == 1
        fprintf('%s complete: best J %.6g, centre x = [%s], unchanged streak %d\n', ...
            tag, rowBest.J, sprintf(' %.6g', xNext), unchanged);
    end
    if unchanged >= 2, break; end
end

summary = struct('start', startName, 'nScans', numel(rows), 'u', u0, ...
    'x', mappid_u2x(u0), 'lastRow', rows{end});
if workerId == 1
    save(fullfile(outDir, sprintf('MapPID_CALIB_%s_summary.mat', startName)), 'summary');
end
end
