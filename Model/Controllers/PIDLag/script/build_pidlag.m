%% build_pidlag.m
% Use the Simulink API to build the PIDOpt or PIDLag controller block, saved as <ctrl>.mdl inside Controllers/<ctrl>/. Interface of Sim/script/build_closed_loop.m
% (wired by NAME): In T_s, v, a_y (measured), T_a_lim (command after the assist limit); Out T_a (command). PID followed by a lag stage on the command:
%
%   e_T      = T_s - T_d,ref(v, a_y)
%   u[k]     = Kp e[k] + u_I[k] + d[k],      d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]),  a = Tf/(Tf+Ts), b = Kd/(Tf+Ts)   (derivative on the measured T_s)
%   T_a      = H(z) u                        H(s) = (s/z1 + 1)/(s/p1 + 1), Tustin Ts_ctrl (H = 1 for PIDOpt)
%   u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k])),  Kaw = Ki/Kp      back-calculation on the command AFTER the lag (as MapPID: on the total command)
% The controller does not clamp T_a and does not model the motor (QuyChuan 2.3). Reuses only the PRSM blocks (the Reference block) and no block of PI, PID, Map or MapPID.
%
% HIERARCHY (CLAUDE.md, "Quy tac dung model Simulink"):
%   <ctrl>   In : T_s, v, a_y, T_a_lim    Out: T_a
%     +-- Reference      (copy of PRSM/Ref/Reference)
%     +-- Sum_eT, Prod_P, Prod_Ki, Sum_aw, Prod_Kaw, Sum_dI, Int_uI, UD_Ts, Sum_dTs, Prod_b, UD_d, Prod_a, Sum_d
%     +-- Sum_u (u_P + u_I + u_D), Disc_H (lag, Discrete Transfer Fcn)
%
% Parameters (<ctrl>_*): run Controllers/<ctrl>/load_<ctrl>.m BEFORE building. The model reads ONLY <ctrl>_* variables.
%
% Usage:  >> run('<Model>/Controllers/PIDLag/load_pidlag.m');  build_pidlag('PIDLag', true)

function modelName = build_pidlag(ctrl, overwrite)
if nargin < 2, overwrite = false; end   % true: replace an existing <ctrl>.mdl; false: save as <ctrl>_1, <ctrl>_2, ...
assert(any(strcmp(ctrl, {'PIDOpt', 'PIDLag'})), 'ctrl must be PIDOpt or PIDLag');
P = [ctrl '_'];

scriptDir = fileparts(mfilename('fullpath'));   % PIDLag/script
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
ctlDir    = fullfile(modelDir, 'Controllers', ctrl);
modelName = ctrl; if ~overwrite && exist(fullfile(ctlDir, [ctrl '.mdl']), 'file'), error('build_pidlag:exists', '%s.mdl exists; call build_pidlag(ctrl, true) to overwrite', ctrl); end
modelPath = fullfile(ctlDir, [modelName '.mdl']);
if bdIsLoaded(modelName), close_system(modelName, 0); end
if exist(modelPath, 'file'), delete(modelPath); end

refFile = fullfile(modelDir, 'PRSM', 'Ref', 'Reference.mdl');
if ~bdIsLoaded('Reference'), load_system(refFile); end
refSub = find_system('Reference', 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(refSub) == 1, 'Reference.mdl must have exactly 1 root subsystem');

new_system(modelName);
open_system(modelName);
sub = [modelName '/' ctrl];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'v',       2, 40, 180);
addInport(sub, 'a_y',     3, 40, 300);
addInport(sub, 'T_a_lim', 4, 40, 620);
addOutport(sub, 'T_a', 1, 1500, 160);
gt = addGoto(sub, 'T_s', 120, 60);  add_line(sub, 'T_s/1', [gt '/1'], 'autorouting', 'on');
gv = addGoto(sub, 'v', 120, 180);   add_line(sub, 'v/1',   [gv '/1'], 'autorouting', 'on');

% ----- T_d_ref from the shared Reference block -----
add_block(refSub{1}, [sub '/Reference']);
moveBlock([sub '/Reference'], 300, 260);
add_line(sub, [addFrom(sub, 'v', 200, 240) '/1'], 'Reference/1', 'autorouting', 'on');
add_line(sub, 'a_y/1', 'Reference/2', 'autorouting', 'on');
g = addGoto(sub, 'T_d_ref', 480, 270); add_line(sub, 'Reference/1', [g '/1'], 'autorouting', 'on');

