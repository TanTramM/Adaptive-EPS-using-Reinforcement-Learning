function make_dead_zone_model(srcName, dstName, ctrlName, resultTag)
%MAKE_DEAD_ZONE_MODEL Copy a closed-loop model and add the torque dead zone of the Map in front of the Plant: T_a = 0 while |T_s| < dz_Ts.
%
%   make_dead_zone_model('Model_PIDF_s', 'Model_PIDF_DZ_s', 'PID', 'PIDF_DZ')
%   make_dead_zone_model('Model_SMC_KI_s', 'Model_SMC_KI_DZ_s', 'SMC_KI', 'SMC_KI_DZ')
%
%   srcName  existing closed-loop model in Model/ (root subsystem 'Model_<x>' holding the controller block ctrlName)
%   dstName  new model written to Model/<dstName>.mdl
%   ctrlName name of the controller block inside the closed-loop subsystem (its output port 1 is T_a)
%   resultTag folder name under Result/ used by the StopFcn of the new model
%   The output of the controller goes through Switch_gate: passes when |T_s| >= dz_Ts (T_s = MEASURED torque, Goto tag 'T_s'),
%   else 0. dz_Ts is a base-workspace variable (the Map's dead band Ts0 of data/map.json, set by load_pidf_dz.m / load_smc_ki_dz.m),
%   so the controller runs unchanged and only its command is zeroed near the center, exactly like the Map's dead band.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
for nm = {srcName, dstName}
    if bdIsLoaded(nm{1}), close_system(nm{1}, 0); end
end
load_system(fullfile(modelDir, [srcName '.mdl']));
dstPath = fullfile(modelDir, [dstName '.mdl']);
if exist(dstPath, 'file'), delete(dstPath); end
save_system(srcName, dstPath);                  % the model in memory now has the new name
subs = find_system(dstName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'expected one closed-loop subsystem in %s', dstName);
sub = subs{1};
ctl = [sub '/' ctrlName];
lh = get_param(ctl, 'LineHandles');
lineOut = lh.Outport(1);
dstBlk = get_param(lineOut, 'DstBlockHandle');
assert(isscalar(dstBlk), 'controller output must feed exactly one block');
dstPortNum = get_param(get_param(lineOut, 'DstPortHandle'), 'PortNumber');
delete_line(lineOut);
pos = get_param(ctl, 'Position');
sw = add_block('simulink/Signal Routing/Switch', [sub '/Switch_gate']);
set_param(sw, 'Criteria', 'u2 >= Threshold', 'Threshold', 'dz_Ts');
set_param(sw, 'Position', [pos(3) + 60, pos(2) - 160, pos(3) + 100, pos(2) - 100]);
zc = add_block('simulink/Sources/Constant', [sub '/Constant_gate0']);
set_param(zc, 'Value', '0'); set_param(zc, 'Position', [pos(3) + 10, pos(2) - 80, pos(3) + 40, pos(2) - 60]);
fr = add_block('simulink/Signal Routing/From', [sub '/From_gate']);
set_param(fr, 'GotoTag', 'T_s'); set_param(fr, 'Position', [pos(3) - 60, pos(2) - 200, pos(3) - 20, pos(2) - 186]);
ab = add_block('simulink/Math Operations/Abs', [sub '/Abs_gate']);
set_param(ab, 'Position', [pos(3), pos(2) - 200, pos(3) + 30, pos(2) - 180]);
add_line(sub, [ctrlName '/1'], 'Switch_gate/1', 'autorouting', 'on');
add_line(sub, 'From_gate/1', 'Abs_gate/1', 'autorouting', 'on');
add_line(sub, 'Abs_gate/1', 'Switch_gate/2', 'autorouting', 'on');
add_line(sub, 'Constant_gate0/1', 'Switch_gate/3', 'autorouting', 'on');
add_line(sub, 'Switch_gate/1', [get_param(dstBlk, 'Name') '/' num2str(dstPortNum)], 'autorouting', 'on');
set_param(dstName, 'StopFcn', sprintf('save_run_results(''%s'', ''manual_run'')', resultTag));
save_system(dstName, dstPath);
close_system(dstName, 0);
fprintf('Created: %s (torque dead zone dz_Ts in front of the Plant)\n', dstPath);
end
