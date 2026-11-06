function check_vdb_trail_mu()
%CHECK_VDB_TRAIL_MU Report T_r(alpha) of the Plant and of five distinct VDB library tires at mu = 0.8, 0.5, 0.33, 0.2 (risk R2, plan section 11, step K3a).
%   REPORT ONLY (no pass/fail, no choice of e_p0 or t_0). Same method as check_vdb_trail.m (front half axle, Vx = 20 m/s, alpha staircase, T_r = (e_c*F_y - M_z)/n_st
%   with axle = 2 x wheel) but at four friction levels (ScaleFctrs entry 3, LMUY). The quantity that matters for over-assist is how the reaction torque and the
%   pneumatic trail t = -M_z/F_y change when mu falls, so the table gives, per tire and mu: T_r at alpha 0.01, 0.025, 0.05 rad, peak T_r and its alpha,
%   t at 0.025 rad and t(mu)/t(0.8). Plant side from params.json (PT(9)-(10), (13)-(14)). The duplicate preset 275/65R18 (identical to 205/60R15, K2) is left out.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_K3_trail_mu.txt, .csv, .png
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibtire');
    types = {'Light passenger car 205/60R15', 'Mid-size passenger car 235/45R18', 'Performance car 225/40R19', 'SUV 265/50R20', 'Commercial truck 295/75R22.5'};
    mus = [0.8 0.5 0.33 0.2];
    Vx = 20; hold_s = 0.25; al = unique(round([-0.2:0.005:0.2, -0.01, -0.025, -0.05], 6)); Fz = P.Fzf / 2;
    txtFile = fullfile(outDir, 'Plant_VDB_K3_trail_mu.txt'); fid = fopen(txtFile, 'w'); say = @(varargin) fprintf(fid, varargin{:});
    say('K3a T_r(alpha, mu): Plant and five VDB library tires (%s)\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    say('Front half axle F_z = %.1f N, Vx = %g m/s. Plant: e_c = %.3f m, t_0 = %.3f m, n_st = %g, trail shrinks with mu (PT(14)). Report only.\n\n', Fz, Vx, P.ec, P.t0, P.n);
    say('%-34s %5s | %8s %8s %8s | %8s %7s | %9s %9s\n', 'tire', 'mu', 'Tr.01', 'Tr.025', 'Tr.05', 'peak Tr', 'at rad', 't.025 (m)', 't/t(0.8)');
    ia = @(a) find(abs(al + a) < 1e-9, 1);      % alpha_VDB negative = positive Plant alpha
    rows = []; curves = struct();
    for im = 1:numel(mus)
        mu = mus(im);
        fPl = mfPlant(P, -al, mu, 2 * Fz); TrPl = trailPlant(P, -al, fPl, mu, 2 * Fz);
        tPl = P.t0 - 0; tpl = (TrPl * P.n - P.ec * fPl) ./ fPl;          % Plant pneumatic trail = e_p - e_c
        curves.Plant{im} = TrPl;
        [pk, ipk] = max(TrPl);
        if im == 1, tPl0 = tpl(ia(0.025)); end
        say('%-34s %5.2f | %8.2f %8.2f %8.2f | %8.2f %7.3f | %9.4f %9.3f\n', 'Plant (PT(13)-(14))', mu, TrPl(ia(0.01)), TrPl(ia(0.025)), TrPl(ia(0.05)), pk, -al(ipk), tpl(ia(0.025)), tpl(ia(0.025)) / tPl0);
        rows = [rows; 0, mu, TrPl(ia(0.01)), TrPl(ia(0.025)), TrPl(ia(0.05)), pk, -al(ipk), tpl(ia(0.025))]; %#ok<AGROW>
    end
    for i = 1:numel(types)
        t0v = NaN;
        for im = 1:numel(mus)
            mu = mus(im);
            [Fy, Mz] = stair(types{i}, Vx, Fz, al, hold_s, mu);
            Fa = 2 * Fy; Ma = 2 * Mz; Tr = (P.ec * Fa - Ma) / P.n;
            curves.(sprintf('t%d', i)){im} = Tr;
            [~, ipk] = max(abs(Tr)); tr = -Ma(ia(0.025)) / Fa(ia(0.025));
            if im == 1, t0v = tr; end
            say('%-34s %5.2f | %8.2f %8.2f %8.2f | %8.2f %7.3f | %9.4f %9.3f\n', types{i}, mu, Tr(ia(0.01)), Tr(ia(0.025)), Tr(ia(0.05)), max(abs(Tr)), abs(al(ipk)), tr, tr / t0v);
            rows = [rows; i, mu, Tr(ia(0.01)), Tr(ia(0.025)), Tr(ia(0.05)), max(abs(Tr)), abs(al(ipk)), tr]; %#ok<AGROW>
        end
    end
    fclose(fid); type(txtFile);
    writematrix(rows, fullfile(outDir, 'Plant_VDB_K3_trail_mu.csv'));
    f = figure('Visible', 'off', 'Position', [50 50 1200 800]);
    for im = 1:numel(mus)
        subplot(2, 2, im); hold on; grid on;
        for i = 1:numel(types), plot(-al, curves.(sprintf('t%d', i)){im}); end
        plot(-al, curves.Plant{im}, 'k--', 'LineWidth', 1.6); xlim([0 0.2]);
        title(sprintf('mu = %.2f', mus(im))); xlabel('alpha (rad)'); ylabel('T_r (N.m)');
        if im == 1, legend([types, {'Plant'}], 'Location', 'best', 'Interpreter', 'none', 'FontSize', 7); end
    end
    exportgraphics(f, fullfile(outDir, 'Plant_VDB_K3_trail_mu.png'), 'Resolution', 110); close(f);
end

function [F, M] = stair(tireType, Vx, Fz, al, hold_s, mu)
    mdl = 'tmp_n5_tire'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    set_param(blk, 'tireType', tireType); set_param(blk, 'vertType', 'None'); set_param(blk, 'plySteer', 'off'); set_param(blk, 'turnslip', 'off');
    set_param(blk, 'omegao', num2str(Vx / (0.97 * str2double(get_param(blk, 'UNLOADED_RADIUS'))), 12));
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(Vx); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz); 'ScaleFctrs', sprintf('[1;1;%g;0;ones(23,1)]', mu)};
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
