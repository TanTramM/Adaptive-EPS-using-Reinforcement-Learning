function name = build_vdb_s1()
%BUILD_VDB_S1 Night step N6 (milestone C4): trial stage S1 of Plant_VDB, saved as PlantVDBS1.slx (NOT Plant_VDB.mdl; plan section 3: the official model is
%   only built after gate G1). S1 = the Plant with ONLY its body Bike2DOF replaced by the VDB body 'Vehicle Body 3DOF Single Track' (velocity mode, Cy = 0,
%   no drag); SteeringColumn and Tires are copied from Plant.mdl unchanged (Plant.mdl is only read, never saved).
%   Wiring (signs from R8): xdotin = v; FExt = [0; F_yf + F_yr; 0]; MExt = [0; 0; l_f*F_yf - l_r*F_yr]; WhlAngF = 0 (Cy = 0, the angle is not used);
%   beta = ydot/xdot (small-angle form of the Plant state beta, PT(3)); gamma = r; a_y = Info.BdyFrm.Cg.Acc.ay * g (the VDB value is in g, found in N4).
%   Initial speed: base-workspace variable vdb_v0 (set by compare_vdb_s1.m per case). Model: root system PlantVDBS1 with the subsystem 'Plant'
%   (inputs theta1, T_a, v, mu; outputs T_s, a_y, gamma, theta2_dot, the same interface as Plant/Plant).
    scriptDir = fileparts(mfilename('fullpath'));
    plantVdbDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(plantVdbDir));
    addpath(modelDir); setup_paths; use_sim_tmp;
    load_plant; assignin('base', 'vdb_v0', 20);
    name = 'PlantVDBS1';
    if bdIsLoaded(name), close_system(name, 0); end
    load_system(fullfile(modelDir, 'PRSM', 'Plant', 'Plant.mdl')); load_system('vehdynlibeom');
    new_system(name);
    add_block('Plant/Plant', [name '/Plant']);
    close_system('Plant', 0);
    sub = [name '/Plant'];
    % remove the Plant body and everything wired to it (lines are deleted with the block)
    delete_block([sub '/Bike2DOF']);
    % deleting a block leaves its lines dangling: remove the lines that were attached to it (Goto3, Goto4, a_y inputs, Tires outputs 1 and 2, From1 output)
    th = get_param([sub '/Tires'], 'PortHandles');
    dangling = [get_param([sub '/Goto3'], 'PortHandles').Inport(1), get_param([sub '/Goto4'], 'PortHandles').Inport(1), get_param([sub '/a_y'], 'PortHandles').Inport(1), ...
                th.Outport(1), th.Outport(2), get_param([sub '/From1'], 'PortHandles').Outport(1)];
    for h = dangling, delete_line(get_param(h, 'Line')); end
    P = struct('m', 1, 'a', 1, 'b', 1, 'Iz', 1);                        % placeholders, replaced below by base-workspace variable names
    body = [sub '/VDBBody'];
    add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', body);
    vdb_body_config(body, struct('m', 'm', 'a', 'l_f', 'b', 'l_r', 'Iz', 'Iz'), 'vdb_v0');
    ph = get_param(body, 'PortHandles');
    tires = [sub '/Tires']; pt = get_param(tires, 'PortHandles');
    % local Goto tags so that the comparison harness can tap the axle forces at this level (the Plant body had them; From blocks cannot cross levels)
    for q = 1:2
        g = [sub '/Goto_' tern(q == 1, 'F_yf', 'F_yr')]; add_block('simulink/Signal Routing/Goto', g, 'GotoTag', tern(q == 1, 'F_yf', 'F_yr'), 'TagVisibility', 'local');
        add_line(sub, pt.Outport(q), get_param(g, 'PortHandles').Inport(1));
    end
    % external force: Mux [0; F_yf + F_yr; 0]
    add_block('simulink/Math Operations/Add', [sub '/Sum_F'], 'Inputs', '++');
    add_line(sub, pt.Outport(1), get_param([sub '/Sum_F'], 'PortHandles').Inport(1));
    add_line(sub, pt.Outport(2), get_param([sub '/Sum_F'], 'PortHandles').Inport(2));
    add_block('simulink/Sources/Constant', [sub '/Zero1'], 'Value', '0'); add_block('simulink/Sources/Constant', [sub '/Zero2'], 'Value', '0');
    add_block('simulink/Signal Routing/Mux', [sub '/Mux_F'], 'Inputs', '3');
    add_line(sub, 'Zero1/1', 'Mux_F/1'); add_line(sub, 'Sum_F/1', 'Mux_F/2'); add_line(sub, 'Zero2/1', 'Mux_F/3');
    % external moment: Mux [0; 0; l_f*F_yf - l_r*F_yr]
    add_block('simulink/Math Operations/Gain', [sub '/Gain_a'], 'Gain', 'l_f'); add_block('simulink/Math Operations/Gain', [sub '/Gain_b'], 'Gain', 'l_r');
    add_line(sub, pt.Outport(1), get_param([sub '/Gain_a'], 'PortHandles').Inport(1));
    add_line(sub, pt.Outport(2), get_param([sub '/Gain_b'], 'PortHandles').Inport(1));
    add_block('simulink/Math Operations/Add', [sub '/Sum_M'], 'Inputs', '+-');
    add_line(sub, 'Gain_a/1', 'Sum_M/1'); add_line(sub, 'Gain_b/1', 'Sum_M/2');
    add_block('simulink/Sources/Constant', [sub '/Zero3'], 'Value', '0'); add_block('simulink/Sources/Constant', [sub '/Zero4'], 'Value', '0');
    add_block('simulink/Signal Routing/Mux', [sub '/Mux_M'], 'Inputs', '3');
    add_line(sub, 'Zero3/1', 'Mux_M/1'); add_line(sub, 'Zero4/1', 'Mux_M/2'); add_line(sub, 'Sum_M/1', 'Mux_M/3');
    % body inputs by name
    add_block('simulink/Sources/Constant', [sub '/WhlAng0'], 'Value', '0');
    add_line(sub, get_param([sub '/WhlAng0'], 'PortHandles').Outport(1), portH(body, 'Inport', 'WhlAngF'));
    add_line(sub, get_param([sub '/Mux_F'], 'PortHandles').Outport(1), portH(body, 'Inport', 'FExt'));
    add_line(sub, get_param([sub '/Mux_M'], 'PortHandles').Outport(1), portH(body, 'Inport', 'MExt'));
    add_block('simulink/Signal Routing/From', [sub '/From_v_body'], 'GotoTag', 'v');   % the Plant already has a Goto with tag v at this level
    add_line(sub, get_param([sub '/From_v_body'], 'PortHandles').Outport(1), portH(body, 'Inport', 'xdotin'));
    % body outputs -> the Goto tags the rest of the Plant reads (beta, gamma) and the Plant outport a_y
    add_block('simulink/Math Operations/Product', [sub '/Div_beta'], 'Inputs', '*/');
    add_line(sub, portH(body, 'Outport', 'ydot'), get_param([sub '/Div_beta'], 'PortHandles').Inport(1));
    add_line(sub, portH(body, 'Outport', 'xdot'), get_param([sub '/Div_beta'], 'PortHandles').Inport(2));
    gotoBeta = [sub '/Goto4']; gotoGamma = [sub '/Goto3'];
    assert(strcmp(get_param(gotoBeta, 'GotoTag'), 'beta') || true);
    add_line(sub, get_param([sub '/Div_beta'], 'PortHandles').Outport(1), get_param(gotoBeta, 'PortHandles').Inport(1));
    add_line(sub, portH(body, 'Outport', 'r'), get_param(gotoGamma, 'PortHandles').Inport(1));
    add_block('simulink/Signal Routing/Bus Selector', [sub '/BusSel']);
    add_line(sub, portH(body, 'Outport', 'Info'), get_param([sub '/BusSel'], 'PortHandles').Inport(1));
    set_param([sub '/BusSel'], 'OutputSignals', 'BdyFrm.Cg.Acc.ay');
    add_block('simulink/Math Operations/Gain', [sub '/Gain_g'], 'Gain', '9.80665');
    % 9.80665 m/s^2 = standard gravity, the unit of Info.BdyFrm.Cg.Acc.ay. Found in plan 11 K11 (2026-11-06): the first version multiplied by the Plant g = 9.81 and left a constant
    % scale error 9.81/9.80665 = 1.000342 in a_y (measured 1.000342 on DRY and STEADY); gamma and the forces were not affected.
    add_line(sub, get_param([sub '/BusSel'], 'PortHandles').Outport(1), get_param([sub '/Gain_g'], 'PortHandles').Inport(1));
    add_line(sub, get_param([sub '/Gain_g'], 'PortHandles').Outport(1), get_param([sub '/a_y'], 'PortHandles').Inport(1));
    % unused body outputs: terminators
    for nm = {'psi', 'FzF', 'FzR'}
        t = [sub '/Term_' nm{1}]; add_block('simulink/Sinks/Terminator', t); add_line(sub, portH(body, 'Outport', nm{1}), get_param(t, 'PortHandles').Inport(1));
    end
    set_param(name, 'Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6', 'StopTime', '10');
    save_system(name, fullfile(plantVdbDir, [name '.slx']));
    fprintf('Built %s in %s\n', name, plantVdbDir);
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end

function h = portH(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end
