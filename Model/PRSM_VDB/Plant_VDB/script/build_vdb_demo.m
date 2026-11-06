function mdl = build_vdb_demo(overwrite)
%BUILD_VDB_DEMO Demo model that shows what the Vehicle Dynamics Blockset (VDB) blocks are. It is NOT the Plant_VDB environment yet
%   (Plant_VDB.mdl is built only after gate G1 of Documents/Shared/KeHoach_Plant_VDB.txt) and no controller uses it.
%   Chain A: step front steer angle -> Vehicle Body 3DOF Single Track (velocity mode) -> r, ydot, psi, xdot.
%   Chain B: Vy ramp at constant Vx -> Combined Slip Wheel 2DOF (one tire, vertical load from outside) -> Fy, Mz, Fz. The friction scale
%            factor LMUY (row 3 of ScaleFctrs) is a model-workspace variable so run_vdb_demo can sweep it.
%   Parameters of chain A are read from data/params.json (m, l_f, l_r, Iz, C_alpha per axle); no value is typed by hand.
%   Writes Model/PRSM_VDB/Plant_VDB/VDBDemo.slx. overwrite = false (default) never replaces an existing file: it writes VDBDemo_1, _2 ...
    if nargin < 1, overwrite = false; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));      % Model/ (this file is Model/PRSM_VDB/Plant_VDB/script/)
    plantDir = fileparts(scriptDir);                            % Model/PRSM_VDB/Plant_VDB/
    addpath(modelDir); setup_paths;
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));

    mdl = 'VDBDemo'; k = 0;
    while ~overwrite && exist(fullfile(plantDir, [mdl '.slx']), 'file')
        k = k + 1; mdl = sprintf('VDBDemo_%d', k);
    end
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    load_system('vehdynlibeom'); load_system('vehdynlibtire');

    %% Chain A: 3DOF single track
    body = [mdl '/Body3DOF'];
    add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', body, 'Position', [300 60 460 200]);
    setp(body, 'm', raw.cum2.m.value);
    setp(body, 'a', raw.cum2.l_f.value);
    setp(body, 'b', raw.cum2.l_r.value);
    setp(body, 'Izz', raw.cum3.Iz.value);
    setp(body, 'Cy_f', raw.cum2.C_alpha_f.value);   % NOTE: the block scales Cy by Fz/Fznom (see KeHoach_Plant_VDB.txt, C0 results), so this is not the axle stiffness
    setp(body, 'Cy_r', raw.cum2.C_r.value);
    set_param(body, 'sigmaMode', 'off');           % no relaxation length, like the Plant
    add_block('simulink/Sources/Step', [mdl '/delta_f'], 'Time', '1', 'Before', '0', 'After', '0.02', 'Position', [60 60 110 90]);
    add_block('simulink/Sources/Constant', [mdl '/xdot_in'], 'Value', '20', 'Position', [60 140 110 170]);
    wire(mdl, [mdl '/delta_f'], body, 'WhlAngF');
    wire(mdl, [mdl '/xdot_in'], body, 'xdotin');
    outs = {'r', 'ydot', 'psi', 'xdot'};
    for i = 1:numel(outs)
        tw = [mdl '/log_' outs{i}];
        add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['A_' outs{i}], 'SaveFormat', 'Timeseries', ...
            'Position', [560 40+45*i 640 70+45*i]);
        wireOut(mdl, body, outs{i}, tw);
    end

    %% Chain B: one Combined Slip Wheel 2DOF
    tire = [mdl '/Tire'];
    add_block('vehdynlibtire/Combined Slip Wheel 2DOF', tire, 'Position', [300 300 460 520]);
    try
        set_param(tire, 'tireType', 'Light passenger car 205/60R15');
    catch ME
        fprintf('tireType not set (%s); the tire keeps its default.\n', ME.message);
    end
    try, set_param(tire, 'vertType', 'None'); catch ME, fprintf('vertType not set (%s)\n', ME.message); end
    Fz = raw.cum2.m.value * raw.cum2.g.value * raw.cum2.l_r.value / (raw.cum2.l_f.value + raw.cum2.l_r.value) / 2;   % half front axle static load, N
    hws = get_param(mdl, 'ModelWorkspace');
    assignin(hws, 'LMUY', 1); assignin(hws, 'Fz_static', Fz);
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', '20'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; ...
            'Fext', 'Fz_static'; 'ScaleFctrs', '[1;1;LMUY;0;ones(23,1)]'};
    y0 = 300;
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}];
        add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}, 'Position', [60 y0+30*i 130 y0+22+30*i]);
        wire(mdl, b, tire, srcs{i, 1}, true);
    end
    yv = y0 + 30 * (size(srcs, 1) + 1);
    add_block('simulink/Sources/Ramp', [mdl '/src_Vy'], 'Slope', '0.6', 'InitialOutput', '-3', 'Position', [60 yv 130 yv+22]);
    wire(mdl, [mdl '/src_Vy'], tire, 'Vy');
    names = {'Fy', 'Mz', 'Fz'};
    for i = 1:numel(names)
        tw = [mdl '/log_' names{i}];
        add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['B_' names{i}], 'SaveFormat', 'Timeseries', ...
            'Position', [560 300+45*i 640 330+45*i]);
        wireOut(mdl, tire, names{i}, tw);
    end

    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '10', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    save_system(mdl, fullfile(plantDir, [mdl '.slx']));
    % Input ports that were not wired by name are reported, so nothing is silently left open.
    for b = {body, tire}
        ph = get_param(b{1}, 'PortHandles');
        for i = 1:numel(ph.Inport)
            if get_param(ph.Inport(i), 'Line') == -1
                fprintf('WARNING: open input %d of %s\n', i, b{1});
            end
        end
    end
    fprintf('Built %s in %s\n', mdl, plantDir);
end

function setp(blk, name, val)
    set_param(blk, name, num2str(val, 12));
end

function map = portMap(blk, type)
    % name -> port number of the Inport/Outport blocks inside a masked library block
    h = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type);
    map = containers.Map();
    for i = 1:numel(h)
        map(get_param(h{i}, 'Name')) = str2double(get_param(h{i}, 'Port'));
    end
end

function wire(mdl, src, dst, portName, optional)
    if nargin < 5, optional = false; end
    m = portMap(dst, 'Inport');
    if ~isKey(m, portName)
        if optional, fprintf('(%s has no input %s, skipped)\n', dst, portName); return; end
        error('No input %s in %s. Inputs: %s', portName, dst, strjoin(keys(m), ', '));
    end
    ph = get_param(dst, 'PortHandles');
    if m(portName) > numel(ph.Inport)
        if optional, fprintf('(%s input %s is not an active port with these settings, skipped)\n', dst, portName); return; end
        error('Input %s of %s is not active', portName, dst);
    end
    add_line(mdl, get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(mdl, src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s. Outputs: %s', portName, src, strjoin(keys(m), ', ')); end
    ph = get_param(src, 'PortHandles');
    add_line(mdl, ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
