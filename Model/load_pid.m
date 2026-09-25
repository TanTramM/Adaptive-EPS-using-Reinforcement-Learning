%% load_pid.m
% Load everything needed to build/simulate the PID controller and its
% closed loop (Model_PID_s.mdl), in this order:
%   1. data/pid.json  -> PID design values (Ts_ctrl, Kcu, Pu, alpha_D), and
%      the PID gains computed from them (Documents/DieuKhien_PID.txt);
%   2. load_plant.m   -> plant parameters (data/params.json), which itself
%      calls load_derived.m (F_zf);
%   3. load_ref.m     -> Table 4 reference data (data/ref.json).
%
% PID gains: Ziegler-Nichols closed-loop rules (Seborg, "cycling method").
% Kcu (ultimate gain) and Pu (oscillation period at Kcu) are MEASURED on the
% closed loop by Model/Sim/script/find_ultimate_gain.m and stored in
% pid.json:
%     Kp = 0.6*Kcu,  tau_I = Pu/2,  tau_D = Pu/8
%     Ki = Kp/tau_I,  Kd = Kp*tau_D
% The derivative filter time constant is T_filt = max(alpha_D*tau_D, Ts_ctrl):
% the Forward-Euler filter is only stable for T_filt > Ts_ctrl/2, so it is
% never allowed below one sample time.
%
% Assist limit and anti-windup: the controller saturates T_a at +-T_a,max(v), a 1-D table from data/boundaries.json (field T_a, Documents/Boundaries.txt),
% loaded here as bnd_v_bp [m/s] and bnd_Ta_max [N.m]; the back-calculation gain of the anti-windup is Kaw = 1/tau_I (tracking time constant = tau_I).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/load_pid.m')

scriptDir = fileparts(mfilename('fullpath'));   % Model/
addpath(scriptDir);   % result_dir.m, save_run_results.m
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'pid.json')));

fn = fieldnames(raw);
fn = fn(~startsWith(fn, 'x_'));   % skip the "_note" field (jsondecode names it x_note)
for i = 1:numel(fn)
    assignin('base', fn{i}, raw.(fn{i}).value);
end

Ku = raw.Kcu.value;
Pu = raw.Pu.value;
Ts = raw.Ts_ctrl.value;

Kp     = 0.6*Ku;
tau_I  = Pu/2;
tau_D  = Pu/8;
Ki     = Kp/tau_I;
Kd     = Kp*tau_D;
T_filt = max(raw.alpha_D.value*tau_D, Ts);
Kaw    = 1/tau_I;

out = struct('Kp', Kp, 'Ki', Ki, 'Kd', Kd, 'T_filt', T_filt, 'tau_I', tau_I, 'tau_D', tau_D, 'Kaw', Kaw);
fn = fieldnames(out);
for i = 1:numel(fn)
    assignin('base', fn{i}, out.(fn{i}));
end

fprintf('load_pid: Ziegler-Nichols (Kcu=%.4g, Pu=%.4g s): Kp=%.4g, Ki=%.4g 1/s (tau_I=%.4g s), Kd=%.4g s (tau_D=%.4g s), T_filt=%.4g s\n', ...
    Ku, Pu, Kp, Ki, tau_I, Kd, tau_D, T_filt);

bnd = jsondecode(fileread(fullfile(scriptDir, 'data', 'boundaries.json')));
assignin('base', 'bnd_v_bp',   bnd.T_a.v_kmh(:)'/3.6);
assignin('base', 'bnd_Ta_max', bnd.T_a.value(:)');

run(fullfile(scriptDir, 'load_plant.m'));
run(fullfile(scriptDir, 'load_ref.m'));
