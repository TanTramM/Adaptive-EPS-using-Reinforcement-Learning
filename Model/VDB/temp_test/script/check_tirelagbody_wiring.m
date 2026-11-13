function check_tirelagbody_wiring()
%CHECK_TIRELAGBODY_WIRING Open-loop DRY check of Plant_VDBTireLagBody against Plant_VDBTireLag (plan KeHoach_VDB_ThanXe.txt, V3 (c)).
%   Runs compare_plant_variant for both Plants, reads the last result line of each, and errors (nonzero MATLAB exit in -batch)
%   when the difference of the T_s deviations exceeds 0.1 percentage points. Writes Model/VDB/temp_test/Summary/VDB_body_wiring_s99999.txt.
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(tempDir));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    addpath(fullfile(modelDir, 'VDB', 'Plants', 'script'));
    names = {'Plant_VDBTireLag', 'Plant_VDBTireLagBody'};
    resDir = result_dir('Plant_VDB', 'Variants');
    E = zeros(2, 6);
    for k = 1:2
        compare_plant_variant(names{k}, 'DRY', 0);
        Simulink.sdi.clear;
        txt = fileread(fullfile(resDir, [names{k} '_compare.txt']));
        L = strsplit(strtrim(txt), newline); L = L(contains(L, [names{k} ': DRY']));
        if isempty(L), error('no DRY result line for %s', names{k}); end
        tok = regexp(L{end}, 'a_y ([\d.]+) %, gamma ([\d.]+) %, F_yf ([\d.]+) %, F_yr ([\d.]+) %, T_r ([\d.]+) %, T_s ([\d.]+) %', 'tokens', 'once');
        if isempty(tok), error('cannot parse: %s', L{end}); end
        E(k, :) = str2double(tok);
    end
    d = E(2, 6) - E(1, 6);
    outDir = fullfile(tempDir, 'Summary'); if ~exist(outDir, 'dir'), mkdir(outDir); end
    fid = fopen(fullfile(outDir, 'VDB_body_wiring_s99999.txt'), 'a');
    fprintf(fid, '%s  errors %% (a_y gamma F_yf F_yr T_r T_s)\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    for k = 1:2, fprintf(fid, '  %-22s %s\n', names{k}, sprintf('%.4f ', E(k, :))); end
    fprintf(fid, '  T_s difference (Body - Lag) = %.4f percentage points (limit 0.1)\n', d);
    fclose(fid);
    fprintf('wiring: T_s difference %.4f points\n', d);
    if abs(d) > 0.1, error('wiring check failed: T_s difference %.4f > 0.1 points', d); end
end
