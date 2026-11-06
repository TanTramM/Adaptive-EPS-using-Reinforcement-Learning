function check_vdb_signs()
%CHECK_VDB_SIGNS Item R8 of Documents/Shared/KeHoach_Plant_VDB.txt: sign and frame table between the Plant and the VDB blocks, found by
%   simulation, not by reasoning. Writes Result/PRSM/Plant_VDB/Plant_VDB_R8_signs.txt. Temporary models only (nothing is saved in Model/).
%   Q1 sign of slip angle, Fy, Mz of the VDB tire against the Plant (small left steer, then right steer).
%   Q2 frame of Vx, Vy given to the tire: rotation of the front-axle velocity by the steer angle, two candidate directions, compared with
%      the Plant slip angle alpha_f = delta_f - x3 - l_f*x4/v (PT(6)).
%   Q3 sign and frame of the force and moment given to the 3DOF body through FExt and MExt (body with Cy = 0, velocity mode).
%   Q4 sign of T_r = (e_c*Fy - Mz)/n_st built from the VDB tire, against the Plant T_r (PT(10), (13), (14), caster + shrinking trail).
%   The tire used here is the library preset, so the MAGNITUDES of Fy and T_r are not expected to match the Plant (that is test T1 and T3);
%   only signs, frames and orders of magnitude are judged here.
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    raw = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'params.json')));
    P = struct('m', raw.cum2.m.value, 'a', raw.cum2.l_f.value, 'b', raw.cum2.l_r.value, 'g', raw.cum2.g.value, 'Iz', raw.cum3.Iz.value, ...
        'Ca', raw.cum2.C_alpha_f.value, 'C', raw.cum2.C.value, 'E', raw.cum2.E.value, 'n', raw.cum2.n_st.value, ...
        'ep0', raw.cum2.e_p0.value, 't0', raw.cum2.t_0.value);
    P.ec = P.ep0 - P.t0;  P.Fzf = P.m * P.g * P.b / (P.a + P.b);
    fid = fopen(fullfile(outDir, 'Plant_VDB_R8_signs.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    load_system('vehdynlibeom'); load_system('vehdynlibtire');

    %% Q1: VDB tire, free-rolling, one front wheel, small slip angles of both signs
    mdl = 'tmp_r8_tire'; buildTire(mdl, P);
    vy = [-1 -0.5 0.5 1];                                   % tire-frame lateral velocity, m/s (Vx = 20 m/s) -> alpha = atan(Vy/Vx)
    res = zeros(numel(vy), 4);                              % alpha, Fy, Mz, Fx
    for i = 1:numel(vy)
        Simulink.sdi.clear;
        si = Simulink.SimulationInput(mdl); si = si.setVariable('Vy_set', vy(i), 'Workspace', mdl);
        o = sim(si); k = o.t.Time > 1.5;
        res(i, :) = [atan2(vy(i), 20), mean(o.Fy.Data(k)), mean(o.Mz.Data(k)), mean(o.Fx.Data(k))];
    end
    close_system(mdl, 0);
    say('Q1  VDB tire (Combined Slip Wheel 2DOF, preset 205/60R15, ply steer and turn slip off, free rolling), one front wheel, Fz = %.0f N, Vx = 20 m/s\n', P.Fzf/2);
    say('    Vy_tire (m/s)   alpha=atan(Vy/Vx) (rad)   Fy (N)    Mz (N.m)   Fx (N)\n');
    for i = 1:numel(vy), say('    %+6.2f          %+8.4f                %+8.1f  %+8.2f   %+7.1f\n', vy(i), res(i,1), res(i,2), res(i,3), res(i,4)); end
    odd = max(abs(res(1,2) + res(4,2)), abs(res(2,2) + res(3,2))) / max(abs(res(:,2)));
    say('    odd symmetry of Fy (0 = perfect): %.3f; Fy and alpha have %s sign; Mz and alpha have %s sign\n\n', odd, ...
        tern(all(sign(res(:,2)) == -sign(res(:,1))), 'OPPOSITE', 'the same'), tern(all(sign(res(:,3)) == sign(res(:,1))), 'the SAME', 'opposite'));
    say('    Plant: alpha_f > 0 for a left steer and F_yf > 0 (left). Therefore the Plant alpha_f = -alpha_VDB, and Fy_VDB (tire frame) has the sign of F_yf.\n');
    say('    Mz_VDB has the sign of alpha_VDB, so Mz_VDB < 0 when Fy > 0: the trail t = -Mz/Fy is positive. Check: t at small slip below.\n');
    kk = [2 3]; tr = -res(kk, 3) ./ res(kk, 2);
    say('    trail t = -Mz/Fy at alpha = %+.3f, %+.3f rad : %.4f, %.4f m (Plant pneumatic trail t_0 = %.3f m, caster e_c = %.3f m)\n\n', res(kk(1),1), res(kk(2),1), tr(1), tr(2), P.t0, P.ec);

    %% Q2: frames. Front-axle velocity in the vehicle frame (x forward, y left) rotated into the wheel frame by the steer angle delta.
    v = 20; ydot = 0.3; r = 0.1; delta = 0.03;               % an arbitrary but concrete cornering state
    Vxv = v; Vyv = ydot + P.a * r;                            % front-axle velocity, vehicle frame
    al_plant = delta - ydot / v - P.a * r / v;                % PT(6) with x3 = ydot/v (small angle), x4 = r
    optA = [cos(delta) sin(delta); -sin(delta) cos(delta)] * [Vxv; Vyv];      % rotate by +delta (frame turned left)
    optB = [cos(delta) -sin(delta); sin(delta) cos(delta)] * [Vxv; Vyv];      % rotate by -delta
    alA = atan2(optA(2), optA(1)); alB = atan2(optB(2), optB(1));
    alBody = atan2(Vyv, Vxv) - delta;                          % definition printed in the VDB 3DOF documentation: atan((ydot+a*r)/xdot) - delta
    say('Q2  frame of Vx, Vy given to the tire (state: v=%g m/s, ydot=%g m/s, r=%g rad/s, delta_f=%g rad)\n', v, ydot, r, delta);
    say('    Plant alpha_f (PT(6))                              : %+.5f rad\n', al_plant);
    say('    rotation by +delta, alpha = atan(Vy_w/Vx_w)        : %+.5f rad  (= -alpha_f %s)\n', alA, tern(abs(alA + al_plant) < 2e-3, 'YES', 'no'));
    say('    rotation by -delta, alpha = atan(Vy_w/Vx_w)        : %+.5f rad  (= -alpha_f %s)\n', alB, tern(abs(alB + al_plant) < 2e-3, 'YES', 'no'));
    say('    VDB body definition atan(Vyv/Vxv) - delta          : %+.5f rad\n', alBody);
    say('    -> use the rotation by +delta (Vx_w = Vx cos(d) + Vy sin(d), Vy_w = -Vx sin(d) + Vy cos(d)); then alpha_VDB = -alpha_f(Plant).\n');
    say('       The small residual against -alpha_f comes from atan versus the small-angle form of PT(6).\n\n');

    %% Q3: external force and moment on the 3DOF body (Cy = 0, velocity mode)
    mdl = 'tmp_r8_body'; buildBody(mdl, P);
    Fy = 1000;                                                 % N, lateral force at the CG, positive = vehicle y axis (left)
    Mz = P.a * Fy;                                             % N.m, moment of the same force applied at the front axle
    cases = {[0 Fy 0], [0 0 0]; [0 0 0], [0 0 Mz]; [0 Fy 0], [0 0 Mz]};
    names = {'Fy at CG only', 'Mz only', 'Fy and Mz = a*Fy (a front-axle force)'};
    say('Q3  body 3DOF, Cy = 0, velocity mode (v = 20 m/s, delta = 0), forces through FExt and MExt (vehicle frame), 0.5 s\n');
    for i = 1:size(cases, 1)
        Simulink.sdi.clear;
        si = Simulink.SimulationInput(mdl); si = si.setVariable('FExt_set', cases{i,1}(:), 'Workspace', mdl); si = si.setVariable('MExt_set', cases{i,2}(:), 'Workspace', mdl);
        o = sim(si);
        T = o.ydot.Time(end); Fyc = cases{i,1}(2); Mzc = cases{i,2}(3);
        % Plant equations with constant external force and moment, v = 20 m/s constant: PT(4) r = Mz/Iz*t; PT(3) in the body frame ydot' = Fy/m - v*r
        ref_r = Mzc / P.Iz * T;  ref_y = Fyc / P.m * T - 20 * (Mzc / P.Iz) * T^2 / 2;
        say('    %-40s ydot(%.1f s) = %+8.4f (Plant %+8.4f m/s)   r = %+8.4f (Plant %+8.4f rad/s)\n', names{i}, T, o.ydot.Data(end), ref_y, o.r.Data(end), ref_r);
    end
    close_system(mdl, 0);
    say('    Plant reference: PT(3) in the body frame ydot'' = F/m - v*r (the same centripetal term as dx3/dt = F/(m*v) - x4), PT(4) Iz*dr/dt = l_f*Fyf - l_r*Fyr; a_y = ydot'' + v*r then equals F/m (PT(15)) by construction.\n');
    say('    Same sign and size => FExt (y axis, left) and MExt (z axis, counter-clockwise) match the Plant, the moment about the CG being added by us.\n\n');

    %% Q4: T_r from the VDB tire, one axle = two wheels with half load each
    say('Q4  T_r = (e_c*Fy - Mz)/n_st with the axle forces = 2 x one wheel (tire frame, small steer so cos(delta) = 1), e_c = %.3f m, n_st = %g\n', P.ec, P.n);
    for k = 1:2
        idx = 1 + k;                                           % cases 2, 3: Vy = -0.5, +0.5
        a_vdb = res(idx, 1); a_pl = -a_vdb;                    % Plant alpha_f = -alpha_VDB
        Fy_ax = 2 * res(idx, 2); Mz_ax = 2 * res(idx, 3);
        Tr_vdb = (P.ec * Fy_ax - Mz_ax) / P.n;
        D = 0.8 * P.Fzf; B = P.Ca / (P.C * D);
        Fy_pl = D * sin(P.C * atan(B * a_pl - P.E * (B * a_pl - atan(B * a_pl))));
        ep = P.ec + max(0, P.t0 - sign(a_pl) * P.t0 * P.Ca * tan(a_pl) / (3 * 0.8 * P.Fzf));
        Tr_pl = ep / P.n * Fy_pl;
        say('    Plant alpha_f %+.4f rad (mu 0.8): F_yf %+8.1f N, T_r %+7.3f N.m | VDB: Fy_axle %+8.1f N, Mz_axle %+8.1f N.m, T_r %+7.3f N.m  (same sign: %s)\n', ...
            a_pl, Fy_pl, Tr_pl, Fy_ax, Mz_ax, Tr_vdb, tern(sign(Tr_vdb) == sign(Tr_pl), 'YES', 'NO'));
    end
    say('    A positive T_r must oppose a positive theta2 (Plant PT(2): dx2/dt = (T_a - T_r + T_s - ...)/J_col), i.e. the same sign as F_yf.\n\n');

    say('Table to carry into Plant_VDB (to be confirmed by the results above):\n');
    say('  alpha_f(Plant) = -atan(Vy_w/Vx_w);  Vx_w, Vy_w = front-axle velocity rotated by +delta_f;  Fy to the body = Fy_w (small delta) with the sign printed in Q1;\n');
    say('  FExt = [Fx Fy 0], MExt = [0 0 Mz] in the vehicle frame, Mz = a*Fy_front - b*Fy_rear;  T_r = (e_c*Fy_axle - Mz_axle)/n_st.\n');
    fclose(fid);
    type(fullfile(outDir, 'Plant_VDB_R8_signs.txt'));
end

function buildTire(mdl, P)
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    tire = [mdl '/Tire'];
    add_block('vehdynlibtire/Combined Slip Wheel 2DOF', tire);
    set_param(tire, 'tireType', 'Light passenger car 205/60R15');
    set_param(tire, 'vertType', 'None');
    set_param(tire, 'plySteer', 'off'); set_param(tire, 'turnslip', 'off');
    Re = str2double(get_param(tire, 'UNLOADED_RADIUS'));
    set_param(tire, 'omegao', num2str(20 / (0.97 * Re), 12));   % start spinning at the rolling speed: no start-up slip transient
    hws = get_param(mdl, 'ModelWorkspace');
    assignin(hws, 'Vy_set', 0); assignin(hws, 'Fz_static', P.Fzf / 2);
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', '20'; 'Vy', 'Vy_set'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; ...
            'Fext', 'Fz_static'; 'ScaleFctrs', '[1;1;1;0;ones(23,1)]'};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i,1}];
        add_block('simulink/Sources/Constant', b, 'Value', srcs{i,2});
        wire(mdl, b, tire, srcs{i,1}, true);
    end
    for nm = {'Fy', 'Mz', 'Fx'}
        tw = [mdl '/log_' nm{1}];
        add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries');
        wireOut(mdl, tire, nm{1}, tw);
    end
    add_block('simulink/Sources/Clock', [mdl '/clk']); add_block('simulink/Sinks/To Workspace', [mdl '/log_t'], 'VariableName', 't', 'SaveFormat', 'Timeseries');
    add_line(mdl, 'clk/1', 'log_t/1');
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '2', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
end

