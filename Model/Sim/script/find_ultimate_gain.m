function out = find_ultimate_gain(KpList, cond)
%FIND_ULTIMATE_GAIN Ziegler-Nichols closed-loop experiment on the closed-loop model
%Model_PID_s.mdl in the Model/ folder (Documents/DieuKhien_PID.txt, section 3).
%
%   Procedure (Seborg, "cycling method"): keep ONLY the P term (Ki = Kd = 0),
%   raise Kp until the torque error oscillates without decaying. The Kp at
%   that boundary is the ultimate gain Kcu and the oscillation period is Pu.
%
%   Scenario: steering angle theta1 rises smoothly to 0.4 rad in 1 s and is
%   then held; v = 20 m/s, mu = 0.8 (unchanged). While theta1 is held, the
%   loop is a plain regulation problem, so any oscillation seen after t = 3 s
%   comes from the loop itself. Oscillation size is measured on the torque
%   error e_T (peak-to-peak) in two windows, [3,6] s and [9,12] s: the ratio
%   late/early is < 1 for a decaying response, ~ 1 for a sustained one, > 1
%   for a growing one. Kcu is refined by bisection between the largest Kp
%   with ratio < 0.9 and the smallest Kp with ratio >= 0.9. A non-finite
%   result (the loop blows up) counts as ratio = Inf. Fixed-step solver ode4.
%
%   Run first: load_pid and load_smc (each also runs load_plant, load_ref),
%   then build_model_pid (it creates Model_PID_s.mdl).
%   KpList (optional): coarse Kp values to scan, default a log-spaced list.
%   cond (optional struct) changes the operating condition and the output:
%     v_ms (default 20), theta1 (default 0.4 rad), mu (default 0.8) - scenario of this experiment;
%     nBisect (default 8) - bisection steps; save (default true) - write the Result/PID files below.
%   Used by scan_kcu_grid.m to measure Kcu on a grid of conditions (with save = false).
%
%   Returns a struct with Kcu, Pu, the coarse scan table and the bisection points. With cond.save
%   (default) it saves to Result/PID/:
%     PID_ultimate_gain_Kp_scan.csv/.png (Kp scan + bisection points) and
%     PID_ultimate_gain_result.csv (Kcu, Pu and the Ziegler-Nichols values).

if nargin < 1 || isempty(KpList)
    KpList = [0.5 1 2 3 3.25 3.5 3.75 4 6];
end
if nargin < 2
    cond = struct();
end
defaults = struct('v_ms', 20, 'theta1', 0.4, 'mu', 0.8, 'nBisect', 8, 'save', true);
for nm = fieldnames(defaults)'
    if ~isfield(cond, nm{1})
        cond.(nm{1}) = defaults.(nm{1});
    end
end

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

dt = 1e-3;
tEnd = 12;
t = (0:dt:tEnd)';
theta1 = cond.theta1*(1 - cos(pi*min(t, 1)))/2;
assignin('base', 'sc_theta1', [t theta1]);
assignin('base', 'sc_v',      [t cond.v_ms*ones(size(t))]);
assignin('base', 'sc_mu',     [t cond.mu*ones(size(t))]);

% This experiment overwrites Kp, Ki, Kd in the base workspace. Restore them when
% the function ends (also on error), so later runs of the closed loop keep the
% Ziegler-Nichols gains computed by load_pid.m.
savedGains = struct();
for nm = {'Kp', 'Ki', 'Kd'}
    if evalin('base', sprintf('exist(''%s'', ''var'')', nm{1}))
        savedGains.(nm{1}) = evalin('base', nm{1});
    end
end
cleanupGains = onCleanup(@() restoreGains(savedGains)); %#ok<NASGU>

% P only
assignin('base', 'Ki', 0);
assignin('base', 'Kd', 0);

scan = zeros(numel(KpList), 3);
bis = zeros(0, 3);   % bisection points [Kp ratio Pu]
for i = 1:numel(KpList)
    [ratio, Pu, amp] = trial(modelDir, KpList(i), t);
    scan(i, :) = [KpList(i) ratio Pu];
    fprintf('Kp = %6.3g: pp(late)/pp(early) = %6.3f, Pu = %6.3g s, pp(late) = %.3g N.m\n', ...
        KpList(i), ratio, Pu, amp);
end

isSustained = scan(:, 2) >= 0.9;
first = find(isSustained, 1, 'first');
assert(~isempty(first) && first > 1, ...
    'find_ultimate_gain: no decaying-to-sustained transition inside KpList');
