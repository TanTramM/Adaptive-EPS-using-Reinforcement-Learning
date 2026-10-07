function build_closed_loop(ctrlName)
%BUILD_CLOSED_LOOP Build the runnable closed-loop model Model_<ctrlName>_s.mdl: Plant -> Sensors -> controller -> Actuator -> Plant.
%
%   build_closed_loop('Map_6_8')        % also 'PID', 'SMC', 'SMC_KI', ... (any controller block with the interface below)
%
%   Sources (must already exist; PRSM models carry no suffix): PRSM/Plant/Plant.mdl, PRSM/Ref/Reference.mdl, PRSM/Sensors/Sensors.mdl,
%   PRSM/Actuator/Actuator.mdl and Controllers/<ctrl>/<ctrl>_s.mdl (root subsystem named like the controller); the closed loop is written to Controllers/<ctrl>/Model_<ctrl>_s.mdl.
%
%   Plug and play: the controller block is the ONLY part that changes between models. It is wired BY NAME:
%     - every Inport of the controller is fed from the bus signal of the same name: the measured T_s, theta1, theta2_dot, v,
%       gamma, a_y (output of Sensors, plain name) and T_a_lim (command after the assist limit, from the Actuator);
%     - the measured signals the controller has no Inport for end in Terminator blocks;
%     - its output T_a (the command) goes to the Actuator (Inport T_a_cmd); the Actuator output T_a goes to the Plant.
%   The controller computes e_T = T_s - T_d,ref itself (if it uses it); the assist limit T_a,max(v) and the motor lag are in the Actuator.
%
%   Root level (runnable):
%     From Workspace  sc_theta1, sc_v, sc_mu   ([t value] matrices in base) -> Model_<ctrl> (subsystem) ->
%     To Workspace    log_T_s, log_T_d_ref, log_e_T, log_T_a, log_T_a_cmd, log_a_y   (TRUE values, scored)
%                     log_T_s_meas, log_a_y_meas, log_v_meas                          (what the controller sees)
%
%   Model_<ctrl> (subsystem)
%     In : theta1 (driver angle), v, mu (unmeasured, scenario input)
%     Out: T_s, T_d_ref, e_T, T_a (applied), T_a_cmd, a_y (true), T_s_meas, a_y_meas, v_meas (measured)
%     +-- Plant       In : theta1, T_a, v, mu           Out: T_s, a_y, gamma, theta2_dot (true)
%     +-- Sensors     In : T_s, theta1, theta2_dot, v, gamma, a_y (true)   Out: <signal>_meas
%     +-- <ctrl>      In : (any of the measured signals, T_a_lim)         Out: T_a
%     +-- Actuator    In : T_a_cmd, v (measured)        Out: T_a, T_a_lim
%     +-- Reference_true  In : v, a_y (TRUE)            Out: T_d_ref   (scoring only, not wired to the controller)
%     +-- Sum_eT_true  e_T = T_s - T_d_ref on TRUE values (scoring only): the scored e_T is what the driver feels
%   Goto tags: <signal>_true = true values, plain names (T_s, v, ...) = measured values read by the controller.
%
%   Solver: MaxStep = 0.002 s, StopTime = 10 s (run_test_cases.m overrides the stop time). Run by hand, the model saves its signals
%   and a figure to Result/<ctrl>/ through StopFcn (Model/save_run_results.m).
%
%   Usage: run load_<ctrl>.m first (it runs load_plant, load_ref, load_sensors, load_actuator), build every source block, then
%   >> build_closed_loop('Map_6_8')

modelName = ['Model_' ctrlName '_s'];

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); setup_paths;

src = {fullfile(modelDir, 'PRSM', 'Plant', 'Plant.mdl'), fullfile(modelDir, 'PRSM', 'Ref', 'Reference.mdl'), ...
       fullfile(modelDir, 'PRSM', 'Sensors', 'Sensors.mdl'), fullfile(modelDir, 'PRSM', 'Actuator', 'Actuator.mdl'), ...
       fullfile(modelDir, 'Controllers', ctrlName, [ctrlName '_s.mdl'])};

if bdIsLoaded(modelName), close_system(modelName, 0); end
modelPath = fullfile(modelDir, 'Controllers', ctrlName, [modelName '.mdl']);
if exist(modelPath, 'file'), delete(modelPath); end

