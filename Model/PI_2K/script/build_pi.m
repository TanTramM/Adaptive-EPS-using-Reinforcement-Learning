%% build_pi.m
% Use the Simulink API to build the PI controller (the PID block with Kd = 0, first version) of the PRSM closed loop as its own
% subsystem, saved as PI_2K_s.mdl RIGHT INSIDE the PI/ folder (parent of this script). Matches Documents/PI_2K/pid.txt:
%
%   T_s[k], a_y[k], v[k], T_a_lim[k] sampled at Ts_ctrl (ZOH)
%   T_d,ref[k] = Reference(v[k], a_y[k])                 same Reference block as the scoring (Model/Ref/Reference_s.mdl)
%   e[k]       = T_s[k] - T_d,ref[k]                     e > 0: steering heavier than wanted, more assist needed
%   u_P[k]     = Kp*e[k]
%   u_I[k+1]   = u_I[k] + Ts*(Ki*e[k] + Kaw*(T_a_lim[k] - T_a_cmd[k]))     Forward Euler, back-calculation anti-windup
%   T_a_cmd[k] = u_P[k] + u_I[k]
%
% The assist limit T_a,max(v) and the motor lag are NOT here: they are in the Actuator block of the closed loop (Model/Actuator/).
% T_a_lim (the command after the assist limit, before the motor lag) is read back only for the anti-windup; Kaw = 1/Ti (tracking time
% constant = Ti). The controller measures only what the Sensors block gives (no mu).
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   PI               In : T_s, a_y, v, T_a_lim      Out: T_a (the command T_a_cmd)
%     +-- Reference  In : v, a_y                    Out: T_d_ref   (copy of the root subsystem of Reference_s.mdl)
%     +-- u_P        In : e                         Out: u_P
%     +-- u_I        In : e, aw                     Out: u_I
%
%   e (Sum_eT), T_a_cmd (Sum_Ta) and aw (Prod_aw) are computed at this level and routed with Goto/From.
%
% Gains (Kp, Ki, Kaw) and Ts_ctrl come from the base workspace - run Model/load_pi_2k.m BEFORE building; Reference needs load_ref.m
% (called by load_pi_2k.m).
%
% Usage (run from this folder, PI/script/):
%   >> run('../../load_pi_2k.m')
%   >> build_pi

modelName = 'PI_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
ctrlDir   = fileparts(scriptDir);               % PI/
modelDir  = fileparts(ctrlDir);                 % Model/
modelPath = fullfile(ctrlDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end
refName = 'Reference_s';
if bdIsLoaded(refName), close_system(refName, 0); end
load_system(fullfile(modelDir, 'Ref', [refName '.mdl']));
refRoot = find_system(refName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(refRoot) == 1, 'Reference_s must have exactly 1 root subsystem');

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: PI =============================
sub = [modelName '/PI'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'a_y',     2, 40, 160);
addInport(sub, 'v',       3, 40, 260);
addInport(sub, 'T_a_lim', 4, 40, 560);
addOutport(sub, 'T_a', 1, 1200, 180);

% sampled inputs (the ECU reads the measured signals at Ts_ctrl)
sig = {'T_s', 'a_y', 'v', 'T_a_lim'};
yy  = [60 160 260 560];
for i = 1:numel(sig)
    addZOH(sub, ['ZOH_' sig{i}], 120, yy(i));
    add_line(sub, [sig{i} '/1'], ['ZOH_' sig{i} '/1'], 'autorouting', 'on');
    g = addGoto(sub, sig{i}, 200, yy(i));
    add_line(sub, ['ZOH_' sig{i} '/1'], [g '/1'], 'autorouting', 'on');
end

% T_d_ref = Reference(v, a_y)
refBlk = [sub '/Reference'];
add_block(refRoot{1}, refBlk);
moveBlock(refBlk, 360, 200);
add_line(sub, [addFrom(sub, 'v',   290, 210) '/1'], portRef(refBlk, 'v'),   'autorouting', 'on');
add_line(sub, [addFrom(sub, 'a_y', 290, 250) '/1'], portRef(refBlk, 'a_y'), 'autorouting', 'on');
g = addGoto(sub, 'T_d_ref', 520, 220);
add_line(sub, portRef(refBlk, 'T_d_ref'), [g '/1'], 'autorouting', 'on');

% e = T_s - T_d_ref
addSum(sub, 'Sum_eT', '+-', 640, 70);
add_line(sub, [addFrom(sub, 'T_s',     560,  60) '/1'], 'Sum_eT/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_d_ref', 560, 100) '/1'], 'Sum_eT/2', 'autorouting', 'on');
g = addGoto(sub, 'e', 720, 70);
add_line(sub, 'Sum_eT/1', [g '/1'], 'autorouting', 'on');

% u_P, u_I
uP = [sub '/u_P'];  createSubsystem(uP);  moveBlock(uP, 820,  40);  buildUP(uP);
uI = [sub '/u_I'];  createSubsystem(uI);  moveBlock(uI, 820, 180);  buildUI(uI);
add_line(sub, [addFrom(sub, 'e', 760,  50) '/1'], 'u_P/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'Kp', 760, 70) '/1'], 'u_P/2', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e', 760, 190) '/1'], 'u_I/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'Ki', 760, 220) '/1'], 'u_I/2', 'autorouting', 'on');

