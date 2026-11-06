function [R, msg] = run_vdb_body(P, S, sgn, izFactor, solver)
%RUN_VDB_BODY VDB body 3DOF driven by the Plant baseline forces (used by check_vdb_body.m, night step N4); solver: 'ode23t' (default), 'ode45', 'ode15s', 'ode4' (fixed 1 ms).
% VDB body driven by the Plant forces; returns signals on the baseline grid (a_y from the Info bus, BdyFrm.Cg.Acc.ay)
    msg = ''; R = struct();
    mdl = 'tmp_n4_body'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Body']; add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', blk);
    Q = P; Q.Iz = P.Iz * izFactor; vdb_body_config(blk, Q, S.v(1));
    t = S.t; F = sgn * (S.F_yf + S.F_yr); Mz = sgn * (P.a * S.F_yf - P.b * S.F_yr);
    z = zeros(size(t));
    assignin('base', 'n4_v', [t, S.v]); assignin('base', 'n4_F', [t, z, F, z]); assignin('base', 'n4_M', [t, z, z, Mz]);
    ph = get_param(blk, 'PortHandles');
    add_block('simulink/Sources/Constant', [mdl '/s_ang'], 'Value', '0'); add_line(mdl, get_param([mdl '/s_ang'], 'PortHandles').Outport(1), ph.Inport(1));
    vars = {'n4_v', 'n4_F', 'n4_M'};
    for i = 1:3
        b = [mdl '/s' num2str(i)]; add_block('simulink/Sources/From Workspace', b, 'VariableName', vars{i}, 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
        add_line(mdl, get_param(b, 'PortHandles').Outport(1), ph.Inport(i + 1));
    end
    outs = {2, 'xdot'; 5, 'r'};
    for i = 1:2
        tw = [mdl '/lg' num2str(i)]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['n4_' outs{i, 2}], 'SaveFormat', 'Timeseries');
        add_line(mdl, ph.Outport(outs{i, 1}), get_param(tw, 'PortHandles').Inport(1));
    end
    busLog(mdl, ph.Outport(1), {'BdyFrm.Cg.Acc.ay'}, {'n4_ay'});
    set_param(mdl, 'Solver', solver, 'StopTime', num2str(t(end)), 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    if strcmp(solver, 'ode4'), set_param(mdl, 'SolverType', 'Fixed-step', 'FixedStep', '0.001'); else, set_param(mdl, 'MaxStep', '0.002'); end
    try
        Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    catch ME
        msg = strtrim(ME.message(1:min(160, numel(ME.message)))); close_system(mdl, 0); return;   % reported in the result file, never hidden
    end
    R.t = t; R.v = interp1(o.n4_xdot.Time, squeeze(o.n4_xdot.Data), t); R.gamma = interp1(o.n4_r.Time, squeeze(o.n4_r.Data), t);
    R.a_y = 9.80665 * interp1(o.n4_ay.Time, squeeze(o.n4_ay.Data), t);     % BdyFrm.Cg.Acc.ay is in g (found in N4: steady cornering gave 0.153 for r*v = 1.5 m/s^2)
    close_system(mdl, 0);
end

function busLog(mdl, srcPort, sigs, vars)
% log only the named signals of the Info bus (logging the whole bus used 11 GB in a 100 s run)
    bs = [mdl '/bus_sel']; add_block('simulink/Signal Routing/Bus Selector', bs);
    add_line(mdl, srcPort, get_param(bs, 'PortHandles').Inport(1));
    set_param(bs, 'OutputSignals', strjoin(sigs, ','));
    ph = get_param(bs, 'PortHandles');
    for i = 1:numel(sigs)
        tw = [mdl '/buslog' num2str(i)]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', vars{i}, 'SaveFormat', 'Timeseries');
        add_line(mdl, ph.Outport(i), get_param(tw, 'PortHandles').Inport(1));
    end
end
