function name = build_vdb_s2(variant)
%BUILD_VDB_S2 Night step N9 (TRIAL, not official): S2 and S3 of Documents/Shared/KeHoach_Plant_VDB.txt, saved as PlantVDBS2.slx / PlantVDBS3.slx.
%   Starts from PlantVDBS1.slx (Plant with the VDB body) and replaces the Plant block Tires by two VDB tire blocks (front and rear half axle, forces doubled):
%     S2: tires configured by vdb_tire_config.m (same Magic Formula as the Plant), T_r from PT(13)-(14) with alpha_f computed from the VDB signals.
%     S3: library tire 205/60R15 as it is (ply steer and turn slip off), T_r = (e_c*F_y - M_z)/n_st from the tire M_z (R8, N5).
%   Wiring (signs of R8): front-axle velocity (Vx, Vy + l_f*r) rotated by +delta_f into the wheel frame, rear axle (Vx, Vy - l_r*r); delta_f = theta2/n_st;
%   F_yf = 2*Fy_front_wheel_frame (Plant convention, no cos(delta) factor), F_yr = 2*Fy_rear; alpha_f(Plant) = -atan(Vy_w/Vx_w). The MATLAB Function blocks are
%   used because the slip-angle and trail formulas have several branches (build rules, section 5: allowed, reason stated here). Trial models only, never Plant_VDB.mdl.
    if nargin < 1, variant = 'S2'; end
    scriptDir = fileparts(mfilename('fullpath'));
    plantVdbDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(plantVdbDir));
    addpath(modelDir); setup_paths; use_sim_tmp;
    load_plant; assignin('base', 'vdb_v0', 20);
    name = ['PlantVDB' variant]; if strcmp(variant, 'S2'), name = 'PlantVDBS2'; else, name = 'PlantVDBS3'; end
    if bdIsLoaded(name), close_system(name, 0); end
    load_system(fullfile(plantVdbDir, 'PlantVDBS1.slx')); load_system('vehdynlibeom'); load_system('vehdynlibtire');
    new_system(name);
    add_block('PlantVDBS1/Plant', [name '/Plant']); close_system('PlantVDBS1', 0);
    sub = [name '/Plant'];
    P = load_vdb_params(modelDir);
    % delete the Plant tires and the lines attached to them
    th = get_param([sub '/Tires'], 'PortHandles');
    delete_block([sub '/Tires']);
    dang = {'Sum_F', 'Inport', 1; 'Sum_F', 'Inport', 2; 'Gain_a', 'Inport', 1; 'Gain_b', 'Inport', 1; 'Goto_F_yf', 'Inport', 1; 'Goto_F_yr', 'Inport', 1; 'Goto2', 'Inport', 1};
    for i = 1:size(dang, 1)
        ph = get_param([sub '/' dang{i, 1}], 'PortHandles'); l = get_param(ph.Inport(dang{i, 3}), 'Line'); if l > 0, delete_line(l); end
    end
    body = [sub '/VDBBody'];
    % delta_f = theta2/n_st (theta2 from the Goto tag of the SteeringColumn)
    add_block('simulink/Signal Routing/From', [sub '/From_theta2'], 'GotoTag', 'theta2');
    add_block('simulink/Math Operations/Gain', [sub '/Gain_delta'], 'Gain', '1/n_st');
    link(sub, 'From_theta2', 'Gain_delta');
    % MATLAB Function: wheel-frame velocities
    fv = [sub '/TireInputs']; add_block('simulink/User-Defined Functions/MATLAB Function', fv);
    setScript(fv, [ ...
        'function [VxF, VyF, VxR, VyR, alF] = f(xdot, ydot, r, delta, a, b)' newline ...
        'VyFv = ydot + a*r;' newline ...
        'VxF = xdot*cos(delta) + VyFv*sin(delta);' newline ...
        'VyF = -xdot*sin(delta) + VyFv*cos(delta);' newline ...
        'VxR = xdot; VyR = ydot - b*r;' newline ...
        'alF = -atan2(VyF, VxF);   % Plant slip angle alpha_f = -alpha_VDB' newline]);
    consts = {'l_f', 'in_a'; 'l_r', 'in_b'};
    for i = 1:2, add_block('simulink/Sources/Constant', [sub '/' consts{i, 2}], 'Value', consts{i, 1}); end
    linkPorts(sub, portOut(body, 'xdot'), portIn(fv, 'xdot')); linkPorts(sub, portOut(body, 'ydot'), portIn(fv, 'ydot')); linkPorts(sub, portOut(body, 'r'), portIn(fv, 'r'));
    link(sub, 'Gain_delta', fv, 'delta'); link(sub, 'in_a', fv, 'a'); link(sub, 'in_b', fv, 'b');
    % tires
    tire = struct(); axle = {'front', 'rear'};
    for q = 1:2
        tb = [sub '/Tire_' axle{q}]; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', tb);
        if strcmp(variant, 'S2')
            vdb_tire_config(tb, P, axle{q}, 20);
            Re = str2double(get_param(tb, 'UNLOADED_RADIUS'));
        else
            set_param(tb, 'tireType', 'Light passenger car 205/60R15'); set_param(tb, 'vertType', 'None'); set_param(tb, 'plySteer', 'off'); set_param(tb, 'turnslip', 'off');
            Re = str2double(get_param(tb, 'UNLOADED_RADIUS'));
        end
        set_param(tb, 'omegao', sprintf('vdb_v0/(0.97*%.6g)', Re));                % starts at the rolling speed of the case
        Fz = tern(q == 1, P.Fzf, P.Fzr) / 2;
        cs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz, 12)};
        for i = 1:size(cs, 1), b = sprintf('%s/c%d_%s', sub, q, cs{i, 1}); add_block('simulink/Sources/Constant', b, 'Value', cs{i, 2}); linkPorts(sub, outH(b), portIn(tb, cs{i, 1})); end
        % ScaleFctrs = [1;1;mu;0;ones(23,1)] from the plant input mu
        mg = sprintf('%s/mu_vec%d', sub, q); add_block('simulink/Math Operations/Gain', mg, 'Gain', '[0;0;1;0;zeros(23,1)]', 'Multiplication', 'Matrix(K*u)');
        sb = sprintf('%s/sf_base%d', sub, q); add_block('simulink/Sources/Constant', sb, 'Value', '[1;1;0;0;ones(23,1)]');
        sm = sprintf('%s/sf_sum%d', sub, q); add_block('simulink/Math Operations/Add', sm, 'Inputs', '++');
        mu_in = get_param([sub '/mu'], 'PortHandles');
        add_line(sub, mu_in.Outport(1), get_param(mg, 'PortHandles').Inport(1));
        linkPorts(sub, outH(sb), get_param(sm, 'PortHandles').Inport(1)); linkPorts(sub, outH(mg), get_param(sm, 'PortHandles').Inport(2));
        linkPorts(sub, outH(sm), portIn(tb, 'ScaleFctrs'));
        tire(q).blk = tb;
    end
    linkPorts(sub, portOut(fv, 'VxF'), portIn(tire(1).blk, 'Vx')); linkPorts(sub, portOut(fv, 'VyF'), portIn(tire(1).blk, 'Vy'));
    linkPorts(sub, portOut(fv, 'VxR'), portIn(tire(2).blk, 'Vx')); linkPorts(sub, portOut(fv, 'VyR'), portIn(tire(2).blk, 'Vy'));
    % axle forces F_yf = 2*Fy_front, F_yr = 2*Fy_rear
    for q = 1:2
        g = sprintf('%s/Gain_F%d', sub, q); add_block('simulink/Math Operations/Gain', g, 'Gain', '2');
        linkPorts(sub, portOut(tire(q).blk, 'Fy'), get_param(g, 'PortHandles').Inport(1));
    end
    gF = {[sub '/Gain_F1'], [sub '/Gain_F2']};
    linkPorts(sub, outH(gF{1}), get_param([sub '/Sum_F'], 'PortHandles').Inport(1)); linkPorts(sub, outH(gF{2}), get_param([sub '/Sum_F'], 'PortHandles').Inport(2));
    linkPorts(sub, outH(gF{1}), get_param([sub '/Gain_a'], 'PortHandles').Inport(1)); linkPorts(sub, outH(gF{2}), get_param([sub '/Gain_b'], 'PortHandles').Inport(1));
    linkPorts(sub, outH(gF{1}), get_param([sub '/Goto_F_yf'], 'PortHandles').Inport(1)); linkPorts(sub, outH(gF{2}), get_param([sub '/Goto_F_yr'], 'PortHandles').Inport(1));
    % T_r
    tr = [sub '/TrCalc']; add_block('simulink/User-Defined Functions/MATLAB Function', tr);
    if strcmp(variant, 'S2')
        setScript(tr, [ ...
            'function Tr = f(alF, Fyf, mu, ep0, t0, Ca, Fzf, n)' newline ...
            'ec = ep0 - t0;' newline ...
            'ep = ec + max(0, t0 - sign(alF)*t0*Ca*tan(alF)/(3*mu*Fzf));   % PT(13)-(14)' newline ...
            'Tr = ep/n*Fyf;' newline]);
        ins = {'alF', 'Fyf', 'mu', 'ep0', 't0', 'Ca', 'Fzf', 'n'};
        cv = {'e_p0', 't_0', 'C_alpha_f', 'F_zf', 'n_st'};
        for i = 1:5, add_block('simulink/Sources/Constant', sprintf('%s/trc%d', sub, i), 'Value', cv{i}); link(sub, sprintf('trc%d', i), tr, ins{3 + i}); end
        linkPorts(sub, portOut(fv, 'alF'), portIn(tr, 'alF')); linkPorts(sub, outH(gF{1}), portIn(tr, 'Fyf'));
        add_line(sub, mu_in.Outport(1), portIn(tr, 'mu'));
    else
        setScript(tr, [ ...
            'function Tr = f(Mzf, Fyf, ep0, t0, n)' newline ...
            'ec = ep0 - t0;' newline ...
            'Tr = (ec*Fyf - 2*Mzf)/n;   % axle values = 2 x one wheel (R8 Q4)' newline]);
        cv = {'e_p0', 't_0', 'n_st'}; ins = {'ep0', 't0', 'n'};
        for i = 1:3, add_block('simulink/Sources/Constant', sprintf('%s/trc%d', sub, i), 'Value', cv{i}); link(sub, sprintf('trc%d', i), tr, ins{i}); end
        linkPorts(sub, portOut(tire(1).blk, 'Mz'), portIn(tr, 'Mzf')); linkPorts(sub, outH(gF{1}), portIn(tr, 'Fyf'));
    end
    linkPorts(sub, outH(tr), get_param([sub '/Goto2'], 'PortHandles').Inport(1));
    % unused outputs: terminators (every other output of the tire blocks and of TireInputs)
    for q = 1:2
        ph = get_param(tire(q).blk, 'PortHandles');
        for k = 1:numel(ph.Outport)
            if get_param(ph.Outport(k), 'Line') < 0, t = sprintf('%s/Term_t%d_%d', sub, q, k); add_block('simulink/Sinks/Terminator', t); add_line(sub, ph.Outport(k), get_param(t, 'PortHandles').Inport(1)); end
        end
    end
    ph = get_param(fv, 'PortHandles');
    if strcmp(variant, 'S3'), t = [sub '/Term_alF']; add_block('simulink/Sinks/Terminator', t); add_line(sub, portOut(fv, 'alF'), get_param(t, 'PortHandles').Inport(1)); end
    set_param(name, 'Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6', 'StopTime', '10');
    save_system(name, fullfile(plantVdbDir, [name '.slx']));
    fprintf('Built %s in %s\n', name, plantVdbDir);
