function sel = select_pareto(spec, writeJson)
%SELECT_PARETO Select a grid-search design from the feasible Pareto front.
%   sel = select_pareto(spec, writeJson)
%   Required fields: name, outDir, vn, seed0, seeds, evalFcn, marginFcn,
%   toDesign, jsonPath. Optional fields: PMfin, GMfin, erelMax.

if nargin < 2, writeJson = false; end
defaults = {'PMfin',30; 'GMfin',2; 'erelMax',10; 'marginWorkers',1};
for i = 1:size(defaults, 1), if ~isfield(spec, defaults{i,1}), spec.(defaults{i,1}) = defaults{i,2}; end, end
req = {'name','outDir','vn','seed0','seeds','evalFcn','marginFcn','toDesign','jsonPath'};
for i = 1:numel(req), assert(isfield(spec, req{i}), 'select_pareto:spec', 'Missing spec.%s', req{i}); end

files = dir(fullfile(spec.outDir, sprintf('%s_CALIB_*_w*_s%05d.csv', spec.name, spec.seed0)));
P = table();
for i = 1:numel(files), P = [P; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
assert(~isempty(P), 'select_pareto:noData', 'No grid-search CSV files found for %s.', spec.name);
P = P(P.seed == spec.seed0, :);
[~, iu] = unique(round(table2array(P(:, spec.vn)), 10, 'significant'), 'rows', 'stable'); P = P(sort(iu), :);
feas = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0 & ...
    P.PM_deg >= spec.PMfin & P.GM >= spec.GMfin & isfinite(P.R_pct) & isfinite(P.S_Nm);
F = P(feas, :); F.Jv = F.R_pct .* F.S_Nm;
assert(~isempty(F), 'select_pareto:noFeasible', 'No grid point passes all gates.');
F = sortrows(F, 'Jv');

isFront = true(height(F), 1);
for i = 1:height(F)
    dominates = F.R_pct <= F.R_pct(i) & F.S_Nm <= F.S_Nm(i) & ...
        (F.R_pct < F.R_pct(i) | F.S_Nm < F.S_Nm(i));
    dominates(i) = false;
    if any(dominates), isFront(i) = false; end
end
front = sortrows(F(isFront, :), 'Jv');
Jmin = front.Jv(1);
tie = find(front.Jv <= 1.03 * Jmin);
[~, ip] = max(front.PM_deg(tie)); preferred = tie(ip);

% The preferred Pareto point is checked first. If it fails calib_margin,
% continue through the complete feasible pool in increasing J order.
xPreferred = table2array(front(preferred, spec.vn));
samePreferred = all(abs(table2array(F(:, spec.vn)) - xPreferred) <= 1e-9 .* max(1, abs(xPreferred)), 2);
order = [find(samePreferred, 1); find(~samePreferred)];
pick = 0; M = struct();
marginCacheFile = fullfile(spec.outDir, sprintf('%s_CALIB_margin_failures_s%05d.csv', spec.name, spec.seed0));
marginFailures = readMarginFailures(marginCacheFile, spec.vn);
order = order(:)';
marginWorkers = max(1, floor(spec.marginWorkers));
pool = [];
% Do not create a native process pool merely to replay a complete rejection
% cache. This path must report noMargin without pool startup/shutdown (which
% can itself crash a MATLAB session after all candidate results are saved).
pendingMargin = true;
if ~isempty(marginFailures)
    Xordered = table2array(F(order, spec.vn));
    Xfailed = table2array(marginFailures(:, spec.vn));
    cached = false(size(Xordered,1),1);
    for q = 1:size(Xordered,1)
        cached(q) = any(all(abs(Xfailed-Xordered(q,:)) <= 1e-9.*max(1,abs(Xordered(q,:))),2));
    end
    pendingMargin = any(~cached);
end
if marginWorkers > 1 && pendingMargin
    try
        pool = gcp('nocreate');
        if isempty(pool) || pool.NumWorkers ~= marginWorkers
            if ~isempty(pool), delete(pool); end
            pool = parpool('local', marginWorkers);
        end
        fprintf('select_pareto(%s): evaluating calib_margin in ordered batches of %d workers\n', spec.name, marginWorkers);
    catch ME
        warning('select_pareto:parallelMargin', 'Parallel margin pool unavailable (%s); using one worker.', ME.message);
        pool = [];
        marginWorkers = 1;
    end
end
poolCleanup = onCleanup(@() closeMarginPool(pool));
next = 1;
while next <= numel(order)
    batch = zeros(1, 0);
    while next <= numel(order) && numel(batch) < marginWorkers
        q = order(next); next = next + 1;
        x = table2array(F(q, spec.vn));
        if ~isempty(marginFailures) && any(all(abs(table2array(marginFailures(:, spec.vn)) - x) <= 1e-9 .* max(1, abs(x)), 2))
            fprintf('select_pareto(%s): J-rank %d skips cached calib_margin failure\n', spec.name, q);
        else
            batch(end + 1) = q; %#ok<AGROW>
        end
    end
    if isempty(batch), continue; end
    Xbatch = table2array(F(batch, spec.vn));
    Mbatch = cell(1, numel(batch));
    if isempty(pool)
        for b = 1:numel(batch), Mbatch{b} = runMargin(spec.marginFcn, Xbatch(b, :)); end
    else
        parfor b = 1:numel(batch)
            Mbatch{b} = runMargin(spec.marginFcn, Xbatch(b, :));
        end
    end
    % Consume results in J order. Parallel work can evaluate later points early,
    % but it cannot change which feasible fallback is selected.
    for b = 1:numel(batch)
        q = batch(b); x = Xbatch(b, :); M = Mbatch{b};
        if M.pass, pick = q; break; end
        appendMarginFailure(marginCacheFile, spec.vn, x, M);
        marginFailures = [marginFailures; array2table(x, 'VariableNames', spec.vn)]; %#ok<AGROW>
        fprintf('select_pareto(%s): J-rank %d fails calib_margin (%.3f / %.3f)\n', spec.name, q, M.ratio_gain, M.ratio_delay);
    end
    if pick > 0, break; end
end
assert(pick > 0, 'select_pareto:noMargin', 'No feasible design passes calib_margin.');
chosen = F(pick, :); x = table2array(chosen(:, spec.vn));

% Report five seeds for the chosen point and the next four Pareto points.
frontOrder = [find(all(abs(table2array(front(:, spec.vn)) - x) <= 1e-9 .* max(1, abs(x)), 2), 1); (1:height(front))'];
frontOrder = unique(frontOrder, 'stable'); frontOrder = frontOrder(1:min(5, numel(frontOrder)));
reportFile = fullfile(spec.outDir, sprintf('%s_CALIB_pareto_check_s%05d-s%05d.csv', spec.name, spec.seeds(1), spec.seeds(end)));
nR = numel(frontOrder); nS = numel(spec.seeds);
Jseed = nan(nR, nS); Eseed = Jseed; Rseed = Jseed; Sseed = Jseed;
for i = 1:nR
    xi = table2array(front(frontOrder(i), spec.vn));
    for k = 1:nS
        o = spec.evalFcn(xi, spec.seeds(k), reportFile);
        Jseed(i,k) = o.R * o.S; Eseed(i,k) = o.erel; Rseed(i,k) = o.R; Sseed(i,k) = o.S;
    end
end
chosenFrontRow = find(frontOrder == find(all(abs(table2array(front(:, spec.vn)) - x) <= 1e-9 .* max(1, abs(x)), 2), 1), 1);
if isempty(chosenFrontRow)
    % A calib_margin fallback can be off the Pareto front; report it explicitly.
    chosenFrontRow = 1; Jseed(1,:) = NaN; Eseed(1,:) = NaN; Rseed(1,:) = NaN; Sseed(1,:) = NaN;
    for k = 1:nS
        o = spec.evalFcn(x, spec.seeds(k), reportFile);
        Jseed(1,k) = o.R * o.S; Eseed(1,k) = o.erel; Rseed(1,k) = o.R; Sseed(1,k) = o.S;
    end
end

front.chosen = double(all(abs(table2array(front(:, spec.vn)) - x) <= 1e-9 .* max(1, abs(x)), 2));
writetable(front, fullfile(spec.outDir, sprintf('%s_CALIB_pareto_s%05d.csv', spec.name, spec.seed0)));
F.chosen = double((1:height(F))' == pick);
writetable(F, fullfile(spec.outDir, sprintf('%s_CALIB_pick_s%05d.csv', spec.name, spec.seed0)));
plotPareto(P, F, front, chosen, fullfile(spec.outDir, sprintf('%s_CALIB_pareto_s%05d.png', spec.name, spec.seed0)), spec.name);

chosenJ = Jseed(chosenFrontRow, :); chosenE = Eseed(chosenFrontRow, :);
fprintf('select_pareto(%s): %d evaluated, %d simulated, %d feasible, %d Pareto; chosen J %.6g (R %.6g %%, S %.6g), PM %.3f, GM %.3f\n', ...
    spec.name, height(P), nnz(P.simulated == 1), height(F), height(front), chosen.Jv, chosen.R_pct, chosen.S_Nm, chosen.PM_deg, chosen.GM);
fprintf('  five-seed report: J %.6g +- %.6g, max e_rel %.4g %% (limit %.4g %%), margin ratios %.3f / %.3f\n', ...
    mean(chosenJ), std(chosenJ), max(chosenE), spec.erelMax, M.ratio_gain, M.ratio_delay);
if any(chosenE > spec.erelMax), warning('select_pareto:seedAccuracy', 'Chosen design exceeds e_rel limit on a reporting seed; design is retained for user review.'); end

d = spec.toDesign(x);
sel = struct('x', x, 'design', d, 'J', chosen.Jv, 'R', chosen.R_pct, 'S', chosen.S_Nm, ...
    'PM', chosen.PM_deg, 'GM', chosen.GM, 'erel', chosen.erel_pct, 'margin', M, ...
    'Jseeds', chosenJ, 'erelSeeds', chosenE, 'Jbar', mean(chosenJ), 'sigmaJ', std(chosenJ), ...
    'nEvaluated', height(P), 'nSimulated', nnz(P.simulated == 1), 'nFeasible', height(F), 'nPareto', height(front));

if writeJson
    J = jsondecode(fileread(spec.jsonPath));
    if isfield(J, 'design') && ~isfield(J, 'design_emax5'), J.design_emax5 = J.design; end
    q = d;
    if isfield(q, 'Ts_ctrl'), q = rmfield(q, 'Ts_ctrl'); end
    if isfield(q, 'Ki') && isfield(q, 'Kp'), q.Kaw = q.Ki / q.Kp; end
    q.rule = 'deterministic coarse-to-fine grid, feasible Pareto (R,S), J=R*S with 3% tie by maximum PM, e_max=10%, calib_margin; 2026-10-19';
    q.CALIB_R_pct = chosen.R_pct; q.CALIB_S_Nm = chosen.S_Nm; q.CALIB_J = chosen.Jv;
    q.CALIB_erel_pct = chosen.erel_pct; q.PM_deg = chosen.PM_deg; q.GM = chosen.GM;
    q.CALIB_Jbar_5seed = mean(chosenJ); q.CALIB_sigmaJ_5seed = std(chosenJ); q.CALIB_erel_max_5seed = max(chosenE);
    q.margin_ratio_gain = M.ratio_gain; q.margin_ratio_delay = M.ratio_delay;
    q.n_grid_evaluations = height(P); q.n_grid_simulations = nnz(P.simulated == 1); q.n_grid_feasible = height(F);
    q.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    J.design = q;
    fid = fopen(spec.jsonPath, 'w'); assert(fid >= 0, 'Cannot write %s', spec.jsonPath);
    fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
end
end

function M = runMargin(marginFcn, x)
%RUNMARGIN Preserve a worker failure: it must never become a cached rejection.
M = marginFcn(x);
end

function closeMarginPool(pool)
if ~isempty(pool) && isvalid(pool), delete(pool); end
end

function T = readMarginFailures(fileName, variableNames)
T = array2table(zeros(0, numel(variableNames)), 'VariableNames', variableNames);
if ~isfile(fileName), return; end
try
    raw = readtable(fileName);
    % Early selector runs wrote a headerless CSV.  Recover that cache rather
    % than silently re-running all already validated candidates.
    if ~all(ismember(variableNames, raw.Properties.VariableNames))
        raw = readtable(fileName, 'ReadVariableNames', false);
        if width(raw) >= numel(variableNames)
            raw.Properties.VariableNames(1:numel(variableNames)) = variableNames;
            if width(raw) >= numel(variableNames) + 2
                raw.Properties.VariableNames(numel(variableNames) + (1:2)) = {'ratio_gain', 'ratio_delay'};
            end
        end
    end
    if all(ismember(variableNames, raw.Properties.VariableNames))
        % Inf means the MATLAB/Simulink execution itself failed (for example a
        % missing worker workspace variable), not that this design failed a
        % physical margin test.  Such rows must be retried after recovery.
        if ismember('ratio_gain', raw.Properties.VariableNames)
            raw = raw(isfinite(raw.ratio_gain), :);
        end
        T = raw(:, variableNames);
    end
catch ME
    warning('select_pareto:marginCacheRead', 'Ignoring unreadable margin cache %s: %s', fileName, ME.message);
end
end

function appendMarginFailure(fileName, variableNames, x, M)
row = array2table(x, 'VariableNames', variableNames);
row.ratio_gain = M.ratio_gain;
row.ratio_delay = M.ratio_delay;
if isfile(fileName)
    % A legacy headerless file is still readable by readMarginFailures, but
    % write new files with the column names required for portable recovery.
    writetable(row, fileName, 'WriteMode', 'append', 'WriteVariableNames', false);
else
    writetable(row, fileName);
end
end

function plotPareto(P, F, front, chosen, fileName, name)
fig = figure('Visible', 'off', 'Color', 'w'); hold on; grid on; box on;
sim = P.simulated == 1 & isfinite(P.R_pct) & isfinite(P.S_Nm);
scatter(P.S_Nm(sim), P.R_pct(sim), 18, [0.72 0.72 0.72], 'filled', 'DisplayName', 'Simulated');
scatter(F.S_Nm, F.R_pct, 22, 'k', 'filled', 'DisplayName', 'Feasible');
[~, io] = sort(front.S_Nm); plot(front.S_Nm(io), front.R_pct(io), '-o', 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Pareto front');
scatter(chosen.S_Nm, chosen.R_pct, 90, '^', 'filled', 'DisplayName', 'Chosen');
xlabel('S (N.m)'); ylabel('R (%)'); title(sprintf('%s CALIB v2 grid search', name)); legend('Location', 'best');
exportgraphics(fig, fileName, 'Resolution', 150); close(fig);
end
