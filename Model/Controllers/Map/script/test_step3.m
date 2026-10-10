function test_step3()
%TEST_STEP3 Standalone test for Step 3 of Map controller:
%   1. Linearized plant DC gain and column resonance properties
%   2. Uncompensated loop at K = 6.75 has PM < 0 (unstable without lead)
%   3. Compensated loop with lead achieves PM >= 45 deg, GM >= 2
%   4. Robustness: PM >= 45 deg across all 68 operating conditions at K = 6.75
%   5. Stability boundary K_stab = 9.5: feasible at 9.5, unfeasible at 10.0
%   6. Verifies Map_stability_lead_sweep.csv
%
%   Prints "[test_step3] TEST PASS" when all assertions hold.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

P   = map_params();
ops = map_op_points();
w   = logspace(-1, 5, 6000)';

%% 1. Plant linearization test
fprintf('[test_step3] Testing plant linearization properties...\n');
G60 = map_plant_lin(P, 60 / 3.6, 0.3 * P.g, 0.8);
dc_gain = dcgain(G60);
assert(dc_gain < -0.80 && dc_gain > -1.0, sprintf('DC gain of Plant must be near -0.83, got %g', dc_gain));

% Pole analysis
p_sys = pole(G60);
% Must have a column oscillatory pole pair near 36-40 rad/s
wn = abs(p_sys);
col_poles = wn(wn > 30 & wn < 45);
assert(numel(col_poles) >= 2, 'Plant must have column resonance pole pair near 36-40 rad/s');

%% 2. Uncompensated loop failure at K = 6.75
fprintf('[test_step3] Testing uncompensated loop failure...\n');
Gjw60 = squeeze(freqresp(G60, w));
R_uncomp = map_margins(Gjw60, w, 6.75, Inf, Inf);
assert(R_uncomp.PM < 0, sprintf('Uncompensated loop must have negative phase margin, got %g deg', R_uncomp.PM));
assert(abs(R_uncomp.PM - (-6.7)) < 1.0, sprintf('Uncompensated PM should be near -6.7 deg, got %g', R_uncomp.PM));

%% 3. Compensated loop with lead at K = 6.75
fprintf('[test_step3] Testing compensated loop with lead (z = 59.82, p = 1665.96)...\n');
z_des = 59.82;
p_des = 1665.96;
R_comp = map_margins(Gjw60, w, 6.75, z_des, p_des);
assert(R_comp.stable == 1, 'Compensated loop must be stable');
assert(R_comp.PM >= 45.0, sprintf('Compensated loop PM must be >= 45 deg, got %g', R_comp.PM));
assert(R_comp.GM >= 2.0, sprintf('Compensated loop GM must be >= 2.0, got %g', R_comp.GM));
assert(abs(R_comp.wc - 161) < 5.0, sprintf('Compensated crossover should be near 161 rad/s, got %g', R_comp.wc));

%% 4. Robustness across all 68 operating conditions at K = 6.75
fprintf('[test_step3] Testing robustness across all 68 operating conditions...\n');
Cal = calibrate_map_cached();
kset = 6.75 * [0.25, 0.5, 0.75, 1.0];
for iv = 1:numel(Cal.v_kmh)
    v_ms = Cal.v_kmh(iv) / 3.6;
    for i = 1:size(ops, 1)
        G_op = map_plant_lin(P, v_ms, ops(i, 1) * P.g, ops(i, 2));
        Gjw_op = squeeze(freqresp(G_op, w));
        for ik = 1:numel(kset)
            R_op = map_margins(Gjw_op, w, kset(ik), z_des, p_des);
            assert(R_op.stable == 1, sprintf('Instability at v=%d, op=%d, k=%g', Cal.v_kmh(iv), i, kset(ik)));
            assert(R_op.PM >= 44.9, sprintf('PM violated (%g deg) at v=%d, op=%d, k=%g', R_op.PM, Cal.v_kmh(iv), i, kset(ik)));
            assert(R_op.GM >= 2.0, sprintf('GM violated (%g) at v=%d, op=%d, k=%g', R_op.GM, Cal.v_kmh(iv), i, kset(ik)));
        end
    end
end

%% 5. Stability boundary K_stab = 9.5
fprintf('[test_step3] Testing stability boundary K_stab = 9.5...\n');
% Precompute 4 representative plants at 60 km/h
Gj60 = cell(size(ops, 1), 1);
for i = 1:size(ops, 1)
    Gj60{i} = squeeze(freqresp(map_plant_lin(P, 60 / 3.6, ops(i, 1) * P.g, ops(i, 2)), w));
end

D_9p5 = design_lead(Gj60, w, 9.5);
assert(D_9p5.ok == 1, 'K = 9.5 must have a feasible lead compensator');
assert(D_9p5.PM >= 45.0, 'K = 9.5 PM must be >= 45 deg');

D_10 = design_lead(Gj60, w, 10.0);
assert(D_10.ok == 0, 'K = 10.0 must NOT have any feasible lead on the grid (proves K_stab = 9.5)');

%% 6. Verify sweep CSV
fprintf('[test_step3] Verifying Map_stability_lead_sweep.csv...\n');
csvPath = fullfile(result_dir('Map', 'Design'), 'Map_stability_lead_sweep.csv');
if ~exist(csvPath, 'file')
    sweep_stability();
end
assert(exist(csvPath, 'file') == 2, 'Map_stability_lead_sweep.csv must exist');
T = readtable(csvPath);
assert(any(T.K == 6.75 & T.stable_lead_found == 1), 'CSV must contain successful design at K = 6.75');
assert(any(T.K == 9.5 & T.stable_lead_found == 1), 'CSV must contain successful design at K = 9.5');
assert(any(T.K == 10.0 & T.stable_lead_found == 0), 'CSV must confirm no feasible lead at K = 10.0');

fprintf('\n========================================\n');
fprintf('[test_step3] TEST PASS\n');
fprintf('========================================\n');
end