% ----- e_T = T_s - T_d_ref -----
addSum(sub, 'Sum_eT', '+-', 560, 330);
add_line(sub, [addFrom(sub, 'T_s', 480, 320) '/1'], 'Sum_eT/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_d_ref', 480, 360) '/1'], 'Sum_eT/2', 'autorouting', 'on');
g = addGoto(sub, 'e_T', 660, 340); add_line(sub, 'Sum_eT/1', [g '/1'], 'autorouting', 'on');

% ----- proportional term u_P = Kp e_T -----
addProduct(sub, 'Prod_P', '**', 860, 330);
add_line(sub, [addConstant(sub, [P 'Kp'], 780, 300) '/1'], 'Prod_P/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 780, 360) '/1'], 'Prod_P/2', 'autorouting', 'on');
g = addGoto(sub, 'u_P', 960, 340); add_line(sub, 'Prod_P/1', [g '/1'], 'autorouting', 'on');

% ----- integrator input Ki e_T + Kaw (T_a_lim - T_a), T_a = output AFTER the lag -----
addProduct(sub, 'Prod_Ki', '**', 860, 460);
add_line(sub, [addConstant(sub, [P 'Ki'], 780, 430) '/1'], 'Prod_Ki/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 780, 490) '/1'], 'Prod_Ki/2', 'autorouting', 'on');
addSum(sub, 'Sum_aw', '+-', 560, 620);
add_line(sub, 'T_a_lim/1', 'Sum_aw/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a', 480, 660) '/1'], 'Sum_aw/2', 'autorouting', 'on');
addProduct(sub, 'Prod_Kaw', '**', 860, 600);
add_line(sub, [addConstant(sub, [P 'Kaw'], 780, 570) '/1'], 'Prod_Kaw/1', 'autorouting', 'on');
add_line(sub, 'Sum_aw/1', 'Prod_Kaw/2', 'autorouting', 'on');
addSum(sub, 'Sum_dI', '++', 1000, 520);
add_line(sub, 'Prod_Ki/1',  'Sum_dI/1', 'autorouting', 'on');
add_line(sub, 'Prod_Kaw/1', 'Sum_dI/2', 'autorouting', 'on');

% ----- u_I: discrete-time integrator, forward Euler, sample time <ctrl>_Ts_ctrl -----
full = [sub '/Int_uI'];
add_block('simulink/Discrete/Discrete-Time Integrator', full);
set_param(full, 'IntegratorMethod', 'Integration: Forward Euler', 'SampleTime', [P 'Ts_ctrl'], 'gainval', '1', 'InitialCondition', '0');
moveBlock(full, 1120, 520);
add_line(sub, 'Sum_dI/1', 'Int_uI/1', 'autorouting', 'on');
g = addGoto(sub, 'u_I', 1220, 530); add_line(sub, 'Int_uI/1', [g '/1'], 'autorouting', 'on');

% ----- derivative on the measured T_s: d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]); the unit delays break every algebraic loop -----
addUnitDelay(sub, 'UD_Ts', [P 'Ts_ctrl'], 40, 760);
add_line(sub, [addFrom(sub, 'T_s', 0, 740) '/1'], 'UD_Ts/1', 'autorouting', 'on');
addSum(sub, 'Sum_dTs', '+-', 200, 760);
add_line(sub, [addFrom(sub, 'T_s', 120, 740) '/1'], 'Sum_dTs/1', 'autorouting', 'on');
add_line(sub, 'UD_Ts/1', 'Sum_dTs/2', 'autorouting', 'on');
addProduct(sub, 'Prod_b', '**', 360, 760);
add_line(sub, [addConstant(sub, sprintf('%sKd/(%sTf+%sTs_ctrl)', P, P, P), 280, 720) '/1'], 'Prod_b/1', 'autorouting', 'on');
add_line(sub, 'Sum_dTs/1', 'Prod_b/2', 'autorouting', 'on');
addUnitDelay(sub, 'UD_d', [P 'Ts_ctrl'], 360, 880);
addProduct(sub, 'Prod_a', '**', 520, 880);
add_line(sub, [addConstant(sub, sprintf('%sTf/(%sTf+%sTs_ctrl)', P, P, P), 440, 840) '/1'], 'Prod_a/1', 'autorouting', 'on');
add_line(sub, 'UD_d/1', 'Prod_a/2', 'autorouting', 'on');
addSum(sub, 'Sum_d', '++', 680, 820);
add_line(sub, 'Prod_b/1', 'Sum_d/1', 'autorouting', 'on');
add_line(sub, 'Prod_a/1', 'Sum_d/2', 'autorouting', 'on');
add_line(sub, 'Sum_d/1', 'UD_d/1', 'autorouting', 'on');
g = addGoto(sub, 'u_D', 780, 830); add_line(sub, 'Sum_d/1', [g '/1'], 'autorouting', 'on');

