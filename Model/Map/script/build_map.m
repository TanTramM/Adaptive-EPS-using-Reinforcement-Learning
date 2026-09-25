%% build_map.m
% Use the Simulink API to build the static EPS assist map as its own
% subsystem, saved as Map_s.mdl RIGHT INSIDE the Map/ folder (parent of this
% script). Matches Documents/DieuKhien_Map.txt:
%
%   T_s[k], v[k]  sampled at Ts = Ts_ctrl (ZOH)
%   T_a[k] = sgn(T_s[k]) * M(v[k], |T_s[k]|)
%
% M is the 2-D lookup table (linear interpolation, clipped outside the
% breakpoints) calibrated at mu = 0.8 by Map/script/calibrate_map.m. The map
% is STATIC: no state, no gains, and it does not know mu.
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"): the map is one
% equation with one named quantity (T_a), so it stays in the root subsystem:
%
%   Map
%     In : T_s, v      Out: T_a
%     ZOH_Ts, ZOH_v -> Goto/From (T_s, v) -> Abs_Ts -> Lookup_Ta -> Prod_Ta
%                                            Sign_Ts ----------------^
%
% Lookup table data (map_v_bp, map_Ts_bp, map_Ta_table) and Ts_ctrl are read
% from the base workspace - run Model/load_map.m BEFORE building (it also
% runs load_plant, load_ref).
%
% Usage (run from this folder, Map/script/):
%   >> run('../../load_map.m')
%   >> build_map

modelName = 'Map_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
ctrlDir   = fileparts(scriptDir);               % Map/
modelPath = fullfile(ctrlDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: Map =============================
sub = [modelName '/Map'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s', 1, 40, 60);
addInport(sub, 'v',   2, 40, 200);
addOutport(sub, 'T_a', 1, 840, 110);

% sampled inputs (ECU reads the sensors at Ts_ctrl)
addZOH(sub, 'ZOH_Ts', 120, 60);
addZOH(sub, 'ZOH_v',  120, 200);
add_line(sub, 'T_s/1', 'ZOH_Ts/1', 'autorouting', 'on');
add_line(sub, 'v/1',   'ZOH_v/1',  'autorouting', 'on');

% T_s is used twice (|T_s| into the table, sign at the output) -> Goto/From
g_Ts = addGoto(sub, 'T_s', 200, 60);
add_line(sub, 'ZOH_Ts/1', [g_Ts '/1'], 'autorouting', 'on');
f_Ts_abs  = addFrom(sub, 'T_s', 280, 60);
f_Ts_sign = addFrom(sub, 'T_s', 560, 180);

g_v = addGoto(sub, 'v', 200, 200);
add_line(sub, 'ZOH_v/1', [g_v '/1'], 'autorouting', 'on');
f_v = addFrom(sub, 'v', 340, 200);

addAbsBlock(sub, 'Abs_Ts', 360, 60);
add_line(sub, [f_Ts_abs '/1'], 'Abs_Ts/1', 'autorouting', 'on');

addLookup2D(sub, 'Lookup_Ta', 500, 100);   % In1 = v, In2 = |T_s|
add_line(sub, [f_v '/1'],   'Lookup_Ta/1', 'autorouting', 'on');
add_line(sub, 'Abs_Ts/1',   'Lookup_Ta/2', 'autorouting', 'on');

addSignBlock(sub, 'Sign_Ts', 640, 180);
add_line(sub, [f_Ts_sign '/1'], 'Sign_Ts/1', 'autorouting', 'on');

addProduct(sub, 'Prod_Ta', '**', 740, 110);   % M(v, |T_s|) * sgn(T_s)
add_line(sub, 'Lookup_Ta/1', 'Prod_Ta/1', 'autorouting', 'on');
add_line(sub, 'Sign_Ts/1',   'Prod_Ta/2', 'autorouting', 'on');
add_line(sub, 'Prod_Ta/1',   'T_a/1',     'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

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

function addSignBlock(sys, name, x, y)
% Sign_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sign', full);
    moveBlock(full, x, y);
end

function addAbsBlock(sys, name, x, y)
% Abs_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Abs', full);
    moveBlock(full, x, y);
end

function addZOH(sys, name, x, y)
% ZOH_<signal>: samples a continuous plant signal at Ts_ctrl (ECU input).
    full = [sys '/' name];
    add_block('simulink/Discrete/Zero-Order Hold', full);
    set_param(full, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addLookup2D(sys, name, x, y)
% Lookup_<result>: 2-D n-D Lookup Table. Input 1 = speed [m/s], input 2 = |T_s|
% [N.m]; table and breakpoints are base-workspace variables (load_map.m).
% Linear interpolation, clipped outside the breakpoints (saturated assist).
    full = [sys '/' name];
    add_block('simulink/Lookup Tables/n-D Lookup Table', full);
    set_param(full, 'NumberOfTableDimensions', '2', ...
        'BreakpointsForDimension1', 'map_v_bp', ...
        'BreakpointsForDimension2', 'map_Ts_bp', ...
        'Table', 'map_Ta_table', ...
        'InterpMethod', 'Linear point-slope', ...
        'ExtrapMethod', 'Clip');
    moveBlock(full, x, y);
end
