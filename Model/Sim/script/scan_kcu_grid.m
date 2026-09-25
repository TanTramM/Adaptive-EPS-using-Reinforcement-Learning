function R = scan_kcu_grid(vKmh, muList, ayFractions)
%SCAN_KCU_GRID Measure the ultimate gain Kcu (Ziegler-Nichols experiment) on a grid of operating conditions
%inside the Plant boundaries and export the data as CSV for the report.
%
%   For every speed v in vKmh (default [20 40 60 80 100] km/h), friction mu in muList (default [0.2 0.5 0.8]) and
%   fraction f in ayFractions (default [0.5 1]) the operating point is a_y = f * a_y,lim(v, mu), with
%       a_y,lim(v, mu) = min( a_y,max(v, mu) from data/boundaries.json , 0.4 g )        (Documents/Boundaries.txt)
%   (0.4 g = upper limit of Table 4, the setpoint of the controller). The steering angle theta1 is the one that
%   gives this a_y with the ideal assist, i.e. e_T = 0 at steady state:
%       theta1 = n_st*delta_f + T_d,ref(v, a_y)/K,   delta_f from the steady state of the small-angle Plant.
%   Then find_ultimate_gain (P-only loop, theta1 held, fixed-step ode4) gives Kcu and Pu at that condition.
%
%   Run first: load_pid (runs load_plant, load_ref) and build_model_pid (creates Model_PID_s.mdl).
%   Results (Result/PID/):
%     PID_Kcu_grid.csv               one row per condition: v_kmh, mu, ay_fraction, ay_g, theta1_rad, Kcu, Pu_s,
%                                    ZN gains (Kp, Ki, Kd), margin_current = Kcu / Kp_current, status
%     PID_Kcu_grid_scan_details.csv  every P-only run: condition, Kp, peak-to-peak ratio late/early, Pu, phase
%   Runtime: about 1.5 min per condition.

if nargin < 1, vKmh = [20 40 60 80 100]; end
if nargin < 2, muList = [0.2 0.5 0.8]; end
if nargin < 3, ayFractions = [0.5 1]; end

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

% ---- independent data: plant parameters, Table 4, boundaries, current PID design ----
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
P.Iz = raw.cum3.Iz.value;
L = P.l_f + P.l_r;
P.F_zf = P.m * P.g * P.l_r / L;
P.F_zr = P.m * P.g * P.l_f / L;
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
bnd = jsondecode(fileread(fullfile(modelDir, 'data', 'boundaries.json')));
pidJson = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
KpCurrent = 0.6 * pidJson.Kcu.value;

KpList = [1 2 3 4 6 8 12];
rows = {};
details = {};
id = 0;
for v = vKmh
    for mu = muList
        ayLim = min(interp2(bnd.a_y.mu, bnd.a_y.v_kmh, bnd.a_y.table, mu, v, 'linear'), 0.4);
        for f = ayFractions
            id = id + 1;
            ayG = f * ayLim;
            theta1 = operatingTheta1(P, ref, v/3.6, ayG, mu);
            cond = struct('v_ms', v/3.6, 'theta1', theta1, 'mu', mu, 'nBisect', 6, 'save', false);
            status = 'ok'; Kcu = NaN; Pu = NaN; r = [];
            try
                evalc('r = find_ultimate_gain(KpList, cond);');
            catch ME
                r = []; status = strtok(ME.message, newline);
            end
            if ~isempty(r)
                Kcu = r.Kcu; Pu = r.Pu;
                for k = 1:size(r.scan, 1)
                    details(end+1, :) = {id, v, mu, ayG, r.scan(k, 1), r.scan(k, 2), r.scan(k, 3), 'coarse'}; %#ok<AGROW>
                end
                for k = 1:size(r.bisection, 1)
                    details(end+1, :) = {id, v, mu, ayG, r.bisection(k, 1), r.bisection(k, 2), r.bisection(k, 3), 'bisection'}; %#ok<AGROW>
                end
            end
            Kp = 0.6*Kcu; tauI = Pu/2; tauD = Pu/8;
            rows(end+1, :) = {id, v, mu, f, ayG, theta1, Kcu, Pu, Kp, Kp/tauI, Kp*tauD, Kcu/KpCurrent, status}; %#ok<AGROW>
            fprintf('scan_kcu_grid %2d: v = %3d km/h, mu = %.1f, a_y = %.3f g, theta1 = %.3f rad -> Kcu = %.3f, Pu = %.4f s (%s)\n', ...
                id, v, mu, ayG, theta1, Kcu, Pu, status);
        end
    end
