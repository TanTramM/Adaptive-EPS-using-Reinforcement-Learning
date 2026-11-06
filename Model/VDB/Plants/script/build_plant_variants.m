function names = build_plant_variants(overwrite, only)
%BUILD_PLANT_VARIANTS Build the VDB blocks and the three trial Plants of the step-by-step replacement (Model/VDB), each a copy of Model/original/PRSM/Plant/Plant.mdl
%   in which only the named blocks are replaced; every other block, line and Goto/From tag is the original (SteeringColumn is never touched).
%   names = build_plant_variants(overwrite)   overwrite = false (default) never overwrites: an existing name gets _1, _2, ...
%   Blocks (Model/VDB/Blocks/, root subsystem named like the model, SAME ports as the original block they replace):
%     Tires_VDB.slx      replaces Tires  : in theta2, beta, gamma, v, mu; out F_yf, F_yr, T_r. Inside: two VDB wheels 'Combined Slip Wheel 2DOF' (vdb_tire_config.m, forces
%                        doubled), slip angles by Plant equations (10)-(11), T_r by the Plant pneumatic-trail equations.
%     Body3DOF_VDB.slx   replaces Bike2DOF: in F_yf, F_yr, v; out a_y, gamma, beta. Inside: the VDB body 'Vehicle Body 3DOF Single Track' (vdb_body_config.m), wired as build_vdb_s1.m.
%   Plants (Model/VDB/Plants/, root subsystem named like the model; the replaced block keeps its instance name Tires or Bike2DOF so every wire and tag around it is the original):
%     Plant_VDBTire      step 2: only Tires replaced
%     Plant_VDBBody      step 3: only Bike2DOF replaced (the VDB body with the original Tires)
%     Plant_VDBTireBody  step 4: both replaced
%   Step 1 of making the VDB tire more realistic (2026-11-07, one feature at a time, each checked against the Plant):
%     Tires_VDBLag       as Tires_VDB with the real lateral relaxation length: the block clamps the relaxation frequency from below at FyRelFreqLwrLim = 200*pi rad/s (100 Hz), which
%                        holds the lag at 1.59 ms; lowering the limit to 1 rad/s lets the block use its own relaxation length (measured 0.609 m, tau = 0.609/v, 22-109 ms at 27.8-5.6 m/s)
%     Plant_VDBTireLag   the Plant with only Tires replaced by Tires_VDBLag
%   build_plant_variants(overwrite, only)   only = cell array of model names to build (default: all), e.g. {'Tires_VDBLag', 'Plant_VDBTireLag'}
%   MATLAB Function blocks are used for the slip-angle and trail formulas because they have several branches (build rules, section 5: allowed, reason stated here).
%   Needs the Vehicle Dynamics Blockset. Run by itself (it calls load_plant_vdb).
    if nargin < 1, overwrite = false; end
    if nargin < 2, only = {}; end
    scriptDir = fileparts(mfilename('fullpath'));
    plantsDir = fileparts(scriptDir);
    vdbDir = fileparts(plantsDir);
    blocksDir = fullfile(vdbDir, 'Blocks');
    modelDir = fileparts(vdbDir);
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    load_plant_vdb;
    P = load_vdb_params(modelDir);
    trail = loadTrail(blocksDir);        % coefficients of fit_vdb_trail.m (used only by the variants whose T_r comes from the tire Mz)
    load_system('Tires'); load_system('Bike2DOF'); load_system('Plant');
    load_system('vehdynlibtire'); load_system('vehdynlibeom');
    names = {};
    % --- standalone blocks
    blk = {'Tires_VDB', 'Tires', @(s) fillTires(s, P, false, []); 'Body3DOF_VDB', 'Bike2DOF', @(s) fillBike(s); 'Tires_VDBLag', 'Tires', @(s) fillTires(s, P, true, []); ...
           'Tires_VDBLagMz', 'Tires', @(s) fillTires(s, P, true, trail)};
    for i = 1:size(blk, 1)
        if ~isempty(only) && ~any(strcmp(only, blk{i, 1})), continue; end
        n = pickName(blocksDir, blk{i, 1}, overwrite);
        new_system(n); add_block([blk{i, 2} '/' blk{i, 2}], [n '/' n]); emptySub([n '/' n]); blk{i, 3}([n '/' n]);
        solver(n); save_system(n, fullfile(blocksDir, [n '.slx'])); close_system(n, 0); names{end + 1} = n; %#ok<AGROW>
    end
    % --- plants: name, replace Tires?, replace Bike2DOF?
    pl = {'Plant_VDBTire', true, false, false, false; 'Plant_VDBBody', false, true, false, false; 'Plant_VDBTireBody', true, true, false, false; 'Plant_VDBTireLag', true, false, true, false; 'Plant_VDBTireLagMz', true, false, true, true};
    for i = 1:size(pl, 1)
        if ~isempty(only) && ~any(strcmp(only, pl{i, 1})), continue; end
        n = pickName(plantsDir, pl{i, 1}, overwrite);
        new_system(n); add_block('Plant/Plant', [n '/' n]);
        if pl{i, 2}, emptySub([n '/' n '/Tires']); fillTires([n '/' n '/Tires'], P, pl{i, 4}, tern(pl{i, 5}, trail, [])); end
        if pl{i, 3}, emptySub([n '/' n '/Bike2DOF']); fillBike([n '/' n '/Bike2DOF']); end
        solver(n); save_system(n, fullfile(plantsDir, [n '.slx'])); close_system(n, 0); names{end + 1} = n; %#ok<AGROW>
    end
    close_system('Tires', 0); close_system('Bike2DOF', 0); close_system('Plant', 0);
    fprintf('Built %s\n', strjoin(names, ', '));
