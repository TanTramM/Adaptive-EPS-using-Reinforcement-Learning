function test_reference(modelFileName)
%TEST_REFERENCE Kiem chung khoi Reference (T_d,ref + e_T).
%   test_reference() - test ban vua build (Reference_s.mdl, mac dinh).
%   test_reference('Reference') - test ban da tu format tay (neu co).
%
%   Chi doi hoi model co DUNG 1 subsystem cap goc voi cac cong TEN:
%   In: T_d, v, a_y | Out: T_d_ref, e_T.
%
%   Cap (T_d, v, a_y) co dinh (nhieu truong hop, gom ca a_y am), so sanh
%   T_d_ref/e_T voi noi suy 2D tinh tay bang interp2 tren dung du lieu
%   data/ref.json.

if nargin < 1
    modelFileName = 'Reference_s';
end

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
refDir    = fileparts(scriptDir);               % Ref/
modelDir  = fileparts(refDir);                  % Model/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(refDir, [modelFileName '.mdl']));
dut = subsystemDuyNhat(modelFileName);

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp_ms   = rawRef.v_breakpoints_kmh(:)' / 3.6;
ay_bp_ms2 = rawRef.ay_breakpoints_g(:)' * 9.81;
tableData = rawRef.table_Nm;   % hang=a_y(4), cot=v(5) - dung interp2(X=ay,Y=v,...)

testCases = [
    2.5,     15,     1.5;
    2.5,     15,    -1.5;
    3.0,     25,     3.0;
    -1.0,    10,     0.5*9.81;
];

harnessName = 'test_reference_harness';
for i = 1:size(testCases,1)
    Td_test = testCases(i,1);
    v_test  = testCases(i,2);
    ay_test = testCases(i,3);

    if bdIsLoaded(harnessName)
        close_system(harnessName, 0);
    end
    new_system(harnessName);
    open_system(harnessName);

    add_block(dut, [harnessName '/DUT']);
    set_param([harnessName '/DUT'], 'Position', [250 100 450 300]);
    dutInHarness = [harnessName '/DUT'];

    add_block('simulink/Sources/Constant', [harnessName '/Td_in']);
    set_param([harnessName '/Td_in'], 'Value', num2str(Td_test), 'Position', [50 110 80 130]);
    add_block('simulink/Sources/Constant', [harnessName '/v_in']);
    set_param([harnessName '/v_in'], 'Value', num2str(v_test), 'Position', [50 160 80 180]);
    add_block('simulink/Sources/Constant', [harnessName '/ay_in']);
    set_param([harnessName '/ay_in'], 'Value', num2str(ay_test), 'Position', [50 210 80 230]);

    add_block('simulink/Sinks/To Workspace', [harnessName '/Tdref_out']);
    set_param([harnessName '/Tdref_out'], 'VariableName', 'Tdref_log', 'Position', [550 110 620 130]);
    add_block('simulink/Sinks/To Workspace', [harnessName '/eT_out']);
    set_param([harnessName '/eT_out'], 'VariableName', 'eT_log', 'Position', [550 180 620 200]);

    add_line(harnessName, 'Td_in/1', portRef(dutInHarness, 'T_d'), 'autorouting', 'on');
    add_line(harnessName, 'v_in/1',  portRef(dutInHarness, 'v'), 'autorouting', 'on');
    add_line(harnessName, 'ay_in/1', portRef(dutInHarness, 'a_y'), 'autorouting', 'on');
    add_line(harnessName, portRef(dutInHarness, 'T_d_ref'), 'Tdref_out/1', 'autorouting', 'on');
    add_line(harnessName, portRef(dutInHarness, 'e_T'), 'eT_out/1', 'autorouting', 'on');

    set_param(harnessName, 'StopTime', '0.1');
    simOut = sim(harnessName);

    Tdref_sim = simOut.get('Tdref_log').Data(end);
    eT_sim    = simOut.get('eT_log').Data(end);

    v_clip  = min(max(v_test, min(v_bp_ms)), max(v_bp_ms));
    ay_clip = min(max(abs(ay_test), min(ay_bp_ms2)), max(ay_bp_ms2));
    mag_ref = interp2(ay_bp_ms2, v_bp_ms, tableData', ay_clip, v_clip, 'linear');
    Tdref_ref = sign(ay_test) * mag_ref;
    if ay_test == 0
        Tdref_ref = 0;
    end
    eT_ref = Td_test - Tdref_ref;

    fprintf('[%s] Case %d: T_d=%.3g v=%.3g a_y=%.3g -> T_d_ref: model=%.6g giai_tich=%.6g | e_T: model=%.6g giai_tich=%.6g\n', ...
        modelFileName, i, Td_test, v_test, ay_test, Tdref_sim, Tdref_ref, eT_sim, eT_ref);

    assert(abs(Tdref_sim - Tdref_ref) < 1e-6, 'T_d_ref sai lech vuot nguong o case %d', i);
    assert(abs(eT_sim - eT_ref) < 1e-6, 'e_T sai lech vuot nguong o case %d', i);

    close_system(harnessName, 0);
end

fprintf('[%s] TEST PASS: khop noi suy giai tich, dung ca 2 chieu a_y.\n', modelFileName);
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
