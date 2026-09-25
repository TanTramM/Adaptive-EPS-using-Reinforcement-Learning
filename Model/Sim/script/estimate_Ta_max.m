function R = estimate_Ta_max()
%ESTIMATE_TA_MAX Estimate the assist torque needed at each speed, from the
%Plant itself, following the method of Multi-Map [6] and Nguyen:
%
%     T_a,max(v) = T_r,max(v) - T_d,max(v)
%
%   T_r,max(v): largest road reaction torque at speed v, dry road (mu = 0.8),
%               over the operating range of Table 4 (a_y up to 0.4 g). The
%               Plant is solved at STEADY STATE with T_a = 0, where
%               T_s = T_r (Cum1 Eq., T_s = T_r - T_a), for a steering angle
%               theta1 swept until a_y reaches each Table-4 level.
%   T_d,max(v): driver torque wanted at that operating point = Table 4
%               [7] (data/ref.json) at the same (v, a_y).
%
%   So T_a needed at (v, a_y) is T_r - T_d,ref, and T_a,max(v) is its largest
%   value over a_y = 0.1..0.4 g. All computed independently from
%   data/params.json and data/ref.json (no base-workspace variables).
%   Saves to Result/Plant/: Plant_road_torque_vs_lateral_accel_mu0p8.png,
%   Plant_Ta_needed_table_mu0p8.csv (every v and a_y level) and
%   Plant_Ta_max_by_speed_mu0p8.csv (T_a,max per speed).

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
P.Iz = raw.cum3.Iz.value;
P.F_zf = P.m * P.g * P.l_r / (P.l_f + P.l_r);
P.F_zr = P.m * P.g * P.l_f / (P.l_f + P.l_r);

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_kmh = rawRef.v_breakpoints_kmh(:)';
ay_g  = rawRef.ay_breakpoints_g(:)';
Tref  = rawRef.table_Nm;          % row = a_y, column = v

mu = 0.8;
rows = [];
fig = figure('Visible', 'off', 'Position', [100 100 900 600]);
hold on;
for iv = 1:numel(v_kmh)
    v = v_kmh(iv)/3.6;
    [th1, ay, Tr, af, ok] = sweepTheta(P, v, mu);
    for ia = 1:numel(ay_g)
        target = ay_g(ia)*9.81;
        if ~ok || max(ay) < target
            rows = [rows; v_kmh(iv), ay_g(ia), NaN, NaN, NaN, NaN, Tref(ia, iv), NaN]; %#ok<AGROW>
            continue;
        end
        th = interp1(ay, th1, target);
        tr = interp1(ay, Tr, target);
        a  = interp1(ay, af, target);
        rows = [rows; v_kmh(iv), ay_g(ia), th, rad2deg(th/P.n_st), rad2deg(a), tr, Tref(ia, iv), tr - Tref(ia, iv)]; %#ok<AGROW>
    end
    plot(ay/9.81, Tr, 'DisplayName', sprintf('%d km/h', v_kmh(iv)));
    fprintf('  v = %3d km/h: sweep reaches a_y = %.2f g (tire force peak), T_r peak = %.2f N.m, theta1 = %.2f rad\n', ...
        v_kmh(iv), max(ay)/9.81, max(Tr), th1(end));
end
xlabel('a_y [g]'); ylabel('T_r = T_s at T_a = 0 [N.m]'); grid on; legend show;
title('Road reaction torque vs lateral acceleration (mu = 0.8, T_a = 0)');
xline(0.4, 'k:');
exportgraphics(fig, fullfile(result_dir('Plant'), 'Plant_road_torque_vs_lateral_accel_mu0p8.png'), 'Resolution', 120);
close(fig);

T = array2table(rows, 'VariableNames', {'v_kmh', 'ay_g', 'theta1_rad', 'delta_f_deg', ...
    'alpha_f_deg', 'Tr_Nm', 'Td_ref_Nm', 'Ta_need_Nm'});
disp(T);