end

function n = pickName(dirPath, base, overwrite)
    n = base; k = 0;
    if ~overwrite
        while exist(fullfile(dirPath, [n '.slx']), 'file'), k = k + 1; n = sprintf('%s_%d', base, k); end
    end
    if bdIsLoaded(n), close_system(n, 0); end
end

function solver(mdl)
    set_param(mdl, 'Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6', 'StopTime', '10');
end


function emptySub(sub)
% delete every line and every block of a subsystem except its Inport and Outport blocks
    ln = find_system(sub, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'Line');
    for i = 1:numel(ln), if ishandle(ln(i)), delete_line(ln(i)); end, end
    bl = find_system(sub, 'SearchDepth', 1, 'Type', 'Block');
    for i = 1:numel(bl)
        if strcmp(bl{i}, sub), continue; end
        if ~any(strcmp(get_param(bl{i}, 'BlockType'), {'Inport', 'Outport'})), delete_block(bl{i}); end
    end
end

function fillTires(tires, P, lag, trail)
% interior of the VDB tires: slip angles by Plant (10)-(11), one VDB wheel per axle, forces doubled, T_r by the Plant trail equations;
% lag = true: real lateral relaxation (FyRelFreqLwrLim lowered to 1 rad/s, below v/sigma at 20 km/h = 9 rad/s, so the clamp of 100 Hz never acts in the model range)
% trail = struct of loadTrail (step 2): the aligning moment Mz of the front wheel gives T_r = (e_c F_yf - Mz_axle)/n instead of the Plant trail equation; the trail
%   coefficients of both wheels are the fitted ones and every other Mz term (load, camber, pressure, shift, residual moment, Fx effect) is off. [] = Plant trail equation.
    ov = struct(); if lag, ov.FyRelFreqLwrLim = 1; end
    useMz = ~isempty(trail);
    if useMz, fn = fieldnames(trail); for i = 1:numel(fn), ov.(fn{i}) = trail.(fn{i}); end, end
    add_block('simulink/Sources/Constant', [tires '/in_a'], 'Value', 'l_f');
    add_block('simulink/Sources/Constant', [tires '/in_b'], 'Value', 'l_r');
    add_block('simulink/Sources/Constant', [tires '/in_n'], 'Value', 'n_st');
    fv = [tires '/TireInputs']; add_block('simulink/User-Defined Functions/MATLAB Function', fv);
    setScript(fv, [ ...
        'function [VxF, VyF, VxR, VyR, alF] = f(theta2, beta, gamma, v, a, b, n)' newline ...
        'alF = theta2/n - beta - a*gamma/v;     % Plant (10), delta_f = theta2/n_st' newline ...
        'alR = -beta + b*gamma/v;               % Plant (11)' newline ...
        'VxF = v; VyF = -v*tan(alF);            % VDB alpha = atan(Vy/Vx) = -alpha_f' newline ...
        'VxR = v; VyR = -v*tan(alR);' newline]);
    for nm = {'theta2', 'beta', 'gamma', 'v'}, add_line(tires, portOut(tires, nm{1}, 'Inport'), portIn(fv, nm{1})); end
    add_line(tires, outH([tires '/in_a']), portIn(fv, 'a')); add_line(tires, outH([tires '/in_b']), portIn(fv, 'b')); add_line(tires, outH([tires '/in_n']), portIn(fv, 'n'));
    axle = {'front', 'rear'}; tb = cell(1, 2);
    for q = 1:2
        tb{q} = [tires '/Tire_' axle{q}]; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', tb{q});
        vdb_tire_config(tb{q}, P, axle{q}, 20, ov);
        Re = str2double(get_param(tb{q}, 'UNLOADED_RADIUS'));
        set_param(tb{q}, 'omegao', sprintf('vdb_v0/(0.97*%.6g)', Re));                % starts at the rolling speed of the case (vdb_v0 in the base workspace)
        Fz = tern(q == 1, P.Fzf, P.Fzr) / 2;
        cs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz, 12)};
        for i = 1:size(cs, 1)
            b = sprintf('%s/c%d_%s', tires, q, cs{i, 1}); add_block('simulink/Sources/Constant', b, 'Value', cs{i, 2});
            add_line(tires, outH(b), portIn(tb{q}, cs{i, 1}));
        end
        mg = sprintf('%s/mu_vec%d', tires, q); add_block('simulink/Math Operations/Gain', mg, 'Gain', '[0;0;1;0;zeros(23,1)]', 'Multiplication', 'Matrix(K*u)');   % ScaleFctrs = [1;1;mu;0;ones(23,1)]
        sb = sprintf('%s/sf_base%d', tires, q); add_block('simulink/Sources/Constant', sb, 'Value', '[1;1;0;0;ones(23,1)]');
        sm = sprintf('%s/sf_sum%d', tires, q); add_block('simulink/Math Operations/Add', sm, 'Inputs', '++');
        add_line(tires, portOut(tires, 'mu', 'Inport'), get_param(mg, 'PortHandles').Inport(1));
        add_line(tires, outH(sb), get_param(sm, 'PortHandles').Inport(1)); add_line(tires, outH(mg), get_param(sm, 'PortHandles').Inport(2));
        add_line(tires, outH(sm), portIn(tb{q}, 'ScaleFctrs'));
    end
    add_line(tires, portOut(fv, 'VxF', ''), portIn(tb{1}, 'Vx')); add_line(tires, portOut(fv, 'VyF', ''), portIn(tb{1}, 'Vy'));
    add_line(tires, portOut(fv, 'VxR', ''), portIn(tb{2}, 'Vx')); add_line(tires, portOut(fv, 'VyR', ''), portIn(tb{2}, 'Vy'));
    gF = cell(1, 2); outName = {'F_yf', 'F_yr'};
    for q = 1:2
        gF{q} = sprintf('%s/Gain_F%d', tires, q); add_block('simulink/Math Operations/Gain', gF{q}, 'Gain', '2');
        add_line(tires, portOut(tb{q}, 'Fy', ''), get_param(gF{q}, 'PortHandles').Inport(1));
        add_line(tires, outH(gF{q}), portIn(tires, outName{q}, 'Outport'));
    end
    tr = [tires '/TrCalc']; add_block('simulink/User-Defined Functions/MATLAB Function', tr);
    if useMz
        setScript(tr, [ ...
            'function Tr = f(Fyf, Mzf, ep0, t0, n)' newline ...
            'ec = ep0 - t0;                          % caster, a geometry of the Plant (not in the tire)' newline ...
            'Tr = (ec*Fyf - 2*Mzf)/n;                % Mz of the front wheel x 2 = axle value; Mz is negative for a positive F_yf in the Plant convention' newline]);
        ins = {'ep0', 't0', 'n'}; cv = {'e_p0', 't_0', 'n_st'};
        for i = 1:3, b = sprintf('%s/trc%d', tires, i); add_block('simulink/Sources/Constant', b, 'Value', cv{i}); add_line(tires, outH(b), portIn(tr, ins{i})); end
        add_line(tires, outH(gF{1}), portIn(tr, 'Fyf')); add_line(tires, portOut(tb{1}, 'Mz', ''), portIn(tr, 'Mzf'));
        t = [tires '/Term_alF']; add_block('simulink/Sinks/Terminator', t); add_line(tires, portOut(fv, 'alF', ''), get_param(t, 'PortHandles').Inport(1));
    else
        setScript(tr, [ ...
            'function Tr = f(alF, Fyf, mu, ep0, t0, Ca, Fzf, n)' newline ...
            'ec = ep0 - t0;' newline ...
            'ep = ec + max(0, t0 - sign(alF)*t0*Ca*tan(alF)/(3*mu*Fzf));   % pneumatic trail' newline ...
            'Tr = ep/n*Fyf;' newline]);
        ins = {'ep0', 't0', 'Ca', 'Fzf', 'n'}; cv = {'e_p0', 't_0', 'C_alpha_f', 'F_zf', 'n_st'};
        for i = 1:5, b = sprintf('%s/trc%d', tires, i); add_block('simulink/Sources/Constant', b, 'Value', cv{i}); add_line(tires, outH(b), portIn(tr, ins{i})); end
        add_line(tires, portOut(fv, 'alF', ''), portIn(tr, 'alF')); add_line(tires, outH(gF{1}), portIn(tr, 'Fyf'));
        add_line(tires, portOut(tires, 'mu', 'Inport'), portIn(tr, 'mu'));
    end
    add_line(tires, outH(tr), portIn(tires, 'T_r', 'Outport'));
    for q = 1:2
        ph = get_param(tb{q}, 'PortHandles');
        for kk = 1:numel(ph.Outport)
            if get_param(ph.Outport(kk), 'Line') < 0
                t = sprintf('%s/Term_t%d_%d', tires, q, kk); add_block('simulink/Sinks/Terminator', t); add_line(tires, ph.Outport(kk), get_param(t, 'PortHandles').Inport(1));
            end
        end
    end
