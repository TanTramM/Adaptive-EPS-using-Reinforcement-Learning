function run_ssw_3d(nameA, nameB, caseTag, tWin, scene, seed, offB)
%RUN_SSW_3D Play two logged SSW poses in the Unreal Engine scene of Model/VDB/temp_test/Viz3D/SSW3D.slx (visualisation only).
%   run_ssw_3d('Map', 'MapPID', 'SLIP')                    whole case, vehicle A = Map (red), B = MapPID (blue), scene 'Open surface'
%   run_ssw_3d('Map', 'MapPID', 'SLIP', [80 95])           only 80-95 s, both poses shifted so that A starts at the scene origin
%   run_ssw_3d('Map_VDBTireLag', 'MapPID_VDBTireLag', 'SLIP', [], 'Open surface')
%   Reads Model/VDB/temp_test/<ctrl>/Result/<name>_<CASE>_pose_<sens>.csv written by export_ssw_pose.m (<ctrl> = text before the first '_').
%   offB [m] (default 4): vehicle B is translated sideways by offB, perpendicular to A's heading at the window start, so the two cars do
%   not overlap; a rigid translation keeps every difference between the two paths.
%   Inputs of the 3D vehicles: X, Y [m], Yaw [deg], ISO axes, sampled at viz_Ts = 1/30 s. Run time is about real time (pacing on).
    if nargin < 4, tWin = []; end
    if nargin < 5 || isempty(scene), scene = 'Open surface'; end
    if nargin < 6, seed = 99999; end
    if nargin < 7, offB = 4; end
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(tempDir));
    addpath(fullfile(modelDir, 'shared')); setup_paths;
    sens = sensor_tag(seed);
    A = readPose(tempDir, nameA, caseTag, sens); B = readPose(tempDir, nameB, caseTag, sens);
    if isempty(tWin), tWin = [A.t(1) A.t(end)]; end
    Ts = 1 / 30;
    tq = (tWin(1):Ts:tWin(2))';
    i0 = find(A.t >= tWin(1), 1);
    x0 = A.X(i0); y0 = A.Y(i0);                          % common shift: A starts at the scene origin, B keeps its offset from A
    assignin('base', 'viz_Ts', Ts); assignin('base', 'viz_Tend', tq(end) - tq(1));
    p0 = A.psi(i0);
    put('A', A, tq, x0, y0); put('B', B, tq, x0 + offB * sin(p0), y0 - offB * cos(p0));   % B shifted offB to the left of A (left normal of the initial heading)
    mdl = 'SSW3D';
    load_system(fullfile(tempDir, 'Viz3D', [mdl '.slx']));
    set_param([mdl '/Scene'], 'SceneDesc', scene);
    fprintf('run_ssw_3d: %s (red) vs %s (blue), %s %.1f-%.1f s, scene %s\n', nameA, nameB, caseTag, tWin(1), tWin(2), scene);
    so = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    % write one MP4 per camera (30 frame/s) and a PNG of the middle frame, in Model/VDB/temp_test/Viz3D/
    stem = sprintf('%s_vs_%s_%s_%gto%gs', nameA, nameB, caseTag, tWin(1), tWin(2));
    for cam = {'chase', 'top'}
        try
            ts = so.get(['viz_img_' cam{1}]);
        catch
            continue
        end
        D = ts.Data;                                       % H x W x 3 x N (uint8)
        f = fullfile(tempDir, 'Viz3D', sprintf('%s_%s.mp4', stem, cam{1}));
        vw = VideoWriter(f, 'MPEG-4'); vw.FrameRate = round(1 / Ts); open(vw);
        for k = 1:size(D, 4), writeVideo(vw, D(:, :, :, k)); end
        close(vw);
        imwrite(D(:, :, :, max(1, round(size(D, 4) / 2))), strrep(f, '.mp4', '_mid.png'));
        fprintf('run_ssw_3d: %d frames -> %s\n', size(D, 4), f);
    end
end

function P = readPose(tempDir, name, caseTag, sens)
    ctrl = strtok(name, '_');
    f = fullfile(tempDir, ctrl, 'Result', sprintf('%s_%s_pose_%s.csv', name, caseTag, sens));
    assert(isfile(f), 'run_ssw_3d: missing %s (run export_ssw_pose first)', f);
    P = readtable(f);
end

function put(id, P, tq, x0, y0)
    t = tq - tq(1);
    X = interp1(P.t, P.X, tq) - x0; Y = interp1(P.t, P.Y, tq) - y0; Yaw = rad2deg(interp1(P.t, P.psi, tq));   % body heading (psi), not the course angle psi + beta
    assignin('base', ['viz_' id '_X'], timeseries(X, t));
    assignin('base', ['viz_' id '_Y'], timeseries(Y, t));
    assignin('base', ['viz_' id '_Yaw'], timeseries(Yaw, t));
end
