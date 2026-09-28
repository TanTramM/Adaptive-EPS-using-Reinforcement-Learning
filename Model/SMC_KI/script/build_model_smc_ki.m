%% build_model_smc_ki.m
% Build the complete, runnable closed-loop model for the SMC controller,
% saved as Model_SMC_KI_s.mdl in the Model/ folder (two levels above this
% script). Sources (all "_s", auto-generated, must already exist):
% Plant/Plant_s.mdl, Ref/Reference_s.mdl, SMC/SMC_KI_s.mdl.
%
%   Root level (runnable):
%     From Workspace  sc_theta1, sc_v, sc_mu   ([t value] matrices in base)
%       -> Model_SMC_KI (subsystem) ->
%     To Workspace    log_T_s, log_T_d_ref, log_e_T, log_T_a, log_a_y
%
%   Model_SMC_KI (subsystem)
%     In : theta1 (driver angle), v, mu (unmeasured, scenario input)
%     Out: T_s, T_d_ref, e_T, T_a, a_y
%     |
%     +-- Plant       In : theta1, T_a, v, mu   Out: T_s, theta2, a_y, gamma, beta, theta2_dot
%     +-- Reference   In : T_s, v, a_y          Out: T_d_ref, e_T
%     +-- SMC         In : e_T, T_s, theta1, theta2_dot   Out: T_a
%
% Ports are wired by NAME; a controller port is only wired if the
% controller has it. T_a closes the loop back into the Plant (Goto/From);
% every signal used in more than one place goes through Goto/From. Unused
% plant outputs (theta2, gamma, beta) end in Terminator blocks.
%
% Results: run by hand, the model saves its signals and a time-response figure
% to <repo>/Result/SMC_KI/ through StopFcn (Model/save_run_results.m).
%
% Solver settings saved in the model: MaxStep = 0.002 s (steep dry-friction
% term tanh(c*x), discrete controller at Ts_ctrl), StopTime = 10 s.
%
% Usage (run from this folder, SMC_KI/script/):
%   >> run('../../load_smc_ki.m')      % SMC params, then load_plant, load_ref
%   >> build_model_smc_ki
%   then define sc_theta1, sc_v, sc_mu ([t value] matrices) and simulate.

ctrlName  = 'SMC_KI';
modelName = ['Model_' ctrlName '_s'];

scriptDir = fileparts(mfilename('fullpath'));   % SMC_KI/script
ctrlDir   = fileparts(scriptDir);               % SMC/
modelDir  = fileparts(ctrlDir);                 % Model/

