function setup_paths()
%SETUP_PATHS Add every code folder of Model/ to the MATLAB path. The ONE place that knows the folder layout (restructured 2026-11-06):
%
%   Model/shared/              used by BOTH original and VDB
%     setup_paths.m            this file
%     common/                  shared helpers (result_dir, save_run_results, sensor_noise_vars, pick_by_*, select_*)
%     data/                    every .json (single source of data: params, ref, sensors, actuator, map, pid, mappid ...)
%     Sim/                     shared test frame: Gates.mdl, script/ (build_closed_loop, make_cases, run_cases, calib_*, make_pair_comparisons ...)
%   Model/original/            the models of the paper (Plant with the Pacejka tires and the 2DOF bicycle)
%     PRSM/<Part>/             environment shared by every controller: Plant, Ref, Sensors, AssistLimit, Actuator (load_<part>.m, models; script/ = build_, test_)
%     Controllers/<Ctrl>/      one folder per controller (load_<ctrl>.m, <Ctrl>.mdl, Model_<Ctrl>.mdl, script/)
%   Model/VDB/                 the same structure with Vehicle Dynamics Blockset (VDB) parts
%     Blocks/                  VDB blocks with the same ports as the original block they replace: Tires_VDB (for Tires), Body3DOF_VDB (for Bike2DOF)
%     Plants/                  Plant_VDBTire, Plant_VDBBody, Plant_VDBTireBody = the original Plant with only the named blocks replaced; load_plant_vdb.m, script/
%     Blocks/script/           helpers of the VDB blocks: vdb_tire_config, vdb_body_config, load_vdb_params, use_sim_tmp, make_plant_baseline
%     Archive/                 earlier trial plants (S1, S2, S3, VDBDemo) and their check_ scripts; kept to look things up, not on the path
%
%   Usage: >> run('<repo>/Model/shared/setup_paths.m')   or, with Model/shared already on the path, >> setup_paths

sharedDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(sharedDir);                                    % Model/
addpath(sharedDir);
addpath(fullfile(sharedDir, 'common'));
for part = {'Plant', 'Ref', 'Sensors', 'AssistLimit', 'Actuator', 'Driver'}
    addpath(fullfile(rootDir, 'original', 'PRSM', part{1}));
    addpath(fullfile(rootDir, 'original', 'PRSM', part{1}, 'script'));
end
% VDB: the same environment with VDB parts; Ref, Sensors, AssistLimit, Actuator are shared with original/PRSM
if exist(fullfile(rootDir, 'VDB', 'Blocks', 'script'), 'dir')
    addpath(fullfile(rootDir, 'VDB', 'Blocks', 'script'));
end
% VDB/Blocks (VDB blocks that replace original blocks, same ports) and VDB/Plants (the Plant with some blocks replaced; load_plant_vdb.m, script/)
for d = {'Blocks', 'Plants'}
    if exist(fullfile(rootDir, 'VDB', d{1}), 'dir'), addpath(fullfile(rootDir, 'VDB', d{1})); end
end
if exist(fullfile(rootDir, 'VDB', 'Plants', 'script'), 'dir'), addpath(fullfile(rootDir, 'VDB', 'Plants', 'script')); end
addpath(fullfile(sharedDir, 'Sim', 'script'));
ctl = dir(fullfile(rootDir, 'original', 'Controllers'));
for i = 1:numel(ctl)
    if ctl(i).isdir && ~startsWith(ctl(i).name, '.')
        addpath(fullfile(rootDir, 'original', 'Controllers', ctl(i).name));
        if exist(fullfile(rootDir, 'original', 'Controllers', ctl(i).name, 'script'), 'dir'), addpath(fullfile(rootDir, 'original', 'Controllers', ctl(i).name, 'script')); end
    end
end
end
