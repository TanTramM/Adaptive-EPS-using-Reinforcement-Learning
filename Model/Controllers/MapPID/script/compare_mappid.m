function H = compare_mappid(sens)
%COMPARE_MAPPID O9 of DieuKhien_MapPID.txt: MapPID against Map, PI and PID on the five DREWS cases, from the metrics and signal files already
%   written by run_cases (no controller is run here; the other controllers' files are only read).
%
%   H = compare_mappid('s99999')
%   Reads Result/Controllers/<Ctrl>/Cases/<Ctrl>_metrics_<sens>.csv and <Ctrl>_<CASE>_sig_<sens>.csv for Ctrl = Map, PI, PID, MapPID. Writes to
%   Result/Compare/Map_vs_PI_vs_PID_vs_MapPID/:
%     ..._summary_<sens>.csv      whole-case RMS e_T, max |e_T|, S, TV, reverse assist, peak T_a (% T_a,max), plus the key windows
%     ..._hyp_<sens>.csv          the hypotheses H1-H6 written before the run (DieuKhien_MapPID.txt B5), with the measured numbers and true/false
%     ..._bars_<sens>.png         RMS e_T and S per case, four controllers
%     ..._<CASE>_cmp_<sens>.png   for DRY and SLIP: e_T and T_a of the four controllers against time
if nargin < 1, sens = 's99999'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
ctrl = {'Map', 'PI', 'PID', 'MapPID'};
col = {[0.165 0.471 0.839], [0.800 0.600 0.000], [0.922 0.408 0.204], [0.290 0.227 0.655]};
cases = {'DRY', 'RAMP', 'SLIP', 'WEAVE', 'EDGE'};
outDir = result_dir('Compare', 'Map_vs_PI_vs_PID_vs_MapPID');
base = 'Map_vs_PI_vs_PID_vs_MapPID';
M = cell(1, 4);
for i = 1:4, M{i} = readtable(fullfile(result_dir(ctrl{i}, 'Cases'), sprintf('%s_metrics_%s.csv', ctrl{i}, sens)), 'TextType', 'string'); end
whole = @(T, c, f) T.(f)(T.Case == c & T.Window == "whole case");
win = @(T, c, w, f) T.(f)(T.Case == c & T.Window == w);

%% summary
rows = {};
for c = cases
    for i = 1:4
        T = M{i};
        rows(end + 1, :) = {c{1}, ctrl{i}, whole(T, c{1}, 'RMS_eT_Nm'), whole(T, c{1}, 'MaxAbs_eT_Nm'), whole(T, c{1}, 'S_Nm'), ...
            whole(T, c{1}, 'TV_Ta_Nm_per_s'), whole(T, c{1}, 'Rev_pct'), whole(T, c{1}, 'Peak_Ta_pct_of_Tamax')}; %#ok<AGROW>
    end
end
S = cell2table(rows, 'VariableNames', {'Case', 'Ctrl', 'RMS_eT_Nm', 'MaxAbs_eT_Nm', 'S_Nm', 'TV_Nm_per_s', 'Rev_pct', 'Peak_Ta_pct_of_Tamax'});
S.Case = string(S.Case); S.Ctrl = string(S.Ctrl);          % string columns so that == works in the hypothesis table
key = {};
for i = 1:4
    T = M{i};
    dryW = T(T.Case == "DRY" & T.Window ~= "whole case", :);
    rampW = T(T.Case == "RAMP" & T.Window ~= "whole case", :);
    edgeW = T(T.Case == "EDGE" & startsWith(T.Window, "v"), :);
    key(end + 1, :) = {ctrl{i}, max(abs(dryW.Mean_eT_signed_pct_of_Tdref)), win(T, "DRY", "v40a0p3r", 'Mean_eT_signed_pct_of_Tdref'), ...
        max(abs(rampW.Mean_eT_signed_pct_of_Tdref)), win(T, "SLIP", "pud_in", 'RMS_eT_Nm'), win(T, "SLIP", "down_post", 'Mean_eT_signed_pct_of_Tdref'), ...
        win(T, "SLIP", "down_post", 'RMS_eT_Nm'), max(abs(edgeW.Mean_eT_signed_pct_of_Tdref))}; %#ok<AGROW>
end
K = cell2table(key, 'VariableNames', {'Ctrl', 'DRY_max_abs_erel_pct', 'DRY_v40a0p3r_erel_pct', 'RAMP_max_abs_erel_pct', 'SLIP_pud_in_RMS_eT_Nm', ...
    'SLIP_down_post_erel_pct', 'SLIP_down_post_RMS_eT_Nm', 'EDGE_max_abs_erel_pct'});
writetable(S, fullfile(outDir, sprintf('%s_summary_%s.csv', base, sens)));
writetable(K, fullfile(outDir, sprintf('%s_keywin_%s.csv', base, sens)));
disp(S); disp(K);

%% hypotheses H1-H6 (B5 of DieuKhien_MapPID.txt)
iP = 3; iX = 4;                                                    % PID, MapPID
g = @(f, i) K.(f)(i);
h = {};
h(end + 1, :) = {'H1', 'RAMP: every window |e_rel| < 1 %', g('RAMP_max_abs_erel_pct', iX), 1, g('RAMP_max_abs_erel_pct', iX) < 1};
v = max(g('EDGE_max_abs_erel_pct', iX), 0); d40 = abs(g('DRY_v40a0p3r_erel_pct', iX));
h(end + 1, :) = {'H2', 'EDGE |e_rel| < 1 % and DRY v40a0p3r |e_rel| < 3 %', v, d40, v < 1 && d40 < 3};
sX = S.S_Nm(S.Case == "DRY" & S.Ctrl == "MapPID"); sP = S.S_Nm(S.Case == "DRY" & S.Ctrl == "PID");
h(end + 1, :) = {'H3', 'S on DRY <= S of PID', sX, sP, sX <= sP};
rX = S.Rev_pct(S.Case == "WEAVE" & S.Ctrl == "MapPID"); rP = S.Rev_pct(S.Case == "WEAVE" & S.Ctrl == "PID");
h(end + 1, :) = {'H4', 'reverse assist on WEAVE < PID', rX, rP, rX < rP};
pX = g('SLIP_pud_in_RMS_eT_Nm', iX); pP = g('SLIP_pud_in_RMS_eT_Nm', iP); dX = g('SLIP_down_post_RMS_eT_Nm', iX); dP = g('SLIP_down_post_RMS_eT_Nm', iP);
h(end + 1, :) = {'H5', 'pud_in and down_post RMS e_T <= 1.05 x PID', max(pX / pP, dX / dP), 1.05, pX <= 1.05 * pP && dX <= 1.05 * dP};
ratio = arrayfun(@(c) S.RMS_eT_Nm(S.Case == c{1} & S.Ctrl == "MapPID") / S.RMS_eT_Nm(S.Case == c{1} & S.Ctrl == "PID"), cases);
h(end + 1, :) = {'H6', 'whole-case RMS e_T <= 1.05 x PID on all five cases', max(ratio), 1.05, all(ratio <= 1.05)};
H = cell2table(h, 'VariableNames', {'Hyp', 'Statement', 'MapPID_value', 'Reference', 'Holds'});
writetable(H, fullfile(outDir, sprintf('%s_hyp_%s.csv', base, sens)));
disp(H);
fprintf('compare_mappid: MapPID / PID RMS e_T ratio per case %s = %s\n', strjoin(cases, ' '), mat2str(ratio, 3));

%% bars
fig = figure('Visible', 'off', 'Position', [100 100 1100 420]);
for p = 1:2
    subplot(1, 2, p); hold on;
    f = {'RMS_eT_Nm', 'S_Nm'}; f = f{p};
    Y = zeros(numel(cases), 4);
    for ic = 1:numel(cases), for i = 1:4, Y(ic, i) = S.(f)(S.Case == cases{ic} & S.Ctrl == ctrl{i}); end, end
    b = bar(Y);
    for i = 1:4, b(i).FaceColor = col{i}; end
    set(gca, 'XTick', 1:numel(cases), 'XTickLabel', cases); grid on;
    ylabel(strrep(f, '_', ' ')); if p == 1, legend(ctrl, 'Location', 'northwest'); end
    title(sprintf('%s, whole case (%s)', strrep(f, '_', ' '), sens));
end
exportgraphics(fig, fullfile(outDir, sprintf('%s_bars_%s.png', base, sens)), 'Resolution', 120); close(fig);

%% time plots of DRY and SLIP
for c = {'DRY', 'SLIP'}
    fig = figure('Visible', 'off', 'Position', [100 100 1100 640]);
    for i = 1:4
        Z = readtable(fullfile(result_dir(ctrl{i}, 'Cases'), sprintf('%s_%s_sig_%s.csv', ctrl{i}, c{1}, sens)));
        subplot(2, 1, 1); hold on; plot(Z.t, Z.e_T, 'Color', col{i}, 'LineWidth', 0.8);
        subplot(2, 1, 2); hold on; plot(Z.t, Z.T_a, 'Color', col{i}, 'LineWidth', 0.8);
    end
    subplot(2, 1, 1); ylabel('e_T [N.m]'); grid on; legend(ctrl, 'Location', 'best'); title(sprintf('%s: e_T and T_a (%s)', c{1}, sens));
    subplot(2, 1, 2); ylabel('T_a [N.m]'); xlabel('t [s]'); grid on;
    exportgraphics(fig, fullfile(outDir, sprintf('%s_%s_cmp_%s.png', base, c{1}, sens)), 'Resolution', 120); close(fig);
end
end