end

function setScript(blk, txt)
    rt = sfroot; ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk); ch.Script = txt;
end

function h = portIn(blk, name)
    ph = get_param(blk, 'PortHandles');
    names = fnNames(blk, 'in');
    if ~isempty(names)                                               % MATLAB Function block: ports follow the argument order
        k = find(strcmp(names, name)); assert(numel(k) == 1, 'input %s not found in %s', name, blk); h = ph.Inport(k); return;
    end
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Name', name);
    assert(numel(b) == 1, 'input %s not found in %s', name, blk);
    h = ph.Inport(str2double(get_param(b{1}, 'Port')));
end

function h = portOut(blk, name)
    ph = get_param(blk, 'PortHandles');
    names = fnNames(blk, 'out');
    if ~isempty(names)
        k = find(strcmp(names, name)); assert(numel(k) == 1, 'output %s not found in %s', name, blk); h = ph.Outport(k); return;
    end
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Name', name);
    assert(numel(b) == 1, 'output %s not found in %s', name, blk);
    h = ph.Outport(str2double(get_param(b{1}, 'Port')));
end

function names = fnNames(blk, which)
% argument names of a MATLAB Function block (empty for any other block), parsed from the first line of its script
    names = {};
    try, if ~strcmp(get_param(blk, 'SFBlockType'), 'MATLAB Function'), return; end, catch, return; end
    rt = sfroot; ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk);
    first = strtrim(strtok(ch.Script, newline));
    eq = find(first == '=', 1); op = find(first == '(', 1); cp = find(first == ')', 1, 'last');
    outs = strtrim(first(length('function') + 1:eq - 1)); outs = strrep(strrep(outs, '[', ''), ']', '');
    args = first(op + 1:cp - 1);
    if strcmp(which, 'out'), names = strtrim(strsplit(outs, ',')); else, names = strtrim(strsplit(args, ',')); end
end

function h = outH(blk)
    ph = get_param(blk, 'PortHandles'); h = ph.Outport(1);
end

function linkPorts(sys, src, dst)
    add_line(sys, src, dst);
end

function link(sys, a, b, portName)
% link(sys, srcBlockName, dstBlockName [, dstInputName]): output 1 of a to input of b (by name when portName is given, else input 1)
    src = get_param([sys '/' a], 'PortHandles').Outport(1);
    if nargin < 4
        dst = get_param([sys '/' b], 'PortHandles').Inport(1);
    else
        dstBlk = b; if ~startsWith(b, sys), dstBlk = [sys '/' b]; end
        dst = portIn(dstBlk, portName);
    end
    add_line(sys, src, dst);
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
