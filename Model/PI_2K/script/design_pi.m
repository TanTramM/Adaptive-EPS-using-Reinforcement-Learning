function D = design_pi(wcGrid, aMin, tag)
%DESIGN_PI Linear design of the PI controller of the assist loop (Documents/PI_2K/pid.txt), designed from the PRSM only.
%
%   D = design_pi()                   crossover grid wcGrid = [0.5 1 1.5 2 2.5 3 3.5 4 4.5 5 6 6.5 7], aMin = 0.1
%   D = design_pi(wcGrid, aMin, tag)  tag is appended to the file names (default '': the files read by run_pi_sweep.m)
%
%   Design loop (the same linearized loop the Map lead stage is designed on, Documents/Map_6_8/map.txt section 2.4, held steering angle):
%       G(s) = K / (J_col s^2 + C_col s + K + k_r) * Gm(s),   Gm(s) = wm / (s + wm)   (motor lag, data/actuator.json)
%   for the dry road (k_r = e_p0*C_alpha_f/n_st^2) and the saturated tire (k_r = 0), both discretized with a zero-order hold at Ts = 1 ms.
%   PI (Forward Euler integral):  C(z) = Kp * (1 + (Ts/Ti) / (z - 1)).
%   For every crossover frequency wc of the grid the pair (Kp, Ti) is found as follows. With a = wc*Ti (a >= aMin), Kp(a) makes |C*G1| = 1
%   at wc on the dry road (nominal plant), so only a is free. Kp grows with a, so the smallest a is the smallest high-frequency gain
%   (Kp is the noise gain) and the strongest integral action. The smallest a is taken that keeps, on BOTH plants:
%       closed loop stable, phase margin >= 45 deg, gain margin >= 2 (6 dB).
%   aMin = 0.1 (the PI zero a decade above the crossover) stops the search from degenerating into a pure integrator (a -> 0, Kp -> 0).
%   The largest feasible a is also reported (a_max_feasible): the feasible band of a is narrow because the column resonance (about +9 dB
%   at 35-39 rad/s) limits the loop gain there; above wc of about 6 rad/s no PI is feasible.
%   Writes Result/PI_2K/Design/: PI_design_grid.csv (one row per wc), PI_plant_bode.png, PI_design_margins.png. Returns the table.

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
if nargin < 1, wcGrid = [0.5 1 1.5 2 2.5 3 3.5 4 4.5 5 6 6.5 7]; end
if nargin < 2, aMin = 0.1; end
if nargin < 3, tag = ''; end
Ts = 0.001; pmMin = 45; gmMin = 2;
outDir = result_dir('PI_2K', 'Design');

[G1c, G0c, info] = plantLoops(modelDir);
G1 = c2d(G1c, Ts, 'zoh');
G0 = c2d(G0c, Ts, 'zoh');
aGrid = logspace(log10(aMin), 2.5, 150);

rows = [];
for wc = wcGrid
    z = exp(1j * wc * Ts);
    g1 = abs(squeeze(freqresp(G1, wc)));
    best = []; aMax = nan;
    for a = aGrid
        Ti = a / wc;
        Kp = 1 / (g1 * abs(1 + (Ts / Ti) / (z - 1)));
        [ok, m] = checkLoop(Kp, Ti, Ts, G1, G0, pmMin, gmMin);
        if ok
            aMax = a;
            if isempty(best), best = [Kp, Ti, a, m]; end
        end
    end
    if isempty(best)
        rows = [rows; wc, nan(1, 19)]; %#ok<AGROW>
        fprintf('design_pi: wc = %g rad/s infeasible (PM >= %g deg and GM >= %g on both plants)\n', wc, pmMin, gmMin);
        continue;
    end
    Kp = best(1); Ti = best(2); m = best(4:end);
    C = tf(Kp * [1, -(1 - Ts / Ti)], [1, -1], Ts);
    rows = [rows; wc, Kp, Kp / Ti, Ti, best(3), m, rmsGain(C, Ts), aMax, abs(squeeze(freqresp(feedback(1, C * G1), 2 * pi * 0.5)))]; %#ok<AGROW>
    fprintf('design_pi: wc %5.1f  Kp %.4g  Ki %.4g 1/s  Ti %.4g s (a %.2f)  PM %.1f/%.1f deg  GM %.2f/%.2f  Ms %.2f/%.2f\n', wc, Kp, Kp / Ti, Ti, best(3), ...
        m(1), m(4), m(2), m(5), m(3), m(6));
end
D = array2table(rows, 'VariableNames', {'wc_design_rad_s', 'Kp', 'Ki_1_per_s', 'Ti_s', 'a_wcTi', 'PM_dry_deg', 'GM_dry', 'Ms_dry', ...
    'PM_sat_deg', 'GM_sat', 'Ms_sat', 'wc_dry_rad_s', 'wc_sat_rad_s', 'wcg_dry_rad_s', 'wcg_sat_rad_s', 'stable_dry', 'stable_sat', 'rms_gain_C', 'a_max_feasible', 'S_at_0p5Hz_dry'});
D.feasible = ~isnan(D.Kp);
writetable(D, fullfile(outDir, ['PI_design_grid' tag '.csv']));
if ~isempty(tag), return; end
plotBode(G1c, G0c, info, fullfile(outDir, 'PI_plant_bode.png'));
writePlantInfo(G1c, G0c, info, fullfile(outDir, 'PI_plant_resonance.csv'));
plotMargins(D, fullfile(outDir, 'PI_design_margins.png'));
end

