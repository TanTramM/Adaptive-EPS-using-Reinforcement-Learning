function setup_paths()
%SETUP_PATHS Add every code folder of Model/ to the MATLAB path. The ONE place that knows the folder layout:
%
%   Model/common/              shared helpers (result_dir, save_run_results, sensor_noise_vars)
%   Model/PRSM/<Part>/         environment shared by every controller: Plant, Ref, Sensors, AssistLimit, Actuator (load_<part>.m, models; script/ = build_, test_)
%   Model/PRSM_VDB/Plant_VDB/  Plant built from Vehicle Dynamics Blockset blocks (plug-in replacement of PRSM/Plant, same 4 inputs and 4 outputs; script/ = build_, test_, run_, check_)
%   Model/Sim/script/          shared test frame (build_closed_loop, make_cases, run_cases, make_pair_comparisons ...)
%   Model/Controllers/<Ctrl>/  one folder per controller (load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl, script/)
%
%   Usage: >> run('<repo>/Model/setup_paths.m')   or, with Model/ already on the path, >> setup_paths

modelDir = fileparts(mfilename('fullpath'));
addpath(modelDir);
addpath(fullfile(modelDir, 'common'));
for part = {'Plant', 'Ref', 'Sensors', 'AssistLimit', 'Actuator'}
    addpath(fullfile(modelDir, 'PRSM', part{1}));
    addpath(fullfile(modelDir, 'PRSM', part{1}, 'script'));
end
% PRSM_VDB: the same environment with the Plant replaced by a Vehicle Dynamics Blockset (VDB) plant (Plant_VDB); Ref, Sensors, AssistLimit, Actuator are shared with PRSM
if exist(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB'), 'dir')
    addpath(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB'));
    addpath(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB', 'script'));
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
