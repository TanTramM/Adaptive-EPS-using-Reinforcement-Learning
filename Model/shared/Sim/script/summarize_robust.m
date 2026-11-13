function summarize_robust(stage)
%SUMMARIZE_ROBUST Checks R1-R3 and the summary tables of KeHoach_DoBenThamSo.txt (sections 4 and 6).
%
%   summarize_robust('R1')    nominal rerun equals Result/Controllers/<Ctrl>/Cases_ssw metrics (relative difference < 1e-6)
%   summarize_robust('R2R3')  negative control (each variant differs from nom in RMS_eT) and completeness (same rows as nom)
%   summarize_robust('tables') Robust_summary_s99999.csv, Robust_rank_s99999.csv, Robust_summary_s99999.txt
%   Everything is read from the metrics csv written by run_cases; nothing is recomputed from signals.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
repoDir = fileparts(modelDir);
addpath(fullfile(modelDir, 'shared')); setup_paths;
rootDir = fullfile(repoDir, 'Result', 'Compare', 'Robust');
ctrls = {'Map', 'PID', 'MapPID'}; cases = {'STEADY', 'SLIP', 'WEAVE'};
tag = 's99999';
names = robust_variants();
switch stage
    case 'R1', checkR1();
    case 'R2R3', checkR2R3();
    case 'tables', makeTables();
    otherwise, error('summarize_robust: unknown stage %s', stage);
