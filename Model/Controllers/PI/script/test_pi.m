function test_pi()
%TEST_PI Verify PI.mdl (PI with back-calculation anti-windup and its own e_T from the Reference block, built by build_pi.m).
%
%   Requires the root subsystem to expose ports named: In: T_s, v, a_y, T_a_lim | Out: T_a. Run Model/Controllers/PI/load_pi.m first.
%   OPEN-LOOP test (no plant): synthetic T_s, v, a_y and an independent T_a_lim signal (different from T_a, so the anti-windup term is active
%   all the time) on the 1 ms grid; the expected T_a is computed here from data/ref.json with the recursion
%       e[k] = T_s[k] - T_d,ref(v[k], a_y[k]),  T_a[k] = Kp e[k] + u_I[k],  u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k]))
%   with sgn(a_y) * interp2 of the fine table (not the base-workspace variables), and compared sample by sample with the block in Simulink
%   (fixed step 1 ms).

modelFileName = 'PI';
scriptDir = fileparts(mfilename('fullpath'));   % PI/script
ctlDir    = fileparts(scriptDir);               % PI/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
loadPiPath = fullfile(ctlDir, 'load_pi.m');
evalin('base', sprintf('run(''%s'');', strrep(loadPiPath, '\', '/')));
Ts = evalin('base', 'Ts_ctrl');
Kp = 0.7; Ki = 12; Kaw = Ki / Kp;
assignin('base', 'PI_Kp', Kp); assignin('base', 'PI_Ki', Ki); assignin('base', 'PI_Kaw', Kaw);

%% synthetic inputs on the 1 ms grid
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.2 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v   = (16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t));                      % m/s: 16-27, crosses table breakpoints
a_y = 3.0 * sin(2*pi*0.4*t);                                           % m/s^2, both signs, crosses 0
T_a_lim = 3.0 * sin(2*pi*0.2*t + 0.5) + 0.4;                           % independent of T_a: the anti-windup term is active

%% the block in Simulink
harnessName = 'test_pi_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(ctlDir, [modelFileName '.mdl']));
subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'PI must have exactly 1 root subsystem');
new_system(harnessName);
add_block(subs{1}, [harnessName '/DUT']);
dut = [harnessName '/DUT'];
sigs = {T_s, v, a_y, T_a_lim};
names = {'T_s', 'v', 'a_y', 'T_a_lim'};
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
T_s = in.T_s; v = in.v; a_y = in.a_y; T_a_lim = in.T_a_lim;

%% expected output from the logged inputs, independent of gates and of the block
rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp = rawRef.fine.v_breakpoints_kmh(:)' / 3.6;
ay_bp = rawRef.fine.ay_breakpoints_g(:)' * 9.81;
tab = rawRef.fine.table_Nm';
Td = sign(a_y) .* interp2(ay_bp, v_bp, tab, min(abs(a_y), ay_bp(end)), min(max(v, v_bp(1)), v_bp(end)), 'linear');
Ta_ref = zeros(n, 1); uI = 0;
for k = 1:n
    e = T_s(k) - Td(k);
    Ta_ref(k) = Kp * e + uI;
    uI = uI + Ts * (Ki * e + Kaw * (T_a_lim(k) - Ta_ref(k)));
end
fprintf('[%s] expected T_a: %.3f .. %.3f N.m, T_a_lim - T_a up to %.3f N.m (anti-windup term exercised)\n', modelFileName, min(Ta_ref), max(Ta_ref), max(abs(T_a_lim - Ta_ref)));
Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:);
err = max(abs(Ta_sim - Ta_ref));
fprintf('[%s] max |T_a(Simulink) - T_a(reference)| over %d samples = %.3g N.m\n', modelFileName, n, err);
assert(err < 1e-9, 'T_a differs from the independent reference by %.3g', err);

% structure: integrator is discrete forward Euler at Ts_ctrl; no continuous states in the block
integ = find_system(dut, 'BlockType', 'DiscreteIntegrator');
assert(numel(integ) == 1 && strcmp(get_param(integ{1}, 'IntegratorMethod'), 'Integration: Forward Euler'), 'the integrator must be a forward-Euler discrete-time integrator');
fprintf('[%s] TEST PASS: PI with back-calculation anti-windup and own T_d,ref matches the independent recursion (max error %.3g)\n', modelFileName, err);
close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear tp_T_s tp_v tp_a_y tp_T_a_lim');
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
