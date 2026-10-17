function ip = mapopt_run1_points(outDir, runId, cfg)
%MAPOPT_RUN1_POINTS Every evaluation of the same chain of run 1 as a start point of run 2 (u, log objective, the four constraints under the thresholds of run 2)
f = fullfile(fileparts(outDir), 'Calib_run1', sprintf('MapOpt_CALIB_opt%d_s00000.csv', runId));
assert(isfile(f), 'optimize_mapopt: %s not found (move the run-1 Calib folder to Calib_run1 first)', f);
T = readtable(f); T = T(T.seed == 0, :);
X = [T.K T.z T.p_over_z T.z1 T.p1_over_z1];
[~, iu] = unique(round(X, 9, 'significant'), 'rows', 'stable'); T = T(iu, :); X = X(iu, :);
U = zeros(size(X));
for i = 1:size(X, 1), U(i, :) = mapopt_x2u(X(i, :)); end
sim = T.simulated == 1;
Fv = log(30) * ones(height(T), 1);
Fv(sim) = log(max(T.R_pct(sim) .* T.S_Nm(sim), 1e-6));
PMe = T.PM_deg; PMe(~isfinite(PMe)) = -180;
c4 = zeros(height(T), 1); c4(sim) = T.erel_pct(sim) - 5;
In = [cfg.PMmin - PMe, cfg.GMmin - T.GM, T.c3, c4]; In(isnan(In)) = 200; In = max(min(In, 200), -200);
Fv(~isfinite(Fv)) = log(30);
ip = struct('X', U, 'Fval', Fv, 'Ineq', In);
end
