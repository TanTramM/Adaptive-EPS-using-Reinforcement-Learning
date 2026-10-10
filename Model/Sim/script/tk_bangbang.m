function B = tk_bangbang(mdl, runSeed, vars, limitFraction)
%TK_BANGBANG No-bang-bang gate of the shared selection rule (Tracking/CLAUDE.md): does sensor noise push the command to the assist limit?
%
%   B = tk_bangbang('Model_PI', 10000, struct('Kp', 0.26, 'Ki', 8, 'Kaw', 8/0.26))
%
%   Runs the calibration case TK (tk_run.m) twice with the same controller, once with ideal sensors and once with noisy sensors (seed runSeed).
%   For each run, f = fraction of the scored samples (t >= 2 s) at which the controller COMMAND T_a_cmd reaches the assist limit T_a,max(v) of
%   the Actuator (|T_a_cmd| >= 0.999 * T_a,max(v)). A controller that only saturates when the driver asks for a lot has the same f in both runs;
%   a noise-driven bang-bang controller has a much larger f with noise.
%     B.f_ideal, B.f_noisy   fractions [-]
%     B.delta                f_noisy - f_ideal
%     B.pass                 delta <= limitFraction (default 0.01, a self-chosen 1 %, report the sensitivity at 0.005-0.05)
%   Needs the base-workspace variables of load_ref (Tamax_v_bp_ms, Tamax_table) and of the controller.
if nargin < 4, limitFraction = 0.01; end
S = test_cases('TK');
bp = evalin('base', 'Tamax_v_bp_ms'); tb = evalin('base', 'Tamax_table');
lim = interp1(bp(:), tb(:), min(max(S.v, bp(1)), bp(end)), 'linear');
w = S.t >= 2;
f = zeros(1, 2);
seeds = {[], runSeed};
for k = 1:2
    L = tk_run(mdl, seeds{k}, vars);
    f(k) = mean(abs(L.T_a_cmd(w)) >= 0.999 * lim(w));
end
B = struct('f_ideal', f(1), 'f_noisy', f(2), 'delta', f(2) - f(1), 'pass', (f(2) - f(1)) <= limitFraction);
end
