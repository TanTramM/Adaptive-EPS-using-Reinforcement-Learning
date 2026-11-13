function name = build_ssw_3d(overwrite)
%BUILD_SSW_3D Build Model/VDB/temp_test/Viz3D/SSW3D.slx: two vehicles in an Unreal Engine scene (VDB 3D environment), driven ONLY by logged poses.
%   name = build_ssw_3d(false)   do not overwrite (SSW3D_1.slx ... if SSW3D.slx exists); build_ssw_3d(true) overwrites.
%   Visualisation only: the vehicle dynamics are NOT in this model. Each vehicle reads X, Y, Yaw (ISO axes) from the base-workspace
%   timeseries viz_A_X, viz_A_Y, viz_A_Yaw and viz_B_X, viz_B_Y, viz_B_Yaw (set by run_ssw_3d.m from the *_pose_*.csv files).
%   Blocks: Simulation 3D Scene Configuration (scene viz_scene, camera on vehicle A), two Simulation 3D Vehicle with Ground Following
%   (A red, B blue), From Workspace sources. Sample time viz_Ts. Simulation pacing on (about real time) so the window can be recorded.
    if nargin < 1, overwrite = false; end
    scriptDir = fileparts(mfilename('fullpath'));
    outDir = fullfile(fileparts(scriptDir), 'Viz3D'); if ~isfolder(outDir), mkdir(outDir); end
    name = 'SSW3D';
    if ~overwrite
        k = 0; while isfile(fullfile(outDir, [name '.slx'])), k = k + 1; name = sprintf('SSW3D_%d', k); end
    end
    if bdIsLoaded(name), close_system(name, 0); end
    new_system(name); load_system('sim3dlib'); load_system('sim3dautolib');
    sc = [name '/Scene'];
    add_block('sim3dlib/Simulation 3D Scene Configuration', sc, 'Position', [40 40 200 120]);
    set_param(sc, 'SceneDesc', 'Open surface', 'Ts', 'viz_Ts');
    veh = {'A', 'Red', 220; 'B', 'Blue', 420};
    for i = 1:size(veh, 1)
        id = veh{i, 1}; y0 = veh{i, 3};
        vb = sprintf('%s/Vehicle_%s', name, id);
        add_block('sim3dautolib/Simulation 3D Vehicle with Ground Following', vb, 'Position', [420 y0 600 y0 + 100]);
        set_param(vb, 'PassVehMesh', 'Sedan', 'ActorName', ['Veh' id], 'SampleTime', 'viz_Ts', 'CoordinateScheme', 'ISO');
        try, set_param(vb, 'VehColor', veh{i, 2}); catch, end
        sig = {'X', 'Y', 'Yaw'};
        for j = 1:3
            fw = sprintf('%s/%s_%s', name, id, sig{j});
            add_block('simulink/Sources/From Workspace', fw, 'Position', [200 y0 + 30 * (j - 1) 300 y0 + 30 * (j - 1) + 20]);
            set_param(fw, 'VariableName', sprintf('viz_%s_%s', id, sig{j}), 'SampleTime', 'viz_Ts', 'OutputAfterFinalValue', 'Holding final value');
            add_line(name, [get_param(fw, 'Name') '/1'], sprintf('Vehicle_%s/%d', id, j), 'autorouting', 'on');
        end
    end
    try, set_param(sc, 'vehTag', 'VehA'); catch, end   % camera list is filled only after a model update; else choose in the dialog
    % two recording cameras attached to vehicle A (chase view and top view); images go to the workspace, run_ssw_3d writes the MP4
    cams = {'Chase', '[-14 0 5]', '[0 12 0]', 700; 'Top', '[0 0 35]', '[0 90 0]', 820};
    for i = 1:size(cams, 1)
        cb = sprintf('%s/Cam%s', name, cams{i, 1}); y0 = cams{i, 4};
        add_block('sim3dlib/Simulation 3D Camera Get', cb, 'Position', [420 y0 600 y0 + 60]);
        set_param(cb, 'sensorId', num2str(i), 'sensorName', ['Cam' cams{i, 1}], 'HorizontalResolution', '960', 'VerticalResolution', '540', ...
            'SampleTime', 'viz_Ts');
        try, set_param(cb, 'vehTagList', '{''Scene Origin'', ''VehA'', ''VehB''}'); set_param(cb, 'vehTag', 'VehA'); catch e, warning('%s', e.message); end
        set_param(cb, 'offsetFlag', 'on', 'tmountOffset', cams{i, 2}, 'rmountOffset', cams{i, 3});
        tw = sprintf('%s/img_%s', name, cams{i, 1});
        add_block('simulink/Sinks/To Workspace', tw, 'Position', [680 y0 + 15 760 y0 + 45]);
        set_param(tw, 'VariableName', ['viz_img_' lower(cams{i, 1})], 'SaveFormat', 'Timeseries', 'SampleTime', 'viz_Ts');
        add_line(name, ['Cam' cams{i, 1} '/1'], ['img_' cams{i, 1} '/1'], 'autorouting', 'on');
    end
    set_param(name, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'viz_Ts', 'StopTime', 'viz_Tend', 'EnablePacing', 'on', 'PacingRate', '1');
    save_system(name, fullfile(outDir, [name '.slx'])); close_system(name, 0);
    fprintf('build_ssw_3d: %s\n', fullfile(outDir, [name '.slx']));
end
