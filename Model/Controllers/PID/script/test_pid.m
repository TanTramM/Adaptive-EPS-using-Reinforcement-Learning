function test_pid()
%TEST_PID Verify PID.mdl (PI with back-calculation anti-windup + filtered derivative of the measured T_s, built by build_pid.m).
%
%   Requires the root subsystem to expose ports named: In: T_s, v, a_y, T_a_lim | Out: T_a. Run Model/Controllers/PID/load_pid.m first.
%   OPEN-LOOP test (no plant): synthetic T_s, v, a_y and an independent T_a_lim signal (different from T_a, so the anti-windup term is active
%   all the time) on the 1 ms grid; the expected T_a is computed here from data/ref.json with the recursion
%       e[k] = T_s[k] - T_d,ref(v[k], a_y[k]),  T_a[k] = Kp e[k] + u_I[k] + d[k],  d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]),  a = Tf/(Tf+Ts), b = Kd/(Tf+Ts),  u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k]))
%   with sgn(a_y) * interp2 of the fine table (not the base-workspace variables), and compared sample by sample with the block in Simulink
%   (fixed step 1 ms).

modelFileName = 'PID';
scriptDir = fileparts(mfilename('fullpath'));   % PID/script
ctlDir    = fileparts(scriptDir);               % PID/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
loadPiPath = fullfile(ctlDir, 'load_pid.m');
evalin('base', sprintf('run(''%s'');', strrep(loadPiPath, '\', '/')));
Ts = evalin('base', 'Ts_ctrl');
Kp = 0.7; Ki = 12; Kd = 0.02; Tf = 0.008; Kaw = sqrt(Ki / Kd);   % book design: Kaw = 1/Tt, Tt = sqrt(Ti Td) = sqrt(Kd/Ki)
satL = 1.2;                                                             % saturation level of the harness limiter [N.m]
assignin('base', 'PID_Kp', Kp); assignin('base', 'PID_Ki', Ki); assignin('base', 'PID_Kaw', Kaw);
assignin('base', 'PID_Kd', Kd); assignin('base', 'PID_Tf', Tf);

%% synthetic inputs on the 1 ms grid
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.2 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v   = (16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t));                      % m/s: 16-27, crosses table breakpoints
a_y = 3.0 * sin(2*pi*0.4*t);                                           % m/s^2, both signs, crosses 0
T_a_lim = zeros(n, 1);                                                       % placeholder: the harness feeds back the SATURATED, delayed T_a (below)

%% the block in Simulink
harnessName = 'test_pid_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(ctlDir, [modelFileName '.mdl']));
subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'PID must have exactly 1 root subsystem');
new_system(harnessName);
add_block(subs{1}, [harnessName '/DUT']);
dut = [harnessName '/DUT'];
sigs = {T_s, v, a_y};
names = {'T_s', 'v', 'a_y'};
for i = 1:numel(names)
    assignin('base', ['tp_' names{i}], [t sigs{i}]);
    b = [harnessName '/FW_' names{i}];
    add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tp_' names{i}], 'Interpolate', 'off', ...
        'OutputAfterFinalValue', 'Holding final value');
    add_line(harnessName, ['FW_' names{i} '/1'], portRef(dut, names{i}));
end
add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'tp_Ta_log', 'SaveFormat', 'Timeseries');
add_line(harnessName, portRef(dut, 'T_a'), 'Ta_out/1');
% limiter feedback: T_a_lim[k] = sat(T_a[k-1]) (one-sample delay, saturation at +-satL), so the block really saturates and the back-calculation term acts as in the closed loop
add_block('simulink/Discrete/Unit Delay', [harnessName '/UD'], 'SampleTime', num2str(Ts), 'InitialCondition', '0');
add_block('simulink/Discontinuities/Saturation', [harnessName '/SAT'], 'UpperLimit', num2str(satL), 'LowerLimit', num2str(-satL));
add_line(harnessName, portRef(dut, 'T_a'), 'UD/1');
add_line(harnessName, 'UD/1', 'SAT/1');
add_line(harnessName, 'SAT/1', portRef(dut, 'T_a_lim'));
add_block('simulink/Sinks/To Workspace', [harnessName '/LG_lim'], 'VariableName', 'tp_in_T_a_lim', 'SaveFormat', 'Timeseries');
add_line(harnessName, 'SAT/1', 'LG_lim/1');
set_param(harnessName, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));
for i = 1:numel(names)       % log what the block really receives
    b = [harnessName '/LG_' names{i}];
    add_block('simulink/Sinks/To Workspace', b, 'VariableName', ['tp_in_' names{i}], 'SaveFormat', 'Timeseries');
    add_line(harnessName, ['FW_' names{i} '/1'], ['LG_' names{i} '/1']);
