function ok = check_vdb_lowspeed()
%CHECK_VDB_LOWSPEED Night step N7 (milestone C5), test T6 of Documents/Shared/KeHoach_Plant_VDB.txt: no spurious oscillation of the VDB tire at low speed, and
%   the phase lag of F_y at a 2 Hz sine of the slip angle. Tire = one front half axle configured by vdb_tire_config.m (same Magic Formula as the Plant), mu = 0.8.
%   (a) Step of the slip angle (alpha_VDB 0 -> -0.02 rad at 1 s) at 20, 60 and 100 km/h: overshoot of F_y over its final value must be <= 1 % and the response
%       monotonic (no local extremum after the first 5 ms) at 20 km/h. The first-order time constant (time to 63 % of the final value) is printed for every speed.
%   (b) Sine alpha_VDB = -0.02 sin(2 pi 2 t) for 6 s: amplitude ratio and phase lag of F_y against the quasi-static force of the Plant formula (fit on the
%       last 2 s). The Plant has no tire lag, so the lag printed here is the tire lag the Plant lacks (printed only; plan T6 has no threshold on it).
%   Negative control of the oscillation detector: a synthetic response with a 10 % overshoot and ringing is passed through the same detector, which must flag it.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_T6_lowspeed.txt, _lowspeed.png.
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibtire');
    txtFile = fullfile(outDir, 'Plant_VDB_T6_lowspeed.txt'); fclose(fopen(txtFile, 'w'));
    say = @(varargin) appendTxt(txtFile, sprintf(varargin{:}));
    say('N7 test T6: low-speed behaviour and lag of the VDB tire (%s)\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    speeds = [20 60 100] / 3.6; ok = true; fig = figure('Visible', 'off', 'Position', [50 50 1100 700]);
    say('(a) step of alpha 0 -> -0.02 rad at 1 s\nspeed(km/h)  F_final(N)  overshoot(%%)  extrema after 5 ms  time to 63%% (ms)  detector\n');
    for i = 1:numel(speeds)
        Vx = speeds(i); t = (0:0.001:3)'; al = -0.02 * (t >= 1);
        F = runTire(P, Vx, t, Vx * tan(al));
        [os, nExt, t63, Ff] = stepStats(t, 2 * F, 1);
        c = os <= 1 && nExt == 0;
        if i == 1, ok = ok && c; end
        say('%6.0f       %8.1f    %7.3f        %d                   %7.1f           %s%s\n', Vx * 3.6, Ff, os, nExt, 1000 * t63, verdict(c), tern(i == 1, '  (T6 criterion, 20 km/h)', '  (reference)'));
        subplot(2, 2, 1); hold on; plot(t, 2 * F, 'DisplayName', sprintf('%g km/h', Vx * 3.6));
    end
    subplot(2, 2, 1); grid on; xlim([0.95 1.15]); xlabel('t (s)'); ylabel('F_y axle (N)'); legend('Location', 'best'); title('step of alpha at 1 s');
    % negative control of the detector
    tt = (0:0.001:3)'; Fs = -(1 - exp(-(tt - 1) .* 80) .* (cos(2 * pi * 25 * (tt - 1)) + 0.1)) .* (tt >= 1) * 1000;
    [osN, nN, ~, ~] = stepStats(tt, Fs, 1); cN = osN <= 1 && nN == 0; ok = ok && ~cN;
    say('negative control (synthetic ringing response): overshoot %.1f %%, %d extrema -> detector %s (expected NOT PASS)\n\n', osN, nN, verdict(cN));
    say('(b) sine alpha = -0.02 sin(2 pi 2 t): F_y against the quasi-static Plant force\nspeed(km/h)  amplitude ratio  phase lag (deg)  lag as time (ms)\n');
    for i = 1:numel(speeds)
        Vx = speeds(i); t = (0:0.001:6)'; al = -0.02 * sin(2 * pi * 2 * t);
        F = 2 * runTire(P, Vx, t, Vx * tan(al));
        Fq = mfP(P, -al, 0.8, P.Fzf);                              % quasi-static Plant force (alpha_plant = -alpha_VDB)
        w = t > 4;
        [ar, lag] = fitLag(t(w), Fq(w), F(w), 2);
        say('%6.0f       %8.4f         %8.3f         %8.2f\n', Vx * 3.6, ar, lag, 1000 * lag / 360 / 2);
        if i == 1, subplot(2, 2, 2); plot(t, Fq, t, F, '--'); grid on; xlim([4 5]); xlabel('t (s)'); ylabel('F_y (N)'); title('20 km/h, 2 Hz: Plant quasi-static (solid) and VDB (dashed)'); end
    end
    say('\nN7 T6 overall: %s (20 km/h step criterion and the detector negative control; the lag numbers of (b) are only reported)\n', verdict(ok));
    exportgraphics(fig, fullfile(outDir, 'Plant_VDB_T6_lowspeed.png'), 'Resolution', 110); close(fig);
    type(txtFile);
end

function F = runTire(P, Vx, t, vy)
    mdl = 'tmp_n7_tire'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    info = vdb_tire_config(blk, P, 'front', Vx);
    srcs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Vx', num2str(Vx, 12); 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(info.Fz); 'ScaleFctrs', '[1;1;0.8;0;ones(23,1)]'};
    for i = 1:size(srcs, 1)
        b = [mdl '/src_' srcs{i, 1}]; add_block('simulink/Sources/Constant', b, 'Value', srcs{i, 2}); wire(blk, b, srcs{i, 1});
    end
    assignin('base', 'n7_vy', [t, vy(:)]);
    add_block('simulink/Sources/From Workspace', [mdl '/src_Vy'], 'VariableName', 'n7_vy', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    wire(blk, [mdl '/src_Vy'], 'Vy');
    tw = [mdl '/log_Fy']; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', 'n7_Fy', 'SaveFormat', 'Timeseries'); wireOut(blk, 'Fy', tw);
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    F = interp1(o.n7_Fy.Time, squeeze(o.n7_Fy.Data), t); close_system(mdl, 0);
end

function [os, nExt, t63, Ff] = stepStats(t, F, t0)
    Ff = mean(F(t > t(end) - 0.5)); F0 = mean(F(t > t0 - 0.2 & t < t0));
    d = (F - F0) / (Ff - F0);                                      % normalized step response, 0 -> 1
    w = t >= t0; dd = d(w); tw = t(w) - t0;
    os = 100 * max(0, max(dd) - 1);
    ds = diff(dd); s = sign(ds(tw(1:end-1) > 0.005 & abs(ds) > 1e-6));
    nExt = sum(abs(diff(s)) > 0);                                    % direction reversals after the first 5 ms
    k = find(dd >= 0.632, 1); t63 = tw(k);
end

function [ar, lagDeg] = fitLag(t, ref, y, f)
    A = [sin(2 * pi * f * t), cos(2 * pi * f * t)];
    cr = A \ ref(:); cy = A \ y(:);
    ar = hypot(cy(1), cy(2)) / hypot(cr(1), cr(2));
    lagDeg = mod(rad2deg(atan2(cr(2), cr(1)) - atan2(cy(2), cy(1)) + pi), 360) - 180;   % positive = VDB lags the quasi-static force
end

function F = mfP(P, alpha, mu, Fz)
    D = mu .* Fz; B = P.Ca ./ (P.C .* D); u = B .* alpha;
    F = D .* sin(P.C .* atan(u - P.E .* (u - atan(u))));
end

function appendTxt(f, str)
    fid = fopen(f, 'a'); fprintf(fid, '%s', str); fclose(fid);
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
    if ~isKey(m, portName) || m(portName) > numel(ph.Inport), error('Input %s of %s unavailable', portName, dst); end
    add_line(bdroot(dst), get_param(src, 'PortHandles').Outport(1), ph.Inport(m(portName)));
end

function wireOut(src, portName, dst)
    m = portMap(src, 'Outport');
    if ~isKey(m, portName), error('No output %s in %s', portName, src); end
    ph = get_param(src, 'PortHandles');
    add_line(bdroot(src), ph.Outport(m(portName)), get_param(dst, 'PortHandles').Inport(1));
end
