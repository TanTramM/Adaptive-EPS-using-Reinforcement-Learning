%% build_pi.m
% Use the Simulink API to build the PI controller block, saved as PI.mdl RIGHT INSIDE Controllers/PI/ (parent of this script). Plug-and-play
% interface of Sim/script/build_closed_loop.m (wired by NAME): In T_s, v, a_y (measured), T_a_lim (command after the assist limit); Out T_a (command).
%
%   e_T = T_s - T_d,ref(v, a_y)                              T_d,ref from the shared Reference block (PRSM/Ref), measured v and a_y
%   T_a[k]   = Kp e[k] + u_I[k]
%   u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k])),   Kaw = Ki/Kp       forward Euler, Ts = Ts_ctrl = 1 ms
% The term Kaw (T_a_lim - T_a) is back-calculation anti-windup (tracking time constant Tt = Ti = Kp/Ki): it is zero while the Actuator does not
% clamp, and pulls the integrator back when it does. Kaw = Ki/Kp is a fixed design choice (author's choice, not a tuned parameter). The controller
% does not clamp T_a and does not model the motor (QuyChuan.txt 2.3).
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   PI                   In : T_s, v, a_y, T_a_lim    Out: T_a
%     +-- Reference      In : v, a_y                  Out: T_d_ref        (copy of PRSM/Ref/Reference)
%     +-- Sum_eT         T_s - T_d_ref -> e_T
%     +-- Prod_P         Kp * e_T -> u_P
%     +-- Prod_Ki        Ki * e_T
%     +-- Sum_aw         T_a_lim - T_a;  Prod_Kaw: Kaw * (T_a_lim - T_a)
%     +-- Sum_dI         Ki e_T + Kaw (T_a_lim - T_a)
%     +-- Int_uI         discrete-time integrator, forward Euler, Ts_ctrl -> u_I
%     +-- Sum_Ta         u_P + u_I -> T_a
%
% Parameters: PI_Kp, PI_Ki, PI_Kaw, Ts_ctrl and the Ref variables - run Model/Controllers/PI/load_pi.m BEFORE building.
%
% Usage (run from this folder, PI/script/):
%   >> run('../load_pi.m')
%   >> build_pi              % or build_pi(true) to overwrite

function modelName = build_pi(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing PI.mdl; false: save as PI_1, PI_2, ...

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
ctlDir    = fileparts(scriptDir);               % PI/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(ctlDir, 'PI', overwrite);
modelPath = fullfile(ctlDir, [modelName '.mdl']);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

refFile = fullfile(modelDir, 'PRSM', 'Ref', 'Reference.mdl');
if ~bdIsLoaded('Reference'), load_system(refFile); end
refSub = find_system('Reference', 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(refSub) == 1, 'Reference.mdl must have exactly 1 root subsystem');

new_system(modelName);
open_system(modelName);

sub = [modelName '/PI'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'v',       2, 40, 180);
addInport(sub, 'a_y',     3, 40, 260);
addInport(sub, 'T_a_lim', 4, 40, 500);
addOutport(sub, 'T_a', 1, 1300, 100);

% ----- T_d_ref from the shared Reference block -----
add_block(refSub{1}, [sub '/Reference']);
moveBlock([sub '/Reference'], 200, 190);
add_line(sub, 'v/1',   'Reference/1', 'autorouting', 'on');
add_line(sub, 'a_y/1', 'Reference/2', 'autorouting', 'on');
g = addGoto(sub, 'T_d_ref', 380, 200); add_line(sub, 'Reference/1', [g '/1'], 'autorouting', 'on');

% ----- e_T = T_s - T_d_ref -----
addSum(sub, 'Sum_eT', '+-', 460, 70);
add_line(sub, 'T_s/1', 'Sum_eT/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_d_ref', 380, 110) '/1'], 'Sum_eT/2', 'autorouting', 'on');
g = addGoto(sub, 'e_T', 560, 80); add_line(sub, 'Sum_eT/1', [g '/1'], 'autorouting', 'on');

