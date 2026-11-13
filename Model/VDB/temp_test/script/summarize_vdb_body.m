function summarize_vdb_body()
%SUMMARIZE_VDB_BODY Summary of the VDB body runs (plan KeHoach_VDB_ThanXe.txt, V5), seed 99999.
%   Reads the "whole case" rows of the baseline and of the variants VDBTireLag, VDBBody, VDBTireBody, VDBTireLagBody and writes
%   Model/VDB/temp_test/Summary/VDB_body_summary_s99999.csv (values and % change against the baseline), VDB_body_rank_s99999.csv
%   (ranking of the three controllers by RMS_eT per variant and case, two controllers within 5 % are a tie) and VDB_body_summary_s99999.txt.
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    repoDir = fileparts(fileparts(fileparts(tempDir)));
    outDir = fullfile(tempDir, 'Summary'); if ~exist(outDir, 'dir'), mkdir(outDir); end
    ctrls = {'Map', 'PID', 'MapPID'}; cases = {'STEADY', 'SLIP', 'WEAVE'};
    vars = {'Plant', 'VDBTireLag', 'VDBBody', 'VDBTireBody', 'VDBTireLagBody'};
    V = nan(numel(vars), numel(ctrls), numel(cases), 2);          % RMS_eT, S
    for v = 1:numel(vars)
        for c = 1:numel(ctrls)
            if v == 1
                f = fullfile(repoDir, 'Result', 'Controllers', ctrls{c}, 'Cases_ssw', [ctrls{c} '_metrics_s99999.csv']);
            else
                f = fullfile(tempDir, ctrls{c}, 'Result', [ctrls{c} '_' vars{v} '_metrics_s99999.csv']);
            end
            if ~exist(f, 'file'), continue; end
            T = readtable(f, 'VariableNamingRule', 'preserve');
            for k = 1:numel(cases)
                r = strcmp(T.Case, cases{k}) & strcmp(T.Window, 'whole case');
                if any(r), V(v, c, k, :) = [T.RMS_eT_Nm(find(r, 1)), T.S_Nm(find(r, 1))]; end
            end
        end
    end
    fid = fopen(fullfile(outDir, 'VDB_body_summary_s99999.csv'), 'w');
    fprintf(fid, 'variant,controller,case,RMS_eT_Nm,S_Nm,dRMS_eT_pct,dS_pct\n');
    for v = 1:numel(vars), for c = 1:numel(ctrls), for k = 1:numel(cases)
        a = V(v, c, k, :); b = V(1, c, k, :);
        fprintf(fid, '%s,%s,%s,%.6g,%.6g,%.3f,%.3f\n', vars{v}, ctrls{c}, cases{k}, a(1), a(2), 100 * (a(1) / b(1) - 1), 100 * (a(2) / b(2) - 1));
    end, end, end
    fclose(fid);
    % ranking
    rk = @(x) rankOf(x, ctrls);
    fid = fopen(fullfile(outDir, 'VDB_body_rank_s99999.csv'), 'w');
    fprintf(fid, 'variant,case,order_by_RMS_eT,order_baseline,verdict\n');
    txt = {};
    for v = 2:numel(vars), for k = 1:numel(cases)
        o = rk(squeeze(V(v, :, k, 1))); o0 = rk(squeeze(V(1, :, k, 1)));
        if strcmp(o, o0), vd = 'giu'; elseif contains(o, '=') || contains(o0, '='), vd = 'hoa (co cap chenh duoi 5%)'; else, vd = 'doi'; end
        fprintf(fid, '%s,%s,%s,%s,%s\n', vars{v}, cases{k}, o, o0, vd);
        txt{end + 1} = sprintf('%-15s %-7s %-26s mốc %-26s -> %s', vars{v}, cases{k}, o, o0, vd); %#ok<AGROW>
    end, end
    fclose(fid);
    fid = fopen(fullfile(outDir, 'VDB_body_summary_s99999.txt'), 'w', 'n', 'UTF-8');
    fprintf(fid, 'Tom tat chay Plant co than VDB, seed 99999 (RMS_eT thu bac tu tot den xau; "=" la chenh duoi 5%%)\n');
    for i = 1:numel(txt), fprintf(fid, '%s\n', txt{i}); end
    fprintf(fid, '\nDoi RMS_eT (%%) so voi moc, theo bien the (Map/PID/MapPID) cho STEADY, SLIP, WEAVE:\n');
    for v = 2:numel(vars)
        s = sprintf('%-15s', vars{v});
        for k = 1:numel(cases), s = [s sprintf(' %s:', cases{k})]; %#ok<AGROW>
            for c = 1:numel(ctrls), s = [s sprintf(' %+.1f', 100 * (V(v, c, k, 1) / V(1, c, k, 1) - 1))]; end, end %#ok<AGROW>
        fprintf(fid, '%s\n', s);
    end
    fclose(fid);
    disp('summarize_vdb_body: done');
end

function s = rankOf(x, names)
    if any(isnan(x)), s = 'n/a'; return; end
    [~, i] = sort(x); s = names{i(1)};
    for j = 2:3
        a = x(i(j - 1)); b = x(i(j));
        if abs(a - b) / max(a, b) < 0.05, s = [s ' = ' names{i(j)}]; else, s = [s ' < ' names{i(j)}]; end %#ok<AGROW>
    end
end