end

function fillBike(bike)
% interior of the VDB body, wired as build_vdb_s1.m: xdotin = v; FExt = [0; F_yf + F_yr; 0]; MExt = [0; 0; l_f*F_yf - l_r*F_yr]; WhlAngF = 0;
% beta = ydot/xdot; gamma = r; a_y = Info.BdyFrm.Cg.Acc.ay * 9.80665 (the VDB value is in g)
    body = [bike '/VDBBody'];
    add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', body);
    vdb_body_config(body, struct('m', 'm', 'a', 'l_f', 'b', 'l_r', 'Iz', 'Iz'), 'vdb_v0');
    add_block('simulink/Math Operations/Add', [bike '/Sum_F'], 'Inputs', '++');
    add_line(bike, portOut(bike, 'F_yf', 'Inport'), get_param([bike '/Sum_F'], 'PortHandles').Inport(1));
    add_line(bike, portOut(bike, 'F_yr', 'Inport'), get_param([bike '/Sum_F'], 'PortHandles').Inport(2));
    add_block('simulink/Sources/Constant', [bike '/Zero1'], 'Value', '0'); add_block('simulink/Sources/Constant', [bike '/Zero2'], 'Value', '0');
    add_block('simulink/Signal Routing/Mux', [bike '/Mux_F'], 'Inputs', '3');
    add_line(bike, 'Zero1/1', 'Mux_F/1'); add_line(bike, 'Sum_F/1', 'Mux_F/2'); add_line(bike, 'Zero2/1', 'Mux_F/3');
    add_block('simulink/Math Operations/Gain', [bike '/Gain_a'], 'Gain', 'l_f'); add_block('simulink/Math Operations/Gain', [bike '/Gain_b'], 'Gain', 'l_r');
    add_line(bike, portOut(bike, 'F_yf', 'Inport'), get_param([bike '/Gain_a'], 'PortHandles').Inport(1));
    add_line(bike, portOut(bike, 'F_yr', 'Inport'), get_param([bike '/Gain_b'], 'PortHandles').Inport(1));
    add_block('simulink/Math Operations/Add', [bike '/Sum_M'], 'Inputs', '+-');
    add_line(bike, 'Gain_a/1', 'Sum_M/1'); add_line(bike, 'Gain_b/1', 'Sum_M/2');
    add_block('simulink/Sources/Constant', [bike '/Zero3'], 'Value', '0'); add_block('simulink/Sources/Constant', [bike '/Zero4'], 'Value', '0');
    add_block('simulink/Signal Routing/Mux', [bike '/Mux_M'], 'Inputs', '3');
    add_line(bike, 'Zero3/1', 'Mux_M/1'); add_line(bike, 'Zero4/1', 'Mux_M/2'); add_line(bike, 'Sum_M/1', 'Mux_M/3');
    add_block('simulink/Sources/Constant', [bike '/WhlAng0'], 'Value', '0');
    add_line(bike, get_param([bike '/WhlAng0'], 'PortHandles').Outport(1), portH(body, 'Inport', 'WhlAngF'));
    add_line(bike, get_param([bike '/Mux_F'], 'PortHandles').Outport(1), portH(body, 'Inport', 'FExt'));
    add_line(bike, get_param([bike '/Mux_M'], 'PortHandles').Outport(1), portH(body, 'Inport', 'MExt'));
    add_line(bike, portOut(bike, 'v', 'Inport'), portH(body, 'Inport', 'xdotin'));
    add_block('simulink/Math Operations/Product', [bike '/Div_beta'], 'Inputs', '*/');
    add_line(bike, portH(body, 'Outport', 'ydot'), get_param([bike '/Div_beta'], 'PortHandles').Inport(1));
    add_line(bike, portH(body, 'Outport', 'xdot'), get_param([bike '/Div_beta'], 'PortHandles').Inport(2));
    add_line(bike, get_param([bike '/Div_beta'], 'PortHandles').Outport(1), portIn(bike, 'beta', 'Outport'));
    add_line(bike, portH(body, 'Outport', 'r'), portIn(bike, 'gamma', 'Outport'));
    add_block('simulink/Signal Routing/Bus Selector', [bike '/BusSel']);
    add_line(bike, portH(body, 'Outport', 'Info'), get_param([bike '/BusSel'], 'PortHandles').Inport(1));
    set_param([bike '/BusSel'], 'OutputSignals', 'BdyFrm.Cg.Acc.ay');
    add_block('simulink/Math Operations/Gain', [bike '/Gain_g'], 'Gain', '9.80665');   % standard gravity, the unit of Info.BdyFrm.Cg.Acc.ay (plan 11 K11)
    add_line(bike, get_param([bike '/BusSel'], 'PortHandles').Outport(1), get_param([bike '/Gain_g'], 'PortHandles').Inport(1));
    add_line(bike, get_param([bike '/Gain_g'], 'PortHandles').Outport(1), portIn(bike, 'a_y', 'Outport'));
    for nm = {'psi', 'FzF', 'FzR'}
        t = [bike '/Term_' nm{1}]; add_block('simulink/Sinks/Terminator', t); add_line(bike, portH(body, 'Outport', nm{1}), get_param(t, 'PortHandles').Inport(1));
    end
