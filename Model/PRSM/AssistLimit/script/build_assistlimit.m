%% build_assistlimit.m
% Use the Simulink API to build the AssistLimit block, saved as AssistLimit.mdl RIGHT INSIDE the AssistLimit/ folder (parent of this script).
% It is the ECU table of the assist limit, the ONE place that holds T_a,max(v) (Documents/Thesis/ref.txt section 1.5, data/ref.json field
% Ta_max); the limit includes the safety margin F (make_ta_max.m). The closed loop (Sim/script/build_closed_loop.m) wires its output
% T_a_max to the Actuator (clamp) and, by name, to every controller that has an Inport T_a_max (SMC gain, RL action scaling); no controller
% keeps its own copy of the table.
%
%   AssistLimit     In : v (measured speed)      Out: T_a_max
%     +-- Lookup_Tamax   1-D table, linear interpolation, clipped outside 20-100 km/h
%
% Parameters: Tamax_v_bp_ms, Tamax_table - run Model/PRSM/AssistLimit/load_assistlimit.m BEFORE building.
%
% Usage (run from this folder, AssistLimit/script/):
%   >> run('../load_assistlimit.m')
%   >> build_assistlimit         % or build_assistlimit(true) to overwrite

function modelName = build_assistlimit(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing AssistLimit.mdl; false: save as AssistLimit_1, ...

scriptDir = fileparts(mfilename('fullpath'));   % AssistLimit/script
partDir   = fileparts(scriptDir);               % AssistLimit/
modelDir  = fileparts(fileparts(partDir));      % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(partDir, 'AssistLimit', overwrite);
modelPath = fullfile(partDir, [modelName '.mdl']);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/AssistLimit'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'v', 1, 40, 60);
addOutport(sub, 'T_a_max', 1, 320, 60);
full = [sub '/Lookup_Tamax'];
add_block('simulink/Lookup Tables/1-D Lookup Table', full);
set_param(full, 'Table', 'Tamax_table', 'BreakpointsForDimension1', 'Tamax_v_bp_ms', ...
    'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
moveBlock(full, 160, 50);
add_line(sub, 'v/1', 'Lookup_Tamax/1', 'autorouting', 'on');
add_line(sub, 'Lookup_Tamax/1', 'T_a_max/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);

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
