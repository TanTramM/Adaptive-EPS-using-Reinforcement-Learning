function test_map_opt()
%TEST_MAP_OPT Check the optimisation layer of Map (map_opt_eval, map_opt_margins, map_u2x/map_x2u) before the search on CALIB v2.
%   (1) u -> x -> u round trip and realizable designs;  (2) the linear margins of the design stored in data/map.json equal its stored PM and GM;
%   (3) one simulation of that design on CALIB v2 (seed 0, about 25 s): finite R, S and e_rel (J is Inf when e_rel > 5 %); the same design through the csv cache returns the same J. Prints "[Map] OPT TEST PASS".
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
worst = 0;
for k = 1:200
    u = rand(1, 5); x = map_u2x(u);
    assert(x(2) * x(3) <= pi / 1e-3 * (1 + 1e-9) && x(4) * x(5) >= 3 * (1 - 1e-9) && x(3) >= 1 && x(5) <= 1, 'design not realizable');
    worst = max(worst, max(abs(map_x2u(x) - u)));
end
assert(worst < 1e-9, 'u2x / x2u round trip');
fprintf('[Map] (1) u2x / x2u round trip %.2g, 200 random designs realizable\n', worst);

J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
dm = J.design;
[Gj, w] = map_opt_plants();
R = map_opt_margins(Gj, w, struct('Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag));
fprintf('[Map] (2) margins of the stored design: PM %.3f deg (stored %.3f), GM %.3f (%.3f)\n', R.PM, dm.PM_deg, R.GM, dm.GM);
assert(abs(R.PM - dm.PM_deg) < 0.05 && abs(R.GM - dm.GM) < 0.01, 'margins differ from map.json');

x = [dm.Kmax, dm.lead.z, dm.lead.p / dm.lead.z, dm.lag.z1, dm.lag.p1 / dm.lag.z1];
tmp = [tempname '.csv'];
o = map_opt_eval(x, 0, tmp);
assert(o.simulated == 1 && all(isfinite([o.R o.S o.erel])), 'simulation did not run');
o2 = map_opt_eval(x, 0, tmp);
assert(o2.cached && (isequal(o2.J, o.J) || abs(o2.J - o.J) < 1e-9 * o.J), 'csv cache');
delete(tmp);
fprintf('[Map] (3) stored design on CALIB v2: R %.2f %%, S %.4f, J %.4f, e_rel %.2f %%, c = %s\n', o.R, o.S, o.J, o.erel, mat2str(o.c, 3));
Simulink.sdi.clear;
fprintf('[Map] OPT TEST PASS\n');
end
