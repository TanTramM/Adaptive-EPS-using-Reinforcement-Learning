function T = sweep_leadlag(levels, Ks, ext)
%SWEEP_LEADLAG Design of the lead-lag compensator over a grid of slope limits K and lag levels g_min (Documents/Notes/Controllers/DieuKhien_Map.txt A4, A5, B6).
%
%   T = sweep_leadlag()                       levels g_min = [1.0 0.9 0.8 0.7 0.6], K = 5, 5.5, ... until no candidate passes
%   T = sweep_leadlag(levels, Ks)
%   g_min = smallest allowed gain of the lag stage at 2 Hz (12.57 rad/s); 1.0 means NO lag (lead only, the comparison variant).
%   For each (g_min, K): design_leadlag over the 68 linearized Plants (17 speeds 20-100 km/h x 4 operating points of map_op_points),
%   slopes K*[0.25 0.5 0.75 1]; then an independent check of the chosen compensator with map_margins on a finer frequency grid.
%   Rows are appended to Result/Controllers/Map/Design/Map_design_leadlag.csv one at a time (a rerun skips the rows already there).
%   For one level the K loop stops at the first K with no feasible compensator (feasibility falls with K).
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('Map', 'Design');
csvPath = fullfile(outDir, 'Map_design_leadlag.csv');
if nargin < 1 || isempty(levels), levels = [1.0 0.9 0.8 0.7 0.6]; end
if nargin < 2 || isempty(Ks), Ks = 5:0.5:20; end
if nargin < 3, ext = struct(); end          % optional wider lag bounds, passed to design_leadlag (fields qLim, p1Min)

P   = map_params();
Cal = calibrate_map_cached();
ops = map_op_points();
w   = logspace(-1, 5, 3000)';
wv  = logspace(-1, 5, 9000)';                          % finer grid for the independent check
sensors = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
res = sensors.signals.T_s.resolution;
sigTs = sqrt(res^2 + res^2 / 12);

n = numel(Cal.v_kmh) * size(ops, 1);
Gj = cell(n, 1); Gv = cell(n, 1); idx = 1;
fprintf('sweep_leadlag: frequency responses of %d plants...\n', n);
for iv = 1:numel(Cal.v_kmh)
    for i = 1:size(ops, 1)
        G = map_plant_lin(P, Cal.v_kmh(iv) / 3.6, ops(i, 1) * P.g, ops(i, 2));
        Gj{idx} = squeeze(freqresp(G, w)); Gv{idx} = squeeze(freqresp(G, wv)); idx = idx + 1;
    end
end

vars = {'g_min', 'K', 'ok', 'z', 'p', 'z1', 'p1', 'PM_deg', 'GM', 'wc_rad_s', 'HF_gain', 'Ta_noise_std_Nm', 'n_coarse', 'n_fine', 'n_tried', 'HF_coarse', 'HF_fine', ...
        'at_bound_z', 'at_bound_r', 'at_bound_p', 'at_bound_z1', 'at_bound_q1', 'at_bound_p1', 'PM_check_deg', 'GM_check', 'seconds'};
if exist(csvPath, 'file'), T = readtable(csvPath); else, T = array2table(zeros(0, numel(vars)), 'VariableNames', vars); end
for lev = levels
    for K = Ks
        if any(abs(T.g_min - lev) < 1e-9 & abs(T.K - K) < 1e-9)
            r = T(abs(T.g_min - lev) < 1e-9 & abs(T.K - K) < 1e-9, :);
            if r.ok(1) == 0, break; end
            continue;
        end
        t0 = tic;
        D = design_leadlag(Gj, w, K, lev < 1, [lev 12.57], ext);
        noise = NaN; pmc = NaN; gmc = NaN;
        if D.ok
            noise = map_noise_gain(K, D.z, D.p, [], D.z1, D.p1) * sigTs;
            pmc = Inf; gmc = Inf;
            for ig = 1:n
                for k = K * [0.25 0.5 0.75 1]
                    R = map_margins(Gv{ig}, wv, k, D.z, D.p, [], D.z1, D.p1);
                    if R.stable ~= 1, pmc = -Inf; end
                    pmc = min(pmc, R.PM); gmc = min(gmc, R.GM);
                end
            end
        end
        B = D.atBound;
        row = {lev, K, D.ok, D.z, D.p, D.z1, D.p1, D.PM, D.GM, D.wc, D.HF, noise, D.nCoarse, D.nFine, D.nTried, D.HFcoarse, D.HFfine, ...
               B.z, B.r, B.p, B.z1, B.q1, B.p1, pmc, gmc, toc(t0)};
        T = [T; cell2table(row, 'VariableNames', vars)]; %#ok<AGROW>
        writetable(T, csvPath);
        fprintf('g_min %.1f K %5.2f ok %d | z %6.1f p %7.1f z1 %6.1f p1 %6.2f | PM %.1f (check %.1f) GM %.2f wc %.0f HF %.1f noise %.3f | bounds %d%d%d%d%d%d | %.0f s\n', ...
            lev, K, D.ok, D.z, D.p, D.z1, D.p1, D.PM, pmc, D.GM, D.wc, D.HF, noise, B.z, B.r, B.p, B.z1, B.q1, B.p1, toc(t0));
        if ~D.ok, break; end
    end
end
fprintf('sweep_leadlag: written %s\n', csvPath);
end
