%% build_mappidlag.m
% Use the Simulink API to build the MapPIDLag controller block, saved as MapPIDLag.mdl inside Controllers/MapPIDLag/. Interface of Sim/script/build_closed_loop.m
% (wired by NAME): In T_s, v, a_y (measured), T_a_lim (command after the assist limit); Out T_a (command). Two parallel branches are summed, then the SUM
% goes through one lag (DieuKhien_MapPIDLag.txt B1); there is no lead:
%
%   u_map    = sgn(T_s) M(v, |T_s|)             Map branch (dead zone, calibrated curve with slope limit Kmax, Tustin sample Ts_ctrl)
%   e_T      = T_s - T_d,ref(v, a_y)            PID branch: d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]), a = Tf/(Tf+Ts), b = Kd/(Tf+Ts)
%   u[k]     = u_map[k] + Kp e[k] + u_I[k] + d[k]
%   T_a      = H_lag(z) u                        H_lag(s) = (s/z1 + 1)/(s/p1 + 1), p1 <= z1, Tustin, DC gain 1
%   u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k])),  Kaw = Ki/(Kp + Kmax)   back-calculation on the command AFTER the lag
% The controller does not clamp T_a and does not model the motor (QuyChuan 2.3).
%
% HIERARCHY (CLAUDE.md, "Quy tac dung model Simulink"):
%
%   MapPIDLag            In : T_s, v, a_y, T_a_lim    Out: T_a
%     +-- Cal T_a_map    In : T_s, v                  Out: T_a_map   (hold, |T_s|, sign, 2-D lookup M)
%     +-- Reference      In : v, a_y                  Out: T_d_ref   (copy of PRSM/Ref/Reference)
%     +-- Sum_eT, Prod_P, Prod_Ki, Sum_aw, Prod_Kaw, Sum_dI, Int_uI, UD_Ts, Sum_dTs, Prod_b, UD_d, Prod_a, Sum_d   (PID branch with back-calculation)
%     +-- Sum_u          u_map + u_P + u_I + u_D -> u
%     +-- Cal T_a        In : u                       Out: T_a       (lag, discrete transfer function)
%
% Parameters (MapPIDLag_*): run Model/Controllers/MapPIDLag/load_mappidlag.m BEFORE building. The model reads ONLY MapPIDLag_* variables, so a tuning
% run can change the table, the lag and the PID gains with setVariable.
%
% Usage:  >> run('<Model>/Controllers/MapPIDLag/load_mappidlag.m');  build_mappidlag        % or build_mappidlag(true) to overwrite

