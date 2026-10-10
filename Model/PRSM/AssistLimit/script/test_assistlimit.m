function test_assistlimit()
%TEST_ASSISTLIMIT Verify AssistLimit.mdl (assist limit T_a,max(v), built by build_assistlimit.m) and the data behind it.
%
%   Requires the root subsystem to expose ports named: In: v | Out: T_a_max. Run Model/PRSM/AssistLimit/load_assistlimit.m first.
%   (1) the table in data/ref.json is consistent: T_a,max = T_a,req + F with F = T_f read from data/params.json, and T_a,max decreasing with v
%       from 30 km/h (T_d,ref grows with v while T_r is constant at 0.4 g);
%   (2) the block returns the table value at breakpoints, between breakpoints (linear), and clips below 20 and above 100 km/h.
%   The expected values are computed here from data/ref.json and data/params.json (not from base-workspace variables).

modelFileName = 'AssistLimit';
scriptDir = fileparts(mfilename('fullpath'));   % AssistLimit/script
partDir   = fileparts(scriptDir);               % AssistLimit/
modelDir  = fileparts(fileparts(partDir));      % Model/
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
P = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
Tf = P.cum1.T_f.value;
v_kmh = raw.Ta_max.v_kmh(:)'; tab = raw.Ta_max.Ta_max_Nm(:)'; req = raw.Ta_max.Ta_req_Nm(:)';

assert(abs(raw.Ta_max.F_Nm - Tf) < 1e-12, 'F_Nm in ref.json (%g) differs from T_f in params.json (%g)', raw.Ta_max.F_Nm, Tf);
assert(max(abs(tab - req - Tf)) < 1e-12, 'T_a,max is not T_a,req + F');
assert(all(diff(tab(v_kmh >= 30)) < 0), 'T_a,max must decrease with v from 30 km/h');
fprintf('[%s] data: T_a,max = T_a,req + F, F = T_f = %g N.m; T_a,max(20..100 km/h) = %.3f .. %.3f N.m\n', modelFileName, Tf, tab(1), tab(end));

vbp = v_kmh / 3.6;
harnessName = 'test_assistlimit_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(partDir, [modelFileName '.mdl']));
subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'AssistLimit must have exactly 1 root subsystem');
new_system(harnessName);
add_block(subs{1}, [harnessName '/DUT']);
dut = [harnessName '/DUT'];
add_block('simulink/Sources/Constant', [harnessName '/v_in']);
add_line(harnessName, 'v_in/1', portRef(dut, 'v'));
add_block('simulink/Sinks/To Workspace', [harnessName '/Tamax_out']);
set_param([harnessName '/Tamax_out'], 'VariableName', 'Tamax_log', 'SaveFormat', 'Timeseries');
add_line(harnessName, portRef(dut, 'T_a_max'), 'Tamax_out/1');
set_param(harnessName, 'StopTime', '0.01', 'MaxStep', '1e-3');

%        v [km/h]
cases = [20; 25; 37.5; 60; 82.5; 100; 15; 130];     % breakpoints, between, below and above the table
for i = 1:numel(cases)
    set_param([harnessName '/v_in'], 'Value', sprintf('%.15g', cases(i) / 3.6));
    so = sim(harnessName);
    out = so.get('Tamax_log').Data(end);
    ref = interp1(vbp, tab, min(max(cases(i) / 3.6, vbp(1)), vbp(end)), 'linear');
    fprintf('[%s] case %d: v = %.4g km/h -> T_a_max = %.6g (ref %.6g)\n', modelFileName, i, cases(i), out, ref);
    assert(abs(out - ref) < 1e-9, 'T_a_max mismatch in case %d', i);
end
fprintf('[%s] TEST PASS: table consistency (T_a,max = T_a,req + T_f) and block output at breakpoints, between, and clipped outside 20-100 km/h\n', modelFileName);
close_system(harnessName, 0);
close_system(modelFileName, 0);
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
