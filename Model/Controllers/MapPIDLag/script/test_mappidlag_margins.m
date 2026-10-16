function test_mappidlag_margins()
%TEST_MAPPIDLAG_MARGINS Check mappidlag_margins.m against mappid_margins.m (the MapPID tool, already tested against map.json and the PID design):
%   with the lag of the sum set to the identity (z1 = p1) and the lead of mappid_margins set to the identity (z = p), the two loops are the same, so PM, GM,
%   stability and the high-frequency gain must agree to 1e-9 for a Map + PID design; and with Kmax = 0 and a lag, the loop must equal that of mappid_margins
%   for a PID whose controller carries the same lag (lead = identity, lag on the "Map branch" is NOT the same: so this second check builds the lag into the
%   PID by hand with an explicit loop). Also prints the margins of the MapPID design of mappid.json when it exists, as information.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
[Gj, w] = mappidlag_plants();
% (1) lag = identity, lead = identity: equal to mappid_margins
dN = struct('Kmax', 3.5, 'lag', struct('z1', 50, 'p1', 50), 'Kp', 0.6, 'Ki', 40, 'Kd', 0.04, 'Tf', 0.0025);
dO = struct('Kmax', 3.5, 'lead', struct('z', 50, 'p', 50), 'Kp', 0.6, 'Ki', 40, 'Kd', 0.04, 'Tf', 0.0025);
A = mappidlag_margins(Gj, w, dN); B = mappid_margins(Gj, w, dO);
fprintf('[MapPIDLag margins] identity lag: PM %.6f GM %.6f stable %d | mappid_margins: PM %.6f GM %.6f stable %d\n', A.PM, A.GM, A.stable, B.PM, B.GM, B.stable);
assert(A.stable == B.stable && abs(A.PM - B.PM) < 1e-9 && abs(A.GM - B.GM) < 1e-9, 'identity lag must reproduce mappid_margins');
assert(abs(A.HF - B.HF) < 1e-9, 'high-frequency gain differs');
% (2) lag on a PID alone: equal to an independent loop computed here for two plants
d2 = struct('Kmax', 0, 'lag', struct('z1', 60, 'p1', 20), 'Kp', 1.2, 'Ki', 25, 'Kd', 0.02, 'Tf', 0.004);
R2 = mappidlag_margins(Gj(1:2), w, d2);
pmE = Inf; gmE = Inf; jw = 1i * w; wm = 2 * pi * 100;
for ip = 1:2
    L = -(1 + jw / 60) ./ (1 + jw / 20) .* (1.2 + 25 ./ jw + 0.02 * jw ./ (0.004 * jw + 1)) .* (wm ./ (jw + wm) .* exp(-jw * 1e-3)) .* Gj{ip};
    mag = abs(L); ph = unwrap(angle(L)); ph = ph - 2 * pi * round(ph(1) / (2 * pi));
    i1 = find((mag(1:end-1) - 1) .* (mag(2:end) - 1) < 0);
    for i = i1(:)'
        f = (mag(i) - 1) / (mag(i) - mag(i + 1)); pmE = min(pmE, 180 + rad2deg(ph(i) + f * (ph(i + 1) - ph(i))));
    end
    q = ph + pi; jj = find(q(1:end-1) .* q(2:end) < 0 | (ph(1:end-1) + 3 * pi) .* (ph(2:end) + 3 * pi) < 0);
    for i = jj(:)', gmE = min(gmE, 1 / (0.5 * mag(i) + 0.5 * mag(i + 1))); end
end
fprintf('[MapPIDLag margins] PID + lag, plants 1-2: PM %.4f (independent %.4f), GM %.4f (independent %.4f)\n', R2.PM, pmE, R2.GM, gmE);
assert(abs(R2.PM - pmE) < 1e-9 && abs(R2.GM - gmE) < 1e-9, 'PID + lag margins differ from the independent loop');
fprintf('[MapPIDLag margins] TEST PASS\n');
end
