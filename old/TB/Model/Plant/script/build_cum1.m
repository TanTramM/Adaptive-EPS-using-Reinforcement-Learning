%% build_cum1.m
% Use the Simulink API to build Cluster 1 (steering column, WITH torsion
% spring, two inertias) as its own subsystem, saved as SteeringColumn_s.mdl
% RIGHT INSIDE the Plant/ folder (parent of this script) - the "_s" suffix
% distinguishes it from the hand-formatted version (SteeringColumn.mdl,
% same folder). Matches Documents/Cum1_CEPS.txt:
%
%   Eq.(3) - sensor torque (CV, Blueprint section 1.3):
%     T_s = K*(x1-x3)
%   Eq.(1) - J1 block (steering wheel):
%     x1_dot = x2
%     x2_dot = (T_d - T_s - C1*x2) / J1
%   Eq.(2) - J2 block (column/pinion):
%     x3_dot = x4
%     x4_dot = (T_a - T_r + T_s - T_f*tanh(c*x4) - C2*x4) / J2
%
% x1=theta1 (steering wheel), x3=theta2 (column/pinion). T_s is DIFFERENT
% from T_d (driver hand torque, exogenous, not measurable - see
% Cum1_CEPS.txt header).
%
% NOTE ON THE SPRING TERM: Cum1_CEPS.txt writes the spring term as
% -K*(x1-x3) in Eq.(1) and -K*(x3-x1) in Eq.(2). Since T_s = K*(x1-x3),
% those are exactly -T_s and +T_s. Factoring T_s out into its own subsystem
% (instead of computing K*(x1-x3) twice) follows the "one subsystem per
% NAMED quantity" rule - T_s is a named quantity (it IS the CV).
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   SteeringColumn
%     In : T_d, T_a, T_r
%     Out: theta1, theta1_dot, theta2, theta2_dot, T_s
%     |
%     +-- Cal T_s   In : theta1, theta2      Out: T_s
%     |             (sits BETWEEN Upper and Lower - a hub both depend on,
%     |              same role as D/B sitting above Cal F_yf/Cal F_yr in
%     |              Tires.mdl)
%     +-- Upper     In : T_d, T_s            Out: theta1, theta1_dot
%     |             (Eq.(1), J1 block)
%     +-- Lower     In : T_a, T_r, T_s       Out: theta2, theta2_dot
%                   (Eq.(2), J2 block)
%
%   theta1, theta2, T_s are routed with Goto/From at cluster level.
%
% LAYOUT (CLAUDE.md section 6): Upper occupies the top band, Lower the
% bottom band, Cal T_s sits as a hub between them. Inside each subsystem,
% the main torque-balance -> integrator chain is laid out on ONE straight
% horizontal line; secondary terms (friction, damping, the spring torque
% itself) join that line from below, positioned right next to the block
% that actually consumes them - not forced into a left-hand column.
%
% Parameters (K, J1, C1, J2, C2, T_f, c) are read from the base workspace -
% run Model/load_params.m BEFORE building/simulating.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum1

