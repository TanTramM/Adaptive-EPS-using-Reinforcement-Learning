function test_pidlag(ctrl)
%TEST_PIDLAG Verify PIDLag.mdl / PIDOpt.mdl (PID, then a lag stage, anti-windup on the command after the lag; built by build_pidlag.m).
%
%   test_pidlag('PIDLag')   or   test_pidlag('PIDOpt')   (default: both)
%   OPEN-LOOP test on the 1 ms grid (no plant): synthetic T_s, v, a_y and an independent T_a_lim (so the anti-windup term is active). The expected T_a is computed
%   HERE from data/ref.json and hand-written recursions, not from the base-workspace variables of the model:
%     e[k] = T_s[k] - T_d,ref(v[k], a_y[k]),  d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]),  a = Tf/(Tf+Ts), b = Kd/(Tf+Ts)
%     u[k] = Kp e[k] + u_I[k] + d[k],   T_a[k] = (lag Tustin by hand) u[k],   u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k])),  Kaw = Ki/Kp
%   Cases: (a) lag off (H = 1); (b) a lag z1 = 20, p1 = 8 rad/s with T_a_lim clamping part of the time. Then the end-to-end check: with the lag off and the gains of
%   data/pid.json, Model_<ctrl> and Model_PID give the same CALIB scores (the new controller reproduces PID when it is given PID's gains).
if nargin < 1
    test_pidlag('PIDOpt'); test_pidlag('PIDLag'); return;
end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
ctlDir    = fullfile(modelDir, 'Controllers', ctrl);
addpath(modelDir); setup_paths;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(ctlDir, ['load_' lower(ctrl) '.m']), '\', '/')));
Ts = 1e-3; P = [ctrl '_'];

t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.3 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v   = 16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t);
a_y = 3.0 * sin(2*pi*0.4*t);
T_a_lim = 3.0 * sin(2*pi*0.2*t + 0.5) + 0.4;
harness = 'test_pidlag_harness';
if bdIsLoaded(harness), close_system(harness, 0); end
if bdIsLoaded(ctrl), close_system(ctrl, 0); end
load_system(fullfile(ctlDir, [ctrl '.mdl']));
subs = find_system(ctrl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, '%s must have exactly 1 root subsystem', ctrl);
new_system(harness);
dut = [harness '/DUT'];
add_block(subs{1}, dut);
sigs = {T_s, v, a_y, T_a_lim}; names = {'T_s', 'v', 'a_y', 'T_a_lim'};
for i = 1:numel(names)
    assignin('base', ['tm_' names{i}], [t sigs{i}]);
    add_block('simulink/Sources/From Workspace', [harness '/FW_' names{i}], 'VariableName', ['tm_' names{i}], 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_line(harness, ['FW_' names{i} '/1'], portRef(dut, names{i}));
    add_block('simulink/Sinks/To Workspace', [harness '/LG_' names{i}], 'VariableName', ['tm_in_' names{i}], 'SaveFormat', 'Timeseries');
    add_line(harness, ['FW_' names{i} '/1'], ['LG_' names{i} '/1']);
end
add_block('simulink/Sinks/To Workspace', [harness '/Ta_out'], 'VariableName', 'tm_Ta_log', 'SaveFormat', 'Timeseries');
add_line(harness, portRef(dut, 'T_a'), 'Ta_out/1');
set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));
rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp = rawRef.fine.v_breakpoints_kmh(:)' / 3.6; ay_bp = rawRef.fine.ay_breakpoints_g(:)' * 9.81; tab = rawRef.fine.table_Nm';

cases = struct('name', {'(a) lag off', '(b) lag z1 20, p1 8, clamped'}, 'lag', {[], struct('z1', 20, 'p1', 8)}, ...
    'Kp', {0.7, 0.5}, 'Ki', {12, 20}, 'Kd', {0.02, 0.01}, 'Tf', {0.008, 0.004});
