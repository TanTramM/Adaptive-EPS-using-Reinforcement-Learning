function analyze_weave_branches(step, seeds)
%ANALYZE_WEAVE_BRANCHES Job B (Documents/Shared/KeHoach_WEAVE_HaiNhanh.txt): why MapPID tracks worse than PID on the WEAVE case. No simulation.
%
%   analyze_weave_branches('W0', 99999)               windows table of PID and MapPID from the 1 ms files of one seed (and the whole-case check)
%   analyze_weave_branches('W0', 99995:99999)         the same for several seeds, plus mean and standard deviation over the seeds
%   analyze_weave_branches('W2')                      branch analysis of MapPID (needs MapPID_WEAVE_branch_s99999.csv from run_weave_branches('W1')) and figures
%   analyze_weave_branches('W3')                      table of the diagnostic runs D1-D3 (needs the MapPID_WEAVE_diag_*_s99999.csv files)
%
%   Windows: the sine segments of make_cases('SSW') WEAVE: ctr, lane1, lane2, sw0p3, sw0p8, sw1p5, mu3. Window times come from S.win of the case
%   (the offset of each scene is taken from its first window); the period of each segment is the one defined in buildWEAVES (make_cases.m).
%   Per window: RMS of e_T, amplitude ratio and time delay of T_s against T_d_ref (least squares with a sine and a cosine of the known period plus
%   a constant), peak of |e_T| and its time against the nearest zero crossing of the fitted T_d_ref.
if nargin < 2, seeds = 99999; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(fileparts(scriptDir))));   % Model/
addpath(fullfile(modelDir, 'shared')); setup_paths;
switch step
    case 'W0', stepW0(seeds);
    case 'W2', stepW2();
    case 'W3', stepW3();
    otherwise, error('analyze_weave_branches: unknown step %s', step);
end
end

%% ===================================== window definitions =====================================
function W = weaveWindows()
% Segments: struct array with label, t0, t1, P (cycle time of the sine in the window [s]). Taken from make_cases('SSW'), not typed.
C = make_cases('SSW');
S = C(strcmp({C.tag}, 'WEAVE'));
lab = {S.win.label};
get = @(l) S.win(strcmp(lab, l));
W = struct('label', {}, 't0', {}, 't1', {}, 'P', {});
w = get('ctr');  W(end+1) = struct('label', 'ctr', 't0', w.t0, 't1', w.t1, 'P', 1/0.2);               %#ok<AGROW>
% lane scene: windows lane_ref (scene 1.8-2.2 s), lane_in (6.3-6.7 s): offset of the scene in the case; sine segments [1 3.5] and [5.5 8] of the scene
off = get('lane_ref').t0 - 1.8;
assert(abs(get('lane_in').t0 - off - 6.3) < 1e-9, 'lane scene offset inconsistent');
W(end+1) = struct('label', 'lane1', 't0', off + 1,   't1', off + 3.5, 'P', 1/0.4);                          %#ok<AGROW>
W(end+1) = struct('label', 'lane2', 't0', off + 5.5, 't1', off + 8,   'P', 1/0.4);                          %#ok<AGROW>
for q = {'sw0p3', 0.3; 'sw0p8', 0.8; 'sw1p5', 1.5}'
    w = get(q{1}); W(end+1) = struct('label', q{1}, 't0', w.t0, 't1', w.t1, 'P', 1/q{2});                 %#ok<AGROW>
end
w = get('mu3'); W(end+1) = struct('label', 'mu3', 't0', w.t0, 't1', w.t1, 'P', 1/0.75);                    %#ok<AGROW>
end

function [R, ph, c, res] = sineFit(t, x, P)
% x ~ R sin(w t + ph) + c, with w = 2 pi / P. res = RMS of the fit residual.
w = 2*pi/P; t0 = t(1); tt = t - t0;
A = [sin(w*tt), cos(w*tt), ones(size(tt))];
b = A \ x;
R = hypot(b(1), b(2)); ph = atan2(b(2), b(1)) - w*t0; c = b(3);
res = sqrt(mean((x - A*b).^2));
ph = mod(ph + pi, 2*pi) - pi;
end

