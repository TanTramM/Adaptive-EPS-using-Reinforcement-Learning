function sel = select_mapopt(writeJson)
%SELECT_MAPOPT Verify the optimisation and choose the MapOpt design: the rule of select_mappid.m (DieuKhien_MapPID.txt O6) with the Map seeds 0 / 1.
%
%   sel = select_mapopt(true)   also writes the design to data/mapopt.json
%   Pools every evaluation at seed 0 (MapOpt_CALIB_opt*_s00000.csv, MapOpt_CALIB_ref*_s00000.csv), then: (1) optimal region J <= 1.05 J*; (2) convergence of the runs;
%   (3) neighbourhood +-0.01 of the box of the best design with linear PM >= 30 deg and GM >= 2; (4) seed 1 for the 10 best such designs, ranking by the mean J of the
%   two seeds; (5) the first that passes calib_margin (R not more than 2x at gain x2 and +1 ms) is chosen; (6) reports: bang-bang, reverse assist, e_rel sensitivity
%   3 % and 10 %, the active constraints and box bounds. Outputs in Result/Controllers/MapOpt/Calib/: _region_s00000.csv, _nbr_s00000.csv, _seed2_s00001.csv, _pick_s00000.csv.
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapOpt', 'Calib');
vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1'}; n = 5;
PMfin = 30; GMfin = 2; Ts = 1e-3;
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;

files = [dir(fullfile(outDir, 'MapOpt_CALIB_opt*_s00000.csv')); dir(fullfile(outDir, 'MapOpt_CALIB_ref*_s00000.csv'))];
P = table();
for i = 1:numel(files)
    T = readtable(fullfile(outDir, files(i).name));
    tok = regexp(files(i).name, 'MapOpt_CALIB_(opt|ref)(\d+)_', 'tokens', 'once');
    T.stage = repmat(string(tok{1}), height(T), 1); T.run = repmat(str2double(tok{2}), height(T), 1);
    P = [P; T]; %#ok<AGROW>
end
nEval = height(P); nSim = nnz(P.simulated == 1);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0;
F = P(feas, :);
F.Jv = F.R_pct .* F.S_Nm;
[~, iu] = unique(round(table2array(F(:, vn)), 6, 'significant'), 'rows', 'stable');
F = sortrows(F(iu, :), 'Jv');
Jstar = F.Jv(1);
fprintf('select_mapopt: %d evaluations (%d simulated), %d feasible; J* = %.4f (R %.3f %%, S %.4f)\n', nEval, nSim, height(F), Jstar, F.R_pct(1), F.S_Nm(1));

Rg = F(F.Jv <= 1.05 * Jstar, :);
writetable(Rg, fullfile(outDir, 'MapOpt_CALIB_region_s00000.csv'));
fprintf('(1) optimal region (J <= 1.05 J*): %d designs; ranges:\n', height(Rg));
for k = 1:n, fprintf('    %-11s %.4g .. %.4g\n', vn{k}, min(Rg.(vn{k})), max(Rg.(vn{k}))); end

runs = unique(F.run)';
bestRun = arrayfun(@(r) min(F.Jv(F.run == r)), runs);
nConv = nnz(bestRun <= 1.03 * Jstar);
fprintf('(2) best J per run: %s; %d of %d runs within 3 %% of J*\n', mat2str(bestRun, 4), nConv, numel(runs));

Fok = F(F.PM_deg >= PMfin & F.GM >= GMfin, :);
assert(height(Fok) > 0, 'select_mapopt: no feasible design with PM >= %g and GM >= %g', PMfin, GMfin);
JstarOk = Fok.Jv(1);
fprintf('    best design with linear PM >= %g, GM >= %g: J %.4f (%.2f %% above J*), PM %.1f\n', PMfin, GMfin, JstarOk, 100 * (JstarOk / Jstar - 1), Fok.PM_deg(1));
ub = mapopt_x2u(table2array(Fok(1, vn)));
nbrFile = fullfile(outDir, 'MapOpt_CALIB_nbr_s00000.csv');
better = 0; nnb = 0;
for k = 1:n
    for sgn = [-1 1]
        u = ub; u(k) = min(max(u(k) + sgn * 0.01, 0), 1);
        if abs(u(k) - ub(k)) < 1e-12, continue; end
        o = mapopt_eval(mapopt_u2x(u), 0, nbrFile);
        f = o.simulated && all(o.c <= 0);
        nnb = nnb + 1;
        if f && o.R * o.S < JstarOk, better = better + 1; end
        if ~f, fprintf('    neighbour %s %+d: infeasible, constraints [%s]\n', vn{k}, sgn, num2str(o.c, 3)); end
    end
end
fprintf('(3) neighbourhood: %d feasible neighbours of %d have a smaller J than the best design with PM >= %g\n', better, nnb, PMfin);

top = Fok(1:min(10, height(Fok)), :);
seedFile = fullfile(outDir, 'MapOpt_CALIB_seed2_s00001.csv');
top.J2 = nan(height(top), 1); top.R2 = top.J2; top.S2 = top.J2; top.erel2 = top.J2;
for i = 1:height(top)
    o = mapopt_eval(table2array(top(i, vn)), 1, seedFile);
    top.J2(i) = o.R * o.S; top.R2(i) = o.R; top.S2(i) = o.S; top.erel2(i) = o.erel;
