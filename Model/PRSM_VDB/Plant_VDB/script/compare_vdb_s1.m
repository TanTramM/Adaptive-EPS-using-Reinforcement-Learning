function ok = compare_vdb_s1(tag, lvl, tMax, solverOpt)
%COMPARE_VDB_S1 Night step N6: run PlantVDBS1.slx (build_vdb_s1.m) on one baseline case and compare it with the Plant baseline of make_plant_baseline.m.
%   compare_vdb_s1(tag, lvl [, tMax]): tag in STEADY, SLIP, WEAVE, CALIB; lvl = 0 or 2 (T_a level); tMax truncates the case (default whole case).
%   Same inputs (theta1, T_a, v, mu of the baseline) and the same solver settings as the baseline (MaxStep 2 ms, RelTol 1e-6). Threshold S1 (plan section 2):
%   a_y, gamma, F_yf, T_r, T_s each within 1 % : RMS(difference) / max|Plant signal|. The verdict is computed here. Appends one line to
%   Result/PRSM/Plant_VDB/Plant_VDB_S1_compare.txt and writes Plant_VDB_S1_<tag>_Ta<lvl>.mat (signals) and .png (overlay).
%   Run time of the simulation is printed (for T7). A failing simulation is reported as NOT CONCLUDED with the solver message, never hidden.
    if nargin < 3, tMax = inf; end
    if nargin < 4, solverOpt = struct('Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6'); end   % default = the baseline settings; others only for the recovery attempts of plan 10.9
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    load_plant; load_system('vehdynlibeom');
    S = load(fullfile(outDir, 'baseline', sprintf('Plant_%s_Ta%d.mat', tag, lvl)));
    k = S.t <= tMax;
    names = {'t', 'theta1', 'T_a', 'v', 'mu', 'T_s', 'a_y', 'gamma', 'theta2_dot', 'F_yf', 'F_yr', 'T_r', 'alpha_f'};
    B = struct(); for i = 1:numel(names), B.(names{i}) = S.(names{i})(k); end
    assignin('base', 'vdb_v0', B.v(1));
    mdl = 'tmp_s1_harness'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(fileparts(scriptDir), 'PlantVDBS1.slx')); new_system(mdl);
    add_block('PlantVDBS1/Plant', [mdl '/DUT']); close_system('PlantVDBS1', 0);
    dut = [mdl '/DUT'];
    t = B.t;
    vars = {'theta1', 'T_a', 'v', 'mu'};
    for i = 1:4
        assignin('base', ['s1_' vars{i}], [t, B.(vars{i})]);
        b = [mdl '/src_' vars{i}]; add_block('simulink/Sources/From Workspace', b, 'VariableName', ['s1_' vars{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
        add_line(mdl, get_param(b, 'PortHandles').Outport(1), portH(dut, 'Inport', vars{i}));
    end
    outs = {'T_s', 'a_y', 'gamma'};
    for i = 1:3, logP(mdl, portH(dut, 'Outport', outs{i}), outs{i}); end
    for nm = {'F_yf', 'F_yr', 'T_r'}                                 % taps by the local Goto tags of the DUT level
        fr = [dut '/tap_from_' nm{1}]; tw = [dut '/tap_log_' nm{1}];
        add_block('simulink/Signal Routing/From', fr, 'GotoTag', nm{1}); add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['s1_' nm{1}], 'SaveFormat', 'Timeseries');
        add_line(dut, ['tap_from_' nm{1} '/1'], ['tap_log_' nm{1} '/1']);
    end
    set_param(mdl, 'Solver', solverOpt.Solver, 'StopTime', num2str(t(end)), 'MaxStep', solverOpt.MaxStep, 'RelTol', solverOpt.RelTol, 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    resFile = fullfile(outDir, 'Plant_VDB_S1_compare.txt');
    tic; msg = '';
    try
        Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    catch ME
        msg = strtrim(ME.message(1:min(200, numel(ME.message))));
        for q = 1:numel(ME.cause), msg = [msg ' | cause: ' strtrim(ME.cause{q}.message(1:min(300, numel(ME.cause{q}.message))))]; end   %#ok<AGROW>
    end
    el = toc;
    if ~isempty(msg)
        appendTxt(resFile, sprintf('[%s, MaxStep %s, RelTol %s] %s Ta%d (t <= %g s): RUN ERROR after %.0f s: %s -> NOT CONCLUDED\n', solverOpt.Solver, solverOpt.MaxStep, solverOpt.RelTol, tag, lvl, t(end), el, msg)); ok = false; close_system(mdl, 0); return;
    end
    R = struct('t', t);
    for nm = [outs, {'F_yf', 'F_yr', 'T_r'}], R.(nm{1}) = interp1(o.(['s1_' nm{1}]).Time, squeeze(o.(['s1_' nm{1}]).Data), t); end
    sig = {'a_y', 'gamma', 'F_yf', 'T_r', 'T_s'}; e = zeros(1, 5);
    for i = 1:5, e(i) = sqrt(mean((R.(sig{i}) - B.(sig{i})).^2)) / max(abs(B.(sig{i}))); end
    ok = all(e <= 0.01);
    appendTxt(resFile, sprintf('[%s, MaxStep %s, RelTol %s] %s Ta%d (t <= %g s, sim %.0f s): err a_y %.3f %%, gamma %.3f %%, F_yf %.3f %%, T_r %.3f %%, T_s %.3f %% -> S1 %s\n', solverOpt.Solver, solverOpt.MaxStep, solverOpt.RelTol, tag, lvl, t(end), el, 100 * e, tern(ok, 'PASS', 'NOT PASS')));   % solver args added 2026-11-06 (were missing, garbled the line)
    save(fullfile(outDir, sprintf('Plant_VDB_S1_%s_Ta%d.mat', tag, lvl)), '-struct', 'R');
    f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
    for i = 1:5, subplot(3, 2, i); plot(t, B.(sig{i})); hold on; plot(t, R.(sig{i}), '--'); grid on; ylabel(sig{i}, 'Interpreter', 'none'); end
    sgtitle(sprintf('S1 vs Plant, %s, T_a level %d (solid Plant, dashed S1)', tag, lvl), 'Interpreter', 'none');
    exportgraphics(f, fullfile(outDir, sprintf('Plant_VDB_S1_%s_Ta%d.png', tag, lvl)), 'Resolution', 110); close(f);
    close_system(mdl, 0);
end

function h = portH(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

function logP(mdl, ph, name)
    tw = [mdl '/log_' name]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['s1_' name], 'SaveFormat', 'Timeseries');
    add_line(mdl, ph, get_param(tw, 'PortHandles').Inport(1));
end

function appendTxt(f, str)
    fid = fopen(f, 'a'); fprintf(fid, '%s', str); fclose(fid);
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
