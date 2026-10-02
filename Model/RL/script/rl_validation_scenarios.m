function V = rl_validation_scenarios()
%RL_VALIDATION_SCENARIOS Four fixed VALIDATION episodes used to follow the training progress (not test cases, not training).
%
%   V(k).sc   scenario (same fields as rl_scenario_random), V(k).seed sensor noise seed, V(k).name
%   V(1) 'hold_0p25g_v60_mu_drop'  60 km/h, steering ramps to the angle of 0.25 g on the dry road in 1 s and is held,
%                                   mu 0.8 -> 0.3 at 5 s (over-assist on a slippery road)
%   V(2) 'sine_0p15g_v80_mu_drop'  80 km/h, sine steering 0.15 g, 0.5 Hz, mu 0.8 -> 0.4 at 5 s (dynamic tracking)
%   V(3) 'hold_0p20g_v40_mu_drop'  40 km/h, ramp to 0.2 g in 1 s, held, mu 0.8 -> 0.3 at 5 s (the step-1 scenario shape,
%                                   whose open-loop answer is known, Documents/Plant/plant.txt section 6.3)
%   V(4) 'sine_0p20g_v100_dry'     100 km/h, sine steering 0.2 g, 0.5 Hz, dry road all the time (steady accuracy and smoothness
%                                   where Map and PID are good)
%   All 10 s, sensor level 'high' with seeds 80001-80004: a range separate from the training seeds (1-9999) and from the test
%   seeds (90001-90010). The same episodes are run for Map and PID once, as the reference. Four episodes instead of two so that
%   the choice of the best agent depends less on one scenario (Train1 chose it from two).

T = rl_angle_table();
t = (0:0.001:10)';
ramp = (1 - cos(pi * min(t / 1, 1))) / 2;
fade = (1 - cos(pi * min(t / 0.5, 1))) / 2;

V(1).name = 'hold_0p25g_v60_mu_drop';
V(1).sc = pack(t, 0.25 * ramp, 60, 0.8 - 0.5 * (t >= 5), T);
V(1).seed = 80001;

V(2).name = 'sine_0p15g_v80_mu_drop';
V(2).sc = pack(t, 0.15 * fade .* sin(2 * pi * 0.5 * t), 80, 0.8 - 0.4 * (t >= 5), T);
V(2).seed = 80002;

V(3).name = 'hold_0p20g_v40_mu_drop';
V(3).sc = pack(t, 0.20 * ramp, 40, 0.8 - 0.5 * (t >= 5), T);
V(3).seed = 80003;

V(4).name = 'sine_0p20g_v100_dry';
V(4).sc = pack(t, 0.20 * fade .* sin(2 * pi * 0.5 * t), 100, 0.8 * ones(size(t)), T);
V(4).seed = 80004;
end

function sc = pack(t, a, vK, mu, T)
    sc.t = t;
    sc.theta1 = sign(a) .* interp2(T.ay, T.v, T.th, min(abs(a), T.ay(end)), vK * ones(size(a)), 'linear');
    sc.v = vK / 3.6 * ones(size(t));
    sc.mu = mu;
    sc.ayTarget = a;
end
