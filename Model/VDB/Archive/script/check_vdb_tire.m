function ok = check_vdb_tire()
%CHECK_VDB_TIRE Night step N3 (milestone C1): tests T1 and T2 of Documents/Shared/KeHoach_Plant_VDB.txt for the lateral force of the VDB tire
%   (Combined Slip Wheel 2DOF, configured by vdb_tire_config.m) against the Plant Magic Formula PT(9)-(10), front and rear half axle, mu = 0.8, 0.5, 0.33, 0.24, 0.2.
%   Method: staircase of the lateral velocity (hold 0.25 s per step, quasi-static because the tire lag is a few ms) at Vx = 20 m/s, wheel free rolling,
%   alpha_VDB = atan(Vy/Vx) from -0.35 to +0.35 rad; the force of the half axle is doubled (axle = 2 wheels, plan N1); the Plant value is
%   F_plant(alpha_plant = -alpha_VDB) with the Plant formula evaluated independently from params.json (signs: R8).
%   T1: max over alpha of |F_VDB - F_Plant| <= 1 % of the Plant peak, for every mu and both axles.
%   T2a: peak of F_VDB within 1 % of mu*F_z.  T2b: slope at alpha = 0 within 1 % of the Plant slope (chord over +-0.0025 rad of both; the ratio to C_alpha is also printed,
%   it is below 1 at low mu only because the chord includes the cubic term: first version of the test compared the chord with C_alpha, see plan 10.9).  T2c: mu step at fixed alpha
%   (0.1 rad, mu 0.8 -> 0.2 at 1 s): force 20 ms after the step within 1 % of the Plant value at mu 0.2.
%   Negative controls (must report NOT PASS): (1) the VDB tire with PKY1 doubled (stiffness x2) in the T2b slope test; (2) the Plant formula with
%   the sign of F flipped and with C_alpha doubled in the T1 test. Output: Result/PRSM/Plant_VDB/Plant_VDB_T1T2_tire.txt, _tire.csv, _tire.png.
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibtire');
    Vx = 20; hold_s = 0.25;
    al = unique([-0.35:0.005:0.35, -0.0025, 0.0025]);            % VDB slip angles, rad
    vy = Vx * tan(al);
    mus = [0.8 0.5 0.33 0.24 0.2]; axles = {'front', 'rear'};
    fid = fopen(fullfile(outDir, 'Plant_VDB_T1T2_tire.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});
    say('N3 tests T1, T2 of the VDB tire against the Plant formula (%s)\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    say('axle   mu     peak_Plant(N)  peak_VDB(N)  T1 maxdev/peak(%%)  T2a peak/(mu Fz)  T2b slope/Plant  slope/Ca  T1      T2a     T2b\n');
    ok = true; rows = []; curves = struct();
    for a = 1:2
        Fz = tern(a == 1, P.Fzf, P.Fzr);
        for m = 1:numel(mus)
            [F, ~] = stair(P, axles{a}, Vx, vy, hold_s, mus(m), struct());
            Fv = 2 * F;                                           % axle force, VDB sign convention (tire frame)
            Fp = mf(P, -al, mus(m), Fz, P.Ca);                    % Plant value for alpha_plant = -alpha_VDB
            pk = max(abs(Fp));
            dev = max(abs(Fv(:) - Fp(:))) / pk;
            pkV = max(abs(Fv));
            i1 = find(al == -0.0025); i2 = find(al == 0.0025);
            slope = -(Fv(i2) - Fv(i1)) / (al(i2) - al(i1));      % Fy has the opposite sign of alpha_VDB
            slopeP = -(Fp(i2) - Fp(i1)) / (al(i2) - al(i1));          % the Plant formula measured by the SAME finite difference (the cubic term bends the +-0.0025 rad chord at low mu)
            c1 = dev <= 0.01; c2a = abs(pkV / (mus(m) * Fz) - 1) <= 0.01; c2b = abs(slope / slopeP - 1) <= 0.01;
            ok = ok && c1 && c2a && c2b;
            say('%-6s %.2f   %8.1f      %8.1f      %7.3f            %7.4f           %7.4f        %s  %s  %s\n', axles{a}, mus(m), pk, pkV, 100 * dev, pkV / (mus(m) * Fz), slope / P.Ca, ...
                verdict(c1), verdict(c2a), verdict(c2b));
            rows = [rows; a, mus(m), pk, pkV, dev, pkV / (mus(m) * Fz), slope / slopeP, slope / P.Ca]; %#ok<AGROW>
            curves(a, m).Fv = Fv; curves(a, m).Fp = Fp;
            if m == 1
                % negative controls on the Plant side of T1 (cheap): flipped sign, doubled stiffness
                d1 = max(abs(Fv(:) + Fp(:))) / pk; d2 = max(abs(Fv(:) - mf(P, -al, mus(m), Fz, 2 * P.Ca)')) / pk;
                say('       negative control (Plant side, mu 0.8, %s): sign flipped -> %.1f %% -> %s; Ca x2 -> %.1f %% -> %s (both expected NOT PASS)\n', axles{a}, 100 * d1, verdict(d1 <= 0.01), 100 * d2, verdict(d2 <= 0.01));
                ok = ok && d1 > 0.01 && d2 > 0.01;
            end
        end
    end
    % negative control on the VDB side: stiffness doubled, T2b slope (front, mu 0.8)
    [Fn, ~] = stair(P, 'front', Vx, vy, hold_s, 0.8, struct('PKY1', -2 * P.Ca / 2 / (P.Fzf / 2)));
    i1 = find(al == -0.0025); i2 = find(al == 0.0025);
    sN = -(2 * Fn(i2) - 2 * Fn(i1)) / (al(i2) - al(i1));
    say('negative control (VDB side, PKY1 x2, front, mu 0.8): slope/Ca = %.3f -> T2b %s (expected NOT PASS)\n', sN / P.Ca, verdict(abs(sN / P.Ca - 1) <= 0.01));
    ok = ok && abs(sN / P.Ca - 1) > 0.01;

    % T2c: mu step at fixed alpha, front axle and rear axle
    for a = 1:2
        Fz = tern(a == 1, P.Fzf, P.Fzr); aOne = 0.1; vOne = Vx * tan(aOne);
        t = (0:0.001:2)'; muT = 0.8 + (0.2 - 0.8) * (t >= 1);
        F = stairMuStep(P, axles{a}, Vx, vOne, t, muT);
        k = find(t >= 1.02, 1); Fnew = mf(P, -aOne, 0.2, Fz, P.Ca); Fold = mf(P, -aOne, 0.8, Fz, P.Ca);
        e = abs(2 * F(k) - Fnew) / Fnew; c = e <= 0.01; ok = ok && c;
        say('T2c mu step 0.8 -> 0.2 at alpha 0.1 rad, %s: F(0.98 s) = %.1f N (Plant %.1f), F(1.02 s) = %.1f N (Plant %.1f), error %.3f %% -> %s\n', axles{a}, 2 * F(find(t >= 0.98, 1)), Fold, 2 * F(k), Fnew, 100 * e, verdict(c));
    end
    say('\nN3 overall: %s\n', verdict(ok)); fclose(fid);
    writematrix(rows, fullfile(outDir, 'Plant_VDB_T1T2_tire.csv'));
    f = figure('Visible', 'off', 'Position', [50 50 1200 800]);
    for a = 1:2
        subplot(2, 2, a); hold on; grid on; col = lines(numel(mus));
        for m = 1:numel(mus), plot(al, curves(a, m).Fv, '-', 'Color', col(m, :)); plot(al, curves(a, m).Fp, '--k'); end
        title([axles{a} ' axle: F_y (solid VDB, dashed Plant) vs alpha_{VDB}']); xlabel('alpha_{VDB} (rad)'); ylabel('F_y (N)');
        subplot(2, 2, 2 + a); hold on; grid on;
        for m = 1:numel(mus), plot(al, curves(a, m).Fv(:) - curves(a, m).Fp(:), 'Color', col(m, :)); end
        title([axles{a} ' axle: F_{VDB} - F_{Plant} (N)']); xlabel('alpha_{VDB} (rad)'); legend(arrayfun(@(x) sprintf('mu %.2f', x), mus, 'UniformOutput', false), 'Location', 'best');
    end
    exportgraphics(f, fullfile(outDir, 'Plant_VDB_T1T2_tire.png'), 'Resolution', 110); close(f);
    type(fullfile(outDir, 'Plant_VDB_T1T2_tire.txt'));
end

function [F, Mz] = stair(P, axle, Vx, vy, hold_s, mu, ov)
% VDB half-axle force for each step of a lateral-velocity staircase (mean of the last 0.1 s of each step)
    mdl = 'tmp_n3_tire'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    info = vdb_tire_config(blk, P, axle, Vx, ov);
    n = numel(vy); t = (0:0.001:n * hold_s)'; idx = min(n, floor(t / hold_s) + 1); u = vy(idx)';
    assignin('base', 'n3_vy', [t, u(:)]);
    build(mdl, blk, info, Vx, mu, 'n3_vy', t(end));
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    tt = o.n3_Fy.Time; y = squeeze(o.n3_Fy.Data); z = squeeze(o.n3_Mz.Data);
    F = zeros(1, n); Mz = F;
    for i = 1:n
        w = tt > (i - 1) * hold_s + 0.15 & tt <= i * hold_s; F(i) = mean(y(w)); Mz(i) = mean(z(w));
    end
    close_system(mdl, 0);
end

function F = stairMuStep(P, axle, Vx, vOne, t, muT)
    mdl = 'tmp_n3_tire'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    info = vdb_tire_config(blk, P, axle, Vx);
    assignin('base', 'n3_vy', [t, vOne * ones(size(t))]); assignin('base', 'n3_mu', [t, muT]);
    build(mdl, blk, info, Vx, 'n3_mu', 'n3_vy', t(end));
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    F = interp1(o.n3_Fy.Time, squeeze(o.n3_Fy.Data), t);
    close_system(mdl, 0);
end

function build(mdl, blk, info, Vx, mu, vyVar, tEnd)
% wire the tire: scale factor vector [1;1;mu(t);0;ones(23,1)] built from a constant vector plus mu * unit vector
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(Vx); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(info.Fz)};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    add_block('simulink/Sources/From Workspace', [mdl '/src_Vy'], 'VariableName', vyVar, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    wire(blk, [mdl '/src_Vy'], 'Vy');
    if ischar(mu)
        add_block('simulink/Sources/From Workspace', [mdl '/src_mu'], 'VariableName', mu, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    else
        add_block('simulink/Sources/Constant', [mdl '/src_mu'], 'Value', num2str(mu));
    end
    add_block('simulink/Math Operations/Gain', [mdl '/mu_vec'], 'Gain', '[0;0;1;0;zeros(23,1)]', 'Multiplication', 'Matrix(K*u)');
    add_block('simulink/Sources/Constant', [mdl '/sf_base'], 'Value', '[1;1;0;0;ones(23,1)]');
    add_block('simulink/Math Operations/Add', [mdl '/sf_sum'], 'Inputs', '++');
    add_line(mdl, 'src_mu/1', 'mu_vec/1'); add_line(mdl, 'sf_base/1', 'sf_sum/1'); add_line(mdl, 'mu_vec/1', 'sf_sum/2');
    wire(blk, [mdl '/sf_sum'], 'ScaleFctrs');
    for nm = {'Fy', 'Mz'}
        tw = [mdl '/log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['n3_' nm{1}], 'SaveFormat', 'Timeseries'); wireOut(blk, nm{1}, tw);
    end
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', num2str(tEnd), 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
end

function F = mf(P, alpha, mu, Fz, Ca)
    D = mu .* Fz; B = Ca ./ (P.C .* D); u = B .* alpha;
    F = D .* sin(P.C .* atan(u - P.E .* (u - atan(u))));
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
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
    if ~isKey(m, portName) || m(portName) > numel(ph.Inport), error('Input %s of %s unavailable. Inputs: %s', portName, dst, strjoin(keys(m), ', ')); end
    add_line(bdroot(dst), get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s. Outputs: %s', portName, src, strjoin(keys(m), ', ')); end
    ph = get_param(src, 'PortHandles');
    add_line(bdroot(src), ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
