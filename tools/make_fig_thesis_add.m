% Candidate figures to ADD to the thesis (Documents/Thesis/luanvan.txt), drawn in MATLAB from the model functions and result files.
% They are proposals only: written to Documents/Thesis/image_to_add/, not referenced by luanvan.txt yet.
% Where each one goes and its caption: Documents/Thesis/image_to_add/ChuThich_Hinh.md.
%   Add_2A_Ts_static.png     : steady-state T_s against a_y at 60 km/h without assist, three friction coefficients, and T_ref
%   Add_2B_Tamax.png         : assist limit T_a,max(v), required assist T_a,req and a_y,lim from ref.json (replaces the table of six rows)
%   Add_2C_Sensor.png        : the sensor model (2.25) on a short synthetic signal: true value against measured value for T_s and a_y
%   Add_3A_Slopes.png        : largest natural slope of the calibration points per speed against K_max (ch3_map_slopes.csv)
%   Add_3B_Ts_static_Map.png : steady-state T_s with the Map at 60 km/h for three friction coefficients, against T_ref
%   Add_3C_LeadLag.png       : response of the selected lead-lag compensator to a step and to a sine of period 0.5 s
%   Add_4A_Flow.png          : flow chart of the parameter selection procedure of Chapter 4
%   Add_5A_Bars.png          : E_RMS and S of the three controllers on the three sequences, mean and standard deviation over five seeds
%   Add_5B_EpsSteady.png     : signed deviation eps_w in the 11 windows of STEADY, mean over five seeds
%   Add_5C_SlipStair.png     : SLIP friction staircase (48-68 s), T_s, T_ref and T_a of the three controllers, seed 99999
%   Add_5D_Reverse.png       : share of time with reverse assist, three controllers, three sequences, five seeds
% Vietnamese labels come from the UTF-8 file make_fig_thesis_add_labels.json so that this file stays ASCII.
%
% Run all:      matlab -softwareopengl -batch "run('<repo>\tools\make_fig_thesis_add.m')"
% Run one part: matlab -softwareopengl -batch "sel='5A'; run('<repo>\tools\make_fig_thesis_add.m')"

if ~exist('sel', 'var'), sel = 'all'; end
want = @(k) any(strcmp(sel, {'all', k}));
repoDir  = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoDir, 'Model');
dataDir  = fullfile(modelDir, 'shared', 'data');
figDir   = fullfile(repoDir, 'Documents', 'Thesis', 'figures');
outDir   = fullfile(repoDir, 'Documents', 'Thesis', 'image_to_add');
ctrlDir  = fullfile(repoDir, 'Result', 'Controllers');
if ~exist(outDir, 'dir'), mkdir(outDir); end
addpath(fullfile(modelDir, 'shared')); setup_paths;
lab = jsondecode(fileread(fullfile(repoDir, 'tools', 'make_fig_thesis_add_labels.json'), 'Encoding', 'UTF-8'));
set(groot, 'defaultAxesFontSize', 10, 'defaultLegendFontSize', 9);
co = get(groot, 'defaultAxesColorOrder');
ctrls = {'Map', 'PID', 'MapPID'};
colr  = {co(1, :), co(2, :), co(5, :)};
cases = {'STEADY', 'SLIP', 'WEAVE'};
seeds = 99995:99999;
refCol = [0.25 0.25 0.25];
ref = jsondecode(fileread(fullfile(dataDir, 'ref.json'), 'Encoding', 'UTF-8'));
tref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ay, v, 'linear');

