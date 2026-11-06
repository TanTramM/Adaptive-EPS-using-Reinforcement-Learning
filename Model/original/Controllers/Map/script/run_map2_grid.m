function summary = run_map2_grid(workerId, nWorkers, centreRule)
%RUN_MAP2_GRID Run one resumable worker of the two-variable Map grid (K, g_min), PhuongPhap_TimThamSo.txt 14.8.
%   Case R3 (no pair passes the safety gates): the search stops, prints MAP2_GRID_R3_STOP, and the pipeline reports it (no gate is relaxed).
if nargin < 1, workerId = 1; end
if nargin < 2, nWorkers = 3; end
if nargin < 3, centreRule = 'R1'; end
summary = [];
try
    summary = grid_search(map2_grid_spec(centreRule), workerId, nWorkers);
catch ME
    if strcmp(ME.identifier, 'map2:R3')
        fprintf('MAP2_GRID_R3_STOP worker %d: %s\n', workerId, ME.message);
    else
        rethrow(ME);
    end
end
end
