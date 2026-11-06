function fit = fit_vdb_trail(mus)
%FIT_VDB_TRAIL Choose QBZ1, QCZ1, QDZ1, QEZ1 of the VDB wheel so that its pneumatic trail t(alpha) = -Mz/Fy follows the trail of the Plant, eq. (17) (brush model):
%     t_Plant(alpha) = t_0 * max(0, 1 - tan(alpha) * C_alpha / (3 mu F_z)),   alpha >= 0   (the model is odd in alpha)
%   fit = fit_vdb_trail([0.3 0.5 0.8])   mus = adhesion levels fitted together (default 0.3, 0.5, 0.8); writes Model/VDB/Blocks/data/vdb_trail_fit.json
%   Method (planned before running): everything else of the trail model is switched off (load, camber, pressure, horizontal shift, residual moment, Fx effect: zeroExtras);
%   per mu the wheel is run on a slow slip-angle ramp (0.05 rad/s, front wheel, F_z = F_zf/2, v = 20 m/s) to measure t_sim(alpha); the four coefficients minimise
%   sum over mu and alpha in [0.002, 0.22] rad of ((t_model(alpha) - t_Plant(alpha)) * F_y(alpha))^2 (error weighted by the lateral force, because T_r = (e_c + t) F_y / n),
%   where t_model is the written-out MF trail equation PLUS the measured difference d = t_sim - t_formula of the previous pass (the block differs a little from the equation);
%   passes are repeated until the largest |t_sim - t_Plant| stops improving (at most 5). The residual is reported, not hidden: the MF bell and the straight brush line differ in shape.
    if nargin < 1, mus = [0.3 0.5 0.8]; end
    scriptDir = fileparts(mfilename('fullpath'));
    blocksDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(blocksDir));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    load_plant; P = load_vdb_params(modelDir);
    load_system('vehdynlibtire');
    alg = (0.002:0.002:0.22)';
    % Bounded version (2026-11-07, planned before running): QDZ1 = t_0 / R_0 fixed so that t(0) = t_0; QBZ1, QCZ1, QEZ1 limited to the range of real tyres:
    % QBZ1 6-12 (Pacejka [2] Table 4.2: 6; Table A3.1 measured 205/60R15: 8.964; VDB library tyre: 11.67), QCZ1 1.05-1.29 (1.05; 1.180; 1.29), QEZ1 -4..0 (-10 hypothetical, -1.609 measured, -2.2 library).
    lo = [6, 1.05, -4]; hi = [12, 1.29, 0];
    x = [9, 1.15, -2, tireQDZ1(P)];                 % start inside the bounds; x(4) = QDZ1 fixed
    d = cell(1, numel(mus)); best = inf; xbest = x; hist = zeros(0, 3);
    for pass = 1:5
        ov = zeroExtras(); ov.QBZ1 = x(1); ov.QCZ1 = x(2); ov.QEZ1 = x(3); ov.QDZ1 = x(4);
        T = cell(1, numel(mus)); err = zeros(1, numel(mus));
        for m = 1:numel(mus)
            [al, Fy, Mz, c] = rampRun(P, ov, mus(m));
            ts = interp1(al, -Mz ./ Fy, alg); Fyg = interp1(al, Fy, alg);
            tf = mfTrail(alg, c);
            d{m} = ts - tf;                                  % block minus written-out equation at the coefficients just used
            tp = planTrail(alg, P, mus(m));
            T{m} = struct('ts', ts, 'Fy', Fyg, 'tp', tp, 'c', c);
            err(m) = max(abs(ts - tp));
        end
        fprintf('pass %d: QBZ1 %.4g QCZ1 %.4g QEZ1 %.4g QDZ1 %.4g | max |t_sim - t_Plant| per mu [mm]: %s\n', pass, x, sprintf('%.2f ', 1e3 * err));
        hist(end + 1, :) = [pass, max(err), 0]; %#ok<AGROW>
        if max(err) < best, best = max(err); xbest = x; end
        if pass > 1 && max(err) > 0.98 * hist(pass - 1, 2), break; end   % no further improvement
        obj = @(q) objective(box(q, lo, hi), x(4), alg, T, d, mus);
        qb = Inf;
        for s0 = [9 1.15 -2; 7 1.08 -3; 11 1.25 -1]'
            q0 = asin(2 * (s0 - lo') ./ (hi' - lo') - 1)';
            [q, fq] = fminsearch(obj, q0, optimset('MaxFunEvals', 4000, 'MaxIter', 4000, 'TolX', 1e-8, 'TolFun', 1e-16));
            if fq < qb, qb = fq; qbest = q; end
        end
        x(1:3) = box(qbest, lo, hi);
    end
    fit = struct('QBZ1', xbest(1), 'QCZ1', xbest(2), 'QDZ1', xbest(4), 'QEZ1', xbest(3), 'max_abs_err_mm', 1e3 * best, 'mus', mus);
    fprintf('chosen: QBZ1 %.6g QCZ1 %.6g QDZ1 %.6g QEZ1 %.6g (max |t_sim - t_Plant| %.2f mm over the fitted mu)\n', xbest(1), xbest(2), xbest(4), xbest(3), 1e3 * best);
    outDir = fullfile(blocksDir, 'data'); if ~isfolder(outDir), mkdir(outDir); end
    zn = fieldnames(zeroExtras());
    fid = fopen(fullfile(outDir, 'vdb_trail_fit.json'), 'w'); fprintf(fid, '%s\n', jsonencode(struct('fitted', struct('QBZ1', xbest(1), 'QCZ1', xbest(2), 'QDZ1', xbest(4), 'QEZ1', xbest(3)), ...
        'zeroed', {zn}, 'max_abs_err_mm', 1e3 * best, 'mus', mus, 'bounds', struct('QBZ1', [6 12], 'QCZ1', [1.05 1.29], 'QEZ1', [-4 0]), ...
        'target', 'Plant eq. (17), t_0 = 0.025 m, per wheel C_alpha/2, F_z/2', 'date', '2026-11-07'))); fclose(fid);
end

function x = box(q, lo, hi)
% map unconstrained q to [lo, hi] (sine transform)
    x = lo + (hi - lo) .* (sin(q(:)') + 1) / 2;
end

function q1 = tireQDZ1(P)
% QDZ1 = t_0 / R_0 so that the pneumatic trail at zero slip equals t_0 (Dt = F_z (R_0/F_z0) QDZ1 = R_0 QDZ1 when F_z = FNOMIN)
    load_system('vehdynlibtire'); mdl = 'tmp_fit_r0'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); b = [mdl '/T']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', b); vdb_tire_config(b, P, 'front', 20, struct());
    q1 = P.t0 / str2double(get_param(b, 'UNLOADED_RADIUS')); close_system(mdl, 0);
end

function J = objective(x3, qdz1, alg, T, d, mus)
    J = 0;
    for m = 1:numel(mus)
        c = T{m}.c; c.QBZ1 = x3(1); c.QCZ1 = x3(2); c.QEZ1 = x3(3); c.QDZ1 = qdz1;
        tm = mfTrail(alg, c) + d{m};
        J = J + sum(((tm - T{m}.tp) .* T{m}.Fy).^2);
    end
end

function tp = planTrail(al, P, mu)
% Plant eq. (17), pneumatic part, per wheel: t_0 * max(0, 1 - tan(alpha) C_alpha/(3 mu F_z)) (C_alpha and F_z per wheel: the ratio equals the axle ratio)
    tp = P.t0 * max(0, 1 - tan(al) * (P.Ca / 2) / (3 * mu * P.Fzf / 2));
end

function ov = zeroExtras()
% everything of the trail model except QBZ1, QCZ1, QDZ1, QEZ1 off: load, camber, pressure, horizontal shift, residual moment, Fx effect
    ov = struct();
    for nm = {'QBZ2', 'QBZ3', 'QBZ4', 'QBZ5', 'QBZ6', 'QBZ9', 'QBZ10', 'QDZ2', 'QDZ3', 'QDZ4', 'QDZ6', 'QDZ7', 'QDZ8', 'QDZ9', 'QDZ10', 'QDZ11', ...
              'QEZ2', 'QEZ3', 'QEZ4', 'QEZ5', 'QHZ1', 'QHZ2', 'QHZ3', 'QHZ4', 'PPZ1', 'PPZ2', 'SSZ1', 'SSZ2', 'SSZ3', 'SSZ4'}
        ov.(nm{1}) = 0;
    end
end

function t = mfTrail(al, c)
% MF-Tyre 6.1 pneumatic trail equation at zero camber, lambda = 1
    dfz = (c.Fz - c.Fz0) / c.Fz0; dpi = (c.p - c.pnom) / c.pnom;
    at = al + c.QHZ1 + c.QHZ2 * dfz;
    Bt = c.QBZ1 + c.QBZ2 * dfz + c.QBZ3 * dfz^2; Ct = c.QCZ1;
    Dt = c.Fz * (c.R0 / c.Fz0) * (c.QDZ1 + c.QDZ2 * dfz) * (1 - c.PPZ1 * dpi);
    Et = (c.QEZ1 + c.QEZ2 * dfz + c.QEZ3 * dfz^2) * (1 + c.QEZ4 * (2 / pi) * atan(Bt * Ct * at));
    t = Dt .* cos(Ct * atan(Bt * at - Et .* (Bt * at - atan(Bt * at)))) .* cos(al);
end

function [al, Fy, Mz, c] = rampRun(P, ov, mu)
    mdl = 'tmp_fit_trail'; if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl); b = [mdl '/T']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', b);
    vx = 20; vdb_tire_config(b, P, 'front', vx, ov);
    Re = str2double(get_param(b, 'UNLOADED_RADIUS')); set_param(b, 'omegao', sprintf('%.12g', vx / (0.97 * Re)));
    Fz = P.Fzf / 2; rate = 0.05;
    cs = {'BrkPrs', '0'; 'AxlTrq', '0'; 'Camber', '0'; 'YawRate', '0'; 'Prs', '220000'; 'Gnd', '0'; 'Fext', num2str(Fz, 12); 'Vx', num2str(vx, 12)};
    for i = 1:size(cs, 1), cc = sprintf('%s/c_%s', mdl, cs{i, 1}); add_block('simulink/Sources/Constant', cc, 'Value', cs{i, 2}); ph = get_param(cc, 'PortHandles'); add_line(mdl, ph.Outport(1), portIn(b, cs{i, 1})); end
    add_block('simulink/Sources/Ramp', [mdl '/rampVy'], 'Slope', num2str(-rate * vx, 12), 'Start', '0.5');
    add_line(mdl, get_param([mdl '/rampVy'], 'PortHandles').Outport(1), portIn(b, 'Vy'));
    add_block('simulink/Sources/Constant', [mdl '/sf'], 'Value', sprintf('[1;1;%.12g;0;ones(23,1)]', mu)); add_line(mdl, get_param([mdl '/sf'], 'PortHandles').Outport(1), portIn(b, 'ScaleFctrs'));
    for nm = {'Fy', 'Mz'}
        add_block('simulink/Sinks/To Workspace', [mdl '/lg' nm{1}], 'VariableName', ['ft_' nm{1}], 'SaveFormat', 'Timeseries'); add_line(mdl, portOut(b, nm{1}), get_param([mdl '/lg' nm{1}], 'PortHandles').Inport(1));
    end
    ph = get_param(b, 'PortHandles');
    for k = 1:numel(ph.Outport), if get_param(ph.Outport(k), 'Line') < 0, t = sprintf('%s/Tm%d', mdl, k); add_block('simulink/Sinks/Terminator', t); add_line(mdl, ph.Outport(k), get_param(t, 'PortHandles').Inport(1)); end, end
    tEnd = 0.5 + 0.23 / rate;
    set_param(mdl, 'Solver', 'ode23tb', 'MaxStep', '2e-3', 'RelTol', '1e-7', 'AbsTol', '1e-10', 'StopTime', num2str(tEnd), 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
    [t, iu] = unique(o.ft_Fy.Time, 'last'); Fy = squeeze(o.ft_Fy.Data); Fy = Fy(iu);
    [tm, im] = unique(o.ft_Mz.Time, 'last'); Mz = interp1(tm, squeeze(o.ft_Mz.Data(im)), t);
    al = max(0, rate * (t - 0.5)); ok = al > 0 & abs(Fy) > 1; al = al(ok); Fy = Fy(ok); Mz = Mz(ok);
    [al, iu] = unique(al, 'last'); Fy = Fy(iu); Mz = Mz(iu);
    c = struct('R0', str2double(get_param(b, 'UNLOADED_RADIUS')), 'Fz0', str2double(get_param(b, 'FNOMIN')), 'Fz', Fz, 'p', 220000, 'pnom', str2double(get_param(b, 'NOMPRES')));
    for nm = {'QBZ1', 'QBZ2', 'QBZ3', 'QCZ1', 'QDZ1', 'QDZ2', 'QEZ1', 'QEZ2', 'QEZ3', 'QEZ4', 'QHZ1', 'QHZ2', 'PPZ1'}, c.(nm{1}) = str2double(get_param(b, nm{1})); end
    close_system(mdl, 0);
end

function h = portIn(blk, name)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Name', name);
    ph = get_param(blk, 'PortHandles'); h = ph.Inport(str2double(get_param(b{1}, 'Port')));
end

function h = portOut(blk, name)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Name', name);
    ph = get_param(blk, 'PortHandles'); h = ph.Outport(str2double(get_param(b{1}, 'Port')));
end