%% 2A and 3B: steady-state torsion-bar torque at 60 km/h
if want('2A') || want('3B')
    P = map_params();
    J = jsondecode(fileread(fullfile(dataDir, 'map.json'), 'Encoding', 'UTF-8'));
    d = J.design;
    Cal = calibrate_map(false);
    v = 60; iv = find(Cal.v_kmh == v);
    M = map_table(Cal, iv, d.Kmax, d.Ts0);
    mus = [0.8 0.5 0.35];
    ayv = 0.05:0.005:0.40;
    Tr = nan(numel(mus), numel(ayv)); TsMap = Tr;
    for i = 1:numel(mus)
        for k = 1:numel(ayv)
            if ayv(k) > 0.92 * mus(i), continue; end            % keep away from the friction limit of the tyre
            try
                Tr(i, k) = map_steady_state(P, v / 3.6, ayv(k) * P.g, mus(i)).T_r;
                TsMap(i, k) = fzero(@(x) x + map_eval(M, x) - Tr(i, k), [0, Tr(i, k)]);
            catch
            end
        end
    end
    Tref = tref(v, ayv);
    lsty = {'-', '--', ':'};
    for which = {'2A', '3B'}
        if ~want(which{1}), continue; end
        fig = figure('Visible', 'off', 'Position', [100 100 560 380]);
        hold on;
        for i = 1:numel(mus)
            if strcmp(which{1}, '2A'), y = Tr(i, :); else, y = TsMap(i, :); end
            plot(ayv, y, lsty{i}, 'LineWidth', 1.5, 'Color', co(1, :), 'DisplayName', strrep(lab.mu_fmt, '%.2f', sprintf('%.2f', mus(i))));
        end
        plot(ayv, Tref, '-', 'LineWidth', 1.5, 'Color', refCol, 'DisplayName', lab.ref);
        grid on; box on; xlabel(lab.ay_g); ylabel(lab.Ts_Nm); xlim([0.05 0.40]);
        if strcmp(which{1}, '2A'), title(lab.nomap, 'FontWeight', 'normal'); else, title(lab.withmap, 'FontWeight', 'normal'); end
        legend('Location', 'northwest');
        name = 'Add_2A_Ts_static.png'; if strcmp(which{1}, '3B'), name = 'Add_3B_Ts_static_Map.png'; end
        exportgraphics(fig, fullfile(outDir, name), 'Resolution', 300); close(fig);
    end
    k3 = find(abs(ayv - 0.30) < 1e-9);
    fprintf('2A/3B at 60 km/h, 0.30 g: T_r = %.3f / %.3f / %.3f N.m, T_s with Map = %.3f / %.3f / %.3f N.m, T_ref = %.3f N.m\n', ...
        Tr(:, k3), TsMap(:, k3), Tref(k3));
end

%% 2B: assist limit
if want('2B')
    T = ref.Ta_max;
    fig = figure('Visible', 'off', 'Position', [100 100 560 360]);
    yyaxis left;
    plot(T.v_kmh, T.Ta_req_Nm, '-o', 'LineWidth', 1.4, 'MarkerSize', 4, 'Color', co(1, :), 'DisplayName', lab.Tareq); hold on;
    plot(T.v_kmh, T.Ta_max_Nm, '-s', 'LineWidth', 1.4, 'MarkerSize', 4, 'Color', co(2, :), 'DisplayName', lab.Tamax);
    ylabel(lab.torque_Nm); set(gca, 'YColor', 'k');
    yyaxis right;
    plot(T.v_kmh, T.a_y_lim_g, ':', 'LineWidth', 1.4, 'Color', refCol, 'DisplayName', lab.aylim);
    ylabel(lab.aylim); ylim([0 0.5]); set(gca, 'YColor', refCol);
    grid on; box on; xlabel(lab.v_kmh); xlim([20 100]); legend('Location', 'south');
    exportgraphics(fig, fullfile(outDir, 'Add_2B_Tamax.png'), 'Resolution', 300); close(fig);
end

