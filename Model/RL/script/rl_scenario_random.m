function sc = rl_scenario_random(seed, tEnd, stage)
%RL_SCENARIO_RANDOM One randomized TRAINING episode (step 3 of Documents/RL/DieuKhien_RL.txt).
%
%   sc = rl_scenario_random(seed)                 10 s episode, full range (stage 3)
%   sc = rl_scenario_random(seed, tEnd, stage)    stage 1, 2 or 3 of the curriculum (train_rl.m raises the stage with the episodes)
%
%   Built the same way as the standard test cases (controller-independent steering angle from a target lateral
%   acceleration on the dry road with ideal assist, rl_angle_table.m), with random values drawn from the stream of seed:
%     speed            v      uniform 20-100 km/h, constant in the episode
%     target a_y       |a*|   uniform 0.05 g - f * min(a_y,max(v, 0.8), 0.35 g), f = 0.6 (stage 1) or 0.9 (stages 2, 3)
%     direction        sign   +-1
%     steering shape   hold (1 - cos ramp in 0.5-1.5 s, then held) or sine (0.2-1.0 Hz, 0.5 s fade-in), 50/50
%     friction         stage 1: mu = 0.8 all episode, no step (dry road, learn the tracking and the smoothness first);
%                      stage 2: mu0 uniform 0.6-0.8; with probability 0.8 one step at t in 3-7 s to mu1 uniform 0.4-0.8 (mild);
%                      stage 3: mu0 uniform 0.4-0.8; with probability 0.8 one step at t in 3-7 s to mu1 uniform 0.2-0.8
%                      (drop or rise); the driver keeps the same angle (does not know mu)
%   The values differ from TC1-TC6 by construction (random continuous values, one step only, 10 s): training never
%   replays a test case. Returns sc.t, sc.theta1 [rad], sc.v [m/s], sc.mu, sc.ayTarget [g] and sc.info (drawn values).

if nargin < 2 || isempty(tEnd), tEnd = 10; end
if nargin < 3, stage = 3; end
s = RandStream('mt19937ar', 'Seed', seed);
T = rl_angle_table();
t = (0:0.001:tEnd)';

vK = 20 + 80 * rand(s);
ayLim = min(interp1(T.aylim_v_kmh, T.aylim_g, vK, 'linear'), 0.35);
fAmp = 0.9 - 0.3 * (stage == 1);
amp = 0.05 + (fAmp * ayLim - 0.05) * rand(s);
sgn = 2 * (rand(s) < 0.5) - 1;
isSine = rand(s) < 0.5;
if ~isSine
    tRamp = 0.5 + rand(s);
    a = amp * (1 - cos(pi * min(t / tRamp, 1))) / 2;
    f = NaN;
else
    f = 0.2 + 0.8 * rand(s);
    fade = (1 - cos(pi * min(t / 0.5, 1))) / 2;
    a = amp * fade .* sin(2 * pi * f * t);
    tRamp = NaN;
end
a = sgn * a;

% friction: the random numbers are always drawn in the same order, the stage only changes their ranges
r0 = rand(s); rStep = rand(s); rT = rand(s); r1 = rand(s);
switch stage
    case 1, mu0 = 0.8;               hasStep = false; mu1lo = 0.8; mu1hi = 0.8;
    case 2, mu0 = 0.6 + 0.2 * r0;    hasStep = rStep < 0.8; mu1lo = 0.4; mu1hi = 0.8;
    otherwise, mu0 = 0.4 + 0.4 * r0; hasStep = rStep < 0.8; mu1lo = 0.2; mu1hi = 0.8;
end
tStep = 3 + 4 * rT;
mu1 = mu1lo + (mu1hi - mu1lo) * r1;
mu = mu0 * ones(size(t));
if hasStep
    mu(t >= tStep) = mu1;
else
    tStep = NaN; mu1 = mu0;
end

sc.t = t;
sc.theta1 = sign(a) .* interp2(T.ay, T.v, T.th, min(abs(a), T.ay(end)), min(max(vK, 20), 100) * ones(size(a)), 'linear');
sc.v = vK / 3.6 * ones(size(t));
sc.mu = mu;
sc.ayTarget = a;
sc.info = struct('seed', seed, 'stage', stage, 'v_kmh', vK, 'amp_g', amp, 'sign', sgn, 'sine', isSine, 'freq_Hz', f, 'ramp_s', tRamp, ...
    'mu0', mu0, 'mu_step', hasStep, 't_step_s', tStep, 'mu1', mu1);
end
