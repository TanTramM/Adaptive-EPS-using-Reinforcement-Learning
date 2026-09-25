function test_cum2_s()
%TEST_CUM2_S Verify the Tires_s.mdl model (Cluster 2, auto-built by
%build_cum2.m).
%
%   Requires the root subsystem to expose ports named:
%   In: theta2, beta, gamma, v, mu | Out: F_yf, F_yr, T_r.
%
%   Feeds 2 fixed operating points (one with the e_p floor active) and checks F_yf, F_yr, T_r match the
%   analytic formulas (Eq.(1)-(11), Documents/Cum2_Pacejka.txt) EXACTLY
%   (zero error) - this is a pure algebraic block (no state), so a single
%   time step is enough. The analytic reference is computed INDEPENDENTLY
%   here directly from data/params.json (not from base-workspace values
%   such as F_zf, which load_derived.m itself might get wrong).

modelFileName = 'Tires_s';

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));

dut = findRootSubsystem(modelFileName);

harnessName = 'test_cum2_s_harness';
if bdIsLoaded(harnessName)
    close_system(harnessName, 0);
end
new_system(harnessName);
open_system(harnessName);

add_block(dut, [harnessName '/DUT']);
set_param([harnessName '/DUT'], 'Position', [250 100 450 350]);
dutInHarness = [harnessName '/DUT'];

% Two operating points, one row each: [theta2 beta gamma v mu].
%   1: small slip angle - the aligning-torque floor is inactive (e_p > 0);
%   2: large slip angle at low mu - tan(alpha_f) is beyond tan(alpha_sl) =
%      3*mu*F_zf/C_alpha_f, so e_p is floored at 0 and T_r must be exactly 0.
cases = [0.3  0.02  0.1  20  0.6;
         0.8 -0.1   0    20  0.3];
theta2_test = cases(1,1); beta_test = cases(1,2); gamma_test = cases(1,3); v_test = cases(1,4); mu_test = cases(1,5);

add_block('simulink/Sources/Constant', [harnessName '/theta2_in']);
set_param([harnessName '/theta2_in'], 'Value', num2str(theta2_test), 'Position', [50 110 80 130]);
add_block('simulink/Sources/Constant', [harnessName '/beta_in']);
set_param([harnessName '/beta_in'], 'Value', num2str(beta_test), 'Position', [50 160 80 180]);
add_block('simulink/Sources/Constant', [harnessName '/gamma_in']);
set_param([harnessName '/gamma_in'], 'Value', num2str(gamma_test), 'Position', [50 210 80 230]);
add_block('simulink/Sources/Constant', [harnessName '/v_in']);
set_param([harnessName '/v_in'], 'Value', num2str(v_test), 'Position', [50 260 80 280]);
add_block('simulink/Sources/Constant', [harnessName '/mu_in']);
set_param([harnessName '/mu_in'], 'Value', num2str(mu_test), 'Position', [50 310 80 330]);

add_block('simulink/Sinks/To Workspace', [harnessName '/Fyf_out']);
set_param([harnessName '/Fyf_out'], 'VariableName', 'Fyf_log', 'Position', [550 110 620 130]);
add_block('simulink/Sinks/To Workspace', [harnessName '/Fyr_out']);
set_param([harnessName '/Fyr_out'], 'VariableName', 'Fyr_log', 'Position', [550 180 620 200]);
add_block('simulink/Sinks/To Workspace', [harnessName '/Tr_out']);
set_param([harnessName '/Tr_out'], 'VariableName', 'Tr_log', 'Position', [550 250 620 270]);

