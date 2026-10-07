%% build_actuator.m
% Use the Simulink API to build the Actuator (motor) block, saved as Actuator.mdl RIGHT INSIDE the Actuator/ folder (parent of this
% script). Every controller of the closed loop writes its command T_a_cmd into this block, which models the motor:
%
%   T_a_max  = T_a,max(v)                                   1-D table (Documents/Ref/ref.txt section 1.5, data/ref.json field Ta_max)
%   T_a_lim  = max(-T_a_max, min(T_a_cmd, T_a_max))         assist limit
%   T_a      = Gm(s) * T_a_lim,   Gm(s) = wm/(s + wm)       motor lag, Lee 2018 equation (10), wm = 2*pi*100 Hz (data/actuator.json)
%
% T_a goes to the Plant; T_a_lim (before the lag) is the signal a controller with an integrator uses for anti-windup.
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   Actuator            In : T_a_cmd, v        Out: T_a, T_a_lim
%     +-- T_a_max       In : v                 Out: T_a_max
%     +-- Cal T_a_lim   In : T_a_cmd, T_a_max  Out: T_a_lim   ("Cal " prefix: the parent has an output port named T_a_lim)
%     +-- Motor         In : T_a_lim           Out: T_a
%
% Parameters: Tamax_v_bp_ms, Tamax_table, motor_wm - run Model/load_actuator.m BEFORE building.
%
% Usage (run from this folder, Actuator/script/):
%   >> run('../../load_actuator.m')
%   >> build_actuator            % or build_actuator(true) to overwrite


function modelName = build_actuator(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing Actuator.mdl; false: save as Actuator_1, ...

scriptDir = fileparts(mfilename('fullpath'));   % Actuator/script
actDir    = fileparts(scriptDir);               % Actuator/
modelDir  = fileparts(fileparts(actDir));       % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(actDir, 'Actuator', overwrite);
modelPath = fullfile(actDir, [modelName '.mdl']);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/Actuator'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_a_cmd', 1, 40, 60);
addInport(sub, 'v',       2, 40, 260);
addOutport(sub, 'T_a',     1, 1000, 160);
addOutport(sub, 'T_a_lim', 2, 1000, 60);

s1 = [sub '/T_a_max'];
createSubsystem(s1); moveBlock(s1, 360, 260); buildTaMax(s1);
add_line(sub, 'v/1', 'T_a_max/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a_max', 480, 270); add_line(sub, 'T_a_max/1', [g '/1'], 'autorouting', 'on');

s2 = [sub '/Cal T_a_lim'];
createSubsystem(s2); moveBlock(s2, 560, 60); buildTaLim(s2);
add_line(sub, 'T_a_cmd/1', 'Cal T_a_lim/1', 'autorouting', 'on');
f = addFrom(sub, 'T_a_max', 490, 100); add_line(sub, [f '/1'], 'Cal T_a_lim/2', 'autorouting', 'on');
g = addGoto(sub, 'T_a_lim', 700, 70); add_line(sub, 'Cal T_a_lim/1', [g '/1'], 'autorouting', 'on');
f = addFrom(sub, 'T_a_lim', 900, 60); add_line(sub, [f '/1'], 'T_a_lim/1', 'autorouting', 'on');

s3 = [sub '/Motor'];
createSubsystem(s3); moveBlock(s3, 760, 160); buildMotor(s3);
f = addFrom(sub, 'T_a_lim', 700, 160); add_line(sub, [f '/1'], 'Motor/1', 'autorouting', 'on');
add_line(sub, 'Motor/1', 'T_a/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);

end

%% ===================== T_a_max = T_a,max(v) ============================
function buildTaMax(s)
    addInport(s, 'v', 1, 40, 60);
    addOutport(s, 'T_a_max', 1, 320, 60);
    full = [s '/Lookup_Tamax'];
    add_block('simulink/Lookup Tables/1-D Lookup Table', full);
    set_param(full, 'Table', 'Tamax_table', 'BreakpointsForDimension1', 'Tamax_v_bp_ms', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(full, 160, 50);
    add_line(s, 'v/1', 'Lookup_Tamax/1', 'autorouting', 'on');
    add_line(s, 'Lookup_Tamax/1', 'T_a_max/1', 'autorouting', 'on');
end

%% ===================== T_a_lim = max(-T_a_max, min(T_a_cmd, T_a_max)) ====
function buildTaLim(s)
    addInport(s, 'T_a_cmd', 1, 40, 60);
    addInport(s, 'T_a_max', 2, 40, 180);
    addOutport(s, 'T_a_lim', 1, 560, 70);
    g = addGoto(s, 'T_a_max', 110, 180); add_line(s, 'T_a_max/1', [g '/1'], 'autorouting', 'on');
    fMin = addFrom(s, 'T_a_max', 190, 110);
    fNeg = addFrom(s, 'T_a_max', 190, 200);
    addMinMax(s, 'Min_Ta', 'min', 300, 60);
    add_line(s, 'T_a_cmd/1', 'Min_Ta/1', 'autorouting', 'on');
    add_line(s, [fMin '/1'], 'Min_Ta/2', 'autorouting', 'on');
    full = [s '/Neg_Tamax'];
    add_block('simulink/Math Operations/Unary Minus', full);
    moveBlock(full, 300, 200);
    add_line(s, [fNeg '/1'], 'Neg_Tamax/1', 'autorouting', 'on');
    addMinMax(s, 'Max_Ta', 'max', 440, 70);
    add_line(s, 'Min_Ta/1',    'Max_Ta/1', 'autorouting', 'on');
    add_line(s, 'Neg_Tamax/1', 'Max_Ta/2', 'autorouting', 'on');
    add_line(s, 'Max_Ta/1', 'T_a_lim/1', 'autorouting', 'on');
end

%% ===================== T_a = Gm(s) * T_a_lim, Gm = wm/(s + wm) ==========
function buildMotor(s)
    addInport(s, 'T_a_lim', 1, 40, 60);
    addOutport(s, 'T_a', 1, 320, 60);
    full = [s '/Motor_lag'];
    add_block('simulink/Continuous/Transfer Fcn', full);
    set_param(full, 'Numerator', '[motor_wm]', 'Denominator', '[1 motor_wm]');
    moveBlock(full, 140, 50);
    add_line(s, 'T_a_lim/1', 'Motor_lag/1', 'autorouting', 'on');
    add_line(s, 'Motor_lag/1', 'T_a/1', 'autorouting', 'on');
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

function addMinMax(sys, name, fcn, x, y)
% Min_<result> / Max_<result>: 2-input MinMax block (fcn = 'min' or 'max')
    full = [sys '/' name];
    add_block('simulink/Math Operations/MinMax', full);
    set_param(full, 'Function', fcn, 'Inputs', '2');
    moveBlock(full, x, y);
end
