function test_ismc()
%TEST_ISMC Verify ISMC.mdl (non-integral ISMC-sat built by build_ismc.m).
%
%   Requires the root subsystem to expose ports named:
%     In : T_s, v, a_y, T_a_lim, T_a_max
%     Out: T_a
%   OPEN-LOOP test (no plant): synthetic inputs on 1 ms grid.
%   Expected output is calculated independently from data/ref.json and the equations:
%       e_T[k] = T_s[k] - T_d,ref(v[k], a_y[k])
%       Ts_dot_hat[k] = (T_s[k] - w[k]) / Tf
%       w[k+1] = w[k] + Ts * Ts_dot_hat[k]      (Forward Euler)
%       s[k] = Ts_dot_hat[k] + 2 * lambda * e_T[k] + lambda^2 * z[k]
%       T_a[k] = T_a_max[k] * sat(s[k] / Phi)
%       z[k+1] = z[k] + Ts * (e_T[k] * (|s[k] / Phi| <= 1.0)) (Slotine anti-windup)
%   and compared sample-by-sample with the Simulink block (fixed step 1 ms).

modelFileName = 'ISMC';
scriptDir = fileparts(mfilename('fullpath'));   % ISMC/script
ctlDir    = fileparts(scriptDir);               % ISMC/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
loadSmcPath = fullfile(ctlDir, 'load_ismc.m');
evalin('base', sprintf('run(''%s'');', strrep(loadSmcPath, '\', '/')));
Ts = evalin('base', 'Ts_ctrl');

lambda = 35.0; Phi = 2.5; Tf = 0.005;
assignin('base', 'ISMC_lambda', lambda);
assignin('base', 'ISMC_Phi',    Phi);
assignin('base', 'ISMC_Tf',     Tf);

%% Synthetic inputs on the 1 ms grid
t = (0:Ts:6)'; n = numel(t);
T_s     = 1.5 + 1.2 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v       = (16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t));                      % m/s: 16-27
a_y     = 3.0 * sin(2*pi*0.4*t);                                           % m/s^2, both signs
T_a_lim = 3.0 * sin(2*pi*0.2*t + 0.5) + 0.4;
T_a_max = 7.0 + 1.5 * sin(2*pi*0.15*t);                                   % N.m

%% The block in Simulink
harnessName = 'test_ismc_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(ctlDir, [modelFileName '.mdl']));
subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'ISMC must have exactly 1 root subsystem');

new_system(harnessName);
add_block(subs{1}, [harnessName '/DUT']);
dut = [harnessName '/DUT'];

sigs  = {T_s, v, a_y, T_a_lim, T_a_max};
names = {'T_s', 'v', 'a_y', 'T_a_lim', 'T_a_max'};
for i = 1:numel(names)
    assignin('base', ['tp_' names{i}], [t sigs{i}]);
    b = [harnessName '/FW_' names{i}];
    add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tp_' names{i}], ...
        'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_line(harnessName, ['FW_' names{i} '/1'], portRef(dut, names{i}));
end

add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'tp_Ta_log', 'SaveFormat', 'Timeseries');
add_line(harnessName, portRef(dut, 'T_a'), 'Ta_out/1');
set_param(harnessName, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));

for i = 1:numel(names)
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
T_s = in.T_s; v = in.v; a_y = in.a_y; T_a_max = in.T_a_max;

%% Expected output from the logged inputs, independent of Simulink
rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp = rawRef.fine.v_breakpoints_kmh(:)' / 3.6;
ay_bp = rawRef.fine.ay_breakpoints_g(:)' * 9.81;
tab = rawRef.fine.table_Nm';
Td = sign(a_y) .* interp2(ay_bp, v_bp, tab, min(abs(a_y), ay_bp(end)), min(max(v, v_bp(1)), v_bp(end)), 'linear');

Ta_ref = zeros(n, 1);
w = 0;
z = 0;
for k = 1:n
    e_T = T_s(k) - Td(k);
    Ts_dot_hat = (T_s(k) - w) / Tf;
    w = w + Ts * Ts_dot_hat;
    s = Ts_dot_hat + 2 * lambda * e_T + (lambda^2) * z;
    sat_val = min(1, max(-1, s / Phi));
    Ta_ref(k) = T_a_max(k) * sat_val;
    if abs(s / Phi) <= 1
        z = z + Ts * e_T;
    end
end

Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:);
err = max(abs(Ta_sim - Ta_ref));
fprintf('[%s] expected T_a range: [%.3f, %.3f] N.m\n', modelFileName, min(Ta_ref), max(Ta_ref));
fprintf('[%s] max |T_a(Simulink) - T_a(reference)| over %d samples = %.3g N.m\n', modelFileName, n, err);
assert(err < 1e-9, 'T_a differs from independent reference by %.3g', err);

% Verify discrete structure: no continuous states in the block, exactly 2 forward Euler integrators
integ = find_system(dut, 'BlockType', 'DiscreteIntegrator');
assert(numel(integ) == 2, 'Must have exactly 2 discrete-time integrators (w and z)');
for ii = 1:numel(integ)
    assert(strcmp(get_param(integ{ii}, 'IntegratorMethod'), 'Integration: Forward Euler'), ...
        'Integrator %s must be forward-Euler discrete-time integrator', integ{ii});
end

fprintf('[%s] TEST PASS: ISMC matches the independent recursion (max error %.3g)\n', modelFileName, err);

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear tp_T_s tp_v tp_a_y tp_T_a_lim tp_T_a_max');
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                portNum = get_param(ports{k}, 'Port');
                ref = [parts{end} '/' portNum];
                return;
            end
        end
    end
    error('Port %s not found in %s', portName, subPath);
end

