function sel = select_pid_pareto(writeJson)
%SELECT_PID_PARETO Select and report the PID design from the grid Pareto front.
if nargin < 1, writeJson = false; end
sel = select_pareto(pid_grid_spec(), writeJson);
end
