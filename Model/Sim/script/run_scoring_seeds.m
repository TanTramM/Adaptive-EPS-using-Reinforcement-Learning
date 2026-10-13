function run_scoring_seeds(ctrlName, seeds)
%RUN_SCORING_SEEDS Run the scoring cases (DRY, RAMP, SLIP, WEAVE, EDGE) of ONE controller on several noise seeds, for the statistics of the paper.
%
%   run_scoring_seeds('Map', [99998 99997 99996 99995])
%
%   Calls run_cases(ctrlName, seed) once per seed (every controller sees the same noise sequence for the same seed, QuyChuan 6.1) and writes
%   Result/Controllers/<ctrl>/Cases/<ctrl>_metrics_s<seed>.csv as usual. Resumable: a seed whose metrics file exists is skipped.
%   Run load_<ctrl> in the base workspace first. Simulink.sdi.clear after every seed (the Simulation Data Inspector otherwise fills
%   %TEMP% and the RAM); start MATLAB with TEMP and TMP on the D drive.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
for s = seeds(:)'
    f = fullfile(result_dir(ctrlName, 'Cases'), sprintf('%s_metrics_%s.csv', ctrlName, sensor_tag(s)));
    if isfile(f)
        fprintf('run_scoring_seeds: %s seed %d exists, skipped\n', ctrlName, s);
        continue
    end
    t0 = tic;
    run_cases(ctrlName, s);
    Simulink.sdi.clear;
    fprintf('run_scoring_seeds: %s seed %d done in %.0f s\n', ctrlName, s, toc(t0));
end
end
