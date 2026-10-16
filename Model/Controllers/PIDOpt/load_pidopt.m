%% load_pidopt.m
% Base workspace variables of the PIDOpt controller (PIDOpt_Ts_ctrl, PIDOpt_Kp, PIDOpt_Ki, PIDOpt_Kd, PIDOpt_Tf, PIDOpt_Kaw, PIDOpt_H_num/den) from data/pidopt.json (design written by
% select_pidlag.m; none yet = all gains 0) and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator). The lag stage (H_num/den) is 1 when the design has no lag.
%
% Usage: run this SCRIPT before building or simulating PIDOpt / Model_PIDOpt.
%   >> run('<Model>/Controllers/PIDOpt/load_pidopt.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[PIDOpt_V, PIDOpt_d, PIDOpt_src] = pidlag_design_variables('PIDOpt', modelDir);
PIDOpt_fn = fieldnames(PIDOpt_V);
for PIDOpt_i = 1:numel(PIDOpt_fn)
    assignin('base', PIDOpt_fn{PIDOpt_i}, PIDOpt_V.(PIDOpt_fn{PIDOpt_i}));
end
fprintf('load_pidopt (%s): Kp %g Ki %g Kd %g Tf %g Kaw %g | lag %s | Ts_ctrl %g ms\n', PIDOpt_src, PIDOpt_d.Kp, PIDOpt_d.Ki, PIDOpt_d.Kd, PIDOpt_d.Tf, PIDOpt_V.PIDOpt_Kaw, ...
    mat2str(isfield(PIDOpt_d, 'lag')), 1000 * PIDOpt_d.Ts_ctrl);
clear PIDOpt_V PIDOpt_d PIDOpt_src PIDOpt_fn PIDOpt_i modelDir
