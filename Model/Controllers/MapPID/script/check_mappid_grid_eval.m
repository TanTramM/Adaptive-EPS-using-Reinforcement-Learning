function check_mappid_grid_eval()
%CHECK_MAPPID_GRID_EVAL Reproduce one pre-grid MapPID evaluation.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
J = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json')));
d = J.design;
x = [d.Kmax, d.lead.z, d.lead.p / d.lead.z, d.lag.z1, d.lag.p1 / d.lag.z1, d.Kp, d.Ki, d.Kd, d.Tf];
o = mappid_eval(x, 30000, '');
assert(abs(o.R - 2.61563957) < 1e-3, 'MapPID R reproduction failed: %.9g.', o.R);
assert(abs(o.S - 0.7301092583) < 1e-3, 'MapPID S reproduction failed: %.9g.', o.S);
assert(abs(o.J - 1.909702666) < 2e-3, 'MapPID J reproduction failed: %.9g.', o.J);
fprintf('check_mappid_grid_eval: PASS (R %.6f, S %.6f, J %.6f)\n', o.R, o.S, o.J);
end
