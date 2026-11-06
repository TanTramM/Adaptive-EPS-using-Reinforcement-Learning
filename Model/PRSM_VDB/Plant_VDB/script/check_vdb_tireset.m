function ok = check_vdb_tireset()
%CHECK_VDB_TIRESET Does choosing a library tire by name really change the tire? (risk R6, plan section 11, step K2)
%   The preset coefficients are not readable from the mask (the helper functions tireMF* are opaque and take no useful input), so the check is done on the
%   tire output: for each of the six presets, Fy(alpha) and Mz(alpha) from a slow Vy sweep (Vx = 20 m/s, mu = 1) at three vertical loads (3167, 4549, 7000 N),
%   each curve made in a freshly built block. The check also repeats everything in the reverse order of presets (order effect of the set_param call).
%   Reports: peak Fy, Fy and Mz at alpha = 0.02 rad, and every pair of presets whose curves agree to 1e-9 relative (= same data).
%   Negative control (tests that the method sees a real coefficient change): External file with PDY1 x 1.1 must raise the Fy peak by 10 % (+-0.5 %).
%   PASS = the order test is reproducible to 1e-9 AND the negative control works. Whether two presets are equal is a finding, not a pass/fail item.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_K2_tireset.txt, .csv
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    load_system('vehdynlibtire');
    presets = {'Light passenger car 205/60R15', 'Mid-size passenger car 235/45R18', 'Performance car 225/40R19', 'SUV 265/50R20', ...
               'Light truck 275/65R18', 'Commercial truck 295/75R22.5'};
    loads = [3167 4549 7000];
    fid = fopen(fullfile(outDir, 'Plant_VDB_K2_tireset.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    say('K2 library tire selection check (%s)\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    nP = numel(presets); nL = numel(loads);
    C1 = cell(nP, nL); C2 = cell(nP, nL);
    for ip = 1:nP, for il = 1:nL, C1{ip, il} = curve(presets{ip}, loads(il), 1); end, end
    for ip = nP:-1:1, for il = nL:-1:1, C2{ip, il} = curve(presets{ip}, loads(il), 1); end, end
    worst = 0;
    for ip = 1:nP, for il = 1:nL, worst = max(worst, max(abs(C1{ip, il}(:) - C2{ip, il}(:))) / max(abs(C1{ip, il}(:)))); end, end
    cOrder = worst < 1e-9;
    say('Order test (forward vs reverse order of presets and loads): worst relative difference %.2e -> %s\n\n', worst, verdict(cOrder));
    say('%-34s | %9s %9s %9s | %9s %9s %9s | %9s %9s %9s\n', 'preset', 'pkFy3167', 'pkFy4549', 'pkFy7000', 'Fy.02 3167', 'Fy.02 4549', 'Fy.02 7000', 'Mz.02 3167', 'Mz.02 4549', 'Mz.02 7000');
    rows = zeros(nP, 9);
    for ip = 1:nP
        for il = 1:nL
            c = C1{ip, il}; a = c(:, 1); fy = c(:, 2); mz = c(:, 3);
            [~, i0] = min(abs(a - 0.02));
            rows(ip, il) = max(abs(fy)); rows(ip, 3 + il) = fy(i0); rows(ip, 6 + il) = mz(i0);
        end
        say('%-34s | %9.1f %9.1f %9.1f | %9.1f %9.1f %9.1f | %9.2f %9.2f %9.2f\n', presets{ip}, rows(ip, :));
    end
    say('\nPairs of presets with the SAME curves at all three loads (relative difference < 1e-9):\n');
    anySame = false;
    for ip = 1:nP
        for jp = ip + 1:nP
            d = 0;
            for il = 1:nL, d = max(d, max(abs(C1{ip, il}(:) - C1{jp, il}(:))) / max(abs(C1{ip, il}(:)))); end
            if d < 1e-9, say('  SAME: %s  ==  %s\n', presets{ip}, presets{jp}); anySame = true; end
        end
    end
    if ~anySame, say('  none: the six presets are all different\n'); end
    say('\nPairs that differ (largest relative difference of the curves, for information):\n');
    for ip = 1:nP
        for jp = ip + 1:nP
            d = 0;
            for il = 1:nL, d = max(d, max(abs(C1{ip, il}(:) - C1{jp, il}(:))) / max(abs(C1{ip, il}(:)))); end
            say('  %-34s vs %-34s : %.3e\n', presets{ip}, presets{jp}, d);
        end
    end
    % negative control: a deliberate coefficient change through External file must be seen
    base = curve('External file', 4549, 1); mod = curve('External file', 4549, 1.1);
    ratio = max(abs(mod(:, 2))) / max(abs(base(:, 2)));
    cNeg = abs(ratio - 1.1) < 0.005;
    say('\nNegative control (External file, PDY1 x 1.1): Fy peak ratio %.4f (expected 1.10 +-0.005) -> %s\n', ratio, verdict(cNeg));
    ok = cOrder && cNeg;
    say('\nK2 overall (order test and negative control): %s\n', verdict(ok));
    fclose(fid); type(fullfile(outDir, 'Plant_VDB_K2_tireset.txt'));
    T = table(presets', rows(:, 1), rows(:, 2), rows(:, 3), rows(:, 4), rows(:, 5), rows(:, 6), rows(:, 7), rows(:, 8), rows(:, 9), 'VariableNames', ...
        {'preset', 'pkFy_3167', 'pkFy_4549', 'pkFy_7000', 'Fy02_3167', 'Fy02_4549', 'Fy02_7000', 'Mz02_3167', 'Mz02_4549', 'Mz02_7000'});
    writetable(T, fullfile(outDir, 'Plant_VDB_K2_tireset.csv'));
end

function s = verdict(c)
    if c, s = 'PASS'; else, s = 'NOT PASS'; end
end

function c = curve(tireType, Fz, pdyScale)
%CURVE [alpha Fy Mz] of one tire block in a slow Vy sweep, Vx = 20 m/s, mu = 1 (alpha = atan(Vy/Vx)).
    mdl = 'tmp_k2'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    set_param(blk, 'tireType', tireType); set_param(blk, 'vertType', 'None'); set_param(blk, 'plySteer', 'off'); set_param(blk, 'turnslip', 'off');
    set_param(blk, 'omegao', num2str(20 / (0.97 * str2double(get_param(blk, 'UNLOADED_RADIUS'))), 12));
    if pdyScale ~= 1
        set_param(blk, 'PDY1', num2str(pdyScale * str2double(get_param(blk, 'PDY1')), 12));
    end
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', '20'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz); ...
            'ScaleFctrs', '[1;1;1;0;ones(23,1)]'};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    b = [mdl '/src_Vy']; add_block('simulink/Sources/Ramp', b, 'Slope', '0.5', 'InitialOutput', '0'); wire(blk, b, 'Vy');   % 0 .. 4 m/s in 8 s (alpha to 0.2 rad)
    for nm = {'Fy', 'Mz'}
        tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', nm{1}, 'SaveFormat', 'Timeseries'); wireOut(blk, nm{1}, tw);
    end
    for nm = {'Info', 'Fx', 'Mx', 'My', 'Omega', 'Fz'}
        t = [mdl '/T_' nm{1}]; add_block('simulink/Sinks/Terminator', t); wireOut(blk, nm{1}, t);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '8', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    tq = (0.5:0.01:8)'; vy = 0.5 * tq;
    c = [atan(vy / 20), interp1(o.Fy.Time, squeeze(o.Fy.Data), tq), interp1(o.Mz.Time, squeeze(o.Mz.Data), tq)];
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
