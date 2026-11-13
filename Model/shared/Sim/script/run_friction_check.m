function run_friction_check(stage)
%RUN_FRICTION_CHECK Dry-friction check (variant Tf0: T_f = 0), Documents/Shared/KeHoach_MaSatCotLai.txt sections 1-2.
%
%   run_friction_check('R0')   Map nominal, SSW, seed 99999 -> Result/Compare/Friction/R0/, compared with Result/Controllers/Map/Cases_ssw (1e-6 relative)
%   run_friction_check('A')    Map, PID, MapPID x seeds 99995-99999, variant Tf0, SSW -> Result/Compare/Friction/Tf0/ (resumable; needs R0 PASS)
%   run_friction_check('B')    CALIB of Map, seeds 99990-99994, nominal and T_f = 0 -> Result/Compare/Friction/Friction_CALIB_runs.csv
%                              (nominal first; stops if the 26.23659312 % of Table 4.5 is not reproduced)
%   run_friction_check('all')  R0, A, B in this order
%
%   Nothing outside Result/Compare/Friction/ is written. Machine hygiene as in run_robust_cases.m.
if nargin < 1, stage = 'all'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
repoDir = fileparts(modelDir);
addpath(fullfile(modelDir, 'shared')); setup_paths;
addpath(fullfile(modelDir, 'VDB', 'Blocks', 'script'));

use_sim_tmp();
cache = 'D:\sim_cache\friction'; if ~isfolder(cache), mkdir(cache); end
Simulink.fileGenControl('set', 'CacheFolder', cache, 'CodeGenFolder', cache, 'createDir', true);
tmp = 'D:\sim_tmp\friction'; if ~isfolder(tmp), mkdir(tmp); end
setenv('TEMP', tmp); setenv('TMP', tmp);

rootDir = fullfile(repoDir, 'Result', 'Compare', 'Friction');
if ~isfolder(rootDir), mkdir(rootDir); end
progress = fullfile(rootDir, 'Friction_progress.txt');
loader = struct('Map', 'load_map', 'PID', 'load_pid', 'MapPID', 'load_mappid');
logLine(progress, sprintf('%s START stage=%s', stamp(), stage));

if any(strcmp(stage, {'R0', 'all'})), stageR0(rootDir, progress, loader); end
if any(strcmp(stage, {'A', 'all'})), stageA(rootDir, progress, loader); end
if any(strcmp(stage, {'B', 'all'})), stageB(rootDir, progress, loader); end
logLine(progress, sprintf('%s FINISHED stage=%s', stamp(), stage));
end

%% ---------------------------------------------------------------- R0
function stageR0(rootDir, progress, loader)
    r0 = fullfile(rootDir, 'R0'); if ~isfolder(r0), mkdir(r0); end
    repoDir = fileparts(fileparts(fileparts(rootDir)));
    seed = 99999; sens = sensor_tag(seed);
    mfile = fullfile(r0, sprintf('Map_metrics_%s.csv', sens));
    if ~isfile(mfile)
        checkDisk(progress);
        evalin('base', [loader.Map ';']);
        run_cases('Map', seed, 'SSW', r0);
        Simulink.sdi.clear; try close_system('Model_Map', 0); catch, end
    end
    A = readtable(mfile); B = readtable(fullfile(repoDir, 'Result', 'Controllers', 'Map', 'Cases_ssw', sprintf('Map_metrics_%s.csv', sens)));
    assert(isequal(size(A), size(B)) && isequal(A.Window, B.Window) && isequal(A.Case, B.Case), 'R0: table layout differs');
    worst = 0; worstName = '';
    for k = 3:width(A)
        a = A{:, k}; b = B{:, k};
        assert(isequal(isnan(a), isnan(b)), 'R0: NaN pattern differs in column %s', A.Properties.VariableNames{k});
        ok = ~isnan(a);
        rel = abs(a(ok) - b(ok)) ./ max(abs(b(ok)), 1e-12);
        if ~isempty(rel) && max(rel) > worst, worst = max(rel); worstName = A.Properties.VariableNames{k}; end
    end
    pass = worst <= 1e-6;
    txt = sprintf('R0 %s: largest relative difference %.3g (column %s), threshold 1e-6\n', ternary(pass, 'PASS', 'FAIL'), worst, worstName);
    fid = fopen(fullfile(rootDir, 'Friction_R0.txt'), 'w'); fprintf(fid, '%s', txt); fclose(fid);
    logLine(progress, [stamp() ' ' strtrim(txt)]);
    if ~pass, error('run_friction_check:R0', 'R0 FAIL (%s). Stop and report; do not rerun the nominal.', strtrim(txt)); end
end

