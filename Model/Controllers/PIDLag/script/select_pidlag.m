function sel = select_pidlag(ctrl, writeJson)
%SELECT_PIDLAG Verify the optimisation and choose the PIDOpt / PIDLag design: the rule of select_mappid.m (DieuKhien_MapPID.txt O6) with the PID-family seeds 10000 / 10001.
%
%   sel = select_pidlag('PIDLag', true)   also writes the design to data/pidlag.json (PIDOpt: data/pidopt.json)
%   Pools every evaluation at seed 10000 (<ctrl>_CALIB_opt*_s10000.csv, <ctrl>_CALIB_ref*_s10000.csv), then, in the order written in advance:
%   (1) optimal region: feasible designs (simulated, linear PM > 0, GM >= 1, lag gain at 2 Hz >= 0.707, e_rel <= 5 %) with J <= 1.05 J*;
%   (2) convergence: best J of every run (opt i + ref i); how many runs are within 3 % of J*;
%   (3) neighbourhood: around the best design with linear PM >= 30 deg and GM >= 2, +-0.01 of the box in each normalized variable;
%   (4) seed: the 10 best distinct designs with PM >= 30, GM >= 2 are run again with seed 10001; ranking by the mean J of the two seeds;
%   (5) the first of that ranking that passes the simulation margin gate calib_margin (QuyChuan 5.2: R not more than 2x at gain x2 and +1 ms) is chosen;
%   (6) reports: bang-bang (calib_bangbang), reverse assist, e_rel sensitivity 3 % and 10 %, the active constraints and box bounds.
%   Outputs in Result/Controllers/<ctrl>/Calib/: <ctrl>_CALIB_region_s10000.csv, _nbr_s10000.csv, _seed2_s10001.csv, _pick_s10000.csv.
if nargin < 2, writeJson = false; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir(ctrl, 'Calib');
vn = {'Kp', 'Ki', 'Kd', 'Tf', 'z1', 'p1_over_z1'}; n = 4 + 2 * strcmp(ctrl, 'PIDLag'); vn = vn(1:n);
PMfin = 30; GMfin = 2; Ts = 1e-3;
mdl = ['Model_' ctrl];

%% pool
files = [dir(fullfile(outDir, [ctrl '_CALIB_opt*_s10000.csv'])); dir(fullfile(outDir, [ctrl '_CALIB_ref*_s10000.csv']))];
P = table();
for i = 1:numel(files)
    T = readtable(fullfile(outDir, files(i).name));
    tok = regexp(files(i).name, [ctrl '_CALIB_(opt|ref)(\d+)_'], 'tokens', 'once');
    T.stage = repmat(string(tok{1}), height(T), 1); T.run = repmat(str2double(tok{2}), height(T), 1);
    P = [P; T]; %#ok<AGROW>
end
nEval = height(P); nSim = nnz(P.simulated == 1);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0;
F = P(feas, :);
F.Jv = F.R_pct .* F.S_Nm;
[~, iu] = unique(round(table2array(F(:, vn)), 6, 'significant'), 'rows', 'stable');
F = F(iu, :);
F = sortrows(F, 'Jv');
Jstar = F.Jv(1);
fprintf('select_pidlag(%s): %d evaluations (%d simulated), %d feasible; J* = %.4f (R %.3f %%, S %.4f)\n', ctrl, nEval, nSim, height(F), Jstar, F.R_pct(1), F.S_Nm(1));

%% (1) optimal region
Rg = F(F.Jv <= 1.05 * Jstar, :);
writetable(Rg, fullfile(outDir, [ctrl '_CALIB_region_s10000.csv']));
fprintf('(1) optimal region (J <= 1.05 J*): %d designs; ranges:\n', height(Rg));
for k = 1:n, fprintf('    %-11s %.4g .. %.4g\n', vn{k}, min(Rg.(vn{k})), max(Rg.(vn{k}))); end

%% (2) convergence of the independent runs
runs = unique(F.run)';
bestRun = arrayfun(@(r) min(F.Jv(F.run == r)), runs);
nConv = nnz(bestRun <= 1.03 * Jstar);
fprintf('(2) best J per run: %s; %d of %d runs within 3 %% of J*\n', mat2str(bestRun, 4), nConv, numel(runs));

