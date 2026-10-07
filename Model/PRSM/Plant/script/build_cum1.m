%% build_cum1.m
% Use the Simulink API to build Cluster 1 (steering column, WITH torsion
% spring, two inertias) as its own subsystem, saved as SteeringColumn.mdl
% RIGHT INSIDE the Plant/ folder (parent of this script) - the "_s" suffix
% distinguishes it from the hand-formatted version (SteeringColumn.mdl,
% same folder). Matches Documents/Cum1_CEPS.txt, with the driver's
% STEERING WHEEL ANGLE theta1 as the ONLY steering input (Lee 2018 [1],
% section IV.A: "the steering angle is an input command"; theta1 is what
% the steering angle sensor measures - no angular-velocity sensor exists,
% so theta1_dot / theta1_ddot are NOT inputs):
%
%   Eq.(3) - sensor torque (CV, Blueprint section 1.3):
%     T_s = K*(x1-x3)
%   Eq.(2) - column block (J_col, column/pinion):
%     x3_dot = x4
%     x4_dot = (T_a - T_r + T_s - T_f*tanh(c*x4) - C_col*x4) / J_col
%
% x1=theta1 (steering wheel, INPUT), x3=theta2 (column/pinion, state).
% Why theta1 is the input and not T_d: with the J1 equation
% T_d = J1*x1_ddot + C1*x1_dot + T_s, at rest T_s = T_d, so if T_d were
% prescribed, T_a could not change the CV T_s at steady state. A driver
% holds the ANGLE; the hand torque T_d is the result. With theta1
% prescribed, the J1 equation only DEFINES T_d - it does not feed any other
% equation, and T_d is not controlled or measured - so it is NOT built here
% (J1, C1 do not enter this model).
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"):
%
%   SteeringColumn
%     In : theta1, T_a, T_r
%     Out: T_s, theta2, theta2_dot
%     |
%     +-- Cal T_s   In : theta1, theta2      Out: T_s
%     |             (Eq.(3), hub: Lower depends on it)
%     +-- Lower     In : T_a, T_r, T_s       Out: theta2, theta2_dot
%                   (Eq.(2), column block J_col)
%
%   theta2 and T_s are routed with Goto/From at cluster level.
%
% LAYOUT (CLAUDE.md section 6): Cal T_s in the top band, Lower in the
% bottom band. Inside each subsystem, the main chain is on ONE straight
% horizontal line; secondary terms join that line from below, right next
% to the block that consumes them.
%
% Parameters (K, J_col, C_col, T_f, c) are read from the base workspace -
% run Model/load_plant.m BEFORE building/simulating.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_plant.m')
%   >> build_cum1            % or build_cum1(true) to overwrite