modelName = 'SteeringColumn_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelPath = fullfile(plantDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: SteeringColumn ==================
sub = [modelName '/SteeringColumn'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

% --- Inputs: T_d feeds Upper (top band), T_a/T_r feed Lower (bottom band) ---
addInport(sub, 'T_d', 1,  40,  60);
addInport(sub, 'T_a', 2,  40, 460);
addInport(sub, 'T_r', 3,  40, 520);

% --- Outputs: grouped by which band produces them; T_s (the hub output)
% sits between the two bands, matching Cal T_s's own position ---
addOutport(sub, 'theta1',     1, 900,  60);
addOutport(sub, 'theta1_dot', 2, 900, 140);
addOutport(sub, 'T_s',        3, 900, 300);
addOutport(sub, 'theta2',     4, 900, 460);
addOutport(sub, 'theta2_dot', 5, 900, 540);

%% ===================== Cal T_s - Eq.(3), the hub =======================
% Vertically centered between Upper and Lower: it consumes theta1 (from
% Upper, above) and theta2 (from Lower, below), and feeds T_s back to both.
ts = [sub '/Cal T_s'];
createSubsystem(ts);
moveBlock(ts, 420, 260);
buildCalTs(ts);

%% ===================== Upper - Eq.(1), J1 block (top band) =============
up = [sub '/Upper'];
createSubsystem(up);
moveBlock(up, 420, 60);
buildUpper(up);

%% ===================== Lower - Eq.(2), J2 block (bottom band) ==========
lo = [sub '/Lower'];
createSubsystem(lo);
moveBlock(lo, 420, 460);
buildLower(lo);

%% ===================== Cluster-level wiring ============================
% Straight into each subsystem's primary input (same row as the block)
add_line(sub, 'T_d/1', 'Upper/1', 'autorouting', 'on');
add_line(sub, 'T_a/1', 'Lower/1', 'autorouting', 'on');
add_line(sub, 'T_r/1', 'Lower/2', 'autorouting', 'on');

% theta1 (Upper) -> Goto right after Upper ; From near Cal T_s (its top
% input, joining from above) and near the cluster output
g_th1 = addGoto(sub, 'theta1', 640,  60);
add_line(sub, 'Upper/1', [g_th1 '/1'], 'autorouting', 'on');
f_th1_ts  = addFrom(sub, 'theta1', 320, 240);
add_line(sub, [f_th1_ts '/1'], 'Cal T_s/1', 'autorouting', 'on');
f_th1_out = addFrom(sub, 'theta1', 800,  60);
add_line(sub, [f_th1_out '/1'], 'theta1/1', 'autorouting', 'on');

% theta2 (Lower) -> Goto right after Lower ; From near Cal T_s (its bottom
% input, joining from below) and near the cluster output
g_th2 = addGoto(sub, 'theta2', 640, 460);
add_line(sub, 'Lower/1', [g_th2 '/1'], 'autorouting', 'on');
f_th2_ts  = addFrom(sub, 'theta2', 320, 320);
add_line(sub, [f_th2_ts '/1'], 'Cal T_s/2', 'autorouting', 'on');
f_th2_out = addFrom(sub, 'theta2', 800, 460);
add_line(sub, [f_th2_out '/1'], 'theta2/1', 'autorouting', 'on');

% T_s (Cal T_s) -> Goto right after Cal T_s ; From near Upper (joins its
% torque-sum from below), near Lower (joins from above), and cluster output
g_ts = addGoto(sub, 'T_s', 640, 300);
add_line(sub, 'Cal T_s/1', [g_ts '/1'], 'autorouting', 'on');
f_ts_up  = addFrom(sub, 'T_s', 320, 200);
add_line(sub, [f_ts_up '/1'], 'Upper/2', 'autorouting', 'on');
f_ts_lo  = addFrom(sub, 'T_s', 320, 580);
add_line(sub, [f_ts_lo '/1'], 'Lower/3', 'autorouting', 'on');
f_ts_out = addFrom(sub, 'T_s', 800, 300);
add_line(sub, [f_ts_out '/1'], 'T_s/1', 'autorouting', 'on');

% Rate outputs: 1 destination each, wire directly
add_line(sub, 'Upper/2', 'theta1_dot/1', 'autorouting', 'on');
add_line(sub, 'Lower/2', 'theta2_dot/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

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

%% ===================== Eq.(1): J1 block (steering wheel) ===============
function buildUpper(up)
% x2_dot = (T_d - T_s - C1*x2)/J1 ; x1_dot = x2
% Main line (torque balance -> integrate twice): T_d -> Sum_torque ->
% Div_x2dot -> Int_x2 -> Int_x1 -> theta1, all on the same row (y=60).
% T_s joins Sum_torque from below (secondary input). C1*x2 (feedback
% through the damping term) sits below the main line, close to
% Sum_torque. theta1_dot (=x2) is a side output, placed on its own lower
% row next to where the x2 signal already lives.
    addInport(up, 'T_d', 1, 40,  60);
    addInport(up, 'T_s', 2, 40, 200);

    addOutport(up, 'theta1',     1, 760,  60);
    addOutport(up, 'theta1_dot', 2, 760, 200);

    addSum    (up, 'Sum_torque', '+--', 260,  60);   % T_d - T_s - C1*x2
    addProduct(up, 'Div_x2dot',  '*/',  380,  60);   % /J1
    addIntegrator(up, 'Int_x2', 460, 60);            % x2 = theta1_dot
    addIntegrator(up, 'Int_x1', 600, 60);            % x1 = theta1

    hJ1 = addConstant(up, 'J1', 380, 160);   % right below Div_x2dot
    hC1 = addConstant(up, 'C1', 160, 300);   % right above Prod_C1x2
    addProduct(up, 'Prod_C1x2', '**', 260, 260);     % C1*x2, below main line

    % x2 feeds Prod_C1x2 (secondary) and the theta1_dot output -> Goto/From
    g_x2 = addGoto(up, 'x2', 500, 60);
    add_line(up, 'Int_x2/1', [g_x2 '/1'], 'autorouting', 'on');
    f_x2_int = addFrom(up, 'x2', 540,  60);
    f_x2_c1  = addFrom(up, 'x2', 160, 260);
    f_x2_out = addFrom(up, 'x2', 680, 200);

    add_line(up, 'T_d/1', 'Sum_torque/1', 'autorouting', 'on');
    add_line(up, 'T_s/1', 'Sum_torque/2', 'autorouting', 'on');
    add_line(up, 'Prod_C1x2/1', 'Sum_torque/3', 'autorouting', 'on');

    add_line(up, [f_x2_c1 '/1'], 'Prod_C1x2/1', 'autorouting', 'on');
    add_line(up, [hC1 '/1'],     'Prod_C1x2/2', 'autorouting', 'on');

    add_line(up, 'Sum_torque/1', 'Div_x2dot/1', 'autorouting', 'on');
    add_line(up, [hJ1 '/1'],     'Div_x2dot/2', 'autorouting', 'on');
    add_line(up, 'Div_x2dot/1',  'Int_x2/1',    'autorouting', 'on');

    add_line(up, [f_x2_int '/1'], 'Int_x1/1', 'autorouting', 'on');
    add_line(up, 'Int_x1/1',      'theta1/1', 'autorouting', 'on');
    add_line(up, [f_x2_out '/1'], 'theta1_dot/1', 'autorouting', 'on');
end

%% ===================== Eq.(2): J2 block (column/pinion) ================
function buildLower(lo)
% x4_dot = (T_a - T_r + T_s - T_f*tanh(c*x4) - C2*x4)/J2 ; x3_dot = x4
% Main line: T_a -> Sum_torque -> Div_x4dot -> Int_x4 -> Int_x3 -> theta2,
% all on the same row (y=60). T_r, T_s join Sum_torque directly (they are
% cluster/Goto inputs already positioned at this subsystem's edge).
% T_f*tanh(c*x4) and C2*x4 sit below the main line, close to where each
% is consumed. theta2_dot (=x4) is a side output on its own lower row.
    addInport(lo, 'T_a', 1, 40,  60);
    addInport(lo, 'T_r', 2, 40, 120);
    addInport(lo, 'T_s', 3, 40, 180);

    addOutport(lo, 'theta2',     1, 900,  60);
    addOutport(lo, 'theta2_dot', 2, 900, 220);

    addSum    (lo, 'Sum_torque', '+-+--', 420,  60);  % T_a-T_r+T_s-(.)-(.)
    addProduct(lo, 'Div_x4dot',  '*/',    560,  60);  % /J2
    addIntegrator(lo, 'Int_x4', 640, 60);             % x4 = theta2_dot
    addIntegrator(lo, 'Int_x3', 780, 60);             % x3 = theta2

    hJ2 = addConstant(lo, 'J2', 560, 160);   % right below Div_x4dot

    % T_f*tanh(c*x4) branch, below the main line near where it feeds in
    hc  = addConstant(lo, 'c',   160, 340);
    hTf = addConstant(lo, 'T_f', 300, 300);
    addProduct(lo, 'Prod_cx4',     '**',    220, 320);
    addTrigFcn(lo, 'Trig_tanh_x4', 'tanh',  300, 340);
    addProduct(lo, 'Prod_Tf',      '**',    380, 300);

    % C2*x4 branch, below the main line near where it feeds in
    hC2 = addConstant(lo, 'C2', 160, 420);
    addProduct(lo, 'Prod_C2x4', '**', 220, 400);

    % x4 feeds Prod_cx4, Prod_C2x4 (secondary) and theta2_dot -> Goto/From
    g_x4 = addGoto(lo, 'x4', 680, 60);
    add_line(lo, 'Int_x4/1', [g_x4 '/1'], 'autorouting', 'on');
    f_x4_int = addFrom(lo, 'x4', 720,  60);
    f_x4_c   = addFrom(lo, 'x4', 160, 300);
    f_x4_c2  = addFrom(lo, 'x4', 160, 380);
    f_x4_out = addFrom(lo, 'x4', 820, 220);

    add_line(lo, [f_x4_c '/1'], 'Prod_cx4/1', 'autorouting', 'on');
    add_line(lo, [hc '/1'],     'Prod_cx4/2', 'autorouting', 'on');
    add_line(lo, 'Prod_cx4/1',  'Trig_tanh_x4/1', 'autorouting', 'on');
    add_line(lo, 'Trig_tanh_x4/1', 'Prod_Tf/1', 'autorouting', 'on');
    add_line(lo, [hTf '/1'],       'Prod_Tf/2', 'autorouting', 'on');

    add_line(lo, [f_x4_c2 '/1'], 'Prod_C2x4/1', 'autorouting', 'on');
    add_line(lo, [hC2 '/1'],     'Prod_C2x4/2', 'autorouting', 'on');

    add_line(lo, 'T_a/1',       'Sum_torque/1', 'autorouting', 'on');
    add_line(lo, 'T_r/1',       'Sum_torque/2', 'autorouting', 'on');
    add_line(lo, 'T_s/1',       'Sum_torque/3', 'autorouting', 'on');
    add_line(lo, 'Prod_Tf/1',   'Sum_torque/4', 'autorouting', 'on');
    add_line(lo, 'Prod_C2x4/1', 'Sum_torque/5', 'autorouting', 'on');

    add_line(lo, 'Sum_torque/1', 'Div_x4dot/1', 'autorouting', 'on');
    add_line(lo, [hJ2 '/1'],     'Div_x4dot/2', 'autorouting', 'on');
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
% STRAIGHT to a base-workspace variable name.
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
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, inputsStr, x, y)
% Computation blocks DO get meaningful names: Prod_<result>, Div_<result>.
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

function addIntegrator(sys, name, x, y)
% Int_<state variable>
    full = [sys '/' name];
    add_block('simulink/Continuous/Integrator', full);
    moveBlock(full, x, y);
end
