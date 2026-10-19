function spec = map_grid_spec()
%MAP_GRID_SPEC Configuration of the deterministic Map grid search.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Ts0 = J.design.Ts0;
Cal = calibrate_map_cached();
spec = struct();
spec.name = 'Map';
spec.n = 5;
spec.vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1'};
spec.u2x = @map_u2x;
spec.x2u = @map_x2u;
spec.evalFcn = @map_opt_eval;
spec.seed = 0;
spec.seed0 = 0;
spec.seeds = 1:5;
spec.outDir = result_dir('Map', 'Calib');
spec.tag = 'grid';
spec.free = 1:5;
spec.u0 = 0.5 * ones(1, 5);
spec.hStart = 1 / 6;
spec.coarse = true;
spec.PMfin = 30;
spec.GMfin = 2;
spec.erelMax = 10;
spec.toDesign = @(x) mapDesign(x, Ts0);
spec.marginFcn = @(x) mapMargin(x, Cal, Ts0);
spec.jsonPath = fullfile(modelDir, 'data', 'map.json');
end

function d = mapDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), ...
    'lead', struct('z', x(2), 'p', x(2) * x(3)), ...
    'lag', struct('z1', x(4), 'p1', x(4) * x(5)));
end

function M = mapMargin(x, Cal, Ts0)
d = mapDesign(x, Ts0);
M = calib_margin('Model_Map', 1, map_variables(Cal, d));
Simulink.sdi.clear;
end
