function test_actuator()
%TEST_ACTUATOR Verify Actuator.mdl (clamp to the input T_a_max + motor lag, auto-built by build_actuator.m).
%
%   Requires the root subsystem to expose ports named: In: T_a_cmd, T_a_max | Out: T_a, T_a_lim.
%   Run Model/PRSM/Actuator/load_actuator.m first. The expected values are computed here from data/actuator.json:
%   (1) steady state: T_a_lim = T_a = clip(T_a_cmd, -T_a_max, +T_a_max), both signs, inside and outside the limit;
%   (2) dynamics: the response to a step of the (unsaturated) command is the first-order lag, T_a(tau_m) = 63.2% of the step.

modelFileName = 'Actuator';
scriptDir = fileparts(mfilename('fullpath'));   % Actuator/script
actDir    = fileparts(scriptDir);               % Actuator/
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
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
add_block('simulink/Sources/Constant', [harnessName '/Tmax_in']);
add_line(harnessName, 'cmd/1',  portRef(dut, 'T_a_cmd'));
add_line(harnessName, 'Tmax_in/1', portRef(dut, 'T_a_max'));
for nm = {'T_a', 'T_a_lim'}
    add_block('simulink/Sinks/To Workspace', [harnessName '/' nm{1} '_out']);
    set_param([harnessName '/' nm{1} '_out'], 'VariableName', [nm{1} '_log'], 'SaveFormat', 'Timeseries');
    add_line(harnessName, portRef(dut, nm{1}), [nm{1} '_out/1']);
end
set_param(harnessName, 'StopTime', '0.1', 'MaxStep', '1e-4', 'RelTol', '1e-8');

%         T_a_max [N.m]  command [N.m]
cases = [ 8.0,   2.0;          % inside the limit
          8.0,  -2.0;
          8.0,  50;            % above the limit -> clipped
          8.0, -50;
          6.5,  50;            % another limit
          3.7,  -50];          % small limit (low speed)
for i = 1:size(cases, 1)
    assignin('base', 'cmd_value', cases(i, 2));
    set_param([harnessName '/Tmax_in'], 'Value', sprintf('%.15g', cases(i, 1)));
    so = sim(harnessName);
    Ta  = so.get('T_a_log').Data(end);
    Tl  = so.get('T_a_lim_log').Data(end);
    lim = cases(i, 1);
    ref = min(max(cases(i, 2), -lim), lim);
    fprintf('[%s] case %d: T_a_max=%.3g cmd=%.3g -> T_a_lim=%.6g T_a=%.6g (ref %.6g)\n', modelFileName, i, lim, cases(i, 2), Tl, Ta, ref);
    assert(abs(Tl - ref) < 1e-9, 'T_a_lim mismatch in case %d', i);
    assert(abs(Ta - ref) < 1e-4 * max(1, abs(ref)), 'T_a steady state mismatch in case %d', i);
end

% dynamics: unsaturated step of 1 N.m
assignin('base', 'cmd_value', 1);
set_param([harnessName '/Tmax_in'], 'Value', '8');
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
fprintf('[%s] TEST PASS: clamp to the input T_a_max both signs; motor lag tau_m = %.4g ms (measured %.4g ms)\n', modelFileName, 1000 / wm, 1000 * t63);
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
