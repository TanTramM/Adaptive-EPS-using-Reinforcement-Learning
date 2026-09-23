function test_cum1_s()
%TEST_CUM1_S Verify the SteeringColumn_s.mdl model (Cluster 1, auto-built
%by build_cum1.m - WITH torsion spring, two inertias).
%
%   Requires the root subsystem to expose ports named:
%   In: T_d, T_a, T_r | Out: theta1, theta1_dot, theta2, theta2_dot, T_s.
%
%   Applies a T_d step, T_a=0, T_r=0, and simulates. WITH T_a=T_r=0, the
%   system does NOT settle at a fixed ANGLE (nothing holds either mass
%   still) - instead both masses converge to the SAME steady ANGULAR
%   VELOCITY omega (rotating together, with a constant angle offset
%   theta1-theta2). Steady-state condition (set x2=x4=omega, all
%   derivatives=0, in Eq.(1),(2) of Documents/Cum1_CEPS.txt, cancelling
%   the K*(x1-x3) term between the two equations):
%
%     (C1+C2)*omega + T_f*tanh(c*omega) = T_d          (same form as the
%                                                        old rigid-shaft
%                                                        model, B_total=C1+C2)
%     T_s_ss = T_d - C1*omega   (= C2*omega + T_f*tanh(c*omega), the two
%                                 ways of computing it must agree - self
%                                 checked below)

modelFileName = 'SteeringColumn_s';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = findRootSubsystem(modelFileName);

harnessName = 'test_cum1_s_harness';
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

% MaxStep is REQUIRED: the default variable-step solver picks steps too
% large once the system has settled, interacting badly with the steep
% tanh(c*x4) term (c=100) - this distorts logged data (looks like a slow,
% undamped oscillation, but is NOT real physics - verified: forcing
% MaxStep=0.01 makes it converge EXACTLY to the analytic value from t~3s
% onward, staying perfectly stable).
set_param(harnessName, 'StopTime', '6', 'MaxStep', '0.01');
simOut = sim(harnessName);

theta1_log = simOut.get('theta1_log');
theta1_dot_log = simOut.get('theta1_dot_log');
theta2_dot_log = simOut.get('theta2_dot_log');
Ts_log = simOut.get('Ts_log');

assert(~any(isnan(theta1_log.Data)), 'theta1 contains NaN');
assert(~any(isnan(theta1_dot_log.Data)), 'theta1_dot contains NaN');
assert(~any(isnan(theta2_dot_log.Data)), 'theta2_dot contains NaN');
assert(~any(isnan(Ts_log.Data)), 'T_s contains NaN');
assert(theta1_log.Data(end) > 0, 'theta1 expected > 0 (positive Td step)');

C1 = evalin('base', 'C1');
C2 = evalin('base', 'C2');
T_f = evalin('base', 'T_f');
c  = evalin('base', 'c');
Td_final = 3;

omega_ref = fzero(@(w) (C1+C2)*w + T_f*tanh(c*w) - Td_final, 0.5);
Ts_ref = Td_final - C1*omega_ref;
Ts_ref_check = C2*omega_ref + T_f*tanh(c*omega_ref);
assert(abs(Ts_ref - Ts_ref_check) < 1e-9, ...
    'Internal error: the 2 ways of computing Ts_ref disagree (%.6g vs %.6g)', Ts_ref, Ts_ref_check);

assert(abs(theta1_dot_log.Data(end) - omega_ref) < 1e-3, ...
    'theta1_dot steady state does not match analytic solution (model=%.6g, analytic=%.6g)', ...
    theta1_dot_log.Data(end), omega_ref);
assert(abs(theta2_dot_log.Data(end) - omega_ref) < 1e-3, ...
    'theta2_dot steady state does not match analytic solution (model=%.6g, analytic=%.6g)', ...
    theta2_dot_log.Data(end), omega_ref);
assert(abs(Ts_log.Data(end) - Ts_ref) < 1e-3, ...
    'T_s steady state does not match analytic solution (model=%.6g, analytic=%.6g)', ...
    Ts_log.Data(end), Ts_ref);

fprintf(['[%s] TEST PASS: omega(end)=%.6g rad/s (analytic=%.6g), ' ...
    'T_s(end)=%.6g N.m (analytic=%.6g)\n'], ...
    modelFileName, theta1_dot_log.Data(end), omega_ref, Ts_log.Data(end), Ts_ref);

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