add_line(harnessName, 'theta2_in/1', portRef(dutInHarness, 'theta2'), 'autorouting', 'on');
add_line(harnessName, 'beta_in/1',  portRef(dutInHarness, 'beta'), 'autorouting', 'on');
add_line(harnessName, 'gamma_in/1', portRef(dutInHarness, 'gamma'), 'autorouting', 'on');
add_line(harnessName, 'v_in/1',     portRef(dutInHarness, 'v'), 'autorouting', 'on');
add_line(harnessName, 'mu_in/1',    portRef(dutInHarness, 'mu'), 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'F_yf'), 'Fyf_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'F_yr'), 'Fyr_out/1', 'autorouting', 'on');
add_line(harnessName, portRef(dutInHarness, 'T_r'),  'Tr_out/1', 'autorouting', 'on');

set_param(harnessName, 'StopTime', '0.1');

% --- Independent reference parameters, read straight from data/params.json ---
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
p2 = raw.cum2;
m_ = p2.m.value; l_f = p2.l_f.value; l_r = p2.l_r.value; g_ = p2.g.value;
C_alpha_f = p2.C_alpha_f.value; C_r = p2.C_r.value;
C_ = p2.C.value; E_ = p2.E.value; n_st = p2.n_st.value; e_p0 = p2.e_p0.value;
F_zf = m_*g_*l_r / (l_f + l_r);
F_zr = m_*g_*l_f / (l_f + l_r);

names = {'theta2_in', 'beta_in', 'gamma_in', 'v_in', 'mu_in'};
tol = 1e-6;
for k = 1:size(cases, 1)
    for j = 1:numel(names)
        set_param([harnessName '/' names{j}], 'Value', sprintf('%.15g', cases(k, j)));
    end
    theta2_test = cases(k,1); beta_test = cases(k,2); gamma_test = cases(k,3); v_test = cases(k,4); mu_test = cases(k,5);

    simOut = sim(harnessName);
    Fyf_sim = simOut.get('Fyf_log').Data(end);
    Fyr_sim = simOut.get('Fyr_log').Data(end);
    Tr_sim  = simOut.get('Tr_log').Data(end);

    delta_f = theta2_test / n_st;
    alpha_f = delta_f - beta_test - l_f*gamma_test/v_test;
    alpha_r = -beta_test + l_r*gamma_test/v_test;

    D = mu_test * F_zf;
    B = C_alpha_f / (C_ * D);
    F_yf_ref = D * sin(C_ * atan(B*alpha_f - E_*(B*alpha_f - atan(B*alpha_f))));
    D_r = mu_test * F_zr;
    B_r = C_r / (C_ * D_r);
    F_yr_ref = D_r * sin(C_ * atan(B_r*alpha_r - E_*(B_r*alpha_r - atan(B_r*alpha_r))));
    assert(abs(F_yr_ref) <= D_r + 1e-9, 'rear force must not exceed mu*F_zr');

    e_p = max(0, e_p0 - sign(alpha_f) * e_p0 * C_alpha_f * tan(alpha_f) / (3*mu_test*F_zf));
    K_tr = e_p / n_st;
    T_r_ref = K_tr * F_yf_ref;

    if k == 1
        assert(e_p > 0, 'case 1 must leave the e_p floor inactive');
    else
        assert(tan(abs(alpha_f)) > 3*mu_test*F_zf/C_alpha_f, 'case 2 must exceed the sliding angle');
        assert(e_p == 0 && T_r_ref == 0, 'case 2 reference must be floored at 0');
    end

    assert(abs(Fyf_sim-F_yf_ref) < tol, 'case %d: F_yf error exceeds tolerance', k);
    assert(abs(Fyr_sim-F_yr_ref) < tol, 'case %d: F_yr error exceeds tolerance', k);
    assert(abs(Tr_sim-T_r_ref) < tol, 'case %d: T_r error exceeds tolerance', k);

    fprintf('[%s] case %d PASS: F_yf=%.8g F_yr=%.8g T_r=%.8g (matches analytic, e_p=%.5g m)\n', ...
        modelFileName, k, Fyf_sim, Fyr_sim, Tr_sim, e_p);
end
fprintf('[%s] TEST PASS (all %d operating points)\n', modelFileName, size(cases, 1));

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
