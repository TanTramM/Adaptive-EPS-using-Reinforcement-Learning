function test_plant_s()
%TEST_PLANT_S Verify the closed-loop Plant_s built from the generated
%   "_s" cluster models (Plant_s.mdl). Self-contained.
%
%   Requires exactly 1 root-level subsystem with ports found BY NAME:
%   In : T_d, T_a, v, mu
%   Out: theta1, theta1_dot, theta2, theta2_dot, T_s, a_y, gamma, beta
%
%   Run load_params.m first (Simulink blocks read the base workspace).
%
%   Excitation: T_d steps to 3 N*m at t=0.1 s, T_a=0, v=20 m/s, mu=0.8.
%   Checks: no NaN, all loops active (signals move), and the independent
%   identity T_s = K*(theta1 - theta2) with K read straight from params.json.

modelFileName = 'Plant_s';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

% Independent reference: read K directly from params.json
params = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
K = params.cum1.K.value;

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
set_param([harnessName '/DUT'], 'Position', [250 100 450 500]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Step', [harnessName '/Td_step']);
set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', '3', 'Before', '0', ...
    'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
set_param([harnessName '/Ta_zero'], 'Value', '0', 'Position', [50 160 80 180]);
add_block('simulink/Sources/Constant', [harnessName '/v_const']);
set_param([harnessName '/v_const'], 'Value', '20', 'Position', [50 210 80 230]);
add_block('simulink/Sources/Constant', [harnessName '/mu_const']);
set_param([harnessName '/mu_const'], 'Value', '0.8', 'Position', [50 260 80 280]);

add_line(harnessName, 'Td_step/1',  portRef(dutInHarness, 'T_d'), 'autorouting', 'on');
add_line(harnessName, 'Ta_zero/1',  portRef(dutInHarness, 'T_a'), 'autorouting', 'on');
add_line(harnessName, 'v_const/1',  portRef(dutInHarness, 'v'),   'autorouting', 'on');
add_line(harnessName, 'mu_const/1', portRef(dutInHarness, 'mu'),  'autorouting', 'on');

outs = {'theta1', 'theta1_dot', 'theta2', 'theta2_dot', 'T_s', 'a_y', 'gamma', 'beta'};
for i = 1:numel(outs)
    blk = [harnessName '/' outs{i} '_out'];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', [outs{i} '_log'], 'SaveFormat', 'Timeseries', ...
        'Position', [600 (100 + 50*i) 670 (120 + 50*i)]);
    add_line(harnessName, portRef(dutInHarness, outs{i}), [outs{i} '_out/1'], ...
        'autorouting', 'on');
end

% MaxStep: tanh(c*x) friction term (c=100) in Cluster 1 distorts logged
% data if the variable-step solver takes large steps after settling.
set_param(harnessName, 'StopTime', '3', 'MaxStep', '0.01');
simOut = sim(harnessName);

logs = struct();
for i = 1:numel(outs)
    ts = simOut.get([outs{i} '_log']);
    logs.(outs{i}) = ts.Data;
    assert(~any(isnan(ts.Data)), '%s contains NaN', outs{i});
end

assert(abs(logs.theta1(end)) > 0, 'theta1 did not move - check the T_d path');
assert(abs(logs.T_s(end))    > 0, 'T_s is zero - check Cluster 1 wiring');
assert(abs(logs.gamma(end))  > 0, 'gamma is zero - check the Tires <-> Bike2DOF loop');
assert(abs(logs.a_y(end))    > 0, 'a_y is zero - check Bike2DOF');

% Independent identity: T_s = K*(theta1 - theta2) at every sample
tsRef = K * (logs.theta1 - logs.theta2);
err = max(abs(logs.T_s - tsRef));
assert(err < 1e-6 * max(1, max(abs(tsRef))), ...
    'T_s deviates from K*(theta1-theta2): max err = %.3g', err);

fprintf(['[%s] TEST PASS: theta1=%.6g rad, theta2=%.6g rad, T_s=%.6g N*m, ' ...
    'beta=%.6g rad, gamma=%.6g rad/s, a_y=%.6g m/s^2 (at t=end)\n'], ...
    modelFileName, logs.theta1(end), logs.theta2(end), logs.T_s(end), ...
    logs.beta(end), logs.gamma(end), logs.a_y(end));

close_system(harnessName, 0);
close_system(modelFileName, 0);
end

%% ===================== Utility functions =====================
function subPath = findRootSubsystem(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
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