%% 2C: sensor model on a synthetic signal (illustration of (2.25))
if want('2C')
    sj = [];
    if exist(fullfile(dataDir, 'sensors.json'), 'file'), sj = jsondecode(fileread(fullfile(dataDir, 'sensors.json'), 'Encoding', 'UTF-8')); end
    rng(99999);
    dt = 1e-4; t = (0:dt:0.1)';
    x1 = 2.0 + 0.3 * sin(2 * pi * t / 0.5);                       % T_s (N.m), true
    x2 = 0.15 + 0.03 * sin(2 * pi * t / 0.5);                     % a_y (g), true
    y1 = sens(x1, t, 0.01, 0.01, 1e-3);
    y2 = sens(x2, t, 0.01, 0.01, 10e-3);
    fig = figure('Visible', 'off', 'Position', [100 100 900 330]);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(tl); plot(ax, t * 1000, x1, 'LineWidth', 1.4, 'Color', refCol); hold(ax, 'on');
    stairs(ax, t * 1000, y1, 'LineWidth', 1.0, 'Color', co(1, :));
    grid(ax, 'on'); box(ax, 'on'); xlabel(ax, 'ms'); ylabel(ax, lab.Ts_Nm); title(ax, lab.sens_Ts, 'FontWeight', 'normal');
    legend(ax, {lab.true_val, lab.meas_val}, 'Location', 'northwest');
    ax = nexttile(tl); plot(ax, t * 1000, x2, 'LineWidth', 1.4, 'Color', refCol); hold(ax, 'on');
    stairs(ax, t * 1000, y2, 'LineWidth', 1.0, 'Color', co(1, :));
    grid(ax, 'on'); box(ax, 'on'); xlabel(ax, 'ms'); ylabel(ax, lab.ay_meas); title(ax, lab.sens_ay, 'FontWeight', 'normal');
    exportgraphics(fig, fullfile(outDir, 'Add_2C_Sensor.png'), 'Resolution', 300); close(fig);
    if isstruct(sj), fprintf('2C: sensors.json fields: %s (illustration uses the values of Table 2.3)\n', strjoin(fieldnames(sj)', ', ')); end
end

%% 3A: natural slopes against K_max
if want('3A')
    S = readtable(fullfile(figDir, 'ch3_map_slopes.csv'));
    fig = figure('Visible', 'off', 'Position', [100 100 560 340]);
    bar(S.v_kmh, S.max_natural_slope_0p1_0p3g, 0.6, 'FaceColor', co(1, :), 'EdgeColor', 'none', 'DisplayName', lab.slope_nat); hold on;
    yline(S.Kmax(1), '--', 'LineWidth', 1.5, 'Color', co(2, :), 'DisplayName', sprintf(lab.slope_kmax, S.Kmax(1)));
    grid on; box on; xlabel(lab.v_kmh); ylabel(lab.slope_y); xlim([15 105]); ylim([0 21]); legend('Location', 'north');
    exportgraphics(fig, fullfile(outDir, 'Add_3A_Slopes.png'), 'Resolution', 300); close(fig);
end

%% 3C: lead-lag compensator, step and sine of period 0.5 s
if want('3C')
    Sel = readtable(fullfile(figDir, 'ch4_selected.csv'), 'ReadRowNames', true);
    t1i = Sel{'tau1_in_ms', 'Map'} / 1000; t1o = Sel{'tau1_out_ms', 'Map'} / 1000;
    t2i = Sel{'tau2_in_ms', 'Map'} / 1000; t2o = Sel{'tau2_out_ms', 'Map'} / 1000;
    dt = 1e-5;
    t = (0:dt:0.4)'; u = double(t >= 0.02);
    w = sect(u, t1i, t1o, dt); y = sect(w, t2i, t2o, dt);
    ts = (0:dt:2.0)'; us = sin(2 * pi * ts / 0.5);
    ws = sect(us, t1i, t1o, dt); ys = sect(ws, t2i, t2o, dt);
    last = ts >= 1.5;
    fprintf('3C: step peak w = %.2f, u_map peak = %.2f; sine amplitude ratio u_map/M = %.3f\n', max(w), max(y), max(abs(ys(last))) / 1);
    fig = figure('Visible', 'off', 'Position', [100 100 900 330]);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, t * 1000, u, 'LineWidth', 1.4, 'Color', refCol); plot(ax, t * 1000, w, '--', 'LineWidth', 1.2, 'Color', co(2, :));
    plot(ax, t * 1000, y, 'LineWidth', 1.6, 'Color', co(1, :));
    grid(ax, 'on'); box(ax, 'on'); xlim(ax, [0 150]); xlabel(ax, 'ms'); ylabel(ax, lab.ll_y); title(ax, lab.ll_step_title, 'FontWeight', 'normal');
    legend(ax, {lab.ll_in, lab.ll_lead, lab.ll_out}, 'Location', 'northeast');
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, ts, us, 'LineWidth', 1.4, 'Color', refCol); plot(ax, ts, ys, 'LineWidth', 1.6, 'Color', co(1, :));
    grid(ax, 'on'); box(ax, 'on'); xlim(ax, [1.0 2.0]); xlabel(ax, lab.t_s); ylabel(ax, lab.ll_y); title(ax, lab.ll_sin_title, 'FontWeight', 'normal');
    legend(ax, {lab.ll_in, lab.ll_out}, 'Location', 'northeast');
    exportgraphics(fig, fullfile(outDir, 'Add_3C_LeadLag.png'), 'Resolution', 300); close(fig);
end

