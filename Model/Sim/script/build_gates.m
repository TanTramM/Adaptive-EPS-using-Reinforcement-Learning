%% build_gates.m
% Use the Simulink API to build Gates.mdl: ONE MATLAB Function block (source: gates_fcn.m, same folder) inside a root subsystem Gates.
% The block is a measuring instrument for calibration (QuyChuan.txt part 4 and 5): it reads TRUE signals of the closed loop and
% outputs running scores (R, S, TV, bang-bang and reverse-assist fractions, per-window accuracy). Nothing goes back into the loop, so
% the real controller model does not contain it. It is embedded into the <ctrl>_calib closed loop; the released model has no Gates.
%
%   Gates   In : T_s, T_d_ref, T_a, T_a_cmd, T_a_lim, winId
%           Out: R, S, S_cmd, TV, maxTa, maxEt, satFrac, revFrac, nonfinite, erelWin, RWin, refWin, cntWin
%   +-- gates_fcn   MATLAB Function block, sample time 1 ms (the grid of the test cases); its code is a copy of gates_fcn.m
%
% Usage:
%   >> build_gates            % or build_gates(true) to overwrite an existing Gates.mdl

function modelName = build_gates(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing Gates.mdl; false: save as Gates_1, ...

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
simDir    = fileparts(scriptDir);               % Sim/
modelDir  = fileparts(simDir);                  % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(simDir, 'Gates', overwrite);
modelPath = fullfile(simDir, [modelName '.mdl']);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/Gates'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

inNames  = {'T_s', 'T_d_ref', 'T_a', 'T_a_cmd', 'T_a_lim', 'winId'};
outNames = {'R', 'S', 'S_cmd', 'TV', 'maxTa', 'maxEt', 'satFrac', 'revFrac', 'nonfinite', 'erelWin', 'RWin', 'refWin', 'cntWin'};
for i = 1:numel(inNames),  addInport(sub,  inNames{i},  i, 40,   60 + 60*(i-1)); end
for i = 1:numel(outNames), addOutport(sub, outNames{i}, i, 700, 40 + 50*(i-1)); end

blk = [sub '/gates_fcn'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk);
moveBlock(blk, 300, 200);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blk);
ch.Script = fileread(fullfile(scriptDir, 'gates_fcn.m'));
ch.ChartUpdate = 'DISCRETE';
ch.SampleTime = '0.001';

for i = 1:numel(inNames),  add_line(sub, [inNames{i} '/1'],  sprintf('gates_fcn/%d', i), 'autorouting', 'on'); end
for i = 1:numel(outNames), add_line(sub, sprintf('gates_fcn/%d', i), [outNames{i} '/1'], 'autorouting', 'on'); end

save_system(modelName, modelPath);
close_system(modelName, 0);
fprintf('Created: %s\n', modelPath);

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
