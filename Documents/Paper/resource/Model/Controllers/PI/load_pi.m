%% load_pi.m
% Base workspace variables of the PI controller: Ts_ctrl [s] (controller period), PI_Kp, PI_Ki [1/s], PI_Kaw (= Ki/Kp, back-calculation gain) from
% data/pi.json (design written by the selection script), and the PRSM variables (Plant, Ref, Sensors, AssistLimit, Actuator) through
% load_plant, load_ref, load_sensors, load_assistlimit and load_actuator. The names are prefixed PI_ so that PI and PID can be loaded together.
% Before the design exists the gains are 0 (open loop).
%
% Usage: run this SCRIPT before building or simulating PI / Model_PI.
%   >> run('<Model>/Controllers/PI/load_pi.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/PI/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));
J = jsondecode(fileread(fullfile(modelDir, 'data', 'pi.json')));
Ts_ctrl = J.Ts_ctrl;
if isfield(J, 'design')
    PI_Kp = J.design.Kp; PI_Ki = J.design.Ki; PI_Kaw = J.design.Ki / J.design.Kp;
    fprintf('load_pi: PI Kp %.4g, Ki %.4g 1/s, Kaw %.4g, Ts_ctrl %g ms\n', PI_Kp, PI_Ki, PI_Kaw, 1000 * Ts_ctrl);
else
    PI_Kp = 0; PI_Ki = 0; PI_Kaw = 0;
    fprintf('load_pi: no design yet in data/pi.json: all gains 0, Ts_ctrl %g ms\n', 1000 * Ts_ctrl);
end
