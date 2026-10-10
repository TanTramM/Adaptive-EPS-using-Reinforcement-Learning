function A = map_k_accuracy(tolPct, Ts0)
%MAP_K_ACCURACY Smallest slope limit K (grid 0.25) where dry-road steady error
%   stays within tolPct (default 3 %) of T_d,ref over a_y in [0.1, 0.3] g for every speed.
%   Writes Result/Controllers/Map/Design/Map_K_for_accuracy.csv.
if nargin < 1, tolPct = 3; end
if nargin < 2, Ts0 = 0.3; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

Cal = calibrate_map_cached();
Ks = 0.25:0.25:20;
n = numel(Cal.v_kmh);
A.v_kmh = Cal.v_kmh;
A.Kmin = nan(n, 1);
A.err_at_Kmin = nan(n, 1);
A.natural_max = nan(n, 1);

for iv = 1:n
    sl = Cal.slope{iv};
    ay = Cal.ay_g{iv};
    mNat = ay >= 0.105 & ay <= 0.3 + 1e-9;
    if any(mNat)
        A.natural_max(iv) = max(sl(mNat));
    else
        A.natural_max(iv) = max(sl(2:end));
    end
    for K = Ks
        E = map_dry_error(Cal, iv, K, Ts0);
        m = E.ay_g >= 0.1 - 1e-9 & E.ay_g <= 0.3 + 1e-9;
        e = max(abs(E.pct(m)));
        if e <= tolPct
            A.Kmin(iv) = K;
            A.err_at_Kmin(iv) = e;
            break;
        end
    end
end

T = table(A.v_kmh, A.Kmin, A.err_at_Kmin, A.natural_max, ...
    'VariableNames', {'v_kmh', 'Kmin_for_accuracy', 'max_err_pct_at_Kmin', 'natural_slope_max_0p1_0p3g'});
outDir = result_dir('Map', 'Design');
csvPath = fullfile(outDir, 'Map_K_for_accuracy.csv');
writetable(T, csvPath);
fprintf('map_k_accuracy: written %s\n', csvPath);
end

