function modelName = build_map(overwrite)
%BUILD_MAP Build the Map controller block (Documents/Thesis/map.txt section 1.2), saved as Map.mdl in Controllers/Map/.
%
%   Reads ONLY T_s and v (measured), no mu, no e_T, no integral:
%     T_a,map = sgn(T_s) * M(v, |T_s|)                  M: 2-D table, linear interpolation, constant beyond the last point
%     T_a     = H(z) * T_a,map                          H: lead (s/z+1)/(s/p+1) in Tustin form at Ts_ctrl
%
%   Map
%     In : T_s, v                         Out: T_a
%     +-- Cal T_a_map   In : T_s, v       Out: T_a_map     (hold at Ts_ctrl, |T_s|, sign, 2-D lookup M)
%     +-- Cal T_a       In : T_a_map      Out: T_a         (lead)
%
%   Parameters (Map_Ts_ctrl, Map_v_bp, Map_Ts_bp, Map_table, Map_H_num/den): run load_map.m first.
%   Usage: >> build_map            % or build_map(true) to overwrite an existing Map.mdl (false: save as Map_1, ...)
if nargin < 1, overwrite = false; end

scriptDir = fileparts(mfilename('fullpath'));   % Controllers/Map/script
mapDir    = fileparts(scriptDir);               % Controllers/Map/
modelDir  = fileparts(fileparts(mapDir));       % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(mapDir, 'Map', overwrite);
modelPath = fullfile(mapDir, [modelName '.mdl']);
if bdIsLoaded(modelName), close_system(modelName, 0); end
if exist(modelPath, 'file'), delete(modelPath); end

new_system(modelName);
open_system(modelName);
sub = [modelName '/Map'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s', 1, 40, 60);
addInport(sub, 'v',   2, 40, 200);
addOutport(sub, 'T_a', 1, 800, 120);

s1 = [sub '/Cal T_a_map'];
createSubsystem(s1); moveBlock(s1, 300, 60); buildTaMap(s1);
add_line(sub, 'T_s/1', 'Cal T_a_map/1', 'autorouting', 'on');
gv = addGoto(sub, 'v', 120, 200); add_line(sub, 'v/1', [gv '/1'], 'autorouting', 'on');
f = addFrom(sub, 'v', 200, 100); add_line(sub, [f '/1'], 'Cal T_a_map/2', 'autorouting', 'on');
g = addGoto(sub, 'T_a_map', 440, 70); add_line(sub, 'Cal T_a_map/1', [g '/1'], 'autorouting', 'on');

s2 = [sub '/Cal T_a'];
createSubsystem(s2); moveBlock(s2, 620, 120); buildTa(s2);
f = addFrom(sub, 'T_a_map', 540, 110); add_line(sub, [f '/1'], 'Cal T_a/1', 'autorouting', 'on');
add_line(sub, 'Cal T_a/1', 'T_a/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);
end

%% ===================== T_a,map = sgn(T_s) * M(v, |T_s|) =====================
function buildTaMap(s)
    addInport(s, 'T_s', 1, 40, 60);
    addInport(s, 'v',   2, 40, 200);
    addOutport(s, 'T_a_map', 1, 760, 120);
    addZoh(s, 'ZOH_T_s', 'Map_Ts_ctrl', 120, 60);
    addZoh(s, 'ZOH_v',   'Map_Ts_ctrl', 120, 200);
    add_line(s, 'T_s/1', 'ZOH_T_s/1', 'autorouting', 'on');
    add_line(s, 'v/1',   'ZOH_v/1',   'autorouting', 'on');
    gs = addGoto(s, 'T_s', 220, 60); add_line(s, 'ZOH_T_s/1', [gs '/1'], 'autorouting', 'on');
    add_block('simulink/Math Operations/Abs', [s '/Abs_T_s']); moveBlock([s '/Abs_T_s'], 300, 60);
    addSignBlock(s, 'Sign_T_s', 300, 20);
    f = addFrom(s, 'T_s', 220, 100); add_line(s, [f '/1'], 'Abs_T_s/1', 'autorouting', 'on');
    f = addFrom(s, 'T_s', 220, 20);  add_line(s, [f '/1'], 'Sign_T_s/1', 'autorouting', 'on');
    lk = [s '/Lookup_M'];
    add_block('simulink/Lookup Tables/n-D Lookup Table', lk);
    set_param(lk, 'NumberOfTableDimensions', '2', 'BreakpointsSpecification', 'Explicit values', ...
        'BreakpointsForDimension1', 'Map_v_bp', 'BreakpointsForDimension2', 'Map_Ts_bp', 'Table', 'Map_table', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(lk, 440, 120);
    add_line(s, 'ZOH_v/1', 'Lookup_M/1', 'autorouting', 'on');
    add_line(s, 'Abs_T_s/1', 'Lookup_M/2', 'autorouting', 'on');
    addProduct(s, 'Prod_T_a_map', '**', 620, 120);
    add_line(s, 'Sign_T_s/1', 'Prod_T_a_map/1', 'autorouting', 'on');
    add_line(s, 'Lookup_M/1', 'Prod_T_a_map/2', 'autorouting', 'on');
    add_line(s, 'Prod_T_a_map/1', 'T_a_map/1', 'autorouting', 'on');
end

%% ===================== T_a = H T_a,map =====================
function buildTa(s)
    addInport(s, 'T_a_map', 1, 40, 60);
    addOutport(s, 'T_a', 1, 360, 60);
    h = [s '/Disc_H'];
    add_block('simulink/Discrete/Discrete Transfer Fcn', h);
    set_param(h, 'Numerator', 'Map_H_num', 'Denominator', 'Map_H_den', 'SampleTime', 'Map_Ts_ctrl');
    moveBlock(h, 160, 40);
    g = addGoto(s, 'T_a_map', 100, 60); add_line(s, 'T_a_map/1', [g '/1'], 'autorouting', 'on');
    f = addFrom(s, 'T_a_map', 100, 100); add_line(s, [f '/1'], 'Disc_H/1', 'autorouting', 'on');
    add_line(s, 'Disc_H/1', 'T_a/1', 'autorouting', 'on');
end

%% ===================== helpers =====================
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
function addSignBlock(sys, name, x, y)
    full = [sys '/' name]; add_block('simulink/Math Operations/Sign', full); moveBlock(full, x, y);
end
function addZoh(sys, name, tsVar, x, y)
    full = [sys '/' name]; add_block('simulink/Discrete/Zero-Order Hold', full); set_param(full, 'SampleTime', tsVar); moveBlock(full, x, y);
end

