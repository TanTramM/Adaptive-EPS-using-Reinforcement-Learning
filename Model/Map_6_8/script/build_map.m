%% build_map.m
% Use the Simulink API to build the conventional EPS assist controller
% (baseline) as its own subsystem, saved as Map_6_8_s.mdl RIGHT INSIDE the Map/
% folder (parent of this script). Matches Documents/Map_6_8/map.txt:
%
%   T_s[k], v[k] sampled at Ts_ctrl (ZOH)
%   T_a_map[k] = sgn(T_s[k]) * M(v[k], |T_s[k]|)        torque map (2-D table)
%   T_a        = (1 - w(v)) * H_low(z) * T_a_map + w(v) * H_high(z) * T_a_map
%                one lead stage per speed tier (K_max = 8 for v <= 60 km/h, 6 for v >= 65 km/h), blended by the speed
%
% M and the lead coefficients come from Map/script/calibrate_map.m
% (data/map_6_8.json) through the base workspace (run Model/load_map_6_8.m first).
% The controller has no integrator, does not know mu and does not compute e_T. The assist limit T_a,max(v) and the
% motor delay are NOT here: they are in the Actuator block of the closed loop (Model/Actuator/).
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   Map                 In : T_s, v          Out: T_a
%     +-- T_a_map       In : T_s, v          Out: T_a_map
%     +-- T_a_c         In : T_a_map, v      Out: T_a_c   (wired to the output T_a)
%
% Usage (run from this folder, Map/script/):
%   >> run('../../load_map_6_8.m')
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
addInport(sub, 'v',   2, 40, 260);
addOutport(sub, 'T_a', 1, 900, 80);

% sampled inputs (ECU reads the sensors at Ts_ctrl)
addZOH(sub, 'ZOH_Ts', 120, 60);
addZOH(sub, 'ZOH_v',  120, 260);
add_line(sub, 'T_s/1', 'ZOH_Ts/1', 'autorouting', 'on');
add_line(sub, 'v/1',   'ZOH_v/1',  'autorouting', 'on');
g = addGoto(sub, 'T_s', 200, 60);  add_line(sub, 'ZOH_Ts/1', [g '/1'], 'autorouting', 'on');
g = addGoto(sub, 'v',   200, 260); add_line(sub, 'ZOH_v/1',  [g '/1'], 'autorouting', 'on');

% T_a_map
s1 = [sub '/T_a_map'];
createSubsystem(s1); moveBlock(s1, 360, 60); buildTaMap(s1);
f = addFrom(sub, 'T_s', 290, 60);  add_line(sub, [f '/1'], 'T_a_map/1', 'autorouting', 'on');
f = addFrom(sub, 'v',   290, 100); add_line(sub, [f '/1'], 'T_a_map/2', 'autorouting', 'on');
g = addGoto(sub, 'T_a_map', 480, 70); add_line(sub, 'T_a_map/1', [g '/1'], 'autorouting', 'on');

% T_a_c
s2 = [sub '/T_a_c'];
createSubsystem(s2); moveBlock(s2, 640, 60); buildTaC(s2);
f = addFrom(sub, 'T_a_map', 570, 70); add_line(sub, [f '/1'], 'T_a_c/1', 'autorouting', 'on');
f = addFrom(sub, 'v',       570, 110); add_line(sub, [f '/1'], 'T_a_c/2', 'autorouting', 'on');

