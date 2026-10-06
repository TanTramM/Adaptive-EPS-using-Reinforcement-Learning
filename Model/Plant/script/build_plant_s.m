%% build_plant_s.m
% Regenerate the 3 cluster models WITH the "_s" suffix (by calling
% build_cum1, build_cum2, build_cum3 - always fresh), then assemble them
% into 1 model Plant_s.mdl, saved RIGHT INSIDE the Plant/ folder.
% Counterpart: build_plant.m (assembles the HAND-FORMATTED trio, no "_s",
% without regenerating them).
%
% Ports are wired by NAME (found via find_system), not by port number - so
% this works regardless of how the 3 source models order their ports.
%
% Cluster interfaces (see Cum1_CEPS.txt, Cum2_Pacejka.txt, Cum3_2DOF.txt):
%   SteeringColumn  In : theta1, T_a, T_r         Out: T_s, theta2, theta2_dot
%   Tires           In : theta2, beta, gamma, v, mu   Out: F_yf, F_yr, T_r
%   Bike2DOF        In : F_yf, F_yr, v            Out: beta, gamma, a_y
%
% Plant interface:
%   In : theta1 (driver steering-wheel angle, measured), T_a (MV, from the
%        controller), v (measured DV), mu (unmeasured DV)
%   Out: only the signals a sensor can measure: T_s (CV), a_y (for T_d,ref(v,a_y)), gamma,
%        theta2_dot (column speed from the motor encoder). theta2 and beta stay inside (Tires needs them), not exposed.
%
% Wiring (matches Documents/HeThongPlant_TongHop.txt):
%   theta1, T_a               -> SteeringColumn         (direct)
%   mu                        -> Tires                  (direct)
%   v                         -> Tires, Bike2DOF        (Goto/From, 2 dest.)
%   SteeringColumn.theta2     -> Tires                  (Goto/From)
%   Tires.F_yf, F_yr          -> Bike2DOF               (direct)
%   Tires.T_r                 -> SteeringColumn.T_r     (FEEDBACK loop 1)
%   Bike2DOF.beta, gamma      -> Tires ; gamma -> Out   (FEEDBACK loop 2)
%   SteeringColumn.T_s, theta2_dot, Bike2DOF.a_y -> Out (direct)
%
% Feedback signals flow backward relative to the left-to-right layout
% (SteeringColumn -> Tires -> Bike2DOF) - routed via Goto/From so no wire
% loops back across the diagram.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_plant.m')
%   >> build_plant_s

regenerateClusterModels();

modelName = 'Plant_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelPath = fullfile(plantDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

srcFiles = struct('steer', 'SteeringColumn_s', 'tires', 'Tires_s', 'bike', 'Bike2DOF_s');
assemblePlant(modelName, modelPath, plantDir, srcFiles);

%% ===================== Regenerate the 3 "_s" cluster models =============
function regenerateClusterModels()
% Calling build_cum1/2/3 inside a LOCAL FUNCTION keeps their script-level
% variables (modelName, sub, ...) in this function's own workspace - they
% do not overwrite build_plant_s.m's variables of the same name.
    build_cum1;
    build_cum2;
    build_cum3;
end

