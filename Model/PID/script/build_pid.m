%% build_pid.m
% Use the Simulink API to build the discrete PID controller with the assist
% limit T_a,max(v) and back-calculation anti-windup as its own subsystem,
% saved as PID_s.mdl RIGHT INSIDE the PID/ folder (parent of this script).
% Matches Documents/DieuKhien_PID.txt:
%
%   e[k]      = e_T(k*Ts)                       (ZOH, Ts = Ts_ctrl)
%   u_P[k]    = Kp*e[k]
%   u_I[k+1]  = u_I[k] + Ts*(Ki*e[k] + Kaw*(T_a[k] - T_a,unsat[k]))
%   w[k]      = (e[k] - x[k])/T_filt             (filtered derivative,
%   x[k+1]    = x[k] + Ts*w[k]                    Seborg Eq. 8-12)
%   u_D[k]    = Kd*w[k]
%   T_a,unsat[k] = u_P[k] + u_I[k] + u_D[k]
%   T_a[k]    = max(-T_a,max(v[k]), min(T_a,unsat[k], T_a,max(v[k])))
%
% T_a,max(v) is a 1-D table (Documents/Ref/ref.txt section 1.5, data/ref.json field Ta_max,
% the T_a field), clipped outside 20-100 km/h. The term Kaw*(T_a - T_a,unsat)
% is zero while the command is inside the limits and pulls the integrator
% back while it is saturated (back-calculation anti-windup).
%
% Sign: e_T = T_s - T_d,ref > 0 means the steering is too HEAVY, so more
% assist is needed; the plant gain dT_s/dT_a is negative, hence all gains
% are positive with T_a = +PID(e_T).
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"):
%
%   PID
%     In : e_T, v      Out: T_a
%     |
%     +-- u_P        In : e        Out: u_P
%     +-- u_I        In : e, aw    Out: u_I
%     +-- u_D        In : e        Out: u_D
%     +-- T_a_max    In : v        Out: T_a_max
%
%   e (sampled error), v (sampled speed), T_a_unsat, T_a_max, T_a and aw
%   (anti-windup term) are routed with Goto/From.
%
% Gains (Kp, Ki, Kd, T_filt, Kaw), Ts_ctrl and the T_a,max table
% (Tamax_v_bp_ms, Tamax_table) are read from the base workspace - run
% Model/load_pid.m BEFORE building (it also runs load_plant and load_ref).
%
% Usage (run from this folder, PID/script/):
%   >> run('../../load_pid.m')
%   >> build_pid

