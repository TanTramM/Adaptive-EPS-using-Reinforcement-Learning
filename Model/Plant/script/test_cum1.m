function test_cum1()
%TEST_CUM1 Verify SteeringColumn.mdl (Cluster 1, hand-formatted from the
%build_cum1.m output - torsion spring, two inertias, steering ANGLE theta1 as input).
%
%   Requires the root subsystem to expose ports named:
%   In : theta1, T_a, T_r | Out: T_s, theta2, theta2_dot.
%
%   Two cases, each compared with an analytic reference computed here
%   from params.json (NOT from the base workspace, so it also catches
%   errors in load_plant/load_derived):
%
%   A) theta1 held constant, T_a and T_r constant. Nothing rotates
%      (x4=0, tanh(0)=0), so Eq.(2) gives T_s = T_r - T_a, then
%      theta2 = theta1 - T_s/K.
%   B) theta1 = w*t (ramp). theta2 follows at the same rate (x4 = w), so
%      T_s = T_r - T_a + T_f*tanh(c*w) + C_col*w and theta2_dot = w.

modelFileName = 'SteeringColumn';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
K  = raw.cum1.K.value;   C_col = raw.cum1.C_col.value;
T_f = raw.cum1.T_f.value; c = raw.cum1.c.value;

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = findRootSubsystem(modelFileName);

harnessName = 'test_cum1_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [300 100 500 300]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Ramp', [harnessName '/th1_ramp']);
add_block('simulink/Sources/Constant', [harnessName '/Ta_src']);
add_block('simulink/Sources/Constant', [harnessName '/Tr_src']);
add_line(harnessName, 'th1_ramp/1', portRef(dutInHarness, 'theta1'));
add_line(harnessName, 'Ta_src/1',   portRef(dutInHarness, 'T_a'));
add_line(harnessName, 'Tr_src/1',   portRef(dutInHarness, 'T_r'));

outs = {'T_s', 'theta2', 'theta2_dot'};
for i = 1:numel(outs)
    blk = [harnessName '/' outs{i} '_out'];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', [outs{i} '_log'], 'SaveFormat', 'Timeseries');
    add_line(harnessName, portRef(dutInHarness, outs{i}), [outs{i} '_out/1']);
end

% MaxStep is REQUIRED: the steep tanh(c*x4) term (c=100) distorts logged
% data if the variable-step solver takes large steps after settling.
set_param(harnessName, 'MaxStep', '0.005');

%% ----- Case A: constant angle -----
th1 = 0.1; Ta = 0.5; Tr = 2;
simOut = runCase(harnessName, 0, th1, Ta, Tr, 15);
TsA_ref = Tr - Ta;
[Ts, th2, ~] = lastValues(simOut);
checkClose('A: T_s',    Ts,  TsA_ref,         1e-3);
checkClose('A: theta2', th2, th1 - TsA_ref/K, 1e-5);

%% ----- Case B: ramp -----
w = 0.1; Ta = 0.5; Tr = 2;
simOut = runCase(harnessName, w, 0, Ta, Tr, 10);
TsB_ref = Tr - Ta + T_f*tanh(c*w) + C_col*w;
[Ts, ~, th2dot] = lastValues(simOut);
checkClose('B: T_s',        Ts,     TsB_ref, 1e-3);
checkClose('B: theta2_dot', th2dot, w,       1e-4);

fprintf('[%s] TEST PASS: A) T_s=%.5g theta2=%.6g | B) T_s=%.5g theta2_dot=%.5g\n', ...
    modelFileName, TsA_ref, th1 - TsA_ref/K, TsB_ref, w);

close_system(harnessName, 0);
close_system(modelFileName, 0);
end

%% ===================== Utility functions =====================
function simOut = runCase(h, slope, x0, Ta, Tr, stopTime)
    set_param([h '/th1_ramp'], 'Slope', sprintf('%.15g', slope), ...
        'X0', sprintf('%.15g', x0), 'start', '0');
    set_param([h '/Ta_src'], 'Value', sprintf('%.15g', Ta));
    set_param([h '/Tr_src'], 'Value', sprintf('%.15g', Tr));
    set_param(h, 'StopTime', sprintf('%.15g', stopTime));
    simOut = sim(h);
end

function [Ts, th2, th2dot] = lastValues(simOut)
    a = simOut.get('T_s_log');        Ts     = a.Data(end);
    assert(~any(isnan(a.Data)), 'T_s contains NaN');
    a = simOut.get('theta2_log');     th2    = a.Data(end);
    a = simOut.get('theta2_dot_log'); th2dot = a.Data(end);
end

function checkClose(label, actual, ref, tol)
    assert(abs(actual - ref) < tol, '%s: model=%.6g, analytic=%.6g', label, actual, ref);
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
