%% build_smc.m
% Use the Simulink API to build the discrete first-order sliding-mode
% controller with a boundary layer (saturation function sat) as its own
% subsystem, saved as SMC_s.mdl RIGHT INSIDE the SMC/ folder (parent of this
% script). Matches Documents/SMC/DieuKhien_SMC.txt:
%
%   (all inputs sampled by ZOH at Ts = Ts_ctrl)
%   theta1_dot_hat = (theta1 - x_f)/tau_f,  x_f[k+1] = x_f[k] + Ts*theta1_dot_hat[k]
%   s     = theta2_dot - theta1_dot_hat - (lambda/K)*e_T      (no integral action)
%   T_eq  = -T_s + C_col*theta2_dot
%           + J_col*lambda*(theta1_dot_hat - theta2_dot)
%   u_sw  = k_sw*sat(s/Phi),      sat(x) = max(-1, min(1, x))
%   T_a_unsat = T_eq - J_col*u_sw
%   T_a   = max(-T_a,max(v), min(T_a_unsat, T_a,max(v)))   (assist limit, Documents/Ref/ref.txt section 1.5;
%           T_a,max(v) = 1-D table of data/ref.json (field Ta_max), clipped outside 20-100 km/h)
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"):
%
%   SMC
%     In : e_T, T_s, theta1, theta2_dot, v   Out: T_a
%     |
%     +-- theta1_dot_hat   In : theta1                          Out: theta1_dot_hat
%     +-- s                In : theta2_dot, theta1_dot_hat, e_T  Out: s
%     +-- T_eq             In : T_s, theta2_dot, theta1_dot_hat  Out: T_eq
%     +-- u_sw             In : s                               Out: u_sw
%     +-- T_a_max          In : v                               Out: T_a_max
%
%   The sampled inputs and every named quantity are routed with Goto/From.
%
% Parameters (K, J_col, C_col, lambda, tau_f, k_sw, Phi, Ts_ctrl, Tamax_v_bp_ms, Tamax_table) are
% read from the base workspace - run Model/load_smc.m (it also runs
% load_plant, load_ref) BEFORE building.
%
% Usage (run from this folder, SMC/script/):
%   >> run('../../load_smc.m')
%   >> build_smc

modelName = 'SMC_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % SMC/script
ctrlDir   = fileparts(scriptDir);               % SMC/
modelPath = fullfile(ctrlDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: SMC =============================
sub = [modelName '/SMC'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

inNames = {'e_T', 'T_s', 'theta1', 'theta2_dot', 'v'};
for i = 1:numel(inNames)
    y = 60 + 80*(i-1);
    addInport(sub, inNames{i}, i, 40, y);
    addZOH(sub, ['ZOH_' inNames{i}], 120, y);
    g = addGoto(sub, inNames{i}, 200, y);
    add_line(sub, [inNames{i} '/1'], ['ZOH_' inNames{i} '/1'], 'autorouting', 'on');
    add_line(sub, ['ZOH_' inNames{i} '/1'], [g '/1'], 'autorouting', 'on');
end
addOutport(sub, 'T_a', 1, 1500, 220);

%% ----- theta1_dot_hat (filtered derivative of the measured angle) -----
td = [sub '/theta1_dot_hat'];  createSubsystem(td);  moveBlock(td, 420, 400);
buildTheta1DotHat(td);
add_line(sub, [addFrom(sub, 'theta1', 340, 400) '/1'], 'theta1_dot_hat/1', 'autorouting', 'on');
g_tdh = addGoto(sub, 'theta1_dot_hat', 600, 400);
add_line(sub, 'theta1_dot_hat/1', [g_tdh '/1'], 'autorouting', 'on');

%% ----- s (sliding variable) -----
ss = [sub '/s'];  createSubsystem(ss);  moveBlock(ss, 420, 60);
buildS(ss);
add_line(sub, [addFrom(sub, 'theta2_dot',     340,  40) '/1'], 's/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'theta1_dot_hat', 340,  80) '/1'], 's/2', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T',            340, 120) '/1'], 's/3', 'autorouting', 'on');