end
top.Jmean = (top.Jv + top.J2) / 2;
top.Jchange_pct = 100 * (top.J2 - top.Jv) ./ top.Jv;
top = sortrows(top, 'Jmean');
fprintf('(4) seed 1: J change %s %%\n', mat2str(round(top.Jchange_pct', 1)));

[Gj, w] = mappid_plants();
Cal = calibrate_map_cached();
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapOpt', 'load_mapopt.m'), '\', '/')));
pick = 0;
top.margin_pass = nan(height(top), 1); top.ratio_gain = top.margin_pass; top.ratio_delay = top.margin_pass;
for i = 1:height(top)
    d = xToDesign(table2array(top(i, vn)), Ts, Ts0);
    M = calib_margin('Model_MapOpt', 0, mapopt_variables(Cal, d));
    Simulink.sdi.clear;
    top.margin_pass(i) = M.pass; top.ratio_gain(i) = M.ratio_gain; top.ratio_delay(i) = M.ratio_delay;
    if M.pass, pick = i; break; end
end
assert(pick > 0, 'select_mapopt: no candidate passes calib_margin');
c = top(pick, :);
x = table2array(c(1, vn));
d = xToDesign(x, Ts, Ts0);
Rl = mappid_margins(Gj, w, struct('Kmax', d.Kmax, 'lead', d.lead, 'lag', d.lag, 'Kp', 0, 'Ki', 0, 'Kd', 0, 'Tf', 0.005));
fprintf('(5) chosen: candidate %d of the seed ranking: J %.4f (seed 0) / %.4f (seed 1), linear PM %.1f GM %.2f, margin ratios %.2f / %.2f\n', pick, c.Jv, c.J2, Rl.PM, Rl.GM, c.ratio_gain, c.ratio_delay);

B = calib_bangbang('Model_MapOpt', 0, mapopt_variables(Cal, d));
Simulink.sdi.clear;
T10 = P(P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.erel_pct <= 10, :);
J3 = min(F.Jv(F.erel_pct <= 3)); J10 = min(T10.R_pct .* T10.S_Nm);
lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1));
fprintf('(6) bang-bang: f_ideal %.4f f_noisy %.4f delta %.4f spread %.4f | rev %.2f %% | e_rel %.2f %% | J* if e_rel <= 3 %%: %.4g, if <= 10 %%: %.4g | lag gain 2 Hz %.3f\n', ...
    B.f_ideal, B.f_noisy, B.delta, B.disp, c.rev_pct, c.erel_pct, J3, J10, lagGain);
active = {};
if lagGain < 0.72, active{end + 1} = 'steering band (lag gain at 2 Hz near 0.707)'; end
if c.erel_pct > 4.5, active{end + 1} = 'e_rel near 5 %'; end
if Rl.PM < PMfin + 2, active{end + 1} = sprintf('final linear PM near %g deg', PMfin); end
if Rl.GM < GMfin + 0.1, active{end + 1} = sprintf('final linear GM near %g', GMfin); end
uc = mapopt_x2u(x); atB = find(uc < 0.005 | uc > 0.995);
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('    active constraints / bounds: %s\n', strjoin(active, '; '));

sel = struct('x', x, 'design', d, 'J', c.Jv, 'R', c.R_pct, 'S', c.S_Nm, 'TV', c.TV, 'erel', c.erel_pct, 'rev', c.rev_pct, 'J_seed2', c.J2, 'PM', Rl.PM, 'GM', Rl.GM, ...
    'lagGain2Hz', lagGain, 'bangbang', B, 'Jstar', Jstar, 'nEval', nEval, 'nSim', nSim, 'active', {active});
writetable(top, fullfile(outDir, 'MapOpt_CALIB_pick_s00000.csv'));
if writeJson
    jf = fullfile(modelDir, 'data', 'mapopt.json');
    J = jsondecode(fileread(jf));
    q = struct('Kmax', d.Kmax, 'Ts0', Ts0, 'lead', d.lead, 'lag', d.lag);
    q.rule = 'min J = R*S by simultaneous optimisation (surrogateopt x3 + patternsearch x3), the MapPID method; PM >= 30, GM >= 2, calib_margin';
    q.CALIB_R_pct = c.R_pct; q.CALIB_S_Nm = c.S_Nm; q.CALIB_TV_Nm_per_s = c.TV; q.CALIB_erel_pct = c.erel_pct; q.CALIB_rev_pct = c.rev_pct; q.CALIB_J = c.Jv;
    q.seed_00001_R_pct = c.R2; q.seed_00001_S_Nm = c.S2; q.seed_00001_erel_pct = c.erel2; q.PM_deg = Rl.PM; q.GM = Rl.GM; q.HF_gain = Rl.HF; q.lag_gain_2Hz = lagGain;
    q.margin_ratio_gain = c.ratio_gain; q.margin_ratio_delay = c.ratio_delay;
    q.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp);
    q.n_evaluations = nEval; q.n_simulations = nSim; q.design_seed = 0; q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mapopt: design written to %s\n', jf);
end
end

function d = xToDesign(x, Ts, Ts0)
d = struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)));
end
