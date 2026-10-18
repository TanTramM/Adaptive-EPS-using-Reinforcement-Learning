function M = run_mappid_cases(runSeed)
%RUN_MAPPID_CASES Run the five scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE) for the design of data/mappid.json at one seed (default 30000, the local seed of MapPID;
%   DieuKhien_MapPID.txt H5: ONE local seed this time, the five scoring seeds 99999-99995 come later with run_scoring_seeds). Results in Result/Controllers/MapPID/Cases/.
if nargin < 1, runSeed = 30000; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
M = run_cases('MapPID', runSeed);
Simulink.sdi.clear;
end
