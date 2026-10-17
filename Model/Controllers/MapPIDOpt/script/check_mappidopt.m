function check_mappidopt()
%CHECK_MAPPIDOPT DieuKhien_MapPID.txt H7 (d): mappidopt_eval on the design of data/mappid.json at seed 30000 must reproduce its stored CALIB score (J 3.0716, R 9.79 %, S 0.3137)
%   to 2e-3 relative (the closed loop is a variable-step simulation). Uses the closed loop Model_MapPIDOpt, so it also checks the whole chain of the new controller.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
Jx = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json'))); q = Jx.design;
x = [q.Kmax, q.lead.z, q.lead.p / q.lead.z, q.lag.z1, q.lag.p1 / q.lag.z1, q.Kp, q.Ki, q.Kd, q.Tf];
csv = fullfile(result_dir('MapPIDOpt', 'Design'), 'MapPIDOpt_check_s30000.csv');
if exist(csv, 'file'), delete(csv); end
o = mappidopt_eval(x, 30000, csv);
fprintf('[MapPIDOpt] check: J %.4f R %.3f S %.4f e_rel %.2f PM %.2f GM %.2f (mappid.json J %.4f R %.3f S %.4f e_rel %.2f PM %.2f GM %.2f)\n', ...
    o.J, o.R, o.S, o.erel, o.PM, o.GM, q.CALIB_J, q.CALIB_R_pct, q.CALIB_S_Nm, q.CALIB_erel_pct, q.PM_deg, q.GM);
assert(o.simulated == 1 && abs(o.J / q.CALIB_J - 1) < 2e-3, 'the MapPID design is not reproduced by MapPIDOpt');
fprintf('[MapPIDOpt] CHECK PASS\n');
end