function r = windowRow(T, w)
% metrics of one controller signal table T (t, T_s, T_d_ref, e_T) in the window w
m = T.t >= w.t0 & T.t <= w.t1;
t = T.t(m); eT = T.e_T(m); Ts = T.T_s(m); Tr = T.T_d_ref(m);
[Rr, phr, cr, resr] = sineFit(t, Tr, w.P);
[Rs, phs] = sineFit(t, Ts, w.P);
om = 2*pi/w.P;
dphi = mod(phr - phs + pi, 2*pi) - pi;                 % positive = T_s behind T_d_ref
[pk, ip] = max(abs(eT));
% zero crossings of the fitted reference inside the window: w t + ph = k pi
k0 = ceil((om*w.t0 + phr - cr*0)/pi); k1 = floor((om*w.t1 + phr)/pi);
tz = ((k0:k1)*pi - phr)/om;
if isempty(tz), dtp = NaN; else, [~, iz] = min(abs(tz - t(ip))); dtp = 1000*(t(ip) - tz(iz)); end
r = struct('P_s', w.P, 'RMS_eT', sqrt(mean(eT.^2)), 'RMS_Tdref', sqrt(mean(Tr.^2)), 'amp_ratio', Rs/Rr, 'delay_ms', 1000*dphi/om, ...
    'peak_eT', pk, 'peak_dt_ms', dtp, 'fitres_ref', resr/Rr);
end

function T = readSig(ctrl, seed)
f = fullfile(result_dir(ctrl, 'CasesSSW'), '..', 'Cases_ssw_1ms', sprintf('%s_WEAVE_sig1ms_%s.csv', ctrl, sensor_tag(seed)));
assert(isfile(f), 'missing %s', f);
T = readtable(f);
end

%% ===================================== W0 =====================================
function stepW0(seeds)
W = weaveWindows();
ctrls = {'PID', 'MapPID'};
rows = table();
for s = seeds(:)'
    for ci = 1:2
        c = ctrls{ci}; T = readSig(c, s);
        % check against the metrics file ('whole case', t >= 2 s as in export_ssw_signals)
        M = readtable(fullfile(result_dir(c, 'CasesSSW'), sprintf('%s_metrics_%s.csv', c, sensor_tag(s))));
        ref = M.RMS_eT_Nm(strcmp(M.Case, 'WEAVE') & strcmp(M.Window, 'whole case'));
        mine = sqrt(mean(T.e_T(T.t >= 2).^2));
        fprintf('W0 check %s seed %d: RMS e_T whole case %.6f (file 1 ms) vs %.6f (metrics), diff %.4f %%\n', c, s, mine, ref, 100*(mine/ref - 1));
        rr = struct('ctrl', string(c), 'seed', s, 'window', "whole", 'P_s', NaN, 'RMS_eT', mine, 'RMS_Tdref', NaN, 'amp_ratio', NaN, 'delay_ms', NaN, ...
            'peak_eT', max(abs(T.e_T(T.t >= 2))), 'peak_dt_ms', NaN, 'fitres_ref', NaN, 'check_rel_diff_pct', 100*(mine/ref - 1));
        rows = [rows; struct2table(rr)]; %#ok<AGROW>
        for k = 1:numel(W)
            r = windowRow(T, W(k));
            rr = struct('ctrl', string(c), 'seed', s, 'window', string(W(k).label)); rr = mergeStruct(rr, r); rr.check_rel_diff_pct = NaN;
            rows = [rows; struct2table(rr)]; %#ok<AGROW>
        end
    end
end
outDir = compareDir();
labels = [{'whole'}, {W.label}];
% paired gap per seed and window: MapPID - PID
G = table();
for s = seeds(:)'
    for k = 1:numel(labels)
        a = rows(rows.seed == s & (rows.ctrl == "PID") & (rows.window == string(labels{k})), :);
        b = rows(rows.seed == s & (rows.ctrl == "MapPID") & (rows.window == string(labels{k})), :);
        g = struct('seed', s, 'window', string(labels{k}), 'P_s', a.P_s, 'RMS_eT_PID', a.RMS_eT, 'RMS_eT_MapPID', b.RMS_eT, ...
            'gap_RMS_pct', 100*(b.RMS_eT/a.RMS_eT - 1), 'gap_RMS_Nm', b.RMS_eT - a.RMS_eT, ...
            'amp_PID', a.amp_ratio, 'amp_MapPID', b.amp_ratio, 'dAmp_pct', 100*(b.amp_ratio - a.amp_ratio), ...
            'delay_PID_ms', a.delay_ms, 'delay_MapPID_ms', b.delay_ms, 'dDelay_ms', b.delay_ms - a.delay_ms, ...
            'peak_PID', a.peak_eT, 'peak_MapPID', b.peak_eT, 'peakdt_PID_ms', a.peak_dt_ms, 'peakdt_MapPID_ms', b.peak_dt_ms, ...
            'fitres_ref_PID', a.fitres_ref);
        G = [G; struct2table(g)]; %#ok<AGROW>
    end
