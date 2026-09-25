function test_model_smc()
%TEST_MODEL_SMC Verify Model_SMC.mdl (closed loop Plant + Reference +
%SMC, hand-formatted from the build_model_smc.m output). Self-contained.
%
%   Runs the model itself through its root From Workspace / To Workspace
%   blocks. Scenario: theta1 rises smoothly 0 -> 0.4 rad in 1 s and is held,
%   v = 20 m/s, mu steps 0.8 -> 0.3 at t = 5 s, simulated to t = 15 s.
%   Checks, with references computed INDEPENDENTLY from data/params.json and
%   data/ref.json (run load_smc first - Simulink blocks read the base
%   workspace):
%   (1) Reference wiring: e_T = T_s - T_d_ref at every logged sample, and
%       T_d_ref at the end equals interp2 of Table 4 at (v, a_y_end).
%   (2) Plant wiring: at the end (steady state, T_a held constant), T_s and
%       a_y equal the Newton steady state of the plant equations for the
%       final (theta1, T_a, v, mu).
%   (3) SMC (first order + sat boundary layer) has NO integral action; only checks that e_T(end) is finite and bounded (|e_T(end)| < 3 N.m) - its steady-state offset is expected (Documents/DieuKhien_SMC.txt).

modelFileName = 'Model_SMC';
tEnd = 15;

scriptDir = fileparts(mfilename('fullpath'));   % SMC/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/

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

t = (0:0.001:tEnd)';
theta1 = 0.4*(1 - cos(pi*min(t, 1)))/2;
v = 20; muEnd = 0.3;
assignin('base', 'sc_theta1', [t theta1]);
assignin('base', 'sc_v',      [t v*ones(size(t))]);
assignin('base', 'sc_mu',     [t 0.8 - 0.5*(t >= 5)]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(modelDir, [modelFileName '.mdl']));
set_param(modelFileName, 'StopTime', sprintf('%.15g', tEnd));
so = sim(Simulink.SimulationInput(modelFileName));
close_system(modelFileName, 0);
evalin('base', 'clear sc_theta1 sc_v sc_mu');

Ts   = so.get('log_T_s');
Tref = so.get('log_T_d_ref');
eT   = so.get('log_e_T');
Ta   = so.get('log_T_a');
ay   = so.get('log_a_y');
assert(all(isfinite(eT.Data)), 'e_T is not finite');

% (1) Reference wiring
err1 = max(abs(eT.Data - (Ts.Data - Tref.Data)));
assert(err1 < 1e-9, '(1) e_T ~= T_s - T_d_ref: max err %.3g', err1);
v_bp  = rawRef.v_breakpoints_kmh(:)'/3.6;
ay_bp = rawRef.ay_breakpoints_g(:)'*9.81;
ayEnd = ay.Data(end);
ayc = min(max(abs(ayEnd), min(ay_bp)), max(ay_bp));
TrefInd = sign(ayEnd)*interp2(ay_bp, v_bp, rawRef.table_Nm', ayc, min(max(v, min(v_bp)), max(v_bp)), 'linear');
assert(abs(Tref.Data(end) - TrefInd) < 1e-9, '(1) T_d_ref(end) = %.6g, independent = %.6g', Tref.Data(end), TrefInd);

% (2) Plant wiring: Newton steady state for the final inputs
ss = steadyState(P, theta1(end), Ta.Data(end), v, muEnd);
assert(abs(Ts.Data(end) - ss.T_s) < 5e-3, '(2) T_s(end) = %.6g, steady state = %.6g', Ts.Data(end), ss.T_s);
assert(abs(ayEnd - ss.a_y) < 5e-3, '(2) a_y(end) = %.6g, steady state = %.6g', ayEnd, ss.a_y);

% (3)
assert(abs(eT.Data(end)) < 3, '(3) SMC: |e_T(end)| = %.4g, expected bounded < 3', abs(eT.Data(end)));

fprintf(['[%s] TEST PASS: e_T = T_s - T_d_ref (max err %.2g); T_d_ref(end) = %.5g matches Table 4; ' ...
    'T_s(end) = %.5g (steady state %.5g), a_y(end) = %.5g (steady state %.5g); e_T(end) = %.4g N.m, T_a(end) = %.4g N.m\n'], ...
    modelFileName, err1, Tref.Data(end), Ts.Data(end), ss.T_s, ayEnd, ss.a_y, eT.Data(end), Ta.Data(end));
end

%% ===================== Independent plant steady state ===================
function ss = steadyState(P, theta1, Ta, v, mu)
% Newton on x = [beta; gamma; theta2]
    x = [0; 0; theta1];
    for it = 1:100
        r = residual(P, x, theta1, Ta, v, mu);
        if norm(r) < 1e-12
            break;
        end
        J = zeros(3);
        for j = 1:3
            dx = zeros(3, 1); dx(j) = 1e-7;
            J(:, j) = (residual(P, x + dx, theta1, Ta, v, mu) - r) / 1e-7;
        end
        x = x - J \ r;
    end
    assert(norm(residual(P, x, theta1, Ta, v, mu)) < 1e-9, 'Newton did not converge');
    [F_yf, F_yr] = tireModel(P, x(3), x(1), x(2), v, mu);
    ss.T_s = P.K*(theta1 - x(3));
    ss.a_y = (F_yf + F_yr)/P.m;
end

function r = residual(P, x, theta1, Ta, v, mu)
    [F_yf, F_yr, T_r] = tireModel(P, x(3), x(1), x(2), v, mu);
    r = [(F_yf + F_yr)/(P.m*v) - x(2);
         (P.l_f*F_yf - P.l_r*F_yr)/P.Iz;
         T_r - Ta - P.K*(theta1 - x(3))];
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
    e_p = max(0, P.e_p0 - sign(alpha_f) * P.e_p0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    T_r = e_p / P.n_st * F_yf;
end
