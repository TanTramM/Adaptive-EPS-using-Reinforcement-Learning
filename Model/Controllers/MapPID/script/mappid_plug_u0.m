function [u0, xMap] = mappid_plug_u0(modelDir)
%MAPPID_PLUG_U0 Starting vector of the plug-in search (PhuongPhap_TimThamSo.txt 15.1).
%   The Map block (K, z, p/z, z1, p1/z1) is LOCKED to the design of data/map.json; the four PID entries of u0 are
%   placeholders (the coarse grid overwrites every free entry). The check is a round trip: mappid_u2x(u0) must return the
%   Map parameters of map.json with relative error below 1e-9, otherwise the box clips the locked Map and the search stops.
if nargin < 1 || isempty(modelDir)
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
end
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
d = J.design;
xMap = [d.Kmax, d.lead.z, d.lead.p / d.lead.z, d.lag.z1, d.lag.p1 / d.lag.z1];
x = [xMap, 1, 10, 0.01, 0.01];
u0 = mappid_x2u(x);
xBack = mappid_u2x(u0);
err = max(abs(xBack(1:5) - xMap) ./ max(abs(xMap), eps));
assert(err < 1e-9, 'mappid_plug_u0:roundTrip', 'Locked Map is clipped by the box or the round trip fails (relative error %.3g).', err);
end
