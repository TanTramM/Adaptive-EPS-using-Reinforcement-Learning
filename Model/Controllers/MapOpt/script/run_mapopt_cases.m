function M = run_mapopt_cases(runSeed)
%RUN_MAPOPT_CASES Run the five scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE) for the design of data/mapopt.json at one seed (default 0, the local seed of the Map family;
%   DieuKhien_MapOpt.txt C5: ONE seed this time, the five scoring seeds 99999-99995 come later with run_scoring_seeds). Results in Result/Controllers/MapOpt/Cases/.
if nargin < 1, runSeed = 0; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapOpt', 'load_mapopt.m'), '\', '/')));
M = run_cases('MapOpt', runSeed);
Simulink.sdi.clear;
end
