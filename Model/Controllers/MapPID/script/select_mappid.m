function sel = select_mappid(writeJson)
%SELECT_MAPPID O6 of DieuKhien_MapPID.txt: verify the optimisation and choose the MapPID design.
%
%   sel = select_mappid(true)   also writes the design to data/mappid.json
%   Pools every evaluation at seed 30000 (MapPID_CALIB_opt*_s30000.csv of O4, MapPID_CALIB_ref*_s30000.csv of O5), then, in the order written in advance:
%   (1) optimal region: feasible designs (simulated, linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707, e_rel <= 5 %) with J <= 1.05 J*;
%   (2) convergence: best J of every run (opt i + ref i); how many runs are within 3 % of J*;
%   (3) neighbourhood: around the best design, +-0.01 of the box in each of the nine normalized variables (18 runs); does any FEASIBLE neighbour have a
%       smaller J (directions that leave the feasible set are ignored and the active constraints are named);
%   (4) seed: the 10 best distinct feasible designs are run again with seed 30001; ranking by the mean J of the two seeds;
%   (5) in that order: final linear requirement PM >= 30 deg and GM >= 2 over 68 plants x 5 slopes (D14: changed by the user on 2026-10-13 from
%       option C PM >= 15, GM >= 1.5 after the first selection; 30 deg = lower end of Seborg 14.7), then the simulation margin gate
%       calib_margin (QuyChuan 5.2); the first design that passes both is chosen;
%   (6) reports: bang-bang (calib_bangbang), reverse assist, e_rel sensitivity 3 % and 10 % (from the pooled table), the active constraints.
%   Outputs in Result/Controllers/MapPID/Calib/: MapPID_CALIB_region_s30000.csv, MapPID_CALIB_nbr_s30000.csv, MapPID_CALIB_seed2_s30001.csv,
%   MapPID_CALIB_pick_s30000.csv.
if nargin < 1, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Calib');
vn = {'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
PMfin = 30; GMfin = 2;                                               % final linear requirement (D14)

%% pool
files = [dir(fullfile(outDir, 'MapPID_CALIB_opt*_s30000.csv')); dir(fullfile(outDir, 'MapPID_CALIB_ref*_s30000.csv'))];
P = table();
for i = 1:numel(files)
    T = readtable(fullfile(outDir, files(i).name));
    tok = regexp(files(i).name, 'MapPID_CALIB_(opt|ref)(\d+)_', 'tokens', 'once');
    T.stage = repmat(string(tok{1}), height(T), 1); T.run = repmat(str2double(tok{2}), height(T), 1);
    P = [P; T]; %#ok<AGROW>
end
nEval = height(P); nSim = nnz(P.simulated == 1);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0;
F = P(feas, :);
F.Jv = F.R_pct .* F.S_Nm;
[~, iu] = unique(round(table2array(F(:, vn)), 6, 'significant'), 'rows', 'stable');   % the same design can sit in two files (start of O5)
F = F(iu, :);
[F, ~] = sortrows(F, 'Jv');
Jstar = F.Jv(1);
fprintf('select_mappid: %d evaluations (%d simulated), %d feasible; J* = %.4f (R %.3f %%, S %.4f)\n', nEval, nSim, height(F), Jstar, F.R_pct(1), F.S_Nm(1));

%% (1) optimal region
Rg = F(F.Jv <= 1.05 * Jstar, :);
writetable(Rg, fullfile(outDir, 'MapPID_CALIB_region_s30000.csv'));
fprintf('(1) optimal region (J <= 1.05 J*): %d designs; ranges:\n', height(Rg));
for k = 1:9, fprintf('    %-11s %.4g .. %.4g\n', vn{k}, min(Rg.(vn{k})), max(Rg.(vn{k}))); end

%% (2) convergence of the independent runs
runs = unique(F.run)';
bestRun = arrayfun(@(r) min(F.Jv(F.run == r)), runs);
nConv = nnz(bestRun <= 1.03 * Jstar);
fprintf('(2) best J per run: %s; %d of %d runs within 3 %% of J*\n', mat2str(bestRun, 4), nConv, numel(runs));

%% (3) neighbourhood of the best design that meets the final linear requirement (PM_deg and GM of the pooled table)
Fok = F(F.PM_deg >= PMfin & F.GM >= GMfin, :);
JstarOk = Fok.Jv(1);
fprintf('    best design with linear PM >= %g, GM >= %g: J %.4f (%.2f %% above J*), PM %.1f\n', PMfin, GMfin, JstarOk, 100 * (JstarOk / Jstar - 1), Fok.PM_deg(1));
xb = table2array(Fok(1, vn));
ub = mappid_x2u(xb);
nbrFile = fullfile(outDir, 'MapPID_CALIB_nbr_s30000.csv');
better = 0; nbr = zeros(0, 4);
for k = 1:9
    for sgn = [-1 1]
        u = ub; u(k) = min(max(u(k) + sgn * 0.01, 0), 1);
        if abs(u(k) - ub(k)) < 1e-12, continue; end
        o = mappid_eval(mappid_u2x(u), 30000, nbrFile);
        f = o.simulated && all(o.c <= 0);
        Jn = o.R * o.S;
        nbr(end + 1, :) = [k sgn f Jn]; %#ok<AGROW>
        if f && Jn < JstarOk, better = better + 1; end
        if ~f, fprintf('    neighbour %s %+d: infeasible, constraints [%s]\n', vn{k}, sgn, num2str(o.c, 3)); end
    end
end
fprintf('(3) neighbourhood: %d feasible neighbours of %d have a smaller J than the best design with PM >= %g\n', better, size(nbr, 1), PMfin);

%% (4) second seed for the 10 best distinct designs
top = Fok(1:min(10, height(Fok)), :);
seedFile = fullfile(outDir, 'MapPID_CALIB_seed2_s30001.csv');
top.J2 = nan(height(top), 1); top.R2 = top.J2; top.S2 = top.J2; top.erel2 = top.J2;
for i = 1:height(top)
    o = mappid_eval(table2array(top(i, vn)), 30001, seedFile);
    top.J2(i) = o.R * o.S; top.R2(i) = o.R; top.S2(i) = o.S; top.erel2(i) = o.erel;
end
top.Jmean = (top.Jv + top.J2) / 2;
top.Jchange_pct = 100 * (top.J2 - top.Jv) ./ top.Jv;
top = sortrows(top, 'Jmean');
fprintf('(4) seed 30001: J change %s %%\n', mat2str(round(top.Jchange_pct', 1)));

%% (5) final linear requirement and the simulation margin gate
[Gj, w] = mappid_plants();
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
pick = 0; M = [];
top.PM_ok = false(height(top), 1); top.margin_pass = nan(height(top), 1); top.ratio_gain = top.margin_pass; top.ratio_delay = top.margin_pass;
for i = 1:height(top)
    d = xToDesign(table2array(top(i, vn)), Ts0);
    Rl = mappid_margins(Gj, w, d);
    top.PM_ok(i) = Rl.stable && Rl.PM >= PMfin && Rl.GM >= GMfin;
    if ~top.PM_ok(i), fprintf('    candidate %d: linear PM %.1f GM %.2f fails the final requirement\n', i, Rl.PM, Rl.GM); continue; end
    M = calib_margin('Model_MapPID', 30000, mappid_variables(Cal, d));
Simulink.sdi.clear;
    top.margin_pass(i) = M.pass; top.ratio_gain(i) = M.ratio_gain; top.ratio_delay(i) = M.ratio_delay;
    if M.pass, pick = i; break; end
end
assert(pick > 0, 'select_mappid: no candidate passes the final requirements');
c = top(pick, :);
x = table2array(c(1, vn));
d = xToDesign(x, Ts0);
Rl = mappid_margins(Gj, w, d);
fprintf('(5) chosen: candidate %d of the seed ranking: J %.4f (seed 30000) / %.4f (seed 30001), linear PM %.1f GM %.2f, margin ratios %.2f / %.2f\n', ...
    pick, c.Jv, c.J2, Rl.PM, Rl.GM, c.ratio_gain, c.ratio_delay);

%% (6) reports
B = calib_bangbang('Model_MapPID', 30000, mappid_variables(Cal, d));
Simulink.sdi.clear;
e3 = F(F.erel_pct <= 3, :); e10 = F;                                 % every feasible design already has e_rel <= 5 %
T10 = P(P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.erel_pct <= 10, :);
J3 = min(e3.Jv); J10 = min(T10.R_pct .* T10.S_Nm);
lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1));
fprintf('(6) bang-bang: f_ideal %.4f f_noisy %.4f delta %.4f spread %.4f | rev %.2f %% | e_rel %.2f %% | J* if e_rel <= 3 %%: %.4f, if <= 10 %%: %.4f | lag gain 2 Hz %.3f\n', ...
    B.f_ideal, B.f_noisy, B.delta, B.disp, 100 * c.rev_pct, c.erel_pct, J3, J10, lagGain);
active = {};
if lagGain < 0.72, active{end + 1} = 'steering band (lag gain at 2 Hz near 0.707)'; end
if c.erel_pct > 4.5, active{end + 1} = 'e_rel near 5 %'; end
if Rl.PM < PMfin + 2, active{end + 1} = sprintf('final linear PM near %g deg', PMfin); end
if Rl.GM < GMfin + 0.1, active{end + 1} = sprintf('final linear GM near %g', GMfin); end
uc = mappid_x2u(x); atB = find(uc < 0.005 | uc > 0.995);
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('    active constraints / bounds: %s\n', strjoin(active, '; '));

sel = struct('x', x, 'design', d, 'J', c.Jv, 'R', c.R_pct, 'S', c.S_Nm, 'TV', c.TV, 'erel', c.erel_pct, 'rev', c.rev_pct, ...
    'J_seed2', c.J2, 'R_seed2', c.R2, 'S_seed2', c.S2, 'erel_seed2', c.erel2, 'PM', Rl.PM, 'GM', Rl.GM, 'HF', Rl.HF, 'lagGain2Hz', lagGain, ...
    'ratio_gain', c.ratio_gain, 'ratio_delay', c.ratio_delay, 'bangbang', B, 'Jstar', Jstar, 'nEval', nEval, 'nSim', nSim, ...
    'nRegion', height(Rg), 'nRunsConverged', nConv, 'bestPerRun', bestRun, 'nBetterNeighbours', better, 'J_erel3', J3, 'J_erel10', J10, 'active', {active});
writetable(top, fullfile(outDir, 'MapPID_CALIB_pick_s30000.csv'));
if writeJson
    jf = fullfile(modelDir, 'data', 'mappid.json');
    J = jsondecode(fileread(jf));
    Jmd = Jm.design;
    J.design = struct('Kmax', d.Kmax, 'Ts0', Ts0, 'lead', d.lead, 'lag', d.lag, 'Kp', d.Kp, 'Ki', d.Ki, 'Kd', d.Kd, 'Tf', d.Tf, ...
        'Kaw', ifelse(d.Ki > 0 && d.Kp + d.Kmax > 0, d.Ki / (d.Kp + d.Kmax), 0), 'rule', 'min J = R*S by simultaneous optimisation (surrogateopt x3 + patternsearch x3), QuyChuan 6.1 exception', ...
        'CALIB_R_pct', c.R_pct, 'CALIB_S_Nm', c.S_Nm, 'CALIB_TV_Nm_per_s', c.TV, 'CALIB_erel_pct', c.erel_pct, 'CALIB_rev_pct', 100 * c.rev_pct, 'CALIB_J', c.Jv, ...
        'seed_30001_R_pct', c.R2, 'seed_30001_S_Nm', c.S2, 'seed_30001_erel_pct', c.erel2, 'PM_deg', Rl.PM, 'GM', Rl.GM, 'HF_gain', Rl.HF, 'lag_gain_2Hz', lagGain, ...
        'margin_ratio_gain', c.ratio_gain, 'margin_ratio_delay', c.ratio_delay, 'bangbang', struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp), ...
        'n_evaluations', nEval, 'n_simulations', nSim, 'design_seed', 30000, 'map_source_date', Jmd.date, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mappid: design written to %s\n', jf);
end
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lead', struct('z', x(2), 'p', x(2) * x(3)), 'lag', struct('z1', x(4), 'p1', x(4) * x(5)), ...
    'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