function modelName = build_cum1(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing SteeringColumn.mdl; false: save as SteeringColumn_1, SteeringColumn_2, ... instead

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(fileparts(plantDir));     % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(plantDir, 'SteeringColumn', overwrite);
modelPath = fullfile(plantDir, [modelName '.mdl']);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: SteeringColumn ==================
sub = [modelName '/SteeringColumn'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

% --- Inputs: theta1 feeds Cal T_s (top band), T_a/T_r feed Lower (bottom band) ---
addInport(sub, 'theta1', 1, 40,  60);
addInport(sub, 'T_a',    2, 40, 260);
addInport(sub, 'T_r',    3, 40, 320);

% --- Outputs: T_s from the top band, theta2 group from the bottom band ---
addOutport(sub, 'T_s',        1, 900,  60);
addOutport(sub, 'theta2',     2, 900, 260);
addOutport(sub, 'theta2_dot', 3, 900, 340);

%% ===================== Cal T_s - Eq.(3) ================================
ts = [sub '/Cal T_s'];
createSubsystem(ts);
moveBlock(ts, 420, 60);
buildCalTs(ts);

%% ===================== Lower - Eq.(2), column block J_col ========================
lo = [sub '/Lower'];
createSubsystem(lo);
moveBlock(lo, 420, 260);
buildLower(lo);

%% ===================== Cluster-level wiring ============================
% 1 destination each: wire directly
add_line(sub, 'theta1/1', 'Cal T_s/1', 'autorouting', 'on');
add_line(sub, 'T_a/1',    'Lower/1',   'autorouting', 'on');
add_line(sub, 'T_r/1',    'Lower/2',   'autorouting', 'on');
add_line(sub, 'Lower/2',  'theta2_dot/1', 'autorouting', 'on');

% theta2 (Lower) -> Goto right after Lower ; From near Cal T_s (bottom
% input, joining from below) and near the cluster output
g_th2 = addGoto(sub, 'theta2', 640, 260);
add_line(sub, 'Lower/1', [g_th2 '/1'], 'autorouting', 'on');
f_th2_ts  = addFrom(sub, 'theta2', 320, 120);
add_line(sub, [f_th2_ts '/1'], 'Cal T_s/2', 'autorouting', 'on');
f_th2_out = addFrom(sub, 'theta2', 800, 260);
add_line(sub, [f_th2_out '/1'], 'theta2/1', 'autorouting', 'on');

% T_s (Cal T_s) -> Goto right after Cal T_s ; From near Lower (joins from
% above) and near the cluster output
g_ts = addGoto(sub, 'T_s', 640, 60);
add_line(sub, 'Cal T_s/1', [g_ts '/1'], 'autorouting', 'on');
f_ts_lo  = addFrom(sub, 'T_s', 320, 380);
add_line(sub, [f_ts_lo '/1'], 'Lower/3', 'autorouting', 'on');
f_ts_out = addFrom(sub, 'T_s', 800, 60);
add_line(sub, [f_ts_out '/1'], 'T_s/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

end

%% ===================== Eq.(3): sensor torque (hub) ======================
function buildCalTs(ts)
% T_s = K*(theta1 - theta2)
% Main line: Sum_dTheta -> Prod_Ts -> T_s, all on the same row. K joins
% Prod_Ts from below, right where it is consumed.
    addInport(ts, 'theta1', 1, 40,  60);
    addInport(ts, 'theta2', 2, 40, 160);

    addOutport(ts, 'T_s', 1, 460, 100);

    addSum    (ts, 'Sum_dTheta', '+-', 180, 100);   % theta1 - theta2
    addProduct(ts, 'Prod_Ts',    '**', 300, 100);   % K*(theta1-theta2)

    hK = addConstant(ts, 'K', 300, 220);   % right below Prod_Ts

    add_line(ts, 'theta1/1', 'Sum_dTheta/1', 'autorouting', 'on');
    add_line(ts, 'theta2/1', 'Sum_dTheta/2', 'autorouting', 'on');
    add_line(ts, 'Sum_dTheta/1', 'Prod_Ts/1', 'autorouting', 'on');
    add_line(ts, [hK '/1'],      'Prod_Ts/2', 'autorouting', 'on');
    add_line(ts, 'Prod_Ts/1',    'T_s/1',     'autorouting', 'on');
end

%% ===================== Eq.(2): column block (J_col, column/pinion) ================
function buildLower(lo)
% x4_dot = (T_a - T_r + T_s - T_f*tanh(c*x4) - C_col*x4)/J_col ; x3_dot = x4
% Main line: T_a -> Sum_torque -> Div_x4dot -> Int_x4 -> Int_x3 -> theta2,
% all on the same row (y=60). T_r, T_s join Sum_torque directly (they are
% cluster/Goto inputs already positioned at this subsystem's edge).
% T_f*tanh(c*x4) and C_col*x4 sit below the main line, close to where each
% is consumed. theta2_dot (=x4) is a side output on its own lower row.
    addInport(lo, 'T_a', 1, 40,  60);
    addInport(lo, 'T_r', 2, 40, 120);
    addInport(lo, 'T_s', 3, 40, 180);

    addOutport(lo, 'theta2',     1, 900,  60);
    addOutport(lo, 'theta2_dot', 2, 900, 220);

    addSum    (lo, 'Sum_torque', '+-+--', 420,  60);  % T_a-T_r+T_s-(.)-(.)
    addProduct(lo, 'Div_x4dot',  '*/',    560,  60);  % /J_col
    addIntegrator(lo, 'Int_x4', 640, 60);             % x4 = theta2_dot
    addIntegrator(lo, 'Int_x3', 780, 60);             % x3 = theta2

    hJcol = addConstant(lo, 'J_col', 560, 160);   % right below Div_x4dot

    % T_f*tanh(c*x4) branch, below the main line near where it feeds in
    hc  = addConstant(lo, 'c',   160, 340);
    hTf = addConstant(lo, 'T_f', 300, 300);
    addProduct(lo, 'Prod_cx4',     '**',    220, 320);
    addTrigFcn(lo, 'Trig_tanh_x4', 'tanh',  300, 340);
    addProduct(lo, 'Prod_Tf',      '**',    380, 300);

    % C_col*x4 branch, below the main line near where it feeds in
    hCcol = addConstant(lo, 'C_col', 160, 420);
    addProduct(lo, 'Prod_Ccolx4', '**', 220, 400);

    % x4 feeds Prod_cx4, Prod_Ccolx4 (secondary) and theta2_dot -> Goto/From
    g_x4 = addGoto(lo, 'x4', 680, 60);
    add_line(lo, 'Int_x4/1', [g_x4 '/1'], 'autorouting', 'on');
    f_x4_int = addFrom(lo, 'x4', 720,  60);
    f_x4_c   = addFrom(lo, 'x4', 160, 300);
    f_x4_ccol  = addFrom(lo, 'x4', 160, 380);
    f_x4_out = addFrom(lo, 'x4', 820, 220);

    add_line(lo, [f_x4_c '/1'], 'Prod_cx4/1', 'autorouting', 'on');
    add_line(lo, [hc '/1'],     'Prod_cx4/2', 'autorouting', 'on');
    add_line(lo, 'Prod_cx4/1',  'Trig_tanh_x4/1', 'autorouting', 'on');
    add_line(lo, 'Trig_tanh_x4/1', 'Prod_Tf/1', 'autorouting', 'on');
    add_line(lo, [hTf '/1'],       'Prod_Tf/2', 'autorouting', 'on');

    add_line(lo, [f_x4_ccol '/1'], 'Prod_Ccolx4/1', 'autorouting', 'on');
    add_line(lo, [hCcol '/1'],     'Prod_Ccolx4/2', 'autorouting', 'on');

    add_line(lo, 'T_a/1',       'Sum_torque/1', 'autorouting', 'on');
    add_line(lo, 'T_r/1',       'Sum_torque/2', 'autorouting', 'on');
    add_line(lo, 'T_s/1',       'Sum_torque/3', 'autorouting', 'on');
    add_line(lo, 'Prod_Tf/1',   'Sum_torque/4', 'autorouting', 'on');
    add_line(lo, 'Prod_Ccolx4/1', 'Sum_torque/5', 'autorouting', 'on');

    add_line(lo, 'Sum_torque/1', 'Div_x4dot/1', 'autorouting', 'on');
    add_line(lo, [hJcol '/1'],     'Div_x4dot/2', 'autorouting', 'on');
    add_line(lo, 'Div_x4dot/1',  'Int_x4/1',    'autorouting', 'on');

    add_line(lo, [f_x4_int '/1'], 'Int_x3/1', 'autorouting', 'on');
    add_line(lo, 'Int_x3/1',      'theta2/1', 'autorouting', 'on');
    add_line(lo, [f_x4_out '/1'], 'theta2_dot/1', 'autorouting', 'on');
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
