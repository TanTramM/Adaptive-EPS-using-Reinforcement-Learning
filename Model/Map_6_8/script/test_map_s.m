function test_map_s()
%TEST_MAP_S Verify Map_6_8_s.mdl (conventional EPS assist controller, auto-built by build_map.m).
%
%   Requires the root subsystem to expose ports named:  In: T_s, v | Out: T_a.
%
%   Everything is recomputed INDEPENDENTLY from data/map_6_8.json (run load_map_6_8 first - the blocks read the base
%   workspace):
%   (1) Table properties: zero inside the dead band |T_s| <= Ts0, non-decreasing in |T_s|, slope <= the K_max of its speed (two tiers), last
%       column = T_a,max(v).
%   (2) Two lead stages (low-speed and high-speed tier): Tustin coefficients of (s/z + 1)/(s/p + 1) derived by hand here equal the
%       stored ones; DC gain 1.
%   (3) Simulation: T_s(t) (sine sweep plus steps, both signs) and v(t) (ramp 10 -> 110 km/h, outside the table on
%       both ends) held between samples; at every sample T_a equals
%       (1 - w(v)) H_low(z) [ sgn(T_s) * interp2(table, v, |T_s|) ] + w(v) H_high(z) [ ... ]
%       computed with filter() here (no saturation: the assist limit and the motor are in the Actuator block).
%   The last column of the table is T_a,max(v) (the map reaches the assist limit at its end).
%   (4) After a long hold, T_a equals the static map value (DC gain of the compensator is 1).

modelFileName = 'Map_s';

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
ctrlDir   = fileparts(scriptDir);               % Map/
modelDir  = fileparts(ctrlDir);                 % Model/

raw  = jsondecode(fileread(fullfile(modelDir, 'data', 'map_6_8.json')));
Ts   = raw.Ts_ctrl.value;
vBp  = raw.v_breakpoints_kmh(:)' / 3.6;
tsBp = raw.Ts_breakpoints_Nm(:)';
tab  = raw.Ta_table_Nm;
rawRefTa = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
TaMx = rawRefTa.Ta_max.Ta_max_Nm(:)';   % T_a,max(v) of Ref (Documents/Ref/ref.txt section 1.5)

% ---- (1) table properties ----
assert(all(all(tab(:, tsBp <= raw.Ts0.value + 1e-12) == 0)), '(1) table is not zero inside the dead band');
slope = diff(tab, 1, 2) ./ diff(tsBp);
assert(all(slope(:) >= -1e-9), '(1) table decreases in |T_s|');
Kv = raw.Kmax_by_speed(:);   % K_max of every map speed (two tiers)
assert(all(max(slope, [], 2) <= Kv + 1e-6), '(1) a row of the table has a slope above its K_max');
assert(max(abs(tab(:, end)' - TaMx)) < 1e-9, '(1) last column differs from T_a,max');

% ---- (2) lead stage coefficients ----
tiers = {raw.lead, raw.lead_hi};   % low-speed tier, high-speed tier
numI = cell(1, 2); denI = cell(1, 2);
for q = 1:2
    a = 2 / (tiers{q}.zero_rad_s * Ts);  b = 2 / (tiers{q}.pole_rad_s * Ts);
    numI{q} = [a + 1, 1 - a] / (b + 1);   denI{q} = [1, (1 - b) / (b + 1)];
    assert(max(abs(numI{q} - tiers{q}.num(:)')) < 1e-9 && max(abs(denI{q} - tiers{q}.den(:)')) < 1e-9, ...
        '(2) stored lead coefficients of tier %d differ from the Tustin transform', q);
    assert(abs(sum(numI{q}) / sum(denI{q}) - 1) < 1e-12, '(2) DC gain of lead stage %d is not 1', q);
end
blendV = [0, raw.blend_kmh(:)', 400] / 3.6;   blendW = [0 0 1 1];

% ---- (3) input sequence ----
N1 = 4000; N2 = 1500;                                   % sweep, then hold
k1 = (0:N1-1)';
Tsin = 3.5 * sin(2*pi*(0.2 + 0.8*k1/N1) .* k1 * Ts) + 0.8 * sign(sin(2*pi*1.3*k1*Ts));
vin  = (10 + 100 * k1 / N1) / 3.6;
TsHold = 1.9; vHold = 60 / 3.6;
Tsin = [Tsin; TsHold * ones(N2, 1)];  vin = [vin; vHold * ones(N2, 1)];
N = numel(Tsin);
tIn = [0; ((1:N-1)' - 0.5) * Ts];     % value k holds from (k-0.5)*Ts
assignin('base', 'test_map_Ts', [tIn Tsin]);
assignin('base', 'test_map_v',  [tIn vin]);

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_map_s_harness';
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

vc = min(max(vin, vBp(1)), vBp(end));
tc = min(max(abs(Tsin), tsBp(1)), tsBp(end));
u  = sign(Tsin) .* interp2(tsBp, vBp, tab, tc, vc, 'linear');
wv = interp1(blendV, blendW, vin);   % weight of the high-speed lead
Ta_ref = (1 - wv) .* filter(numI{1}, denI{1}, u) + wv .* filter(numI{2}, denI{2}, u);
err3 = max(abs(Ta_sim - Ta_ref));
assert(err3 < 1e-9, '(3) T_a differs from the independent computation: max err %.3g', err3);

% ---- (4) steady state after the hold ----
TaStatic = interp2(tsBp, vBp, tab, TsHold, vHold, 'linear');
assert(abs(Ta_sim(end) - TaStatic) < 1e-6, '(4) T_a after the hold = %.6g, static map = %.6g', Ta_sim(end), TaStatic);

fprintf(['[%s] TEST PASS: table (dead band, monotone, slope <= %g, ends at T_a,max) OK; lead coefficients = Tustin; ' ...
    'T_a matches the independent map + lead stage at %d samples (max err %.2g); ' ...
    'steady T_a = static map (%.4f N.m)\n'], modelFileName, raw.Kmax.value, N, err3, TaStatic);

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_map_Ts test_map_v');
end

%% ===================== Utility functions =====================
function subPath = findRootSubsystem(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - ports are found BY
% NAME, never by assumed order.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    for type = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', type{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