% ----- u = u_P + u_I + u_D, then the lag stage T_a = H u -----
addSum(sub, 'Sum_u', '+++', 1300, 150);
add_line(sub, [addFrom(sub, 'u_P', 1220, 120) '/1'], 'Sum_u/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_I', 1220, 160) '/1'], 'Sum_u/2', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_D', 1220, 200) '/1'], 'Sum_u/3', 'autorouting', 'on');
h = [sub '/Disc_H'];
add_block('simulink/Discrete/Discrete Transfer Fcn', h);
set_param(h, 'Numerator', [P 'H_num'], 'Denominator', [P 'H_den'], 'SampleTime', [P 'Ts_ctrl']);
moveBlock(h, 1380, 140);
add_line(sub, 'Sum_u/1', 'Disc_H/1', 'autorouting', 'on');
add_line(sub, 'Disc_H/1', 'T_a/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a', 1440, 260); add_line(sub, 'Disc_H/1', [g '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
close_system('Reference', 0);
fprintf('Created: %s\n', modelPath);
end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
    pos = get_param(blk, 'Position');
    set_param(blk, 'Position', [x, y, x + pos(3) - pos(1), y + pos(4) - pos(2)]);
end
function createSubsystem(path)
    add_block('simulink/Ports & Subsystems/Subsystem', path);
    delete_line(path, 'In1/1', 'Out1/1');
    delete_block([path '/In1']); delete_block([path '/Out1']);
end
function addInport(sys, name, port, x, y)
    full = [sys '/' name]; add_block('simulink/Sources/In1', full); set_param(full, 'Port', num2str(port)); moveBlock(full, x, y);
end
function addOutport(sys, name, port, x, y)
    full = [sys '/' name]; add_block('simulink/Sinks/Out1', full); set_param(full, 'Port', num2str(port)); moveBlock(full, x, y);
end
function nm = addConstant(sys, valueExpr, x, y)
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], 'MakeNameUnique', 'on');
    set_param(h, 'Value', valueExpr); moveBlock(h, x, y); nm = get_param(h, 'Name');
end
function nm = addGoto(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local'); moveBlock(h, x, y); nm = get_param(h, 'Name');
end
function nm = addFrom(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/From', [sys '/From'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag); moveBlock(h, x, y); nm = get_param(h, 'Name');
end
function addProduct(sys, name, inputsStr, x, y)
    full = [sys '/' name]; add_block('simulink/Math Operations/Product', full); set_param(full, 'Inputs', inputsStr); moveBlock(full, x, y);
end
function addSum(sys, name, signs, x, y)
    full = [sys '/' name]; add_block('simulink/Math Operations/Sum', full); set_param(full, 'Inputs', signs); moveBlock(full, x, y);
end
function addSignBlock(sys, name, x, y)
    full = [sys '/' name]; add_block('simulink/Math Operations/Sign', full); moveBlock(full, x, y);
end
function addZoh(sys, name, tsVar, x, y)
    full = [sys '/' name]; add_block('simulink/Discrete/Zero-Order Hold', full); set_param(full, 'SampleTime', tsVar); moveBlock(full, x, y);
end
function addUnitDelay(sys, name, ts, x, y)
    full = [sys '/' name]; add_block('simulink/Discrete/Unit Delay', full); set_param(full, 'SampleTime', ts, 'InitialCondition', '0'); moveBlock(full, x, y);
end
