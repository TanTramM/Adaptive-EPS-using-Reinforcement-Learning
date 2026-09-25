function test_map()
%TEST_MAP Verify Map.mdl (static EPS assist map, hand-formatted from the build_map.m output).
%
%   Requires the root subsystem to expose ports named:
%   In: T_s, v | Out: T_a.
%
%   Feeds piecewise-constant (T_s, v) pairs (held between samples) and compares T_a at every sample instant with:
%   (1) an independent 2-D interpolation of the table read straight from data/map.json (clipped outside the
%       breakpoints, odd in T_s): pseudo-random pairs, including negative T_s and speeds outside 20-100 km/h;
%   (2) the calibration itself: at every breakpoint speed and every calibration T_s (Table 4 values) the output is
%       the calibrated T_a (data/map.json calibration_*), and the assist saturates at T_a,max beyond the last pair.
%   The table is read from the base workspace by the Lookup block (run load_map first) - this test checks the
%   IMPLEMENTATION (table wiring, sign handling, sampling), not the calibration values.

modelFileName = 'Map';

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
ctrlDir   = fileparts(scriptDir);               % Map/
modelDir  = fileparts(ctrlDir);                 % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
Ts = raw.Ts_ctrl.value;
vBp  = raw.v_breakpoints_kmh(:)' / 3.6;
tsBp = raw.Ts_breakpoints_Nm(:)';
table = raw.Ta_table_Nm;
calTs = raw.calibration_Ts_Nm;     % rows a_y, columns v
calTa = raw.calibration_Ta_Nm;

% ---- input sequence ----
rng(2);
Nrand = 300;
Tsin = 4.5*(2*rand(Nrand, 1) - 1);
vin  = (10 + 100*rand(Nrand, 1)) / 3.6;
[nA, nV] = size(calTs);
Tcal = []; vcal = []; Tacal = [];
for j = 1:nV
    for i = 1:nA
        for sg = [1 -1]
            Tcal(end+1, 1) = sg*calTs(i, j);      %#ok<AGROW>
            vcal(end+1, 1) = vBp(j);              %#ok<AGROW>
            Tacal(end+1, 1) = sg*calTa(i, j);     %#ok<AGROW>
        end
    end
end
Tsin = [Tsin; Tcal; 5.0; -5.0];  vin = [vin; vcal; vBp(1); vBp(end)];   % last two: beyond the last pair (saturation)
N = numel(Tsin);
tIn = [0; ((1:N-1)' - 0.5)*Ts];     % value k holds from (k-0.5)*Ts
assignin('base', 'test_map_Ts', [tIn Tsin]);
assignin('base', 'test_map_v',  [tIn vin]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_map_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);
add_block(dut, [harnessName '/DUT']);
dutInHarness = [harnessName '/DUT'];

add_block('simulink/Sources/From Workspace', [harnessName '/Ts_in']);
set_param([harnessName '/Ts_in'], 'VariableName', 'test_map_Ts', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Sources/From Workspace', [harnessName '/v_in']);
set_param([harnessName '/v_in'], 'VariableName', 'test_map_v', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'Ta_log', 'SaveFormat', 'Array', 'SampleTime', 'Ts_ctrl');
add_line(harnessName, 'Ts_in/1', portRef(dutInHarness, 'T_s'));
add_line(harnessName, 'v_in/1',  portRef(dutInHarness, 'v'));
add_line(harnessName, portRef(dutInHarness, 'T_a'), 'Ta_out/1');
set_param(harnessName, 'StopTime', sprintf('%.15g', (N-1)*Ts), 'Solver', 'ode1', 'FixedStep', sprintf('%.15g', Ts/2));
simOut = sim(harnessName);
Ta_sim = simOut.get('Ta_log');
assert(numel(Ta_sim) >= N, 'Expected %d samples, got %d', N, numel(Ta_sim));
Ta_sim = Ta_sim(1:N);

% ---- (1) independent table interpolation ----
vc = min(max(vin, vBp(1)), vBp(end));
tc = min(max(abs(Tsin), tsBp(1)), tsBp(end));
Ta_ref = sign(Tsin) .* interp2(tsBp, vBp, table, tc, vc, 'linear');
err1 = max(abs(Ta_sim - Ta_ref));
assert(err1 < 1e-9, '(1) T_a differs from the independent table interpolation: max err %.3g', err1);

% ---- (2) calibration reproduction ----
idx = Nrand + (1:numel(Tcal));
err2 = max(abs(Ta_sim(idx) - Tacal));
assert(err2 < 1e-9, '(2) T_a at calibration points differs from data/map.json calibration: max err %.3g', err2);
assert(abs(Ta_sim(end-1) - calTa(end, 1)) < 1e-9 && abs(Ta_sim(end) + calTa(end, end)) < 1e-9, ...
    '(2) saturation at T_a,max not reached beyond the last pair');

fprintf('[%s] TEST PASS: T_a matches the independent table interpolation at %d samples (max err %.2g) and reproduces the %d calibration points (max err %.2g); saturates at T_a,max\n', ...
    modelFileName, N, err1, numel(Tcal), err2);

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_map_Ts test_map_v');
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