% ----- proportional term u_P = Kp e_T -----
addProduct(sub, 'Prod_P', '**', 760, 70);
add_line(sub, [addConstant(sub, 'PI_Kp', 680, 40) '/1'], 'Prod_P/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 680, 100) '/1'], 'Prod_P/2', 'autorouting', 'on');
g = addGoto(sub, 'u_P', 860, 80); add_line(sub, 'Prod_P/1', [g '/1'], 'autorouting', 'on');

% ----- integrator input Ki e_T + Kaw (T_a_lim - T_a) -----
addProduct(sub, 'Prod_Ki', '**', 760, 330);
add_line(sub, [addConstant(sub, 'PI_Ki', 680, 300) '/1'], 'Prod_Ki/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 680, 360) '/1'], 'Prod_Ki/2', 'autorouting', 'on');
addSum(sub, 'Sum_aw', '+-', 460, 500);
add_line(sub, 'T_a_lim/1', 'Sum_aw/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a', 380, 540) '/1'], 'Sum_aw/2', 'autorouting', 'on');
addProduct(sub, 'Prod_Kaw', '**', 760, 480);
add_line(sub, [addConstant(sub, 'PI_Kaw', 680, 450) '/1'], 'Prod_Kaw/1', 'autorouting', 'on');
add_line(sub, 'Sum_aw/1', 'Prod_Kaw/2', 'autorouting', 'on');
addSum(sub, 'Sum_dI', '++', 900, 400);
add_line(sub, 'Prod_Ki/1',  'Sum_dI/1', 'autorouting', 'on');
add_line(sub, 'Prod_Kaw/1', 'Sum_dI/2', 'autorouting', 'on');

% ----- u_I: discrete-time integrator, forward Euler, sample time Ts_ctrl -----
full = [sub '/Int_uI'];
add_block('simulink/Discrete/Discrete-Time Integrator', full);
set_param(full, 'IntegratorMethod', 'Integration: Forward Euler', 'SampleTime', 'Ts_ctrl', 'gainval', '1', 'InitialCondition', '0');
moveBlock(full, 1020, 400);
add_line(sub, 'Sum_dI/1', 'Int_uI/1', 'autorouting', 'on');
g = addGoto(sub, 'u_I', 1120, 410); add_line(sub, 'Int_uI/1', [g '/1'], 'autorouting', 'on');

% ----- T_a = u_P + u_I -----
addSum(sub, 'Sum_Ta', '++', 1100, 90);
add_line(sub, [addFrom(sub, 'u_P', 1000, 80) '/1'], 'Sum_Ta/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_I', 1000, 140) '/1'], 'Sum_Ta/2', 'autorouting', 'on');
add_line(sub, 'Sum_Ta/1', 'T_a/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a', 1200, 160); add_line(sub, 'Sum_Ta/1', [g '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
close_system('Reference', 0);
fprintf('Created: %s\n', modelPath);

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

function nm = addConstant(sys, valueExpr, x, y)
% Constant block, DEFAULT name; Value = the base-workspace variable name. Returns the block name.
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], 'MakeNameUnique', 'on');
    set_param(h, 'Value', valueExpr);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addGoto(sys, tag, x, y)
% Goto block, DEFAULT name; LOCAL scope only.
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addFrom(sys, tag, x, y)
% From block, DEFAULT name.
    h = add_block('simulink/Signal Routing/From', [sys '/From'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, ops, x, y)
% Prod_<result>: Product block; ops = '**' (multiply) or '*/' (divide)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', ops);
    moveBlock(full, x, y);
end

function addSum(sys, name, signs, x, y)
% Sum_<result>: Sum block with the given list of signs, e.g. '+-'
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sum', full);
    set_param(full, 'Inputs', signs);
    moveBlock(full, x, y);
end