% T_a_cmd = u_P + u_I
addSum(sub, 'Sum_Ta', '++', 1000, 110);
add_line(sub, 'u_P/1', 'Sum_Ta/1', 'autorouting', 'on');
add_line(sub, 'u_I/1', 'Sum_Ta/2', 'autorouting', 'on');
g = addGoto(sub, 'T_a_cmd', 1080, 110);
add_line(sub, 'Sum_Ta/1', [g '/1'], 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a_cmd', 1120, 180) '/1'], 'T_a/1', 'autorouting', 'on');

% anti-windup: aw = Kaw*(T_a_lim - T_a_cmd), zero while the command is inside the limits
addSum(sub, 'Sum_aw', '+-', 400, 560);
add_line(sub, [addFrom(sub, 'T_a_lim', 320, 550) '/1'], 'Sum_aw/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a_cmd', 320, 590) '/1'], 'Sum_aw/2', 'autorouting', 'on');
addProduct(sub, 'Prod_aw', '**', 520, 560);
add_line(sub, 'Sum_aw/1',   'Prod_aw/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'Kaw', 440, 620) '/1'],  'Prod_aw/2', 'autorouting', 'on');

% 1D Lookups for Gains based on v
add1DLookup(sub, 'LUT_Kp', 'v_breakpoints', 'Kp', 600, 260);
add_line(sub, [addFrom(sub, 'v', 520, 270) '/1'], 'LUT_Kp/1', 'autorouting', 'on');
g = addGoto(sub, 'Kp', 680, 260);
add_line(sub, 'LUT_Kp/1', [g '/1'], 'autorouting', 'on');

add1DLookup(sub, 'LUT_Ki', 'v_breakpoints', 'Ki', 600, 340);
add_line(sub, [addFrom(sub, 'v', 520, 350) '/1'], 'LUT_Ki/1', 'autorouting', 'on');
g = addGoto(sub, 'Ki', 680, 340);
add_line(sub, 'LUT_Ki/1', [g '/1'], 'autorouting', 'on');

add1DLookup(sub, 'LUT_Kaw', 'v_breakpoints', 'Kaw', 360, 620);
add_line(sub, [addFrom(sub, 'v', 280, 630) '/1'], 'LUT_Kaw/1', 'autorouting', 'on');
g = addGoto(sub, 'Kaw', 440, 620);
add_line(sub, 'LUT_Kaw/1', [g '/1'], 'autorouting', 'on');

g = addGoto(sub, 'aw', 600, 560);
add_line(sub, 'Prod_aw/1', [g '/1'], 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'aw', 760, 260) '/1'], 'u_I/3', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
close_system(refName, 0);

fprintf('Created: %s\n', modelPath);

%% ===================== u_P = Kp*e =======================================
function buildUP(sys)
    addInport(sys, 'e', 1, 40, 60);
    addInport(sys, 'Kp', 2, 40, 140);
    addOutport(sys, 'u_P', 1, 300, 60);
    addProduct(sys, 'Prod_uP', '**', 180, 60);
    add_line(sys, 'e/1',       'Prod_uP/1', 'autorouting', 'on');
    add_line(sys, 'Kp/1',      'Prod_uP/2', 'autorouting', 'on');
    add_line(sys, 'Prod_uP/1', 'u_P/1',     'autorouting', 'on');
end

%% ===================== u_I = integral of (Ki*e + aw) =====================
function buildUI(sys)
    addInport(sys, 'e',  1, 40, 60);
    addInport(sys, 'Ki', 2, 40, 140);
    addInport(sys, 'aw', 3, 40, 180);
    addOutport(sys, 'u_I', 1, 560, 60);
    addProduct(sys, 'Prod_Kie', '**', 180, 60);
    addSum(sys, 'Sum_Kie', '++', 300, 70);
    addDiscreteIntegrator(sys, 'Int_uI', 420, 60);
    add_line(sys, 'e/1',        'Prod_Kie/1', 'autorouting', 'on');
    add_line(sys, 'Ki/1',       'Prod_Kie/2', 'autorouting', 'on');
    add_line(sys, 'Prod_Kie/1', 'Sum_Kie/1',  'autorouting', 'on');
    add_line(sys, 'aw/1',       'Sum_Kie/2',  'autorouting', 'on');
    add_line(sys, 'Sum_Kie/1',  'Int_uI/1',   'autorouting', 'on');
    add_line(sys, 'Int_uI/1',   'u_I/1',      'autorouting', 'on');
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - wiring by NAME.
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
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

function nm = addConstant(sys, baseWorkspaceVar, x, y)
% Constant block, DEFAULT name; Value points STRAIGHT to a base-workspace variable name.
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], 'MakeNameUnique', 'on');
    set_param(h, 'Value', baseWorkspaceVar);
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

function addProduct(sys, name, inputsStr, x, y)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addSum(sys, name, inputsStr, x, y)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addDiscreteIntegrator(sys, name, x, y)
% Int_<state>: Discrete-Time Integrator, Forward Euler, sample time Ts_ctrl (base workspace). y[k] = x[k], x[k+1] = x[k] + Ts_ctrl*u[k].
    full = [sys '/' name];
    add_block('simulink/Discrete/Discrete-Time Integrator', full);
    set_param(full, 'IntegratorMethod', 'Integration: Forward Euler', 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addZOH(sys, name, x, y)
% ZOH_<signal>: samples a signal at Ts_ctrl (ECU input).
    full = [sys '/' name];
    add_block('simulink/Discrete/Zero-Order Hold', full);
    set_param(full, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function nm = add1DLookup(sys, name, bpVar, tableVar, x, y)
    h = add_block('simulink/Lookup Tables/1-D Lookup Table', [sys '/' name]);
    set_param(h, 'BreakpointsForDimension1', bpVar, 'Table', tableVar, 'ExtrapMethod', 'Clip');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end
