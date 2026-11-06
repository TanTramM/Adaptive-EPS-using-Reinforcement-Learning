function ok = check_vdb_n1()
%CHECK_VDB_N1 Self-check of night step N1 (config of the tire and body blocks). Writes Result/PRSM/Plant_VDB/Plant_VDB_N1_config.txt.
%   Criteria (set before running, plan section 10.2): free-rolling tire at alpha = 0 gives |Fy| < 1 % of the Fy peak; |Fx| < 1 % of Fz;
%   the body in velocity mode follows the speed input (error < 0.5 km/h); Fy peak = mu*Fz within 1 % (mu = 0.8). Negative control: PDY1 = 1.2 must give NOT PASS
%   on the peak test (PHY1 and PVY1 have no effect in this block, so they cannot be used as the negative control of the alpha = 0 test).
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    fid = fopen(fullfile(outDir, 'Plant_VDB_N1_config.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    load_system('vehdynlibeom'); load_system('vehdynlibtire');
    ok = true;
    say('N1 check of vdb_tire_config.m and vdb_body_config.m (%s)\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));

    v0 = 20;
    for axle = {'front', 'rear'}
        for neg = [false true]
            mdl = 'tmp_n1_tire';
            if bdIsLoaded(mdl), close_system(mdl, 0); end
            new_system(mdl);
            blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
            if neg, ov = struct('PDY1', 1.2); else, ov = struct(); end   % deliberate error for the negative control
            info = vdb_tire_config(blk, P, axle{1}, v0, ov);
            srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(v0); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; ...
                    'Fext', num2str(info.Fz); 'ScaleFctrs', '[1;1;0.8;0;ones(23,1)]'};
            for i = 1:size(srcs, 1)
                b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2});
                wire(blk, b, srcs{i, 1});
            end
            add_block('simulink/Sources/Ramp', [mdl '/src_Vy'], 'Slope', '1', 'InitialOutput', '-6');   % Vy from -6 to +6 m/s over 12 s
            wire(blk, [mdl '/src_Vy'], 'Vy');
            for nm = {'Fy', 'Fx'}
                tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries');
                wireOut(blk, nm{1}, tw);
            end
            set_param(mdl, 'Solver', 'ode23t', 'StopTime', '12', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
            Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
            t = o.Fy.Time; Fy = o.Fy.Data(:); Fx = o.Fx.Data(:);
            peak = max(abs(Fy));
            % Fy at alpha = 0 from a separate run at constant Vy = 0.002 m/s, alpha = 1e-4 rad (a sweep is biased by the tire lag), last 1 s of 3 s
            set_param([mdl '/src_Vy'], 'Slope', '0', 'InitialOutput', '0.002'); set_param(mdl, 'StopTime', '3');
            Simulink.sdi.clear; o0 = sim(Simulink.SimulationInput(mdl));
            fy0 = mean(o0.Fy.Data(o0.Fy.Time > 2));
            fxmax = max(abs(o0.Fx.Data(o0.Fx.Time > 2)));     % free rolling at Vy = 0: Fx must settle to ~0 (start-up transient excluded)
            c1 = abs(fy0) < 0.01 * peak;  c2 = fxmax < 0.01 * info.Fz;
            c4 = abs(peak - 0.8 * info.Fz) < 0.01 * 0.8 * info.Fz;      % Fy peak = mu*Fz with mu = 0.8 given through the scale factor
            if ~neg
                say('%s half axle: Fz = %.1f N, Ca = %.0f N/rad; Fy(alpha~0) = %+.2f N (%.3f %% of peak %.0f N), max|Fx| over last 1 s = %.1f N (%.2f %% of Fz), peak/(0.8 Fz) = %.4f -> %s\n', ...
                    axle{1}, info.Fz, info.Ca, fy0, 100 * abs(fy0) / peak, peak, fxmax, 100 * fxmax / info.Fz, peak / (0.8 * info.Fz), verdict(c1 && c2 && c4));
                ok = ok && c1 && c2 && c4;
            else
                say('  negative control (PDY1 = 1.2, %s): peak/(0.8 Fz) = %.4f -> %s (expected NOT PASS)\n', axle{1}, peak / (0.8 * info.Fz), verdict(c4));
                ok = ok && ~c4;
            end
            close_system(mdl, 0);
        end
    end

    % body: velocity input followed? ramp 90 -> 45 km/h in 13 s with a small lateral force
    mdl = 'tmp_n1_body'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Body']; add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', blk);
    vdb_body_config(blk, P, 90 / 3.6);
    add_block('simulink/Sources/Constant', [mdl '/s1'], 'Value', '0'); wire(blk, [mdl '/s1'], 'WhlAngF');
    add_block('simulink/Sources/Ramp', [mdl '/s2'], 'Slope', num2str(-(45 / 3.6) / 13), 'InitialOutput', num2str(90 / 3.6)); wire(blk, [mdl '/s2'], 'xdotin');
    add_block('simulink/Sources/Constant', [mdl '/s3'], 'Value', '[0;0;0]'); wire(blk, [mdl '/s3'], 'FExt');
    add_block('simulink/Sources/Constant', [mdl '/s4'], 'Value', '[0;0;0]'); wire(blk, [mdl '/s4'], 'MExt');
    for nm = {'xdot', 'r'}
        tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries'); wireOut(blk, nm{1}, tw);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '13', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    vref = 90 / 3.6 - (45 / 3.6) / 13 * o.xdot.Time;  err = max(abs(o.xdot.Data(:) - vref)) * 3.6;
    c3 = err < 0.5;  ok = ok && c3;
    say('\nbody: 90 -> 45 km/h in 13 s, max |xdot - input| = %.4f km/h (limit 0.5) -> %s; final xdot = %.3f m/s (input %.3f)\n', err, verdict(c3), o.xdot.Data(end), 45 / 3.6);
    close_system(mdl, 0);
    cFb = check_vdb_freebody();     % K1c-d (plan section 11): free-body and fixed-input checks, repeated whenever the configuration may have changed
    say('\nfree-body and fixed-input checks (check_vdb_freebody.m, Plant_VDB_K1_freebody.txt): %s\n', verdict(cFb)); ok = ok && cFb;
    say('\nN1 overall: %s\n', verdict(ok));
    fclose(fid); type(fullfile(outDir, 'Plant_VDB_N1_config.txt'));
end

function s = verdict(c)
    if c, s = 'PASS'; else, s = 'NOT PASS'; end
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
