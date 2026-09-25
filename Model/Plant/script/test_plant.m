function test_plant()
%TEST_PLANT Verify the closed-loop Plant.mdl (built by build_plant.m
%from the hand-formatted clusters, no "_s"). Self-contained.
%
%   Requires exactly 1 root-level subsystem with ports found BY NAME:
%   In : theta1, T_a, v, mu | Out: T_s, theta2, a_y, gamma, beta
%
%   Run load_plant.m first (Simulink blocks read the base workspace).
%
%   For constant (theta1, T_a, v, mu) the plant settles to a steady state
%   (theta2_dot = 0, so the friction term T_f*tanh(c*x4) vanishes). The
%   reference steady state is computed INDEPENDENTLY here (parameters read
%   straight from data/params.json, not from the base workspace) by solving
%   with Newton the 3 algebraic equations in x = [beta; gamma; theta2]:
%     (F_yf+F_yr)/(m*v) - gamma    = 0     (beta_dot = 0)
%     l_f*F_yf - l_r*F_yr          = 0     (gamma_dot = 0)
%     T_r - T_a - K*(theta1-theta2) = 0    (J_col balance at rest: T_s = T_r - T_a)
%   then T_s = K*(theta1 - theta2), a_y = (F_yf+F_yr)/m.
%
%   Also checks two physical properties:
%   (1) more assist T_a lowers T_s by LESS than T_a (theta2 shifts by
%       ~T_a/K, which raises delta_f, F_yf, T_r) and raises a_y slightly;
%   (2) at the same angle, lower mu gives lower T_s (the over-assist
%       mechanism: less road torque, same assist).

modelFileName = 'Plant';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

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

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_plant_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 300]);
dutInHarness = [harnessName '/DUT'];

ins = {'theta1', 'T_a', 'v', 'mu'};
for i = 1:numel(ins)
    add_block('simulink/Sources/Constant', [harnessName '/' ins{i} '_in']);
    add_line(harnessName, [ins{i} '_in/1'], portRef(dutInHarness, ins{i}));
end
outs = {'T_s', 'theta2', 'a_y', 'gamma', 'beta'};
for i = 1:numel(outs)
    blk = [harnessName '/' outs{i} '_out'];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', [outs{i} '_log'], 'SaveFormat', 'Timeseries');
    add_line(harnessName, portRef(dutInHarness, outs{i}), [outs{i} '_out/1']);
end
% MaxStep: steep tanh(c*x4) term (c=100). StopTime long enough for the slow
% friction-dominated final approach (time constant ~ (T_f*c)/K ~ 1.4 s).
% Tight RelTol/AbsTol: with default AbsTol=1e-6 the solver stops ~1e-6 rad
% short of the true equilibrium (a 3e-4 N.m bias in T_s = K*(theta1-theta2)).
set_param(harnessName, 'StopTime', '40', 'MaxStep', '0.01', 'RelTol', '1e-8', 'AbsTol', '1e-10');

theta1 = 0.3; v = 20;
%          mu    T_a
cases = [ 0.8,  0.0;
          0.8,  1.0;
          0.4,  0.0;
          0.4,  1.0];
res = zeros(size(cases, 1), numel(outs));   % model results, columns = outs
for i = 1:size(cases, 1)
    mu = cases(i, 1); Ta = cases(i, 2);
    set_param([harnessName '/theta1_in'], 'Value', sprintf('%.15g', theta1));
    set_param([harnessName '/T_a_in'],    'Value', sprintf('%.15g', Ta));
    set_param([harnessName '/v_in'],      'Value', sprintf('%.15g', v));
    set_param([harnessName '/mu_in'],     'Value', sprintf('%.15g', mu));
    simOut = sim(harnessName);
    for k = 1:numel(outs)
        d = simOut.get([outs{k} '_log']).Data;
        assert(~any(isnan(d)), '%s contains NaN', outs{k});
        res(i, k) = d(end);
    end

    ref = steadyStateRef(P, theta1, Ta, v, mu);
    tol = 1e-5 * max(1, max(abs([ref.T_s ref.a_y ref.gamma ref.beta])));
    checkClose(sprintf('case %d T_s', i),    res(i,1), ref.T_s,    tol);
    checkClose(sprintf('case %d theta2', i), res(i,2), ref.theta2, tol);
    checkClose(sprintf('case %d a_y', i),    res(i,3), ref.a_y,    tol);
    checkClose(sprintf('case %d gamma', i),  res(i,4), ref.gamma,  tol);
    checkClose(sprintf('case %d beta', i),   res(i,5), ref.beta,   tol);
    fprintf(['[%s] case %d (mu=%.2g, T_a=%.2g): T_s=%.6g (ref %.6g) theta2=%.6g (ref %.6g) ' ...
        'a_y=%.6g (ref %.6g)\n'], modelFileName, i, mu, Ta, res(i,1), ref.T_s, ...
        res(i,2), ref.theta2, res(i,3), ref.a_y);
end

% (1) more assist lowers T_s, but by LESS than T_a: T_a pushes theta2 up by
%     ~T_a/K, which raises delta_f, F_yf and hence T_r (partly compensating)
%     - the fast path through the spring, plus a slight rise in a_y (slow path)
for pair = [1 2; 3 4]'
    dTs = res(pair(2),1) - res(pair(1),1);
    assert(dTs < -0.5 && dTs > -1.0, 'T_a=1 should lower T_s by 0.5..1.0, got %.6g', dTs);
    assert(res(pair(2),3) > res(pair(1),3), 'more assist should raise a_y slightly (theta2 shifts)');
end
% (2) same angle, lower mu -> lower T_s (over-assist mechanism)
assert(res(3,1) < res(1,1), 'Expected T_s(mu=0.4) < T_s(mu=0.8) at the same angle');

fprintf(['[%s] TEST PASS: steady state matches the Newton reference in 4 cases; ' ...
    'more T_a lowers T_s (by less than T_a); T_s drops %.3g%% from mu=0.8 to 0.4 at theta1=%.2g rad\n'], ...
    modelFileName, 100*(res(1,1) - res(3,1))/res(1,1), theta1);

close_system(harnessName, 0);
close_system(modelFileName, 0);
end

%% ===================== Independent steady-state reference ================
function ref = steadyStateRef(P, theta1, Ta, v, mu)
% Newton iteration on x = [beta; gamma; theta2], finite-difference Jacobian.
    x = [0; 0; theta1];
    for it = 1:100
        r = residual(P, x, theta1, Ta, v, mu);
        if norm(r) < 1e-12
            break;
        end
        J = zeros(3);
        h = 1e-7;
        for j = 1:3
            dx = zeros(3, 1); dx(j) = h;
            J(:, j) = (residual(P, x + dx, theta1, Ta, v, mu) - r) / h;
        end
        x = x - J \ r;
    end
    assert(norm(residual(P, x, theta1, Ta, v, mu)) < 1e-9, 'Newton did not converge');
    [F_yf, F_yr] = tireModel(P, x(3), x(1), x(2), v, mu);
    ref.beta   = x(1);
    ref.gamma  = x(2);
    ref.theta2 = x(3);
    ref.a_y    = (F_yf + F_yr) / P.m;
    ref.T_s    = P.K * (theta1 - x(3));
end

function r = residual(P, x, theta1, Ta, v, mu)
% x = [beta; gamma; theta2]
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

function checkClose(label, actual, ref, tol)
    assert(abs(actual - ref) < tol, '%s: model=%.10g, reference=%.10g', label, actual, ref);
end

%% ===================== Utility functions =====================
function subPath = findRootSubsystem(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName
% inside subPath - ports are found BY NAME, never by assumed order.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