function modelName = build_mappidlag(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing MapPIDLag.mdl; false: save as MapPIDLag_1, MapPIDLag_2, ...

scriptDir = fileparts(mfilename('fullpath'));   % MapPIDLag/script
ctlDir    = fileparts(scriptDir);               % MapPIDLag/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
modelName = pickName(ctlDir, 'MapPIDLag', overwrite);
modelPath = fullfile(ctlDir, [modelName '.mdl']);
if bdIsLoaded(modelName), close_system(modelName, 0); end
if exist(modelPath, 'file'), delete(modelPath); end

refFile = fullfile(modelDir, 'PRSM', 'Ref', 'Reference.mdl');
if ~bdIsLoaded('Reference'), load_system(refFile); end
refSub = find_system('Reference', 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(refSub) == 1, 'Reference.mdl must have exactly 1 root subsystem');

new_system(modelName);
open_system(modelName);
sub = [modelName '/MapPIDLag'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'T_s',     1, 40,  60);
addInport(sub, 'v',       2, 40, 180);
addInport(sub, 'a_y',     3, 40, 300);
addInport(sub, 'T_a_lim', 4, 40, 620);
addOutport(sub, 'T_a', 1, 1700, 160);
gt = addGoto(sub, 'T_s', 120, 60);  add_line(sub, 'T_s/1', [gt '/1'], 'autorouting', 'on');
gv = addGoto(sub, 'v', 120, 180);   add_line(sub, 'v/1',   [gv '/1'], 'autorouting', 'on');

% ----- Map branch -----
s1 = [sub '/Cal T_a_map'];
createSubsystem(s1); moveBlock(s1, 300, 60); buildTaMap(s1);
add_line(sub, [addFrom(sub, 'T_s', 200, 60) '/1'], 'Cal T_a_map/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'v',   200, 100) '/1'], 'Cal T_a_map/2', 'autorouting', 'on');
g = addGoto(sub, 'u_map', 440, 70); add_line(sub, 'Cal T_a_map/1', [g '/1'], 'autorouting', 'on');

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
add_line(sub, [addConstant(sub, 'MapPIDLag_Kp', 780, 300) '/1'], 'Prod_P/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 780, 360) '/1'], 'Prod_P/2', 'autorouting', 'on');
g = addGoto(sub, 'u_P', 960, 340); add_line(sub, 'Prod_P/1', [g '/1'], 'autorouting', 'on');

% ----- integrator input Ki e_T + Kaw (T_a_lim - T_a), T_a = the command after the lag -----
addProduct(sub, 'Prod_Ki', '**', 860, 460);
add_line(sub, [addConstant(sub, 'MapPIDLag_Ki', 780, 430) '/1'], 'Prod_Ki/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'e_T', 780, 490) '/1'], 'Prod_Ki/2', 'autorouting', 'on');
addSum(sub, 'Sum_aw', '+-', 560, 620);
add_line(sub, 'T_a_lim/1', 'Sum_aw/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'T_a', 480, 660) '/1'], 'Sum_aw/2', 'autorouting', 'on');
addProduct(sub, 'Prod_Kaw', '**', 860, 600);
add_line(sub, [addConstant(sub, 'MapPIDLag_Kaw', 780, 570) '/1'], 'Prod_Kaw/1', 'autorouting', 'on');
add_line(sub, 'Sum_aw/1', 'Prod_Kaw/2', 'autorouting', 'on');
addSum(sub, 'Sum_dI', '++', 1000, 520);
add_line(sub, 'Prod_Ki/1',  'Sum_dI/1', 'autorouting', 'on');
add_line(sub, 'Prod_Kaw/1', 'Sum_dI/2', 'autorouting', 'on');

% ----- u_I: discrete-time integrator, forward Euler, sample time MapPIDLag_Ts_ctrl (no direct feedthrough: breaks the loop through the lag) -----
full = [sub '/Int_uI'];
add_block('simulink/Discrete/Discrete-Time Integrator', full);
set_param(full, 'IntegratorMethod', 'Integration: Forward Euler', 'SampleTime', 'MapPIDLag_Ts_ctrl', 'gainval', '1', 'InitialCondition', '0');
moveBlock(full, 1120, 520);
add_line(sub, 'Sum_dI/1', 'Int_uI/1', 'autorouting', 'on');
g = addGoto(sub, 'u_I', 1220, 530); add_line(sub, 'Int_uI/1', [g '/1'], 'autorouting', 'on');

% ----- derivative on the measured T_s: d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]); the unit delays break every algebraic loop -----
addUnitDelay(sub, 'UD_Ts', 'MapPIDLag_Ts_ctrl', 40, 760);
add_line(sub, [addFrom(sub, 'T_s', 0, 740) '/1'], 'UD_Ts/1', 'autorouting', 'on');
addSum(sub, 'Sum_dTs', '+-', 200, 760);
add_line(sub, [addFrom(sub, 'T_s', 120, 740) '/1'], 'Sum_dTs/1', 'autorouting', 'on');
add_line(sub, 'UD_Ts/1', 'Sum_dTs/2', 'autorouting', 'on');
addProduct(sub, 'Prod_b', '**', 360, 760);
add_line(sub, [addConstant(sub, 'MapPIDLag_Kd/(MapPIDLag_Tf+MapPIDLag_Ts_ctrl)', 280, 720) '/1'], 'Prod_b/1', 'autorouting', 'on');
add_line(sub, 'Sum_dTs/1', 'Prod_b/2', 'autorouting', 'on');
addUnitDelay(sub, 'UD_d', 'MapPIDLag_Ts_ctrl', 360, 880);
addProduct(sub, 'Prod_a', '**', 520, 880);
add_line(sub, [addConstant(sub, 'MapPIDLag_Tf/(MapPIDLag_Tf+MapPIDLag_Ts_ctrl)', 440, 840) '/1'], 'Prod_a/1', 'autorouting', 'on');
add_line(sub, 'UD_d/1', 'Prod_a/2', 'autorouting', 'on');
addSum(sub, 'Sum_d', '++', 680, 820);
add_line(sub, 'Prod_b/1', 'Sum_d/1', 'autorouting', 'on');
add_line(sub, 'Prod_a/1', 'Sum_d/2', 'autorouting', 'on');
add_line(sub, 'Sum_d/1', 'UD_d/1', 'autorouting', 'on');
g = addGoto(sub, 'u_D', 780, 830); add_line(sub, 'Sum_d/1', [g '/1'], 'autorouting', 'on');

% ----- u = u_map + u_P + u_I + u_D -----
addSum(sub, 'Sum_u', '++++', 1360, 150);
add_line(sub, [addFrom(sub, 'u_map', 1260, 120) '/1'], 'Sum_u/1', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_P',   1260, 160) '/1'], 'Sum_u/2', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_I',   1260, 200) '/1'], 'Sum_u/3', 'autorouting', 'on');
add_line(sub, [addFrom(sub, 'u_D',   1260, 240) '/1'], 'Sum_u/4', 'autorouting', 'on');
g = addGoto(sub, 'u', 1440, 160); add_line(sub, 'Sum_u/1', [g '/1'], 'autorouting', 'on');

% ----- T_a = lag(u) -----
s2 = [sub '/Cal T_a'];
createSubsystem(s2); moveBlock(s2, 1520, 140); buildTa(s2);
add_line(sub, [addFrom(sub, 'u', 1480, 100) '/1'], 'Cal T_a/1', 'autorouting', 'on');
add_line(sub, 'Cal T_a/1', 'T_a/1', 'autorouting', 'on');
g = addGoto(sub, 'T_a', 1640, 260); add_line(sub, 'Cal T_a/1', [g '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
close_system('Reference', 0);
fprintf('Created: %s\n', modelPath);
end

%% ===================== T_a_map = sgn(T_s) * M(v, |T_s|) (as build_map) =====================
function buildTaMap(s)
    addInport(s, 'T_s', 1, 40, 60);
    addInport(s, 'v',   2, 40, 200);
    addOutport(s, 'T_a_map', 1, 760, 120);
    addZoh(s, 'ZOH_T_s', 'MapPIDLag_Ts_ctrl', 120, 60);
    addZoh(s, 'ZOH_v',   'MapPIDLag_Ts_ctrl', 120, 200);
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
        'BreakpointsForDimension1', 'MapPIDLag_v_bp', 'BreakpointsForDimension2', 'MapPIDLag_Ts_bp', 'Table', 'MapPIDLag_table', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(lk, 440, 120);
    add_line(s, 'ZOH_v/1', 'Lookup_M/1', 'autorouting', 'on');
    add_line(s, 'Abs_T_s/1', 'Lookup_M/2', 'autorouting', 'on');
    addProduct(s, 'Prod_T_a_map', '**', 620, 120);
    add_line(s, 'Sign_T_s/1', 'Prod_T_a_map/1', 'autorouting', 'on');
    add_line(s, 'Lookup_M/1', 'Prod_T_a_map/2', 'autorouting', 'on');
    add_line(s, 'Prod_T_a_map/1', 'T_a_map/1', 'autorouting', 'on');
end

%% ===================== T_a = H_lag u =====================
function buildTa(s)
    addInport(s, 'u', 1, 40, 60);
    addOutport(s, 'T_a', 1, 360, 60);
    h = [s '/Disc_H'];
    add_block('simulink/Discrete/Discrete Transfer Fcn', h);
    set_param(h, 'Numerator', 'MapPIDLag_H_num', 'Denominator', 'MapPIDLag_H_den', 'SampleTime', 'MapPIDLag_Ts_ctrl');
    moveBlock(h, 160, 40);
    g = addGoto(s, 'u', 100, 60); add_line(s, 'u/1', [g '/1'], 'autorouting', 'on');
    f = addFrom(s, 'u', 100, 100); add_line(s, [f '/1'], 'Disc_H/1', 'autorouting', 'on');
    add_line(s, 'Disc_H/1', 'T_a/1', 'autorouting', 'on');
end

%% ===================== Model name that never silently replaces a file =====================
function name = pickName(folder, baseName, overwrite)
    name = baseName;
    if overwrite || ~exist(fullfile(folder, [name '.mdl']), 'file') && ~bdIsLoaded(name), return; end
    k = 1;
    while exist(fullfile(folder, sprintf('%s_%d.mdl', baseName, k)), 'file') || bdIsLoaded(sprintf('%s_%d', baseName, k)), k = k + 1; end
    name = sprintf('%s_%d', baseName, k);
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
