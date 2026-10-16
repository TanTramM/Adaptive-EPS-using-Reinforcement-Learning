function sel = select_mappidlag(writeJson, variant)
%SELECT_MAPPIDLAG P6 of DieuKhien_MapPIDLag.txt: verify the optimisation and choose the MapPIDLag design (same rules as select_mappid.m of MapPID).
%
%   sel = select_mappidlag(true, variant)   also writes the design to data/mappidlag.json (field design for 'MapPIDLag', field pidlag.design for 'PIDLag')
%   variant 'MapPIDLag' (default, seven variables) or 'PIDLag' (the PID + lag reference, K = 0, six variables).
%   Pools every evaluation at seed 50000 (<variant>_CALIB_opt*_s50000.csv of P4, <variant>_CALIB_ref*_s50000.csv of P5), then, in the order written in advance:
%   (1) optimal region: feasible designs (simulated, linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707, e_rel <= 5 %) with J <= 1.05 J*;
%   (2) convergence: best J of every run (opt i + ref i); how many runs are within 3 % of J*;
%   (3) neighbourhood: around the best design that meets the final linear requirement, +-0.01 of the box in each normalized variable; does any FEASIBLE
%       neighbour have a smaller J (directions that leave the feasible set are ignored and the active constraints are named);
%   (4) seed: the 10 best distinct designs with linear PM >= 30 deg and GM >= 2 are run again with seed 50001; ranking by the mean J of the two seeds;
%   (5) in that order: the final linear requirement PM >= 30 deg, GM >= 2 over 68 plants x 5 slopes (same as MapPID D14), then the simulation margin gate
%       calib_margin (QuyChuan 5.2); the first design that passes both is chosen;
%   (6) reports: bang-bang (calib_bangbang), reverse assist, e_rel sensitivity 3 % and 10 % (from the pooled table), the active constraints.
%   Outputs in Result/Controllers/MapPIDLag/Calib/: <variant>_CALIB_region_s50000.csv, _nbr_s50000.csv, _seed2_s50001.csv, _pick_s50000.csv.
if nargin < 1, writeJson = false; end
if nargin < 2 || isempty(variant), variant = 'MapPIDLag'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPIDLag', 'Calib');
vn = {'K', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf'};
free = 1:7; if strcmp(variant, 'PIDLag'), free = 2:7; end              % variables the optimiser moved
PMfin = 30; GMfin = 2;                                               % final linear requirement
seed1 = 50000; seed2 = 50001;

%% pool
files = [dir(fullfile(outDir, [variant '_CALIB_opt*_s50000.csv'])); dir(fullfile(outDir, [variant '_CALIB_ref*_s50000.csv']))];
P = table();
for i = 1:numel(files)
    T = readtable(fullfile(outDir, files(i).name));
    tok = regexp(files(i).name, [variant '_CALIB_(opt|ref)(\d+)_'], 'tokens', 'once');
    T.stage = repmat(string(tok{1}), height(T), 1); T.run = repmat(str2double(tok{2}), height(T), 1);
    P = [P; T]; %#ok<AGROW>
end
nEval = height(P); nSim = nnz(P.simulated == 1);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0;
F = P(feas, :);
F.Jv = F.R_pct .* F.S_Nm;
[~, iu] = unique(round(table2array(F(:, vn)), 6, 'significant'), 'rows', 'stable');   % the same design can sit in two files (start of P5)
F = F(iu, :);
[F, ~] = sortrows(F, 'Jv');
Jstar = F.Jv(1);
fprintf('select_mappidlag(%s): %d evaluations (%d simulated), %d feasible; J* = %.4f (R %.3f %%, S %.4f)\n', variant, nEval, nSim, height(F), Jstar, F.R_pct(1), F.S_Nm(1));

%% (1) optimal region
Rg = F(F.Jv <= 1.05 * Jstar, :);
writetable(Rg, fullfile(outDir, [variant '_CALIB_region_s50000.csv']));
fprintf('(1) optimal region (J <= 1.05 J*): %d designs; ranges:\n', height(Rg));
for k = free, fprintf('    %-11s %.4g .. %.4g\n', vn{k}, min(Rg.(vn{k})), max(Rg.(vn{k}))); end

%% (2) convergence of the independent runs
runs = unique(F.run)';
bestRun = arrayfun(@(r) min(F.Jv(F.run == r)), runs);
nConv = nnz(bestRun <= 1.03 * Jstar);
fprintf('(2) best J per run: %s; %d of %d runs within 3 %% of J*\n', mat2str(bestRun, 4), nConv, numel(runs));

%% (3) neighbourhood of the best design that meets the final linear requirement
Fok = F(F.PM_deg >= PMfin & F.GM >= GMfin, :);
assert(height(Fok) > 0, 'select_mappidlag: no feasible design has linear PM >= %g and GM >= %g', PMfin, GMfin);
JstarOk = Fok.Jv(1);
fprintf('    best design with linear PM >= %g, GM >= %g: J %.4f (%.2f %% above J*), PM %.1f\n', PMfin, GMfin, JstarOk, 100 * (JstarOk / Jstar - 1), Fok.PM_deg(1));
xb = table2array(Fok(1, vn));
ub = mappidlag_x2u(xb);
nbrFile = fullfile(outDir, [variant '_CALIB_nbr_s50000.csv']);
better = 0; nbr = zeros(0, 4);
for k = free
    for sgn = [-1 1]
        u = ub; u(k) = min(max(u(k) + sgn * 0.01, 0), 1);
        if abs(u(k) - ub(k)) < 1e-12, continue; end
        o = mappidlag_eval(mappidlag_u2x(u), seed1, nbrFile);
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
seedFile = fullfile(outDir, [variant '_CALIB_seed2_s50001.csv']);
top.J2 = nan(height(top), 1); top.R2 = top.J2; top.S2 = top.J2; top.erel2 = top.J2;
for i = 1:height(top)
    o = mappidlag_eval(table2array(top(i, vn)), seed2, seedFile);
    top.J2(i) = o.R * o.S; top.R2(i) = o.R; top.S2(i) = o.S; top.erel2(i) = o.erel;
end
top.Jmean = (top.Jv + top.J2) / 2;
top.Jchange_pct = 100 * (top.J2 - top.Jv) ./ top.Jv;
top = sortrows(top, 'Jmean');
fprintf('(4) seed %d: J change %s %%\n', seed2, mat2str(round(top.Jchange_pct', 1)));

%% (5) final linear requirement and the simulation margin gate
[Gj, w] = mappidlag_plants();
Cal = calibrate_map_cached();
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'load_mappidlag.m'), '\', '/')));
pick = 0; M = [];
top.PM_ok = false(height(top), 1); top.margin_pass = nan(height(top), 1); top.ratio_gain = top.margin_pass; top.ratio_delay = top.margin_pass;
for i = 1:height(top)
    d = xToDesign(table2array(top(i, vn)), Ts0);
    Rl = mappidlag_margins(Gj, w, d);
    top.PM_ok(i) = Rl.stable && Rl.PM >= PMfin && Rl.GM >= GMfin;
    if ~top.PM_ok(i), fprintf('    candidate %d: linear PM %.1f GM %.2f fails the final requirement\n', i, Rl.PM, Rl.GM); continue; end
    M = calib_margin('Model_MapPIDLag', seed1, mappidlag_variables(Cal, d));
    Simulink.sdi.clear;
    top.margin_pass(i) = M.pass; top.ratio_gain(i) = M.ratio_gain; top.ratio_delay(i) = M.ratio_delay;
    if M.pass, pick = i; break; end
end
assert(pick > 0, 'select_mappidlag: no candidate passes the final requirements');
c = top(pick, :);
x = table2array(c(1, vn));
d = xToDesign(x, Ts0);
Rl = mappidlag_margins(Gj, w, d);
fprintf('(5) chosen: candidate %d of the seed ranking: J %.4f (seed %d) / %.4f (seed %d), linear PM %.1f GM %.2f, margin ratios %.2f / %.2f\n', ...
    pick, c.Jv, seed1, c.J2, seed2, Rl.PM, Rl.GM, c.ratio_gain, c.ratio_delay);

%% (6) reports
B = calib_bangbang('Model_MapPIDLag', seed1, mappidlag_variables(Cal, d));
Simulink.sdi.clear;
e3 = F(F.erel_pct <= 3, :);
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
uc = mappidlag_x2u(x); atB = free(uc(free) < 0.005 | uc(free) > 0.995);
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('    active constraints / bounds: %s\n', strjoin(active, '; '));

sel = struct('x', x, 'design', d, 'J', c.Jv, 'R', c.R_pct, 'S', c.S_Nm, 'TV', c.TV, 'erel', c.erel_pct, 'rev', c.rev_pct, ...
    'J_seed2', c.J2, 'R_seed2', c.R2, 'S_seed2', c.S2, 'erel_seed2', c.erel2, 'PM', Rl.PM, 'GM', Rl.GM, 'HF', Rl.HF, 'lagGain2Hz', lagGain, ...
    'ratio_gain', c.ratio_gain, 'ratio_delay', c.ratio_delay, 'bangbang', B, 'Jstar', Jstar, 'nEval', nEval, 'nSim', nSim, ...
    'nRegion', height(Rg), 'nRunsConverged', nConv, 'bestPerRun', bestRun, 'nBetterNeighbours', better, 'J_erel3', J3, 'J_erel10', J10, 'active', {active});
writetable(top, fullfile(outDir, [variant '_CALIB_pick_s50000.csv']));
if writeJson
    jf = fullfile(modelDir, 'data', 'mappidlag.json');
    J = jsondecode(fileread(jf));
    Jmd = Jm.design;
    ds = struct('Kmax', d.Kmax, 'Ts0', Ts0, 'lag', d.lag, 'Kp', d.Kp, 'Ki', d.Ki, 'Kd', d.Kd, 'Tf', d.Tf, ...
        'Kaw', ifelse(d.Ki > 0 && d.Kp + d.Kmax > 0, d.Ki / (d.Kp + d.Kmax), 0), ...
        'rule', 'min J = R*S by simultaneous optimisation (surrogateopt x3 + patternsearch x3), same method and constraints as MapPID', ...
        'CALIB_R_pct', c.R_pct, 'CALIB_S_Nm', c.S_Nm, 'CALIB_TV_Nm_per_s', c.TV, 'CALIB_erel_pct', c.erel_pct, 'CALIB_rev_pct', 100 * c.rev_pct, 'CALIB_J', c.Jv, ...
        'seed_50001_R_pct', c.R2, 'seed_50001_S_Nm', c.S2, 'seed_50001_erel_pct', c.erel2, 'PM_deg', Rl.PM, 'GM', Rl.GM, 'HF_gain', Rl.HF, 'lag_gain_2Hz', lagGain, ...
        'margin_ratio_gain', c.ratio_gain, 'margin_ratio_delay', c.ratio_delay, 'bangbang', struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp), ...
        'n_evaluations', nEval, 'n_simulations', nSim, 'design_seed', seed1, 'map_source_date', Jmd.date, 'date', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    if strcmp(variant, 'PIDLag'), J.pidlag = struct('design', ds); else, J.design = ds; end
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_mappidlag: design (%s) written to %s\n', variant, jf);
end
end

function d = xToDesign(x, Ts0)
d = struct('Ts_ctrl', 1e-3, 'Ts0', Ts0, 'Kmax', x(1), 'lag', struct('z1', x(2), 'p1', x(2) * x(3)), 'Kp', x(4), 'Ki', x(5), 'Kd', x(6), 'Tf', x(7));
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
