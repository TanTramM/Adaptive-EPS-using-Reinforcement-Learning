function test_cum3_s()
%TEST_CUM3_S Verify Bike2DOF_s.mdl (Cluster 3, auto-built by build_cum3.m).
%
%   Requires the root subsystem to expose ports named:
%   In: F_yf, F_yr, v | Out: beta, gamma, a_y.
%
%   Feeds CONSTANT F_yf, F_yr, v and compares beta(t), gamma(t) with the
%   analytic solution of the constant-coefficient 2nd-order linear system
%   (expm), a_y with (F_yf+F_yr)/m. Parameters are read INDEPENDENTLY from
%   data/params.json.

modelFileName = 'Bike2DOF_s';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = findRootSubsystem(modelFileName);

harnessName = 'test_cum3_s_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 350]);
dutInHarness = [harnessName '/DUT'];

Fyf_test = -500; Fyr_test = -900; v_test = 20;

add_block('simulink/Sources/Constant', [harnessName '/Fyf_in']);
set_param([harnessName '/Fyf_in'], 'Value', num2str(Fyf_test), 'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/Fyr_in']);
set_param([harnessName '/Fyr_in'], 'Value', num2str(Fyr_test), 'Position', [50 160 80 180]);
add_block('simulink/Sources/Constant', [harnessName '/v_in']);
set_param([harnessName '/v_in'], 'Value', num2str(v_test), 'Position', [50 210 80 230]);

add_block('simulink/Sinks/To Workspace', [harnessName '/beta_out']);
set_param([harnessName '/beta_out'], 'VariableName', 'beta_log', 'Position', [550 110 620 130]);
add_block('simulink/Sinks/To Workspace', [harnessName '/gamma_out']);
set_param([harnessName '/gamma_out'], 'VariableName', 'gamma_log', 'Position', [550 180 620 200]);
add_block('simulink/Sinks/To Workspace', [harnessName '/ay_out']);
set_param([harnessName '/ay_out'], 'VariableName', 'ay_log', 'Position', [550 250 620 270]);

add_line(harnessName, 'Fyf_in/1', portRef(dutInHarness, 'F_yf'), 'autorouting', 'on');
add_line(harnessName, 'Fyr_in/1', portRef(dutInHarness, 'F_yr'), 'autorouting', 'on');
add_line(harnessName, 'v_in/1',   portRef(dutInHarness, 'v'), 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'beta'),  'beta_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'gamma'), 'gamma_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'a_y'),   'ay_out/1', 'autorouting', 'on');

Tstop = 2;
set_param(harnessName, 'StopTime', num2str(Tstop));
simOut = sim(harnessName);

beta_sim  = simOut.get('beta_log');
gamma_sim = simOut.get('gamma_log');
ay_sim    = simOut.get('ay_log');

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
m_ = raw.cum2.m.value; l_f = raw.cum2.l_f.value; l_r = raw.cum2.l_r.value;
Iz = raw.cum3.Iz.value;

Fsum = Fyf_test + Fyr_test;
Bu = [Fsum/(m_*v_test); (l_f*Fyf_test - l_r*Fyr_test)/Iz];
A = [0 -1; 0 0];

x0 = [0; 0];
tVec = beta_sim.Time;
xAnalytic = zeros(numel(tVec), 2);
for k = 1:numel(tVec)
    t = tVec(k);
    xAnalytic(k,:) = ((expm(A*t))*x0 + (t*eye(2) + A*t^2/2)*Bu)';
end
beta_ref  = xAnalytic(:,1);
gamma_ref = xAnalytic(:,2);
ay_ref    = Fsum/m_ * ones(size(tVec));

err_beta  = max(abs(beta_sim.Data - beta_ref));
err_gamma = max(abs(gamma_sim.Data - gamma_ref));
err_ay    = max(abs(ay_sim.Data - ay_ref));

tol = 1e-4;
assert(err_beta < tol, 'beta error exceeds tolerance');
assert(err_gamma < tol, 'gamma error exceeds tolerance');
assert(err_ay < 1e-6, 'a_y error exceeds tolerance');

fprintf('[%s] TEST PASS: beta(end)=%.6g gamma(end)=%.6g a_y=%.6g (matches analytic, error<%.0e)\n', ...
    modelFileName, beta_sim.Data(end), gamma_sim.Data(end), ay_sim.Data(end), tol);

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
