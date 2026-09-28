function test_smc_ki()
%TEST_SMC Verify SMC.mdl (discrete first-order SMC with sat boundary layer,
%hand-formatted from the build_smc_ki.m output).
%
%   Requires the root subsystem to expose ports named:
%   In: e_T, T_s, theta1, theta2_dot, v | Out: T_a.
%
%   Feeds pseudo-random piecewise-constant inputs (held between samples) and
%   compares T_a at every sample instant with the same discrete algorithm
%   written independently in MATLAB code (Documents/DieuKhien_SMC.txt).
%   Plant parameters (K, J_col, C_col) are read INDEPENDENTLY from
%   data/params.json; controller settings (lambda, tau_f, k_sw, Phi, Ts_ctrl)
%   from the base workspace (run load_smc_ki first) - this test
%   checks the IMPLEMENTATION, not the tuning.

modelFileName = 'SMC_KI';

scriptDir = fileparts(mfilename('fullpath'));   % SMC_KI/script
ctrlDir   = fileparts(scriptDir);               % SMC/
modelDir  = fileparts(ctrlDir);                 % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct('K', raw.cum1.K.value, 'J_col', raw.cum1.J_col.value, ...
    'C_col', raw.cum1.C_col.value);
for nm = {'lambda', 'tau_f', 'k_sw', 'Phi', 'k_I', 'Ts_ctrl'}
    P.(nm{1}) = evalin('base', nm{1});
end
Ts = P.Ts_ctrl;

N = 300;
rng(2);
kk = (0:N-1)';
eT   = 0.8*sin(kk/15) + 0.1*randn(N, 1);
Tsn  = 3 + sin(kk/25) + 0.05*randn(N, 1);
th1  = 0.3 + 0.1*sin(kk/30);
th2d = 0.2*sin(kk/10) + 0.02*randn(N, 1);
vv   = (10 + 100*(0.5 + 0.5*sin(kk/70)))/3.6;   % 10-110 km/h, exercises the table clip
bnd  = jsondecode(fileread(fullfile(modelDir, 'data', 'boundaries.json')));
vBp  = bnd.T_a.v_kmh(:)'/3.6; TaMaxTable = bnd.T_a.value(:)';
tIn = [0; ((1:N-1)' - 0.5)*Ts];
assignin('base', 'test_smc_ki_in', [tIn eT Tsn th1 th2d vv]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_smc_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);
add_block(dut, [harnessName '/DUT']);
dutInHarness = [harnessName '/DUT'];

inNames = {'e_T', 'T_s', 'theta1', 'theta2_dot', 'v'};
add_block('simulink/Sources/From Workspace', [harnessName '/in']);
set_param([harnessName '/in'], 'VariableName', 'test_smc_ki_in', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Signal Routing/Demux', [harnessName '/demux']);
set_param([harnessName '/demux'], 'Outputs', '5');
add_line(harnessName, 'in/1', 'demux/1');
for i = 1:5
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
Ta_ref = zeros(N, 1); xf = 0; z = 0; sat = false(N, 1);
for k = 1:N
    th1dh = (th1(k) - xf)/P.tau_f;
    s0 = th2d(k) - th1dh - (P.lambda/P.K)*eT(k);
    s = s0 + P.k_I*z;
    Teq = -Tsn(k) + P.C_col*th2d(k) + P.J_col*P.lambda*(th1dh - th2d(k));
    usw = P.k_sw*max(-1, min(1, s/P.Phi));
    Tunsat = Teq - P.J_col*usw;
    TaMax = interp1(vBp, TaMaxTable, min(max(vv(k), vBp(1)), vBp(end)), 'linear');
    Ta_ref(k) = max(-TaMax, min(Tunsat, TaMax));
    sat(k) = abs(Tunsat) > TaMax;
    xf = xf + Ts*th1dh;
    z = max(-P.Phi/P.k_I, min(P.Phi/P.k_I, z + Ts*s0));
end

assert(any(sat) && any(~sat), 'the test signal must saturate at some samples and not at others');
n = min(numel(Ta_sim), N);
err = max(abs(Ta_sim(1:n) - Ta_ref(1:n)));
assert(n == N, 'Expected %d samples, got %d', N, n);
assert(err < 1e-9, 'T_a differs from the reference algorithm: max err %.3g', err);
fprintf('[%s] TEST PASS: T_a matches the reference discrete first-order SMC (sat) with T_a,max(v) limit at %d samples (max err %.2g, %d saturated)\n', ...
    modelFileName, N, err, nnz(sat));

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_smc_ki_in');
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