%% ===================== plants =====================
function [G1c, G0c, info] = plantLoops(modelDir)
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    P = struct();
    for grp = {'cum1', 'cum2'}
        fn = fieldnames(raw.(grp{1}));
        for i = 1:numel(fn), P.(fn{i}) = raw.(grp{1}).(fn{i}).value; end
    end
    wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;
    kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
    Gm = tf(wm, [1 wm]);
    G1c = tf(P.K, [P.J_col, P.C_col, P.K + kr]) * Gm;
    G0c = tf(P.K, [P.J_col, P.C_col, P.K]) * Gm;
    info = struct('K', P.K, 'J_col', P.J_col, 'C_col', P.C_col, 'kr', kr, 'wm', wm);
end

%% ===================== margins of one design point =====================
function [ok, m] = checkLoop(Kp, Ti, Ts, G1, G0, pmMin, gmMin)
    C = tf(Kp * [1, -(1 - Ts / Ti)], [1, -1], Ts);
    m = zeros(1, 12);   % [PM GM Ms (dry), PM GM Ms (sat), wc (dry, sat), wcg (dry, sat), stable (dry, sat)]
    ok = true;
    for k = 1:2
        if k == 1, G = G1; else, G = G0; end
        L = C * G;
        stable = isstable(feedback(L, 1));
        [gm, pm, wcg, wcp] = margin(L);
        Ms = norm(feedback(1, L), Inf);
        j = (k - 1) * 3;
        m(1 + j) = pm; m(2 + j) = gm; m(3 + j) = Ms;
        m(6 + k) = wcp; m(8 + k) = wcg;
        m(10 + k) = stable;
        ok = ok && stable && pm >= pmMin && gm >= gmMin;
    end
end

function r = rmsGain(C, Ts)
    w = linspace(1, pi / Ts, 2000);
    r = sqrt(mean(abs(squeeze(freqresp(C, w))).^2));
end

function writePlantInfo(G1c, G0c, info, file)
    w = logspace(0, 3.2, 8000);
    nm = {'dry road'; 'saturated tire'}; kr = [info.kr; 0]; Gs = {G1c, G0c};
    dc = zeros(2, 1); pk = dc; wp = dc; zeta = dc; w180 = dc;
    for q = 1:2
        mag = squeeze(abs(freqresp(Gs{q}, w))); ph = squeeze(angle(freqresp(Gs{q}, w)));
        dc(q) = mag(1); [pk(q), i] = max(mag); wp(q) = w(i);
        zeta(q) = info.C_col / (2 * sqrt((info.K + kr(q)) * info.J_col));
        k = find(unwrap(ph) <= -pi, 1); w180(q) = w(k);
    end
    writetable(table(nm, kr, dc, pk, 20 * log10(pk), wp, zeta, w180, 'VariableNames', {'plant', 'k_r_Nm_per_rad', 'dc_gain', 'peak_gain', 'peak_dB', ...
        'peak_rad_s', 'zeta_column', 'phase_minus180_rad_s'}), file);
end

%% ===================== figures =====================
function plotBode(G1c, G0c, info, file)
    w = logspace(0, 3.2, 600);
    f = figure('Visible', 'off', 'Position', [50 50 1000 750]);
    for k = 1:2
        if k == 1, G = G1c; nm = sprintf('dry road, k_r = %.1f N.m/rad', info.kr); c = [0.165 0.471 0.839];
        else, G = G0c; nm = 'saturated tire, k_r = 0'; c = [0.85 0.33 0.1]; end
        [mag, ph] = bode(G, w);
        subplot(2, 1, 1); semilogx(w, 20 * log10(squeeze(mag)), 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm); hold on;
        subplot(2, 1, 2); semilogx(w, squeeze(ph), 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm); hold on;
    end
    subplot(2, 1, 1); grid on; ylabel('|G| [dB]'); legend('Location', 'southwest'); title('Plant of the assist loop: T_a to T_s, with the motor lag (held steering angle)');
    subplot(2, 1, 2); grid on; ylabel('phase [deg]'); xlabel('\omega [rad/s]'); yline(-180, 'k--');
    exportgraphics(f, file, 'Resolution', 130); close(f);
end

function plotMargins(D, file)
    f = figure('Visible', 'off', 'Position', [50 50 1000 800]);
    ok = D.feasible;
    subplot(3, 1, 1); semilogx(D.wc_design_rad_s(ok), D.Kp(ok), 'o-', 'LineWidth', 1.4); grid on; ylabel('K_p (noise gain)');
    title('PI design versus the crossover frequency (smallest T_i with PM >= 45 deg, GM >= 2 on both plants)');
    subplot(3, 1, 2); semilogx(D.wc_design_rad_s(ok), D.Ki_1_per_s(ok), 'o-', 'LineWidth', 1.4); grid on; ylabel('K_i [1/s]');
    subplot(3, 1, 3); hold on;
    semilogx(D.wc_design_rad_s(ok), D.PM_dry_deg(ok), 'o-', 'LineWidth', 1.4, 'DisplayName', 'PM dry [deg]');
    semilogx(D.wc_design_rad_s(ok), D.PM_sat_deg(ok), 's-', 'LineWidth', 1.4, 'DisplayName', 'PM saturated [deg]');
    semilogx(D.wc_design_rad_s(ok), 10 * D.GM_dry(ok), 'o--', 'LineWidth', 1.2, 'DisplayName', '10 x GM dry');
    semilogx(D.wc_design_rad_s(ok), 10 * D.GM_sat(ok), 's--', 'LineWidth', 1.2, 'DisplayName', '10 x GM saturated');
    set(gca, 'XScale', 'log'); grid on; legend('Location', 'best'); xlabel('design crossover \omega_c [rad/s]');
    for q = 1:3, subplot(3, 1, q); set(gca, 'XTick', [0.5 1 2 3 5 7], 'XLim', [0.45 8]); end
    exportgraphics(f, file, 'Resolution', 130); close(f);
end
