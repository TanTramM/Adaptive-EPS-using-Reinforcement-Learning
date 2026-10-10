function test_step2()
%TEST_STEP2 Standalone test for Step 2 of Map controller:
%   1. map_table: dead zone, monotonicity, non-negativity, slope limit <= Kmax, bounded by calibration
%   2. map_eval: dead zone zero, anti-symmetry, saturation, interpolation at breakpoints
%   3. map_dry_error: equilibrium residual |T_s - T_r + M(T_s)| < 1e-11, non-negative error e_T >= 0
%   4. map_k_accuracy: CSV generated, K_acc satisfies error <= 3 % on [0.1, 0.3] g, and K_acc - 0.25 fails (> 3 %)
%
%   Prints "[test_step2] TEST PASS" when all assertions hold.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

fprintf('[test_step2] Loading calibration...\n');
Cal = calibrate_map_cached();
n = numel(Cal.v_kmh);
Ts0 = 0.3;

%% 1. Test map_table on multiple speeds and Kmax values
fprintf('[test_step2] Testing map_table properties...\n');
testKs = [1.0, 4.0, 6.75, 10.0, 15.0];
for iv = [1, 5, 9, 13, 17] % sample speeds: 20, 40, 60, 80, 100 km/h
    for Kmax = testKs
        M = map_table(Cal, iv, Kmax, Ts0);
        
        % Deadzone start
        assert(abs(M.Ts(1) - Ts0) < 1e-12, 'M.Ts(1) must equal Ts0');
        assert(abs(M.Ta(1) - 0) < 1e-12, 'M.Ta(1) must equal 0');
        
        % Monotonicity and non-negativity
        assert(all(M.Ta >= 0), 'M.Ta must be non-negative');
        dTa = diff(M.Ta);
        dTs = diff(M.Ts);
        assert(all(dTa >= -1e-12), 'M.Ta must be non-decreasing');
        assert(all(dTs > 1e-9), 'M.Ts must be strictly increasing');
        
        % Slope limit <= Kmax
        slopes = dTa ./ dTs;
        assert(all(slopes <= Kmax + 1e-9), sprintf('Slope must not exceed Kmax (%g), max found %g', Kmax, max(slopes)));
        
        % Bounded by calibration points
        Ta_cal = Cal.Ta{iv}(:);
        assert(all(M.Ta(2:end) <= Ta_cal + 1e-9), 'M.Ta must be bounded from above by Ta_cal');
        
        % If Kmax is very large, M must match Ta_cal exactly (except deadzone connection)
        if Kmax >= 200
            assert(max(abs(M.Ta(2:end) - Ta_cal)) < 1e-9, 'Large Kmax must follow Ta_cal exactly');
        end
    end
end

%% 2. Test map_eval properties
fprintf('[test_step2] Testing map_eval properties...\n');
iv60 = find(Cal.v_kmh == 60);
M60 = map_table(Cal, iv60, 6.75, Ts0);

% Deadzone check
assert(abs(map_eval(M60, 0)) < 1e-12, 'map_eval(0) must be 0');
assert(abs(map_eval(M60, 0.15)) < 1e-12, 'map_eval in deadzone must be 0');
assert(abs(map_eval(M60, Ts0)) < 1e-12, 'map_eval at Ts0 boundary must be 0');
assert(abs(map_eval(M60, -0.2)) < 1e-12, 'map_eval in negative deadzone must be 0');

% Anti-symmetry: map_eval(-x) == -map_eval(x)
testVals = [0.0, 0.25, 0.5, 1.2, 2.5, 3.8, 6.0];
for tv = testVals
    y_pos = map_eval(M60, tv);
    y_neg = map_eval(M60, -tv);
    assert(abs(y_pos + y_neg) < 1e-12, sprintf('map_eval must be anti-symmetric at %g', tv));
end

% Breakpoint evaluation matches M.Ta
for k = 1:numel(M60.Ts)
    y_k = map_eval(M60, M60.Ts(k));
    assert(abs(y_k - M60.Ta(k)) < 1e-12, sprintf('map_eval at breakpoint %d must match M.Ta', k));
end

% Saturation beyond last breakpoint
y_end = M60.Ta(end);
assert(abs(map_eval(M60, M60.Ts(end) + 1.0) - y_end) < 1e-12, 'map_eval beyond Ts(end) must saturate');
assert(abs(map_eval(M60, M60.Ts(end) + 10.0) - y_end) < 1e-12, 'map_eval far beyond Ts(end) must saturate');

%% 3. Test map_dry_error equilibrium residual
fprintf('[test_step2] Testing map_dry_error equilibrium residual...\n');
for iv = [1, 9, 17] % 20, 60, 100 km/h
    E = map_dry_error(Cal, iv, 6.75, Ts0);
    Tr = Cal.Tr{iv};
    M = map_table(Cal, iv, 6.75, Ts0);
    for k = 1:numel(E.Ts_eq)
        res = abs(E.Ts_eq(k) - Tr(k) + map_eval(M, E.Ts_eq(k)));
        assert(res < 1e-11, sprintf('Equilibrium residual must be < 1e-11, got %e at k=%d, iv=%d', res, k, iv));
        % Since M(Ts) <= Ta_cal = Tr - Ts_cal, Ts_eq >= Ts_cal => eT >= -1e-11
        assert(E.eT(k) >= -1e-11, sprintf('Steady error eT must be non-negative, got %e', E.eT(k)));
    end
end

%% 4. Test map_k_accuracy and minimal property of K_acc
fprintf('[test_step2] Testing map_k_accuracy and minimality of K_acc...\n');
A = map_k_accuracy(3, Ts0);
csvPath = fullfile(result_dir('Map', 'Design'), 'Map_K_for_accuracy.csv');
assert(exist(csvPath, 'file') == 2, 'Map_K_for_accuracy.csv must exist');

for iv = 1:n
    Kmin = A.Kmin(iv);
    assert(~isnan(Kmin), sprintf('Kmin must not be NaN at %d km/h', A.v_kmh(iv)));
    assert(A.err_at_Kmin(iv) <= 3.0 + 1e-9, sprintf('Error at Kmin must be <= 3 %%, got %g at %d km/h', A.err_at_Kmin(iv), A.v_kmh(iv)));
    
    % If Kmin > 0.25, verify that Kmin - 0.25 violates the 3 % tolerance (proving minimality)
    if Kmin > 0.25
        E_sub = map_dry_error(Cal, iv, Kmin - 0.25, Ts0);
        m = E_sub.ay_g >= 0.1 - 1e-9 & E_sub.ay_g <= 0.3 + 1e-9;
        err_sub = max(abs(E_sub.pct(m)));
        assert(err_sub > 3.0, sprintf('Kmin - 0.25 must exceed 3 %%, but got %g at %d km/h', err_sub, A.v_kmh(iv)));
    end
end

fprintf('\n========================================\n');
fprintf('[test_step2] TEST PASS\n');
fprintf('========================================\n');
end

