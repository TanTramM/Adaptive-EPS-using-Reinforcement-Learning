%% load_ismc.m
% Base workspace variables of the ISMC controller: Ts_ctrl [s] (controller period),
% ISMC_lambda [rad/s] (sliding surface slope), ISMC_Phi [N.m/s] (boundary layer thickness),
% ISMC_Tf [s] (derivative filter time constant), and the PRSM variables (Plant, Ref, Sensors,
% AssistLimit, Actuator) through load_plant, load_ref, load_sensors, load_assistlimit and load_actuator.
% Names are prefixed ISMC_ so controllers can be loaded independently.
%
% Usage: run this SCRIPT before building or simulating ISMC / Model_ISMC.
%   >> run('<Model>/Controllers/ISMC/load_ismc.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/ISMC/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

J = jsondecode(fileread(fullfile(modelDir, 'data', 'ismc.json')));
Ts_ctrl = J.Ts_ctrl;
if isfield(J, 'design')
    ISMC_lambda = J.design.lambda;
    ISMC_Phi    = J.design.Phi;
    ISMC_Tf     = J.design.Tf;
    fprintf('load_ismc: ISMC lambda %.4g rad/s, Phi %.4g N.m/s, Tf %.4g s, Ts_ctrl %g ms\n', ...
        ISMC_lambda, ISMC_Phi, ISMC_Tf, 1000 * Ts_ctrl);
else
    ISMC_lambda = 0;
    ISMC_Phi    = 1.0;
    ISMC_Tf     = 0.005;
    fprintf('load_ismc: no design yet in data/ismc.json: open-loop gains loaded, Ts_ctrl %g ms\n', 1000 * Ts_ctrl);
end