function buildBody(mdl, P)
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    body = [mdl '/Body'];
    add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', body);
    for nm = {'m', P.m; 'a', P.a; 'b', P.b; 'Izz', P.Iz; 'Cy_f', 0; 'Cy_r', 0}'
        set_param(body, nm{1}, num2str(nm{2}, 12));
    end
    set_param(body, 'sigmaMode', 'off'); set_param(body, 'extFMode', 'on'); set_param(body, 'extMMode', 'on');
    hws = get_param(mdl, 'ModelWorkspace');
    assignin(hws, 'FExt_set', [0; 0; 0]); assignin(hws, 'MExt_set', [0; 0; 0]);
    srcs = {'WhlAngF', '0'; 'xdotin', '20'; 'FExt', 'FExt_set'; 'MExt', 'MExt_set'};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i,1}];
        add_block('simulink/Sources/Constant', b, 'Value', srcs{i,2});
        wire(mdl, b, body, srcs{i,1});
    end
    for nm = {'ydot', 'r'}
        tw = [mdl '/log_' nm{1}];
        add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries');
        wireOut(mdl, body, nm{1}, tw);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '0.5', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end

function map = portMap(blk, type)
    h = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type);
    map = containers.Map();
    for i = 1:numel(h), map(get_param(h{i}, 'Name')) = str2double(get_param(h{i}, 'Port')); end
end

function wire(mdl, src, dst, portName, optional)
    if nargin < 5, optional = false; end
    m = portMap(dst, 'Inport');
    ph = get_param(dst, 'PortHandles');
    if ~isKey(m, portName) || m(portName) > numel(ph.Inport)
        if optional, return; end
        error('Input %s of %s is not available. Inputs: %s', portName, dst, strjoin(keys(m), ', '));
    end
    add_line(mdl, get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(mdl, src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s. Outputs: %s', portName, src, strjoin(keys(m), ', ')); end
    ph = get_param(src, 'PortHandles');
    add_line(mdl, ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