%% (3) neighbourhood of the best design that meets the final linear requirement
Fok = F(F.PM_deg >= PMfin & F.GM >= GMfin, :);
assert(height(Fok) > 0, 'select_pidlag: no feasible design with PM >= %g and GM >= %g', PMfin, GMfin);
JstarOk = Fok.Jv(1);
fprintf('    best design with linear PM >= %g, GM >= %g: J %.4f (%.2f %% above J*), PM %.1f\n', PMfin, GMfin, JstarOk, 100 * (JstarOk / Jstar - 1), Fok.PM_deg(1));
ub = pidlag_x2u(ctrl, table2array(Fok(1, vn)));
nbrFile = fullfile(outDir, [ctrl '_CALIB_nbr_s10000.csv']);
better = 0; nbr = zeros(0, 4);
for k = 1:n
    for sgn = [-1 1]
        u = ub; u(k) = min(max(u(k) + sgn * 0.01, 0), 1);
        if abs(u(k) - ub(k)) < 1e-12, continue; end
        o = pidlag_eval(ctrl, pidlag_u2x(ctrl, u), 10000, nbrFile);
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
seedFile = fullfile(outDir, [ctrl '_CALIB_seed2_s10001.csv']);
top.J2 = nan(height(top), 1); top.R2 = top.J2; top.S2 = top.J2; top.erel2 = top.J2;
for i = 1:height(top)
    o = pidlag_eval(ctrl, table2array(top(i, vn)), 10001, seedFile);
    top.J2(i) = o.R * o.S; top.R2(i) = o.R; top.S2(i) = o.S; top.erel2(i) = o.erel;
