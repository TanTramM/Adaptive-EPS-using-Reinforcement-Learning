function test_cum1(modelFileName)
%TEST_CUM1 Kiem chung khoi SteeringColumn (Cum 1, CO THANH XOAN, 2 khoi
%quan tinh J1-K-J2).
%   test_cum1() - test ban vua build (SteeringColumn_s.mdl, mac dinh).
%   test_cum1('SteeringColumn') - test ban da tu format tay.
%
%   Chi doi hoi model co DUNG 1 subsystem cap goc voi cac cong TEN:
%   In: T_d, T_a, T_r | Out: theta1, theta1_dot, theta2, theta2_dot, T_s -
%   khong quan tam thu tu cong hay ten subsystem ben trong.
%
%   Cap T_d buoc nhay, T_a=0, T_r=0, mo phong du lau. VOI T_a=T_r=0, he
%   KHONG dung o 1 GOC co dinh (khong co gi can ca 2 khoi dung lai) - thay
%   vao do ca 2 khoi tien toi cung 1 VAN TOC GOC XAC LAP omega (quay deu
%   cung nhau, do lech goc theta1-theta2 tien toi hang so). Dieu kien xac
%   lap (dat x2=x4=omega, cac dao ham=0 vao PT (1),(2) trong
%   Documents/Cum1_CEPS.txt va cong don khu K*(x1-x3)):
%
%     (C1+C2)*omega + T_f*tanh(c*omega) = T_d          (giong dung dang PT
%                                                        cua ban truc cung
%                                                        cu, B_total=C1+C2)
%     T_s_xaclap = T_d - C1*omega   (= C2*omega + T_f*tanh(c*omega), 2 cach
%                                     tinh phai khop nhau - tu kiem chung)

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
set_param([harnessName '/DUT'], 'Position', [200 100 400 300]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Step', [harnessName '/Td_step']);
set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', '3', 'Before', '0', ...
    'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
set_param([harnessName '/Ta_zero'], 'Value', '0', 'Position', [50 200 80 220]);
add_block('simulink/Sources/Constant', [harnessName '/Tr_zero']);
set_param([harnessName '/Tr_zero'], 'Value', '0', 'Position', [50 260 80 280]);

add_block('simulink/Sinks/To Workspace', [harnessName '/theta1_out']);
set_param([harnessName '/theta1_out'], 'VariableName', 'theta1_log', 'Position', [450 110 520 130]);
add_block('simulink/Sinks/To Workspace', [harnessName '/theta1_dot_out']);
set_param([harnessName '/theta1_dot_out'], 'VariableName', 'theta1_dot_log', 'Position', [450 150 520 170]);
add_block('simulink/Sinks/To Workspace', [harnessName '/theta2_out']);
set_param([harnessName '/theta2_out'], 'VariableName', 'theta2_log', 'Position', [450 190 520 210]);
add_block('simulink/Sinks/To Workspace', [harnessName '/theta2_dot_out']);
set_param([harnessName '/theta2_dot_out'], 'VariableName', 'theta2_dot_log', 'Position', [450 230 520 250]);
add_block('simulink/Sinks/To Workspace', [harnessName '/Ts_out']);
set_param([harnessName '/Ts_out'], 'VariableName', 'Ts_log', 'Position', [450 270 520 290]);

add_line(harnessName, 'Td_step/1', portRef(dutInHarness, 'T_d'), 'autorouting', 'on');
add_line(harnessName, 'Ta_zero/1', portRef(dutInHarness, 'T_a'), 'autorouting', 'on');
add_line(harnessName, 'Tr_zero/1', portRef(dutInHarness, 'T_r'), 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta1'), 'theta1_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta1_dot'), 'theta1_dot_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta2'), 'theta2_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'theta2_dot'), 'theta2_dot_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'T_s'), 'Ts_out/1', 'autorouting', 'on');

% MaxStep BAT BUOC: solver buoc-thay-doi mac dinh chon buoc qua lon sau khi
% he da on dinh, tuong tac xau voi ham tanh(c*x4) doc dung (c=100) - gay
% meo so lieu log (trong nhu dao dong cham khong tat, nhung KHONG PHAI vat
% ly that - da kiem chung: ep MaxStep=0.01 thi hoi tu CHINH XAC ve gia tri
% giai tich tu t~3s tro di, on dinh tuyet doi).
set_param(harnessName, 'StopTime', '6', 'MaxStep', '0.01');
simOut = sim(harnessName);

theta1_log = simOut.get('theta1_log');
theta1_dot_log = simOut.get('theta1_dot_log');
theta2_dot_log = simOut.get('theta2_dot_log');
Ts_log = simOut.get('Ts_log');

assert(~any(isnan(theta1_log.Data)), 'theta1 co NaN');
assert(~any(isnan(theta1_dot_log.Data)), 'theta1_dot co NaN');
assert(~any(isnan(theta2_dot_log.Data)), 'theta2_dot co NaN');
assert(~any(isnan(Ts_log.Data)), 'T_s co NaN');
assert(theta1_log.Data(end) > 0, 'theta1 cuoi ky vong > 0 (Td buoc nhay duong)');

C1 = evalin('base', 'C1');
C2 = evalin('base', 'C2');
T_f = evalin('base', 'T_f');
c  = evalin('base', 'c');
Td_final = 3;

omega_ref = fzero(@(w) (C1+C2)*w + T_f*tanh(c*w) - Td_final, 0.5);
Ts_ref = Td_final - C1*omega_ref;
Ts_ref_check = C2*omega_ref + T_f*tanh(c*omega_ref);
assert(abs(Ts_ref - Ts_ref_check) < 1e-9, ...
    'Loi noi bo: 2 cach tinh T_s_ref khong khop (%.6g vs %.6g)', Ts_ref, Ts_ref_check);

assert(abs(theta1_dot_log.Data(end) - omega_ref) < 1e-3, ...
    'theta1_dot xac lap khong khop giai tich (model=%.6g, giai_tich=%.6g)', ...
    theta1_dot_log.Data(end), omega_ref);
assert(abs(theta2_dot_log.Data(end) - omega_ref) < 1e-3, ...
    'theta2_dot xac lap khong khop giai tich (model=%.6g, giai_tich=%.6g)', ...
    theta2_dot_log.Data(end), omega_ref);
assert(abs(Ts_log.Data(end) - Ts_ref) < 1e-3, ...
    'T_s xac lap khong khop giai tich (model=%.6g, giai_tich=%.6g)', ...
    Ts_log.Data(end), Ts_ref);

fprintf(['[%s] TEST PASS: omega(end)=%.6g rad/s (giai_tich=%.6g), ' ...
    'T_s(end)=%.6g N.m (giai_tich=%.6g)\n'], ...
    modelFileName, theta1_dot_log.Data(end), omega_ref, Ts_log.Data(end), Ts_ref);

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
