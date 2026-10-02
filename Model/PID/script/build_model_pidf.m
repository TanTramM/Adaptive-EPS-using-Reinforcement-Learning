%% build_model_pidf.m
% Create Model_PIDF_s.mdl in Model/ as a copy of Model_PID_s.mdl: the PIDF controller (PID with a stronger derivative filter,
% data/pidf.json, Model/PID/script/tune_pidf.m) has the same structure as the PID, only the gains and the derivative filter
% constant differ, and the PID block reads them from the base workspace (Kp, Ki, Kd, T_filt, Kaw, Ts_ctrl; run load_pidf.m).
% The copy writes its results to Result/PIDF/ (StopFcn). Run Model/PID/script/build_model_pid.m first.
%
% Usage (from PID/script/):  >> build_model_pidf

scriptDir = fileparts(mfilename('fullpath'));   % PID/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
srcName = 'Model_PID_s';
dstName = 'Model_PIDF_s';
for nm = {srcName, dstName}
    if bdIsLoaded(nm{1}), close_system(nm{1}, 0); end
end
load_system(fullfile(modelDir, [srcName '.mdl']));
dstPath = fullfile(modelDir, [dstName '.mdl']);
if exist(dstPath, 'file'), delete(dstPath); end
save_system(srcName, dstPath);                  % the model in memory is now called Model_PIDF_s
set_param(dstName, 'StopFcn', 'save_run_results(''PIDF'', ''manual_run'')');
save_system(dstName, dstPath);
close_system(dstName, 0);
fprintf('Created: %s\n', dstPath);
