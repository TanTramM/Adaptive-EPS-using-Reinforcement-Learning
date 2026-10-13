function out = check_mappid_loop(seed)
%CHECK_MAPPID_LOOP End-to-end check of Model_MapPID on the calibration case CALIB (same seed, same noise):
%   (1) PID gains 0 and the Map design of map.json  -> scores equal calib_run('Model_Map', seed)
%   (2) Kmax = 0 (table 0) and the PID design of pid.json, Kaw = Ki/Kp -> scores equal calib_run('Model_PID', seed)
%   Both must agree to the solver tolerance (relative 2e-4: the closed loop runs a variable-step solver, whose step sequence differs slightly between models); a difference means a wiring or a variable error in MapPID.mdl. Run load_map, load_pid, load_mappid and
%   build_closed_loop('MapPID') first (done here when the model file is missing). Output: struct with the three score structs.
if nargin < 1 || isempty(seed), seed = 30000; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
for nm = {'Map', 'PID', 'MapPID'}
    evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', nm{1}, ['load_' lower(nm{1}) '.m']), '\', '/')));
end
if ~exist(fullfile(modelDir, 'Controllers', 'MapPID', 'Model_MapPID.mdl'), 'file'), build_closed_loop('MapPID'); end
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Cal = evalin('base', 'calibrate_map_cached()');

tc = tic; [~, mMap]  = calib_run('Model_Map', seed, []); fprintf('[check] one calib_run takes %.1f s (first call incl. compile)\n', toc(tc));
[~, mPID]  = calib_run('Model_PID', seed, []);
d1 = struct('Ts_ctrl', dm.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
[~, m1] = calib_run('Model_MapPID', seed, mappid_variables(Cal, d1));
d2 = struct('Ts_ctrl', dm.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', 0, 'lead', dm.lead, 'lag', dm.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
[~, m2] = calib_run('Model_MapPID', seed, mappid_variables(Cal, d2));
f = {'R', 'S', 'TV', 'erel', 'rev'};
for i = 1:numel(f)
    fprintf('[%-6s] %-5s Map %.6g | MapPID(PID=0) %.6g || PID %.6g | MapPID(K=0) %.6g\n', 'check', f{i}, mMap.(f{i}), m1.(f{i}), mPID.(f{i}), m2.(f{i}));
    assert(abs(m1.(f{i}) - mMap.(f{i})) <= 2e-4 * max(1, abs(mMap.(f{i}))), 'MapPID with PID = 0 differs from Map in %s', f{i});
    assert(abs(m2.(f{i}) - mPID.(f{i})) <= 2e-4 * max(1, abs(mPID.(f{i}))), 'MapPID with K = 0 differs from PID in %s', f{i});
end
fprintf('[MapPID] closed-loop check PASS (seed %d): PID = 0 reproduces Map, K = 0 reproduces PID\n', seed);
out = struct('Map', mMap, 'PID', mPID, 'MapPID_asMap', m1, 'MapPID_asPID', m2);
end
