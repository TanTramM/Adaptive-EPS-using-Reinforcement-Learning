function run_robust_cases(variantList, seed, ctrlList)
%RUN_ROBUST_CASES Run the SSW cases of each Plant-parameter variant on Map, PID, MapPID (KeHoach_DoBenThamSo.txt, sections 3 and 5).
%
%   run_robust_cases({'nom'})                    variants by name (robust_variants.m); {} or 'all' = every variant
%   run_robust_cases(list, 99995)                another run seed (default 99999)
%   run_robust_cases(list, seed, {'Map','PID'})  subset of controllers
%
%   Per (variant, controller): load_<ctrl> (nominal), assign the variant, load_derived, run_cases(ctrl, seed, 'SSW', outDir) with
%   outDir = Result/Compare/Robust/<variant>/. A (variant, controller) whose metrics csv exists is skipped, so a rerun resumes.
%   Progress goes to Result/Compare/Robust/Robust_progress.txt. Models are not saved (close_system(...,0)).
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
repoDir = fileparts(modelDir);
addpath(fullfile(modelDir, 'shared')); setup_paths;
addpath(fullfile(modelDir, 'VDB', 'Blocks', 'script'));
if nargin < 1 || isempty(variantList) || (ischar(variantList) && strcmp(variantList, 'all')), variantList = robust_variants(); end
if nargin < 2 || isempty(seed), seed = 99999; end
if nargin < 3 || isempty(ctrlList), ctrlList = {'Map', 'PID', 'MapPID'}; end
loader = struct('Map', 'load_map', 'PID', 'load_pid', 'MapPID', 'load_mappid');

% machine hygiene shared with the WEAVE frame (section 9 of the plan)
use_sim_tmp();
cache = 'D:\sim_cache\robust'; if ~isfolder(cache), mkdir(cache); end
Simulink.fileGenControl('set', 'CacheFolder', cache, 'CodeGenFolder', cache, 'createDir', true);
tmp = 'D:\sim_tmp\robust'; if ~isfolder(tmp), mkdir(tmp); end
setenv('TEMP', tmp); setenv('TMP', tmp);

rootDir = fullfile(repoDir, 'Result', 'Compare', 'Robust');
if ~isfolder(rootDir), mkdir(rootDir); end
progress = fullfile(rootDir, 'Robust_progress.txt');
logLine(progress, sprintf('%s START variants=%s seed=%d', stamp(), strjoin(variantList, ','), seed));
sens = sensor_tag(seed);
for iv = 1:numel(variantList)
    vn = variantList{iv};
    outDir = fullfile(rootDir, vn);
    if ~isfolder(outDir), mkdir(outDir); end
    for ic = 1:numel(ctrlList)
        ctrl = ctrlList{ic};
        mfile = fullfile(outDir, sprintf('%s_metrics_%s.csv', ctrl, sens));
        if isfile(mfile), continue; end
        freeC = java.io.File('C:\').getFreeSpace() / 2^30;
        if freeC < 10, logLine(progress, sprintf('%s STOP drive C has %.1f GB (< 10 GB)', stamp(), freeC)); error('run_robust_cases: drive C below 10 GB'); end
        t0 = tic;
        evalin('base', [loader.(ctrl) ';']);                     % (1) nominal values
        A = robust_variants(vn);                                  % read the nominal values of the base workspace
        for j = 1:size(A, 1), assignin('base', A{j, 1}, A{j, 2}); end   % (2)
        evalin('base', 'load_derived;');                          % (3)
        M = run_cases(ctrl, seed, 'SSW', outDir);                 % (4)
        Simulink.sdi.clear;                                       % (5)
        try close_system(['Model_' ctrl], 0); catch, end
        w = strcmp(M.Window, 'whole case');
        r = M.RMS_eT_Nm(w);
        logLine(progress, sprintf('%s DONE %s %s %.0f s RMS_eT STEADY %.4f SLIP %.4f WEAVE %.4f (C free %.1f GB)', stamp(), vn, ctrl, toc(t0), r(1), r(2), r(3), freeC));
    end
end
logLine(progress, sprintf('%s ALL FINISHED %s', stamp(), strjoin(variantList, ',')));
end

function s = stamp(), s = datestr(now, 'yyyy-mm-dd HH:MM:SS'); end
function logLine(file, txt)
    fid = fopen(file, 'a'); fprintf(fid, '%s\n', txt); fclose(fid); fprintf('%s\n', txt);
end
