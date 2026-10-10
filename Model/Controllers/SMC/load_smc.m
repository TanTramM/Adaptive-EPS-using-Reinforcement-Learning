%% load_smc.m
% Base workspace variables of the SMC controller: Ts_ctrl [s] (controller period),
% SMC_lambda [rad/s] (sliding surface slope), SMC_Phi [N.m/s] (boundary layer thickness),
% SMC_Tf [s] (derivative filter time constant), and the PRSM variables (Plant, Ref, Sensors,
% AssistLimit, Actuator) through load_plant, load_ref, load_sensors, load_assistlimit and load_actuator.
% Names are prefixed SMC_ so controllers can be loaded independently.
%
% Usage: run this SCRIPT before building or simulating SMC / Model_SMC.
%   >> run('<Model>/Controllers/SMC/load_smc.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/SMC/)
addpath(modelDir); setup_paths;
run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

J = jsondecode(fileread(fullfile(modelDir, 'data', 'smc.json')));
Ts_ctrl = J.Ts_ctrl;
if isfield(J, 'design')
    SMC_lambda = J.design.lambda;
    SMC_Phi    = J.design.Phi;
    SMC_Tf     = J.design.Tf;
    fprintf('load_smc: SMC lambda %.4g rad/s, Phi %.4g N.m/s, Tf %.4g s, Ts_ctrl %g ms\n', ...
        SMC_lambda, SMC_Phi, SMC_Tf, 1000 * Ts_ctrl);
else
    SMC_lambda = 0;
    SMC_Phi    = 1.0;
    SMC_Tf     = 0.005;
    fprintf('load_smc: no design yet in data/smc.json: open-loop gains loaded, Ts_ctrl %g ms\n', 1000 * Ts_ctrl);
end

