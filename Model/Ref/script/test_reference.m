function test_reference()
%TEST_REFERENCE Verify Reference.mdl (T_d,ref + e_T, hand-formatted from the
%build_reference.m output).
%
%   Requires the root subsystem to expose ports named:
%   In: T_s, v, a_y | Out: T_d_ref, e_T.
%
%   Feeds fixed (T_s, v, a_y) cases (incl. negative a_y and points outside
%   the table range, checking Clip) and compares T_d_ref / e_T with a 2-D
%   interpolation computed INDEPENDENTLY here with interp2 on the same
%   data/ref.json data (not the base-workspace variables of load_ref.m).

modelFileName = 'Reference';

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
refDir    = fileparts(scriptDir);               % Ref/
modelDir  = fileparts(refDir);                  % Model/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(refDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp_ms   = rawRef.v_breakpoints_kmh(:)' / 3.6;
ay_bp_ms2 = rawRef.ay_breakpoints_g(:)' * 9.81;
tableData = rawRef.table_Nm;   % row=a_y(4), column=v(5)

harnessName = 'test_reference_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 300]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Constant', [harnessName '/Ts_in']);
add_block('simulink/Sources/Constant', [harnessName '/v_in']);
add_block('simulink/Sources/Constant', [harnessName '/ay_in']);
add_block('simulink/Sinks/To Workspace', [harnessName '/Tdref_out']);
set_param([harnessName '/Tdref_out'], 'VariableName', 'Tdref_log', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', [harnessName '/eT_out']);
set_param([harnessName '/eT_out'], 'VariableName', 'eT_log', 'SaveFormat', 'Timeseries');

add_line(harnessName, 'Ts_in/1', portRef(dutInHarness, 'T_s'));
add_line(harnessName, 'v_in/1',  portRef(dutInHarness, 'v'));
add_line(harnessName, 'ay_in/1', portRef(dutInHarness, 'a_y'));
add_line(harnessName, portRef(dutInHarness, 'T_d_ref'), 'Tdref_out/1');
add_line(harnessName, portRef(dutInHarness, 'e_T'),     'eT_out/1');
set_param(harnessName, 'StopTime', '0.1');

%            T_s    v [m/s]  a_y [m/s^2]
testCases = [ 2.5,  15,      1.5;
              2.5,  15,     -1.5;       % negative a_y
              3.0,  25,      3.0;
             -1.0,  10,      0.5*9.81]; % outside range -> Clip
for i = 1:size(testCases, 1)
    Ts_test = testCases(i, 1); v_test = testCases(i, 2); ay_test = testCases(i, 3);
    set_param([harnessName '/Ts_in'], 'Value', sprintf('%.15g', Ts_test));
    set_param([harnessName '/v_in'],  'Value', sprintf('%.15g', v_test));
    set_param([harnessName '/ay_in'], 'Value', sprintf('%.15g', ay_test));
    simOut = sim(harnessName);
    Tdref_sim = simOut.get('Tdref_log').Data(end);
    eT_sim    = simOut.get('eT_log').Data(end);

    v_clip  = min(max(v_test, min(v_bp_ms)), max(v_bp_ms));
    ay_clip = min(max(abs(ay_test), min(ay_bp_ms2)), max(ay_bp_ms2));
    Tdref_ref = sign(ay_test) * interp2(ay_bp_ms2, v_bp_ms, tableData', ay_clip, v_clip, 'linear');
    eT_ref = Ts_test - Tdref_ref;

    fprintf('[%s] case %d: T_s=%.3g v=%.3g a_y=%.3g -> T_d_ref: model=%.6g ref=%.6g | e_T: model=%.6g ref=%.6g\n', ...
        modelFileName, i, Ts_test, v_test, ay_test, Tdref_sim, Tdref_ref, eT_sim, eT_ref);
    assert(abs(Tdref_sim - Tdref_ref) < 1e-6, 'T_d_ref mismatch in case %d', i);
    assert(abs(eT_sim - eT_ref) < 1e-6, 'e_T mismatch in case %d', i);
end

fprintf('[%s] TEST PASS: matches independent interpolation, both a_y signs, Clip outside range\n', modelFileName);
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
