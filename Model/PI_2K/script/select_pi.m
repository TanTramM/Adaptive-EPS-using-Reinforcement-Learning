function select_pi(wc)
%SELECT_PI Write data/pi_2k.json from one row of the PI design grid (Result/PI_2K/Design/PI_design_grid.csv).
%
%   select_pi()        the point selected by the rule of run_pi_sweep.m (Result/PI_2K/Sweep/PI_sweep_selection.csv, row 'PI_2K')
%   select_pi(wc)      the row with this design crossover frequency [rad/s]
%
%   pid.json holds Ts_ctrl, Kp, Ki and the design record (crossover, margins). load_pi_2k.m reads it; Kaw = 1/Ti = Ki/Kp is derived there.

scriptDir = fileparts(mfilename('fullpath'));   % PI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);
D = readtable(fullfile(result_dir('PI_2K', 'Design'), 'PI_design_grid.csv'));
if nargin < 1
    T = readtable(fullfile(result_dir('PI_2K', 'Sweep'), 'PI_sweep_selection.csv'));
    wc = T.selected_parameter(strcmp(T.controller, 'PI_2K'));
end
r = D(abs(D.wc_design_rad_s - wc) < 1e-9 & D.feasible == 1, :);
assert(height(r) == 1, 'no feasible design row with wc = %g rad/s', wc);

out = struct();
out.x_note = ['PI controller (PID block with Kd = 0) of the assist loop, Documents/PI_2K/pid.txt. Written by Model/PI_2K/script/select_pi.m from ' ...
    'Result/PI_2K/Design/PI_design_grid.csv (design_pi.m: smallest Ti with PM >= 45 deg and GM >= 2 on the dry and the saturated plant, motor lag ' ...
    'included) at the crossover frequency chosen by run_pi_sweep.m.'];
out.Ts_ctrl = struct('value', 0.001, 'unit', 's', 'desc', 'ECU sample time, same as the Map');
out.Kp = struct('value', r.Kp, 'unit', '-', 'desc', 'proportional gain');
out.Ki = struct('value', r.Ki_1_per_s, 'unit', '1/s', 'desc', 'integral gain (Forward Euler); Ti = Kp/Ki, Kaw = Ki/Kp');
out.design = struct('wc_design_rad_s', r.wc_design_rad_s, 'Ti_s', r.Ti_s, 'a_wcTi', r.a_wcTi, 'pm_dry_deg', r.PM_dry_deg, 'gm_dry', r.GM_dry, ...
    'ms_dry', r.Ms_dry, 'pm_saturated_deg', r.PM_sat_deg, 'gm_saturated', r.GM_sat, 'ms_saturated', r.Ms_sat);
fid = fopen(fullfile(modelDir, 'data', 'pid.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(out, 'PrettyPrint', true));
fclose(fid);
fprintf('select_pi: wrote data/pi_2k.json (wc %g rad/s, Kp %.4g, Ki %.4g 1/s, Ti %.4g s)\n', r.wc_design_rad_s, r.Kp, r.Ki_1_per_s, r.Ti_s);
end
