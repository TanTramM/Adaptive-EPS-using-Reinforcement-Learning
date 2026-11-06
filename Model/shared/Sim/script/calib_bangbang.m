function B = calib_bangbang(mdl, runSeed, vars, limitFraction)
%CALIB_BANGBANG No-bang-bang gate of the shared selection rule (QuyChuan 5.4, v5): does sensor noise push the command to the assist limit?
%
%   B = calib_bangbang('Model_PI', 10000, struct('PI_Kp', 0.75, 'PI_Ki', 7, 'PI_Kaw', 7/0.75))
%
%   Runs the calibration case CALIB (calib_run.m) three times with the same controller: ideal sensors, noisy sensors with seed runSeed and
%   noisy sensors with the second seed of the same range (runSeed + 1). For each run, f = fraction of the scored samples (t >= 2 s) at which
%   the controller COMMAND T_a_cmd reaches the assist limit T_a,max(v) of the Actuator (|T_a_cmd| >= 0.999 * T_a,max(v)). A controller that only
%   saturates when the driver asks for a lot has the same f in all runs; a noise-driven bang-bang controller has a much larger f with noise.
%     B.f_ideal                fraction without noise
%     B.f_noisy                fraction with noise, seed runSeed (kept for the callers of the first version)
%     B.f_noisy2               fraction with noise, seed runSeed + 1
%     B.delta1, B.delta2       f_noisy - f_ideal and f_noisy2 - f_ideal
%     B.delta                  mean of delta1 and delta2 (the noise-induced increase of the time at the limit)
%     B.disp                   |delta1 - delta2|, the spread of delta between the two seeds (QuyChuan 9.4)
%     B.pass_stat              delta <= disp: the statistical rule proposed in QuyChuan 9.4 (measured 2026-10-11: no PID point passes it,
%                              delta is small but systematically positive, so the rule cannot discriminate; reported only)
%     B.pass_ratio             delta <= f_ideal: noise adds no more time at the limit than the load itself already causes (reported)
%     B.pass_limit             delta <= limitFraction (default 0.01, self-chosen 1 %, QuyChuan 5.4; report the sensitivity 0.005-0.05)
%     B.pass                   = pass_limit (the gate in force until the user decides between the three rules; see the log of QuyChuan)
%   Needs the base-workspace variables of load_ref (Tamax_v_bp_ms, Tamax_table) and of the controller.
if nargin < 4, limitFraction = 0.01; end
S = make_cases('CALIB');
bp = evalin('base', 'Tamax_v_bp_ms'); tb = evalin('base', 'Tamax_table');
lim = interp1(bp(:), tb(:), min(max(S.v, bp(1)), bp(end)), 'linear');
w = S.t >= 2;
f = zeros(1, 3);
seeds = {[], runSeed, runSeed + 1};
for k = 1:3
    L = calib_run(mdl, seeds{k}, vars);
    f(k) = mean(abs(L.T_a_cmd(w)) >= 0.999 * lim(w));
end
d1 = f(2) - f(1); d2 = f(3) - f(1); dm = (d1 + d2) / 2;
B = struct('f_ideal', f(1), 'f_noisy', f(2), 'f_noisy2', f(3), 'delta1', d1, 'delta2', d2, 'delta', dm, 'disp', abs(d1 - d2), ...
    'pass_stat', dm <= abs(d1 - d2), 'pass_ratio', dm <= f(1), 'pass_limit', dm <= limitFraction, 'pass', dm <= limitFraction);
end
