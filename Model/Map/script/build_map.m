%% build_map.m
% Use the Simulink API to build the conventional EPS assist controller
% (baseline) as its own subsystem, saved as Map_s.mdl RIGHT INSIDE the Map/
% folder (parent of this script). Matches Documents/Map/map.txt:
%
%   T_s[k], v[k] sampled at Ts_ctrl (ZOH)
%   T_a_map[k] = sgn(T_s[k]) * M(v[k], |T_s[k]|)        torque map (2-D table)
%   T_a_c      = H(z)^2 * T_a_map                        two lead stages
%   T_a_max[k] = T_a,max(v[k])                           1-D table
%   T_a        = max(-T_a_max, min(T_a_c, T_a_max))      saturation
%
% M, T_a,max and the lead coefficients come from Map/script/calibrate_map.m
% (data/map.json) through the base workspace (run Model/load_map.m first).
% The controller has no integrator and does not know mu.
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink"):
%
%   Map                 In : T_s, v          Out: T_a
%     +-- T_a_map       In : T_s, v          Out: T_a_map
%     +-- T_a_c         In : T_a_map         Out: T_a_c
%     +-- T_a_max       In : v               Out: T_a_max
%     +-- Cal T_a       In : T_a_c, T_a_max  Out: T_a   ("Cal " prefix: the
%                                                        parent has an output
%                                                        port named T_a)
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
addInport(sub, 'v',   2, 40, 260);
addOutport(sub, 'T_a', 1, 1000, 160);

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
g = addGoto(sub, 'T_a_c', 760, 70);   add_line(sub, 'T_a_c/1', [g '/1'], 'autorouting', 'on');

% T_a_max
s3 = [sub '/T_a_max'];
createSubsystem(s3); moveBlock(s3, 360, 260); buildTaMax(s3);
f = addFrom(sub, 'v', 290, 260); add_line(sub, [f '/1'], 'T_a_max/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a_max', 480, 270); add_line(sub, 'T_a_max/1', [g '/1'], 'autorouting', 'on');

% Cal T_a (saturation)
s4 = [sub '/Cal T_a'];
createSubsystem(s4); moveBlock(s4, 860, 150); buildCalTa(s4);
f = addFrom(sub, 'T_a_c',   790, 150); add_line(sub, [f '/1'], 'Cal T_a/1', 'autorouting', 'on');
f = addFrom(sub, 'T_a_max', 790, 190); add_line(sub, [f '/1'], 'Cal T_a/2', 'autorouting', 'on');
add_line(sub, 'Cal T_a/1', 'T_a/1', 'autorouting', 'on');

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

%% ===================== T_a_c = H(z)^2 * T_a_map ========================
function buildTaC(s)
    addInport(s, 'T_a_map', 1, 40, 60);
    addOutport(s, 'T_a_c', 1, 440, 60);
    addLead(s, 'Lead_1', 150, 50);
    addLead(s, 'Lead_2', 290, 50);
    add_line(s, 'T_a_map/1', 'Lead_1/1', 'autorouting', 'on');
    add_line(s, 'Lead_1/1',  'Lead_2/1', 'autorouting', 'on');
    add_line(s, 'Lead_2/1',  'T_a_c/1',  'autorouting', 'on');
end

%% ===================== T_a_max = T_a,max(v) ============================
function buildTaMax(s)
    addInport(s, 'v', 1, 40, 60);
    addOutport(s, 'T_a_max', 1, 320, 60);
    full = [s '/Lookup_Tamax'];
    add_block('simulink/Lookup Tables/1-D Lookup Table', full);
    set_param(full, 'Table', 'map_Tamax', 'BreakpointsForDimension1', 'map_v_bp', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(full, 160, 50);
    add_line(s, 'v/1', 'Lookup_Tamax/1', 'autorouting', 'on');
    add_line(s, 'Lookup_Tamax/1', 'T_a_max/1', 'autorouting', 'on');
end

%% ===================== T_a = max(-T_a_max, min(T_a_c, T_a_max)) =========
function buildCalTa(s)
    addInport(s, 'T_a_c',   1, 40, 60);
    addInport(s, 'T_a_max', 2, 40, 180);
    addOutport(s, 'T_a', 1, 560, 70);
    g = addGoto(s, 'T_a_max', 110, 180); add_line(s, 'T_a_max/1', [g '/1'], 'autorouting', 'on');
    fMin = addFrom(s, 'T_a_max', 190, 110);
    fNeg = addFrom(s, 'T_a_max', 190, 200);
    addMinMax(s, 'Min_Ta', 'min', 300, 60);
    add_line(s, 'T_a_c/1', 'Min_Ta/1', 'autorouting', 'on');
    add_line(s, [fMin '/1'], 'Min_Ta/2', 'autorouting', 'on');
    full = [s '/Neg_Tamax'];
    add_block('simulink/Math Operations/Unary Minus', full);
    moveBlock(full, 300, 200);
    add_line(s, [fNeg '/1'], 'Neg_Tamax/1', 'autorouting', 'on');
    addMinMax(s, 'Max_Ta', 'max', 440, 70);
    add_line(s, 'Min_Ta/1',    'Max_Ta/1', 'autorouting', 'on');
    add_line(s, 'Neg_Tamax/1', 'Max_Ta/2', 'autorouting', 'on');
    add_line(s, 'Max_Ta/1', 'T_a/1', 'autorouting', 'on');
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

function addMinMax(sys, name, fcn, x, y)
% Min_<result> / Max_<result>: two-input MinMax block.
    full = [sys '/' name];
    add_block('simulink/Math Operations/MinMax', full);
    set_param(full, 'Function', fcn, 'Inputs', '2');
    moveBlock(full, x, y);
end

function addZOH(sys, name, x, y)
% ZOH_<signal>: samples a continuous plant signal at Ts_ctrl (ECU input).
    full = [sys '/' name];
    add_block('simulink/Discrete/Zero-Order Hold', full);
    set_param(full, 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addLead(sys, name, x, y)
% Lead_<n>: one discrete lead stage (Tustin), coefficients from load_map.m.
    full = [sys '/' name];
    add_block('simulink/Discrete/Discrete Transfer Fcn', full);
    set_param(full, 'Numerator', 'map_lead_num', 'Denominator', 'map_lead_den', 'SampleTime', 'Ts_ctrl');
    moveBlock(full, x, y);
end

function addLookup2D(sys, name, x, y)
% Lookup_<result>: 2-D n-D Lookup Table. Input 1 = speed [m/s], input 2 = |T_s|
% [N.m]; table and breakpoints are base-workspace variables (load_map.m).
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
