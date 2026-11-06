function check_vdb_bodystate(tEnd, lvl, aero)
%CHECK_VDB_BODYSTATE Log the states of the VDB body inside PlantVDBS1 on the SLIP baseline and print them (plan 10.10 step 2; plan section 11, step K8).
%   check_vdb_bodystate(tEnd, lvl, aero)
%   tEnd : stop time in s (default 69.39);  lvl : T_a level 0 or 2 (default 0)
%   aero : 'off'     (default) the configuration of vdb_body_config.m (Cs, Cym, Cpm = 0): the body must NOT diverge;
%          'default' puts the library default aerodynamic tables back (Cs, Cym, Cpm), which reproduces the 2026-11-06 failure: ydot about 27 m/s and
%                    r about -1.66 rad/s at 69.39 s (plan 10.10 step 2) and the solver stops near 69.4 s.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_K8_bodystate_<aero>.txt
    if nargin < 1, tEnd = 69.39; end
    if nargin < 2, lvl = 0; end
    if nargin < 3, aero = 'off'; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    fid = fopen(fullfile(outDir, ['Plant_VDB_K8_bodystate_' aero '.txt']), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    load_plant; load_system('vehdynlibeom');
    S = load(fullfile(outDir, 'baseline', sprintf('Plant_SLIP_Ta%d.mat', lvl)));
    t = S.t; k = t <= tEnd; t = t(k);
    assignin('base', 'vdb_v0', S.v(1));
    mdl = 'tmp_bodystate'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(modelDir, 'VDB', 'Archive', 'PlantVDBS1.slx')); new_system(mdl);
    add_block('PlantVDBS1/Plant', [mdl '/DUT']); close_system('PlantVDBS1', 0);
    dut = [mdl '/DUT']; vars = {'theta1', 'T_a', 'v', 'mu'};
    if strcmp(aero, 'default')
        set_param([dut '/VDBBody'], 'Cs', '[0 0.01:0.01:0.3]', 'Cym', '[0 1e-6:0.01:0.3]', 'Cpm', '0.1');   % library defaults (the bug)
    end
    for i = 1:4
        assignin('base', ['bs_' vars{i}], [t, S.(vars{i})(k)]);
        b = [mdl '/src_' vars{i}]; add_block('simulink/Sources/From Workspace', b, 'VariableName', ['bs_' vars{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
        ph = get_param(dut, 'PortHandles'); nb = find_system(dut, 'SearchDepth', 1, 'BlockType', 'Inport', 'Name', vars{i});
        add_line(mdl, get_param(b, 'PortHandles').Outport(1), ph.Inport(str2double(get_param(nb{1}, 'Port'))));
    end
    ph = get_param(dut, 'PortHandles'); nb = find_system(dut, 'SearchDepth', 1, 'BlockType', 'Outport', 'Name', 'gamma');
    tw = [mdl '/log_g']; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', 'bs_gamma_out', 'SaveFormat', 'Timeseries');
    add_line(mdl, ph.Outport(str2double(get_param(nb{1}, 'Port'))), get_param(tw, 'PortHandles').Inport(1));
    set_param(mdl, 'Solver', 'VariableStepAuto', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'RelTol', '1e-6', 'SaveState', 'on', 'StateSaveName', 'xout', ...
        'SaveFormat', 'Dataset', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    say('K8 body states, SLIP T_a level %d, aero tables = %s, stop %.2f s (%s)\n', lvl, aero, t(end), datestr(now, 'yyyy-mm-dd HH:MM'));
    Simulink.sdi.clear; o = [];
    try
        o = sim(Simulink.SimulationInput(mdl));
        say('RAN to %g s without a solver error\n', t(end));
    catch ME
        say('SOLVER ERROR: %s\n', strtok(ME.message, newline));
    end
    if ~isempty(o)
        x = o.xout;
        for i = 1:x.numElements
            e = x{i}; v = e.Values; dv = squeeze(v.Data);
            try, bp = e.BlockPath; blkName = bp.convertToCell{end}; catch, blkName = '?'; end %#ok<NASGU>
            if contains(blkName, 'xdot ext/Integrator')       % body state [x, ydot, psi, r, ...] of the VDB body
                for tq = [0.5 30 60 62 64 66 69]
                    j = find(v.Time >= tq, 1); if isempty(j), continue; end
                    say('  t=%.2f: body integrator state %s\n', v.Time(j), mat2str(dv(j, :), 6));
                end
                say('  last: t=%.2f: %s   (ydot = element 2, r = element 4)\n', v.Time(end), mat2str(dv(end, :), 6));
            end
        end
    end
    fclose(fid); type(fullfile(outDir, ['Plant_VDB_K8_bodystate_' aero '.txt']));
    close_system(mdl, 0);
end
