function ok = check_vdb_body(solver, mode)
%CHECK_VDB_BODY Night step N4 (milestone C2): tests T4 and T5 of Documents/Shared/KeHoach_Plant_VDB.txt for the VDB body 'Vehicle Body 3DOF Single Track'.
%   T5 (body driven by the Plant forces): the body (velocity mode, Cy = 0, no drag) receives v(t) from the baseline as xdotin and the Plant forces of the
%   baseline as external force and moment, FExt = [0; F_yf + F_yr; 0], MExt = [0; 0; l_f*F_yf - l_r*F_yr] (signs from R8). Compared with the Plant
%   baseline over every case of N2 (STEADY, SLIP, WEAVE, CALIB, both T_a levels):
%     gamma and a_y: RMS(difference)/max|Plant signal| <= 1 %;  v: max |xdot - v| <= 0.5 km/h in the windows where v is held (|dv/dt| < 0.02 m/s^2),
%     <= 1 km/h in the windows where v changes (|dv/dt| > 0.1 m/s^2; includes SLIP 90 -> 45 km/h).
%   Because the Plant PT(3) is beta' = F/(m v) - gamma while the VDB body integrates ydot, they differ by dv/dt*beta when v changes; this term is computed
%   from the baseline (beta by integrating PT(3)) and printed next to the errors of the changing-v windows (plan 10.2, N4).
%   T4 (does mu soften the tire INSIDE the 3DOF block?): body with its own tire (Cy_f = Cy_r = C_alpha, muMode on), steady cornering at a small steer angle
%   (linear range) for mu = 0.8 and 0.3: the ratio of the steady yaw rate and of the front slope F_yf/alpha_f is printed; answer YES if they change by
%   more than 1 %. Answered by the measurement, no pass/fail.
%   Negative controls (must report NOT PASS on STEADY, T_a = 0): the sign of the force flipped; Izz doubled.
%   Output: Result/PRSM/Plant_VDB/Plant_VDB_T4T5_body.txt, _body.csv, _body.png.
    if nargin < 1, solver = 'ode23t'; end
    if nargin < 2, mode = 'all'; end                                 % 'T4' = only the T4 measurement (T5 runs are long and may fail, see plan 10.9)
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB'); bDir = fullfile(outDir, 'baseline');
    P = load_vdb_params(modelDir);
    load_system('vehdynlibeom');
    txtFile = fullfile(outDir, 'Plant_VDB_T4T5_body.txt'); fclose(fopen(txtFile, 'w'));
    say = @(varargin) appendTxt(txtFile, sprintf(varargin{:}));         % appended line by line so progress is visible during a long run
    say('N4 tests T4, T5 of the VDB body (%s)\n\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    tags = {'STEADY', 'SLIP', 'WEAVE', 'CALIB'}; negTag = 'STEADY';
    if strcmp(mode, 'T4'), tags = {}; end
    if strcmp(mode, 'WEAVE'), tags = {'WEAVE'}; negTag = 'WEAVE'; end        % WEAVE is the only case that ran to the end with ode23t (plan 10.9)
    ok = true; rows = []; keep = struct();
    say('T5: body driven by the Plant forces\ncase    Ta  err(gamma)%%  err(a_y)%%  v err held(km/h)  v err change(km/h)  max|dv/dt*beta| (m/s^2)  RMS(dv/dt*beta)/max|a_y| %%  T5\n');
    for k = 1:numel(tags)
        for lv = [0 2]
            S = load(fullfile(bDir, sprintf('Plant_%s_Ta%d.mat', tags{k}, lv)));
            [R, msg] = run_vdb_body(P, S, 1, 1, solver);
            if ~isempty(msg)
                say('%-7s %d   RUN ERROR: %s -> NOT CONCLUDED\n', tags{k}, lv, msg); ok = false; continue;
            end
            [eG, eA, eVh, eVc, dvb, dvbr] = metrics(S, R);
            c = eG <= 0.01 && eA <= 0.01 && eVh <= 0.5 && eVc <= 1.0; ok = ok && c;
            say('%-7s %d   %7.4f     %7.4f    %7.3f           %7.3f             %8.4f                 %7.4f                       %s\n', tags{k}, lv, 100 * eG, 100 * eA, eVh, eVc, dvb, 100 * dvbr, verdict(c));
            rows = [rows; k, lv, eG, eA, eVh, eVc, dvb, dvbr]; %#ok<AGROW>
            keep(k, lv / 2 + 1).S = S; keep(k, lv / 2 + 1).R = R;
        end
    end
    % negative controls
    S = load(fullfile(bDir, ['Plant_' negTag '_Ta0.mat']));
    if strcmp(mode, 'T4'), negIdx = []; else, negIdx = 1:2; end
    if ~isempty(negIdx), [R1, m1] = run_vdb_body(P, S, -1, 1, solver); [R2, m2] = run_vdb_body(P, S, 1, 2, solver); end
    for q = negIdx
        if q == 1, R = R1; m = m1; nm = 'force sign flipped'; else, R = R2; m = m2; nm = 'Izz doubled'; end
        if ~isempty(m), say('negative control (%s): RUN ERROR %s\n', nm, m); ok = false; continue; end
        [eG, ~, ~, ~, ~, ~] = metrics(S, R); c = eG <= 0.01;
        say('negative control (%s, %s, Ta 0): err(gamma) = %.2f %% -> T5 %s (expected NOT PASS)\n', nm, negTag, 100 * eG, verdict(c)); ok = ok && ~c;
    end
    % T4
    say('\nT4: tire inside the 3DOF block, steady cornering, v = 20 m/s, Cy_f = Cy_r = C_alpha = %.0f N/rad, muMode on\n', P.Ca);
    res = zeros(2, 4);
    mus = [0.8 0.3];
    for i = 1:2
        [r, ay, alf] = steadyT4(P, mus(i), 0.01);
        res(i, :) = [mus(i), r, ay, alf];
        say('  mu %.2f, steer 0.01 rad: yaw rate %.5f rad/s, a_y %.4f m/s^2, front slip angle %.6f rad, front slope F_yf/|alpha_f| = %.0f N/rad\n', mus(i), r, ay, alf, P.m * ay * P.b / (P.a + P.b) / abs(alf));
    end
    sl = zeros(1, 2);
    for i = 1:2, sl(i) = P.m * res(i, 3) * P.b / (P.a + P.b) / abs(res(i, 4)); end
    ratio = sl(2) / sl(1);
    say('  front slope ratio mu 0.3 / mu 0.8 = %.4f (mu ratio = %.4f); yaw-rate ratio = %.4f (the yaw rate hardly changes because a_y = v*r is fixed by geometry)\n', ratio, 0.3 / 0.8, res(2, 2) / res(1, 2));
    say('  -> mu %s the slope of the tire inside the 3DOF block (threshold 1 %%); answer to T4: %s\n', tern(abs(ratio - 1) > 0.01, 'SOFTENS', 'does NOT soften'), tern(abs(ratio - 1) > 0.01, 'YES, the internal tire gets softer in proportion to mu, so it cannot meet Y4; the external Plant-like tire of T1/T2 must be used', 'NO'));
    [r3, ay3, ~] = steadyT4(P, 0.3, 0.1); [r8, ay8, ~] = steadyT4(P, 0.8, 0.1);
    say('  large steer 0.1 rad: a_y mu 0.8 = %.3f, mu 0.3 = %.3f m/s^2 (limit mu*g = %.2f, %.2f)\n', ay8, ay3, 0.8 * P.g, 0.3 * P.g);
    say('\nN4 overall: %s\n', verdict(ok));
    writematrix(rows, fullfile(outDir, 'Plant_VDB_T4T5_body.csv'));
    if ~strcmp(mode, 'all'), type(txtFile); return; end
    f = figure('Visible', 'off', 'Position', [50 50 1200 900]); lab = {'gamma', 'a_y', 'v'};
    for j = 1:3
        subplot(3, 2, 2 * j - 1); S = keep(2, 2).S; R = keep(2, 2).R; hold on; plot(S.t, S.(lab{j})); plot(S.t, R.(lab{j}), '--'); grid on; ylabel(lab{j}, 'Interpreter', 'none');
        if j == 1, title('SLIP, Ta = 2: Plant (solid) and VDB body (dashed)'); end
        subplot(3, 2, 2 * j); plot(S.t, R.(lab{j}) - S.(lab{j})); grid on; ylabel(['VDB - Plant ' lab{j}], 'Interpreter', 'none');
    end
    exportgraphics(f, fullfile(outDir, 'Plant_VDB_T4T5_body.png'), 'Resolution', 110); close(f);
    type(fullfile(outDir, 'Plant_VDB_T4T5_body.txt'));
end

function [eG, eA, eVh, eVc, dvb, dvbr] = metrics(S, R)
    eG = sqrt(mean((R.gamma - S.gamma).^2)) / max(abs(S.gamma));
    eA = sqrt(mean((R.a_y - S.a_y).^2)) / max(abs(S.a_y));
    dv = gradient(S.v, S.t); dvs = movmean(dv, 200);
    held = abs(dvs) < 0.02; chg = abs(dvs) > 0.1;
    ev = abs(R.v - S.v) * 3.6;
    eVh = tern(any(held), max(ev(held)), 0); eVc = tern(any(chg), max(ev(chg)), 0);
    % beta of PT(3): beta' = F/(m v) - gamma, integrated from the baseline (small initial beta = 0)
    F = S.a_y * 1;                                                  % a_y = F/m in the Plant
    beta = cumtrapz(S.t, F ./ max(S.v, 1) - S.gamma);
    term = dvs .* beta;
    dvb = max(abs(term)); dvbr = sqrt(mean(term.^2)) / max(abs(S.a_y));
end

function [r, ay, alf] = steadyT4(P, mu, delta)
    mdl = 'tmp_n4_t4'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); blk = [mdl '/Body']; add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', blk);
    vdb_body_config(blk, P, 20);
    set_param(blk, 'muMode', 'on'); set_param(blk, 'extFMode', 'off'); set_param(blk, 'extMMode', 'off');
    set_param(blk, 'Cy_f', num2str(P.Ca)); set_param(blk, 'Cy_r', num2str(P.Ca));
    ph = get_param(blk, 'PortHandles'); vals = {num2str(delta), '20', sprintf('[%g;%g]', mu, mu)}; nmIn = {'WhlAngF', 'xdotin', 'Mu'}; idx = zeros(1, 3);
    for i = 1:3                                                      % ports looked up BY NAME (the order changes when FExt and MExt are off)
        h = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Name', nmIn{i});
        idx(i) = str2double(get_param(h{1}, 'Port'));
    end
    for i = 1:3
        b = [mdl '/s' num2str(i)]; add_block('simulink/Sources/Constant', b, 'Value', vals{i}); add_line(mdl, get_param(b, 'PortHandles').Outport(1), ph.Inport(idx(i)));
    end
    tw = [mdl '/lg1']; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', 'n4_r', 'SaveFormat', 'Timeseries'); add_line(mdl, ph.Outport(5), get_param(tw, 'PortHandles').Inport(1));
    busLog(mdl, ph.Outport(1), {'BdyFrm.Cg.Acc.ay', 'BdyFrm.Cg.Vel.ydot'}, {'n4_ay', 'n4_ydot'});
    set_param(mdl, 'Solver', 'ode23t', 'StopTime', '15', 'MaxStep', '0.002', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    r = o.n4_r.Data(end); ay = 9.80665 * o.n4_ay.Data(end); ydot = o.n4_ydot.Data(end);
    alf = atan((ydot + P.a * r) / 20) - delta;                       % front slip angle, definition of the VDB documentation (R8)
    close_system(mdl, 0);
end

function busLog(mdl, srcPort, sigs, vars)
% log only the named signals of the Info bus (logging the whole bus used 11 GB in a 100 s run)
    bs = [mdl '/bus_sel']; add_block('simulink/Signal Routing/Bus Selector', bs);
    add_line(mdl, srcPort, get_param(bs, 'PortHandles').Inport(1));
    set_param(bs, 'OutputSignals', strjoin(sigs, ','));
    ph = get_param(bs, 'PortHandles');
    for i = 1:numel(sigs)
        tw = [mdl '/buslog' num2str(i)]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', vars{i}, 'SaveFormat', 'Timeseries');
        add_line(mdl, ph.Outport(i), get_param(tw, 'PortHandles').Inport(1));
    end
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
