function spec = pid_grid_spec()
%PID_GRID_SPEC Configuration of the deterministic PID grid search.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
spec = struct();
spec.name = 'PID';
spec.n = 4;
spec.vn = {'Kp','Ki','Kd','Tf'};
spec.u2x = @pid_u2x;
spec.x2u = @pid_x2u;
spec.evalFcn = @(x, seed, csvFile) pidlag_eval('PID', x, seed, csvFile);
spec.seed = 10000;
spec.seed0 = 10000;
spec.seeds = 10001:10005;
spec.outDir = result_dir('PID', 'Calib');
spec.tag = 'grid';
spec.free = 1:4;
spec.u0 = 0.5 * ones(1, 4);
spec.hStart = 1/6;
spec.coarse = true;
spec.PMfin = 30;
spec.GMfin = 2;
spec.erelMax = 10;
spec.toDesign = @(x) struct('Ts_ctrl', 1e-3, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
spec.marginFcn = @(x) pidMargin(x);
spec.jsonPath = fullfile(modelDir, 'data', 'pid.json');
end

function M = pidMargin(x)
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
loadFile = strrep(fullfile(modelDir, 'Controllers', 'PID', 'load_pid.m'), '\', '/');
evalin('base', sprintf('run(''%s'');', loadFile));
d = struct('Ts_ctrl', 1e-3, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
M = calib_margin('Model_PID', 10001, pidlag_variables('PID', d));
Simulink.sdi.clear;
end
