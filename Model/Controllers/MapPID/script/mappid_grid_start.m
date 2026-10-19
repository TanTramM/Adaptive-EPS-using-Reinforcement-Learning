function u0 = mappid_grid_start(startName, modelDir)
%MAPPID_GRID_START Build the two pre-registered MapPID starting points.
%   S1 starts from the selected grid PID with the Map branch disabled.
%   S2 starts from the selected grid Map with the PID branch near disabled.
if nargin < 2 || isempty(modelDir)
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
end
startName = upper(char(startName));

pidPick = result_dir('PID', 'Calib');
mapPick = result_dir('Map', 'Calib');
switch startName
    case 'S1'
        assert(exist(fullfile(pidPick, 'PID_CALIB_pick_s10000.csv'), 'file') == 2, ...
            'PID grid selection is not finished (PID_CALIB_pick_s10000.csv is missing).');
        J = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
        assert(isfield(J, 'design'), 'pid.json has no selected design.');
        d = J.design;
        x = [0, 50, 1, 20, 1, d.Kp, d.Ki, d.Kd, d.Tf];
        u0 = mappid_x2u(x);
        u0(1:5) = [0, 0.5, 0, 0.5, 1];
    case 'S2'
        assert(exist(fullfile(mapPick, 'Map_CALIB_pick_s00000.csv'), 'file') == 2, ...
            'Map grid selection is not finished (Map_CALIB_pick_s00000.csv is missing).');
        J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
        assert(isfield(J, 'design'), 'map.json has no selected design.');
        d = J.design;
        assert(isfield(d, 'lag'), 'The selected Map design has no lag data.');
        x = [d.Kmax, d.lead.z, d.lead.p / d.lead.z, d.lag.z1, d.lag.p1 / d.lag.z1, ...
             1e-3, 0.1, 0, sqrt(1e-3 * 0.0796)];
        u0 = mappid_x2u(x);
        u0(6:9) = [0, 0, 0, 0.5];
    otherwise
        error('startName must be S1 or S2.');
end
end
