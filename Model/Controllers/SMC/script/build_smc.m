%% build_smc.m
% Use the Simulink API to build the SMC-sat controller block, saved as
% SMC.mdl inside Controllers/SMC/ (parent of this script).
% Plug-and-play interface of Sim/script/build_closed_loop.m (wired by NAME):
%   In : T_s, v, a_y, T_a_lim (measured/closed-loop signals), T_a_max (from AssistLimit)
%   Out: T_a (commanded assist torque)
%
% Mathematical formulation (SMC-sat without integral, Slotine & Li Ch. 7):
%   e_T = T_s - T_d,ref(v, a_y)                  from shared Reference block
%   Ts_dot_hat: filtered derivative of T_s, H(s) = s / (Tf * s + 1), Forward Euler, Ts = Ts_ctrl = 1 ms
%       w[k+1] = w[k] + Ts * Ts_dot_hat[k],  Ts_dot_hat[k] = (T_s[k] - w[k]) / Tf
%   Sliding surface:  s = Ts_dot_hat + lambda * e_T
%   Saturation law:   T_a = T_a_max * sat(s / Phi)
%
% Hierarchy (CLAUDE.md):
%   SMC                   In : T_s, v, a_y, T_a_lim, T_a_max    Out: T_a
%     +-- Reference, Sum_eT, Sum_diff, Prod_Ts_dot, Int_w (Forward Euler, Ts_ctrl)
%     +-- Prod_lambda_e   SMC_lambda * e_T
%     +-- Sum_s           Ts_dot_hat + lambda*e_T -> s
%     +-- Div_s_Phi, Sat_s, Prod_Ta   T_a_max * sat(s / Phi)
%
% Usage:
%   >> run('../load_smc.m')
%   >> build_smc          % or build_smc(true) to overwrite

function modelName = build_smc(overwrite)
if nargin < 1, overwrite = false; end

scriptDir = fileparts(mfilename('fullpath'));   % SMC/script
ctlDir    = fileparts(scriptDir);               % SMC/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(ctlDir, 'SMC', overwrite);
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

sub = [modelName '/SMC'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'v',       2, 40, 180);
addInport(sub, 'a_y',     3, 40, 260);
addInport(sub, 'T_a_lim', 4, 40, 480);
addInport(sub, 'T_a_max', 5, 40, 380);
addOutport(sub, 'T_a',    1, 1500, 70);

% Inport T_s -> Goto tag T_s
gTs = addGoto(sub, 'T_s', 180, 60);
add_line(sub, 'T_s/1', [gTs '/1'], 'autorouting', 'on');

% Inport T_a_max -> Goto tag T_a_max
gTamax = addGoto(sub, 'T_a_max', 180, 380);
add_line(sub, 'T_a_max/1', [gTamax '/1'], 'autorouting', 'on');

% Inport T_a_lim terminated (no integral state, so no anti-windup)
hTerm = add_block('simulink/Sinks/Terminator', [sub '/Term_Ta_lim'], 'MakeNameUnique', 'on');
moveBlock(hTerm, 180, 480);
add_line(sub, 'T_a_lim/1', [get_param(hTerm, 'Name') '/1'], 'autorouting', 'on');

% ----- T_d_ref from the shared Reference block -----
add_block(refSub{1}, [sub '/Reference']);
moveBlock([sub '/Reference'], 200, 190);
add_line(sub, 'v/1',   'Reference/1', 'autorouting', 'on');
add_line(sub, 'a_y/1', 'Reference/2', 'autorouting', 'on');
g = addGoto(sub, 'T_d_ref', 380, 200); add_line(sub, 'Reference/1', [g '/1'], 'autorouting', 'on');

% ----- e_T = T_s - T_d_ref -----
addSum(sub, 'Sum_eT', '+-', 460, 70);
add_line(sub, [addFrom(sub, 'T_s', 380, 60) '/1'], 'Sum_eT/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_d_ref', 380, 110) '/1'], 'Sum_eT/2', 'autorouting', 'on');
g = addGoto(sub, 'e_T', 560, 80); add_line(sub, 'Sum_eT/1', [g '/1'], 'autorouting', 'on');