end
tag = sensor_tag(seeds(end));
if isscalar(seeds)
    writetable(G, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_windows_%s.csv', tag)));
    writetable(rows, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_windows_long_%s.csv', tag)));
    disp(G(:, {'window', 'P_s', 'RMS_eT_PID', 'RMS_eT_MapPID', 'gap_RMS_pct', 'amp_PID', 'amp_MapPID', 'delay_PID_ms', 'delay_MapPID_ms', 'peakdt_PID_ms', 'peakdt_MapPID_ms'}));
else
    writetable(G, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_windows_%dseeds_per_seed.csv', numel(seeds))));
    A = table();
    for k = 1:numel(labels)
        g = G(G.window == string(labels{k}), :);
        ms = @(x) [mean(x), std(x)];
        a = struct('window', string(labels{k}), 'P_s', g.P_s(1));
        flds = {'RMS_eT_PID', 'RMS_eT_MapPID', 'gap_RMS_pct', 'amp_PID', 'amp_MapPID', 'dAmp_pct', 'delay_PID_ms', 'delay_MapPID_ms', 'dDelay_ms'};
        for q = 1:numel(flds)
            v = ms(g.(flds{q})); a.([flds{q} '_mean']) = v(1); a.([flds{q} '_std']) = v(2);
        end
        A = [A; struct2table(a)]; %#ok<AGROW>
    end
    writetable(A, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_windows_%dseeds.csv', numel(seeds))));
    disp(A(:, {'window', 'P_s', 'RMS_eT_PID_mean', 'RMS_eT_MapPID_mean', 'gap_RMS_pct_mean', 'gap_RMS_pct_std', 'dAmp_pct_mean', 'dDelay_ms_mean', 'dDelay_ms_std'}));
end
end

function d = compareDir()
modelDir = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
d = fullfile(fileparts(modelDir), 'Result', 'Compare', 'PID_vs_MapPID');
if ~isfolder(d), mkdir(d); end
end

function a = mergeStruct(a, b)
f = fieldnames(b);
for i = 1:numel(f), a.(f{i}) = b.(f{i}); end
end

%% ===================================== W2 =====================================
function stepW2()
seed = 99999; tag = sensor_tag(seed);
modelDir = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
Jm = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
outDir = compareDir();
B = readtable(fullfile(fileparts(result_dir('MapPID', 'CasesSSW')), 'Cases_ssw_branch', sprintf('MapPID_WEAVE_branch_%s.csv', tag)));
Pd = readSig('PID', seed);
assert(max(abs(Pd.t - B.t)) < 1e-9, 'time grids differ');
if ismember('T_s_meas', B.Properties.VariableNames), Tm = B.T_s_meas; else, Tm = B.T_s; end
B.u_PID = B.u_P + B.u_I + B.u_D; B.T_s_m = Tm;
W = weaveWindows();
R = table(); X = table();
for k = 1:numel(W)
    w = W(k); m = B.t >= w.t0 & B.t <= w.t1;
    r = segStats(B, Pd, m, Ts0);
    om = 2*pi/w.P;
    [Rs, phs] = sineFit(B.t(m), B.T_s(m), w.P); [Rm, phm] = sineFit(B.t(m), B.u_map(m), w.P);
    [Rp, php] = sineFit(B.t(m), B.u_PID(m), w.P); [Rc, ~] = sineFit(B.t(m), B.T_a_cmd(m), w.P);
    [Rr, phr] = sineFit(B.t(m), B.T_d_ref(m), w.P);
    dly = @(a, b) 1000 * (mod(a - b + pi, 2*pi) - pi) / om;     % delay of the signal with phase b behind the signal with phase a
    r.Amp_umap = Rm; r.Amp_uPID = Rp; r.Amp_Tacmd = Rc; r.Amp_Ts = Rs; r.Amp_Tdref = Rr;
    r.delay_umap_vs_Ts_ms = dly(phs, phm); r.delay_uPID_vs_Ts_ms = dly(phs, php); r.delay_Ts_vs_ref_ms = dly(phr, phs);
    R = [R; [table(string(w.label), w.P, 'VariableNames', {'window', 'P_s'}), struct2table(r)]]; %#ok<AGROW>
    % segments of +-0.3 cycle around every zero crossing of the fitted reference inside the window (segment fully inside the window)
    [~, phf, cf] = sineFit(B.t(m), B.T_d_ref(m), w.P);
    k0 = ceil((om*w.t0 + phf)/pi); k1 = floor((om*w.t1 + phf)/pi);
    tz = ((k0:k1)*pi - phf)/om;
    tz = tz(tz - 0.3*w.P >= w.t0 & tz + 0.3*w.P <= w.t1);
    for j = 1:numel(tz)
        ms = B.t >= tz(j) - 0.3*w.P & B.t <= tz(j) + 0.3*w.P;
        q = segStats(B, Pd, ms, Ts0);
        X = [X; [table(string(w.label), j, tz(j), 'VariableNames', {'window', 'crossing', 't_cross_s'}), struct2table(q)]]; %#ok<AGROW>
    end
end
writetable(R, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_branch_windows_%s.csv', tag)));
writetable(X, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_branch_crossings_%s.csv', tag)));
% mean over the crossings of each window
A = table();
for k = 1:numel(W)
    x = X(X.window == string(W(k).label), :);
    if isempty(x), continue; end
    a = varfun(@mean, x(:, 4:end)); a.Properties.VariableNames = x.Properties.VariableNames(4:end);
    A = [A; [table(string(W(k).label), height(x), 'VariableNames', {'window', 'n_cross'}), a]]; %#ok<AGROW>
end
writetable(A, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_branch_crossings_mean_%s.csv', tag)));
disp(R(:, {'window', 'P_s', 'RMS_umap', 'RMS_uP', 'RMS_uI', 'RMS_uD', 'RMS_uPID', 'frac_dz_meas', 'frac_dz_true', 'opp_frac', 'opp_RMS', 'delay_umap_vs_Ts_ms', 'delay_uPID_vs_Ts_ms', 'delay_Ts_vs_ref_ms'}));
disp(A(:, {'window', 'n_cross', 'RMS_eT_PID', 'RMS_eT_MapPID', 'frac_dz_meas', 'dz_run_ms', 'opp_frac', 'opp_RMS', 'RMS_umap', 'RMS_uPID'}));
% figures
lane1 = W(strcmp({W.label}, 'lane1')); lane2 = W(strcmp({W.label}, 'lane2'));
zoomFig(B, Pd, [W(strcmp({W.label}, 'sw1p5')).t0, W(strcmp({W.label}, 'sw1p5')).t1], 'sw1p5', outDir, tag);
zoomFig(B, Pd, [lane1.t0 - 0.3, lane2.t1 + 0.3], 'lane', outDir, tag);
mu3 = W(strcmp({W.label}, 'mu3'));
zoomFig(B, Pd, [mu3.t0, mu3.t0 + 3*mu3.P], 'mu3', outDir, tag);
end

function r = segStats(B, Pd, m, Ts0)
% statistics of the MapPID branches (table B) and of the PID and MapPID tracking error in the samples m
dt = 0.001;
um = B.u_map(m); up = B.u_PID(m); Tm = B.T_s_m(m); Tt = B.T_s(m);
r.RMS_eT_PID = sqrt(mean(Pd.e_T(m).^2)); r.RMS_eT_MapPID = sqrt(mean(B.e_T(m).^2));
r.RMS_umap = sqrt(mean(um.^2)); r.RMS_uP = sqrt(mean(B.u_P(m).^2)); r.RMS_uI = sqrt(mean(B.u_I(m).^2));
r.RMS_uD = sqrt(mean(B.u_D(m).^2)); r.RMS_uPID = sqrt(mean(up.^2));
dz = abs(Tm) < Ts0; r.frac_dz_meas = mean(dz); r.frac_dz_true = mean(abs(Tt) < Ts0);
d = diff([0; dz(:); 0]); s = find(d == 1); e = find(d == -1);
if isempty(s), r.dz_run_ms = NaN; else, r.dz_run_ms = 1000*dt*mean(e - s); end
opp = um .* up < 0;                                   % the two branches pull in opposite directions
r.opp_frac = mean(opp); r.opp_RMS = sqrt(mean((opp .* min(abs(um), abs(up))).^2));
end

function zoomFig(B, Pd, tl, name, outDir, tag)
m = B.t >= tl(1) & B.t <= tl(2);
f = figure('Visible', 'off', 'Position', [100 100 1100 900], 'Renderer', 'painters');
tiledlayout(4, 1, 'TileSpacing', 'compact');
nexttile; plot(B.t(m), B.T_d_ref(m), 'k', B.t(m), Pd.T_s(m), 'b', B.t(m), B.T_s(m), 'r'); grid on; ylabel('T_s [N.m]'); title(['WEAVE ' name ', seed ' tag(2:end) ':  {\color{black}T_{d,ref}}  {\color{blue}T_s PID}  {\color{red}T_s MapPID}']);
nexttile; plot(B.t(m), Pd.e_T(m), 'b', B.t(m), B.e_T(m), 'r'); grid on; ylabel('e_T [N.m]'); title('{\color{blue}PID}  {\color{red}MapPID}');
nexttile; plot(B.t(m), B.u_map(m), 'm', B.t(m), B.u_P(m) + B.u_I(m) + B.u_D(m), 'g'); grid on; ylabel('branch [N.m]'); title('{\color{magenta}u_{map}}  {\color[rgb]{0,0.6,0}u_{PID} = u_P + u_I + u_D}');
nexttile; plot(B.t(m), Pd.T_a(m), 'b', B.t(m), B.T_a(m), 'r'); grid on; ylabel('T_a [N.m]'); xlabel('t [s]'); title('{\color{blue}PID}  {\color{red}MapPID}');
linkaxes(findall(f, 'Type', 'axes'), 'x'); xlim(tl);
exportgraphics(f, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_zoom_%s_%s.png', name, tag)), 'Resolution', 130);
close(f);
end

%% ===================================== W3 =====================================
function stepW3()
seed = 99999; tag = sensor_tag(seed);
outDir = compareDir();
W = weaveWindows();
src = struct('name', {'PID', 'MapPID', 'D1', 'D2', 'D3'});
T = {readSig('PID', seed), readSig('MapPID', seed)};
for k = 3:5
    T{k} = readtable(fullfile(fileparts(result_dir('MapPID', 'CasesSSW')), 'Cases_ssw_branch', sprintf('MapPID_WEAVE_diag_%s_%s.csv', src(k).name, tag))); %#ok<AGROW>
end
labels = [{'whole'}, {W.label}];
rms = zeros(numel(labels), 5); dly = zeros(numel(labels), 5); amp = zeros(numel(labels), 5);
for j = 1:5
    rms(1, j) = sqrt(mean(T{j}.e_T(T{j}.t >= 2).^2));
    for k = 1:numel(W)
        r = windowRow(T{j}, W(k)); rms(k+1, j) = r.RMS_eT; dly(k+1, j) = r.delay_ms; amp(k+1, j) = r.amp_ratio;
    end
end
Tab = table(string(labels(:)), 'VariableNames', {'window'});
for j = 1:5, Tab.(['RMS_eT_' src(j).name]) = rms(:, j); end
Tab.gap_MapPID_vs_PID_pct = 100*(rms(:, 2) ./ rms(:, 1) - 1);
for j = 3:5
    Tab.(['change_' src(j).name '_vs_MapPID_pct']) = 100*(rms(:, j) ./ rms(:, 2) - 1);
    Tab.(['gap_' src(j).name '_vs_PID_pct']) = 100*(rms(:, j) ./ rms(:, 1) - 1);
    Tab.(['gap_closed_' src(j).name '_pct']) = 100*(rms(:, 2) - rms(:, j)) ./ (rms(:, 2) - rms(:, 1));
end
for j = 1:5, Tab.(['delay_ms_' src(j).name]) = dly(:, j); end
for j = 1:5, Tab.(['amp_' src(j).name]) = amp(:, j); end
writetable(Tab, fullfile(outDir, sprintf('PID_vs_MapPID_WEAVE_diag_%s.csv', tag)));
disp(Tab(:, {'window', 'RMS_eT_PID', 'RMS_eT_MapPID', 'RMS_eT_D1', 'RMS_eT_D2', 'RMS_eT_D3', 'gap_MapPID_vs_PID_pct', 'gap_D1_vs_PID_pct', 'gap_D2_vs_PID_pct', 'gap_D3_vs_PID_pct'}));
disp(Tab(:, {'window', 'change_D1_vs_MapPID_pct', 'change_D2_vs_MapPID_pct', 'change_D3_vs_MapPID_pct', 'delay_ms_PID', 'delay_ms_MapPID', 'delay_ms_D1', 'delay_ms_D2', 'delay_ms_D3'}));
end
