%% build_mapopt.m
% Use the Simulink API to build the MapOpt controller block, saved as MapOpt.mdl inside Controllers/MapOpt/. Interface of Sim/script/build_closed_loop.m
% (wired by NAME): In T_s, v (measured); Out T_a (command). The Map law only:
%   u_map = H(z) sgn(T_s) M(v, |T_s|)   dead zone Ts0, calibrated dry-road curve with slope limit Kmax, lead x lag, Tustin Ts_ctrl
% The controller does not clamp T_a and does not model the motor (QuyChuan 2.3). Parameters (MapOpt_*): run Controllers/MapOpt/load_mapopt.m BEFORE building.
% HIERARCHY: MapOpt (In T_s, v; Out T_a) +-- Cal T_a_map (hold, |T_s|, sign, 2-D lookup M) +-- Cal u_map (lead-lag, discrete transfer function)
% Usage:  >> run('<Model>/Controllers/MapOpt/load_mapopt.m');  build_mapopt(true)

function modelName = build_mapopt(overwrite)
if nargin < 1, overwrite = false; end
scriptDir = fileparts(mfilename('fullpath'));
ctlDir    = fileparts(scriptDir);
modelName = 'MapOpt'; if ~overwrite && exist(fullfile(ctlDir, 'MapOpt.mdl'), 'file'), error('build_mapopt:exists', 'MapOpt.mdl exists; call build_mapopt(true) to overwrite'); end
modelPath = fullfile(ctlDir, [modelName '.mdl']);
if bdIsLoaded(modelName), close_system(modelName, 0); end
if exist(modelPath, 'file'), delete(modelPath); end

new_system(modelName);
open_system(modelName);
sub = [modelName '/MapOpt'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'v',       2, 40, 180);
addOutport(sub, 'T_a', 1, 1000, 100);
gt = addGoto(sub, 'T_s', 120, 60);  add_line(sub, 'T_s/1', [gt '/1'], 'autorouting', 'on');
gv = addGoto(sub, 'v', 120, 180);   add_line(sub, 'v/1',   [gv '/1'], 'autorouting', 'on');

% ----- Map branch -----
s1 = [sub '/Cal T_a_map'];
createSubsystem(s1); moveBlock(s1, 300, 60); buildTaMap(s1);
add_line(sub, [addFrom(sub, 'T_s', 200, 60) '/1'], 'Cal T_a_map/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'v',   200, 100) '/1'], 'Cal T_a_map/2', 'autorouting', 'on');
g = addGoto(sub, 'T_a_map', 440, 70); add_line(sub, 'Cal T_a_map/1', [g '/1'], 'autorouting', 'on');
s2 = [sub '/Cal u_map'];
createSubsystem(s2); moveBlock(s2, 620, 60); buildUMap(s2);
add_line(sub, [addFrom(sub, 'T_a_map', 540, 60) '/1'], 'Cal u_map/1', 'autorouting', 'on');
g = addGoto(sub, 'u_map', 780, 70); add_line(sub, 'Cal u_map/1', [g '/1'], 'autorouting', 'on');

add_line(sub, 'Cal u_map/1', 'T_a/1', 'autorouting', 'on');
save_system(modelName, modelPath);
close_system(modelName, 0);
disp(['Created: ' modelPath]);
end

%% ===================== T_a_map = sgn(T_s) * M(v, |T_s|) (as build_map) =====================
function buildTaMap(s)
    addInport(s, 'T_s', 1, 40, 60);
    addInport(s, 'v',   2, 40, 200);
    addOutport(s, 'T_a_map', 1, 760, 120);
    addZoh(s, 'ZOH_T_s', 'MapOpt_Ts_ctrl', 120, 60);
    addZoh(s, 'ZOH_v',   'MapOpt_Ts_ctrl', 120, 200);
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
        'BreakpointsForDimension1', 'MapOpt_v_bp', 'BreakpointsForDimension2', 'MapOpt_Ts_bp', 'Table', 'MapOpt_table', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(lk, 440, 120);
    add_line(s, 'ZOH_v/1', 'Lookup_M/1', 'autorouting', 'on');
    add_line(s, 'Abs_T_s/1', 'Lookup_M/2', 'autorouting', 'on');
    addProduct(s, 'Prod_T_a_map', '**', 620, 120);
    add_line(s, 'Sign_T_s/1', 'Prod_T_a_map/1', 'autorouting', 'on');
    add_line(s, 'Lookup_M/1', 'Prod_T_a_map/2', 'autorouting', 'on');
    add_line(s, 'Prod_T_a_map/1', 'T_a_map/1', 'autorouting', 'on');
end

%% ===================== u_map = H T_a_map (as build_map) =====================
function buildUMap(s)
    addInport(s, 'T_a_map', 1, 40, 60);
    addOutport(s, 'u_map', 1, 360, 60);
    h = [s '/Disc_H'];
    add_block('simulink/Discrete/Discrete Transfer Fcn', h);
    set_param(h, 'Numerator', 'MapOpt_H_num', 'Denominator', 'MapOpt_H_den', 'SampleTime', 'MapOpt_Ts_ctrl');
    moveBlock(h, 160, 40);
    g = addGoto(s, 'T_a_map', 100, 60); add_line(s, 'T_a_map/1', [g '/1'], 'autorouting', 'on');
    f = addFrom(s, 'T_a_map', 100, 100); add_line(s, [f '/1'], 'Disc_H/1', 'autorouting', 'on');
    add_line(s, 'Disc_H/1', 'u_map/1', 'autorouting', 'on');
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