lo = scan(first-1, 1);  hi = scan(first, 1);  PuHi = scan(first, 3);   % Pu at the current upper bracket
for it = 1:cond.nBisect
    mid = sqrt(lo*hi);
    [ratio, Pu, ~] = trial(modelDir, mid, t);
    bis(end+1, :) = [mid ratio Pu]; %#ok<AGROW>
    if ratio >= 0.9
        hi = mid; PuHi = Pu;
    else
        lo = mid;
    end
    fprintf('  bisection: Kp = %.4f, ratio = %.3f\n', mid, ratio);
end
[~, PuFinal, ~] = trial(modelDir, hi, t);


out.Kcu = hi;
out.Pu  = PuFinal;
out.scan = scan;
out.PuHi = PuHi;
out.bisection = bis;
out.cond = cond;
fprintf('\nUltimate gain Kcu = %.4g, oscillation period Pu = %.4g s (%.3g Hz)\n', hi, PuFinal, 1/PuFinal);
evalin('base', 'clear sc_theta1 sc_mu sc_v');

% ----- save to Result/PID/ -----
if ~cond.save
    return;
end
outDir = result_dir('PID');
allScan = sortrows([scan; bis], 1);   % coarse scan + bisection points
T = array2table(allScan, 'VariableNames', {'Kp', 'peak_to_peak_late_over_early', 'Pu_s'});
writetable(T, fullfile(outDir, 'PID_ultimate_gain_Kp_scan.csv'));
writetable(table(hi, PuFinal, 0.6*hi, PuFinal/2, PuFinal/8, ...
    'VariableNames', {'Kcu', 'Pu_s', 'Kp_ZN', 'tau_I_s', 'tau_D_s'}), ...
    fullfile(outDir, 'PID_ultimate_gain_result.csv'));
fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
r = allScan(:, 2); r(~isfinite(r)) = 1e30;
semilogy(allScan(:, 1), max(r, 1e-16), 'o-'); grid on; hold on;
yline(0.9, 'r--', 'decay/sustained threshold 0.9');
xline(hi, 'k:', sprintf('K_{cu} = %.4g', hi));
xlabel('K_p (P-only)'); ylabel('e_T peak-to-peak, late / early window');
title('PID Ziegler-Nichols experiment: ultimate gain');
exportgraphics(fig, fullfile(outDir, 'PID_ultimate_gain_Kp_scan.png'), 'Resolution', 120);
close(fig);
end

%% ===================== One trial =====================================
function [ratio, Pu, ampLate] = trial(modelDir, Kp, t)
% One P-only run of Model_PID_s.mdl (Model/ folder), scenario from the
% base-workspace matrices sc_theta1, sc_v, sc_mu; solver settings are
% changed in memory only (the model is closed without saving).
    assignin('base', 'Kp', Kp);
    modelName = 'Model_PID_s';
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(fullfile(modelDir, [modelName '.mdl']));
    % fixed step: a diverging loop must not stop the solver (variable step fails)
    set_param(modelName, 'StopTime', sprintf('%.15g', t(end)), 'Solver', 'ode4', 'FixedStep', '0.0005');
    try
        so = sim(Simulink.SimulationInput(modelName));
    catch
        % solver failure = the loop blew up (violent instability)
        close_system(modelName, 0);
        ratio = Inf; Pu = NaN; ampLate = Inf;
        return;
    end
    ts = so.get('log_e_T');
    [tu, iu] = unique(ts.Time, 'last');
    e = interp1(tu, squeeze(ts.Data(iu)), t, 'linear', 'extrap');
    close_system(modelName, 0);

    early = t >= 3 & t <= 6;
    late  = t >= 9 & t <= 12;
    ppEarly = max(e(early)) - min(e(early));
    ampLate = max(e(late)) - min(e(late));
    ratio = ampLate / max(ppEarly, 1e-9);
    if ~isfinite(ratio) || ~isfinite(ampLate)
        ratio = Inf;
    end

    % period from upward zero crossings of the detrended late window
    el = e(late) - mean(e(late));
    tl = t(late);
    idx = find(el(1:end-1) < 0 & el(2:end) >= 0);
    if numel(idx) >= 3
        Pu = (tl(idx(end)) - tl(idx(1))) / (numel(idx) - 1);
    else
        Pu = NaN;
    end
end

function restoreGains(savedGains)
    fn = fieldnames(savedGains);
    for k = 1:numel(fn)
        assignin('base', fn{k}, savedGains.(fn{k}));
    end
end
