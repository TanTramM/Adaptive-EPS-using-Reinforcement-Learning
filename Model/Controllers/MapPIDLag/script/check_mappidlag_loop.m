function out = check_mappidlag_loop(seed)
%CHECK_MAPPIDLAG_LOOP End-to-end check of Model_MapPIDLag on the calibration case CALIB (same seed, same noise):
%   (1) PID gains 0, lag = identity, the slope limit of map.json -> scores equal calib_run('Model_Map', seed) with the Map table and the lead-lag set to the identity
%   (2) Kmax = 0 (table 0), lag = identity, the PID design of pid.json (Kaw = Ki/Kp) -> scores equal calib_run('Model_PID', seed)
%   Both must agree to the solver tolerance (relative 1e-3: the closed loop runs a variable-step solver, whose step sequence differs slightly between models);
%   a difference means a wiring or a variable error in MapPIDLag.mdl. Run build_mappidlag and build_closed_loop('MapPIDLag') first (done here when the model
%   file is missing). Output: struct with the score structs.
if nargin < 1 || isempty(seed), seed = 50000; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
for nm = {'Map', 'PID', 'MapPIDLag'}
    evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', nm{1}, ['load_' lower(nm{1}) '.m']), '\', '/')));
end
if ~exist(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'Model_MapPIDLag.mdl'), 'file'), build_closed_loop('MapPIDLag'); end
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Cal = evalin('base', 'calibrate_map_cached()');
ident = struct('z1', 100, 'p1', 100);

dMapId = struct('Ts_ctrl', dm.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', dm.Kmax, 'lead', struct('z', 100, 'p', 100));   % Map with the lead-lag removed
tc = tic; [~, mMap] = calib_run('Model_Map', seed, map_variables(Cal, dMapId)); fprintf('[check] one calib_run takes %.1f s\n', toc(tc));
Simulink.sdi.clear;
[~, mPID] = calib_run('Model_PID', seed, []); Simulink.sdi.clear;
d1 = struct('Ts_ctrl', dm.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', dm.Kmax, 'lag', ident, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
[~, m1] = calib_run('Model_MapPIDLag', seed, mappidlag_variables(Cal, d1)); Simulink.sdi.clear;
d2 = struct('Ts_ctrl', dm.Ts_ctrl, 'Ts0', dm.Ts0, 'Kmax', 0, 'lag', ident, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
[~, m2] = calib_run('Model_MapPIDLag', seed, mappidlag_variables(Cal, d2)); Simulink.sdi.clear;
f = {'R', 'S', 'TV', 'erel', 'rev'};
tol = 1e-3;     % the noisy closed loop under a variable-step solver is sensitive to rounding (2.5e-4 on TV seen between two structurally equal models); open-loop test_mappidlag is exact to 1e-13
for i = 1:numel(f)
    fprintf('[%-9s] %-5s Map(no lead-lag) %.6g | MapPIDLag(PID=0) %.6g || PID %.6g | MapPIDLag(K=0) %.6g\n', 'check', f{i}, mMap.(f{i}), m1.(f{i}), mPID.(f{i}), m2.(f{i}));
    assert(abs(m1.(f{i}) - mMap.(f{i})) <= tol * max(1, abs(mMap.(f{i}))), 'MapPIDLag with PID = 0 differs from Map in %s', f{i});
    assert(abs(m2.(f{i}) - mPID.(f{i})) <= tol * max(1, abs(mPID.(f{i}))), 'MapPIDLag with K = 0 differs from PID in %s', f{i});
end
fprintf('[MapPIDLag] closed-loop check PASS (seed %d): PID = 0 reproduces the Map table, K = 0 reproduces PID\n', seed);
out = struct('Map', mMap, 'PID', mPID, 'MapPIDLag_asMap', m1, 'MapPIDLag_asPID', m2);
end