end

R = cell2table(rows, 'VariableNames', {'id', 'v_kmh', 'mu', 'ay_fraction', 'ay_g', 'theta1_rad', 'Kcu', 'Pu_s', ...
    'Kp_ZN', 'Ki_ZN_1_per_s', 'Kd_ZN_s', 'margin_current_Kcu_over_Kp', 'status'});
D = cell2table(details, 'VariableNames', {'id', 'v_kmh', 'mu', 'ay_g', 'Kp', 'pp_late_over_early', 'Pu_s', 'phase'});
outDir = result_dir('PID');
writetable(R, fullfile(outDir, 'PID_Kcu_grid.csv'));
writetable(D, fullfile(outDir, 'PID_Kcu_grid_scan_details.csv'));

ok = strcmp(R.status, 'ok');
[kmin, imin] = min(R.Kcu(ok)); idx = find(ok); imin = idx(imin);
fprintf('\nKcu on the grid: min = %.3f (v = %d km/h, mu = %.1f, a_y = %.3f g), max = %.3f; Kp of the current design = %.3f\n', ...
    kmin, R.v_kmh(imin), R.mu(imin), R.ay_g(imin), max(R.Kcu(ok)), KpCurrent);
fprintf('Written: %s and %s\n', fullfile(outDir, 'PID_Kcu_grid.csv'), fullfile(outDir, 'PID_Kcu_grid_scan_details.csv'));
end

%% ===================== Operating point (plain MATLAB, no Simulink) =======
function theta1 = operatingTheta1(P, ref, v, ayG, mu)
% theta1 that gives lateral acceleration ayG (in g) with e_T = 0: theta1 = n_st*delta_f + T_d,ref/K, with delta_f from
% the steady state of the small-angle Plant (continuation on a_y). T_d,ref: Table 4, clipped to its range like the
% Reference block.
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    z = [0.001; 0.01; 0.001];   % [beta; gamma; delta_f]
    for a = unique([0.01:0.01:ayG, ayG])
        F = @(z) [ (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / (P.m * v) - z(2);
                   (P.l_f * fyf(z, v, P, mu) - P.l_r * fyr(z, v, P, mu)) / P.Iz;
                   (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / P.m - a * 9.81 ];
        [z, ~, flag] = fsolve(F, z, opt);
        assert(flag > 0, 'no steady state at v = %g m/s, mu = %g, a_y = %g g', v, mu, a);
    end
    vBp = ref.v_breakpoints_kmh(:)';
    aBp = ref.ay_breakpoints_g(:);
    Tdref = interp2(vBp, aBp, ref.table_Nm, min(max(v*3.6, vBp(1)), vBp(end)), min(max(ayG, aBp(1)), aBp(end)), 'linear');
    theta1 = P.n_st * z(3) + Tdref / P.K;
end

function F = magicFormula(P, alpha, mu, Fz, Calpha)
    D = mu * Fz;
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function F = fyf(z, v, P, mu)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    F = magicFormula(P, alpha_f, mu, P.F_zf, P.C_alpha_f);
end

function F = fyr(z, v, P, mu)
    alpha_r = -z(1) + P.l_r * z(2) / v;
    F = magicFormula(P, alpha_r, mu, P.F_zr, P.C_r);
end
