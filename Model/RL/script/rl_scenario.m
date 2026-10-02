function sc = rl_scenario(vKmh, theta1Hold, muAfter, tStep, tEnd)
%RL_SCENARIO Scenario played by the RL environment (step 1: one fixed hold-angle scenario).
%
%   sc = rl_scenario()                                  40 km/h, theta1 0.774 rad, mu 0.8 -> 0.3 at 12 s, 30 s
%   sc = rl_scenario(vKmh, theta1Hold, muAfter, tStep, tEnd)
%
%   The steering wheel angle ramps from 0 to theta1Hold in 0.5 s and is held; mu steps from 0.8 to muAfter at
%   tStep. Same shape as the open-loop check of Documents/Plant/plant.txt section 6.3, so with T_a = 0 the
%   result is known in advance. Returns sc.t, sc.theta1 [rad], sc.v [m/s], sc.mu (column vectors).
%   Training scenarios (randomized, separate from TC1-TC6) replace this in step 3.

if nargin < 1, vKmh = 40; end
if nargin < 2, theta1Hold = 0.774; end
if nargin < 3, muAfter = 0.3; end
if nargin < 4, tStep = 12; end
if nargin < 5, tEnd = 30; end

t = (0:0.001:tEnd)';
sc.t      = t;
sc.theta1 = theta1Hold * min(t / 0.5, 1);
sc.v      = vKmh / 3.6 * ones(size(t));
sc.mu     = 0.8 - (0.8 - muAfter) * (t >= tStep);
end
