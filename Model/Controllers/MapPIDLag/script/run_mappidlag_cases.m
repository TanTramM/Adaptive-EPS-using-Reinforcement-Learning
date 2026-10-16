function M = run_mappidlag_cases(variant, runSeed)
%RUN_MAPPIDLAG_CASES Run the five scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE) for the design of data/mappidlag.json at one seed.
%
%   M = run_mappidlag_cases('MapPIDLag', 50000)   the MapPIDLag design: results in Result/Controllers/MapPIDLag/Cases/ (names MapPIDLag_<CASE>_..._s50000)
%   M = run_mappidlag_cases('PIDLag', 50000)      the PID + lag reference (K = 0): the same model with the variables of pidlag.design; run_cases writes under the name
%                                                 of the model (MapPIDLag_...), so the files are stashed, produced, then moved to
%                                                 Result/Controllers/MapPIDLag/PIDLag/Cases/ and renamed PIDLag_<CASE>_... (the title inside the PNG still reads
%                                                 MapPIDLag); the files of the MapPIDLag design in Cases/ are restored untouched.
%   The local seed of the controller (50000) is used when one controller is run alone; the common seed 99999 only when several controllers are compared
%   (Tracking/CLAUDE.md), which is a later step.
if nargin < 1 || isempty(variant), variant = 'MapPIDLag'; end
if nargin < 2, runSeed = 50000; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
assignin('base', 'MapPIDLag_variant', variant);
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'load_mappidlag.m'), '\', '/')));
if ~exist(fullfile(modelDir, 'Controllers', 'MapPIDLag', 'Model_MapPIDLag.mdl'), 'file'), build_closed_loop('MapPIDLag'); end
if strcmp(variant, 'MapPIDLag')
    M = run_cases('MapPIDLag', runSeed);
    Simulink.sdi.clear;
    return;
end
assert(strcmp(variant, 'PIDLag'), 'variant must be MapPIDLag or PIDLag');
sens = sensor_tag(runSeed);
casesDir = result_dir('MapPIDLag', 'Cases');
stash = fullfile(result_dir('MapPIDLag', 'PIDLag'), 'stash_tmp');
if ~exist(stash, 'dir'), mkdir(stash); end
mine = dir(fullfile(casesDir, ['MapPIDLag_*_' sens '.*']));
for i = 1:numel(mine), movefile(fullfile(casesDir, mine(i).name), fullfile(stash, mine(i).name)); end
try
    M = run_cases('MapPIDLag', runSeed);
    Simulink.sdi.clear;
    outDir = result_dir('MapPIDLag', 'PIDLag', 'Cases');
    made = dir(fullfile(casesDir, ['MapPIDLag_*_' sens '.*']));
    for i = 1:numel(made)
        movefile(fullfile(casesDir, made(i).name), fullfile(outDir, ['PIDLag_' made(i).name(numel('MapPIDLag_') + 1:end)]));
    end
catch ME
    restore(stash, casesDir); rethrow(ME);
end
restore(stash, casesDir);
end

function restore(stash, casesDir)
f = dir(fullfile(stash, '*'));
for i = 1:numel(f)
    if ~f(i).isdir, movefile(fullfile(stash, f(i).name), fullfile(casesDir, f(i).name)); end
end
rmdir(stash);
end