modelName = 'PID_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
ctrlDir   = fileparts(scriptDir);               % PID/
modelPath = fullfile(ctrlDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: PID =============================
sub = [modelName '/PID'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'e_T', 1, 40, 200);
addInport(sub, 'v',   2, 40, 560);
addOutport(sub, 'T_a', 1, 1300, 210);

addZOH(sub, 'ZOH_e', 120, 200);
g_e = addGoto(sub, 'e', 200, 200);
add_line(sub, 'e_T/1',   'ZOH_e/1',     'autorouting', 'on');
add_line(sub, 'ZOH_e/1', [g_e '/1'],    'autorouting', 'on');

addZOH(sub, 'ZOH_v', 120, 560);
g_v = addGoto(sub, 'v', 200, 560);
add_line(sub, 'v/1',     'ZOH_v/1',     'autorouting', 'on');
add_line(sub, 'ZOH_v/1', [g_v '/1'],    'autorouting', 'on');

uP = [sub '/u_P'];  createSubsystem(uP);  moveBlock(uP, 400,  60);  buildUP(uP);
uI = [sub '/u_I'];  createSubsystem(uI);  moveBlock(uI, 400, 200);  buildUI(uI);
uD = [sub '/u_D'];  createSubsystem(uD);  moveBlock(uD, 400, 340);  buildUD(uD);

f_e_P = addFrom(sub, 'e', 320,  60);
f_e_I = addFrom(sub, 'e', 320, 200);
f_e_D = addFrom(sub, 'e', 320, 340);
add_line(sub, [f_e_P '/1'], 'u_P/1', 'autorouting', 'on');
add_line(sub, [f_e_I '/1'], 'u_I/1', 'autorouting', 'on');
add_line(sub, [f_e_D '/1'], 'u_D/1', 'autorouting', 'on');

% unsaturated command
addSum(sub, 'Sum_Ta_unsat', '+++', 620, 200);   % u_P + u_I + u_D
add_line(sub, 'u_P/1',          'Sum_Ta_unsat/1', 'autorouting', 'on');
add_line(sub, 'u_I/1',          'Sum_Ta_unsat/2', 'autorouting', 'on');
add_line(sub, 'u_D/1',          'Sum_Ta_unsat/3', 'autorouting', 'on');
g_unsat = addGoto(sub, 'T_a_unsat', 700, 200);
add_line(sub, 'Sum_Ta_unsat/1', [g_unsat '/1'], 'autorouting', 'on');

% assist limit T_a,max(v)
taMax = [sub '/T_a_max']; createSubsystem(taMax); moveBlock(taMax, 400, 560); buildTamax(taMax);
f_v = addFrom(sub, 'v', 320, 560);
add_line(sub, [f_v '/1'], 'T_a_max/1', 'autorouting', 'on');
g_max = addGoto(sub, 'T_a_max', 560, 560);
add_line(sub, 'T_a_max/1', [g_max '/1'], 'autorouting', 'on');

% saturation: T_a = max(-T_a_max, min(T_a_unsat, T_a_max))
f_unsat1 = addFrom(sub, 'T_a_unsat', 800, 200);
f_max1   = addFrom(sub, 'T_a_max',   800, 260);
f_max2   = addFrom(sub, 'T_a_max',   800, 380);
addMinMax(sub, 'Min_Ta', 'min', 900, 210);
add_line(sub, [f_unsat1 '/1'], 'Min_Ta/1', 'autorouting', 'on');
add_line(sub, [f_max1 '/1'],   'Min_Ta/2', 'autorouting', 'on');
hNeg = addConstant(sub, '-1', 900, 440);
addProduct(sub, 'Prod_Tamin', '**', 980, 380);   % -T_a_max
add_line(sub, [f_max2 '/1'], 'Prod_Tamin/1', 'autorouting', 'on');
add_line(sub, [hNeg '/1'],   'Prod_Tamin/2', 'autorouting', 'on');
addMinMax(sub, 'Max_Ta', 'max', 1080, 250);
add_line(sub, 'Min_Ta/1',      'Max_Ta/1', 'autorouting', 'on');
add_line(sub, 'Prod_Tamin/1',  'Max_Ta/2', 'autorouting', 'on');
g_Ta = addGoto(sub, 'T_a', 1160, 250);
add_line(sub, 'Max_Ta/1', [g_Ta '/1'], 'autorouting', 'on');
f_Ta_out = addFrom(sub, 'T_a', 1220, 210);
add_line(sub, [f_Ta_out '/1'], 'T_a/1', 'autorouting', 'on');

% anti-windup: aw = Kaw*(T_a - T_a_unsat), fed back into the integrator
f_Ta_aw    = addFrom(sub, 'T_a',       620, 460);
f_unsat_aw = addFrom(sub, 'T_a_unsat', 620, 500);
addSum(sub, 'Sum_aw', '+-', 720, 470);           % T_a - T_a_unsat
add_line(sub, [f_Ta_aw '/1'],    'Sum_aw/1', 'autorouting', 'on');
add_line(sub, [f_unsat_aw '/1'], 'Sum_aw/2', 'autorouting', 'on');
hKaw = addConstant(sub, 'Kaw', 800, 520);
addProduct(sub, 'Prod_aw', '**', 880, 470);
add_line(sub, 'Sum_aw/1',    'Prod_aw/1', 'autorouting', 'on');
add_line(sub, [hKaw '/1'],   'Prod_aw/2', 'autorouting', 'on');
g_aw = addGoto(sub, 'aw', 960, 470);
add_line(sub, 'Prod_aw/1', [g_aw '/1'], 'autorouting', 'on');
f_aw = addFrom(sub, 'aw', 320, 250);
add_line(sub, [f_aw '/1'], 'u_I/2', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

%% ===================== u_P = Kp*e =======================================
function buildUP(sys)
    addInport(sys, 'e', 1, 40, 60);
    addOutport(sys, 'u_P', 1, 300, 60);
    hKp = addConstant(sys, 'Kp', 140, 140);   % right below Prod_uP
    addProduct(sys, 'Prod_uP', '**', 180, 60);
    add_line(sys, 'e/1',       'Prod_uP/1', 'autorouting', 'on');
    add_line(sys, [hKp '/1'],  'Prod_uP/2', 'autorouting', 'on');
    add_line(sys, 'Prod_uP/1', 'u_P/1',     'autorouting', 'on');
end


%% ===================== u_I = integral of (Ki*e + aw) =====================
function buildUI(sys)
% Main line: e -> Prod_Kie -> Sum_Kie -> Int_uI -> u_I. aw (anti-windup
% term, Kaw*(T_a - T_a_unsat), zero when not saturated) joins Sum_Kie.
    addInport(sys, 'e',  1, 40, 60);
    addInport(sys, 'aw', 2, 40, 180);
    addOutport(sys, 'u_I', 1, 560, 60);
    hKi = addConstant(sys, 'Ki', 140, 140);   % right below Prod_Kie
    addProduct(sys, 'Prod_Kie', '**', 180, 60);
    addSum(sys, 'Sum_Kie', '++', 300, 70);    % Ki*e + aw
    addDiscreteIntegrator(sys, 'Int_uI', 420, 60);
    add_line(sys, 'e/1',        'Prod_Kie/1', 'autorouting', 'on');
    add_line(sys, [hKi '/1'],   'Prod_Kie/2', 'autorouting', 'on');
    add_line(sys, 'Prod_Kie/1', 'Sum_Kie/1',  'autorouting', 'on');
    add_line(sys, 'aw/1',       'Sum_Kie/2',  'autorouting', 'on');
    add_line(sys, 'Sum_Kie/1',  'Int_uI/1',   'autorouting', 'on');
    add_line(sys, 'Int_uI/1',   'u_I/1',      'autorouting', 'on');
end

%% ===================== u_D = Kd*w, w = (e - x)/T_filt ====================
function buildUD(sys)
% Main line: e -> Sum_ex -> Div_w -> Prod_uD -> u_D. The filter state x
% (Int_x, fed by w) joins Sum_ex from below via Goto/From.
    addInport(sys, 'e', 1, 40, 60);
    addOutport(sys, 'u_D', 1, 560, 70);

    addSum    (sys, 'Sum_ex', '+-', 140, 70);   % e - x
    addProduct(sys, 'Div_w',  '*/', 240, 70);   % /T_filt
    addProduct(sys, 'Prod_uD', '**', 440, 70);  % Kd*w

    hTf = addConstant(sys, 'T_filt', 200, 160);  % right below Div_w
    hKd = addConstant(sys, 'Kd', 400, 160);      % right below Prod_uD

    % w feeds Prod_uD (main line) and the filter integrator -> Goto/From
    g_w = addGoto(sys, 'w', 320, 70);
    add_line(sys, 'Div_w/1', [g_w '/1'], 'autorouting', 'on');
    f_w_uD  = addFrom(sys, 'w', 380,  70);
    f_w_int = addFrom(sys, 'w', 140, 240);

    addDiscreteIntegrator(sys, 'Int_x', 220, 240);
    g_x = addGoto(sys, 'x', 300, 240);
    f_x = addFrom(sys, 'x', 60, 120);

    add_line(sys, 'e/1',          'Sum_ex/1',  'autorouting', 'on');
    add_line(sys, [f_x '/1'],     'Sum_ex/2',  'autorouting', 'on');
    add_line(sys, 'Sum_ex/1',     'Div_w/1',   'autorouting', 'on');
    add_line(sys, [hTf '/1'],     'Div_w/2',   'autorouting', 'on');
    add_line(sys, [f_w_uD '/1'],  'Prod_uD/1', 'autorouting', 'on');
    add_line(sys, [hKd '/1'],     'Prod_uD/2', 'autorouting', 'on');
    add_line(sys, 'Prod_uD/1',    'u_D/1',     'autorouting', 'on');
    add_line(sys, [f_w_int '/1'], 'Int_x/1',   'autorouting', 'on');
    add_line(sys, 'Int_x/1',      [g_x '/1'],  'autorouting', 'on');
end


%% ===================== T_a,max(v) ========================================
function buildTamax(sys)
% Assist limit as a function of the (sampled) speed: 1-D lookup table
% (base workspace Tamax_v_bp_ms [m/s], Tamax_table [N.m], from data/ref.json (Ta_max)).
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

function addAbsBlock(sys, name, x, y)
% Abs_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Abs', full);
    moveBlock(full, x, y);
end

function addSqrtBlock(sys, name, x, y)
% Sqrt_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sqrt', full);
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
