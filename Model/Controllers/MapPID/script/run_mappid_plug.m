function summary = run_mappid_plug(workerId, nWorkers)
%RUN_MAPPID_PLUG One resumable worker of the plug-in grid (PhuongPhap_TimThamSo.txt 15).
%   The Map block (K, z, p/z, z1, p1/z1) is locked to the design of data/map.json; only the PID block
%   standard-form PID parameters (K, Ti, Td, N) are searched on the agreed four-dimensional coarse-to-fine grid. CSV columns remain (Kp, Ki, Kd, Tf).
%   Results: Result/Controllers/MapPID/Calib_v2/PlugPlay/MapPID_CALIB_P1B1_w<id>_s30000.csv
if nargin < 1, workerId = 1; end
if nargin < 2, nWorkers = 4; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = fullfile(result_dir('MapPID', 'Calib'), 'PlugPlay');
u0 = mappid_plug_u0(modelDir);
spec = struct('name', 'MapPID', 'n', 9, 'u2x', @mappid_u2x, 'x2u', @mappid_x2u, ...
    'evalFcn', @mappid_eval, 'seed', 30000, 'outDir', outDir, 'tag', 'P1B1', ...
    'free', 6:9, 'u0', u0, 'hStart', 1 / 6, 'coarse', true);
summary = grid_search(spec, workerId, nWorkers);
end
