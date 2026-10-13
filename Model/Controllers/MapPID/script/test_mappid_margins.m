function test_mappid_margins()
%TEST_MAPPID_MARGINS Verify mappid_margins.m (linear margins of the MapPID loop over 68 linearized Plants x 5 slopes).
%   (1) PID branch OFF (Kp = Ki = Kd = 0), Map design of data/map.json: PM and GM equal the values recorded by the Map design (map.json PM_deg, GM),
%       which were computed by map_margins over the same 68 plants and the slopes Kmax x {0.25, 0.5, 0.75, 1}.
%   (2) Map branch OFF (Kmax = 0), PID of data/pid.json: stable (its PM is about 38 deg, the PID was never designed for 45); and, under the stress of QuyChuan 5.2 (loop gain x2, one more
%       sample of delay), the verdict is compared with the PID stability boundary of scan_pid_stability.m as INFORMATION only (different linear models):
%       (information only, not asserted:
%       the two models differ, so a few points near the boundary may disagree).
%   (3) the high-frequency gain R.HF equals Kmax (p/z)(p1/z1) + Kp + Kd/Tf computed here by hand; a gain of Kp = 20 is unstable.
%   (4) k = 0 only (Kmax = 0): the margin of a pure PID does not depend on the lead-lag fields.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Jp = jsondecode(fileread(fullfile(modelDir, 'data', 'pid.json'))); q = Jp.design;
[Gj, w, info] = mappid_plants();
assert(numel(Gj) == 68 && numel(info.v_kmh) == 68, 'expected 68 plants');

%% (1) Map alone reproduces the recorded design margins
d1 = struct('Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005);
R1 = mappid_margins(Gj, w, d1);
fprintf('[MapPID] (1) Map alone: PM %.3f deg (map.json %.3f), GM %.3f (map.json %.3f), stable %d\n', R1.PM, dm.PM_deg, R1.GM, dm.GM, R1.stable);
assert(R1.stable && abs(R1.PM - dm.PM_deg) < 0.05 && abs(R1.GM - dm.GM) < 0.02, 'Map alone does not reproduce the margins recorded in map.json');

%% (2) PID alone: nominal and under stress, against the stability boundary of scan_pid_stability
d2 = struct('Kmax', 0, 'lead', dm.lead, 'lag', dm.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
R2 = mappid_margins(Gj, w, d2);
fprintf('[MapPID] (2) PID alone (pid.json): PM %.2f deg, GM %.2f, stable %d, HF gain %.2f\n', R2.PM, R2.GM, R2.stable, R2.HF);
assert(R2.stable && R2.PM > 30 && R2.GM > 2, 'the PID of pid.json must be stable with PM > 30 deg and GM > 2 on the 68 plants');
% information only: agreement with the boundary of scan_pid_stability.m (two plants, discrete PID, another stress); NOT asserted. The models differ
% (68 plants with the vehicle dynamics against 2 column plants) and a loop with an integrator is conditionally stable (stable although |L| > 1 at a
% -180 deg crossing, GM < 1), where gain x2 can even re-stabilise a loop that is unstable at nominal gain; the nonlinear simulation gate decides.
B = readtable(fullfile(result_dir('PID', 'Design'), 'PID_stability_boundary.csv'));
rows = find(abs(B.Kd_s - q.Kd) < 1e-9 & abs(B.Tf_s - q.Tf) < 1e-9);
if isempty(rows), rows = find(B.Kd_s == 0.02 & abs(B.Tf_s - 0.0025) < 1e-9); end
agree = 0; total = 0;
for r = rows'
    kiOk = B.max_Ki_contig(r);
    if kiOk == 0, continue; end
    dd = struct('Kmax', 0, 'lead', dm.lead, 'lag', dm.lag, 'Kp', B.Kp(r), 'Ki', kiOk, 'Kd', B.Kd_s(r), 'Tf', B.Tf_s(r));
    Rs = mappid_margins(Gj, w, dd, 2e-3, 2); total = total + 1; agree = agree + Rs.stable;
end
fprintf('[MapPID] (2) info: %d of %d points that scan_pid_stability calls stable under stress are also stable here (68 plants)\n', agree, total);

%% (3) high-frequency gain by hand; an obviously unstable gain
d3 = struct('Kmax', 5, 'lead', struct('z', 30, 'p', 400), 'lag', struct('z1', 25, 'p1', 9), 'Kp', 0.5, 'Ki', 20, 'Kd', 0.01, 'Tf', 0.004);
R3 = mappid_margins(Gj, w, d3);
hf = 5 * (400 / 30) * (9 / 25) + 0.5 + 0.01 / 0.004;
assert(abs(R3.HF - hf) < 1e-12, 'HF gain mismatch: %.6g vs %.6g', R3.HF, hf);
d4 = d3; d4.Kp = 20;
R4 = mappid_margins(Gj, w, d4);
fprintf('[MapPID] (3) HF gain %.4f (by hand %.4f); Kp = 20 stable = %d (must be 0)\n', R3.HF, hf, R4.stable);
assert(~R4.stable, 'Kp = 20 must be unstable');

%% (4) the lead-lag fields do not matter when Kmax = 0
d5 = d2; d5.lead = struct('z', 10, 'p', 90); d5.lag = struct('z1', 100, 'p1', 20);
R5 = mappid_margins(Gj, w, d5);
assert(abs(R5.PM - R2.PM) < 1e-9 && abs(R5.GM - R2.GM) < 1e-9, 'with Kmax = 0 the margins must not depend on the lead-lag');
fprintf('[MapPID] TEST PASS (margins)\n');
end
