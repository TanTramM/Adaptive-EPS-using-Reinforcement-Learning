function check_mappid_plug()
%CHECK_MAPPID_PLUG Step 1 of PhuongPhap_TimThamSo.txt 15.3: the box reproduces the locked Map, and one evaluation runs.
%   Map block locked to map.json, PID block = pid.json design; seed 30000; nothing is written to PlugPlay.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
[u0, xMap] = mappid_plug_u0(modelDir);
xBack = mappid_u2x(u0);
fprintf('check_mappid_plug: round trip OK, max relative error %.3g\n', max(abs(xBack(1:5) - xMap) ./ abs(xMap)));
P = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); d = P.design;
x = [xMap, d.Kp, d.Ki, d.Kd, d.Tf];
o = mappid_eval(x, 30000, '');
Simulink.sdi.clear;
assert(o.simulated == 1 && isfinite(o.R) && isfinite(o.S), 'check_mappid_plug: evaluation did not simulate (c = %s).', mat2str(o.c, 4));
fprintf('check_mappid_plug: PASS (R %.4f %%, S %.5f Nm, J %.5f, e_rel %.3f %%, PM %.2f, GM %.2f, c = %s)\n', ...
    o.R, o.S, o.J, o.erel, o.PM, o.GM, mat2str(o.c, 4));
end
