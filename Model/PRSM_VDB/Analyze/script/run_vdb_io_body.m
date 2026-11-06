function run_vdb_io_body(caseList)
%RUN_VDB_IO_BODY One-port-at-a-time test of the VDB body block (VDBBody.mdl), plan Documents/Shared/KeHoach_Plant_VDB.txt 12.10 (cases BC1-BC14,
%   bases G0 and G1) run as in Documents/Shared/ChayTu_VDB_IO.txt. Rows are appended to Result/PRSM/Plant_VDB/Analyze/Plant_VDB_IO_body_cases.csv
%   (one row per case, base and output); a case already in the csv is skipped, so the script can be rerun after a crash.
%   caseList : optional cell array of case ids ({'G0','G1','BC1',...}); default = all, in plan order.
%   Nothing is saved to any model: inputs go by Simulink.SimulationInput (setVariable, setBlockParameter, setModelParameter).
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths;
    addpath(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB', 'script'));
    folder = use_sim_tmp;
    Simulink.fileGenControl('set', 'CacheFolder', fullfile(folder, 'cache_body'), 'CodeGenFolder', fullfile(folder, 'codegen_body'), 'createDir', true);
    evalin('base', 'load_vdb_io_defaults;');        % plant variables (m, l_f, l_r, Iz) used by the mask of the body block
    P = load_vdb_params(modelDir);
    load_system(fullfile(modelDir, 'PRSM_VDB', 'Analyze', 'VDBBody.mdl'));
    outDir = fullfile(result_dir('Plant_VDB'), 'Analyze');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    csvFile = fullfile(outDir, 'Plant_VDB_IO_body_cases.csv');
    if ~exist(csvFile, 'file')
        fid = fopen(csvFile, 'w');
        fprintf(fid, 'ma_ca,cong_doi,goc,dau_ra,loai,do_max,dap_an_max,sai_lech,nguong,ket_qua,sai_lech_gia_thuyet_sai,phan_biet,ghi_chu\n');
        fclose(fid);
    end
    defs = case_defs();
    if nargin < 1 || isempty(caseList), caseList = {defs.id}; end
    cache = containers.Map();
    if any(strcmp(caseList, 'plot')), plot_summary(csvFile, outDir); close_system('VDBBody', 0); return; end
    if any(strcmp(caseList, 'verify')), verify_findings(P, outDir, cache); close_system('VDBBody', 0); return; end
    for iCase = 1:numel(caseList)
        d = defs(strcmp({defs.id}, caseList{iCase}));
        for kBase = 1:numel(d.gocs)
            goc = d.gocs{kBase};
            if row_exists(csvFile, d.id, goc), fprintf('skip %s %s (already in csv)\n', d.id, goc); continue; end
            fprintf('== %s on %s\n', d.id, goc);
            rows = []; ok = false;
            for kTry = 1:3
                try
                    [rows, cache] = evaluate_case(d, goc, 1, P, cache);
                    if any(strcmp({rows.ket_qua}, 'KHONG PHAN BIET'))
                        [rows2, cache] = evaluate_case(d, goc, 2, P, cache);   % step amplitude doubled, one rerun (ChayTu 3)
                        for kk = 1:numel(rows2), rows2(kk).ghi_chu = ['bien do x2; ' rows2(kk).ghi_chu]; end
                        rows = rows2;
                    end
                    ok = true; break;
                catch ME
                    fprintf('  try %d failed: %s\n', kTry, ME.message);
                end
            end
            if ~ok
                rows = mkrow(d.port, '-', 'loi', NaN, NaN, NaN, NaN, 'LOI CHAY', NaN, '-', 'sim failed 3 times');
            end
            write_rows(csvFile, d.id, goc, rows);
            fprintf('  %d rows: %s\n', numel(rows), strjoin(unique({rows.ket_qua}), ' / '));
        end
    end
    close_system('VDBBody', 0);
end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function defs = case_defs()
% Case table (plan 12.10): port = changed port, gocs = bases, T = stop time (s).
    ids = {'G0', 'G1', 'BC1', 'BC2', 'BC3', 'BC4', 'BC5', 'BC6', 'BC7', 'BC8', 'BC9', 'BC10', 'BC11', 'BC12', 'BC13', 'BC14'};
    ports = {'-', '-', 'xdotin', 'xdotin', 'FExt(1)', 'FExt(2)', 'FExt(3)', 'MExt(1)', 'MExt(2)', 'MExt(3)', 'WhlAngF', 'xdot_o', 'm', 'Izz', 'a', 'b'};
    gocs = {{'G0'}, {'G1'}, {'G1'}, {'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0', 'G1'}, {'G0'}, ...
            {'G1'}, {'G1'}, {'G1'}, {'G1'}};
    Ts = [4 4 4 15 4 4 4 4 4 4 4 4 4 4 4 4];
    defs = struct('id', ids, 'port', ports, 'gocs', gocs, 'T', num2cell(Ts));
end

function cfg = base_config(goc, P)
% Operating point of a base. Channels are piecewise-linear (T, V); equal consecutive T means a step.
    r0 = 0.3 * P.g / 20; T0 = [0 1e3];
    cfg.xdotin = struct('T', T0, 'V', [20 20]);
    z = struct('T', T0, 'V', [0 0]);
    cfg.fx = z; cfg.fy = z; cfg.fz = z; cfg.mx = z; cfg.my = z; cfg.mz = z; cfg.whl = z;
    cfg.ic = struct('xdot_o', 20, 'ydot_o', 0, 'r_o', 0);
    cfg.par = struct('m', P.m, 'a', P.a, 'b', P.b, 'Izz', P.Iz);   % values used by the independent answer
    cfg.maskset = struct();                                         % mask parameter overrides sent to the block
    if strcmp(goc, 'G1')
        cfg.ic.r_o = r0;
        cfg.fy = struct('T', T0, 'V', P.m * 20 * r0 * [1 1]);
    end
end

function ch = step_ch(ch, ts, delta)
    v0 = ch.V(1);
    ch = struct('T', [0 ts ts 1e3], 'V', [v0 v0 v0 + delta v0 + delta]);
end

function cfg = apply_case(id, goc, amp, P)
    cfg = base_config(goc, P); ts = 1;
    switch id
        case {'G0', 'G1'}
        case 'BC1', cfg.xdotin = step_ch(cfg.xdotin, ts, 2 * amp);
        case 'BC2', cfg.xdotin = struct('T', [0 1 14 1e3], 'V', [25 25 12.5 12.5]); cfg.ic.xdot_o = 25;
        case 'BC3', cfg.fx = step_ch(cfg.fx, ts, 2000 * amp);
        case 'BC4', cfg.fy = step_ch(cfg.fy, ts, 1000 * amp);
        case 'BC5', cfg.fz = step_ch(cfg.fz, ts, 2000 * amp);
        case 'BC6', cfg.mx = step_ch(cfg.mx, ts, 500 * amp);
        case 'BC7', cfg.my = step_ch(cfg.my, ts, 500 * amp);
        case 'BC8', cfg.mz = step_ch(cfg.mz, ts, 500 * amp);
        case 'BC9', cfg.whl = step_ch(cfg.whl, ts, 0.1 * amp);
        case 'BC9pos', cfg.whl = step_ch(cfg.whl, ts, 0.1 * amp); cfg.maskset.Cy_f = 12000;
        case 'BC10', cfg.ic.xdot_o = 18;
        case 'BC11', cfg.par.m = 1.1 * P.m; cfg.maskset.m = 1.1 * P.m;
        case 'BC12', cfg.par.Izz = 1.1 * P.Iz; cfg.maskset.Izz = 1.1 * P.Iz; cfg.mz = step_ch(cfg.mz, ts, 500);   % plan: G1 + BC8
        case 'BC13', cfg.par.a = 1.1 * P.a; cfg.maskset.a = 1.1 * P.a; cfg.fy = step_ch(cfg.fy, ts, 1000);       % plan: G1 + BC4
        case 'BC14', cfg.par.b = 1.1 * P.b; cfg.maskset.b = 1.1 * P.b; cfg.fy = step_ch(cfg.fy, ts, 1000);
        otherwise, error('unknown case %s', id);
    end
end

function [cfg, T] = case_cfg(id, goc, amp, P)
    cfg = apply_case(id, goc, amp, P); T = 4; if strcmp(id, 'BC2'), T = 15; end
end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function t = all_times(chs)
    t = [];
    for i = 1:numel(chs), t = [t, chs{i}.T]; end %#ok<AGROW>
end

function v = ev(ch, t, side)
% Piecewise-linear channel with steps. side = 'left' gives the limit from the left at a step time; default the value from that time on.
    if nargin < 3, side = 'right'; end
    v = zeros(size(t));
    for i = 1:numel(t)
        if strcmp(side, 'left'), k = find(ch.T < t(i), 1, 'last'); if isempty(k), k = 1; tt = ch.T(1); else, tt = t(i); end
        else, k = find(ch.T <= t(i), 1, 'last'); tt = t(i); end
        if k >= numel(ch.T), v(i) = ch.V(end);
        else, v(i) = ch.V(k) + (ch.V(k + 1) - ch.V(k)) * (tt - ch.T(k)) / (ch.T(k + 1) - ch.T(k)); end
    end
end

function [t, M] = vec_series(chs, Tend)
% Sample times of a vector input: every breakpoint of the channels, two rows (left limit, new value) where any channel steps.
    bt = unique([all_times(chs), Tend]); bt = bt(bt <= Tend);
    t = []; M = [];
    for i = 1:numel(bt)
        r = cellfun(@(c) ev(c, bt(i)), chs); l = cellfun(@(c) ev(c, bt(i), 'left'), chs);
        if i > 1 && any(abs(r - l) > 0), t(end + 1) = bt(i); M(end + 1, :) = l; end %#ok<AGROW>
        t(end + 1) = bt(i); M(end + 1, :) = r; %#ok<AGROW>
    end
    t = t(:);
end

function res = run_sim(cfg, T, mp)
% Run VDBBody for T seconds; return the signals on a 1 ms grid.
    if nargin < 3, mp = struct(); end
    Tend = T + 1; blk = 'VDBBody/VDBBody';
    [tx, xv] = vec_series({cfg.xdotin}, Tend); [tw, wv] = vec_series({cfg.whl}, Tend);
    [tF, FE] = vec_series({cfg.fx, cfg.fy, cfg.fz}, Tend); [tM, ME] = vec_series({cfg.mx, cfg.my, cfg.mz}, Tend);
    in = Simulink.SimulationInput('VDBBody');
    in = in.setVariable('in_xdotin', timeseries(xv, tx));
    in = in.setVariable('in_WhlAngF', timeseries(wv, tw));
    in = in.setVariable('in_FExt', timeseries(FE, tF));
    in = in.setVariable('in_MExt', timeseries(ME, tM));
    in = in.setModelParameter('StopTime', num2str(T), 'ReturnWorkspaceOutputs', 'on');
    in = in.setBlockParameter(blk, 'xdot_o', num2str(cfg.ic.xdot_o, 12));
    in = in.setBlockParameter(blk, 'ydot_o', num2str(cfg.ic.ydot_o, 12));
    in = in.setBlockParameter(blk, 'r_o', num2str(cfg.ic.r_o, 12));
    fm = fieldnames(mp); for iF = 1:numel(fm), in = in.setModelParameter(fm{iF}, mp.(fm{iF})); end
    fn = fieldnames(cfg.maskset);
    for iF = 1:numel(fn), in = in.setBlockParameter(blk, fn{iF}, num2str(cfg.maskset.(fn{iF}), 12)); end
    Simulink.sdi.clear;
    out = sim(in);
    tg = (0:0.001:T)'; res.tg = tg;
    for nm = {'xdot', 'ydot', 'psi', 'r', 'FzF', 'FzR'}, res.(nm{1}) = grid_of(out.get(['out_' nm{1}]), tg); end
    for nm = {'ay', 'Beta', 'ExtFx', 'ExtFy', 'ExtFz', 'ExtMx', 'ExtMy', 'ExtMz'}, res.(nm{1}) = grid_of(out.get(['info_' nm{1}]), tg); end
    tsx = out.get('out_xdot'); tsy = out.get('out_ydot'); tsb = out.get('info_Beta');
    res.native = struct('t', tsx.Time(:), 'xdot', squeeze(tsx.Data), 'ydot', squeeze(tsy.Data), 'tb', tsb.Time(:), 'Beta', squeeze(tsb.Data));
    res.ay_g = res.ay;                      % raw Info ay, in g
    res.ay = res.ay * 9.80665;              % m/s^2 with the standard g found in K11
end

function g = grid_of(ts, tg)
    t = ts.Time(:); d = squeeze(ts.Data); d = d(:);
    [t, iu] = unique(t, 'last'); d = d(iu);
    g = interp1(t, d, tg, 'linear', 'extrap');
end

function [res, cache] = get_run(cache, id, goc, amp, P)
    key = sprintf('%s|%s|%g', id, goc, amp);
    if ~cache.isKey(key)
        [cfg, T] = case_cfg(id, goc, amp, P);
        cache(key) = struct('cfg', cfg, 'T', T, 'res', run_sim(cfg, T)); %#ok<NASGU>
    end
    res = cache(key);
end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function E = expected_ode(cfg, par, opt, tg)
% Independent answer (plan 12.9 / 12.10): ydot' = Fy/m - xdot*r, r' = Mz/Izz, psi' = r (ode45, RelTol 1e-10, AbsTol 1e-12), solved segment by segment
% between the breakpoints of the inputs. opt flags build the WRONG hypotheses used as negative controls.
    def = struct('sgnFy', 1, 'sgnMz', 1, 'fx_in', 0, 'fz_in', 0, 'mx_in', 0, 'my_in', 0, 'lever', 0, 'plant', false);
    fn = fieldnames(opt); for i = 1:numel(fn), def.(fn{i}) = opt.(fn{i}); end, opt = def;
    function [Fy, Mz] = forces(t)
        Fy = opt.sgnFy * ev(cfg.fy, t) + opt.fx_in * ev(cfg.fx, t) + opt.fz_in * ev(cfg.fz, t);
        Mz = opt.sgnMz * ev(cfg.mz, t) + opt.mx_in * ev(cfg.mx, t) + opt.my_in * ev(cfg.my, t) + opt.lever * ev(cfg.fy, t);
    end
    function dy = rhs(t, y)
        [Fy, Mz] = forces(t); v = ev(cfg.xdotin, t);
        if opt.plant, dy = [Fy / (par.m * v) - y(2); Mz / par.Izz; y(2)];      % y(1) = beta (Plant form)
        else, dy = [Fy / par.m - v * y(2); Mz / par.Izz; y(2)]; end
    end
    chs = {cfg.xdotin, cfg.fx, cfg.fy, cfg.fz, cfg.mx, cfg.my, cfg.mz};
    bp = unique([0, all_times(chs), tg(end)]); bp = bp(bp <= tg(end));
    y0 = [cfg.ic.ydot_o; cfg.ic.r_o; 0];
    if opt.plant, y0(1) = cfg.ic.ydot_o / ev(cfg.xdotin, 0); end
    Y = zeros(numel(tg), 3); opts = odeset('RelTol', 1e-10, 'AbsTol', 1e-12);
    Y(1, :) = y0';
    for k = 1:numel(bp) - 1
        ii = find(tg > bp(k) & tg <= bp(k + 1));
        if isempty(ii), continue; end
        ts = [bp(k); tg(ii)];
        [~, yy] = ode45(@rhs, ts, y0, opts);
        if size(yy, 1) == 2, yy = yy([1 end], :); end
        Y(ii, :) = yy(2:end, :); y0 = yy(end, :)';
    end
    xd = ev(cfg.xdotin, tg)'; xd = xd(:);
    E.xdot = xd; E.r = Y(:, 2); E.psi = Y(:, 3);
    if opt.plant, E.ydot = xd .* Y(:, 1); else, E.ydot = Y(:, 1); end
    [FyG, ~] = forces(tg'); FyG = FyG(:);
    E.ay = FyG / par.m;                                  % body-frame acceleration ydot' + xdot*r = Fy/m, m/s^2
    E.Beta = atan2(E.ydot, xd);
    E.ExtFx = ev(cfg.fx, tg)'; E.ExtFy = ev(cfg.fy, tg)'; E.ExtFz = ev(cfg.fz, tg)';
    E.ExtMx = ev(cfg.mx, tg)'; E.ExtMy = ev(cfg.my, tg)'; E.ExtMz = ev(cfg.mz, tg)';
end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function [rows, cache] = evaluate_case(d, goc, amp, P, cache)
    id = d.id; [cfg, T] = case_cfg(id, goc, amp, P); tg = (0:0.001:T)';
    keep = true(size(tg)); if strcmp(id, 'BC2'), keep(abs(tg - 1) <= 0.002 | abs(tg - 14) <= 0.002) = false; end   % ramp corners: the solver does not land on them (verify csv)
    if any(strcmp(id, {'BC1', 'BC3', 'BC4', 'BC5', 'BC6', 'BC7', 'BC8', 'BC9', 'BC12', 'BC13', 'BC14'})), keep(1001) = false; end   % one sample at the step (t = 1 s)
    [R, cache] = get_run(cache, id, goc, amp, P); M = R.res;
    thrD = 1e-6; thrZ = 1e-9;
    refLv = struct('xdot', 1, 'ydot', 0.01, 'r', 0.001, 'psi', 0.001, 'ay', 0.1, 'Beta', 1e-3, 'ExtFx', 1, 'ExtFy', 1, 'ExtFz', 1, ...
                   'ExtMx', 1, 'ExtMy', 1, 'ExtMz', 1, 'FzF', 1, 'FzR', 1);
    outs = {'xdot', 'ydot', 'r', 'psi', 'ay', 'Beta', 'ExtFx', 'ExtFy', 'ExtFz', 'ExtMx', 'ExtMy', 'ExtMz', 'FzF', 'FzR'};
    % which comparison each output gets
    odeSet = {'G0', 'G1', 'BC1', 'BC2', 'BC4', 'BC8', 'BC11', 'BC12'};
    refMap = containers.Map({'BC3', 'BC5', 'BC6', 'BC7', 'BC9', 'BC13', 'BC14'}, {goc, goc, goc, goc, goc, 'BC4', 'BC4'});
    isODE = any(strcmp(id, odeSet));
    rows = repmat(mkrow('', '', '', 0, 0, 0, 0, '', 0, '', ''), 0, 1);
    if strcmp(id, 'BC10')
        [B0, cache] = get_run(cache, 'G0', 'G0', 1, P); b = B0.res;
        rows(end + 1) = mkrow(d.port, 'xdot(t=0)', 'ghi_nhan', M.xdot(1), 18, abs(M.xdot(1) - 18), NaN, 'GHI NHAN', NaN, '-', ...
            sprintf('xdot(0)=%.6g m/s: khoi theo %s', M.xdot(1), tern(abs(M.xdot(1) - 18) < abs(M.xdot(1) - 20), 'xdot_o=18', 'xdotin=20')));
        for nm = {'xdot', 'ydot', 'r', 'ay', 'FzF', 'FzR'}
            dif = max(abs(M.(nm{1})(keep) - b.(nm{1})(keep))); %#ok<*AGROW>
            ms = find(abs(M.xdot - 20) > 1e-6, 1, 'last'); if isempty(ms), ms = 0; end
            rows(end + 1) = mkrow(d.port, nm{1}, 'ghi_nhan', max(abs(M.(nm{1}))), max(abs(b.(nm{1}))), dif, NaN, 'GHI NHAN', NaN, '-', ...
                sprintf('lech so voi G0 toan ca %.3g; xdot hoi tu ve 20 sau %.3f s', dif, ms * 1e-3));
        end
        return;
    end
    for iO = 1:numel(outs)
        o = outs{iO}; ref = refLv.(o);
        isExt = strncmp(o, 'Ext', 3); isFz = strncmp(o, 'Fz', 2);
        meas = M.(o)(keep);
        if isExt
            Eo = expected_ode(cfg, cfg.par, struct(), tg); exp_ = Eo.(o)(keep); thr = thrD; loai = 'doi';
            werr = NaN; wnote = '';
            [wexp, hasW] = ext_wrong(id, o, cfg, tg);
            if hasW, werr = relerr(meas, wexp(keep), exp_, ref); wnote = 'gia thuyet sai: thanh phan ke ben'; end
            e = relerr(meas, exp_, exp_, ref);
            rows(end + 1) = judge(d.port, o, loai, meas, exp_, e, thr, werr, wnote);
        elseif isFz
            if any(strcmp(id, {'G0', 'G1', 'BC1', 'BC2', 'BC5', 'BC11', 'BC12', 'BC13', 'BC14'}))
                rows(end + 1) = mkrow(d.port, o, 'ghi_nhan', max(abs(meas)), NaN, max(meas) - min(meas), NaN, 'GHI NHAN', NaN, '-', ...
                    sprintf('%s: min %.6g, max %.6g N (F_z%s tinh: %.6g N)', o, min(meas), max(meas), tern(strcmp(o, 'FzF'), 'f', 'r'), ...
                    tern(strcmp(o, 'FzF'), P.Fzf, P.Fzr)));
            else
                base = base_of(id, goc, P, refMap, cache); [B, cache] = get_run(cache, base{1}, base{2}, 1, P); b = B.res.(o)(keep);
                rows(end + 1) = ref_row(d.port, o, meas, b, relerr(meas, b, b, ref), thrZ, NaN, '');
            end
        elseif isODE
            if strcmp(id, 'G0') || strcmp(id, 'G1') || any(strcmp(id, {'BC1', 'BC2', 'BC4', 'BC8', 'BC11', 'BC12'}))
                Eo = expected_ode(cfg, cfg.par, struct(), tg); exp_ = Eo.(o)(keep);
                if strcmp(o, 'xdot') && strcmp(id, 'G0'), end
                e = relerr(meas, exp_, exp_, ref);
                [wp, hasW, wnote] = ode_wrong(id, o, cfg, P, tg, M);
                werr = NaN; if hasW, werr = relerr(meas, wp(keep), exp_, ref); end
                if any(strcmp(id, {'BC4', 'BC8'})) && ~any(strcmp(o, {'ydot', 'r', 'psi', 'ay', 'Beta', 'xdot'})), end
                rows(end + 1) = judge(d.port, o, 'doi', meas, exp_, e, thrD, werr, wnote);
            end
        else
            base = base_of(id, goc, P, refMap, cache); [B, cache] = get_run(cache, base{1}, base{2}, 1, P); b = B.res.(o)(keep);
            [wp, hasW, wnote] = ode_wrong(id, o, cfg, P, tg, M);
            werr = NaN; if hasW, werr = relerr(meas, wp(keep), b, ref); end
            rows(end + 1) = ref_row(d.port, o, meas, b, relerr(meas, b, b, ref), thrZ, werr, wnote);
        end
    end
    if strcmp(id, 'BC9')       % positive control: with Cy_f = 12000 the same step must change the body (the test is not blind)
        [Rp, cache] = get_run(cache, 'BC9pos', goc, amp, P); Mp = Rp.res;
        base = base_of(id, goc, P, refMap, cache); [B, cache] = get_run(cache, base{1}, base{2}, 1, P);
        for nm = {'ydot', 'r'}
            e = relerr(Mp.(nm{1})(keep), B.res.(nm{1})(keep), B.res.(nm{1})(keep), refLv.(nm{1}));
            rows(end + 1) = mkrow(d.port, [nm{1} '(Cy_f=12000)'], 'doi_chung_duong', max(abs(Mp.(nm{1}))), max(abs(B.res.(nm{1}))), e, thrD, ...
                tern(e >= 1e-3, 'DAT', 'KHONG DAT'), NaN, '-', 'doi chung duong: ket qua phai KHAC goc (phep thu khong mu)');
        end
    end
end

function base = base_of(id, goc, P, refMap, cache) %#ok<INUSD>
% Reference run of the "unchanged outputs" comparison: the base, or (BC13, BC14) the run G1 + BC4.
    if refMap.isKey(id) && any(strcmp(id, {'BC13', 'BC14'})), base = {'BC4', 'G1'}; else, base = {goc, goc}; end
    if any(strcmp(id, {'BC4', 'BC8', 'BC1', 'BC2', 'BC11', 'BC12'})), base = {goc, goc}; end
end

function [wp, hasW, note] = ode_wrong(id, o, cfg, P, tg, M)
% Wrong hypothesis for the key output of each case (negative control). Returns the wrong prediction on the full grid.
    wp = []; hasW = false; note = ''; opt = []; par = cfg.par; mdlM = M; %#ok<NASGU>
    switch id
        case {'BC1', 'BC2'}, if strcmp(o, 'ydot'), opt = struct('plant', true); note = 'gia thuyet sai: dang Plant beta'' = F/(m v) - gamma'; end
        case 'BC3', if strcmp(o, 'ydot'), opt = struct('fx_in', 1); note = 'gia thuyet sai: Fx cong vao ydot'; end
        case 'BC4'
            if strcmp(o, 'ydot'), opt = struct('sgnFy', -1); note = 'gia thuyet sai: dau Fy nguoc'; end
            if strcmp(o, 'ay'), wp = M.ay_g * 9.81; hasW = true; note = 'gia thuyet sai: doi ay sang m/s^2 voi g = 9.81'; return; end
        case 'BC5', if strcmp(o, 'ydot'), opt = struct('fz_in', 1); note = 'gia thuyet sai: Fz vao ydot'; end
        case 'BC6', if strcmp(o, 'r'), opt = struct('mx_in', 1); note = 'gia thuyet sai: Mx vao r'; end
        case 'BC7', if strcmp(o, 'r'), opt = struct('my_in', 1); note = 'gia thuyet sai: My vao r'; end
        case 'BC8', if strcmp(o, 'r'), opt = struct('sgnMz', -1); note = 'gia thuyet sai: dau Mz nguoc'; end
        case 'BC11', if strcmp(o, 'ydot'), par.m = P.m; opt = struct(); note = 'gia thuyet sai: m khong duoc dung'; end
        case 'BC12', if strcmp(o, 'r'), par.Izz = P.Iz; opt = struct(); note = 'gia thuyet sai: Izz khong duoc dung'; end
        case 'BC13', if strcmp(o, 'r'), opt = struct('lever', 0.1 * P.a); note = 'gia thuyet sai: a la canh tay don cua FExt(2) (them 0.1*a*Fy vao mo-men)'; end
        case 'BC14', if strcmp(o, 'r'), opt = struct('lever', -0.1 * P.b); note = 'gia thuyet sai: b la canh tay don cua FExt(2) (them -0.1*b*Fy vao mo-men)'; end
    end
    if ~isempty(opt)
        E = expected_ode(cfg, par, opt, tg); wp = E.(o); hasW = true;
        if any(strcmp(id, {'BC13', 'BC14'})), wp = wp + 0; end
    end
end

function [wexp, hasW] = ext_wrong(id, o, cfg, tg)
% Wrong order of the components of FExt / MExt: the field is expected to show the neighbouring component (only for the port that the case changes).
    hasW = false; wexp = []; ch = struct('Fx', cfg.fx, 'Fy', cfg.fy, 'Fz', cfg.fz, 'Mx', cfg.mx, 'My', cfg.my, 'Mz', cfg.mz);
    pairs = {'BC3', 'ExtFx', 'Fy'; 'BC4', 'ExtFy', 'Fx'; 'BC5', 'ExtFz', 'Fy'; 'BC6', 'ExtMx', 'My'; 'BC7', 'ExtMy', 'Mx'; 'BC8', 'ExtMz', 'My'};
    k = find(strcmp(pairs(:, 1), id) & strcmp(pairs(:, 2), o));
    if ~isempty(k), wexp = ev(ch.(pairs{k, 3}), tg)'; hasW = true; end
end

function e = relerr(meas, ans_, scaleVec, refLevel)
    e = max(abs(meas(:) - ans_(:))) / max(max(abs(scaleVec(:))), refLevel);
end

function r = judge(port, o, loai, meas, exp_, e, thr, werr, note)
    if isnan(werr), phan = '-'; else, phan = tern(werr >= 10 * thr, 'co', 'khong'); end
    if e <= thr
        if strcmp(phan, 'khong'), res = 'KHONG PHAN BIET'; else, res = 'DAT'; end
    else, res = 'KHONG DAT'; end
    r = mkrow(port, o, loai, max(abs(meas)), max(abs(exp_)), e, thr, res, werr, phan, note);
end

function r = ref_row(port, o, meas, b, e, thr, werr, note)
    r = judge(port, o, 'khong_doi', meas, b, e, thr, werr, note);
end

function r = mkrow(port, o, loai, domax, ansmax, sl, thr, res, werr, phan, note)
    r = struct('cong_doi', port, 'dau_ra', o, 'loai', loai, 'do_max', domax, 'dap_an_max', ansmax, 'sai_lech', sl, 'nguong', thr, ...
        'ket_qua', res, 'wrong', werr, 'phan_biet', phan, 'ghi_chu', note);
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end

function tf = row_exists(csvFile, id, goc)
    txt = fileread(csvFile);
    tf = ~isempty(regexp(txt, ['(^|\n)' id ',[^,]*,' goc ','], 'once'));
end

function write_rows(csvFile, id, goc, rows)
    fid = fopen(csvFile, 'a');
    for i = 1:numel(rows)
        r = rows(i);
        fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', id, r.cong_doi, goc, r.dau_ra, r.loai, fnum(r.do_max), fnum(r.dap_an_max), ...
            fnum(r.sai_lech), fnum(r.nguong), r.ket_qua, fnum(r.wrong), r.phan_biet, strrep(r.ghi_chu, ',', ';'));
    end
    fclose(fid);
end

function s = fnum(x), if isnan(x), s = ''; else, s = sprintf('%.6g', x); end, end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function verify_findings(P, outDir, cache)
% Independent checks of the rows that came out KHONG DAT (ChayTu 4, B5). Writes Plant_VDB_IO_body_verify.csv.
    vf = fullfile(outDir, 'Plant_VDB_IO_body_verify.csv');
    fid = fopen(vf, 'w'); fprintf(fid, 'kiem,duong_do,gia_tri,don_vi,ghi_chu\n');
    L = P.a + P.b;
    % V1: BC2 xdot, Beta: compare on the NATIVE solver samples (no interpolation to the 1 ms grid) and with a finer MaxStep
    [cfg, T] = case_cfg('BC2', 'G1', 1, P);
    for mpv = [0.002 0.0005]
        r = run_sim(cfg, T, struct('MaxStep', num2str(mpv)));
        nx = r.native; ex = ev(cfg.xdotin, nx.t')';
        ex = ev(cfg.xdotin, nx.t')';
        fprintf(fid, 'BC2_xdot,mau goc cua bo giai MaxStep %g,%.6g,m/s,max|xdot - xdotin| tren cac mau goc (khong noi suy)\n', mpv, max(abs(nx.xdot - ex)));
        nb = atan2(nx.ydot, nx.xdot);          % tb equals t (same solver samples)
        fprintf(fid, 'BC2_Beta,mau goc MaxStep %g,%.6g,rad,max|Beta - atan(ydot/xdot) cua chinh khoi| tren cac mau goc\n', mpv, max(abs(squeeze(nx.Beta) - nb)));
        % same on the 1 ms grid with this MaxStep
        E = expected_ode(cfg, cfg.par, struct(), r.tg);
        fprintf(fid, 'BC2_xdot_luoi,luoi 1 ms MaxStep %g,%.6g,m/s,max|xdot - xdotin| tren luoi 1 ms\n', mpv, max(abs(r.xdot - E.xdot)));
        [~, im] = max(abs(r.xdot - E.xdot)); fprintf(fid, 'BC2_xdot_luoi_vitri,luoi 1 ms MaxStep %g,%.6g,s,thoi diem lech lon nhat (goc cua dot la 1 s va 14 s)\n', mpv, r.tg(im));
    end
    % V2: FzF, FzR respond to Fx, My and to the body-frame acceleration. Pitch transfer model: dFz_F(wheel) = (h/(2L))*(Fx + m*ax_b) - My/(2L) with
    % ax_b = xdot' - r*ydot; h is fitted on BC3/G0 (pure Fx) and L = a + b; test sign of the m*ax_b term on the other runs.
    [R3, cache] = get_run(cache, 'BC3', 'G0', 1, P); [R0, cache] = get_run(cache, 'G0', 'G0', 1, P);
    k = 3000; dF = R3.res.FzF(k) - R0.res.FzF(k); h = dF * 2 * L / 2000;
    fprintf(fid, 'FzF_BC3_G0,h ngam tu Fx (dFzF*2L/Fx),%.6g,m,do cao tam khoi luong ngam: h = dFzF_banh*2*(a+b)/Fx; L = a+b = %.4f m\n', h, L);
    dFR = R3.res.FzR(k) - R0.res.FzR(k);
    fprintf(fid, 'FzF_BC3_G0,dFzF + dFzR (bao toan tai),%.6g,N,tong thay doi tai moi banh (0 = chi chuyen tai)\n', dF + dFR);
    [R7, cache] = get_run(cache, 'BC7', 'G0', 1, P);
    dF7 = R7.res.FzF(k) - R0.res.FzF(k); dF7pred = -500 / (2 * L);
    fprintf(fid, 'FzF_BC7_G0,dFzF do My=500 N.m,%.6g,N,do duoc; du doan -My/(2L) = %.6g N; sai lech tuong doi %.3g\n', dF7, dF7pred, abs(dF7 - dF7pred) / abs(dF7pred));
    runs = {'BC4', 'G1'; 'BC8', 'G0'; 'BC8', 'G1'; 'BC1', 'G1'; 'BC12', 'G1'};
    for q = 1:size(runs, 1)
        [Rq, cache] = get_run(cache, runs{q, 1}, runs{q, 2}, 1, P); cq = Rq.cfg; tg = Rq.res.tg;
        E = expected_ode(cq, cq.par, struct(), tg);
        xdd = gradient(E.xdot, 1e-3); axb = xdd - E.r .* E.ydot;
        Fx = ev(cq.fx, tg)'; My = ev(cq.my, tg)';
        [Rb, cache] = get_run(cache, runs{q, 2}, runs{q, 2}, 1, P);        % base of the same G (same static load)
        dFzF = Rq.res.FzF - 4548.73; dFzR = Rq.res.FzR - 3166.84;
        Lq = L;
        for sg = [1 -1]
            pf = (h / (2 * Lq)) * (Fx + sg * cq.par.m * axb) - My / (2 * Lq);
            keep = tg > 0.01 & abs(tg - 1) > 0.0015 & abs(tg - 14) > 0.0015;
            ef = max(abs(dFzF(keep) - pf(keep))); sc = max(abs(dFzF(keep)));
            fprintf(fid, 'FzF_%s_%s,dFzF so voi du doan chuyen tai doc (dau m*ax_b = %+d),%.6g,N,sai lech lon nhat; bien do dFzF %.6g N\n', runs{q, 1}, runs{q, 2}, sg, ef, sc);
        end
    end
    fclose(fid);
end

% ----------------------------------------------------------------------------------------------------------------------------------------------
function plot_summary(csvFile, outDir)
% One column per (case, base): bar = largest sai_lech/nguong over the motion outputs (log scale; 1 = the threshold), diamond = same for FzF, FzR.
    T = readtable(csvFile, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    key = T.ma_ca + "/" + T.goc; [uk, ~, ik] = unique(key, 'stable');
    n = numel(uk); bar_ = nan(n, 1); fz = nan(n, 1); st = strings(n, 1);
    for i = 1:n
        R = T(ik == i, :); rec = R.loai == "ghi_nhan"; ok = ~rec & ~isnan(R.nguong) & R.loai ~= "doi_chung_duong";
        isz = startsWith(R.dau_ra, "Fz");
        v = R.sai_lech ./ R.nguong;
        if any(ok & ~isz), bar_(i) = max(v(ok & ~isz)); end
        if any(ok & isz), fz(i) = max(v(ok & isz)); end
        if any(R.ket_qua == "LOI CHAY"), st(i) = "LOI"; elseif all(R.loai == "ghi_nhan"), st(i) = "REC";
        elseif any(R.ket_qua == "KHONG DAT"), st(i) = "FAIL"; elseif any(R.ket_qua == "KHONG PHAN BIET"), st(i) = "NOSEP"; else, st(i) = "PASS"; end
    end
    fl = 1e-4; col = struct('PASS', [0.2 0.6 0.3], 'FAIL', [0.8 0.2 0.2], 'NOSEP', [0.9 0.6 0.1], 'REC', [0.5 0.5 0.5], 'LOI', [0 0 0]);
    f = figure('Visible', 'off', 'Position', [50 50 1300 560]); ax = axes(f); hold(ax, 'on');
    for i = 1:n
        c = col.(char(st(i))); h = max(bar_(i), fl); if isnan(bar_(i)), h = fl; end
        bar(ax, i, h, 'FaceColor', c, 'EdgeColor', 'none', 'BarWidth', 0.7);
        if ~isnan(fz(i)), plot(ax, i, max(fz(i), fl), 'kd', 'MarkerFaceColor', 'w', 'MarkerSize', 7); end
    end
    set(ax, 'YScale', 'log', 'XTick', 1:n, 'XTickLabel', uk, 'XTickLabelRotation', 60, 'YLim', [fl 1e9]);
    yline(ax, 1, 'k--', 'threshold'); grid(ax, 'on'); ylabel(ax, 'max error / threshold (bar: motion outputs; diamond: FzF, FzR)');
    title(ax, 'VDBBody one-port-at-a-time test: green PASS, red FAIL, orange NOT SEPARABLE, grey record only');
    exportgraphics(f, fullfile(outDir, 'Plant_VDB_IO_body_summary.png'), 'Resolution', 150); close(f);
end