%% 4A: flow chart of the selection procedure
if want('4A')
    steps = lab.flow; n = numel(steps);
    fig = figure('Visible', 'off', 'Position', [100 100 620 640], 'Color', 'w');
    ax = axes(fig, 'Position', [0 0 1 1]); hold(ax, 'on'); axis(ax, 'off');
    xlim(ax, [0 1]); ylim(ax, [0 n + 0.5]);
    bw = 0.97; bh = 0.62;
    for k = 1:n
        yc = n + 0.5 - k;
        rectangle(ax, 'Position', [(1 - bw) / 2, yc - bh / 2, bw, bh], 'Curvature', 0.15, 'LineWidth', 1.2, 'EdgeColor', co(1, :), 'FaceColor', [0.95 0.97 1]);
        text(ax, 0.5, yc, sprintf('%d. %s', k, steps{k}), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 8.5);
        if k < n
            plot(ax, [0.5 0.5], [yc - bh / 2, yc - 1 + bh / 2 + 0.04], 'k-', 'LineWidth', 1.1);
            patch(ax, 0.5 + [-0.012 0.012 0], (yc - 1 + bh / 2) + [0.05 0.05 0], 'k');
        end
    end
    exportgraphics(fig, fullfile(outDir, 'Add_4A_Flow.png'), 'Resolution', 300); close(fig);
end

%% metrics of the five seeds (5A, 5B, 5D)
if want('5A') || want('5B') || want('5D')
    Mt = cell(1, 3);
    for c = 1:3
        fr = cell(numel(seeds), 1);
        for q = 1:numel(seeds)
            Tq = readtable(fullfile(ctrlDir, ctrls{c}, 'Cases_ssw', sprintf('%s_metrics_s%05d.csv', ctrls{c}, seeds(q))));
            Tq.Seed = repmat(seeds(q), height(Tq), 1); fr{q} = Tq;
        end
        Mt{c} = vertcat(fr{:});
    end
    getv = @(c, cs, win, col) Mt{c}.(col)(strcmp(Mt{c}.Case, cs) & strcmp(Mt{c}.Window, win));
end

%% 5A: E_RMS and S bars
if want('5A')
    fig = figure('Visible', 'off', 'Position', [100 100 900 340]);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    cols = {'RMS_eT_Nm', 'S_Nm'}; yl = {lab.erms_y, lab.s_y};
    for p = 1:2
        m = zeros(3); s = zeros(3);
        for k = 1:3, for c = 1:3, x = getv(c, cases{k}, 'whole case', cols{p}); m(k, c) = mean(x); s(k, c) = std(x); end, end
        ax = nexttile(tl); groupbars(ax, m, s, colr);
        set(ax, 'XTick', 1:3, 'XTickLabel', cases); ylabel(ax, yl{p}); grid(ax, 'on'); box(ax, 'on');
        if p == 1, legend(ax, ctrls, 'Location', 'northwest'); end
    end
    exportgraphics(fig, fullfile(outDir, 'Add_5A_Bars.png'), 'Resolution', 300); close(fig);
end

%% 5B: signed deviation in the STEADY windows
if want('5B')
    wins = unique(Mt{1}.Window(strcmp(Mt{1}.Case, 'STEADY') & ~strcmp(Mt{1}.Window, 'whole case')), 'stable');
    m = zeros(numel(wins), 3); s = m; xl = cell(numel(wins), 1);
    for i = 1:numel(wins)
        for c = 1:3, x = getv(c, 'STEADY', wins{i}, 'Mean_eT_signed_pct_of_Tdref'); m(i, c) = mean(x); s(i, c) = std(x); end
        tok = regexp(wins{i}, 'v(\d+)a(\d)p(\d+)([lr])', 'tokens', 'once');
        side = lab.left; if tok{4} == 'r', side = lab.right; end
        xl{i} = sprintf('%s km/h, %s.%s g, %s', tok{1}, tok{2}, tok{3}, side);
    end
    fig = figure('Visible', 'off', 'Position', [100 100 1000 380]);
    ax = axes(fig); groupbars(ax, m, s, colr);
    set(ax, 'XTick', 1:numel(wins), 'XTickLabel', xl, 'XTickLabelRotation', 30);
    ylabel(ax, lab.eps_y); grid(ax, 'on'); box(ax, 'on'); legend(ax, ctrls, 'Location', 'northwest');
    exportgraphics(fig, fullfile(outDir, 'Add_5B_EpsSteady.png'), 'Resolution', 300); close(fig);
