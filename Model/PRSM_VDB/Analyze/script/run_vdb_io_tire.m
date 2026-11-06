function run_vdb_io_tire(stage)
%RUN_VDB_IO_TIRE One-at-a-time port test of the VDB tire block (Combined Slip Wheel 2DOF, configuration S2) in VDBTire.mdl.
%   Plan: Documents/Shared/KeHoach_Plant_VDB.txt 12.2, 12.9 (table B), 12.10 (tire part: cases TC1-TC40 from the working points L0, L1), run rules:
%   Documents/Shared/ChayTu_VDB_IO.txt (section 8: TCW1, TCW2 on PlantVDBS2.slx, in memory only).
%   run_vdb_io_tire(stage), stage in 'all' (default), 'tc1' (base points + TC1-TC5b, TC32), 'cells' (TC6-TC31), 'misc' (TC33-TC38), 'tcw', 'report'.
%   Every case changes ONE input by a step at t_s = 0.5 s (all other inputs keep the base value), runs 1 s, and compares every output of the block with
%   (a) the answer computed here from the Plant equations through the mapping table (expected-to-change outputs, tolerance 1e-6 relative, read in 0.9-1.0 s),
%   (b) the base case (expected-not-to-change outputs, tolerance 1e-9 relative), or (c) is only recorded. All inputs of all cases (also the base) get the
%   same break points at t_s so that the solver takes the same steps in the base and in the case (a difference then comes from the port, not from the solver).
%   Results: Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_tire_*. The model is never saved. The csv is appended one case at a time (resumable).
    if nargin < 1, stage = 'all'; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    analyzeDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(analyzeDir));
    addpath(modelDir); setup_paths;
    addpath(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB', 'script')); addpath(analyzeDir);
    fold = use_sim_tmp();
    Simulink.fileGenControl('set', 'CacheFolder', fullfile(fold, 'cache_tire'), 'CodeGenFolder', fullfile(fold, 'codegen_tire'), 'createDir', true);
    ctx.P = load_vdb_params(modelDir);
    ctx.modelDir = modelDir; ctx.analyzeDir = analyzeDir; ctx.mdl = 'VDBTire';
    ctx.outDir = fullfile(result_dir('Plant_VDB'), 'Analyze'); if ~exist(ctx.outDir, 'dir'), mkdir(ctx.outDir); end
    ctx.csv = fullfile(ctx.outDir, 'Plant_VDB_IO_tire_cases.csv');
    ctx.ts = 0.5; ctx.tg = (0:1e-4:1)';
    ctx.win = ctx.tg >= 0.9;                                    % read-out window (after 280 lag constants)
    ctx.all = true(size(ctx.tg)); ctx.all(abs(ctx.tg - ctx.ts) < 1e-12) = false;   % whole run without the one sample at the step
    F0 = 0.8 * ctx.P.Fzf / 2;
    ctx.ref = struct('Omega', 40, 'Fx', F0, 'Fy', F0, 'Fz', ctx.P.Fzf / 2, 'Mx', 100, 'My', 100, 'Mz', 100, 'Alpha', 0.03, 'Kappa', 0.02);
    ctx.outs = {'Omega', 'Fx', 'Fy', 'Fz', 'Mx', 'My', 'Mz', 'Alpha', 'Kappa'};
    load_system(ctx.mdl);
    if ~exist(ctx.csv, 'file')
        fid = fopen(ctx.csv, 'w', 'n', 'UTF-8');
        fprintf(fid, 'ma_ca,cong_doi,goc,dau_ra,loai,do_max,dap_an_max,sai_lech,nguong,ket_qua,sai_lech_gia_thuyet_sai,phan_biet,ghi_chu\n'); fclose(fid);
    end
    specs = caseTable(ctx);
    ctx.cache = containers.Map();
    groupOf = struct('tc1', {{'GL0', 'GL1', 'TC1', 'TC2', 'TC3', 'TC4a', 'TC4b', 'TC5', 'TC5b', 'TC32'}}, 'misc', {{'TC33', 'TC34', 'TC35a', 'TC35b', 'TC36', 'TC37', 'TC38'}});
    if any(strcmp(stage, {'all', 'tc1', 'cells', 'misc'}))
        for k = 1:numel(specs)
            s = specs(k);
            if strcmp(stage, 'tc1') && ~ismember(s.code, groupOf.tc1), continue; end
            if strcmp(stage, 'misc') && ~ismember(s.code, groupOf.misc), continue; end
            if strcmp(stage, 'cells') && ~strncmp(s.code, 'TCc', 3), continue; end
            ctx = runSpec(ctx, s);
        end
    end
    if any(strcmp(stage, {'all', 'tcw'})), runTcw(ctx); end
    if any(strcmp(stage, {'all', 'report'})), makeReport(ctx); end
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function specs = caseTable(ctx)
    P = ctx.P; win = ctx.win;
    none = struct('out', {}, 'ans', {}, 'hyp', {}, 'name', {});
    mk = @(o, a, h, nm) struct('out', o, 'ans', a, 'hyp', h, 'name', nm);
    bm = @(S0, o) mean(S0.(o)(win));
    specs = struct('code', {}, 'also', {}, 'port', {}, 'base', {}, 'chg', {}, 'doi', {}, 'same', {}, 'auto', {}, 'extra', {}, 'k', {}, 'nv', {});
    add = @(code, port, base, chg, doi, same, auto, extra) struct('code', code, 'also', {{}}, 'port', port, 'base', base, 'chg', chg, 'doi', doi, 'same', {same}, 'auto', auto, 'extra', extra, 'k', 0, 'nv', 0);
    noExtra = @(ctx, b, n, S0, S1, amp) {};
    % base points: no change, the outputs with an answer are compared with the Plant equations (the answer of L1 is PT(10) at alpha_f = 0.03, mu 0.8)
    specs(end+1) = add('GL0', 'ca goc L0 (khong truot)', 'L0', @(b, amp) b, @(b, n, S0) [mk('Alpha', 0, NaN, ''), mk('Fy', 0, NaN, ''), mk('Fz', n.Fext, NaN, '')], {}, -1, noExtra);
    specs(end+1) = add('GL1', 'ca goc L1 (alpha_f = 0.03 rad)', 'L1', @(b, amp) b, ...
        @(b, n, S0) [mk('Alpha', pred(P, n).a, n.Vy / n.Vx * 0 + atan(n.Vy / n.Vx) * 1.001, 'goc sai 0.1 phan tram'), mk('Fy', pred(P, n).Fy, -pred(P, n).Fy, 'dau nguoc'), mk('Fz', n.Fext, NaN, '')], {}, -1, noExtra);
    % TC1: Vy, alpha 0.03 -> 0.06 rad (retry with amp = 2: 0.09)
    specs(end+1) = add('TC1', 'Vy (alpha 0.03 -> 0.06 rad)', 'L1', @(b, amp) setf(b, 'Vy', -b.Vx * tan(0.03 * (1 + amp))), ...
        @(b, n, S0) [mk('Alpha', pred(P, n).a, n.Vy / n.Vx, 'goc nho Vy/Vx'), mk('Fy', pred(P, n).Fy, -pred(P, n).Fy, 'dau nguoc')], {'Fz'}, false, @extraTC1);
    specs(end+1) = add('TC2', 'Vx 20 -> 25 m/s, Vy giu', 'L1', @(b, amp) setf(b, 'Vx', b.Vx + 5 * amp), ...
        @(b, n, S0) [mk('Alpha', pred(P, n).a, bm(S0, 'Alpha'), 'Vx khong vao alpha'), mk('Fy', pred(P, n).Fy, bm(S0, 'Fy'), 'Fy khong doi')], {'Fz'}, false, noExtra);
    specs(end+1) = add('TC3', 'Vx 20 -> 25 m/s, Vy = 0', 'L0', @(b, amp) setf(b, 'Vx', b.Vx + 5 * amp), ...
        @(b, n, S0) none, {'Alpha', 'Fy', 'Fz', 'Mx', 'Mz'}, false, noExtra);
    specs(end+1) = add('TC4a', 'Fext 4549 -> 5000 N (khong truot)', 'L0', @(b, amp) setf(b, 'Fext', b.Fext + amp * (5000 - b.Fext)), ...
        @(b, n, S0) mk('Fz', n.Fext, b.Fext, 'Fz khong theo Fext'), {'Alpha', 'Fy', 'Mx', 'Mz'}, false, noExtra);
    specs(end+1) = add('TC4b', 'Fext 4549 -> 5000 N (alpha 0.03)', 'L1', @(b, amp) setf(b, 'Fext', b.Fext + amp * (5000 - b.Fext)), ...
        @(b, n, S0) [mk('Fz', n.Fext, b.Fext, 'Fz khong theo Fext'), mk('Fy', pred(P, n).Fy, bm(S0, 'Fy'), 'Fy khong doi theo tai')], {'Alpha'}, false, @extraTC4b);
    specs(end+1) = add('TC5', 'ScaleFctrs o 3: 0.8 -> 0.5', 'L1', @(b, amp) setf(b, 'ScaleFctrs', setk(b.ScaleFctrs, 3, 0.8 - 0.3 * amp)), ...
        @(b, n, S0) mk('Fy', pred(P, n).Fy, hypStiff(P, b, n), 'mu vao do cung'), {'Alpha', 'Fz'}, false, noExtra);
    specs(end+1) = add('TC5b', 'ScaleFctrs o 3: 0.8 -> 0.5 (alpha 0.002, do doc tai 0)', 'L1s', @(b, amp) setf(b, 'ScaleFctrs', setk(b.ScaleFctrs, 3, 0.8 - 0.3 * amp)), ...
        @(b, n, S0) mk('Fy', pred(P, n).Fy, hypStiff(P, b, n), 'mu vao do cung'), {'Alpha', 'Fz'}, false, @extraTC5b);
    specs(end+1) = add('TC32', 'ScaleFctrs o 3 x 1.1 (doi chung duong: o co tac dung)', 'L1', @(b, amp) setf(b, 'ScaleFctrs', setk(b.ScaleFctrs, 3, 0.8 * (1 + 0.1 * amp))), ...
        @(b, n, S0) mk('Fy', pred(P, n).Fy, bm(S0, 'Fy'), 'Fy khong doi'), {'Alpha', 'Fz'}, false, noExtra);
    % TC6-TC31: the 26 other cells of ScaleFctrs (cell 4: 0 -> 0.1; the others x 1.1); code TCc<k>
    for k = [1 2 4:27]
        if k == 4, nv = 0.1; else, nv = 1.1; end
        specs(end+1) = add(sprintf('TCc%02d', k), sprintf('ScaleFctrs o %d -> %g', k, nv), 'L1', @(b, amp) setf(b, 'ScaleFctrs', setk(b.ScaleFctrs, k, nv)), @(b, n, S0) none, {}, true, noExtra); %#ok<AGROW>
        specs(end).k = k; specs(end).nv = nv;
    end
    % TC33-TC38: ports tied to a constant 0 (or fixed value) in the model
    specs(end+1) = add('TC33', 'BrkPrs 0 -> 1e5 Pa', 'L1', @(b, amp) setf(b, 'BrkPrs', 1e5 * amp), @(b, n, S0) none, {}, false, noExtra);
    specs(end+1) = add('TC34', 'AxlTrq 0 -> 50 N.m', 'L1', @(b, amp) setf(b, 'AxlTrq', 50 * amp), @(b, n, S0) none, {}, false, noExtra);
    specs(end+1) = add('TC35a', 'Camber 0 -> 0.03 rad (khong truot)', 'L0', @(b, amp) setf(b, 'Camber', 0.03 * amp), @(b, n, S0) none, {}, false, noExtra);
    specs(end+1) = add('TC35b', 'Camber 0 -> 0.03 rad (alpha 0.03)', 'L1', @(b, amp) setf(b, 'Camber', 0.03 * amp), @(b, n, S0) none, {}, false, noExtra);
    specs(end+1) = add('TC36', 'YawRate 0 -> 0.2 rad/s', 'L1', @(b, amp) setf(b, 'YawRate', 0.2 * amp), @(b, n, S0) none, ctx.outs, false, noExtra);
    specs(end+1) = add('TC37', 'Prs 220 -> 260 kPa', 'L1', @(b, amp) setf(b, 'Prs', 220000 + 40000 * amp), @(b, n, S0) none, {'Alpha', 'Fy', 'Fz'}, false, noExtra);
    specs(end+1) = add('TC38', 'Gnd 0 -> 0.01 m', 'L1', @(b, amp) setf(b, 'Gnd', 0.01 * amp), @(b, n, S0) none, ctx.outs, false, noExtra);
end

function s = setf(s, f, v), s.(f) = v; end
function v = setk(v, k, x), v(k) = x; end

function b = baseInputs(P, name)
    b = struct('BrkPrs', 0, 'AxlTrq', 0, 'Vx', 20, 'Vy', 0, 'Camber', 0, 'YawRate', 0, 'Prs', 220000, 'Gnd', 0, 'Fext', P.Fzf / 2, 'ScaleFctrs', [1 1 0.8 0 ones(1, 23)]);
    switch name
        case 'L1', b.Vy = -20 * tan(0.03);
        case 'L1s', b.Vy = -20 * tan(0.002);
    end
end

function r = pred(P, n)
% answer through the mapping table: VDB slip angle = atan(Vy/Vx); Fy of the half axle = PT(10) at alpha_f = -alpha_VDB with the VDB load dependence of the slope
    r.a = atan(n.Vy / n.Vx); mu = n.ScaleFctrs(3); Fz0 = P.Fzf / 2;
    CaEff = (P.Ca / 2) * sin(2 * atan(n.Fext / Fz0));            % PKY1*FNOMIN*sin(PKY4*atan(Fz/(PKY2*FNOMIN))), PKY2 = 1, PKY4 = 2
    r.Fy = mfh(P, -r.a, mu, n.Fext, CaEff);
end

function F = mfh(P, alpha, mu, Fz, Ca)
    D = mu .* Fz; B = Ca ./ (P.C .* D); u = B .* alpha;
    F = D .* sin(P.C .* atan(u - P.E .* (u - atan(u))));
end

function h = hypStiff(P, b, n)
% wrong hypothesis "mu enters the stiffness": Ca scaled by mu_new/mu_old
    r = pred(P, n); mu0 = b.ScaleFctrs(3); mu1 = n.ScaleFctrs(3);
    h = mfh(P, -r.a, mu1, n.Fext, (P.Ca / 2) * mu1 / mu0);
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function ctx = runSpec(ctx, s)
    done = doneCodes(ctx.csv);
    codes = [{s.code}, s.also];
    if all(ismember(codes, done)), fprintf('skip %s\n', s.code); return; end
    [S0, b, ctx] = getBase(ctx, s.base);
    amp = 1; rows = {}; el = NaN;
    for attempt = 1:2
        try
            n = s.chg(b, amp);
            tic; S1 = simcase(ctx, b, n); el = toc;
            doi = s.doi(b, n, S0);
            rows = rowsFor(ctx, s.code, s.port, s.base, S0, S1, doi, s.same, s.auto);
            rows = [rows, s.extra(ctx, b, n, S0, S1, amp)]; %#ok<AGROW>
        catch ME
            rows = {mkrow(s.code, s.port, s.base, 'all', 'doi', NaN, NaN, NaN, NaN, 'LOI CHAY', NaN, 'n/a', strtrim(ME.message(1:min(160, numel(ME.message)))))};
            break;
        end
        kpb = any(cellfun(@(r) strcmp(r.ket_qua, 'KHONG PHAN BIET'), rows));
        if kpb && attempt == 1, amp = 2; fprintf('%s: KHONG PHAN BIET, rerun with amp 2\n', s.code); continue; end
        if amp == 2, rows = cellfun(@(r) setNote(r, ['bac gap doi; ' r.ghi_chu]), rows, 'UniformOutput', false); end
        break;
    end
    writeRows(ctx.csv, rows);
    fprintf('%s done (%.1f s): %s\n', s.code, el, strjoin(unique(cellfun(@(r) r.ket_qua, rows, 'UniformOutput', false)), ', '));
end

function r = setNote(r, note), r.ghi_chu = note; end

function [S0, b, ctx] = getBase(ctx, name)
    b = baseInputs(ctx.P, name);
    if ~isKey(ctx.cache, name), ctx.cache(name) = simcase(ctx, b, b); end
    S0 = ctx.cache(name);
end

function S = simcase(ctx, b, n)
% one run of VDBTire.mdl: inputs = base value until t_s, new value afterwards (matrix format [t u], repeated time stamp = step)
    tEnd = 2; fn = fieldnames(b);
    in = Simulink.SimulationInput(ctx.mdl);
    for i = 1:numel(fn)
        M = [0, b.(fn{i})(:)'; ctx.ts, b.(fn{i})(:)'; ctx.ts, n.(fn{i})(:)'; tEnd, n.(fn{i})(:)'];
        in = in.setVariable(['in_' fn{i}], M);
    end
    in = in.setModelParameter('StopTime', '1', 'MaxStep', '1e-4', 'RelTol', '1e-9', 'AbsTol', '1e-12', 'ReturnWorkspaceOutputs', 'on');
    Simulink.sdi.clear; out = sim(in);
    S = struct('t', ctx.tg);
    for i = 1:numel(ctx.outs)
        o = ctx.outs{i};
        if any(strcmp(o, {'Alpha', 'Kappa'})), vn = ['info_' o]; else, vn = ['out_' o]; end
        ts = out.get(vn); S.(o) = resamp(ts.Time, squeeze(ts.Data), ctx.tg, ctx.ts);
    end
end

function y = resamp(tt, yy, tg, ts)
    tt = tt(:); yy = yy(:);
    k = find(diff(tt) == 0 & abs(tt(1:end-1) - ts) < 1e-9, 1);
    if isempty(k)
        [tu, iu] = unique(tt, 'last'); y = interp1(tu, yy(iu), tg, 'linear', 'extrap');
    else
        y = zeros(size(tg)); pre = tg < ts;
        y(pre) = interp1(tt(1:k), yy(1:k), tg(pre), 'linear', 'extrap');
        y(~pre) = interp1(tt(k+1:end), yy(k+1:end), tg(~pre), 'linear', 'extrap');
    end
end

function done = doneCodes(f)
    done = {}; fid = fopen(f, 'r', 'n', 'UTF-8'); fgetl(fid);
    while true
        l = fgetl(fid); if ~ischar(l), break; end
        c = strsplit(l, ','); if ~isempty(c{1}), done{end+1} = c{1}; end %#ok<AGROW>
    end
    fclose(fid); done = unique(done);
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function rows = rowsFor(ctx, code, port, basen, S0, S1, doi, same, auto)
    rows = {};
    for i = 1:numel(ctx.outs)
        o = ctx.outs{i}; ref = ctx.ref.(o);
        d = []; if ~isempty(doi), d = find(strcmp({doi.out}, o), 1); end
        if ~isempty(d)
            y = S1.(o)(ctx.win); a = doi(d).ans; den = max(max(abs(a)), ref);
            dev = max(abs(y - a)) / den; tol = 1e-6;
            devH = NaN; pb = 'n/a';
            if ~isnan(doi(d).hyp), devH = max(abs(y - doi(d).hyp)) / den; if devH >= 10 * tol, pb = 'co'; else, pb = 'khong'; end, end
            if dev > tol, ket = 'KHONG DAT'; elseif strcmp(pb, 'khong'), ket = 'KHONG PHAN BIET'; else, ket = 'DAT'; end
            note = 'dap an tinh tu phuong trinh Plant qua anh xa';
            if ~isempty(doi(d).name), note = [note '; gia thuyet sai: ' doi(d).name]; end
            rows{end+1} = mkrow(code, port, basen, o, 'doi', max(abs(y)), max(abs(a)), dev, tol, ket, devH, pb, note); %#ok<AGROW>
        else
            if isequal(auto, -1), continue; end      % base-point checks grade only the outputs that have an answer
            y = S1.(o)(ctx.all); y0 = S0.(o)(ctx.all); dev = max(abs(y - y0)) / max(max(abs(y0)), ref);
            if ismember(o, same) || (auto && dev <= 1e-9)
                if dev <= 1e-9, ket = 'DAT'; else, ket = 'KHONG DAT'; end
                rows{end+1} = mkrow(code, port, basen, o, 'khong_doi', max(abs(y)), max(abs(y0)), dev, 1e-9, ket, NaN, 'n/a', 'so voi ca goc'); %#ok<AGROW>
            else
                if auto, note = 'CO TAC DUNG: lech so voi ca goc'; else, note = 'chi ghi nhan: lech so voi ca goc'; end
                rows{end+1} = mkrow(code, port, basen, o, 'ghi_nhan', max(abs(y)), max(abs(y0)), dev, NaN, 'GHI NHAN', NaN, 'n/a', note); %#ok<AGROW>
            end
        end
    end
end

function r = mkrow(code, port, basen, o, loai, doMax, ans, dev, tol, ket, devH, pb, note)
    r = struct('ma_ca', code, 'cong_doi', port, 'goc', basen, 'dau_ra', o, 'loai', loai, 'do_max', doMax, 'dap_an_max', ans, 'sai_lech', dev, 'nguong', tol, ...
        'ket_qua', ket, 'sai_lech_gia_thuyet_sai', devH, 'phan_biet', pb, 'ghi_chu', note);
end

function k = vnKet(k)
% internal ASCII verdicts -> Vietnamese words (code points, so that the source file stays ASCII)
    switch k
        case 'DAT', k = char([272 7840 84]);
        case 'KHONG DAT', k = char([75 72 212 78 71 32 272 7840 84]);
        case 'KHONG PHAN BIET', k = char([75 72 212 78 71 32 80 72 194 78 32 66 73 7878 84]);
        case 'GHI NHAN', k = char([71 72 73 32 78 72 7852 78]);
        case 'LOI CHAY', k = char([76 7894 73 32 67 72 7840 89]);
    end
end

function writeRows(f, rows)
    fid = fopen(f, 'a', 'n', 'UTF-8');
    for i = 1:numel(rows)
        r = rows{i}; r.ket_qua = vnKet(r.ket_qua); note = strrep(strrep(r.ghi_chu, ',', ';'), newline, ' '); port = strrep(r.cong_doi, ',', ';');
        fprintf(fid, '%s,%s,%s,%s,%s,%.8e,%.8e,%.6e,%.1e,%s,%.6e,%s,%s\n', r.ma_ca, port, r.goc, r.dau_ra, r.loai, r.do_max, r.dap_an_max, r.sai_lech, r.nguong, r.ket_qua, ...
            r.sai_lech_gia_thuyet_sai, r.phan_biet, note);
    end
    fclose(fid);
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function rows = extraTC1(ctx, b, n, S0, S1, amp)
% TC39: lag of Fy after the step of TC1 (first-order, expected 1.59 ms +-2 %); TC40: twice the half-axle Fy against PT(10) of the axle (F_zf, C_alpha_f)
    P = ctx.P; tg = ctx.tg; rows = {};
    F0 = mean(S1.Fy(tg > 0.45 & tg < ts0(ctx))); F1 = mean(S1.Fy(ctx.win));
    y = (S1.Fy - F0) / (F1 - F0); sel = tg > ctx.ts & y > 0.05 & y < 0.95;
    pf = polyfit(tg(sel) - ctx.ts, log(1 - y(sel)), 1); tau = -1 / pf(1);
    i63 = find(tg > ctx.ts & y >= 1 - exp(-1), 1); t63 = tg(i63) - ctx.ts;
    a45 = S1.Alpha(4501); ya = (S1.Alpha - a45) / (mean(S1.Alpha(ctx.win)) - a45); ia = ya(find(tg > ctx.ts, 1));
    dev = abs(tau - 1.59e-3) / 1.59e-3; devH = abs(0 - 1.59e-3) / 1.59e-3;
    if dev <= 0.02, ket = 'DAT'; else, ket = 'KHONG DAT'; end
    rows{end+1} = mkrow('TC39', 'khong doi cong: tre lop sau bac TC1', 'TC1', 'Fy_tau', 'doi', tau, 1.59e-3, dev, 0.02, ket, devH, 'co', ...
        sprintf('hang so thoi gian ham mu bac 1 tu hoi quy log; thoi diem dat 63.2%% = %.3e s; Info.Alpha da dat %.4f cua bac o mau dau sau bac (Alpha nhay tuc thi neu gan 1)', t63, ia)); %#ok<AGROW>
    % TC40
    for q = 1:2
        if q == 1, Sx = S0; nx = b; nm = 'ca goc L1'; else, Sx = S1; nx = n; nm = 'ca TC1'; end
        af = -atan(nx.Vy / nx.Vx);
        ans_ = mfh(P, af, nx.ScaleFctrs(3), P.Fzf, P.Ca);
        ax = 2 * Sx.Fy(ctx.win); den = max(abs(ans_), ctx.ref.Fy);
        dv = max(abs(ax - ans_)) / den; dh = max(abs(Sx.Fy(ctx.win) - ans_)) / den;
        if dv > 1e-6, ket = 'KHONG DAT'; elseif dh < 1e-5, ket = 'KHONG PHAN BIET'; else, ket = 'DAT'; end
        rows{end+1} = mkrow('TC40', 'khong doi cong: 2 x Fy nua cau so voi PT(10) cau', nm, 'Fy_cau', 'doi', max(abs(ax)), abs(ans_), dv, 1e-6, ket, dh, 'co', 'gia thuyet sai: khong nhan 2'); %#ok<AGROW>
    end
end

function t = ts0(ctx), t = ctx.ts - 1e-9; end

function rows = extraTC4b(ctx, b, n, S0, S1, amp)
% the same Fy of TC4b against the Plant-style formula (stiffness independent of load): recorded only
    P = ctx.P; a = atan(n.Vy / n.Vx); Fp = mfh(P, -a, n.ScaleFctrs(3), n.Fext, P.Ca / 2);
    dev = max(abs(S1.Fy(ctx.win) - Fp)) / max(abs(Fp), ctx.ref.Fy);
    rows = {mkrow('TC4b', 'Fext', 'L1', 'Fy_Plant_style', 'ghi_nhan', max(abs(S1.Fy(ctx.win))), abs(Fp), dev, NaN, 'GHI NHAN', NaN, 'n/a', 'so voi cong thuc kieu Plant (do cung khong doi theo tai)')};
end

function rows = extraTC5b(ctx, b, n, S0, S1, amp)
    ratio = mean(S1.Fy(ctx.win)) / mean(S0.Fy(ctx.win));
    rows = {mkrow('TC5b', 'ScaleFctrs o 3', 'L1s', 'Fy_ratio_mu', 'ghi_nhan', ratio, 1, abs(ratio - 1), NaN, 'GHI NHAN', NaN, 'n/a', ...
        'ti so Fy(mu moi)/Fy(mu 0.8) o alpha 0.002: gan 1 nghia la do doc tai 0 khong doi theo mu')};
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function runTcw(ctx)
% TCW1, TCW2 on PlantVDBS2.slx: the model is only loaded, copied into a temporary harness and closed without saving
    P = ctx.P; done = doneCodes(ctx.csv);
    evalin('base', 'load_plant;');
    cs = make_cases('SSW'); tags = {cs.tag}; rows = {};
    for tg = {'SLIP', 'WEAVE'}
        tag = tg{1}; c1 = ['TCW1_' tag]; c2 = ['TCW2_' tag];
        if all(ismember({c1, c2}, done)), continue; end
        c = cs(strcmp(tags, tag)); t = c.t(:); Ta = 2 * double(t >= 1);
        assignin('base', 'vdb_v0', c.v(1));
        h = 'tmp_tcw'; if bdIsLoaded(h), close_system(h, 0); end
        load_system(fullfile(ctx.modelDir, 'PRSM_VDB', 'Plant_VDB', 'PlantVDBS2.slx')); load_system('vehdynlibeom'); load_system('vehdynlibtire');
        new_system(h); add_block('PlantVDBS2/Plant', [h '/DUT']); close_system('PlantVDBS2', 0);
        dut = [h '/DUT'];
        vals = {c.theta1(:), Ta, c.v(:), c.mu(:)}; vars = {'theta1', 'T_a', 'v', 'mu'};
        for i = 1:4
            assignin('base', ['tcw_in_' vars{i}], [t, vals{i}]);
            b = [h '/src_' vars{i}]; add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tcw_in_' vars{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
            add_line(h, get_param(b, 'PortHandles').Outport(1), portH(dut, 'Inport', vars{i}));
        end
        for nm = {'T_s', 'a_y', 'gamma'}    % required outputs of the Plant block: terminate (not logged)
            add_block('simulink/Sinks/Terminator', [h '/term_' nm{1}]); add_line(h, portH(dut, 'Outport', nm{1}), get_param([h '/term_' nm{1}], 'PortHandles').Inport(1));
        end
        for nm = {'theta2', 'T_r', 'F_yf'}   % taps by the local Goto tags
            fr = [dut '/tcw_from_' nm{1}]; tw = [dut '/tcw_log_' nm{1}];
            add_block('simulink/Signal Routing/From', fr, 'GotoTag', nm{1}); add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['tcw_' nm{1}], 'SaveFormat', 'Timeseries');
            add_line(dut, ['tcw_from_' nm{1} '/1'], ['tcw_log_' nm{1} '/1']);
        end
        for nm = {'xdot', 'ydot', 'r'}       % body outputs
            tw = [dut '/tcw_log_' nm{1}]; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['tcw_' nm{1}], 'SaveFormat', 'Timeseries');
            add_line(dut, portByName([dut '/VDBBody'], 'Outport', nm{1}), get_param(tw, 'PortHandles').Inport(1));
        end
        bs = [dut '/tcw_BusSel']; add_block('simulink/Signal Routing/Bus Selector', bs);
        add_line(dut, portByName([dut '/Tire_front'], 'Outport', 'Info'), get_param(bs, 'PortHandles').Inport(1));
        set_param(bs, 'OutputSignals', 'Alpha');
        tw = [dut '/tcw_log_Alpha']; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', 'tcw_Alpha', 'SaveFormat', 'Timeseries');
        add_line(dut, get_param(bs, 'PortHandles').Outport(1), get_param(tw, 'PortHandles').Inport(1));
        set_param(h, 'Solver', 'VariableStepAuto', 'StopTime', num2str(t(end)), 'MaxStep', '0.002', 'RelTol', '1e-6', 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
        Simulink.sdi.clear; tic; o = sim(Simulink.SimulationInput(h)); el = toc;
        close_system(h, 0);
        g = @(nm) o.get(['tcw_' nm]);
        tA = g('Alpha').Time; tA = tA(:);
        gi = @(nm) interp1(uniqTime(g(nm).Time), uniqVal(g(nm).Time, squeeze(g(nm).Data)), tA, 'linear', 'extrap');
        xd = gi('xdot'); yd = gi('ydot'); r = gi('r'); th2 = gi('theta2'); Tr = gi('T_r'); Fyf = gi('F_yf'); Al = squeeze(g('Alpha').Data); Al = Al(:);
        muT = interp1(t, c.mu(:), tA);
        delta = th2 / P.n; vyv = yd + P.a * r;
        Vxw = xd .* cos(delta) + vyv .* sin(delta); Vyw = -xd .* sin(delta) + vyv .* cos(delta);
        aV = atan2(Vyw, Vxw);                       % expected Info.Alpha = -alpha_f
        dev1 = max(abs(Al - aV)); aNoRot = atan2(vyv, xd); dh1 = max(abs(Al - aNoRot));
        if dev1 <= 1e-6, k1 = 'DAT'; else, k1 = 'KHONG DAT'; end
        if dh1 < 1e-5 && dev1 <= 1e-6, k1 = 'KHONG PHAN BIET'; end
        rows{end+1} = mkrow(c1, 'Info.Alpha cua Tire_front tren S2 (SLIP/WEAVE)', 'S2', 'Alpha', 'doi', max(abs(Al)), max(abs(aV)), dev1, 1e-6, k1, dh1, 'co', ...
            sprintf('rad tuyet doi; %d mau; ca %s; sim %.0f s; gia thuyet sai: khong xoay theo delta_f', numel(tA), tag, el)); %#ok<AGROW>
        alF = -aV; ep = (P.ec) + max(0, P.t0 - sign(alF) .* P.t0 .* P.Ca .* tan(alF) ./ (3 .* muT .* P.Fzf));
        TrE = ep ./ P.n .* Fyf; den = max(abs(TrE)); dev2 = max(abs(Tr - TrE)) / den;
        TrH = P.ep0 ./ P.n .* Fyf; dh2 = max(abs(Tr - TrH)) / den;
        if dev2 <= 1e-6, k2 = 'DAT'; else, k2 = 'KHONG DAT'; end
        if dh2 < 1e-5 && dev2 <= 1e-6, k2 = 'KHONG PHAN BIET'; end
        rows{end+1} = mkrow(c2, 'T_r cua S2 so voi PT(13)-(14) voi alpha_f tinh lai', 'S2', 'T_r', 'doi', max(abs(Tr)), den, dev2, 1e-6, k2, dh2, 'co', ...
            sprintf('tuong doi; ca %s; gia thuyet sai: e_p = e_p0 khong doi', tag)); %#ok<AGROW>
        writeRows(ctx.csv, rows(end-1:end));
        fprintf('%s %s done (%.0f s): dev %.2e rad, %.2e rel\n', c1, c2, el, dev1, dev2);
    end
end

function tu = uniqTime(tt), tu = unique(tt(:), 'last'); end
function v = uniqVal(tt, yy), [~, iu] = unique(tt(:), 'last'); yy = yy(:); v = yy(iu); end

function h = portH(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

function h = portByName(blk, type, name)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', type, 'Name', name);
    assert(numel(b) == 1, 'port %s not found in %s', name, blk);
    ph = get_param(blk, 'PortHandles'); p = str2double(get_param(b{1}, 'Port'));
    if strcmp(type, 'Inport'), h = ph.Inport(p); else, h = ph.Outport(p); end
end

% ------------------------------------------------------------------------------------------------------------------------------------------------------
function makeReport(ctx)
%MAKEREPORT From the case csv: per-case summary csv, mapping-line table csv (levels of evidence of table 12.9 B), 27-cell ScaleFctrs table csv, summary figure.
%   The Vietnamese text report (Plant_VDB_IO_tire_report.txt) is assembled from these csv files outside MATLAB (this source file is ASCII only).
    T = readtable(ctx.csv, 'Delimiter', ',', 'TextType', 'string', 'Encoding', 'UTF-8');
    okS = string(vnKet('DAT')); badS = string(vnKet('KHONG DAT')); kpbS = string(vnKet('KHONG PHAN BIET')); ghiS = string(vnKet('GHI NHAN'));
    codes = unique(T.ma_ca, 'stable');
    S = struct('ma_ca', {}, 'cong_doi', {}, 'goc', {}, 'n_cham', {}, 'n_ghi', {}, 'ratio', {}, 'ket_qua', {});
    for i = 1:numel(codes)
        R = T(T.ma_ca == codes(i), :); cham = R.loai ~= "ghi_nhan" & ~isnan(R.nguong);
        lines = R(cham, :);
        if any(R.ket_qua == string(vnKet('LOI CHAY'))), ket = string(vnKet('LOI CHAY'));
        elseif any(lines.ket_qua == badS), ket = badS;
        elseif any(lines.ket_qua == kpbS), ket = kpbS;
        elseif ~isempty(lines), ket = okS;
        else, ket = ghiS; end
        if ~isempty(lines), ratio = max(lines.sai_lech ./ lines.nguong); else, ratio = max([R.sai_lech; 0]) / 1e-9; end
        if startsWith(codes(i), 'TCc') && any(R.loai == "ghi_nhan" & R.sai_lech > 1e-9), ket = ghiS; ratio = max(R.sai_lech(R.loai == "ghi_nhan")) / 1e-9; end
        S(end+1) = struct('ma_ca', codes(i), 'cong_doi', R.cong_doi(1), 'goc', R.goc(1), 'n_cham', height(lines), 'n_ghi', sum(~cham), 'ratio', ratio, 'ket_qua', ket); %#ok<AGROW>
    end
    ST = struct2table(S); writetable(ST, fullfile(ctx.outDir, 'Plant_VDB_IO_tire_summary.csv'), 'Encoding', 'UTF-8');
    % mapping lines: id, tokens 'code/output'
    L = {'B01_Vx', {'TC2/Alpha', 'TC2/Fy'}; 'B02_Vy', {'TC1/Alpha', 'TC1/Fy'}; 'B03_Alpha', {'TC1/Alpha', 'TC2/Alpha', 'TCW1_SLIP/Alpha', 'TCW1_WEAVE/Alpha'}; ...
         'B04_Fext_Fz', {'TC4a/Fz', 'TC4b/Fz'}; 'B05_Fy_tai', {'TC4b/Fy'}; 'B06_mu_o3', {'TC5/Fy', 'TC5b/Fy', 'TC32/Fy'}; 'B07_o3_do_doc', {'TC5b/Fy_ratio_mu'}; ...
         'B08_Fy_nhan2', {'TC40/Fy_cau'}; 'B09_tre', {'TC39/Fy_tau'}; 'B10_Mz', {'TC1/Mz', 'TC5/Mz'}; 'B11_BrkPrs', {'TC33/Fy', 'TC33/Fx', 'TC33/Kappa'}; ...
         'B12_AxlTrq', {'TC34/Fy', 'TC34/Fx', 'TC34/Kappa'}; 'B13_Camber', {'TC35a/Fy', 'TC35b/Fy', 'TC35a/Mx', 'TC35b/Mx', 'TC35a/Mz', 'TC35b/Mz'}; ...
         'B14_YawRate', {'TC36/Omega', 'TC36/Fx', 'TC36/Fy', 'TC36/Fz', 'TC36/Mx', 'TC36/My', 'TC36/Mz', 'TC36/Alpha', 'TC36/Kappa'}; ...
         'B15_Prs', {'TC37/Fy', 'TC37/Mz'}; 'B16_Gnd', {'TC38/Omega', 'TC38/Fx', 'TC38/Fy', 'TC38/Fz', 'TC38/Mx', 'TC38/My', 'TC38/Mz', 'TC38/Alpha', 'TC38/Kappa'}; ...
         'B17_Tr', {'TCW2_SLIP/T_r', 'TCW2_WEAVE/T_r'}; 'B18_he_so', {'TC1/Fy', 'TC2/Fy', 'TC4b/Fy', 'TC5/Fy', 'TC5b/Fy', 'TC32/Fy'}; 'B19_Kappa_goc', {'TC1/Kappa'}};
    M = struct('id', {}, 'ma_ca', {}, 'cap_bang_chung', {}, 'so_do_max', {}, 'so_dong', {});
    for i = 1:size(L, 1)
        tok = L{i, 2}; lv = {}; val = [];
        for j = 1:numel(tok)
            p = split(string(tok{j}), '/'); R = T(T.ma_ca == p(1) & T.dau_ra == p(2), :);
            for r = 1:height(R)
                if R.loai(r) == "ghi_nhan", lv{end+1} = 'ghi'; else, lv{end+1} = char(R.ket_qua(r)); end %#ok<AGROW>
                val(end+1) = R.sai_lech(r); %#ok<AGROW>
            end
        end
        if isempty(lv), cap = 'KHONG CO DU LIEU';
        elseif any(strcmp(lv, char(badS))), cap = 'KHONG DAT';
        elseif any(strcmp(lv, char(kpbS))), cap = 'KHONG PHAN BIET';
        elseif all(strcmp(lv, 'ghi')), cap = 'CHI GHI NHAN';
        else, cap = 'DO TRUC TIEP DAT'; end
        cham = ~strcmp(lv, 'ghi'); if any(cham), vmax = max(val(cham)); else, vmax = max([val, 0]); end
        M(end+1) = struct('id', L{i, 1}, 'ma_ca', strjoin(unique(cellfun(@(x) x(1:find(x == '/', 1) - 1), tok, 'UniformOutput', false), 'stable'), ' '), 'cap_bang_chung', cap, 'so_do_max', vmax, 'so_dong', numel(lv)); %#ok<AGROW>
    end
    writetable(struct2table(M), fullfile(ctx.outDir, 'Plant_VDB_IO_tire_map.csv'), 'Encoding', 'UTF-8');
    % 27-cell table: cell k, tested value, outputs that changed against the base L1 (threshold 1e-9 relative) and the largest change
    C27 = struct('o', {}, 'ma_ca', {}, 'gia_tri_moi', {}, 'tac_dung', {}, 'dau_ra_doi', {}, 'do_lech_max', {});
    for k = 1:27
        if k == 3, code = 'TC32'; nv = 0.88; else, code = sprintf('TCc%02d', k); nv = 1.1; if k == 4, nv = 0.1; end, end
        R = T(T.ma_ca == code, :); if isempty(R), continue; end
        eff = R(R.loai == "ghi_nhan" & R.sai_lech > 1e-9 & ~startsWith(R.dau_ra, "Fy_"), :);
        if k == 3
            ta = 'CO'; names = 'Fy Mx Mz'; mx = max(eff.sai_lech);
        elseif isempty(eff)
            ta = 'KHONG'; names = '-'; mx = 0;
        else
            ta = 'CO'; names = strjoin(cellstr(eff.dau_ra)', ' '); mx = max(eff.sai_lech);
        end
        C27(end+1) = struct('o', k, 'ma_ca', code, 'gia_tri_moi', nv, 'tac_dung', ta, 'dau_ra_doi', names, 'do_lech_max', mx); %#ok<AGROW>
    end
    writetable(struct2table(C27), fullfile(ctx.outDir, 'Plant_VDB_IO_tire_scale27.csv'), 'Encoding', 'UTF-8');
    % figure: one column per case, bar = max(deviation / threshold) of the graded rows (log); grey = recorded only (deviation / 1e-9)
    f = figure('Visible', 'off', 'Position', [50 50 1500 560]); ax = axes(f); hold(ax, 'on');
    n = height(ST); r = max(ST.ratio, 1e-9);   % zero deviation is drawn at the floor of the axis
    for i = 1:n
        if ST.ket_qua(i) == okS, c = [0.2 0.65 0.3]; elseif ST.ket_qua(i) == ghiS, c = [0.6 0.6 0.6]; else, c = [0.85 0.2 0.2]; end
        bar(ax, i, r(i), 'FaceColor', c, 'EdgeColor', 'none');
    end
    set(ax, 'YScale', 'log', 'XTick', 1:n, 'XTickLabel', cellstr(ST.ma_ca), 'XTickLabelRotation', 90); yline(ax, 1, 'k--', 'threshold');
    ylabel(ax, 'max(deviation / threshold)   (grey: recorded only, deviation / 1e-9)'); ylim(ax, [1e-9 1e12]); ax.TickLabelInterpreter = 'none'; grid(ax, 'on');
    nGraded = sum(ST.ket_qua == okS | ST.ket_qua == badS | ST.ket_qua == kpbS);
    title(ax, sprintf('VDB tire, one port at a time: %d of %d graded cases PASS (green); grey = recorded only', sum(ST.ket_qua == okS), nGraded));
    exportgraphics(f, fullfile(ctx.outDir, 'Plant_VDB_IO_tire_summary.png'), 'Resolution', 110); close(f);
    fprintf('report stage: %d cases, %d PASS, %d NOT PASS, %d not distinguishable, %d recorded only\n', n, sum(ST.ket_qua == okS), sum(ST.ket_qua == badS), sum(ST.ket_qua == kpbS), sum(ST.ket_qua == ghiS));
end
