%% build_reference.m
% Build the "Reference" block (T_d,ref(v,a_y)),
% saved as Reference.mdl RIGHT INSIDE the Ref/ folder - the "_s" suffix
% distinguishes it from a hand-formatted version (Reference.mdl). Matches
% Blueprint_OverAssist_RL.txt section 1.3:
%
%   T_d,ref(v, a_y) = sgn(a_y) * LUT(v, |a_y|)   (2-D linear interpolation on
%                     the fine table of Documents/Ref/ref.txt section 1.3:
%                     Table 4 of [5] plus a_y = 0 -> 0, PCHIP-resampled by
%                     Ref/script/make_ref_table.m)
%   The tracking error e_T = T_s - T_d,ref is NOT computed here: each controller that needs it computes it itself
%   (the Map does not use e_T).
%
% Table 4 data are NOT embedded here - read from Model/data/ref.json by
% Model/load_ref.m (separate from load_plant.m); the 2-D Lookup Table only
% references base-workspace variable names (Tdref_v_bp_ms,
% Tdref_ay_bp_ms2, Tdref_table).
%
% Table 4 only has POSITIVE a_y (magnitude, no turning direction): look up
% with |a_y|, then multiply by sign(a_y) so T_d,ref has the same sign as the
% actual steering torque. The table contains a_y = 0 -> 0, so the product is
% continuous when a_y changes sign.
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"):
%
%   Reference
%     In : v, a_y      Out: T_d_ref
%     |
%     +-- Cal T_d_ref   In : v, a_y   Out: T_d_ref
%     |                 (named quantity; "Cal " prefix because the parent
%     |                  also has an output port named T_d_ref)
%
% Usage (run from this folder, Ref/script/):
%   >> run('../../load_ref.m')
%   >> build_reference            % or build_reference(true) to overwrite


function modelName = build_reference(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing Reference.mdl; false: save as Reference_1, ...

assert(evalin('base', 'exist(''Tdref_table'', ''var'')') == 1, ...
    'ref.json not loaded - run load_ref before build_reference.');

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
refDir    = fileparts(scriptDir);               % Ref/
modelDir  = fileparts(fileparts(refDir));       % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(refDir, 'Reference', overwrite);
modelPath = fullfile(refDir, [modelName '.mdl']);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: Reference =======================
sub = [modelName '/Reference'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'v',   1, 40,  60);
addInport(sub, 'a_y', 2, 40, 120);

addOutport(sub, 'T_d_ref', 1, 500, 90);

tdr = [sub '/Cal T_d_ref'];
createSubsystem(tdr);
moveBlock(tdr, 260, 70);
buildCalTdref(tdr);

add_line(sub, 'v/1',   'Cal T_d_ref/1', 'autorouting', 'on');
add_line(sub, 'a_y/1', 'Cal T_d_ref/2', 'autorouting', 'on');
add_line(sub, 'Cal T_d_ref/1', 'T_d_ref/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

end

%% ===================== T_d_ref = sgn(a_y) * LUT(v, |a_y|) ===============
function buildCalTdref(tdr)
% Main line: LUT_Tdref -> Prod_Tdref -> T_d_ref. v enters the LUT directly;
% a_y is used twice (Abs and Sign) -> Goto/From. Sign_ay joins Prod_Tdref
% from below.
    addInport(tdr, 'v',   1, 40,  60);
    addInport(tdr, 'a_y', 2, 40, 160);

    addOutport(tdr, 'T_d_ref', 1, 560, 70);

    g_ay = addGoto(tdr, 'a_y', 120, 160);
    add_line(tdr, 'a_y/1', [g_ay '/1'], 'autorouting', 'on');
    f_ay_abs = addFrom(tdr, 'a_y', 120, 100);
    f_ay_sgn = addFrom(tdr, 'a_y', 300, 200);

    full = [tdr '/Abs_ay'];
    add_block('simulink/Math Operations/Abs', full);
    moveBlock(full, 200, 100);
    addSignBlock(tdr, 'Sign_ay', 380, 200);

    full = [tdr '/LUT_Tdref'];
    add_block('simulink/Lookup Tables/2-D Lookup Table', full);
    set_param(full, 'Table', 'Tdref_table', ...
        'BreakpointsForDimension1', 'Tdref_v_bp_ms', ...
        'BreakpointsForDimension2', 'Tdref_ay_bp_ms2', ...
        'InterpMethod', 'Linear', 'ExtrapMethod', 'Clip');
    moveBlock(full, 300, 60);

    addProduct(tdr, 'Prod_Tdref', '**', 460, 70);   % sgn(a_y) * LUT

    add_line(tdr, 'v/1',           'LUT_Tdref/1', 'autorouting', 'on');
    add_line(tdr, [f_ay_abs '/1'], 'Abs_ay/1',    'autorouting', 'on');
    add_line(tdr, 'Abs_ay/1',      'LUT_Tdref/2', 'autorouting', 'on');
    add_line(tdr, [f_ay_sgn '/1'], 'Sign_ay/1',   'autorouting', 'on');
    add_line(tdr, 'LUT_Tdref/1',   'Prod_Tdref/1', 'autorouting', 'on');
    add_line(tdr, 'Sign_ay/1',     'Prod_Tdref/2', 'autorouting', 'on');
    add_line(tdr, 'Prod_Tdref/1',  'T_d_ref/1',   'autorouting', 'on');
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

function nm = addConstant(sys, baseWorkspaceVar, x, y)
% Constant block, DEFAULT name (Constant, Constant1, ...); Value points
% STRAIGHT to a base-workspace variable name (or a literal such as '3').
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'Value', baseWorkspaceVar);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
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

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addTrigFcn(sys, name, op, x, y)
% Trig_<function>_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Trigonometric Function', full);
    set_param(full, 'Operator', op);
    moveBlock(full, x, y);
end

function addSignBlock(sys, name, x, y)
% Sign_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sign', full);
    moveBlock(full, x, y);
end

function addIntegrator(sys, name, x, y)
% Int_<state variable>
    full = [sys '/' name];
    add_block('simulink/Continuous/Integrator', full);
    moveBlock(full, x, y);
end
