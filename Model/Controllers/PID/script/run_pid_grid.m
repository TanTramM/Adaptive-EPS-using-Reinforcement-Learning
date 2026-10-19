function summary = run_pid_grid(workerId, nWorkers)
%RUN_PID_GRID Run one resumable worker of the PID coarse-to-fine grid.
if nargin < 1, workerId = 1; end
if nargin < 2, nWorkers = 3; end
summary = grid_search(pid_grid_spec(), workerId, nWorkers);
end
