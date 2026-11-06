function ok = compare_vdb_s2(variant, tag, lvl, tMax, solverOpt)
%COMPARE_VDB_S2 Night step N9 (TRIAL, no pass threshold): run PlantVDBS2.slx or PlantVDBS3.slx (build_vdb_s2.m) on one baseline case and compare it with the Plant baseline of make_plant_baseline.m.
%   compare_vdb_s2(variant, tag, lvl [, tMax]): variant 'S2' or 'S3'; tag in STEADY, SLIP, WEAVE, CALIB; lvl = 0 or 2 (T_a level); tMax truncates the case (default whole case).
%   Same inputs (theta1, T_a, v, mu of the baseline) and the same solver settings as the baseline (MaxStep 2 ms, RelTol 1e-6). There is NO pass threshold for S2 and S3 (plan N9: trial, not official);
%   the relative differences RMS(difference)/max|Plant signal| of a_y, gamma, F_yf, T_r, T_s are written down, and the 10 % of plan section 2 (C8) is only printed as a reference. Appends one line to
%   Result/PRSM/Plant_VDB/Plant_VDB_S2S3_compare.txt and writes Plant_VDB_<variant>_<tag>_Ta<lvl>.mat (signals) and .png (overlay).
%   Run time of the simulation is printed (for T7). A failing simulation is reported as NOT CONCLUDED with the solver message, never hidden.
    if nargin < 4, tMax = inf; end
    custom = nargin >= 5;      % K10 (plan section 11): another solver; the result files get the suffix of the solver and a high-frequency check is written
    modelName = ['PlantVDB' variant];
    if ~custom, solverOpt = struct('Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6'); end   % the baseline settings
    sfx = ''; if custom, sfx = ['_' solverOpt.Solver '_' solverOpt.Label]; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    load_plant; load_system('vehdynlibeom');
    S = load(fullfile(outDir, 'baseline', sprintf('Plant_%s_Ta%d.mat', tag, lvl)));
    k = S.t <= tMax;
    names = {'t', 'theta1', 'T_a', 'v', 'mu', 'T_s', 'a_y', 'gamma', 'theta2_dot', 'F_yf', 'F_yr', 'T_r', 'alpha_f'};
    B = struct(); for i = 1:numel(names), B.(names{i}) = S.(names{i})(k); end
    assignin('base', 'vdb_v0', B.v(1));
    mdl = 'tmp_s1_harness'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(fileparts(scriptDir), [modelName '.slx'])); new_system(mdl);
    add_block([modelName '/Plant'], [mdl '/DUT']); close_system(modelName, 0);
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
    if custom
        set_param(mdl, 'Solver', solverOpt.Solver, 'FixedStep', solverOpt.FixedStep, 'StopTime', num2str(t(end)), 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    else
        set_param(mdl, 'Solver', solverOpt.Solver, 'StopTime', num2str(t(end)), 'MaxStep', solverOpt.MaxStep, 'RelTol', solverOpt.RelTol, 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    end
    resFile = fullfile(outDir, 'Plant_VDB_S2S3_compare.txt');
    tic; msg = '';
    try
        Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    catch ME
        msg = strtrim(ME.message(1:min(200, numel(ME.message))));
        for q = 1:numel(ME.cause), msg = [msg ' | cause: ' strtrim(ME.cause{q}.message(1:min(300, numel(ME.cause{q}.message))))]; end   %#ok<AGROW>
    end
    el = toc;
    if ~isempty(msg)
        appendTxt(resFile, sprintf('[%s, %s, MaxStep %s, RelTol %s] %s Ta%d (t <= %g s): RUN ERROR after %.0f s: %s -> NOT CONCLUDED\n', variant, solverOpt.Solver, solverOpt.MaxStep, solverOpt.RelTol, tag, lvl, t(end), el, msg)); ok = false; close_system(mdl, 0); return;
    end
    R = struct('t', t);
    for nm = [outs, {'F_yf', 'F_yr', 'T_r'}], R.(nm{1}) = interp1(o.(['s1_' nm{1}]).Time, squeeze(o.(['s1_' nm{1}]).Data), t); end
    sig = {'a_y', 'gamma', 'F_yf', 'T_r', 'T_s'}; e = zeros(1, 5);
    for i = 1:5, e(i) = sqrt(mean((R.(sig{i}) - B.(sig{i})).^2)) / max(abs(B.(sig{i}))); end
    ok = all(e <= 0.10);        % reference only (10 % of plan C8), not a verdict
    if custom
        hp = @(x) sqrt(mean((x - movmean(x, 21)).^2)) / max(abs(x));      % high-frequency content (21 ms window), relative to the signal range
        appendTxt(resFile, sprintf('[%s, %s, fixed step %s s] %s Ta%d: err a_y %.3f %%, gamma %.3f %%, F_yf %.3f %%, T_r %.3f %%, T_s %.3f %%; high-frequency content of gamma %.2e (Plant %.2e), of T_s %.2e (Plant %.2e)\n', variant, solverOpt.Solver, solverOpt.FixedStep, tag, lvl, 100 * e, hp(R.gamma), hp(B.gamma), hp(R.T_s), hp(B.T_s)));
    end
    appendTxt(resFile, sprintf('[%s] %s Ta%d (t <= %g s, sim %.0f s): err a_y %.3f %%, gamma %.3f %%, F_yf %.3f %%, T_r %.3f %%, T_s %.3f %% -> %s (trial, no threshold; 10 %% is only a reference)\n', variant, tag, lvl, t(end), el, 100 * e, tern(all(e <= 0.10), 'within 10 %', 'beyond 10 %')));
    save(fullfile(outDir, sprintf('Plant_VDB_%s_%s_Ta%d%s.mat', variant, tag, lvl, sfx)), '-struct', 'R');
    f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
    for i = 1:5, subplot(3, 2, i); plot(t, B.(sig{i})); hold on; plot(t, R.(sig{i}), '--'); grid on; ylabel(sig{i}, 'Interpreter', 'none'); end
    sgtitle(sprintf('%s vs Plant (trial), %s, T_a level %d (solid Plant, dashed %s)', variant, tag, lvl, variant), 'Interpreter', 'none');
    exportgraphics(f, fullfile(outDir, sprintf('Plant_VDB_%s_%s_Ta%d%s.png', variant, tag, lvl, sfx)), 'Resolution', 110); close(f);
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