end

%% 5C: SLIP friction staircase
if want('5C')
    tw = [48 68];
    fig = figure('Visible', 'off', 'Position', [100 100 900 560]);
    tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    axA = nexttile(tl, [1 1]); axB = nexttile(tl, [1 1]); axC = nexttile(tl, [1 1]);
    hold(axA, 'on'); hold(axB, 'on'); hold(axC, 'on');
    for c = 1:3
        S = readtable(fullfile(ctrlDir, ctrls{c}, 'Cases_ssw', sprintf('%s_SLIP_sig_s%05d.csv', ctrls{c}, 99999)));
        k = S.t >= tw(1) & S.t <= tw(2);
        plot(axA, S.t(k), S.T_s(k), 'LineWidth', 1.3, 'Color', colr{c}, 'DisplayName', ctrls{c});
        plot(axB, S.t(k), S.T_a(k), 'LineWidth', 1.2, 'Color', colr{c}, 'DisplayName', ctrls{c});
        if c == 3
            plot(axA, S.t(k), S.T_d_ref(k), '--', 'LineWidth', 1.3, 'Color', refCol, 'DisplayName', lab.ref);
            plot(axC, S.t(k), S.mu(k), 'LineWidth', 1.4, 'Color', refCol);
        end
    end
    for ax = [axA axB axC], grid(ax, 'on'); box(ax, 'on'); xlim(ax, tw); end
    set(axA, 'XTickLabel', []); set(axB, 'XTickLabel', []);
    ylabel(axA, lab.Ts_Nm); ylabel(axB, lab.Ta_Nm); ylabel(axC, lab.mu); xlabel(axC, lab.t_s); ylim(axC, [0 1]);
    title(axA, lab.slip_a, 'FontWeight', 'normal'); title(axB, lab.slip_b, 'FontWeight', 'normal');
    legend(axA, 'Location', 'southwest');
    exportgraphics(fig, fullfile(outDir, 'Add_5C_SlipStair.png'), 'Resolution', 300); close(fig);
end

%% 5D: reverse assist
if want('5D')
    m = zeros(3); s = zeros(3);
    for k = 1:3, for c = 1:3, x = getv(c, cases{k}, 'whole case', 'Rev_pct'); m(k, c) = mean(x); s(k, c) = std(x); end, end
    fprintf('5D: reverse assist (%%), rows STEADY SLIP WEAVE, columns Map PID MapPID:\n'); disp(m);
    fig = figure('Visible', 'off', 'Position', [100 100 560 340]);
    ax = axes(fig); groupbars(ax, m, s, colr);
    set(ax, 'XTick', 1:3, 'XTickLabel', cases); ylabel(ax, lab.rev_y); grid(ax, 'on'); box(ax, 'on'); ylim(ax, [0 max(m(:) + s(:)) * 1.1]);
    legend(ax, ctrls, 'Location', 'northwest');
    exportgraphics(fig, fullfile(outDir, 'Add_5D_Reverse.png'), 'Resolution', 300); close(fig);
end

fprintf('done: %s\n', outDir);

%% local functions
function y = sens(x, t, Delta, sigma, Tu)
    % noise, quantisation and zero-order hold of (2.25)
    y = zeros(size(x)); last = 0; nextT = 0;
    for k = 1:numel(t)
        if t(k) >= nextT - 1e-12
            last = Delta * round((x(k) + sigma * randn) / Delta);
            nextT = nextT + Tu;
        end
        y(k) = last;
    end
end

function y = sect(u, ti, to, dt)
    % first-order section to*y' + y = ti*u' + u, Tustin discretisation
    a = 2 * to / dt; b = 2 * ti / dt;
    y = zeros(size(u)); y(1) = u(1);
    for k = 2:numel(u)
        y(k) = ((b + 1) * u(k) + (1 - b) * u(k - 1) - (1 - a) * y(k - 1)) / (a + 1);
    end
end

function groupbars(ax, m, s, colr)
    hb = bar(ax, m, 'grouped', 'EdgeColor', 'none'); hold(ax, 'on');
    for c = 1:numel(hb)
        hb(c).FaceColor = colr{c};
        xe = hb(c).XEndPoints;
        errorbar(ax, xe, m(:, c), s(:, c), 'k', 'LineStyle', 'none', 'CapSize', 3, 'HandleVisibility', 'off');
    end
end
