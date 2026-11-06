function ok = check_vdb_trail()
%CHECK_VDB_TRAIL Night step N5 (milestone C3): test T3 of Documents/Shared/KeHoach_Plant_VDB.txt, the reaction torque T_r built from the aligning moment M_z
%   of each of the six library tire sets of the VDB tire block, compared with the Plant T_r (PT(13)-(14), e_p0 = e_c + t_0, shrinking pneumatic trail).
%   REPORT ONLY (plan T3): no conclusion about e_p0. The pass/fail part is the SIGN: -M_z/F_y > 0 at small slip (positive pneumatic trail) and T_r of the
%   same sign as F_y (T_r opposes the steering angle, R8). Method: one front half axle (F_z = F_zf/2, Vx = 20 m/s, free rolling, preset tire, ply steer and
%   turn slip off, mu = 1), staircase of alpha_VDB from -0.2 to +0.2 rad (hold 0.25 s); axle values = 2 x one wheel; T_r = (e_c*F_y - M_z)/n_st (R8).
%   Plant side: alpha_plant = -alpha_VDB, F_y and T_r from PT(9)-(10), (13)-(14) with mu = 1 and the same F_z, evaluated independently from params.json.
%   Negative control: the sign of M_z flipped must report NOT PASS on the sign test. Output: Result/PRSM/Plant_VDB/Plant_VDB_T3_trail.txt, _trail.csv, _trail.png.
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibtire');
    types = {'Light passenger car 205/60R15', 'Mid-size passenger car 235/45R18', 'Performance car 225/40R19', 'SUV 265/50R20', 'Light truck 275/65R18', 'Commercial truck 295/75R22.5'};
    Vx = 20; hold_s = 0.25; al = unique(round([-0.2:0.01:0.2, -0.025, 0.025], 6)); Fz = P.Fzf / 2;
    txtFile = fullfile(outDir, 'Plant_VDB_T3_trail.txt'); fclose(fopen(txtFile, 'w'));
    say = @(varargin) appendTxt(txtFile, sprintf(varargin{:}));
    say('N5 test T3: reaction torque T_r from the aligning moment of six VDB tire sets (%s)\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    say('Front half axle F_z = %.1f N, Vx = %g m/s, mu = 1; Plant: e_c = %.3f m, t_0 = %.3f m (e_p0 = %.3f m), n_st = %g\n\n', Fz, Vx, P.ec, P.t0, P.ep0, P.n);
    say('tire                                  trail t=-Mz/Fy at alpha 0.01  0.025  0.05 rad (m)   T_r VDB at 0.025 rad (N.m)  T_r Plant (N.m)  ratio   peak T_r VDB / Plant   sign\n');
    ok = true; rows = []; Tcurve = cell(1, numel(types));
    fPl = mfPlant(P, -al, 1, 2 * Fz); TrPl = trailPlant(P, -al, fPl, 1, 2 * Fz);
    for i = 1:numel(types)
        [Fy, Mz] = stair(types{i}, Vx, Fz, al, hold_s);
        Fa = 2 * Fy; Ma = 2 * Mz;                                  % axle values
        Tr = (P.ec * Fa - Ma) / P.n;
        Tcurve{i} = Tr;
        k = @(a) find(abs(al - a) < 1e-9, 1);
        idx = arrayfun(@(a) find(abs(al + a) < 1e-9, 1), [0.01 0.025 0.05]);   % negative alpha_VDB = positive Plant alpha
        idx2 = find(abs(al + 0.025) < 1e-6, 1); if isempty(idx2), [~, idx2] = min(abs(al + 0.025)); end
        trail = -Ma(idx) ./ Fa(idx);
        signTrail = all(trail > 0);
        signTr = all(sign(Tr(abs(al) > 0.005 & abs(al) < 0.1)) == sign(Fa(abs(al) > 0.005 & abs(al) < 0.1)));
        c = signTrail && signTr; ok = ok && c;
        % negative control: Mz sign flipped
        TrN = (P.ec * Fa + Ma) / P.n; trailN = Ma(idx) ./ Fa(idx);
        cN = all(trailN > 0) && all(sign(TrN(abs(al) > 0.005 & abs(al) < 0.1)) == sign(Fa(abs(al) > 0.005 & abs(al) < 0.1)));
        ok = ok && ~cN;
        iP = find(abs(al + 0.025) < 1e-6, 1);
        say('%-38s %7.4f %7.4f %7.4f                       %8.2f                    %8.2f        %6.2f   %6.2f / %6.2f      %s  (neg. control Mz flipped: %s)\n', types{i}, trail(1), trail(2), trail(3), ...
            Tr(iP), TrPl(iP), Tr(iP) / TrPl(iP), max(abs(Tr)), max(abs(TrPl)), verdict(c), verdict(cN));
        rows = [rows; i, trail, Tr(iP), TrPl(iP), max(abs(Tr)), max(abs(TrPl))]; %#ok<AGROW>
    end
    say('\nN5 sign tests overall: %s (T3 itself is report only: the table above is the result; no conclusion about e_p0)\n', verdict(ok));
    writematrix(rows, fullfile(outDir, 'Plant_VDB_T3_trail.csv'));
    f = figure('Visible', 'off', 'Position', [50 50 1000 650]); hold on; grid on;
    for i = 1:numel(types), plot(al, Tcurve{i}); end
    plot(al, TrPl, 'k--', 'LineWidth', 1.5);
    legend([types, {'Plant (mu 1)'}], 'Location', 'best', 'Interpreter', 'none'); xlabel('alpha_{VDB} (rad)'); ylabel('T_r (N.m)'); title('Reaction torque T_r of the six VDB tire sets and of the Plant');
    exportgraphics(f, fullfile(outDir, 'Plant_VDB_T3_trail.png'), 'Resolution', 110); close(f);
    type(txtFile);
end

function [F, M] = stair(tireType, Vx, Fz, al, hold_s)
    mdl = 'tmp_n5_tire'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    set_param(blk, 'tireType', tireType); set_param(blk, 'vertType', 'None'); set_param(blk, 'plySteer', 'off'); set_param(blk, 'turnslip', 'off');
    set_param(blk, 'omegao', num2str(Vx / (0.97 * str2double(get_param(blk, 'UNLOADED_RADIUS'))), 12));
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(Vx); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz); 'ScaleFctrs', '[1;1;1;0;ones(23,1)]'};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    n = numel(al); t = (0:0.001:n * hold_s)'; idx = min(n, floor(t / hold_s) + 1); vy = Vx * tan(al);
    assignin('base', 'n5_vy', [t, vy(idx)']);
    add_block('simulink/Sources/From Workspace', [mdl '/src_Vy'], 'VariableName', 'n5_vy', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    wire(blk, [mdl '/src_Vy'], 'Vy');
    for nm = {'Fy', 'Mz'}
        tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['n5_' nm{1}], 'SaveFormat', 'Timeseries'); wireOut(blk, nm{1}, tw);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    tt = o.n5_Fy.Time; y = squeeze(o.n5_Fy.Data); z = squeeze(o.n5_Mz.Data); F = zeros(1, n); M = F;
    for i = 1:n
        w = tt > (i - 1) * hold_s + 0.15 & tt <= i * hold_s; F(i) = mean(y(w)); M(i) = mean(z(w));
    end
    close_system(mdl, 0);
end

function F = mfPlant(P, alpha, mu, Fz)
    D = mu .* Fz; B = P.Ca ./ (P.C .* D); u = B .* alpha;
    F = D .* sin(P.C .* atan(u - P.E .* (u - atan(u))));
end

function Tr = trailPlant(P, alpha, F, mu, Fz)
    ep = P.ec + max(0, P.t0 - sign(alpha) .* P.t0 .* P.Ca .* tan(alpha) ./ (3 .* mu .* Fz));
    Tr = ep ./ P.n .* F;
end

function appendTxt(f, str)
    fid = fopen(f, 'a'); fprintf(fid, '%s', str); fclose(fid);
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
    if ~isKey(m, portName) || m(portName) > numel(ph.Inport), error('Input %s of %s unavailable', portName, dst); end
    add_line(bdroot(dst), get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s', portName, src); end
    ph = get_param(src, 'PortHandles');
    add_line(bdroot(src), ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