end
so = sim(harnessName);
ts = so.get('tp_Ta_log');
tg = ts.Time(:); n = numel(tg);
in = struct();
for i = 1:numel(names)
    q = so.get(['tp_in_' names{i}]);
    in.(names{i}) = squeeze(q.Data); in.(names{i}) = in.(names{i})(:);
    assert(numel(in.(names{i})) == n, 'logged input %s has a different length', names{i});
end
q = so.get('tp_in_T_a_lim'); T_a_lim = squeeze(q.Data); T_a_lim = T_a_lim(:);
T_s = in.T_s; v = in.v; a_y = in.a_y;

%% expected output from the logged inputs, independent of gates and of the block
rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp = rawRef.fine.v_breakpoints_kmh(:)' / 3.6;
ay_bp = rawRef.fine.ay_breakpoints_g(:)' * 9.81;
tab = rawRef.fine.table_Nm';
Td = sign(a_y) .* interp2(ay_bp, v_bp, tab, min(abs(a_y), ay_bp(end)), min(max(v, v_bp(1)), v_bp(end)), 'linear');
Ta_ref = zeros(n, 1); uI = 0; dk = 0; Tsp = 0; a = Tf / (Tf + Ts); b = Kd / (Tf + Ts);
for k = 1:n
    e = T_s(k) - Td(k);
    dk = a * dk + b * (T_s(k) - Tsp); Tsp = T_s(k);
    Ta_ref(k) = Kp * e + uI + dk;
    uI = uI + Ts * (Ki * e + Kaw * (T_a_lim(k) - Ta_ref(k)));
end
lim_expect = [0; min(max(Ta_ref(1:end-1), -satL), satL)];
assert(max(abs(T_a_lim - lim_expect)) < 1e-9, 'limiter feedback differs from sat(delayed T_a)');
assert(nnz(abs(Ta_ref) > satL) > 100, 'the limit is not touched: choose a smaller satL');
fprintf('[%s] limit touched in %d of %d samples\n', modelFileName, nnz(abs(Ta_ref) > satL), n);
fprintf('[%s] expected T_a: %.3f .. %.3f N.m, T_a_lim - T_a up to %.3f N.m (anti-windup term exercised)\n', modelFileName, min(Ta_ref), max(Ta_ref), max(abs(T_a_lim - Ta_ref)));
Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:);
err = max(abs(Ta_sim - Ta_ref));
fprintf('[%s] max |T_a(Simulink) - T_a(reference)| over %d samples = %.3g N.m\n', modelFileName, n, err);
assert(err < 1e-9, 'T_a differs from the independent reference by %.3g', err);

% structure: integrator is discrete forward Euler at Ts_ctrl; no continuous states in the block
integ = find_system(dut, 'BlockType', 'DiscreteIntegrator');
assert(numel(integ) == 1 && strcmp(get_param(integ{1}, 'IntegratorMethod'), 'Integration: Forward Euler'), 'the integrator must be a forward-Euler discrete-time integrator');
fprintf('[%s] TEST PASS: PID (back-calculation anti-windup, filtered derivative of T_s) matches the independent recursion (max error %.3g)\n', modelFileName, err);
close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear tp_T_s tp_v tp_a_y tp_in_T_a_lim');
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - wiring by NAME.
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
