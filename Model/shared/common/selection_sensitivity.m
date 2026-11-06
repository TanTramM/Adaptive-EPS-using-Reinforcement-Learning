function S = selection_sensitivity(T, maskNoErel, keyCols, outCsv)
%SELECTION_SENSITIVITY Sensitivity of the selected point to the free choices of the rule (QuyChuan 6.2 and 9.5, v5), computed from the sweep table.
%
%   S = selection_sensitivity(T, maskNoErel, keyCols, outCsv)
%   T           sweep table with columns R_pct, S_Nm, erel_pct, rev_pct and the parameter columns
%   maskNoErel  logical vector: candidates that pass every constraint except the e_rel gate (finite values, Ti, Tf, steering-band constraint)
%   keyCols     cell array of parameter column names to print, e.g. {'Kp','Ki_1_per_s'}
%   outCsv      optional path: the table is written there
%   Rows: the balanced rule J = R^a * S with a = 0.5, 1, 2 (e_rel <= 5 %); the same with e_rel <= 3 % and <= 10 %;
%   the old rule 'R within 5 % of the smallest R, then the smallest S' (pick_by_tolerance, e_rel <= 5 %).
%   The margin gate is NOT re-evaluated here (table only); the chosen point of the selection script is the reference (a = 1, 5 %).
rows = {};
spec = {'J=R^0.5*S, e_rel<=5%', 'bal', 0.5, 5; 'J=R*S, e_rel<=5% (rule)', 'bal', 1, 5; 'J=R^2*S, e_rel<=5%', 'bal', 2, 5; ...
        'J=R*S, e_rel<=3%', 'bal', 1, 3; 'J=R*S, e_rel<=10%', 'bal', 1, 10; 'old: R within 5%, min S, e_rel<=5%', 'tol', 0.05, 5};
fprintf('selection_sensitivity (table only, margin gate not re-run):\n');
for q = 1:size(spec, 1)
    adm = maskNoErel(:) & (T.erel_pct <= spec{q, 4});
    if ~any(adm), fprintf('  %-38s: no admissible point\n', spec{q, 1}); continue; end
    if strcmp(spec{q, 2}, 'bal'), idx = pick_by_balance(T.R_pct, T.S_Nm, adm, spec{q, 3}); else, idx = pick_by_tolerance(T.R_pct, T.S_Nm, adm, spec{q, 3}); end
    i = idx(1);
    kv = ''; for c = 1:numel(keyCols), kv = [kv sprintf(' %s=%g', keyCols{c}, T.(keyCols{c})(i))]; end %#ok<AGROW>
    fprintf('  %-38s: R %6.2f%% S %.4f TV %6.1f erel %5.2f%% rev %5.2f%% |%s\n', spec{q, 1}, T.R_pct(i), T.S_Nm(i), T.TV_Nm_per_s(i), T.erel_pct(i), T.rev_pct(i), kv);
    rows(end+1, :) = {spec{q, 1}, T.R_pct(i), T.S_Nm(i), T.TV_Nm_per_s(i), T.erel_pct(i), T.rev_pct(i), strtrim(kv)}; %#ok<AGROW>
end
S = cell2table(rows, 'VariableNames', {'rule', 'R_pct', 'S_Nm', 'TV_Nm_per_s', 'erel_pct', 'rev_pct', 'point'});
if nargin >= 4 && ~isempty(outCsv), writetable(S, outCsv); end
end
