function test_pid()
%TEST_PID Verify PID.mdl (discrete PID with assist limit T_a,max(v) and back-calculation
%anti-windup, hand-formatted from the build_pid.m output).
%
%   Requires the root subsystem to expose ports named:
%   In: e_T, v | Out: T_a.
%
%   Feeds pseudo-random piecewise-constant e_T and v (held between samples)
%   and compares T_a at every sample instant with the same discrete
%   algorithm written independently in MATLAB code (Documents/DieuKhien_PID.txt):
%     u_P = Kp*e ; w = (e - x)/T_filt ; u_D = Kd*w ; x[k+1] = x[k] + Ts*w ;
%     T_unsat = u_P + u_I + u_D ; T_max = T_a,max(v) (clipped table) ;
%     T_a = max(-T_max, min(T_unsat, T_max)) ;
%     u_I[k+1] = u_I[k] + Ts*(Ki*e + Kaw*(T_a - T_unsat)).
%   The error amplitude is large enough that the command saturates at part of
%   the samples (checked), and v goes below 20 km/h and above 100 km/h to
%   exercise the clipping of the table. Gains and Kaw are read from the base
%   workspace (run load_pid first); the T_a,max table is read INDEPENDENTLY
%   from data/boundaries.json - this test checks the IMPLEMENTATION, not the
%   tuning.

modelFileName = 'PID';

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
ctrlDir   = fileparts(scriptDir);               % PID/
modelDir  = fileparts(ctrlDir);                 % Model/

G = struct();
for nm = {'Kp', 'Ki', 'Kd', 'T_filt', 'Kaw', 'Ts_ctrl'}
    G.(nm{1}) = evalin('base', nm{1});
end
Ts = G.Ts_ctrl;

bnd = jsondecode(fileread(fullfile(modelDir, 'data', 'boundaries.json')));
vBp = bnd.T_a.v_kmh(:)'/3.6;
TaMaxTable = bnd.T_a.value(:)';

N = 400;
rng(1);
kk = (0:N-1)';
e = 6*sin(kk/20) + 0.5*randn(N, 1);                      % large enough to saturate
v = (10 + 100*(0.5 + 0.5*sin(kk/70)))/3.6;               % 10-110 km/h
tIn = [0; ((1:N-1)' - 0.5)*Ts];     % value k holds from (k-0.5)*Ts
assignin('base', 'test_pid_in', [tIn e v]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_pid_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);
add_block(dut, [harnessName '/DUT']);
dutInHarness = [harnessName '/DUT'];

inNames = {'e_T', 'v'};
add_block('simulink/Sources/From Workspace', [harnessName '/in']);
set_param([harnessName '/in'], 'VariableName', 'test_pid_in', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Signal Routing/Demux', [harnessName '/demux']);
set_param([harnessName '/demux'], 'Outputs', '2');
add_line(harnessName, 'in/1', 'demux/1');
for i = 1:2
    add_line(harnessName, sprintf('demux/%d', i), portRef(dutInHarness, inNames{i}));
end
add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'Ta_log', 'SaveFormat', 'Array', ...
    'SampleTime', 'Ts_ctrl');
add_line(harnessName, portRef(dutInHarness, 'T_a'), 'Ta_out/1');
set_param(harnessName, 'StopTime', sprintf('%.15g', (N-1)*Ts), 'Solver', 'ode1', ...
    'FixedStep', sprintf('%.15g', Ts/2));
simOut = sim(harnessName);
Ta_sim = simOut.get('Ta_log');

% --- independent reference implementation ---
Ta_ref = zeros(N, 1); TaMax = zeros(N, 1); uI = 0; x = 0;
for k = 1:N
    TaMax(k) = interp1(vBp, TaMaxTable, min(max(v(k), vBp(1)), vBp(end)), 'linear');
    w = (e(k) - x)/G.T_filt;
    Tunsat = G.Kp*e(k) + uI + G.Kd*w;
    Ta_ref(k) = max(-TaMax(k), min(Tunsat, TaMax(k)));
    uI = uI + Ts*(G.Ki*e(k) + G.Kaw*(Ta_ref(k) - Tunsat));
    x  = x + Ts*w;
end
saturated = abs(Ta_ref) >= TaMax - 1e-12;
assert(any(saturated) && any(~saturated), 'the test signal must saturate at some samples and not at others');

n = min(numel(Ta_sim), N);
err = max(abs(Ta_sim(1:n) - Ta_ref(1:n)));
assert(n == N, 'Expected %d samples, got %d', N, n);
assert(err < 1e-9, 'T_a differs from the reference algorithm: max err %.3g', err);
fprintf('[%s] TEST PASS: T_a matches the reference discrete PID with T_a,max(v) saturation and anti-windup at %d samples (max err %.2g, %d saturated samples)\n', ...
    modelFileName, N, err, nnz(saturated));

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_pid_in');
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
