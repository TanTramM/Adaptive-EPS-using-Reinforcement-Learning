function test_pi_s()
%test_pi_s Verify PI_2K_s.mdl (the PI controller of the PRSM loop, auto-built by build_pi.m).
%
%   Requires the root subsystem to expose ports named:  In: T_s, a_y, v, T_a_lim | Out: T_a.
%
%   Everything is recomputed INDEPENDENTLY from data/pi_2k.json and data/ref.json (run load_pi_2k first - the blocks read the base workspace):
%   (1) Simulation: T_s(t) (sine sweep plus offsets), a_y(t) (slow sine, both signs) and v(t) (ramp 10 -> 110 km/h) held between samples;
%       the harness feeds T_a back through a saturation of +-Lim into T_a_lim (the Actuator does this in the closed loop). At every sample
%         e[k]      = T_s[k] - T_d,ref(v[k], a_y[k])        (T_d,ref = sgn(a_y) * interp2(fine table, v, |a_y|))
%         T_a[k]    = Kp*e[k] + u_I[k],   u_I[k+1] = u_I[k] + Ts*(Ki*e[k] + Kaw*(sat(T_a[k]) - T_a[k])),   Kaw = Ki/Kp
%       computed with a plain loop here.
%   (2) Anti-windup: during a long hold with e constant and the command above the limit, u_I settles at Lim (not growing), so
%       T_a = Lim + Kp*e.

modelFileName = 'PI_s';

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
ctrlDir   = fileparts(scriptDir);               % PI/
modelDir  = fileparts(ctrlDir);                 % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'pi_2k.json')));
Ts = raw.Ts_ctrl.value;
Kp_sched = raw.Kp.value(:);
Ki_sched = raw.Ki.value(:);
v_sched = raw.v_breakpoints_kmh.value(:) / 3.6;
Kaw_sched = Ki_sched ./ Kp_sched;
rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
vBp  = rawRef.fine.v_breakpoints_kmh(:)' / 3.6;
ayBp = rawRef.fine.ay_breakpoints_g(:)' * 9.81;
tab  = rawRef.fine.table_Nm';          % row = v, column = a_y
Lim  = 1.5;                            % harness assist limit [N.m]

% ---- input sequence ----
N1 = 5000; N2 = 1500;
k1 = (0:N1-1)';
Tsin = 3 * sin(2*pi*(0.2 + 0.8*k1/N1) .* k1 * Ts) + 1.0 * sign(sin(2*pi*0.7*k1*Ts));
ain  = 4 * sin(2*pi*0.3*k1*Ts);
vin  = (10 + 100 * k1 / N1) / 3.6;
Tsin = [Tsin; 4 * ones(N2, 1)]; ain = [ain; zeros(N2, 1)]; vin = [vin; 50 / 3.6 * ones(N2, 1)];
N = numel(Tsin);
tIn = [0; ((1:N-1)' - 0.5) * Ts];
assignin('base', 'test_pi_Ts', [tIn Tsin]);
assignin('base', 'test_pi_ay', [tIn ain]);
assignin('base', 'test_pi_v',  [tIn vin]);

if bdIsLoaded(modelFileName), close_system(modelFileName, 0); end
load_system(fullfile(ctrlDir, [modelFileName '.mdl']));
dut = findRootSubsystem(modelFileName);

harnessName = 'test_pi_s_harness';
if bdIsLoaded(harnessName), close_system(harnessName, 0); end
new_system(harnessName);
open_system(harnessName);
add_block(dut, [harnessName '/DUT']);
d = [harnessName '/DUT'];
names = {'Ts_in', 'ay_in', 'v_in'}; vars = {'test_pi_Ts', 'test_pi_ay', 'test_pi_v'}; ports = {'T_s', 'a_y', 'v'};
for i = 1:3
    add_block('simulink/Sources/From Workspace', [harnessName '/' names{i}]);
    set_param([harnessName '/' names{i}], 'VariableName', vars{i}, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_line(harnessName, [names{i} '/1'], portRef(d, ports{i}));
end
add_block('simulink/Discontinuities/Saturation', [harnessName '/Sat_Ta'], 'UpperLimit', num2str(Lim), 'LowerLimit', num2str(-Lim));
add_line(harnessName, portRef(d, 'T_a'), 'Sat_Ta/1');
add_line(harnessName, 'Sat_Ta/1', portRef(d, 'T_a_lim'));
add_block('simulink/Sinks/To Workspace', [harnessName '/Ta_out']);
set_param([harnessName '/Ta_out'], 'VariableName', 'Ta_log', 'SaveFormat', 'Array', 'SampleTime', 'Ts_ctrl');
add_line(harnessName, portRef(d, 'T_a'), 'Ta_out/1');
set_param(harnessName, 'StopTime', sprintf('%.15g', (N-1)*Ts), 'Solver', 'ode1', 'FixedStep', sprintf('%.15g', Ts/2));
simOut = sim(harnessName);
Ta_sim = simOut.get('Ta_log');
assert(numel(Ta_sim) >= N, 'Expected %d samples, got %d', N, numel(Ta_sim));
Ta_sim = Ta_sim(1:N);

% ---- (1) independent computation ----
vc = min(max(vin, vBp(1)), vBp(end));
ac = min(abs(ain), ayBp(end));
Td = sign(ain) .* interp2(ayBp, vBp, tab, ac, vc, 'linear');
e = Tsin - Td;
uI = 0; Ta_ref = zeros(N, 1); nSat = 0;
for k = 1:N
    v_k = vin(k);
    v_clip = min(max(v_k, v_sched(1)), v_sched(end));
    Kp = interp1(v_sched, Kp_sched, v_clip, 'linear');
    Ki = interp1(v_sched, Ki_sched, v_clip, 'linear');
    Kaw = interp1(v_sched, Kaw_sched, v_clip, 'linear');
    Ta = Kp * e(k) + uI;
    Ta_ref(k) = Ta;
    Tl = min(max(Ta, -Lim), Lim);
    nSat = nSat + (Tl ~= Ta);
    uI = uI + Ts * (Ki * e(k) + Kaw * (Tl - Ta));
end
err1 = max(abs(Ta_sim - Ta_ref));
assert(err1 < 1e-9, '(1) T_a differs from the independent computation: max err %.3g', err1);
assert(nSat > 100, '(1) the limit was active at only %d samples: the anti-windup path is not exercised', nSat);

% ---- (2) anti-windup equilibrium during the hold ----
Kp_end = interp1(v_sched, Kp_sched, min(max(vin(end), v_sched(1)), v_sched(end)), 'linear');
Ta_eq = Lim + Kp_end * 4;
assert(abs(Ta_sim(end) - Ta_eq) < 1e-6, '(2) T_a after the saturated hold = %.6g, expected Lim + Kp*e = %.6g', Ta_sim(end), Ta_eq);

fprintf(['[%s] TEST PASS: T_a matches the independent PI (e = T_s - T_d,ref from ref.json, Forward Euler integral, back-calculation anti-windup) ' ...
    'at %d samples (max err %.2g, limit active at %d samples); saturated hold T_a = Lim + Kp*e = %.4f N.m\n'], modelFileName, N, err1, nSat, Ta_eq);

close_system(harnessName, 0);
close_system(modelFileName, 0);
evalin('base', 'clear test_pi_Ts test_pi_ay test_pi_v');
end

%% ===================== Utility functions =====================
function subPath = findRootSubsystem(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - ports are found BY NAME.
    parts = strsplit(subPath, '/');
    for type = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', type{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