end

    function T = readM(vn, c, tg)
        T = readtable(fullfile(rootDir, vn, sprintf('%s_metrics_%s.csv', c, tg)), 'VariableNamingRule', 'preserve');
    end

    function checkR1()
        ok = true; lines = {sprintf('R1 nominal rerun vs Result/Controllers/<Ctrl>/Cases_ssw, %s', datestr(now, 'yyyy-mm-dd HH:MM'))};
        for i = 1:numel(ctrls)
            A = readM('nom', ctrls{i}, tag);
            B = readtable(fullfile(repoDir, 'Result', 'Controllers', ctrls{i}, 'Cases_ssw', sprintf('%s_metrics_%s.csv', ctrls{i}, tag)), 'VariableNamingRule', 'preserve');
            same = height(A) == height(B) && isequal(A.Case, B.Case) && isequal(A.Window, B.Window);
            e1 = NaN; e2 = NaN;
            if same
                e1 = maxRel(A.RMS_eT_Nm, B.RMS_eT_Nm); e2 = maxRel(A.S_Nm, B.S_Nm);
            end
            pass = same && e1 < 1e-6 && e2 < 1e-6;
            ok = ok && pass;
            lines{end+1} = sprintf('%-7s rows %d vs %d, max rel diff RMS_eT_Nm %.3g, S_Nm %.3g -> %s', ctrls{i}, height(A), height(B), e1, e2, ternary(pass, 'PASS', 'FAIL')); %#ok<AGROW>
        end
        lines{end+1} = ternary(ok, '[summarize_robust] R1 PASS', '[summarize_robust] R1 FAIL');
        writeLines(fullfile(rootDir, 'Robust_R1.txt'), lines);
    end

    function checkR2R3()
        lines = {sprintf('R2 negative control and R3 completeness, %s', datestr(now, 'yyyy-mm-dd HH:MM'))};
        okAll = true;
        for k = 2:numel(names)
            vn = names{k}; maxd = 0; complete = true;
            for i = 1:numel(ctrls)
                A = readM('nom', ctrls{i}, tag); V = readM(vn, ctrls{i}, tag);
                complete = complete && height(A) == height(V) && isequal(A.Window, V.Window) && isequal(A.Case, V.Case);
                if height(A) == height(V)
                    maxd = max(maxd, maxRel(V.RMS_eT_Nm, A.RMS_eT_Nm));
                end
            end
            r2 = maxd > 1e-6;
            okAll = okAll && r2 && complete;
            lines{end+1} = sprintf('%-10s max rel diff of RMS_eT vs nom %.3g -> R2 %s; R3 rows %s', vn, maxd, ternary(r2, 'differs (OK)', 'SAME AS NOM (variable not entering the model)'), ternary(complete, 'OK', 'INCOMPLETE')); %#ok<AGROW>
        end
        lines{end+1} = ternary(okAll, '[summarize_robust] R2 R3 PASS', '[summarize_robust] R2 R3 FAIL (see lines above)');
        writeLines(fullfile(rootDir, 'Robust_R2R3.txt'), lines);
    end

    function makeTables()
        rows = {};
        for k = 1:numel(names)
            for i = 1:numel(ctrls)
                V = readM(names{k}, ctrls{i}, tag); N = readM('nom', ctrls{i}, tag);
                for c = 1:numel(cases)
                    wv = strcmp(V.Case, cases{c}) & strcmp(V.Window, 'whole case'); wn = strcmp(N.Case, cases{c}) & strcmp(N.Window, 'whole case');
                    sw = strcmp(V.Case, cases{c}) & ~strcmp(V.Window, 'whole case') & isfinite(V.Mean_eT_signed_pct_of_Tdref);
                    sn = strcmp(N.Case, cases{c}) & ~strcmp(N.Window, 'whole case') & isfinite(N.Mean_eT_signed_pct_of_Tdref);
                    E = V.RMS_eT_Nm(wv); En = N.RMS_eT_Nm(wn);
                    S = V.S_Nm(wv); Sn = N.S_Nm(wn);
                    eps_v = V.Mean_eT_signed_pct_of_Tdref(sw); eps_n = N.Mean_eT_signed_pct_of_Tdref(sn);
                    rows(end+1, :) = {names{k}, ctrls{i}, cases{c}, E, S, V.Light_s(wv), V.Heavy_s(wv), max(abs(eps_v)), mean(eps_v), ...
                        100 * (E - En) / En, 100 * (S - Sn) / Sn, mean(eps_v) - mean(eps_n), max(abs(eps_v)) - max(abs(eps_n))}; %#ok<AGROW>
                end
            end
        end
        T = cell2table(rows, 'VariableNames', {'Variant', 'Ctrl', 'Case', 'E_RMS_Nm', 'S_Nm', 'Light_s', 'Heavy_s', 'MaxAbsEps_pct', 'MeanEps_pct', ...
            'dE_pct', 'dS_pct', 'dMeanEps_pt', 'dMaxAbsEps_pt'});
        writetable(T, fullfile(rootDir, sprintf('Robust_summary_%s.csv', tag)));

        % rank of E_RMS in each (variant, case): '=' when two values differ by less than 5 % of the smaller (QuyChuan 6.4 tie threshold)
        rk = {};
        for k = 1:numel(names)
            for c = 1:numel(cases)
                m = strcmp(T.Variant, names{k}) & strcmp(T.Case, cases{c});
                E = T.E_RMS_Nm(m); cn = T.Ctrl(m);
                rk(end+1, :) = {names{k}, cases{c}, rankText(E, cn)}; %#ok<AGROW>
            end
        end
        R = cell2table(rk, 'VariableNames', {'Variant', 'Case', 'Order_best_first'});
        nomRank = containers.Map();
        for r = 1:height(R), if strcmp(R.Variant{r}, 'nom'), nomRank(R.Case{r}) = R.Order_best_first{r}; end, end
        st = cell(height(R), 1);
        for r = 1:height(R)
            if strcmp(R.Order_best_first{r}, nomRank(R.Case{r})), st{r} = 'giu'; else, st{r} = 'khac nom'; end
        end
        R.vs_nom = st;
        writetable(R, fullfile(rootDir, sprintf('Robust_rank_%s.csv', tag)));
        txt = textSummary(T, R);
        writeLines(fullfile(rootDir, sprintf('Robust_summary_%s.txt', tag)), txt);
        fprintf('%s\n', txt{:});
    end

    function txt = textSummary(T, R)
        txt = {sprintf('Robust summary (seed 99999), %s. Delta = bien the - nom. Thu hang E_RMS: dau "=" khi chenh < 5 %%.', datestr(now, 'yyyy-mm-dd HH:MM'))};
        for c = 1:numel(cases)
            txt{end+1} = ''; txt{end+1} = ['Ca ' cases{c} ': Delta E_RMS (%) theo nhom, p20 / m20, thu tu Map, PID, MapPID']; %#ok<AGROW>
            for g = robust_variants('groups')
                line = sprintf('%-8s', g{1});
                for i = 1:numel(ctrls)
                    a = T.dE_pct(strcmp(T.Variant, [g{1} 'p20']) & strcmp(T.Ctrl, ctrls{i}) & strcmp(T.Case, cases{c}));
                    b = T.dE_pct(strcmp(T.Variant, [g{1} 'm20']) & strcmp(T.Ctrl, ctrls{i}) & strcmp(T.Case, cases{c}));
                    line = [line sprintf(' | %s %+7.1f / %+7.1f', ctrls{i}, a, b)]; %#ok<AGROW>
                end
                txt{end+1} = line; %#ok<AGROW>
            end
            txt{end+1} = ['Thu hang nom ' cases{c} ': ' R.Order_best_first{strcmp(R.Variant, 'nom') & strcmp(R.Case, cases{c})}]; %#ok<AGROW>
            d = R(strcmp(R.Case, cases{c}) & strcmp(R.vs_nom, 'khac nom'), :);
            for r = 1:height(d), txt{end+1} = sprintf('  doi thu hang: %s -> %s', d.Variant{r}, d.Order_best_first{r}); end %#ok<AGROW>
        end
        txt{end+1} = ''; txt{end+1} = 'Sai lech tinh STEADY: trung binh epsilon_w (% T_d,ref, am = tay nhe hon muc tieu) va max |epsilon_w|, nom va bien the';
        for i = 1:numel(ctrls)
            m = strcmp(T.Variant, 'nom') & strcmp(T.Ctrl, ctrls{i}) & strcmp(T.Case, 'STEADY');
            txt{end+1} = sprintf('%-7s nom: mean eps %+.3f, max|eps| %.3f', ctrls{i}, T.MeanEps_pct(m), T.MaxAbsEps_pct(m)); %#ok<AGROW>
        end
    end

    function s = rankText(E, cn)
        [~, o] = sort(E); s = cn{o(1)};
        for j = 2:numel(o)
            if abs(E(o(j)) - E(o(j-1))) / min(E(o(j)), E(o(j-1))) < 0.05, s = [s ' = ' cn{o(j)}]; else, s = [s ' < ' cn{o(j)}]; end %#ok<AGROW>
        end
    end
end

function d = maxRel(a, b)
    ok = isfinite(a) & isfinite(b);
    d = max(abs(a(ok) - b(ok)) ./ max(abs(b(ok)), 1e-12));
    if isempty(d), d = 0; end
    if any(isfinite(a) ~= isfinite(b)), d = Inf; end
end
function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
function writeLines(file, lines)
    fid = fopen(file, 'w'); fprintf(fid, '%s\n', lines{:}); fclose(fid);
end