fprintf('\nT_a,max(v) = max over a_y of (T_r - T_d,ref), mu = %.1f:\n', mu);
Ta_max = zeros(size(v_kmh));
for iv = 1:numel(v_kmh)
    sel = T.v_kmh == v_kmh(iv);
    Ta_max(iv) = max(T.Ta_need_Nm(sel), [], 'omitnan');
    fprintf('  v = %3d km/h: T_a,max = %6.3f N.m (T_r,max = %6.3f, T_d,max = %.2f)\n', v_kmh(iv), ...
        Ta_max(iv), max(T.Tr_Nm(sel), [], 'omitnan'), max(T.Td_ref_Nm(sel)));
end
writetable(T, fullfile(result_dir('Plant'), 'Plant_Ta_needed_table_mu0p8.csv'));
Tmax = table(v_kmh(:), Ta_max(:), 'VariableNames', {'v_kmh', 'Ta_max_Nm'});
writetable(Tmax, fullfile(result_dir('Plant'), 'Plant_Ta_max_by_speed_mu0p8.csv'));
R = T;
end

%% ===================== Steady-state sweep over theta1 =================
function [th1, ay, Tr, af, ok] = sweepTheta(P, v, mu)
% Continuation in theta1 (T_a = 0). Stops when the Magic Formula passes its
% peak (F_yf stops increasing) or Newton fails.
    ok = true;
    x = [0; 0; 0];   % [beta; gamma; theta2]
    th1 = []; ay = []; Tr = []; af = [];
    prevF = -Inf;
    for th = 0:0.01:8
        [x, conv] = newton(P, x, th, v, mu);
        if ~conv
            break;
        end
        [F_yf, F_yr, T_r, alpha_f] = tireModel(P, x(3), x(1), x(2), v, mu);
        th1(end+1) = th; ay(end+1) = (F_yf + F_yr)/P.m; Tr(end+1) = T_r; af(end+1) = alpha_f; %#ok<AGROW>
        if abs(F_yf) < prevF - 1e-6 || abs(alpha_f) > 1.2
            break;
        end
        prevF = abs(F_yf);
    end
    if numel(th1) < 3
        ok = false;
    end
    % use magnitudes (steering left, a_y and T_r negative in this sign convention)
    ay = abs(ay); Tr = abs(Tr); af = abs(af);
end

function [x, conv] = newton(P, x, theta1, v, mu)
    conv = false;
    for it = 1:60
        r = residual(P, x, theta1, v, mu);
        if norm(r) < 1e-10
            conv = true;
            return;
        end
        J = zeros(3);
        for j = 1:3
            dx = zeros(3, 1); dx(j) = 1e-7;
            J(:, j) = (residual(P, x + dx, theta1, v, mu) - r) / 1e-7;
        end
        if rcond(J) < 1e-14
            return;
        end
        x = x - J \ r;
    end
end

function r = residual(P, x, theta1, v, mu)
    [F_yf, F_yr, T_r] = tireModel(P, x(3), x(1), x(2), v, mu);
    r = [(F_yf + F_yr)/(P.m*v) - x(2);
         (P.l_f*F_yf - P.l_r*F_yr)/P.Iz;
         T_r - P.K*(theta1 - x(3))];   % T_a = 0
end

function [F_yf, F_yr, T_r, alpha_f] = tireModel(P, theta2, beta, gamma, v, mu)
% Documents/Cum2_Pacejka.txt Eq.(1)-(11)
    delta_f = theta2 / P.n_st;
    alpha_f = delta_f - beta - P.l_f*gamma/v;
    alpha_r = -beta + P.l_r*gamma/v;
    D = mu * P.F_zf;
    B = P.C_alpha_f / (P.C * D);
    u = B * alpha_f;
    F_yf = D * sin(P.C * atan(u - P.E*(u - atan(u))));
    D_r = mu * P.F_zr;
    B_r = P.C_r / (P.C * D_r);
    u_r = B_r * alpha_r;
    F_yr = D_r * sin(P.C * atan(u_r - P.E*(u_r - atan(u_r))));
    e_p = max(0, P.e_p0 - sign(alpha_f) * P.e_p0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    T_r = e_p / P.n_st * F_yf;
end
