%% load_pidlag.m
% Base workspace variables of the PIDLag controller (PIDLag_Ts_ctrl, PIDLag_Kp, PIDLag_Ki, PIDLag_Kd, PIDLag_Tf, PIDLag_Kaw, PIDLag_H_num/den) from data/pidlag.json (design written by
% select_pidlag.m; none yet = all gains 0) and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator). The lag stage (H_num/den) is 1 when the design has no lag.
%
% Usage: run this SCRIPT before building or simulating PIDLag / Model_PIDLag.
%   >> run('<Model>/Controllers/PIDLag/load_pidlag.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

[PIDLag_V, PIDLag_d, PIDLag_src] = pidlag_design_variables('PIDLag', modelDir);
PIDLag_fn = fieldnames(PIDLag_V);
for PIDLag_i = 1:numel(PIDLag_fn)
    assignin('base', PIDLag_fn{PIDLag_i}, PIDLag_V.(PIDLag_fn{PIDLag_i}));
end
fprintf('load_pidlag (%s): Kp %g Ki %g Kd %g Tf %g Kaw %g | lag %s | Ts_ctrl %g ms\n', PIDLag_src, PIDLag_d.Kp, PIDLag_d.Ki, PIDLag_d.Kd, PIDLag_d.Tf, PIDLag_V.PIDLag_Kaw, ...
    mat2str(isfield(PIDLag_d, 'lag')), 1000 * PIDLag_d.Ts_ctrl);
clear PIDLag_V PIDLag_d PIDLag_src PIDLag_fn PIDLag_i modelDir
