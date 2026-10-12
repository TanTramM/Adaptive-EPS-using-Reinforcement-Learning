%% load_pid.m
% Base workspace variables of the PID controller: Ts_ctrl [s] (controller period), PID_Kp, PID_Ki [1/s], PID_Kd [s], PID_Tf [s] (derivative
% filter time constant), PID_Kaw (= Ki/Kp, back-calculation gain) from data/pid.json (design written by the selection script), and the PRSM
% variables (Plant, Ref, Sensors, AssistLimit, Actuator) through load_plant, load_ref, load_sensors, load_assistlimit and load_actuator.
% The names are prefixed PID_ so that PI and PID can be loaded together. Before the design exists the gains are 0 (open loop), Tf = 5 ms.
%
% Usage: run this SCRIPT before building or simulating PID / Model_PID.
%   >> run('<Model>/Controllers/PID/load_pid.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/PID/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));
J = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json')));
Ts_ctrl = J.Ts_ctrl;
if isfield(J, 'design')
    PID_Kp = J.design.Kp; PID_Ki = J.design.Ki; PID_Kd = J.design.Kd; PID_Tf = J.design.Tf; PID_Kaw = J.design.Ki / J.design.Kp;
    fprintf('load_pid: PID Kp %.4g, Ki %.4g 1/s, Kd %.4g s, Tf %.4g s, Kaw %.4g, Ts_ctrl %g ms\n', PID_Kp, PID_Ki, PID_Kd, PID_Tf, PID_Kaw, 1000 * Ts_ctrl);
else
    PID_Kp = 0; PID_Ki = 0; PID_Kd = 0; PID_Tf = 0.005; PID_Kaw = 0;
    fprintf('load_pid: no design yet in data/pid.json: all gains 0, Ts_ctrl %g ms\n', 1000 * Ts_ctrl);
end