src = {fullfile(modelDir, 'Plant', 'Plant_s.mdl'), ...
       fullfile(modelDir, 'Ref',   'Reference_s.mdl'), ...
       fullfile(ctrlDir, [ctrlName '_s.mdl'])};

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
modelPath = fullfile(modelDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

srcNames = cell(size(src));
for i = 1:numel(src)
    [~, srcNames{i}] = fileparts(src{i});
    if bdIsLoaded(srcNames{i})
        close_system(srcNames{i}, 0);
    end
    load_system(src{i});
end

new_system(modelName);
open_system(modelName);

%% ===================== Closed-loop subsystem ============================
sub = [modelName '/Model_' ctrlName];
createSubsystem(sub);
moveBlock(sub, 300, 80);
buildClosedLoop(sub, srcNames, ctrlName);

%% ===================== Root: scenario sources and logging ===============
ins  = {'theta1', 'v', 'mu'};
for i = 1:numel(ins)
    blk = [modelName '/From Workspace ' ins{i}];
    add_block('simulink/Sources/From Workspace', blk);
    set_param(blk, 'VariableName', ['sc_' ins{i}], 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value');
    moveBlock(blk, 60, 60 + 60*(i-1));
    add_line(modelName, ['From Workspace ' ins{i} '/1'], portRef(sub, ins{i}), 'autorouting', 'on');
end
outs = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y'};
for i = 1:numel(outs)
    blk = [modelName '/To Workspace ' outs{i}];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', ['log_' outs{i}], 'SaveFormat', 'Timeseries');
    moveBlock(blk, 600, 40 + 60*(i-1));
    add_line(modelName, portRef(sub, outs{i}), ['To Workspace ' outs{i} '/1'], 'autorouting', 'on');
end

set_param(modelName, 'StopTime', '10', 'MaxStep', '0.002', 'RelTol', '1e-6');
% When the model is run by hand (Run button) the To Workspace logs are
% exported to Result/SMC_KI/ (files named SMC_manual_run_*). Silent when a
% script runs the model through sim() with an output object.
% Logs go to the base workspace (not to an output object) so that StopFcn can
% read them after a run by hand; scripts run the model with
% sim(Simulink.SimulationInput(name)), which always returns an output object.
set_param(modelName, 'ReturnWorkspaceOutputs', 'off');
set_param(modelName, 'StopFcn', sprintf('save_run_results(''%s'', ''manual_run'')', ctrlName));

save_system(modelName, modelPath);
close_system(modelName, 0);
for i = 1:numel(srcNames)
    close_system(srcNames{i}, 0);
end
fprintf('Created: %s\n', modelPath);

%% ===================== Plant + Reference + controller =====================
function buildClosedLoop(sub, srcNames, ctrlName)
    add_block(findRootSubsystem(srcNames{1}), [sub '/Plant']);
    moveBlock([sub '/Plant'], 600, 60);
    add_block(findRootSubsystem(srcNames{2}), [sub '/Reference']);
    moveBlock([sub '/Reference'], 1000, 60);
    add_block(findRootSubsystem(srcNames{3}), [sub '/' ctrlName]);
    moveBlock([sub '/' ctrlName], 300, 400);

    plant = [sub '/Plant'];
    ref   = [sub '/Reference'];
    ctl   = [sub '/' ctrlName];

    % ----- External inputs / outputs -----
    addInport(sub, 'theta1', 1, 40,  60);
    addInport(sub, 'v',      2, 40, 140);
    addInport(sub, 'mu',     3, 40, 220);

    addOutport(sub, 'T_s',     1, 1400,  60);
    addOutport(sub, 'T_d_ref', 2, 1400, 140);
    addOutport(sub, 'e_T',     3, 1400, 220);
    addOutport(sub, 'T_a',     4, 1400, 300);
    addOutport(sub, 'a_y',     5, 1400, 380);

    % ----- Scenario inputs -----
    g_th1 = addGoto(sub, 'theta1', 120, 60);
    add_line(sub, 'theta1/1', [g_th1 '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'theta1', 500, 60) '/1'], portRef(plant, 'theta1'), 'autorouting', 'on');

    g_v = addGoto(sub, 'v', 120, 140);
    add_line(sub, 'v/1', [g_v '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v', 500, 180) '/1'], portRef(plant, 'v'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v', 900, 100) '/1'], portRef(ref, 'v'), 'autorouting', 'on');

    add_line(sub, 'mu/1', portRef(plant, 'mu'), 'autorouting', 'on');

    % ----- Plant outputs -----
    g_Ts = addGoto(sub, 'T_s', 860, 60);
    add_line(sub, portRef(plant, 'T_s'), [g_Ts '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s', 900,  60) '/1'], portRef(ref, 'T_s'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s', 1320, 60) '/1'], 'T_s/1', 'autorouting', 'on');

    g_ay = addGoto(sub, 'a_y', 860, 180);
    add_line(sub, portRef(plant, 'a_y'), [g_ay '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y', 900, 140) '/1'], portRef(ref, 'a_y'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y', 1320, 380) '/1'], 'a_y/1', 'autorouting', 'on');

    g_th2d = addGoto(sub, 'theta2_dot', 860, 300);
    add_line(sub, portRef(plant, 'theta2_dot'), [g_th2d '/1'], 'autorouting', 'on');

    unused = {'theta2', 'gamma', 'beta'};
    for i = 1:numel(unused)
        h = add_block('simulink/Sinks/Terminator', [sub '/Terminator'], 'MakeNameUnique', 'on');
        moveBlock(h, 860, 220 + 20*i);
        add_line(sub, portRef(plant, unused{i}), [get_param(h, 'Name') '/1'], 'autorouting', 'on');
    end

    % ----- Reference outputs -----
    g_eT = addGoto(sub, 'e_T', 1200, 220);
    add_line(sub, portRef(ref, 'e_T'), [g_eT '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'e_T', 1320, 220) '/1'], 'e_T/1', 'autorouting', 'on');
    add_line(sub, portRef(ref, 'T_d_ref'), 'T_d_ref/1', 'autorouting', 'on');

    % ----- Controller inputs (only the ports it has) -----
    ctlIns = get_param(find_system(ctl, 'SearchDepth', 1, 'BlockType', 'Inport'), 'Name');
    for i = 1:numel(ctlIns)
        f = addFrom(sub, ctlIns{i}, 200, 400 + 40*(i-1));
        add_line(sub, [f '/1'], portRef(ctl, ctlIns{i}), 'autorouting', 'on');
    end

    % ----- T_a: FEEDBACK controller -> Plant, and output -----
    g_Ta = addGoto(sub, 'T_a', 500, 400);
    add_line(sub, portRef(ctl, 'T_a'), [g_Ta '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 500, 100) '/1'], portRef(plant, 'T_a'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 1320, 300) '/1'], 'T_a/1', 'autorouting', 'on');
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
% inside subPath - wiring by NAME.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
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