%% ===================== Assemble Plant from 3 source models ===============
function assemblePlant(modelName, modelPath, plantDir, srcFiles)
    fn = fieldnames(srcFiles);
    for i = 1:numel(fn)
        nm = srcFiles.(fn{i});
        if bdIsLoaded(nm)
            close_system(nm, 0);
        end
        load_system(fullfile(plantDir, [nm '.mdl']));
    end

    new_system(modelName);
    open_system(modelName);

    sub = [modelName '/Plant'];
    createSubsystem(sub);
    moveBlock(sub, 50, 50);

    add_block(findRootSubsystem(srcFiles.steer), [sub '/SteeringColumn']);
    moveBlock([sub '/SteeringColumn'], 300, 60);
    add_block(findRootSubsystem(srcFiles.tires), [sub '/Tires']);
    moveBlock([sub '/Tires'], 700, 60);
    add_block(findRootSubsystem(srcFiles.bike), [sub '/Bike2DOF']);
    moveBlock([sub '/Bike2DOF'], 1100, 60);

    steer = [sub '/SteeringColumn'];
    tires = [sub '/Tires'];
    bike  = [sub '/Bike2DOF'];

    %% ----- External inputs (left edge) -----
    addInport(sub, 'theta1', 1, 40,  60);
    addInport(sub, 'T_a',    2, 40, 140);
    addInport(sub, 'v',      3, 40, 400);
    addInport(sub, 'mu',     4, 40, 480);

    %% ----- External outputs (right edge) -----
    addOutport(sub, 'T_s',        1, 1500,  60);
    addOutport(sub, 'a_y',        2, 1500, 140);
    addOutport(sub, 'gamma',      3, 1500, 220);
    addOutport(sub, 'theta2_dot', 4, 1500, 300);

    %% ----- Forward, single destination: wire directly -----
    add_line(sub, 'theta1/1', portRef(steer, 'theta1'), 'autorouting', 'on');
    add_line(sub, 'T_a/1',    portRef(steer, 'T_a'),    'autorouting', 'on');
    add_line(sub, 'mu/1',     portRef(tires, 'mu'),     'autorouting', 'on');

    add_line(sub, portRef(tires, 'F_yf'), portRef(bike, 'F_yf'), 'autorouting', 'on');
    add_line(sub, portRef(tires, 'F_yr'), portRef(bike, 'F_yr'), 'autorouting', 'on');

    add_line(sub, portRef(steer, 'T_s'), 'T_s/1', 'autorouting', 'on');
    add_line(sub, portRef(bike, 'a_y'),  'a_y/1', 'autorouting', 'on');
    add_line(sub, portRef(steer, 'theta2_dot'), 'theta2_dot/1', 'autorouting', 'on');

    %% ----- v: 2 destinations (Tires, Bike2DOF) -> Goto/From -----
    g_v = addGoto(sub, 'v', 120, 400);
    add_line(sub, 'v/1', [g_v '/1'], 'autorouting', 'on');
    f_v_tires = addFrom(sub, 'v', 620, 300);
    add_line(sub, [f_v_tires '/1'], portRef(tires, 'v'), 'autorouting', 'on');
    f_v_bike = addFrom(sub, 'v', 1020, 260);
    add_line(sub, [f_v_bike '/1'], portRef(bike, 'v'), 'autorouting', 'on');

    %% ----- theta2: SteeringColumn -> Tires (internal only) -> Goto/From -----
    g_th2 = addGoto(sub, 'theta2', 560, 100);
    add_line(sub, portRef(steer, 'theta2'), [g_th2 '/1'], 'autorouting', 'on');
    f_th2_tires = addFrom(sub, 'theta2', 620, 100);
    add_line(sub, [f_th2_tires '/1'], portRef(tires, 'theta2'), 'autorouting', 'on');

    %% ----- T_r: FEEDBACK (Tires -> SteeringColumn) -> Goto/From -----
    g_tr = addGoto(sub, 'T_r', 960, 220);
    add_line(sub, portRef(tires, 'T_r'), [g_tr '/1'], 'autorouting', 'on');
    f_tr = addFrom(sub, 'T_r', 220, 220);
    add_line(sub, [f_tr '/1'], portRef(steer, 'T_r'), 'autorouting', 'on');

    %% ----- beta, gamma: FEEDBACK (Bike2DOF -> Tires) + external output ---
    g_gamma = addGoto(sub, 'gamma', 1360, 300);
    add_line(sub, portRef(bike, 'gamma'), [g_gamma '/1'], 'autorouting', 'on');
    f_gamma_tires = addFrom(sub, 'gamma', 620, 180);
    add_line(sub, [f_gamma_tires '/1'], portRef(tires, 'gamma'), 'autorouting', 'on');
    f_gamma_out = addFrom(sub, 'gamma', 1420, 220);
    add_line(sub, [f_gamma_out '/1'], 'gamma/1', 'autorouting', 'on');

    g_beta = addGoto(sub, 'beta', 1360, 380);
    add_line(sub, portRef(bike, 'beta'), [g_beta '/1'], 'autorouting', 'on');
    f_beta_tires = addFrom(sub, 'beta', 620, 140);
    add_line(sub, [f_beta_tires '/1'], portRef(tires, 'beta'), 'autorouting', 'on');

    save_system(modelName, modelPath);
    close_system(modelName, 0);
    for i = 1:numel(fn)
        close_system(srcFiles.(fn{i}), 0);
    end

    fprintf('Created: %s\n', modelPath);
end

function subPath = findRootSubsystem(modelFileName)
% Return the ONE root-level subsystem of an already-loaded .mdl.
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName
% inside subPath - wiring by NAME, so hand-formatted clusters may reorder
% their ports freely.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
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
