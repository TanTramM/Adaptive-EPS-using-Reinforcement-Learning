function ok = compare_plant_variant(model, tag, lvl, tMax)
%COMPARE_PLANT_VARIANT Run one of the Plants of Model/VDB/Plants (Plant_VDBTire, Plant_VDBBody, Plant_VDBTireBody; build_plant_variants.m) on one baseline case and compare it with the Plant baseline of make_plant_baseline.m.
%   ok = compare_plant_variant(model, tag, lvl [, tMax])   model = the Plant name; tag in STEADY, DRY, SLIP, WEAVE, EDGE, RAMP, CALIB; lvl = 0 or 2 (T_a level); tMax truncates the case.
%   Same inputs (theta1, T_a, v, mu of the baseline) and same solver settings as the baseline (MaxStep 2 ms, RelTol 1e-6). NO pass threshold (trial):
%   the relative differences RMS(difference)/max|Plant signal| of a_y, gamma, F_yf, F_yr, T_r, T_s are printed and appended to
%   Result/PRSM/Plant_VDB/Variants/<model>_compare.txt; signals (.mat) and the overlay (.png) are written to the same folder.
%   10 % (plan section 2, C8) is printed only as a reference. A failing simulation is reported as NOT CONCLUDED with the solver message.
    if nargin < 4, tMax = inf; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    folderDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(folderDir));      % Model/ (this file is Model/VDB/Plants/script/)
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB', 'Variants');
    baseDir = result_dir('Plant_VDB');
    load_plant_vdb; load_system('vehdynlibtire'); load_system('vehdynlibeom');
    S = load(fullfile(baseDir, 'baseline', sprintf('Plant_%s_Ta%d.mat', tag, lvl)));
    k = S.t <= tMax;
    names = {'t', 'theta1', 'T_a', 'v', 'mu', 'T_s', 'a_y', 'gamma', 'theta2_dot', 'F_yf', 'F_yr', 'T_r'};
    B = struct(); for i = 1:numel(names), B.(names{i}) = S.(names{i})(k); end
    assignin('base', 'vdb_v0', B.v(1));
    modelName = model;
    mdl = 'tmp_plantvdb_harness'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(folderDir, [modelName '.slx'])); new_system(mdl);
    add_block([modelName '/' modelName], [mdl '/DUT']); close_system(modelName, 0);
    dut = [mdl '/DUT'];
    t = B.t;
    vars = {'theta1', 'T_a', 'v', 'mu'};
    for i = 1:4
        assignin('base', ['tn_' vars{i}], [t, B.(vars{i})]);
        b = [mdl '/src_' vars{i}]; add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tn_' vars{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
        add_line(mdl, get_param(b, 'PortHandles').Outport(1), portH(dut, 'Inport', vars{i}));
    end
    for nm = {'T_s', 'a_y', 'gamma'}, logP(mdl, portH(dut, 'Outport', nm{1}), nm{1}); end
    for nm = {'F_yf', 'F_yr', 'T_r'}                                  % taps on the output ports of the Tires block (the original Plant has no Goto tag for F_yf, F_yr at the DUT level)
        tw = [dut '/tap_log_' nm{1}];
        add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['tn_' nm{1}], 'SaveFormat', 'Timeseries');
        add_line(dut, portH([dut '/Tires'], 'Outport', nm{1}), get_param(tw, 'PortHandles').Inport(1));
    end
    set_param(mdl, 'Solver', 'VariableStepAuto', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'RelTol', '1e-6', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    resFile = fullfile(outDir, [model '_compare.txt']);
    tic; msg = '';
    try
        Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    catch ME
        msg = strtrim(ME.message(1:min(200, numel(ME.message))));
        for q = 1:numel(ME.cause), msg = [msg ' | cause: ' strtrim(ME.cause{q}.message(1:min(300, numel(ME.cause{q}.message))))]; end   %#ok<AGROW>
    end
    el = toc;
    if ~isempty(msg)
        appendTxt(resFile, sprintf('%s: %s Ta%d (t <= %g s): RUN ERROR after %.0f s: %s -> NOT CONCLUDED\n', model, tag, lvl, t(end), el, msg)); ok = false; close_system(mdl, 0); return;
    end
    sig = {'a_y', 'gamma', 'F_yf', 'F_yr', 'T_r', 'T_s'};
    R = struct('t', t);
    for i = 1:numel(sig), R.(sig{i}) = interp1(o.(['tn_' sig{i}]).Time, squeeze(o.(['tn_' sig{i}]).Data), t); end
    e = zeros(1, numel(sig));
    for i = 1:numel(sig), e(i) = sqrt(mean((R.(sig{i}) - B.(sig{i})).^2)) / max(abs(B.(sig{i}))); end
    ok = all(e <= 0.10);          % reference only (10 % of plan C8), not a verdict
    line = sprintf('%s: %s Ta%d (t <= %g s, sim %.0f s): err a_y %.4f %%, gamma %.4f %%, F_yf %.4f %%, F_yr %.4f %%, T_r %.4f %%, T_s %.4f %% -> %s (trial, no threshold)\n', ...
        model, tag, lvl, t(end), el, 100 * e, tern(ok, 'within 10 %', 'beyond 10 %'));
    fprintf('%s', line); appendTxt(resFile, line);
    save(fullfile(outDir, sprintf('%s_%s_Ta%d.mat', model, tag, lvl)), '-struct', 'R');
    f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
    for i = 1:numel(sig), subplot(3, 2, i); plot(t, B.(sig{i})); hold on; plot(t, R.(sig{i}), '--'); grid on; ylabel(sig{i}, 'Interpreter', 'none'); end
    sgtitle(sprintf('%s vs Plant (trial), %s, T_a level %d (solid Plant, dashed %s)', model, tag, lvl, model), 'Interpreter', 'none');
    exportgraphics(f, fullfile(outDir, sprintf('%s_%s_Ta%d.png', model, tag, lvl)), 'Resolution', 110); close(f);
    close_system(mdl, 0);
end

function h = portH(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

function logP(mdl, ph, name)
    tw = [mdl '/log_' name]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['tn_' name], 'SaveFormat', 'Timeseries');
    add_line(mdl, ph, get_param(tw, 'PortHandles').Inport(1));
end

function appendTxt(f, str)
    fid = fopen(f, 'a'); fprintf(fid, '%s', str); fclose(fid);
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
