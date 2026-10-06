function test_smc_s()
%TEST_SMC_S Verify SMC_s.mdl (discrete first-order SMC with sat boundary layer, no integral, auto-built by build_smc.m).
%
%   Requires the root subsystem to expose ports named: In: T_s, theta1, theta2_dot, v, a_y | Out: T_a.
%
%   Feeds pseudo-random piecewise-constant inputs (held between samples) and compares T_a (the command) at every sample instant with the
%   same discrete algorithm written independently in MATLAB code (Documents/SMC/DieuKhien_SMC.txt): e_T = T_s - T_d,ref(v, a_y) with
%   T_d,ref = sgn(a_y) * interp2 of the fine reference table read from data/ref.json, the filtered derivative of theta1, the sliding
%   variable, the equivalent control and the boundary-layer switching term. There is NO saturation in the controller (the assist limit
%   T_a,max(v) and the motor are in the Actuator block). Plant parameters (K, J_col, C_col) are read INDEPENDENTLY from data/params.json;
%   controller settings (lambda, tau_f, k_sw, Phi, Ts_ctrl) from the base workspace (run load_smc first) - this test checks the
%   IMPLEMENTATION, not the tuning.

modelFileName = 'SMC_s';

scriptDir = fileparts(mfilename('fullpath'));   % SMC/script
ctrlDir   = fileparts(scriptDir);               % SMC/
modelDir  = fileparts(ctrlDir);                 % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct('K', raw.cum1.K.value, 'J_col', raw.cum1.J_col.value, 'C_col', raw.cum1.C_col.value);
for nm = {'lambda', 'tau_f', 'k_sw', 'Phi', 'Ts_ctrl'}
    P.(nm{1}) = evalin('base', nm{1});
end
Ts = P.Ts_ctrl;
rr = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
vTab = rr.fine.v_breakpoints_kmh(:)' / 3.6;  ayTab = rr.fine.ay_breakpoints_g(:)' * 9.81;  TdTab = rr.fine.table_Nm';

N = 300;
rng(2);
kk = (0:N-1)';
Tsn  = 3 + sin(kk/25) + 0.05*randn(N, 1);
th1  = 0.3 + 0.1*sin(kk/30);
th2d = 0.2*sin(kk/10) + 0.02*randn(N, 1);
vv   = (10 + 100*(0.5 + 0.5*sin(kk/70)))/3.6;   % 10-110 km/h, exercises the table clip
ay   = 3.0*sin(kk/45);                           % both signs, passes through zero
tIn = [0; ((1:N-1)' - 0.5)*Ts];
assignin('base', 'test_smc_in', [tIn Tsn th1 th2d vv ay]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_smc_s_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);
add_block(dut, [harnessName '/DUT']);
dutInHarness = [harnessName '/DUT'];

inNames = {'T_s', 'theta1', 'theta2_dot', 'v', 'a_y'};
add_block('simulink/Sources/From Workspace', [harnessName '/in']);
set_param([harnessName '/in'], 'VariableName', 'test_smc_in', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Signal Routing/Demux', [harnessName '/demux']);
set_param([harnessName '/demux'], 'Outputs', '5');
add_line(harnessName, 'in/1', 'demux/1');
for i = 1:5
    add_line(harnessName, sprintf('demux/%d', i), portRef(dutInHarness, inNames{i}));
end
add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'Ta_log', 'SaveFormat', 'Array', 'SampleTime', 'Ts_ctrl');
add_line(harnessName, portRef(dutInHarness, 'T_a'), 'Ta_out/1');
set_param(harnessName, 'StopTime', sprintf('%.15g', (N-1)*Ts), 'Solver', 'ode1', 'FixedStep', sprintf('%.15g', Ts/2));
simOut = sim(harnessName);
Ta_sim = simOut.get('Ta_log');

% --- independent reference implementation ---
Ta_ref = zeros(N, 1); xf = 0; inLayer = false(N, 1);
for k = 1:N
    Tdref = sign(ay(k)) * interp2(ayTab, vTab, TdTab, min(max(abs(ay(k)), ayTab(1)), ayTab(end)), min(max(vv(k), vTab(1)), vTab(end)), 'linear');
    eT = Tsn(k) - Tdref;
    th1dh = (th1(k) - xf)/P.tau_f;
    s = th2d(k) - th1dh - (P.lambda/P.K)*eT;
    Teq = -Tsn(k) + P.C_col*th2d(k) + P.J_col*P.lambda*(th1dh - th2d(k));
    usw = P.k_sw*max(-1, min(1, s/P.Phi));
    Ta_ref(k) = Teq - P.J_col*usw;
    inLayer(k) = abs(s) < P.Phi;
    xf = xf + Ts*th1dh;
end

assert(any(inLayer) && any(~inLayer), 'the test signal must be inside the boundary layer at some samples and outside at others');
n = min(numel(Ta_sim), N);
err = max(abs(Ta_sim(1:n) - Ta_ref(1:n)));
assert(n == N, 'Expected %d samples, got %d', N, n);
assert(err < 1e-9, 'T_a differs from the reference algorithm: max err %.3g', err);
fprintf('[%s] TEST PASS: T_a matches the reference discrete first-order SMC (sat, no integral, e_T inside) at %d samples (max err %.2g, %d inside the boundary layer)\n', ...
    modelFileName, N, err, nnz(inLayer));

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_smc_in');
end

%% ===================== Utility functions =====================
function subPath = findRootSubsystem(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - ports are found BY NAME, never by assumed order.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    for type = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', type{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
