function T = sweep_stability()
%SWEEP_STABILITY Analyzes loop stability and designs lead compensators across K values.
%   Evaluates 68 linearized plant conditions (17 speeds x 4 operating points).
%   Finds optimal lead (z, p), PM, GM, crossover wc, HF gain, noise std, and K_stab.
%   Writes Result/Controllers/Map/Design/Map_stability_lead_sweep.csv.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Design');

P   = map_params();
Cal = calibrate_map_cached();
ops = map_op_points();
w   = logspace(-1, 5, 6000)';

sensors = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
res = sensors.signals.T_s.resolution;
sigTs = sqrt(res^2 + res^2 / 12);     % noise 1 step + quantizer variance

% Precompute frequency responses for all 68 operating plants
fprintf('sweep_stability: precomputing 68 plant frequency responses...\n');
Gj = cell(numel(Cal.v_kmh) * size(ops, 1), 1);
idx = 1;
for iv = 1:numel(Cal.v_kmh)
    v_ms = Cal.v_kmh(iv) / 3.6;
    for i = 1:size(ops, 1)
        Gj{idx} = squeeze(freqresp(map_plant_lin(P, v_ms, ops(i, 1) * P.g, ops(i, 2)), w));
        idx = idx + 1;
    end
end

Ks = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 6.75, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 9.75, 10.0, 12.0];
rows = [];

fprintf('sweep_stability: designing lead across K grid...\n');
for K = Ks
    D = design_lead(Gj, w, K);
    noise = NaN;
    if D.ok
        noise = map_noise_gain(K, D.z, D.p) * sigTs;
    end
    rows(end+1, :) = [K, D.ok, D.z, D.p, D.PM, D.GM, D.wc, D.HF, noise, D.nFeasible]; %#ok<AGROW>
    fprintf('  K %5.2f | ok %d | z %6.1f | p %7.1f | PM %5.1f | GM %4.2f | HF %6.1f | noise %.3f N.m | feasible %4d\n', ...
        K, D.ok, D.z, D.p, D.PM, D.GM, D.HF, noise, D.nFeasible);
end

T = array2table(rows, 'VariableNames', {'K', 'stable_lead_found', 'z_rad_s', 'p_rad_s', ...
    'PM_deg', 'GM', 'wc_rad_s', 'HF_gain', 'Ta_noise_std_Nm', 'n_feasible_leads'});
csvPath = fullfile(outDir, 'Map_stability_lead_sweep.csv');
writetable(T, csvPath);

okK = T.stable_lead_found == 1;
Kstab = max(T.K(okK));
fprintf('sweep_stability: K_stab = %g (largest K with PM >= 45 deg, GM >= 2)\n', Kstab);
fprintf('sweep_stability: written %s\n', csvPath);
end

