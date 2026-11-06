function audit_vdb_params(kinds)
%AUDIT_VDB_PARAMS Inventory and perturbation test of every mask parameter of the VDB body and tire blocks (risk R1, plan section 11, step K1a-b).
%   audit_vdb_params()            both blocks;  audit_vdb_params({'body'}) or ({'tire'}) one block.
%   Group of each parameter:
%     SET        named in vdb_body_config.m or vdb_tire_config.m (set on purpose, not perturbed);
%     NO_EFFECT  not set by the configs and changing it (numbers: x2 + 1, flags and enums: another value) moves no output by more than 1e-9 (relative);
%     EFFECT     not set by the configs and changing it moves an output: this is the group that must be empty (a default that silently acts);
%     SKIP       read-only, not a number or an enum, or could not be changed (reason in column note);
%     SIMFAIL    the perturbed model did not run (reason in column note; counted as EFFECT-unknown, looked at by hand).
%   Each perturbation rebuilds the block from scratch so that mask side effects of one change cannot leak into the next one.
%   Results: Result/PRSM/Plant_VDB/Plant_VDB_K1_audit_<kind>.csv (written after every parameter, resumable: parameters already in the file are skipped).
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    if nargin < 1, kinds = {'body', 'tire'}; end
    load_system('vehdynlibeom'); load_system('vehdynlibtire');
    cfgText = [fileread(fullfile(scriptDir, 'vdb_body_config.m')) fileread(fullfile(scriptDir, 'vdb_tire_config.m'))];
    for ik = 1:numel(kinds)
        kind = kinds{ik};
        csvFile = fullfile(outDir, ['Plant_VDB_K1_audit_' kind '.csv']);
        done = {};
        if exist(csvFile, 'file')
            T = readtable(csvFile, 'TextType', 'string'); done = cellstr(T.name);
        else
            fid = fopen(csvFile, 'w'); fprintf(fid, 'name,type,default,configured,group,effect,note\n'); fclose(fid);
        end
        [mdl, blk] = buildOne(kind, P, struct());
        dpf = get_param(blk, 'DialogParameters'); names = fieldnames(dpf);
        % default values: a fresh block (not configured)
        mdl0 = 'tmp_k1_default'; if bdIsLoaded(mdl0), close_system(mdl0, 0); end
        new_system(mdl0); blk0 = [mdl0 '/Blk']; add_block(libBlock(kind), blk0);
        base = runScenario(mdl, kind);
        close_system(mdl, 0);
        fprintf('[%s] %d parameters, baseline signals: %d samples\n', kind, numel(names), numel(base));
        for i = 1:numel(names)
            nm = names{i};
            if any(strcmp(done, nm)), continue; end
            info = dpf.(nm); typ = info.Type;
            defv = safeGet(blk0, nm);
            [mdl, blk] = buildOne(kind, P, struct());
            curv = safeGet(blk, nm);
            grp = ''; eff = NaN; note = '';
            if ~isempty(regexp(cfgText, ['''' nm ''''], 'once'))
                grp = 'SET';
            elseif any(strcmp(info.Attributes, 'read-only'))
                grp = 'SKIP'; note = 'read-only';
            else
                [newv, why] = perturbValue(info, curv);
                if isempty(newv)
                    grp = 'SKIP'; note = why;
                else
                    try
                        try
                            set_param(blk, nm, newv);
                            y = runScenario(mdl, kind);
                        catch
                            % the x2 + 1 value may be outside the allowed range (e.g. mu_static must stay above mu_kinetic): retry with a 10 % change
                            if ~strcmp(info.Type, 'string'), rethrow(lasterror); end %#ok<LERR>
                            close_system(mdl, 0); [mdl, blk] = buildOne(kind, P, struct());
                            v10 = evalin('base', curv); newv = mat2str(1.1 * v10 + (v10 == 0) * 0.01, 12);
                            set_param(blk, nm, newv);
                            y = runScenario(mdl, kind);
                        end
                        if numel(y) ~= numel(base) || any(~isfinite(y))
                            grp = 'SIMFAIL'; note = 'output size changed or not finite';
                        else
                            eff = max(abs(y - base)) / (max(abs(base)) + eps);
                            if eff > 1e-9, grp = 'EFFECT'; else, grp = 'NO_EFFECT'; end
                            note = ['set to ' newv];
                            if eff > 1e-9, note = [note '; moves ' movedSignals(y, base, kind)]; end
                        end
                    catch err
                        grp = 'SIMFAIL'; note = strrep(strtok(err.message, newline), ',', ';');
                    end
                end
            end
            if bdIsLoaded(mdl), close_system(mdl, 0); end
            fid = fopen(csvFile, 'a');
            fprintf(fid, '%s,%s,"%s","%s",%s,%.3g,"%s"\n', nm, typ, clip(defv), clip(curv), grp, eff, clip(note, 200));
            fclose(fid);
            fprintf('  %-14s %-9s eff=%.3g %s\n', nm, grp, eff, note);
        end
        close_system(mdl0, 0);
    end
    for ik = 1:numel(kinds)
        T = readtable(fullfile(outDir, ['Plant_VDB_K1_audit_' kinds{ik} '.csv']), 'TextType', 'string');
        g = unique(T.group);
        fprintf('[%s] ', kinds{ik}); for j = 1:numel(g), fprintf('%s=%d  ', g(j), sum(T.group == g(j))); end, fprintf('\n');
    end
end

function s = movedSignals(y, base, kind)
    if strcmp(kind, 'body'), outs = {'xdot', 'ydot', 'psi', 'r', 'FzF', 'FzR'}; else, outs = {'Fy', 'Fx', 'Mz', 'Mx', 'My', 'Omega'}; end
    n = numel(base) / numel(outs) / (1 + strcmp(kind, 'tire')); s = '';
    for k = 1:(1 + strcmp(kind, 'tire'))
        for j = 1:numel(outs)
            ix = ((k - 1) * numel(outs) + (j - 1)) * n + (1:n);
            if max(abs(y(ix) - base(ix))) / (max(abs(base(ix))) + eps) > 1e-9, s = [s outs{j} ' ']; end %#ok<AGROW>
        end
    end
    s = strtrim(strjoin(unique(strsplit(s)), ' '));
    if strcmp(kind, 'tire')      % size of the change of the two signals the Plant_VDB uses (Fy, Mz), relative to the signal's own largest value
        n = numel(base) / numel(outs) / 2; d = zeros(1, 2);
        for k = 1:2
            for jj = [1 3]
                ix = ((k - 1) * numel(outs) + (jj - 1)) * n + (1:n);
                d(jj == [1 3]) = max(d(jj == [1 3]), max(abs(y(ix) - base(ix))) / (max(abs(base(ix))) + eps));
            end
        end
        s = sprintf('%s; rel. change Fy %.1e Mz %.1e', s, d(1), d(2));
    end
end

function lib = libBlock(kind)
    if strcmp(kind, 'body'), lib = 'vehdynlibeom/Vehicle Body 3DOF Single Track'; else, lib = 'vehdynlibtire/Combined Slip Wheel 2DOF'; end
end

function s = clip(s, nmax)
    if nargin < 2, nmax = 70; end
    s = char(string(s)); s = strrep(s, '"', ''''); s = strrep(s, newline, ' ');
    if numel(s) > nmax, s = [s(1:nmax - 3) '...']; end
end

function v = safeGet(blk, nm)
    try, v = get_param(blk, nm); catch, v = '<unreadable>'; end
    if ~ischar(v), v = '<non-text>'; end
end

function [newv, why] = perturbValue(info, curv)
    newv = ''; why = '';
    switch info.Type
        case 'enum'
            opts = info.Enum; opts = opts(~strcmp(opts, curv));
            if isempty(opts), why = 'single enum choice'; else, newv = opts{1}; end
        case 'boolean'
            if strcmp(curv, 'on'), newv = 'off'; else, newv = 'on'; end
        otherwise
            try, v = evalin('base', curv); catch, try, v = eval(curv); catch, v = []; end, end
            if isnumeric(v) && ~isempty(v)
                newv = mat2str(2 * v + 1, 12);
            else
                why = 'not a number';
            end
    end
end

function [mdl, blk] = buildOne(kind, P, ov)
    mdl = 'tmp_k1'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    blk = [mdl '/Blk']; add_block(libBlock(kind), blk);
    if strcmp(kind, 'body')
        vdb_body_config(blk, P, 16.6667);
        set_param(blk, 'ydot_o', '10', 'r_o', '-0.5');
        addConst(mdl, 'WhlAngF', '0.05', blk); addConst(mdl, 'xdotin', '16.6667', blk);
        addConst(mdl, 'FExt', '[0;-3000;0]', blk); addConst(mdl, 'MExt', '[0;0;-500]', blk);
        outs = {'xdot', 'ydot', 'psi', 'r', 'FzF', 'FzR'};
        stop = '2';
    else
        vdb_tire_config(blk, P, 'front', 20, ov);
        % operating point = what build_vdb_s2.m feeds the tire: no brake, no drive torque, camber 0, yaw rate 0, 220 kPa, flat ground, Fext = static load,
        % ScaleFctrs from mu; only Vx, Vy and mu move. Vy sweeps -3..3 m/s (|alpha| up to 0.15 rad). runScenario runs it twice (mu 0.8 at 20 m/s, mu 0.3 at 8 m/s).
        fz = P.Fzf / 2;
        srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', '20'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; ...
                'Fext', num2str(fz, 12); 'ScaleFctrs', '[1;1;0.8;0;ones(23,1)]'};
        for j = 1:size(srcs, 1), addConst(mdl, srcs{j, 1}, srcs{j, 2}, blk); end
        b = [mdl '/src_Vy']; add_block('simulink/Sources/Ramp', b, 'Slope', '3', 'InitialOutput', '-3'); wire(blk, b, 'Vy');
        outs = {'Fy', 'Fx', 'Mz', 'Mx', 'My', 'Omega'};
        stop = '2';
    end
    for j = 1:numel(outs)
        tw = [mdl '/log_' outs{j}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['k1_' outs{j}], 'SaveFormat', 'Timeseries');
        wireOut(blk, outs{j}, tw);
    end
    for nm = {'Info'}
        try, t = [mdl '/T_' nm{1}]; add_block('simulink/Sinks/Terminator', t); wireOut(blk, nm{1}, t); catch, end
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', stop, 'MaxStep', '0.002', 'RelTol', '1e-6', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
end

function y = runScenario(mdl, kind)
    if strcmp(kind, 'body'), outs = {'xdot', 'ydot', 'psi', 'r', 'FzF', 'FzR'}; else, outs = {'Fy', 'Fx', 'Mz', 'Mx', 'My', 'Omega'}; end
    tq = (0:0.01:1.99)';
    runs = 1; if strcmp(kind, 'tire'), runs = 2; end
    y = [];
    for k = 1:runs
        if k == 2
            set_param([mdl '/src_Vx'], 'Value', '8'); set_param([mdl '/src_ScaleFctrs'], 'Value', '[1;1;0.3;0;ones(23,1)]');
            set_param([mdl '/Blk'], 'omegao', num2str(8 / (0.97 * str2double(get_param([mdl '/Blk'], 'UNLOADED_RADIUS'))), 12));   % wheel starts at the rolling speed
        end
        Simulink.sdi.clear;
        o = sim(Simulink.SimulationInput(mdl));
        for j = 1:numel(outs)
            ts = o.(['k1_' outs{j}]);
            d = squeeze(ts.Data); d = reshape(d, numel(ts.Time), []);
            y = [y; reshape(interp1(ts.Time, d, tq, 'linear', 'extrap'), [], 1)]; %#ok<AGROW>
        end
    end
end

function addConst(mdl, portName, val, dst)
    b = [mdl '/src_' portName]; add_block('simulink/Sources/Constant', b, 'Value', val);
    wire(dst, b, portName);
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
