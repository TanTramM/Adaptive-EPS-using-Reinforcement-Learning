function run_scoring_seeds(ctrlName, seeds, set)
%RUN_SCORING_SEEDS Run the scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE) of ONE controller on several noise seeds, for the statistics of the paper.
%
%   run_scoring_seeds('Map', [99998 99997 99996 99995])
%
%   Calls run_cases(ctrlName, seed) once per seed (every controller sees the same noise sequence for the same seed, QuyChuan 6.1) and writes
%   Result/Controllers/<ctrl>/Cases/<ctrl>_metrics_s<seed>.csv as usual. Resumable: a seed whose metrics file exists is skipped.
%   Run load_<ctrl> in the base workspace first. Simulink.sdi.clear after every seed (the Simulation Data Inspector otherwise fills
%   %TEMP% and the RAM); start MATLAB with TEMP and TMP on the D drive.

if nargin < 3 || isempty(set), set = 'V3'; end                      % DREWS v3 (Cases_v3/) by default; 'V2' = Cases_v2/, 'V1' = the old set (Cases/)
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
for s = seeds(:)'
    f = fullfile(result_dir(ctrlName, setToken(set)), sprintf('%s_metrics_%s.csv', ctrlName, sensor_tag(s)));
    if isfile(f)
        fprintf('run_scoring_seeds: %s seed %d exists, skipped\n', ctrlName, s);
        continue
    end
    t0 = tic;
    run_cases(ctrlName, s, set);
    Simulink.sdi.clear;
    fprintf('run_scoring_seeds: %s seed %d done in %.0f s\n', ctrlName, s, toc(t0));
end
end

function t = setToken(set)
    switch set
        case 'V1', t = 'Cases';
        case 'V2', t = 'CasesV2';
        case 'SLIP4', t = 'CasesSLIP4';
        case 'SSW', t = 'CasesSSW';
        otherwise, t = 'CasesV3';
    end
end