% ----- State w (derivative filter): Ts_dot_hat = (T_s - w) / SMC_Tf -----
addSum(sub, 'Sum_diff', '+-', 460, 320);
add_line(sub, [addFrom(sub, 'T_s', 380, 300) '/1'], 'Sum_diff/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'w',   380, 350) '/1'], 'Sum_diff/2', 'autorouting', 'on');

addProduct(sub, 'Prod_Ts_dot', '*/', 560, 320);
add_line(sub, 'Sum_diff/1', 'Prod_Ts_dot/1', 'autorouting', 'on');
add_line(sub, [addConstant(sub, 'SMC_Tf', 460, 370) '/1'], 'Prod_Ts_dot/2', 'autorouting', 'on');
g = addGoto(sub, 'Ts_dot_hat', 660, 300); add_line(sub, 'Prod_Ts_dot/1', [g '/1'], 'autorouting', 'on');

% State w: discrete-time integrator, forward Euler, Ts_ctrl
fullIntW = [sub '/Int_w'];
add_block('simulink/Discrete/Discrete-Time Integrator', fullIntW);
set_param(fullIntW, 'IntegratorMethod', 'Integration: Forward Euler', 'SampleTime', 'Ts_ctrl', 'gainval', '1', 'InitialCondition', '0');
moveBlock(fullIntW, 680, 360);
add_line(sub, 'Prod_Ts_dot/1', 'Int_w/1', 'autorouting', 'on');
g = addGoto(sub, 'w', 800, 370); add_line(sub, 'Int_w/1', [g '/1'], 'autorouting', 'on');

% ----- Sliding surface s = Ts_dot_hat + lambda*e_T -----
addProduct(sub, 'Prod_lambda_e', '**', 760, 40);
add_line(sub, [addConstant(sub, 'SMC_lambda', 640, 20) '/1'], 'Prod_lambda_e/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 640, 60) '/1'],            'Prod_lambda_e/2', 'autorouting', 'on');

addSum(sub, 'Sum_s', '++', 880, 60);
add_line(sub, [addFrom(sub, 'Ts_dot_hat', 760, 90) '/1'], 'Sum_s/1', 'autorouting', 'on');
add_line(sub, 'Prod_lambda_e/1',                          'Sum_s/2', 'autorouting', 'on');
g = addGoto(sub, 's', 980, 70); add_line(sub, 'Sum_s/1', [g '/1'], 'autorouting', 'on');

% ----- Normalized sliding surface: s_over_Phi = s / SMC_Phi -----
addProduct(sub, 'Div_s_Phi', '*/', 1080, 50);
add_line(sub, [addFrom(sub, 's', 980, 40) '/1'], 'Div_s_Phi/1', 'autorouting', 'on');
add_line(sub, [addConstant(sub, 'SMC_Phi', 980, 90) '/1'], 'Div_s_Phi/2', 'autorouting', 'on');
g = addGoto(sub, 's_over_Phi', 1180, 100); add_line(sub, 'Div_s_Phi/1', [g '/1'], 'autorouting', 'on');

% ----- Saturation law: T_a = T_a_max * sat(s / SMC_Phi) -----
fullSat = [sub '/Sat_s'];
add_block('simulink/Discontinuities/Saturation', fullSat);
set_param(fullSat, 'UpperLimit', '1', 'LowerLimit', '-1');
moveBlock(fullSat, 1260, 50);
add_line(sub, 'Div_s_Phi/1', 'Sat_s/1', 'autorouting', 'on');

addProduct(sub, 'Prod_Ta', '**', 1380, 60);
add_line(sub, 'Sat_s/1', 'Prod_Ta/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a_max', 1260, 100) '/1'], 'Prod_Ta/2', 'autorouting', 'on');

add_line(sub, 'Prod_Ta/1', 'T_a/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a', 1480, 110); add_line(sub, 'Prod_Ta/1', [g '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
close_system('Reference', 0);
fprintf('Created: %s\n', modelPath);

end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function createSubsystem(path)
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
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], 'MakeNameUnique', 'on');
    set_param(h, 'Value', valueExpr);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addGoto(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addFrom(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/From', [sys '/From'], 'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, ops, x, y)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', ops);
    moveBlock(full, x, y);
end

function addSum(sys, name, signs, x, y)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sum', full);
    set_param(full, 'Inputs', signs);
    moveBlock(full, x, y);
end
