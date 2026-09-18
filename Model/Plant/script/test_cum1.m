function test_cum1(modelFileName)
%TEST_CUM1 Kiem chung khoi SteeringColumn (Cum 1).
%   test_cum1() - test ban vua build (SteeringColumn_s.mdl, mac dinh).
%   test_cum1('SteeringColumn') - test ban da tu format tay.
%
%   Chi doi hoi model co DUNG 1 subsystem cap goc voi cac cong TEN:
%   In: T_d, T_a, T_r | Out: theta, theta_dot - khong quan tam thu tu cong
%   hay ten subsystem ben trong, nen test duoc CA BAN "_s" LAN BAN DA
%   FORMAT TAY, mien la dung ten cong.
%
%   Cap T_d buoc nhay, T_a=0, T_r=0, mo phong 5s, kiem tra khong NaN va
%   theta_dot bao hoa dung gia tri giai tich: B_total*x2+T_f_total*tanh(c*x2)=T_d.

if nargin < 1
    modelFileName = 'SteeringColumn_s';
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = subsystemDuyNhat(modelFileName);

harnessName = 'test_cum1_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [200 100 400 250]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Step', [harnessName '/Td_step']);
set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', '3', 'Before', '0', ...
    'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
set_param([harnessName '/Ta_zero'], 'Value', '0', 'Position', [50 160 80 180]);
add_block('simulink/Sources/Constant', [harnessName '/Tr_zero']);
set_param([harnessName '/Tr_zero'], 'Value', '0', 'Position', [50 210 80 230]);

add_block('simulink/Sinks/To Workspace', [harnessName '/theta_out']);
set_param([harnessName '/theta_out'], 'VariableName', 'theta_log', 'Position', [450 110 520 130]);
add_block('simulink/Sinks/To Workspace', [harnessName '/theta_dot_out']);
set_param([harnessName '/theta_dot_out'], 'VariableName', 'theta_dot_log', 'Position', [450 180 520 200]);

add_line(harnessName, 'Td_step/1', portRef(dutInHarness, 'T_d'), 'autorouting', 'on');
add_line(harnessName, 'Ta_zero/1', portRef(dutInHarness, 'T_a'), 'autorouting', 'on');
add_line(harnessName, 'Tr_zero/1', portRef(dutInHarness, 'T_r'), 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta'), 'theta_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta_dot'), 'theta_dot_out/1', 'autorouting', 'on');

set_param(harnessName, 'StopTime', '5');
simOut = sim(harnessName);

theta_log = simOut.get('theta_log');
theta_dot_log = simOut.get('theta_dot_log');

assert(~any(isnan(theta_log.Data)), 'theta co NaN');
assert(~any(isnan(theta_dot_log.Data)), 'theta_dot co NaN');
assert(theta_log.Data(end) > 0, 'theta cuoi ky vong > 0 (Td buoc nhay duong)');

B_total = evalin('base', 'B_total');
T_f_total = evalin('base', 'T_f_total');
Td_final = 3;
theta_dot_ref = fzero(@(w) B_total*w + T_f_total*tanh(evalin('base','c')*w) - Td_final, 0.5);
assert(abs(theta_dot_log.Data(end) - theta_dot_ref) < 1e-3, ...
    'theta_dot xac lap khong khop giai tich (model=%.6g, giai_tich=%.6g)', ...
    theta_dot_log.Data(end), theta_dot_ref);

fprintf('[%s] TEST PASS: theta(end)=%.6g rad, theta_dot(end)=%.6g rad/s (giai_tich=%.6g)\n', ...
    modelFileName, theta_log.Data(end), theta_dot_log.Data(end), theta_dot_ref);

close_system(harnessName, 0);
close_system(modelFileName, 0);
end

%% ===================== Ham tien ich =====================
function subPath = subsystemDuyNhat(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s phai co dung 1 subsystem cap goc, tim thay %d', ...
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
    error('Khong tim thay cong ten "%s" trong %s', portName, subPath);
end