%% ----- u_sw (switching term with boundary layer) -----
us = [sub '/u_sw'];  createSubsystem(us);  moveBlock(us, 720, 60);
buildUsw(us);
g_s = addGoto(sub, 's', 600, 60);
add_line(sub, 's/1', [g_s '/1'], 'autorouting', 'on');
add_line(sub, [addFrom(sub, 's', 660, 60) '/1'], 'u_sw/1', 'autorouting', 'on');

%% ----- T_eq (equivalent control from the known column model) -----
te = [sub '/T_eq'];  createSubsystem(te);  moveBlock(te, 720, 240);
buildTeq(te);
add_line(sub, [addFrom(sub, 'T_s',            640, 220) '/1'], 'T_eq/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'theta2_dot',     640, 260) '/1'], 'T_eq/2', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'theta1_dot_hat', 640, 300) '/1'], 'T_eq/3', 'autorouting', 'on');

%% ----- T_a_unsat = T_eq - J_col*u_sw -----
addProduct(sub, 'Prod_Jusw', '**', 900, 70);   % J_col*u_sw
hJ = addConstant(sub, 'J_col', 860, 150);       % right below Prod_Jusw
addSum(sub, 'Sum_Ta_unsat', '+-', 1000, 220);
add_line(sub, 'u_sw/1',        'Prod_Jusw/1',    'autorouting', 'on');
add_line(sub, [hJ '/1'],       'Prod_Jusw/2',    'autorouting', 'on');
add_line(sub, 'T_eq/1',        'Sum_Ta_unsat/1', 'autorouting', 'on');
add_line(sub, 'Prod_Jusw/1',   'Sum_Ta_unsat/2', 'autorouting', 'on');

%% ----- assist limit T_a,max(v) -----
taMax = [sub '/T_a_max']; createSubsystem(taMax); moveBlock(taMax, 720, 480); buildTamax(taMax);
add_line(sub, [addFrom(sub, 'v', 640, 480) '/1'], 'T_a_max/1', 'autorouting', 'on');
g_max = addGoto(sub, 'T_a_max', 900, 480);
add_line(sub, 'T_a_max/1', [g_max '/1'], 'autorouting', 'on');
f_max1 = addFrom(sub, 'T_a_max', 1100, 300);
f_max2 = addFrom(sub, 'T_a_max', 1100, 380);
addMinMax(sub, 'Min_Ta', 'min', 1200, 220);
add_line(sub, 'Sum_Ta_unsat/1', 'Min_Ta/1', 'autorouting', 'on');
add_line(sub, [f_max1 '/1'],    'Min_Ta/2', 'autorouting', 'on');
hNeg = addConstant(sub, '-1', 1200, 440);
addProduct(sub, 'Prod_Tamin', '**', 1280, 380);   % -T_a_max
add_line(sub, [f_max2 '/1'], 'Prod_Tamin/1', 'autorouting', 'on');
add_line(sub, [hNeg '/1'],   'Prod_Tamin/2', 'autorouting', 'on');
addMinMax(sub, 'Max_Ta', 'max', 1380, 250);
add_line(sub, 'Min_Ta/1',     'Max_Ta/1', 'autorouting', 'on');
add_line(sub, 'Prod_Tamin/1', 'Max_Ta/2', 'autorouting', 'on');
add_line(sub, 'Max_Ta/1',     'T_a/1',    'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

%% ===================== theta1_dot_hat = (theta1 - x_f)/tau_f ============
function buildTheta1DotHat(sys)
% Main line: theta1 -> Sum_th1x -> Div_th1dot -> out; filter state x_f
% (Int_xf fed by the output) joins Sum_th1x from below via Goto/From.
    addInport(sys, 'theta1', 1, 40, 60);
    addOutport(sys, 'theta1_dot_hat', 1, 460, 70);
    addSum    (sys, 'Sum_th1x',   '+-', 140, 70);   % theta1 - x_f
    addProduct(sys, 'Div_th1dot', '*/', 260, 70);   % /tau_f
    htf = addConstant(sys, 'tau_f', 220, 160);      % right below Div_th1dot
    g_o = addGoto(sys, 'theta1_dot_hat', 340, 70);
    f_o = addFrom(sys, 'theta1_dot_hat', 380, 70);
    f_i = addFrom(sys, 'theta1_dot_hat', 140, 240);
    addDiscreteIntegrator(sys, 'Int_xf', 220, 240);
    g_x = addGoto(sys, 'x_f', 300, 240);
    f_x = addFrom(sys, 'x_f', 60, 120);
    add_line(sys, 'theta1/1',     'Sum_th1x/1',   'autorouting', 'on');
    add_line(sys, [f_x '/1'],     'Sum_th1x/2',   'autorouting', 'on');
    add_line(sys, 'Sum_th1x/1',   'Div_th1dot/1', 'autorouting', 'on');
    add_line(sys, [htf '/1'],     'Div_th1dot/2', 'autorouting', 'on');
    add_line(sys, 'Div_th1dot/1', [g_o '/1'],     'autorouting', 'on');
    add_line(sys, [f_o '/1'],     'theta1_dot_hat/1', 'autorouting', 'on');
    add_line(sys, [f_i '/1'],     'Int_xf/1',     'autorouting', 'on');
    add_line(sys, 'Int_xf/1',     [g_x '/1'],     'autorouting', 'on');
end

%% ===================== s = theta2_dot - theta1_dot_hat - (lambda/K)*e_T ==
function buildS(sys)
    addInport(sys, 'theta2_dot',     1, 40,  60);
    addInport(sys, 'theta1_dot_hat', 2, 40, 120);
    addInport(sys, 'e_T',            3, 40, 260);
    addOutport(sys, 's', 1, 960, 90);
    hlam = addConstant(sys, 'lambda', 120, 180);
    hK   = addConstant(sys, 'K', 120, 320);
    addProduct(sys, 'Div_lamK',  '*/', 200, 200);   % lambda/K
    addProduct(sys, 'Prod_lamKe', '**', 320, 240);  % (lambda/K)*e_T
    addSum(sys, 'Sum_s', '+--', 440, 90);
    add_line(sys, [hlam '/1'],       'Div_lamK/1',   'autorouting', 'on');
    add_line(sys, [hK '/1'],         'Div_lamK/2',   'autorouting', 'on');
    add_line(sys, 'Div_lamK/1',      'Prod_lamKe/1', 'autorouting', 'on');
    add_line(sys, 'e_T/1',           'Prod_lamKe/2', 'autorouting', 'on');
    add_line(sys, 'theta2_dot/1',    'Sum_s/1',     'autorouting', 'on');
    add_line(sys, 'theta1_dot_hat/1','Sum_s/2',     'autorouting', 'on');
    add_line(sys, 'Prod_lamKe/1',    'Sum_s/3',     'autorouting', 'on');
    add_line(sys, 'Sum_s/1', 's/1', 'autorouting', 'on');
end

%% ===================== u_sw = k_sw*sat(s/Phi) ============================
function buildUsw(sys)
% Main line: s -> Div_sPhi -> Sat_sPhi -> Prod_ksat -> u_sw. Phi and k_sw
% join right below the block that consumes them.
    addInport(sys, 's', 1, 40, 60);
    addOutport(sys, 'u_sw', 1, 460, 70);
    hPhi = addConstant(sys, 'Phi',  160, 140);   % right below Div_sPhi
    hk   = addConstant(sys, 'k_sw', 360, 140);   % right below Prod_ksat
    addProduct(sys, 'Div_sPhi',  '*/', 140, 70);   % s/Phi
    addSaturationBlock(sys, 'Sat_sPhi', 250, 70);  % sat(.) in [-1, 1]
    addProduct(sys, 'Prod_ksat', '**', 340, 70);   % k_sw*sat(s/Phi)
    add_line(sys, 's/1',          'Div_sPhi/1',  'autorouting', 'on');
    add_line(sys, [hPhi '/1'],    'Div_sPhi/2',  'autorouting', 'on');
    add_line(sys, 'Div_sPhi/1',   'Sat_sPhi/1',  'autorouting', 'on');
    add_line(sys, 'Sat_sPhi/1',   'Prod_ksat/1', 'autorouting', 'on');
    add_line(sys, [hk '/1'],      'Prod_ksat/2', 'autorouting', 'on');
    add_line(sys, 'Prod_ksat/1',  'u_sw/1',      'autorouting', 'on');
end

%% ===================== T_eq (known linear column model) ===================
function buildTeq(sys)
% T_eq = -T_s + C_col*theta2_dot + J_col*lambda*(theta1_dot_hat - theta2_dot)
% Dry friction T_f*tanh(c*theta2_dot) is NOT compensated: sampled at Ts_ctrl
% with c = 100 it caused a limit cycle; it is left to the switching term
% (boundary layer) as a bounded disturbance (Documents/SMC/DieuKhien_SMC.txt).
    addInport(sys, 'T_s',            1, 40,  40);
    addInport(sys, 'theta2_dot',     2, 40, 180);
    addInport(sys, 'theta1_dot_hat', 3, 40, 340);
    addOutport(sys, 'T_eq', 1, 720, 180);

    g_w = addGoto(sys, 'theta2_dot', 100, 180);
    add_line(sys, 'theta2_dot/1', [g_w '/1'], 'autorouting', 'on');

    % damping row
    hC = addConstant(sys, 'C_col', 360, 140);
    addProduct(sys, 'Prod_Ccol', '**', 400, 180);
    add_line(sys, [addFrom(sys, 'theta2_dot', 300, 180) '/1'], 'Prod_Ccol/1', 'autorouting', 'on');
    add_line(sys, [hC '/1'], 'Prod_Ccol/2', 'autorouting', 'on');

    % inertia/sliding row
    addSum(sys, 'Sum_dth', '+-', 200, 340);   % theta1_dot_hat - theta2_dot
    hJ   = addConstant(sys, 'J_col',  320, 400);
    hlam = addConstant(sys, 'lambda', 320, 440);
    addProduct(sys, 'Prod_Jlam', '***', 400, 340);
    add_line(sys, 'theta1_dot_hat/1', 'Sum_dth/1', 'autorouting', 'on');
    add_line(sys, [addFrom(sys, 'theta2_dot', 140, 380) '/1'], 'Sum_dth/2', 'autorouting', 'on');
    add_line(sys, 'Sum_dth/1', 'Prod_Jlam/1', 'autorouting', 'on');
    add_line(sys, [hJ '/1'],   'Prod_Jlam/2', 'autorouting', 'on');
    add_line(sys, [hlam '/1'], 'Prod_Jlam/3', 'autorouting', 'on');

    addSum(sys, 'Sum_Teq', '-++', 600, 180);
    add_line(sys, 'T_s/1',       'Sum_Teq/1', 'autorouting', 'on');
    add_line(sys, 'Prod_Ccol/1', 'Sum_Teq/2', 'autorouting', 'on');
    add_line(sys, 'Prod_Jlam/1', 'Sum_Teq/3', 'autorouting', 'on');
    add_line(sys, 'Sum_Teq/1',   'T_eq/1',    'autorouting', 'on');
end

%% ===================== T_a_max(v) = assist limit table =====================
function buildTamax(sys)
% Read from the base workspace: Tamax_v_bp_ms [m/s], Tamax_table [N.m] (loaded by load_ref.m from data/ref.json, field Ta_max).
    addInport(sys, 'v', 1, 40, 60);
    addOutport(sys, 'T_a_max', 1, 300, 60);
    addLookup1D(sys, 'Lookup_Tamax', 140, 60);
    add_line(sys, 'v/1',            'Lookup_Tamax/1', 'autorouting', 'on');
    add_line(sys, 'Lookup_Tamax/1', 'T_a_max/1',      'autorouting', 'on');
end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
% Move a block to (x,y), KEEPING its default size.
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function createSubsystem(path)
% Create an empty Subsystem (removes the default In1->Out1 pair).
    add_block('simulink/Ports & Subsystems/Subsystem', path);
    delete_line(path, 'In1/1', 'Out1/1');
    delete_block([path '/In1']);
    delete_block([path '/Out1']);
end

function addInport(sys, name, port, x, y)
% Ports keep MEANINGFUL names - they ARE the physical variable name and are
% looked up by name in test_*.m.
    full = [sys '/' name];
    add_block('simulink/Sources/In1', full);
    set_param(full, 'Port', num2str(port));
    moveBlock(full, x, y);
end

function addOutport(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sinks/Out1', full);
    set_param(full, 'Port', num2str(port));
    moveBlock(full, x, y);
end

function nm = addConstant(sys, baseWorkspaceVar, x, y)
% Constant block, DEFAULT name (Constant, Constant1, ...); Value points
% STRAIGHT to a base-workspace variable name (or a literal such as '3').
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'Value', baseWorkspaceVar);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addGoto(sys, tag, x, y)
% Goto block, DEFAULT name; LOCAL scope only. tag is the plain variable
% name, no suffix.
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addFrom(sys, tag, x, y)
% From block, DEFAULT name.
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, inputsStr, x, y)
% Prod_<result or operands>, Div_<result> (Inputs='*/').
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addTrigFcn(sys, name, op, x, y)
% Trig_<function>_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Trigonometric Function', full);
    set_param(full, 'Operator', op);
    moveBlock(full, x, y);
end

function addSignBlock(sys, name, x, y)
% Sign_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sign', full);
    moveBlock(full, x, y);
end

function addIntegrator(sys, name, x, y)
% Int_<state variable>
    full = [sys '/' name];
    add_block('simulink/Continuous/Integrator', full);
    moveBlock(full, x, y);
end

function addDiscreteIntegrator(sys, name, x, y)
% Int_<state>: Discrete-Time Integrator, Forward Euler, sample time Ts_ctrl
% (base workspace). y[k] = x[k], x[k+1] = x[k] + Ts_ctrl*u[k].
    full = [sys '/' name];
    add_block('simulink/Discrete/Discrete-Time Integrator', full);
    set_param(full, 'IntegratorMethod', 'Integration: Forward Euler', ...
        'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addZOH(sys, name, x, y)
% ZOH_<signal>: samples a continuous plant signal at Ts_ctrl (ECU input).
    full = [sys '/' name];
    add_block('simulink/Discrete/Zero-Order Hold', full);
    set_param(full, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end



function addSaturationBlock(sys, name, x, y)
% Sat_<argument>: saturation to [-1, 1] (used as sat(s/Phi)).
    full = [sys '/' name];
    add_block('simulink/Discontinuities/Saturation', full);
    set_param(full, 'UpperLimit', '1', 'LowerLimit', '-1');
    moveBlock(full, x, y);
end

function addMinMax(sys, name, fcn, x, y)
% Min_<result> / Max_<result>: 2-input MinMax block (fcn = 'min' or 'max')
    full = [sys '/' name];
    add_block('simulink/Math Operations/MinMax', full);
    set_param(full, 'Function', fcn, 'Inputs', '2');
    moveBlock(full, x, y);
end

function addLookup1D(sys, name, x, y)
% Lookup_<result>: 1-D n-D Lookup Table on the base-workspace variables
% Tamax_v_bp_ms (speed [m/s]) and Tamax_table (T_a,max [N.m]); linear
% interpolation, clipped outside the breakpoints.
    full = [sys '/' name];
    add_block('simulink/Lookup Tables/n-D Lookup Table', full);
    set_param(full, 'NumberOfTableDimensions', '1', ...
        'BreakpointsForDimension1', 'Tamax_v_bp_ms', ...
        'Table', 'Tamax_table', ...
        'InterpMethod', 'Linear point-slope', ...
        'ExtrapMethod', 'Clip');
    moveBlock(full, x, y);
end