add_line(sub, 'T_a_c/1', 'T_a/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);

%% ===================== T_a_map = sgn(T_s) * M(v, |T_s|) ================
function buildTaMap(s)
    addInport(s, 'T_s', 1, 40, 60);
    addInport(s, 'v',   2, 40, 160);
    addOutport(s, 'T_a_map', 1, 640, 100);
    g = addGoto(s, 'T_s', 110, 60); add_line(s, 'T_s/1', [g '/1'], 'autorouting', 'on');
    fAbs = addFrom(s, 'T_s', 180, 60);
    fSgn = addFrom(s, 'T_s', 380, 200);
    addAbsBlock(s, 'Abs_Ts', 260, 60);
    add_line(s, [fAbs '/1'], 'Abs_Ts/1', 'autorouting', 'on');
    addLookup2D(s, 'Lookup_Ta', 380, 100);        % In1 = v, In2 = |T_s|
    add_line(s, 'v/1',      'Lookup_Ta/1', 'autorouting', 'on');
    add_line(s, 'Abs_Ts/1', 'Lookup_Ta/2', 'autorouting', 'on');
    addSignBlock(s, 'Sign_Ts', 460, 200);
    add_line(s, [fSgn '/1'], 'Sign_Ts/1', 'autorouting', 'on');
    addProduct(s, 'Prod_Ta_map', '**', 540, 100);
    add_line(s, 'Lookup_Ta/1', 'Prod_Ta_map/1', 'autorouting', 'on');
    add_line(s, 'Sign_Ts/1',   'Prod_Ta_map/2', 'autorouting', 'on');
    add_line(s, 'Prod_Ta_map/1', 'T_a_map/1', 'autorouting', 'on');
end

%% ===================== T_a_c = (1 - w(v)) * H_low(z) * T_a_map + w(v) * H_high(z) * T_a_map ========
function buildTaC(s)
% Two lead stages, one designed for the K_max of the low speeds and one for the K_max of the high speeds; both have DC gain 1.
% w(v) is 0 up to 60 km/h and 1 from 65 km/h (linear in between): base workspace map_blend_v [m/s], map_blend_w (load_map_6_8.m).
    addInport(s, 'T_a_map', 1, 40, 60);
    addInport(s, 'v',       2, 40, 220);
    addOutport(s, 'T_a_c', 1, 760, 110);
    addLead(s, 'Lead_low',  'map_lead_num',    'map_lead_den',    200, 20);
    addLead(s, 'Lead_high', 'map_lead_hi_num', 'map_lead_hi_den', 200, 120);
    full = [s '/Lookup_w'];
    add_block('simulink/Lookup Tables/1-D Lookup Table', full);
    set_param(full, 'Table', 'map_blend_w', 'BreakpointsForDimension1', 'map_blend_v', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(full, 200, 210);
    g = addGoto(s, 'w', 340, 220); add_line(s, 'Lookup_w/1', [g '/1'], 'autorouting', 'on');
    addSum(s, 'Sum_1mw', '-+', 440, 270);          % 1 - w
    h = addConstant(s, '1', 380, 310);
    add_line(s, [h '/1'], 'Sum_1mw/2', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'w', 380, 260) '/1'], 'Sum_1mw/1', 'autorouting', 'on');
    addProduct(s, 'Prod_low',  '**', 540, 30);
    addProduct(s, 'Prod_high', '**', 540, 130);
    addSum(s, 'Sum_Tac', '++', 660, 100);
    add_line(s, 'v/1', 'Lookup_w/1', 'autorouting', 'on');
    add_line(s, 'T_a_map/1', 'Lead_low/1',  'autorouting', 'on');
    add_line(s, 'T_a_map/1', 'Lead_high/1', 'autorouting', 'on');
    add_line(s, 'Lead_low/1',  'Prod_low/1',  'autorouting', 'on');
    add_line(s, 'Sum_1mw/1',   'Prod_low/2',  'autorouting', 'on');
    add_line(s, 'Lead_high/1', 'Prod_high/1', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'w', 480, 190) '/1'], 'Prod_high/2', 'autorouting', 'on');
    add_line(s, 'Prod_low/1',  'Sum_Tac/1', 'autorouting', 'on');
    add_line(s, 'Prod_high/1', 'Sum_Tac/2', 'autorouting', 'on');
    add_line(s, 'Sum_Tac/1', 'T_a_c/1', 'autorouting', 'on');
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

function nm = addGoto(sys, tag, x, y)
% Goto block, DEFAULT name; LOCAL scope only. tag is the plain variable name.
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

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function nm = addConstant(sys, value, x, y)
% Constant block, DEFAULT name; Value is a literal or a base-workspace variable name.
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], 'MakeNameUnique', 'on');
    set_param(h, 'Value', value);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addZOH(sys, name, x, y)
% ZOH_<signal>: samples a continuous plant signal at Ts_ctrl (ECU input).
    full = [sys '/' name];
    add_block('simulink/Discrete/Zero-Order Hold', full);
    set_param(full, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addLead(sys, name, numVar, denVar, x, y)
% Lead_<tier>: a discrete lead stage (Tustin), coefficients are base-workspace variables set by load_map_6_8.m.
    full = [sys '/' name];
    add_block('simulink/Discrete/Discrete Transfer Fcn', full);
    set_param(full, 'Numerator', numVar, 'Denominator', denVar, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addLookup2D(sys, name, x, y)
% Lookup_<result>: 2-D n-D Lookup Table. Input 1 = speed [m/s], input 2 = |T_s|
% [N.m]; table and breakpoints are base-workspace variables (load_map_6_8.m).
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
