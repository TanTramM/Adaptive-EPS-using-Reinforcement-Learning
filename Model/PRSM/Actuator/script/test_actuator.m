function test_actuator()
%TEST_ACTUATOR Verify Actuator.mdl (assist limit T_a,max(v) + motor lag, auto-built by build_actuator.m).
%
%   Requires the root subsystem to expose ports named: In: T_a_cmd, v | Out: T_a, T_a_lim.
%   Run Model/load_actuator.m first. The expected values are computed here from data/ref.json and data/actuator.json:
%   (1) steady state: T_a_lim = T_a = clip(T_a_cmd, -T_a_max(v), +T_a_max(v)), both signs, inside and outside the limit;
%   (2) dynamics: the response to a step of the (unsaturated) command is the first-order lag, T_a(tau_m) = 63.2% of the step.

modelFileName = 'Actuator';
scriptDir = fileparts(mfilename('fullpath'));   % Actuator/script
actDir    = fileparts(scriptDir);               % Actuator/
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
vbp = raw.Ta_max.v_kmh(:)' / 3.6;
tab = raw.Ta_max.Ta_max_Nm(:)';
wm  = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;

harnessName = 'test_actuator_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(actDir, [modelFileName '.mdl']));
subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'Actuator must have exactly 1 root subsystem');
new_system(harnessName);
add_block(subs{1}, [harnessName '/DUT']);
dut = [harnessName '/DUT'];
add_block('simulink/Sources/Step', [harnessName '/cmd']);
set_param([harnessName '/cmd'], 'Time', '0.01', 'Before', '0', 'After', 'cmd_value');
add_block('simulink/Sources/Constant', [harnessName '/v_in']);
add_line(harnessName, 'cmd/1',  portRef(dut, 'T_a_cmd'));
add_line(harnessName, 'v_in/1', portRef(dut, 'v'));
for nm = {'T_a', 'T_a_lim'}
    add_block('simulink/Sinks/To Workspace', [harnessName '/' nm{1} '_out']);
    set_param([harnessName '/' nm{1} '_out'], 'VariableName', [nm{1} '_log'], 'SaveFormat', 'Timeseries');
    add_line(harnessName, portRef(dut, nm{1}), [nm{1} '_out/1']);
end
set_param(harnessName, 'StopTime', '0.1', 'MaxStep', '1e-4', 'RelTol', '1e-8');

%         v [m/s]  command [N.m]
cases = [ 25/3.6,   2.0;       % inside the limit
          25/3.6,  -2.0;
          25/3.6,  50;         % above the limit -> clipped
          25/3.6, -50;
          100/3.6,  50;
          15/3.6,  -50];       % below the table range -> Clip
for i = 1:size(cases, 1)
    assignin('base', 'cmd_value', cases(i, 2));
    set_param([harnessName '/v_in'], 'Value', sprintf('%.15g', cases(i, 1)));
    so = sim(harnessName);
    Ta  = so.get('T_a_log').Data(end);
    Tl  = so.get('T_a_lim_log').Data(end);
    lim = interp1(vbp, tab, min(max(cases(i, 1), vbp(1)), vbp(end)), 'linear');
    ref = min(max(cases(i, 2), -lim), lim);
    fprintf('[%s] case %d: v=%.3g m/s cmd=%.3g -> T_a_lim=%.6g T_a=%.6g (ref %.6g, T_a,max %.4g)\n', modelFileName, i, cases(i, 1), cases(i, 2), Tl, Ta, ref, lim);
    assert(abs(Tl - ref) < 1e-9, 'T_a_lim mismatch in case %d', i);
    assert(abs(Ta - ref) < 1e-4 * max(1, abs(ref)), 'T_a steady state mismatch in case %d', i);
end

% dynamics: unsaturated step of 1 N.m
assignin('base', 'cmd_value', 1);
set_param([harnessName '/v_in'], 'Value', '25');
so = sim(harnessName);
ts = so.get('T_a_log');
[tu, iu] = unique(ts.Time, 'last');
d = ts.Data(iu);
after = tu >= 0.01 + 1e-9;
rise = after & d > 1e-6 & d < 0.99;
[du, ju] = unique(d(rise));
tt = tu(rise);
t63 = interp1(du, tt(ju), 1 - exp(-1)) - 0.01;
assert(abs(t63 - 1 / wm) < 0.03 / wm, 'time to 63.2%% is %.4g ms, expected %.4g ms', 1000 * t63, 1000 / wm);
fprintf('[%s] TEST PASS: assist limit both signs and clip outside the table; motor lag tau_m = %.4g ms (measured %.4g ms)\n', modelFileName, 1000 / wm, 1000 * t63);
close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear cmd_value');
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - wiring by NAME.
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
