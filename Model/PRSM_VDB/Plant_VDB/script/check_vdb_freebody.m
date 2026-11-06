function ok = check_vdb_freebody()
%CHECK_VDB_FREEBODY Free-body and fixed-input checks of the configured VDB body and tire blocks (risk R1, plan section 11, step K1c-d).
%   Body alone, velocity mode, external force/moment constant, exact solution known:
%       r(t) = r0 + Mz/Iz t ;  ydot(t) = ydot0 + Fy/m t - xdot (r0 t + Mz/(2 Iz) t^2)   (xdot constant, the speed is an input)
%   Cases: (Fy, Mz) = (0, 0) and (-3000 N, -500 N.m) from (ydot0, r0) = (0, 0), (5, -0.5), (25, -0.5). PASS when max error < 1e-4 of the signal range.
%   Negative control: the aerodynamic tables Cs, Cym, Cpm back to the library defaults (the bug found on 2026-11-06) must give NOT PASS.
%   Tire alone, fixed alpha: Fx < 1 N and |Fy| equal to the Plant Magic Formula within 0.1 % of mu*Fz, at mu 0.8 and 0.3 and three slip angles.
%   Negative control: FNOMIN changed by 20 % must give NOT PASS.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_K1_freebody.txt
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibeom'); load_system('vehdynlibtire');
    fid = fopen(fullfile(outDir, 'Plant_VDB_K1_freebody.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    say('K1c-d free-body and fixed-input checks (%s)\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    ok = true;
    xdot = 16.6667;
    cases = [0 0 0 0; 0 0 5 -0.5; 0 0 25 -0.5; -3000 -500 0 0; -3000 -500 5 -0.5; -3000 -500 25 -0.5];   % Fy, Mz, ydot0, r0
    say('BODY (xdot = %.4f m/s, m = %.0f kg, Iz = %.0f kg m^2)\n', xdot, P.m, P.Iz);
    for neg = [false true]
        worst = 0;
        for i = 1:size(cases, 1)
            e = bodyCase(P, xdot, cases(i, :), neg);
            worst = max(worst, e);
            if ~neg, say('  Fy=%6.0f Mz=%5.0f ydot0=%4.0f r0=%5.2f : max error %.2e of range\n', cases(i, :), e); end
        end
        if ~neg
            c = worst < 1e-4; ok = ok && c; say('  worst %.2e (limit 1e-4) -> %s\n', worst, verdict(c));
        else
            c = worst < 1e-4; ok = ok && ~c;
            say('  negative control (default Cs, Cym, Cpm): worst %.2e -> %s (expected NOT PASS)\n', worst, verdict(c));
        end
    end
    say('\nTIRE (half front axle, Fz = %.1f N, Ca = %.0f N/rad, Vx = 20 m/s)\n', P.Fzf / 2, P.Ca / 2);
    for neg = [false true]
        worst = 0; fxw = 0;
        for mu = [0.8 0.3]
            for vy = [0.5 1.5 3]
                [fy, fx, fyExp] = tireCase(P, 20, vy, mu, neg);
                e = abs(abs(fy) - fyExp) / (mu * P.Fzf / 2); worst = max(worst, e); fxw = max(fxw, abs(fx));
                if ~neg, say('  mu=%.1f Vy=%.1f : Fy %.3f N, expected %.3f N, error %.2e of mu*Fz, Fx %.3f N\n', mu, vy, abs(fy), fyExp, e, fx); end
            end
        end
        c = worst < 1e-3 && fxw < 1;
        if ~neg
            ok = ok && c; say('  worst Fy error %.2e (limit 1e-3), max |Fx| %.3f N (limit 1) -> %s\n', worst, fxw, verdict(c));
        else
            ok = ok && ~c; say('  negative control (FNOMIN x 1.2): worst Fy error %.2e -> %s (expected NOT PASS)\n', worst, verdict(c));
        end
    end
    say('\nK1c-d overall: %s\n', verdict(ok));
    fclose(fid); type(fullfile(outDir, 'Plant_VDB_K1_freebody.txt'));
end

function s = verdict(c)
    if c, s = 'PASS'; else, s = 'NOT PASS'; end
end

function e = bodyCase(P, xdot, cs, neg)
    mdl = 'tmp_k1_fb'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Body']; add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', blk);
    vdb_body_config(blk, struct('m', P.m, 'a', P.a, 'b', P.b, 'Iz', P.Iz), xdot);
    if neg
        set_param(blk, 'Cs', '[0 0.01:0.01:0.3]', 'Cym', '[0 1e-6:0.01:0.3]', 'Cpm', '0.1');
    end
    Fy = cs(1); Mz = cs(2); yd0 = cs(3); r0 = cs(4);
    set_param(blk, 'ydot_o', num2str(yd0), 'r_o', num2str(r0));
    srcs = {'xdotin', num2str(xdot); 'FExt', sprintf('[0;%g;0]', Fy); 'MExt', sprintf('[0;0;%g]', Mz); 'WhlAngF', '0'};
    for i = 1:size(srcs, 1)
        b = [mdl '/s_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    outs = {'ydot', 'r'};
    for i = 1:2
        tw = [mdl '/l_' outs{i}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['fb_' outs{i}], 'SaveFormat', 'Timeseries'); wireOut(blk, outs{i}, tw);
    end
    for nm = {'Info', 'psi', 'xdot', 'FzF', 'FzR'}
        t = [mdl '/T_' nm{1}]; add_block('simulink/Sinks/Terminator', t); wireOut(blk, nm{1}, t);
    end
    set_param(mdl, 'Solver', 'ode45', 'StopTime', '3', 'MaxStep', '0.002', 'RelTol', '1e-8', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear;
    try
        o = sim(Simulink.SimulationInput(mdl));
        t = o.fb_r.Time; r = squeeze(o.fb_r.Data); yd = squeeze(o.fb_ydot.Data);
        rE = r0 + Mz / P.Iz * t;
        ydE = yd0 + Fy / P.m * t - xdot * (r0 * t + Mz / (2 * P.Iz) * t .^ 2);
        e = max([max(abs(r - rE)) / max(1e-3, range(rE) + abs(r0)), max(abs(yd - ydE)) / max(1e-3, range(ydE) + abs(yd0))]);
    catch
        e = Inf;           % the simulation did not finish: counts as failure
    end
    close_system(mdl, 0);
end

function [fy, fx, fyExp] = tireCase(P, vx, vy, mu, neg)
    mdl = 'tmp_k1_ft'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    ov = struct(); if neg, ov.FNOMIN = 1.2 * P.Fzf / 2; end
    info = vdb_tire_config(blk, P, 'front', vx, ov);
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(vx); 'Vy', num2str(vy); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; ...
            'Fext', num2str(info.Fz, 12); 'ScaleFctrs', sprintf('[1;1;%g;0;ones(23,1)]', mu)};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    for nm = {'Fy', 'Fx'}
        tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries'); wireOut(blk, nm{1}, tw);
    end
    for nm = {'Info', 'Mz', 'Mx', 'My', 'Omega', 'Fz'}
        t = [mdl '/T_' nm{1}]; add_block('simulink/Sinks/Terminator', t); wireOut(blk, nm{1}, t);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '2', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    sel = o.Fy.Time > 1.5; fy = mean(o.Fy.Data(sel)); fx = mean(o.Fx.Data(sel));
    % Plant Magic Formula (independent): a = |atan(Vy/Vx)|, B = Ca/(C mu Fz)
    a = abs(atan(vy / vx)); B = info.Ca / (P.C * mu * info.Fz);
    fyExp = mu * info.Fz * sin(P.C * atan(B * a - P.E * (B * a - atan(B * a))));
    close_system(mdl, 0);
end

function map = portMap(blk, type)
    h = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type);
    map = containers.Map();
    for i = 1:numel(h), map(get_param(h{i}, 'Name')) = str2double(get_param(h{i}, 'Port')); end
end

function wire(dst, src, portName)
    m = portMap(dst, 'Inport'); ph = get_param(dst, 'PortHandles');
    if ~isKey(m, portName) || m(portName) > numel(ph.Inport), error('Input %s of %s unavailable. Inputs: %s', portName, dst, strjoin(keys(m), ', ')); end
    add_line(bdroot(dst), get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s. Outputs: %s', portName, src, strjoin(keys(m), ', ')); end
    ph = get_param(src, 'PortHandles');
    add_line(bdroot(src), ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
