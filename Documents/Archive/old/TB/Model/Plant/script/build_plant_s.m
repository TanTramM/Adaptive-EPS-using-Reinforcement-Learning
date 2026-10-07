%% build_plant_s.m
% Regenerate the 3 cluster models WITH the "_s" suffix (by calling
% build_cum1, build_cum2, build_cum3 - always fresh, never reusing stale
% files), then assemble those 3 into 1 closed-loop model Plant_s.mdl,
% saved RIGHT INSIDE the Plant/ folder. Counterpart: build_plant.m
% (assembles the HAND-FORMATTED trio, no "_s", without regenerating them).
%
% Ports are wired by NAME (found via find_system), not by port number - so
% this script works regardless of how the 3 source models order their
% ports internally.
%
% Cluster interfaces (see Cum1_CEPS.txt, Cum2_Pacejka.txt, Cum3_2DOF.txt):
%   SteeringColumn  In : T_d, T_a, T_r
%                   Out: theta1, theta1_dot, theta2, theta2_dot, T_s
%   Tires           In : theta2, beta, gamma, v, mu
%                   Out: F_yf, F_yr, T_r
%   Bike2DOF        In : F_yf, F_yr, v
%                   Out: beta, gamma, a_y
%
% Wiring (matches Documents/HeThongPlant_TongHop.txt):
%   T_d, T_a (external In)         -> SteeringColumn
%   v (external In)                -> Tires, Bike2DOF (2 destinations)
%   mu (external In)               -> Tires
%   SteeringColumn.theta2          -> Tires.theta2 ; -> Out (2 destinations)
%   SteeringColumn.theta1, theta1_dot, theta2_dot, T_s -> Out (1 dest each)
%   Tires.F_yf, F_yr               -> Bike2DOF
%   Tires.T_r                      -> SteeringColumn.T_r (feedback loop 1)
%   Bike2DOF.beta, gamma           -> Tires ; -> Out (feedback loop 2, and
%                                     2 destinations each)
%   Bike2DOF.a_y                   -> Out
%
% T_r and beta/gamma close FEEDBACK loops (they flow backward relative to
% the SteeringColumn -> Tires -> Bike2DOF layout, left-to-right) - routed
% via Goto/From regardless of destination count, to avoid long wires
% looping back across the whole diagram. v, theta2 also go via Goto/From
% (2 destinations each). T_d, T_a, mu, F_yf, F_yr and every 1-destination
% forward output are wired directly.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_plant_s
%   (regenerates SteeringColumn_s.mdl, Tires_s.mdl, Bike2DOF_s.mdl, then
%   creates Plant_s.mdl, all in Plant/)

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
% Calling build_cum1/2/3 as LOCAL-FUNCTION calls (not straight from the
% script body) keeps their script-level variables (modelName, sub, ...)
% confined to THIS function's own workspace - they do NOT leak into
% build_plant_s.m's own script variables of the same name.
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

    steerSrc = findRootSubsystem(srcFiles.steer);
    tiresSrc = findRootSubsystem(srcFiles.tires);
    bikeSrc  = findRootSubsystem(srcFiles.bike);

    add_block(steerSrc, [sub '/SteeringColumn']);
    moveBlock([sub '/SteeringColumn'], 280, 60);
    add_block(tiresSrc, [sub '/Tires']);
    moveBlock([sub '/Tires'], 640, 60);
    add_block(bikeSrc, [sub '/Bike2DOF']);
    moveBlock([sub '/Bike2DOF'], 1000, 60);

    steer = [sub '/SteeringColumn'];
    tires = [sub '/Tires'];
    bike  = [sub '/Bike2DOF'];

    %% ----- External inputs (left edge) -----
    addInport(sub, 'T_d', 1, 40,  60);
    addInport(sub, 'T_a', 2, 40, 140);
    addInport(sub, 'v',   3, 40, 600);
    addInport(sub, 'mu',  4, 40, 680);

    %% ----- External outputs (right edge) -----
    addOutport(sub, 'theta1',     1, 1340,  60);
    addOutport(sub, 'theta1_dot', 2, 1340, 120);
    addOutport(sub, 'theta2',     3, 1340, 180);
    addOutport(sub, 'theta2_dot', 4, 1340, 240);
    addOutport(sub, 'T_s',        5, 1340, 300);
    addOutport(sub, 'a_y',        6, 1340, 360);
    addOutport(sub, 'gamma',      7, 1340, 420);
    addOutport(sub, 'beta',       8, 1340, 480);

    %% ----- Forward, single-destination: wire directly -----
    add_line(sub, 'T_d/1', portRef(steer, 'T_d'), 'autorouting', 'on');
    add_line(sub, 'T_a/1', portRef(steer, 'T_a'), 'autorouting', 'on');
    add_line(sub, 'mu/1',  portRef(tires, 'mu'),  'autorouting', 'on');

    add_line(sub, portRef(tires, 'F_yf'), portRef(bike, 'F_yf'), 'autorouting', 'on');
    add_line(sub, portRef(tires, 'F_yr'), portRef(bike, 'F_yr'), 'autorouting', 'on');

    add_line(sub, portRef(steer, 'theta1'),     'theta1/1',     'autorouting', 'on');
    add_line(sub, portRef(steer, 'theta1_dot'), 'theta1_dot/1', 'autorouting', 'on');
    add_line(sub, portRef(steer, 'theta2_dot'), 'theta2_dot/1', 'autorouting', 'on');
    add_line(sub, portRef(steer, 'T_s'),        'T_s/1',        'autorouting', 'on');
    add_line(sub, portRef(bike, 'a_y'),         'a_y/1',        'autorouting', 'on');

    %% ----- v: 2 destinations (Tires, Bike2DOF) -> Goto/From -----
    g_v = addGoto(sub, 'v', 100, 600);
    add_line(sub, 'v/1', [g_v '/1'], 'autorouting', 'on');
    f_v_tires = addFrom(sub, 'v', 560, 500);
    add_line(sub, [f_v_tires '/1'], portRef(tires, 'v'), 'autorouting', 'on');
    f_v_bike = addFrom(sub, 'v', 920, 560);
    add_line(sub, [f_v_bike '/1'], portRef(bike, 'v'), 'autorouting', 'on');

    %% ----- theta2: 2 destinations (Tires, external output) -> Goto/From -----
    g_th2 = addGoto(sub, 'theta2', 560, 60);
    add_line(sub, portRef(steer, 'theta2'), [g_th2 '/1'], 'autorouting', 'on');
    f_th2_tires = addFrom(sub, 'theta2', 580, 100);
    add_line(sub, [f_th2_tires '/1'], portRef(tires, 'theta2'), 'autorouting', 'on');
    f_th2_out = addFrom(sub, 'theta2', 1260, 180);
    add_line(sub, [f_th2_out '/1'], 'theta2/1', 'autorouting', 'on');

    %% ----- T_r: FEEDBACK (Tires -> SteeringColumn) -> Goto/From -----
    g_tr = addGoto(sub, 'T_r', 780, 200);
    add_line(sub, portRef(tires, 'T_r'), [g_tr '/1'], 'autorouting', 'on');
    f_tr = addFrom(sub, 'T_r', 200, 200);
    add_line(sub, [f_tr '/1'], portRef(steer, 'T_r'), 'autorouting', 'on');

    %% ----- beta, gamma: FEEDBACK (Bike2DOF -> Tires) + external output ---
    g_gamma = addGoto(sub, 'gamma', 1100, 420);
    add_line(sub, portRef(bike, 'gamma'), [g_gamma '/1'], 'autorouting', 'on');
    f_gamma_tires = addFrom(sub, 'gamma', 560, 360);
    add_line(sub, [f_gamma_tires '/1'], portRef(tires, 'gamma'), 'autorouting', 'on');
    f_gamma_out = addFrom(sub, 'gamma', 1260, 420);
    add_line(sub, [f_gamma_out '/1'], 'gamma/1', 'autorouting', 'on');

    g_beta = addGoto(sub, 'beta', 1100, 480);
    add_line(sub, portRef(bike, 'beta'), [g_beta '/1'], 'autorouting', 'on');
    f_beta_tires = addFrom(sub, 'beta', 560, 420);
    add_line(sub, [f_beta_tires '/1'], portRef(tires, 'beta'), 'autorouting', 'on');
    f_beta_out = addFrom(sub, 'beta', 1260, 480);
    add_line(sub, [f_beta_out '/1'], 'beta/1', 'autorouting', 'on');

    save_system(modelName, modelPath);
    close_system(modelName, 0);
    for i = 1:numel(fn)
        close_system(srcFiles.(fn{i}), 0);
    end

    fprintf('Created: %s\n', modelPath);
end

%% ===================== Shared utility functions ===========================
function moveBlock(blk, x, y)
% Move a block to (x,y), KEEPING its default size.
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function createSubsystem(path)
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
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addFrom(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function subPath = findRootSubsystem(modelFileName)
% Return the ONE root-level subsystem of an already-loaded .mdl.
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% Find the Inport/Outport named portName inside subPath, return
% "<BlockNameInParent>/<PortNumber>" for use directly in add_line.
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
