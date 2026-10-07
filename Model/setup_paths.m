function setup_paths()
%SETUP_PATHS Add every code folder of Model/ to the MATLAB path. The ONE place that knows the folder layout:
%
%   Model/common/              shared helpers (result_dir, save_run_results, sensor_noise_vars)
%   Model/PRSM/<Part>/         environment shared by every controller: Plant, Ref, Sensors, Actuator (load_<part>.m, models; script/ = build_, test_)
%   Model/Sim/script/          shared test frame (build_closed_loop, test_cases, run_test_cases, make_pair_comparisons ...)
%   Model/Controllers/<Ctrl>/  one folder per controller (load_<ctrl>.m, <Ctrl>_s.mdl, Model_<Ctrl>_s.mdl, script/)
%
%   Usage: >> run('<repo>/Model/setup_paths.m')   or, with Model/ already on the path, >> setup_paths

modelDir = fileparts(mfilename('fullpath'));
addpath(modelDir);
addpath(fullfile(modelDir, 'common'));
for part = {'Plant', 'Ref', 'Sensors', 'Actuator'}
    addpath(fullfile(modelDir, 'PRSM', part{1}));
    addpath(fullfile(modelDir, 'PRSM', part{1}, 'script'));
end
addpath(fullfile(modelDir, 'Sim', 'script'));
ctl = dir(fullfile(modelDir, 'Controllers'));
for i = 1:numel(ctl)
    if ctl(i).isdir && ~startsWith(ctl(i).name, '.')
        addpath(fullfile(modelDir, 'Controllers', ctl(i).name));
        if exist(fullfile(modelDir, 'Controllers', ctl(i).name, 'script'), 'dir'), addpath(fullfile(modelDir, 'Controllers', ctl(i).name, 'script')); end
    end
end
end
