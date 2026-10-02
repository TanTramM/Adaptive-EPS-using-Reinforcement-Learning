%% build_model_pidz.m
% Create Model_PIDZ_s.mdl in Model/: Model_PIDF_s.mdl (PID with a stronger derivative filter) plus two dead zones, both off by default:
%   (B) error dead zone: Dead Zone block on e_T before the PID, half width dz_e [N.m] (output = e_T - dz_e for e_T > dz_e,
%       e_T + dz_e for e_T < -dz_e, else 0); the PID integrator and derivative therefore see 0 inside the band;
%   (A) torque dead zone like the Map's: the PID output is replaced by 0 while |T_s| < dz_Ts [N.m] (Switch on |T_s|, T_s measured).
% dz_e = 0 and dz_Ts = 0 give exactly the PIDF. Set the two variables in the base workspace before running (run_pidz_study.m does).
% Results go to Result/PIDZ/ (StopFcn). Run build_model_pid.m and build_model_pidf.m first.
%
% Usage (from PID/script/):  >> build_model_pidz

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
srcName = 'Model_PIDF_s';
dstName = 'Model_PIDZ_s';
for nm = {srcName, dstName}
    if bdIsLoaded(nm{1}), close_system(nm{1}, 0); end
end
load_system(fullfile(modelDir, [srcName '.mdl']));
dstPath = fullfile(modelDir, [dstName '.mdl']);
if exist(dstPath, 'file'), delete(dstPath); end
save_system(srcName, dstPath);                  % the model in memory is now called Model_PIDZ_s
sub = [dstName '/Model_PID'];
pid = [sub '/PID'];
lh = get_param(pid, 'LineHandles');

% ----- (B) Dead Zone on the e_T input of the PID -----
inNames = get_param(find_system(pid, 'SearchDepth', 1, 'BlockType', 'Inport'), 'Name');
inPorts = str2double(get_param(find_system(pid, 'SearchDepth', 1, 'BlockType', 'Inport'), 'Port'));
k = find(strcmp(inNames, 'e_T'), 1);
lineIn = lh.Inport(inPorts(k));
srcBlk = get_param(lineIn, 'SrcBlockHandle');
srcPort = get_param(lineIn, 'SrcPortHandle');
srcPortNum = get_param(srcPort, 'PortNumber');
delete_line(lineIn);
pos = get_param(pid, 'Position');
dz = add_block('simulink/Discontinuities/Dead Zone', [sub '/DeadZone_eT']);
set_param(dz, 'LowerValue', '-dz_e', 'UpperValue', 'dz_e');
set_param(dz, 'Position', [pos(1) - 160, pos(2) - 120, pos(1) - 160 + 30, pos(2) - 120 + 30]);
add_line(sub, [get_param(srcBlk, 'Name') '/' num2str(srcPortNum)], 'DeadZone_eT/1', 'autorouting', 'on');
add_line(sub, 'DeadZone_eT/1', ['PID/' num2str(inPorts(k))], 'autorouting', 'on');

% ----- (A) gate on the PID output: 0 while |T_s| < dz_Ts -----
lh = get_param(pid, 'LineHandles');
lineOut = lh.Outport(1);
dstBlk = get_param(lineOut, 'DstBlockHandle');
dstPortNum = get_param(get_param(lineOut, 'DstPortHandle'), 'PortNumber');
assert(isscalar(dstBlk), 'PID output must feed exactly one block');
delete_line(lineOut);
sw = add_block('simulink/Signal Routing/Switch', [sub '/Switch_gate']);
set_param(sw, 'Criteria', 'u2 >= Threshold', 'Threshold', 'dz_Ts');
set_param(sw, 'Position', [pos(3) + 60, pos(2) - 160, pos(3) + 60 + 40, pos(2) - 160 + 60]);
zc = add_block('simulink/Sources/Constant', [sub '/Constant_gate0']);
set_param(zc, 'Value', '0'); set_param(zc, 'Position', [pos(3) + 10, pos(2) - 80, pos(3) + 10 + 30, pos(2) - 80 + 20]);
fr = add_block('simulink/Signal Routing/From', [sub '/From_gate']);
set_param(fr, 'GotoTag', 'T_s'); set_param(fr, 'Position', [pos(3) - 60, pos(2) - 200, pos(3) - 60 + 40, pos(2) - 200 + 14]);
ab = add_block('simulink/Math Operations/Abs', [sub '/Abs_gate']);
set_param(ab, 'Position', [pos(3), pos(2) - 200, pos(3) + 30, pos(2) - 200 + 20]);
add_line(sub, 'PID/1', 'Switch_gate/1', 'autorouting', 'on');
add_line(sub, 'From_gate/1', 'Abs_gate/1', 'autorouting', 'on');
add_line(sub, 'Abs_gate/1', 'Switch_gate/2', 'autorouting', 'on');
add_line(sub, 'Constant_gate0/1', 'Switch_gate/3', 'autorouting', 'on');
add_line(sub, 'Switch_gate/1', [get_param(dstBlk, 'Name') '/' num2str(dstPortNum)], 'autorouting', 'on');

set_param(dstName, 'StopFcn', 'save_run_results(''PIDZ'', ''manual_run'')');
save_system(dstName, dstPath);
close_system(dstName, 0);
fprintf('Created: %s (dead zones dz_e, dz_Ts; off when 0)\n', dstPath);