%% ---------------------------------------------------------------- A
function stageA(rootDir, progress, loader)
    r0txt = fullfile(rootDir, 'Friction_R0.txt');
    assert(isfile(r0txt) && contains(fileread(r0txt), 'R0 PASS'), 'run_friction_check: run R0 first (needs PASS)');
    outDir = fullfile(rootDir, 'Tf0'); if ~isfolder(outDir), mkdir(outDir); end
    ctrls = {'Map', 'PID', 'MapPID'}; seeds = 99995:99999;
    for ic = 1:numel(ctrls)
        for is = 1:numel(seeds)
            ctrl = ctrls{ic}; seed = seeds(is); sens = sensor_tag(seed);
            if isfile(fullfile(outDir, sprintf('%s_metrics_%s.csv', ctrl, sens))), continue; end
            checkDisk(progress);
            t0 = tic;
            evalin('base', [loader.(ctrl) ';']);              % nominal values
            assignin('base', 'T_f', 0);                        % the only change
            evalin('base', 'load_derived;');
            M = run_cases(ctrl, seed, 'SSW', outDir);
            Simulink.sdi.clear; try close_system(['Model_' ctrl], 0); catch, end
            w = strcmp(M.Window, 'whole case');
            r = M.RMS_eT_Nm(w);
            logLine(progress, sprintf('%s DONE A Tf0 %s %s %.0f s RMS_eT STEADY %.4f SLIP %.4f WEAVE %.4f', stamp(), ctrl, sens, toc(t0), r(1), r(2), r(3)));
        end
    end
end

%% ---------------------------------------------------------------- B
function stageB(rootDir, progress, loader)
    seeds = 99990:99994; mdl = 'Model_Map';
    file = fullfile(rootDir, 'Friction_CALIB_runs.csv');
    if isfile(file), R = readtable(file); else, R = table(); end
    for pass = 1:2                                   % 1 = nominal, 2 = T_f = 0
        tag = ternary(pass == 1, 'nom', 'Tf0');
        for is = 1:numel(seeds)
            seed = seeds(is);
            if ~isempty(R) && any(strcmp(R.Variant, tag) & R.Seed == seed), continue; end
            checkDisk(progress);
            t0 = tic;
            evalin('base', [loader.Map ';']);
            assert(abs(evalin('base', 'T_f') - 2) < 1e-12, 'run_friction_check: nominal T_f is not 2 N.m');
            if pass == 1, vars = []; else, vars = struct('T_f', 0); end
            [~, m] = calib_run(mdl, seed, vars);
            Simulink.sdi.clear;
            Rk = table(repmat({tag}, numel(m.erelLabel), 1), repmat(seed, numel(m.erelLabel), 1), m.erelLabel(:), m.erelSigned(:), ...
                'VariableNames', {'Variant', 'Seed', 'Label', 'erelSigned'});
            if isempty(R), R = Rk; else, R = [R; Rk]; end %#ok<AGROW>
            writetable(R, file);
            logLine(progress, sprintf('%s DONE B %s seed %d %.0f s erel_max %.4f %%', stamp(), tag, seed, toc(t0), m.erel));
        end
        if pass == 1
            % reproduction of Table 4.5: erel_max of the design = max over the five seeds of the per-seed maximum
            Rn = R(strcmp(R.Variant, 'nom'), :);
            perSeed = arrayfun(@(s) max(abs(Rn.erelSigned(Rn.Seed == s))), seeds);
            ref = 26.23659312; rel = abs(max(perSeed) - ref) / ref;
            txt = sprintf('B nominal: erel_max per seed %s; max over seeds %.8f vs 26.23659312 of Table 4.5, relative difference %.3g -> %s', ...
                mat2str(perSeed, 8), max(perSeed), rel, ternary(rel <= 1e-4, 'REPRODUCED', 'NOT REPRODUCED'));
            logLine(progress, [stamp() ' ' txt]);
            fid = fopen(fullfile(rootDir, 'Friction_CALIB_repro.txt'), 'w'); fprintf(fid, '%s\n', txt); fclose(fid);
            if rel > 1e-4, error('run_friction_check:B', 'B: 26.2366 %% not reproduced (%s). Stop and report.', txt); end
        end
    end
    try close_system(mdl, 0); catch, end
end

%% ---------------------------------------------------------------- helpers
function checkDisk(progress)
    freeC = java.io.File('C:\').getFreeSpace() / 2^30;
    if freeC < 10, logLine(progress, sprintf('%s STOP drive C has %.1f GB (< 10 GB)', stamp(), freeC)); error('run_friction_check: drive C below 10 GB'); end
end
function s = stamp(), s = datestr(now, 'yyyy-mm-dd HH:MM:SS'); end
function v = ternary(c, a, b), if c, v = a; else, v = b; end, end
function logLine(file, txt)
    fid = fopen(file, 'a'); fprintf(fid, '%s\n', txt); fclose(fid); fprintf('%s\n', txt);
end
