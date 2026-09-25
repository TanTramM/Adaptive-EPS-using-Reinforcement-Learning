function p = result_dir(varargin)
%RESULT_DIR Folder for saved results, created if missing.
%   p = result_dir('PID')                  -> <repo>/Result/PID
%   p = result_dir('Compare', 'PID_vs_SMC') -> <repo>/Result/Compare/PID_vs_SMC
%
%   All results live under <repo>/Result/, one folder per subject:
%     Plant/      plant and actuator results (T_a,max estimate, checks)
%     Reference/  Table 4 reference torque
%     PID/, SMC/  results of ONE controller (scenario responses, tuning)
%     Compare/<A>_vs_<B>/  results that compare controllers
%   File naming: <Subject>_<what>_<condition>.<png|csv|mat>, e.g.
%   PID_S1_hold_angle_mu_step_time_response.png.
%   Change the root here only (this is the single place that knows it).

    root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Result');
    p = fullfile(root, varargin{:});
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