srcNames = cell(size(src));
for i = 1:numel(src)
    [~, srcNames{i}] = fileparts(src{i});
    if bdIsLoaded(srcNames{i}), close_system(srcNames{i}, 0); end
    load_system(src{i});
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/Model_' ctrlName];
createSubsystem(sub);
moveBlock(sub, 300, 80);
buildLoop(sub, srcNames, ctrlName);

ins = {'theta1', 'v', 'mu'};
for i = 1:numel(ins)
    blk = [modelName '/From Workspace ' ins{i}];
    add_block('simulink/Sources/From Workspace', blk);
    set_param(blk, 'VariableName', ['sc_' ins{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    moveBlock(blk, 60, 60 + 60*(i-1));
    add_line(modelName, ['From Workspace ' ins{i} '/1'], portRef(sub, ins{i}), 'autorouting', 'on');
end
outs = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'T_a_cmd', 'a_y', 'T_s_meas', 'a_y_meas', 'v_meas'};
for i = 1:numel(outs)
    blk = [modelName '/To Workspace ' outs{i}];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', ['log_' outs{i}], 'SaveFormat', 'Timeseries');
    moveBlock(blk, 600, 40 + 60*(i-1));
    add_line(modelName, portRef(sub, outs{i}), ['To Workspace ' outs{i} '/1'], 'autorouting', 'on');
end

set_param(modelName, 'StopTime', '10', 'MaxStep', '0.002', 'RelTol', '1e-6');
% Logs go to the base workspace (not to an output object) so that StopFcn can read them after a run by hand; scripts run the model
% with sim(Simulink.SimulationInput(name)), which always returns an output object.
set_param(modelName, 'ReturnWorkspaceOutputs', 'off');
set_param(modelName, 'StopFcn', sprintf('save_run_results(''%s'', ''manual_run'')', ctrlName));

save_system(modelName, modelPath);
close_system(modelName, 0);
for i = 1:numel(srcNames), close_system(srcNames{i}, 0); end
fprintf('Created: %s\n', modelPath);
end

%% ===================== Plant + Sensors + controller + Actuator =====================
function buildLoop(sub, srcNames, ctrlName)
    names = {'Plant', 'Reference_true', 'Sensors', 'Actuator'};
    srcIdx = [1 2 3 4];
    xs = [600 1000 760 1000]; ys = [60 600 60 400];
    for i = 1:numel(names)
        add_block(findRootSubsystem(srcNames{srcIdx(i)}), [sub '/' names{i}]);
        moveBlock([sub '/' names{i}], xs(i), ys(i));
    end
    add_block(findRootSubsystem(srcNames{5}), [sub '/' ctrlName]);
    moveBlock([sub '/' ctrlName], 300, 400);
    plant = [sub '/Plant']; refTrue = [sub '/Reference_true']; sens = [sub '/Sensors'];
    act = [sub '/Actuator']; ctl = [sub '/' ctrlName];

    addInport(sub, 'theta1', 1, 40,  60);
    addInport(sub, 'v',      2, 40, 140);
    addInport(sub, 'mu',     3, 40, 220);
    outNames = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'T_a_cmd', 'a_y', 'T_s_meas', 'a_y_meas', 'v_meas'};
    for i = 1:numel(outNames), addOutport(sub, outNames{i}, i, 1500, 60 + 80*(i-1)); end

    % ----- scenario inputs: true theta1 and v go to the Plant and the Sensors -----
    sig = {'theta1', 'v'};
    for i = 1:numel(sig)
        g = addGoto(sub, [sig{i} '_true'], 120, 60 + 80*(i-1));
        add_line(sub, [sig{i} '/1'], [g '/1'], 'autorouting', 'on');
    end
    add_line(sub, 'mu/1', portRef(plant, 'mu'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'theta1_true', 500, 60)  '/1'], portRef(plant, 'theta1'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v_true',      500, 180) '/1'], portRef(plant, 'v'),      'autorouting', 'on');

    % ----- true signals: Plant outputs (and the scenario inputs) -> Sensors, scoring -----
    plantOuts = {'T_s', 'a_y', 'gamma', 'theta2_dot'};
    for i = 1:numel(plantOuts)
        g = addGoto(sub, [plantOuts{i} '_true'], 700, 60 + 40*(i-1));
        add_line(sub, portRef(plant, plantOuts{i}), [g '/1'], 'autorouting', 'on');
    end
    trueSensed = {'T_s', 'theta1', 'theta2_dot', 'v', 'gamma', 'a_y'};
    for i = 1:numel(trueSensed)
        add_line(sub, [addFrom(sub, [trueSensed{i} '_true'], 700, 300 + 40*(i-1)) '/1'], portRef(sens, trueSensed{i}), 'autorouting', 'on');
    end

    % ----- measured signals (bus) -> controller / Terminator / Actuator / logged outputs -----
    ctlIns = get_param(find_system(ctl, 'SearchDepth', 1, 'BlockType', 'Inport'), 'Name');
    for i = 1:numel(trueSensed)
        s = trueSensed{i};
        used = any(strcmp(ctlIns, s)) || strcmp(s, 'v') || any(strcmp({'T_s', 'a_y'}, s));
        if used
            g = addGoto(sub, s, 900, 300 + 40*(i-1));
            add_line(sub, portRef(sens, [s '_meas']), [g '/1'], 'autorouting', 'on');
        else
            h = add_block('simulink/Sinks/Terminator', [sub '/Terminator'], 'MakeNameUnique', 'on');
            moveBlock(h, 900, 300 + 40*(i-1));
            add_line(sub, portRef(sens, [s '_meas']), [get_param(h, 'Name') '/1'], 'autorouting', 'on');
        end
    end
    for i = 1:numel(ctlIns)
        f = addFrom(sub, ctlIns{i}, 200, 400 + 40*(i-1));
        add_line(sub, [f '/1'], portRef(ctl, ctlIns{i}), 'autorouting', 'on');
    end
    % ----- Actuator: controller command + measured speed in, T_a to the Plant, T_a_lim back to the bus -----
    g = addGoto(sub, 'T_a_cmd', 500, 400);
    add_line(sub, portRef(ctl, 'T_a'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a_cmd', 900, 400) '/1'], portRef(act, 'T_a_cmd'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v',       900, 440) '/1'], portRef(act, 'v'), 'autorouting', 'on');
    g = addGoto(sub, 'T_a_lim', 1200, 400);
    add_line(sub, portRef(act, 'T_a_lim'), [g '/1'], 'autorouting', 'on');
    g = addGoto(sub, 'T_a', 1200, 440);
    add_line(sub, portRef(act, 'T_a'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 500, 100) '/1'], portRef(plant, 'T_a'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 1400, 280) '/1'], 'T_a/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a_cmd', 1400, 360) '/1'], 'T_a_cmd/1', 'autorouting', 'on');

    % ----- the plant outputs that are scored directly -----
    add_line(sub, [addFrom(sub, 'T_s_true', 1400, 60)  '/1'], 'T_s/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y_true', 1400, 440) '/1'], 'a_y/1', 'autorouting', 'on');

    % ----- scoring: T_d_ref and e_T on TRUE values -----
    add_line(sub, [addFrom(sub, 'v_true',   900, 640) '/1'], portRef(refTrue, 'v'),   'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y_true', 900, 680) '/1'], portRef(refTrue, 'a_y'), 'autorouting', 'on');
    g = addGoto(sub, 'T_d_ref', 1200, 640);
    add_line(sub, portRef(refTrue, 'T_d_ref'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_d_ref', 1400, 140) '/1'], 'T_d_ref/1', 'autorouting', 'on');
    addSum(sub, 'Sum_eT_true', '+-', 1300, 700);
    add_line(sub, [addFrom(sub, 'T_s_true', 1200, 700) '/1'], 'Sum_eT_true/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_d_ref',  1200, 740) '/1'], 'Sum_eT_true/2', 'autorouting', 'on');
    add_line(sub, 'Sum_eT_true/1', 'e_T/1', 'autorouting', 'on');

    % ----- measured outputs for the log -----
    add_line(sub, [addFrom(sub, 'T_s', 1400, 580) '/1'], 'T_s_meas/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y', 1400, 620) '/1'], 'a_y_meas/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v',   1400, 660) '/1'], 'v_meas/1',   'autorouting', 'on');
end

function subPath = findRootSubsystem(modelFileName)
% Return the ONE root-level subsystem of an already-loaded .mdl.
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - wiring by NAME.
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
% Move a block to (x,y), KEEPING its default size.
    pos = get_param(blk, 'Position');
    set_param(blk, 'Position', [x, y, x + pos(3) - pos(1), y + pos(4) - pos(2)]);
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

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end
