% Static (analytic) bias of Map at the 11 STEADY scoring windows of thesis chapter 5, to compare with the simulated bias of Table 5.3.
%   Same method as section 3.2: steady cornering T_r from map_steady_state, equilibrium T_s + M(v, T_s) = T_r of the Map table built from the dry-road
%   calibration (K_max and T_s0 of the selected design in Model/shared/data/map.json), bias = 100 (T_s - T_ref)/T_ref. No column friction, no dynamics.
%   Writes Documents/Thesis/figures/ch5_static.csv. Nothing is typed by hand except the eleven (speed, nominal acceleration) pairs of the STEADY sequence.
% Run: matlab -softwareopengl -batch "run('<repo>\tools\make_ch5_static.m')"
repoDir = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(repoDir, 'Model'); dataDir = fullfile(modelDir, 'shared', 'data');
addpath(fullfile(modelDir, 'shared')); setup_paths;
P = map_params();
J = jsondecode(fileread(fullfile(dataDir, 'map.json'), 'Encoding', 'UTF-8')); d = J.design;
ref = jsondecode(fileread(fullfile(dataDir, 'ref.json'), 'Encoding', 'UTF-8'));
Cal = calibrate_map(false);
tref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ay, v, 'linear');
lev = [25 0.15; 25 0.25; 45 0.15; 45 0.25; 45 0.35; 65 0.15; 65 0.25; 65 0.35; 85 0.15; 85 0.25; 85 0.38];
n = size(lev, 1);
Tref = nan(n, 1); Tr = Tref; Ts = Tref; eps_st = Tref; slope = Tref; ayMax = Tref;
for k = 1:n
    v = lev(k, 1); ay = lev(k, 2);
    iv = find(Cal.v_kmh == v); M = map_table(Cal, iv, d.Kmax, d.Ts0);
    Tref(k) = tref(v, ay);
    Tr(k) = map_steady_state(P, v / 3.6, ay * P.g, 0.8).T_r;
    Ts(k) = fzero(@(x) x + map_eval(M, x) - Tr(k), [0, Tr(k)]);     % one root: both terms are nondecreasing
    eps_st(k) = 100 * (Ts(k) - Tref(k)) / Tref(k);
    sl = Cal.slope{iv}; a = Cal.ay_g{iv}; [~, j] = min(abs(a - ay));
    slope(k) = sl(j); ayMax(k) = a(end);
end
T = table(lev(:, 1), lev(:, 2), Tref, Tr, Ts, eps_st, slope, repmat(d.Kmax, n, 1), ayMax, ...
    'VariableNames', {'v_kmh', 'ay_g', 'Tref_Nm', 'Tr_Nm', 'Ts_static_Nm', 'eps_static_pct', 'natural_slope', 'Kmax', 'table_ay_max_g'});
writetable(T, fullfile(repoDir, 'Documents', 'Thesis', 'figures', 'ch5_static.csv'));
disp(T);

% the two speed ramps of SLIP (45 to 90 km/h at a nominal 0.20 g on the dry road): static bias of Map at each calibrated speed
vr = 45:5:90; ay = 0.20; er = nan(numel(vr), 1);
for k = 1:numel(vr)
    iv = find(Cal.v_kmh == vr(k)); M = map_table(Cal, iv, d.Kmax, d.Ts0);
    Trr = map_steady_state(P, vr(k) / 3.6, ay * P.g, 0.8).T_r;
    Tsr = fzero(@(x) x + map_eval(M, x) - Trr, [0, Trr]);
    er(k) = 100 * (Tsr - tref(vr(k), ay)) / tref(vr(k), ay);
end
T2 = table(vr(:), repmat(ay, numel(vr), 1), er, 'VariableNames', {'v_kmh', 'ay_g', 'eps_static_pct'});
writetable(T2, fullfile(repoDir, 'Documents', 'Thesis', 'figures', 'ch5_static_ramp.csv'));
disp(T2);
disp('make_ch5_static: done');
