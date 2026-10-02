function verify_Ta_need()
%VERIFY_TA_NEED Check the T_a,max formula on the Simulink Plant_s model.
%
%   Formula (Documents/Ref/ref.txt Eq. (4); the limit itself is computed by make_ta_max.m): at an operating point with lateral
%   acceleration a_y, the assist that makes the sensor torque equal to the
%   wanted torque is  T_a = T_r(a_y) - T_d,ref(v, a_y).
%
%   This script tests the FORMULA (not the tuning of any controller):
%   for each speed v and the largest Table-4 level a_y = 0.4 g, it solves
%   the 5 steady-state equations for [beta, gamma, theta2, theta1, T_a]
%     beta_dot = 0, gamma_dot = 0, J_col balance (T_s = T_r - T_a),
%     a_y = target, T_s = T_d,ref(v, target)
%   independently in MATLAB from data/params.json, then feeds the resulting
%   (theta1, T_a, v, mu = 0.8) into Plant_s.mdl and checks that the model
%   settles to a_y = target and T_s = T_d,ref (steady state, T_a held).
%
%   Run first: load_plant, then build_plant_s. Saves the table to
%   Result/Reference/Reference_Ta_need_formula_check_ay0p4g_mu0p8.csv.

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir
plantDir  = fullfile(modelDir, 'Plant');

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
ia = numel(ay_g);                 % largest level, 0.4 g

modelName = 'Plant_s';
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
load_system(fullfile(plantDir, [modelName '.mdl']));
subs = find_system(modelName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
h = 'verify_Ta_harness';
if bdIsLoaded(h)
    close_system(h, 0);
end
new_system(h);
add_block(subs{1}, [h '/DUT']);
dut = [h '/DUT'];
ins = {'theta1', 'T_a', 'v', 'mu'};
for i = 1:numel(ins)
    add_block('simulink/Sources/Constant', [h '/' ins{i} '_in']);
    add_line(h, [ins{i} '_in/1'], portRef(dut, ins{i}));
end
outs = {'T_s', 'a_y'};
for i = 1:numel(outs)
    add_block('simulink/Sinks/To Workspace', [h '/' outs{i} '_out']);
    set_param([h '/' outs{i} '_out'], 'VariableName', ['V_' outs{i}], 'SaveFormat', 'Array');
    add_line(h, portRef(dut, outs{i}), [outs{i} '_out/1']);
end
set_param(h, 'StopTime', '40', 'MaxStep', '0.01', 'RelTol', '1e-8', 'AbsTol', '1e-10');

fprintf('%8s %10s %10s %12s %12s %12s %12s\n', 'v[km/h]', 'theta1', 'T_a', 'a_y sim[g]', 'a_y ref[g]', 'T_s sim', 'T_d,ref');
maxErr = 0;
res = zeros(numel(v_kmh), 7);   % [v theta1 T_a a_y_sim[g] a_y_ref[g] T_s_sim T_d_ref]
for iv = 1:numel(v_kmh)
    v = v_kmh(iv)/3.6;
    target = ay_g(ia)*9.81;
    Tw = Tref(ia, iv);
    [th1, Ta] = solveOperatingPoint(P, v, 0.8, target, Tw);
    set_param([h '/theta1_in'], 'Value', sprintf('%.15g', th1));
    set_param([h '/T_a_in'],    'Value', sprintf('%.15g', Ta));
    set_param([h '/v_in'],      'Value', sprintf('%.15g', v));
    set_param([h '/mu_in'],     'Value', '0.8');
    so = sim(h);
    vTs = so.get('V_T_s'); Ts_sim = vTs(end);
    vAy = so.get('V_a_y'); ay_sim = vAy(end);
    fprintf('%8d %10.4f %10.4f %12.5f %12.5f %12.5f %12.5f\n', v_kmh(iv), th1, Ta, ...
        ay_sim/9.81, ay_g(ia), Ts_sim, Tw);
    maxErr = max([maxErr, abs(Ts_sim - Tw), abs(ay_sim - target)]);
    res(iv, :) = [v_kmh(iv), th1, Ta, ay_sim/9.81, ay_g(ia), Ts_sim, Tw];
end
writetable(array2table(res, 'VariableNames', {'v_kmh', 'theta1_rad', 'Ta_Nm', 'ay_sim_g', 'ay_target_g', 'Ts_sim_Nm', 'Td_ref_Nm'}), ...
    fullfile(result_dir('Reference'), 'Reference_Ta_need_formula_check_ay0p4g_mu0p8.csv'));
assert(maxErr < 1e-3, 'Formula check failed: max error %.3g', maxErr);
fprintf('\nPASS: T_a = T_r(a_y) - T_d,ref makes the Plant settle at a_y = 0.4 g and T_s = T_d,ref (max error %.2g).\n', maxErr);
close_system(h, 0);
close_system(modelName, 0);
end

%% ===================== 5-equation steady state =====================
function [theta1, Ta] = solveOperatingPoint(P, v, mu, ayTarget, Tw)
% Unknowns z = [beta; gamma; theta2; theta1; T_a] (positive theta1 gives
% positive a_y and T_s in the Plant).
    z = [0; 0; 1; 1; 0];
    for it = 1:200
        r = residual(P, z, v, mu, ayTarget, Tw);
        if norm(r) < 1e-11
            break;
        end
        J = zeros(5);
        for j = 1:5
            dz = zeros(5, 1); dz(j) = 1e-7;
            J(:, j) = (residual(P, z + dz, v, mu, ayTarget, Tw) - r) / 1e-7;
        end
        z = z - J \ r;
    end
    assert(norm(residual(P, z, v, mu, ayTarget, Tw)) < 1e-9, 'Operating point did not converge');
    theta1 = z(4);
    Ta = z(5);
end

function r = residual(P, z, v, mu, ayT, TsT)
    beta = z(1); gamma = z(2); theta2 = z(3); theta1 = z(4); Ta = z(5);
    [F_yf, F_yr, T_r] = tireModel(P, theta2, beta, gamma, v, mu);
    Ts = P.K*(theta1 - theta2);
    r = [(F_yf + F_yr)/(P.m*v) - gamma;
         (P.l_f*F_yf - P.l_r*F_yr)/P.Iz;
         T_r - Ta - Ts;
         (F_yf + F_yr)/P.m - ayT;
         Ts - TsT];
end

function [F_yf, F_yr, T_r] = tireModel(P, theta2, beta, gamma, v, mu)
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
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    T_r = e_p / P.n_st * F_yf;
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
