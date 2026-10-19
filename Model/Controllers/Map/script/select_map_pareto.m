function sel = select_map_pareto(writeJson)
%SELECT_MAP_PARETO Select and report the Map design from the grid Pareto front.
if nargin < 1, writeJson = false; end
sel = select_pareto(map_grid_spec(), writeJson);
end
