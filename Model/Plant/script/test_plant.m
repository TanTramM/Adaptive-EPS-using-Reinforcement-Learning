function test_plant(modelFileName)
%TEST_PLANT Kiem chung Plant (he khep vong 4 trang thai).
%   test_plant() - test ban vua build (Plant_s.mdl, mac dinh).
%   test_plant('Plant') - test ban da tu format tay.
%
%   Chi doi hoi model co DUNG 1 subsystem cap goc voi cac cong TEN:
%   In: T_d, T_a, v, mu | Out: theta, theta_dot, beta, gamma, a_y.
%
%   Cap T_d buoc nhay, T_a=0, v/mu hang so, mo phong vai giay, kiem tra
%   khong NaN va cac vong hoi tiep hoat dong (tin hieu khac 0).

if nargin < 1
    modelFileName = 'Plant_s';
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = subsystemDuyNhat(modelFileName);

harnessName = 'test_plant_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 400]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Step', [harnessName '/Td_step']);
set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', '3', 'Before', '0', 'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
set_param([harnessName '/Ta_zero'], 'Value', '0', 'Position', [50 160 80 180]);
add_block('simulink/Sources/Constant', [harnessName '/v_const']);
set_param([harnessName '/v_const'], 'Value', '20', 'Position', [50 210 80 230]);
add_block('simulink/Sources/Constant', [harnessName '/mu_const']);
set_param([harnessName '/mu_const'], 'Value', '0.8', 'Position', [50 260 80 280]);

outs = {'theta', 'theta_dot', 'beta', 'gamma', 'a_y'};
for i = 1:numel(outs)
    blk = [harnessName '/' outs{i} '_out'];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', [outs{i} '_log'], 'Position', [550 (100+60*i) 620 (120+60*i)]);
    add_line(harnessName, portRef(dutInHarness, outs{i}), [outs{i} '_out/1'], 'autorouting', 'on');
end

add_line(harnessName, 'Td_step/1', portRef(dutInHarness, 'T_d'), 'autorouting', 'on');
add_line(harnessName, 'Ta_zero/1', portRef(dutInHarness, 'T_a'), 'autorouting', 'on');
add_line(harnessName, 'v_const/1', portRef(dutInHarness, 'v'), 'autorouting', 'on');
add_line(harnessName, 'mu_const/1',portRef(dutInHarness, 'mu'), 'autorouting', 'on');

set_param(harnessName, 'StopTime', '3');
simOut = sim(harnessName);

theta_log     = simOut.get('theta_log');
theta_dot_log = simOut.get('theta_dot_log');
beta_log      = simOut.get('beta_log');
gamma_log     = simOut.get('gamma_log');
ay_log        = simOut.get('a_y_log');

assert(~any(isnan(theta_log.Data)),     'theta co NaN');
assert(~any(isnan(theta_dot_log.Data)), 'theta_dot co NaN');
assert(~any(isnan(beta_log.Data)),      'beta co NaN');
assert(~any(isnan(gamma_log.Data)),     'gamma co NaN');
assert(~any(isnan(ay_log.Data)),        'a_y co NaN');
assert(theta_log.Data(end) ~= 0, 'theta khong doi - kiem tra lai duong day T_d');
assert(gamma_log.Data(end) ~= 0, 'gamma khong doi - kiem tra lai vong lap Tires<->Bike2DOF');

fprintf('[%s] TEST PASS: theta(end)=%.6g rad, theta_dot(end)=%.6g rad/s, beta(end)=%.6g rad, gamma(end)=%.6g rad/s, a_y(end)=%.6g m/s^2\n', ...
    modelFileName, theta_log.Data(end), theta_dot_log.Data(end), beta_log.Data(end), gamma_log.Data(end), ay_log.Data(end));

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