if strcmp(ctrl, 'PIDOpt'), cases = cases(1); end
for ic = 1:numel(cases)
    c = cases(ic);
    d = struct('Ts_ctrl', Ts, 'Kp', c.Kp, 'Ki', c.Ki, 'Kd', c.Kd, 'Tf', c.Tf);
    if ~isempty(c.lag), d.lag = c.lag; end
    V = pidlag_variables(ctrl, d);
    assert(abs(V.([P 'Kaw']) - c.Ki / c.Kp) < 1e-12, 'Kaw must be Ki/Kp');
    fn = fieldnames(V);
    for i = 1:numel(fn), assignin('base', fn{i}, V.(fn{i})); end
    so = sim(harness);
    ts = so.get('tm_Ta_log'); Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:);
    assert(numel(Ta_sim) == n, 'unexpected number of samples');
    in = struct();
    for i = 1:numel(names), q = so.get(['tm_in_' names{i}]); in.(names{i}) = reshape(squeeze(q.Data), [], 1); end
    Td = sign(in.a_y) .* interp2(ay_bp, v_bp, tab, min(abs(in.a_y), ay_bp(end)), min(max(in.v, v_bp(1)), v_bp(end)), 'linear');
    % lag by hand (Tustin of (s/z1+1)/(s/p1+1)), as a recursion y[k] = b0 u[k] + b1 u[k-1] - a1 y[k-1]
    if isempty(c.lag), b0 = 1; b1 = 0; a1 = 0; else
        aa = 2 / Ts; den0 = aa / c.lag.p1 + 1;
        b0 = (aa / c.lag.z1 + 1) / den0; b1 = (1 - aa / c.lag.z1) / den0; a1 = (1 - aa / c.lag.p1) / den0;
    end
    Ta_ref = zeros(n, 1); uI = 0; dk = 0; Tsp = 0; up = 0; yp = 0; a = c.Tf / (c.Tf + Ts); b = c.Kd / (c.Tf + Ts); Kaw = c.Ki / c.Kp;
    for k = 1:n
        e = in.T_s(k) - Td(k);
        dk = a * dk + b * (in.T_s(k) - Tsp); Tsp = in.T_s(k);
        u = c.Kp * e + uI + dk;
        Ta_ref(k) = b0 * u + b1 * up - a1 * yp; up = u; yp = Ta_ref(k);
        uI = uI + Ts * (c.Ki * e + Kaw * (in.T_a_lim(k) - Ta_ref(k)));
    end
    err = max(abs(Ta_sim - Ta_ref));
    fprintf('[%s] %s: T_a %.3f .. %.3f N.m, max |Simulink - reference| = %.3g N.m\n', ctrl, c.name, min(Ta_ref), max(Ta_ref), err);
    assert(err < 1e-8, '%s: T_a differs from the independent reference by %.3g', c.name, err);
    assert(max(abs(in.T_a_lim - Ta_ref)) > 1, 'the anti-windup term must be exercised');
end
integ = find_system(dut, 'BlockType', 'DiscreteIntegrator');
assert(numel(integ) == 1 && strcmp(get_param(integ{1}, 'IntegratorMethod'), 'Integration: Forward Euler'), 'the integrator must be a forward-Euler discrete-time integrator');
close_system(harness, 0); close_system(ctrl, 0);
evalin('base', 'clear tm_T_s tm_v tm_a_y tm_T_a_lim');

%% end-to-end: with PID's gains and no lag the new controller reproduces PID on CALIB
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'PID', 'load_pid.m'), '\', '/')));
if ~exist(fullfile(ctlDir, ['Model_' ctrl '.mdl']), 'file'), build_closed_loop(ctrl); end
[~, m1] = calib_run('Model_PID', 10000, []);
d = struct('Ts_ctrl', Ts, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
[~, m2] = calib_run(['Model_' ctrl], 10000, pidlag_variables(ctrl, d));
Simulink.sdi.clear;
rel = max(abs([m1.R - m2.R, m1.S - m2.S, m1.erel - m2.erel]) ./ abs([m1.R, m1.S, max(m1.erel, 1e-3)]));
fprintf('[%s] end-to-end vs PID (Kp %.3g Ki %.3g Kd %.3g Tf %.3g): R %.6f / %.6f, S %.6f / %.6f, e_rel %.4f / %.4f (relative difference %.2g)\n', ...
    ctrl, q.Kp, q.Ki, q.Kd, q.Tf, m1.R, m2.R, m1.S, m2.S, m1.erel, m2.erel, rel);
assert(rel < 1e-5, 'the new controller must reproduce PID when given its gains');
fprintf('[%s] TEST PASS\n', ctrl);
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
