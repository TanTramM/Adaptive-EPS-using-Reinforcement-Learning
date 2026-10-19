function summary = run_map_grid(workerId, nWorkers)
%RUN_MAP_GRID Run one resumable worker of the Map coarse-to-fine grid.
if nargin < 1, workerId = 1; end
if nargin < 2, nWorkers = 3; end
summary = grid_search(map_grid_spec(), workerId, nWorkers);
end
