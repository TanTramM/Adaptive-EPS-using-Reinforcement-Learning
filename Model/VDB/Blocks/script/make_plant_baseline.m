function make_plant_baseline()
%MAKE_PLANT_BASELINE Night step N2 (items R11, R12): open-loop reference signals of the Plant for every comparison test of Plant_VDB.
%   Inputs: the cases of make_cases('SSW') (STEADY, SLIP, WEAVE, 100 s each) and make_cases('CALIB') (140 s), the SAME theta1, v, mu as the closed loop
%   uses (no case is invented), and two T_a levels: T_a = 0 and T_a = a 2 N.m step at t = 1 s (so that the T_a channel is exercised).
%   Output per run: Result/PRSM/Plant_VDB/baseline/Plant_<CASE>_Ta<0|2>.mat with the 1 ms signals t, theta1, T_a, v, mu, T_s, a_y, gamma,
%   theta2_dot, F_yf, F_yr, T_r, alpha_f. A run whose file exists is not run again. Plant.mdl is only read (copied into a temporary harness).
%   Same solver settings as build_closed_loop.m (MaxStep 2 ms, RelTol 1e-6, default variable-step solver).
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = fullfile(result_dir('Plant_VDB'), 'baseline'); if ~exist(outDir, 'dir'), mkdir(outDir); end
    load_plant;                                                         % base workspace parameters read by the Simulink blocks
    plantFile = fullfile(modelDir, 'original', 'PRSM', 'Plant', 'Plant.mdl');
    [~, gitHead] = system(['git -C "' fileparts(modelDir) '" rev-parse --short HEAD']);
    fid = fopen(fullfile(outDir, 'baseline_info.txt'), 'w');
    fprintf(fid, 'Plant baseline (night plan N2), %s\nPlant.mdl SHA-256: %s\ngit HEAD: %s', datestr(now, 'yyyy-mm-dd HH:MM'), fileHash(plantFile), strtrim(gitHead));
    fprintf(fid, '\nT_a levels: 0 and a 2 N.m step at t = 1 s. Signals on a 1 ms grid. Cases: make_cases(''SSW'') and make_cases(''CALIB'').\n');
    fclose(fid);

    cs = make_cases('SSW'); cc = make_cases('CALIB');
    cd3 = make_cases();                                                 % DREWS v3 [DRY, RAMP, SLIP, EDGE, WEAVE]; K1 of plan section 11 adds DRY, RAMP, EDGE (SLIP, WEAVE are already in SSW)
    cd3 = cd3(ismember({cd3.tag}, {'DRY', 'RAMP', 'EDGE'}));
    cases = [slim(cs), slim(cc), slim(cd3)];
    for k = 1:numel(cases)
        for lvl = [0 2]
            f = fullfile(outDir, sprintf('Plant_%s_Ta%d.mat', cases(k).tag, lvl));
            if exist(f, 'file'), fprintf('skip %s\n', f); continue; end
            tic; S = runOne(plantFile, cases(k), lvl); S.case_tag = cases(k).tag; S.Ta_level = lvl;   %#ok<NASGU>
            save(f, '-struct', 'S'); fprintf('%s done in %.0f s\n', f, toc);
        end
    end
end

function S = runOne(plantFile, c, lvl)
    mdl = 'tmp_n2_plant'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(plantFile);
    new_system(mdl);
    add_block('Plant/Plant', [mdl '/DUT']);
    close_system('Plant', 0);                                           % nothing of Plant.mdl is saved
    dut = [mdl '/DUT'];
    t = c.t(:);  Ta = lvl * double(t >= 1);
    assignin('base', 'n2_theta1', [t, c.theta1(:)]); assignin('base', 'n2_Ta', [t, Ta]);
    assignin('base', 'n2_v', [t, c.v(:)]);           assignin('base', 'n2_mu', [t, c.mu(:)]);
    ins = {'theta1', 'T_a', 'v', 'mu'};
    for i = 1:numel(ins)
        b = [mdl '/src_' ins{i}];
        add_block('simulink/Sources/From Workspace', b, 'VariableName', ['n2_' strrep(ins{i}, 'T_a', 'Ta')], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
        add_line(mdl, get_param(b, 'PortHandles').Outport(1), portHandle(dut, 'Inport', ins{i}));
    end
    outs = {'T_s', 'a_y', 'gamma', 'theta2_dot'};
    for i = 1:numel(outs), logPort(mdl, portHandle(dut, 'Outport', outs{i}), outs{i}); end
    % taps of internal signals, by the local Goto tags of the Plant (From blocks at the level of the Goto)
    tap(dut,                'T_r',     'T_r');
    tap([dut '/Bike2DOF'],  'F_yf',    'F_yf');
    tap([dut '/Bike2DOF'],  'F_yr',    'F_yr');
    tap([dut '/Tires'],     'alpha_f', 'alpha_f');
    set_param(mdl, 'Solver', 'VariableStepAuto', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'RelTol', '1e-6', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    tg = (0:0.001:t(end))';
    S = struct('t', tg, 'theta1', interp1(t, c.theta1(:), tg), 'T_a', lvl * double(tg >= 1), 'v', interp1(t, c.v(:), tg), 'mu', interp1(t, c.mu(:), tg));
    names = [outs, {'T_r', 'F_yf', 'F_yr', 'alpha_f'}];
    for i = 1:numel(names)
        ts = o.(['n2_' names{i}]); S.(names{i}) = interp1(ts.Time, squeeze(ts.Data), tg);
    end
    close_system(mdl, 0);
end

function h = portHandle(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

function logPort(mdl, ph, name)
    tw = [mdl '/log_' name];
    add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['n2_' name], 'SaveFormat', 'Timeseries');
    add_line(mdl, ph, get_param(tw, 'PortHandles').Inport(1));
end

function tap(level, tag, name)
    fr = [level '/tap_from_' name]; tw = [level '/tap_log_' name];
    add_block('simulink/Signal Routing/From', fr, 'GotoTag', tag);
    add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['n2_' name], 'SaveFormat', 'Timeseries');
    add_line(level, [get_param(fr, 'Name') '/1'], [get_param(tw, 'Name') '/1']);
end

function s = fileHash(f)
    md = java.security.MessageDigest.getInstance('SHA-256'); fid = fopen(f, 'r'); d = fread(fid, inf, '*uint8'); fclose(fid);
    md.update(d); s = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'))', 1, []));
end

function s = slim(c)
%SLIM Keep only the fields the baseline needs, so that case structs from different make_cases calls can be concatenated.
    s = struct('tag', {c.tag}, 't', {c.t}, 'theta1', {c.theta1}, 'v', {c.v}, 'mu', {c.mu});
end
