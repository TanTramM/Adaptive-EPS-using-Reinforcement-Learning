function test_reference()
%TEST_REFERENCE Verify Reference.mdl (T_d,ref, auto-built by
%build_reference.m).
%
%   Requires the root subsystem to expose ports named:
%   In: v, a_y | Out: T_d_ref.
%
%   (1) The fine table in data/ref.json equals Table 4 plus the point
%       a_y = 0 -> 0, PCHIP-interpolated along a_y then v, recomputed here
%       from the source table (checks make_ref_table.m).
%   (2) Feeds fixed (v, a_y) cases (incl. negative a_y, a_y = 0 and
%       +-small a_y for continuity, points outside the table range for Clip)
%       and compares T_d_ref with sgn(a_y) * interp2 of the fine table
%       read from data/ref.json (not the base-workspace variables of load_ref.m).

modelFileName = 'Reference';

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
refDir    = fileparts(scriptDir);               % Ref/
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(refDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp_ms   = rawRef.fine.v_breakpoints_kmh(:)' / 3.6;
ay_bp_ms2 = rawRef.fine.ay_breakpoints_g(:)' * 9.81;
tableData = rawRef.fine.table_Nm;   % row = a_y, column = v

% (1) fine table = PCHIP of Table 4 with the added point a_y = 0 -> 0
a0 = [0; rawRef.ay_breakpoints_g(:)];
T0 = [zeros(1, numel(rawRef.v_breakpoints_kmh)); rawRef.table_Nm];
Aind = interp1(a0, T0, rawRef.fine.ay_breakpoints_g(:), 'pchip');
Tind = interp1(rawRef.v_breakpoints_kmh(:), Aind', rawRef.fine.v_breakpoints_kmh(:), 'pchip')';
errFine = max(abs(Tind - tableData), [], 'all');
assert(errFine < 1e-5, 'fine table differs from the PCHIP of Table 4: max err %.3g', errFine);
assert(all(tableData(1, :) == 0), 'fine table must contain a_y = 0 -> T_d,ref = 0');

harnessName = 'test_reference_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 300]);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/Constant', [harnessName '/v_in']);
add_block('simulink/Sources/Constant', [harnessName '/ay_in']);
add_block('simulink/Sinks/To Workspace', [harnessName '/Tdref_out']);
set_param([harnessName '/Tdref_out'], 'VariableName', 'Tdref_log', 'SaveFormat', 'Timeseries');

add_line(harnessName, 'v_in/1',  portRef(dutInHarness, 'v'));
add_line(harnessName, 'ay_in/1', portRef(dutInHarness, 'a_y'));
add_line(harnessName, portRef(dutInHarness, 'T_d_ref'), 'Tdref_out/1');
set_param(harnessName, 'StopTime', '0.1');

%            v [m/s]  a_y [m/s^2]
testCases = [ 15,      1.5;
              15,     -1.5;       % negative a_y
              25,      3.0;
              20,      0;         % a_y = 0 -> T_d_ref = 0
              20,      0.01;      % +-small a_y: T_d_ref small, continuous through 0
              20,     -0.01;
              10,      0.5*9.81]; % outside range -> Clip
for i = 1:size(testCases, 1)
    v_test = testCases(i, 1); ay_test = testCases(i, 2);
    set_param([harnessName '/v_in'],  'Value', sprintf('%.15g', v_test));
    set_param([harnessName '/ay_in'], 'Value', sprintf('%.15g', ay_test));
    simOut = sim(harnessName);
    Tdref_sim = simOut.get('Tdref_log').Data(end);

    v_clip  = min(max(v_test, min(v_bp_ms)), max(v_bp_ms));
    ay_clip = min(max(abs(ay_test), min(ay_bp_ms2)), max(ay_bp_ms2));
    Tdref_ref = sign(ay_test) * interp2(ay_bp_ms2, v_bp_ms, tableData', ay_clip, v_clip, 'linear');

    fprintf('[%s] case %d: v=%.3g a_y=%.3g -> T_d_ref: model=%.6g ref=%.6g\n', modelFileName, i, v_test, ay_test, Tdref_sim, Tdref_ref);
    assert(abs(Tdref_sim - Tdref_ref) < 1e-6, 'T_d_ref mismatch in case %d', i);
    if abs(ay_test) <= 0.01
        assert(abs(Tdref_sim) < 0.05, 'T_d_ref not continuous near a_y = 0 in case %d (%.3g)', i, Tdref_sim);
    end
end

fprintf('[%s] TEST PASS: fine table = PCHIP of Table 4 (max err %.2g); matches independent interpolation, both a_y signs, continuous at a_y = 0, Clip outside range\n', ...
    modelFileName, errFine);
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