end
top.Jmean = (top.Jv + top.J2) / 2;
top.Jchange_pct = 100 * (top.J2 - top.Jv) ./ top.Jv;
top = sortrows(top, 'Jmean');
fprintf('(4) seed 10001: J change %s %%\n', mat2str(round(top.Jchange_pct', 1)));

%% (5) the simulation margin gate
[Gj, w] = mappid_plants();
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', ctrl, ['load_' lower(ctrl) '.m']), '\', '/')));
pick = 0;
top.margin_pass = nan(height(top), 1); top.ratio_gain = top.margin_pass; top.ratio_delay = top.margin_pass;
for i = 1:height(top)
    d = xToDesign(ctrl, table2array(top(i, vn)), Ts);
    M = calib_margin(mdl, 10000, pidlag_variables(ctrl, d));
    Simulink.sdi.clear;
    top.margin_pass(i) = M.pass; top.ratio_gain(i) = M.ratio_gain; top.ratio_delay(i) = M.ratio_delay;
    if M.pass, pick = i; break; end
end
assert(pick > 0, 'select_pidlag: no candidate passes calib_margin');
c = top(pick, :);
x = table2array(c(1, vn));
d = xToDesign(ctrl, x, Ts);
Rl = pidlag_margins(Gj, w, d);
fprintf('(5) chosen: candidate %d of the seed ranking: J %.4f (seed 10000) / %.4f (seed 10001), linear PM %.1f GM %.2f, margin ratios %.2f / %.2f\n', ...
    pick, c.Jv, c.J2, Rl.PM, Rl.GM, c.ratio_gain, c.ratio_delay);

%% (6) reports
B = calib_bangbang(mdl, 10000, pidlag_variables(ctrl, d));
Simulink.sdi.clear;
e3 = F(F.erel_pct <= 3, :);
T10 = P(P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.erel_pct <= 10, :);
J3 = min(e3.Jv); J10 = min(T10.R_pct .* T10.S_Nm);
lagGain = 1; if isfield(d, 'lag'), lagGain = abs((1 + 1i * 4 * pi / d.lag.z1) / (1 + 1i * 4 * pi / d.lag.p1)); end
fprintf('(6) bang-bang: f_ideal %.4f f_noisy %.4f delta %.4f spread %.4f | rev %.2f %% | e_rel %.2f %% | J* if e_rel <= 3 %%: %.4g, if <= 10 %%: %.4g | lag gain 2 Hz %.3f\n', ...
    B.f_ideal, B.f_noisy, B.delta, B.disp, c.rev_pct, c.erel_pct, J3, J10, lagGain);
active = {};
if lagGain < 0.72, active{end + 1} = 'steering band (lag gain at 2 Hz near 0.707)'; end
if c.erel_pct > 4.5, active{end + 1} = 'e_rel near 5 %'; end
if Rl.PM < PMfin + 2, active{end + 1} = sprintf('final linear PM near %g deg', PMfin); end
if Rl.GM < GMfin + 0.1, active{end + 1} = sprintf('final linear GM near %g', GMfin); end
uc = pidlag_x2u(ctrl, x); atB = find(uc < 0.005 | uc > 0.995);
for k = atB, active{end + 1} = sprintf('box bound of %s', vn{k}); end %#ok<AGROW>
if isempty(active), active = {'none (interior optimum)'}; end
fprintf('    active constraints / bounds: %s\n', strjoin(active, '; '));

sel = struct('x', x, 'design', d, 'J', c.Jv, 'R', c.R_pct, 'S', c.S_Nm, 'TV', c.TV, 'erel', c.erel_pct, 'rev', c.rev_pct, ...
    'J_seed2', c.J2, 'R_seed2', c.R2, 'S_seed2', c.S2, 'erel_seed2', c.erel2, 'PM', Rl.PM, 'GM', Rl.GM, 'HF', Rl.HF, 'lagGain2Hz', lagGain, ...
    'ratio_gain', c.ratio_gain, 'ratio_delay', c.ratio_delay, 'bangbang', B, 'Jstar', Jstar, 'nEval', nEval, 'nSim', nSim, ...
    'nRegion', height(Rg), 'nRunsConverged', nConv, 'bestPerRun', bestRun, 'nBetterNeighbours', better, 'J_erel3', J3, 'J_erel10', J10, 'active', {active});
writetable(top, fullfile(outDir, [ctrl '_CALIB_pick_s10000.csv']));
if writeJson
    jf = fullfile(modelDir, 'data', [lower(ctrl) '.json']);
    J = jsondecode(fileread(jf));
    q = struct('Kp', d.Kp, 'Ki', d.Ki, 'Kd', d.Kd, 'Tf', d.Tf);
    if isfield(d, 'lag'), q.lag = d.lag; end
    q.Kaw = ifelse(d.Ki > 0 && d.Kp > 0, d.Ki / d.Kp, 0);
    q.rule = 'min J = R*S by simultaneous optimisation (surrogateopt x3 + patternsearch x3), the MapPID method; PM >= 30, GM >= 2, calib_margin';
    q.CALIB_R_pct = c.R_pct; q.CALIB_S_Nm = c.S_Nm; q.CALIB_TV_Nm_per_s = c.TV; q.CALIB_erel_pct = c.erel_pct; q.CALIB_rev_pct = c.rev_pct; q.CALIB_J = c.Jv;
    q.seed_10001_R_pct = c.R2; q.seed_10001_S_Nm = c.S2; q.seed_10001_erel_pct = c.erel2; q.PM_deg = Rl.PM; q.GM = Rl.GM; q.HF_gain = Rl.HF; q.lag_gain_2Hz = lagGain;
    q.margin_ratio_gain = c.ratio_gain; q.margin_ratio_delay = c.ratio_delay;
    q.bangbang = struct('f_ideal', B.f_ideal, 'f_noisy', B.f_noisy, 'delta', B.delta, 'spread', B.disp);
    q.n_evaluations = nEval; q.n_simulations = nSim; q.design_seed = 10000; q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(jf, 'w'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
    fprintf('select_pidlag: design written to %s\n', jf);
end
end

function d = xToDesign(ctrl, x, Ts)
d = struct('Ts_ctrl', Ts, 'Kp', x(1), 'Ki', x(2), 'Kd', x(3), 'Tf', x(4));
if strcmp(ctrl, 'PIDLag'), d.lag = struct('z1', x(5), 'p1', x(5) * x(6)); end
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