end

function setScript(blk, txt)
    rt = sfroot; ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk); ch.Script = txt;
end

function h = outH(blk)
    ph = get_param(blk, 'PortHandles'); h = ph.Outport(1);
end

function h = portH(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

function h = portIn(blk, name, type)
% input port of a block by name (argument of a MATLAB Function block, or input port of a wheel block by its Inport block name);
% with type 'Outport': the Inport handle of the Outport block 'name' inside subsystem 'blk' (wired from the inside)
    if nargin < 3, type = ''; end
    ph = get_param(blk, 'PortHandles');
    if strcmp(type, 'Outport')
        b = find_system(blk, 'SearchDepth', 1, 'BlockType', 'Outport', 'Name', name);
        assert(numel(b) == 1, 'output port %s not found in %s', name, blk); h = get_param(b{1}, 'PortHandles').Inport(1); return;
    end
    names = fnNames(blk, 'in');
    if ~isempty(names)
        k = find(strcmp(names, name)); assert(numel(k) == 1, 'input %s not found in %s', name, blk); h = ph.Inport(k); return;
    end
    h = portH(blk, 'Inport', name);
end

function h = portOut(blk, name, type)
% output port of a block by name (MATLAB Function result, wheel output); with type 'Inport': the outgoing handle of the Inport block 'name' inside subsystem 'blk'
    if nargin < 3, type = ''; end
    if strcmp(type, 'Inport')
        b = find_system(blk, 'SearchDepth', 1, 'BlockType', 'Inport', 'Name', name);
        assert(numel(b) == 1, 'input port %s not found in %s', name, blk); h = get_param(b{1}, 'PortHandles').Outport(1); return;
    end
    ph = get_param(blk, 'PortHandles');
    names = fnNames(blk, 'out');
    if ~isempty(names)
        k = find(strcmp(names, name)); assert(numel(k) == 1, 'output %s not found in %s', name, blk); h = ph.Outport(k); return;
    end
    h = portH(blk, 'Outport', name);
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

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end

function trail = loadTrail(blocksDir)
% fitted trail coefficients (fit_vdb_trail.m) and the list of Mz terms switched off, as one struct of mask coefficients; [] when the fit file is missing
    f = fullfile(blocksDir, 'data', 'vdb_trail_fit.json'); trail = [];
    if ~isfile(f), return; end
    J = jsondecode(fileread(f)); trail = struct();
    fn = fieldnames(J.fitted); for i = 1:numel(fn), trail.(fn{i}) = J.fitted.(fn{i}); end
    z = J.zeroed; if ischar(z), z = {z}; end
    for i = 1:numel(z), trail.(z{i}) = 0; end
end
