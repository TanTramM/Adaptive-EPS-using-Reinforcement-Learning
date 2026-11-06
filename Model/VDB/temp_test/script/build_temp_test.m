function names = build_temp_test(overwrite, onlyTags)
%BUILD_TEMP_TEST Temporary closed loops for the step-by-step replacement: for each controller (Map, PID, MapPID) the ORIGINAL closed loop Model_<Ctrl>.mdl with only its
%   Plant block replaced by one of the three VDB Plants of Model/VDB/Plants. Saved in Model/VDB/temp_test/<Ctrl>/ as
%     Model_<Ctrl>_VDBTire.slx      Plant_VDBTire      (only Tires replaced)
%     Model_<Ctrl>_VDBBody.slx      Plant_VDBBody      (only Bike2DOF replaced)
%     Model_<Ctrl>_VDBTireBody.slx  Plant_VDBTireBody  (both replaced)
%     Model_<Ctrl>_VDBTireLag.slx   Plant_VDBTireLag   (Tires replaced, with the real lateral relaxation length; step 1 of the realism steps, 2026-11-07)
%     Model_<Ctrl>_VDBTireLagMz.slx Plant_VDBTireLagMz (as VDBTireLag, and T_r from the tire aligning moment Mz with fitted trail coefficients; step 2, 2026-11-07)
%   names = build_temp_test(overwrite)   overwrite = false (default) never overwrites: an existing name gets _1, _2, ...
%   Everything else is the original loop (Reference, Sensors, AssistLimit, Actuator, the controller block, scoring blocks, wiring), so the controller parameters are the ones of
%   the original models (data/map.json, pid.json, mappid.json through load_<ctrl>.m). The original Model_<Ctrl>.mdl is only read. StopFcn is cleared so that a manual run
%   does not write into the results of the original controller. Run load_<ctrl> and load_plant_vdb before simulating (smoke_temp_test.m does).
    if nargin < 1, overwrite = false; end
    if nargin < 2, onlyTags = {}; end              % e.g. {'VDBTireLag'}: build only these variants
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    vdbDir = fileparts(tempDir);
    modelDir = fileparts(vdbDir);
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    load_plant_vdb;
    ctrls = {'Map', 'PID', 'MapPID'};
    plants = {'Plant_VDBTire', 'Plant_VDBBody', 'Plant_VDBTireBody', 'Plant_VDBTireLag', 'Plant_VDBTireLagMz'};
    tags = {'VDBTire', 'VDBBody', 'VDBTireBody', 'VDBTireLag', 'VDBTireLagMz'};
    for p = 1:numel(plants), load_system(fullfile(vdbDir, 'Plants', [plants{p} '.slx'])); end
    load_system('vehdynlibtire'); load_system('vehdynlibeom');
    names = {};
    for c = 1:numel(ctrls)
        src = fullfile(modelDir, 'original', 'Controllers', ctrls{c}, ['Model_' ctrls{c} '.mdl']);
        outDir = fullfile(tempDir, ctrls{c}); if ~exist(outDir, 'dir'), mkdir(outDir); end
        for p = 1:numel(plants)
            if ~isempty(onlyTags) && ~any(strcmp(onlyTags, tags{p})), continue; end
            base = ['Model_' ctrls{c} '_' tags{p}]; n = base; k = 0;
            if ~overwrite
                while exist(fullfile(outDir, [n '.slx']), 'file'), k = k + 1; n = sprintf('%s_%d', base, k); end
            end
            if bdIsLoaded(n), close_system(n, 0); end
            if bdIsLoaded(['Model_' ctrls{c}]), close_system(['Model_' ctrls{c}], 0); end
            load_system(src);
            save_system(['Model_' ctrls{c}], fullfile(outDir, [n '.slx']));            % save as: the loaded model is renamed n, the original file is untouched
            inner = [n '/Model_' ctrls{c}];
            old = [inner '/Plant'];
            assert(strcmp(get_param(old, 'BlockType'), 'SubSystem'), 'Plant block not found in %s', inner);
            replace_block(inner, 'Name', 'Plant', [plants{p} '/' plants{p}], 'noprompt');
            % every port of the new Plant block must be connected (same ports as the original Plant)
            ph = get_param([inner '/Plant'], 'PortHandles');
            ln = [cell2mat(get_param(ph.Inport(:), 'Line')); cell2mat(get_param(ph.Outport(:), 'Line'))];
            assert(numel(ph.Inport) == 4 && numel(ph.Outport) == 4 && all(ln > 0), 'unconnected port of Plant in %s', n);
            set_param(n, 'StopFcn', '');
            save_system(n); close_system(n, 0);
            names{end + 1} = n; %#ok<AGROW>
        end
    end
    for p = 1:numel(plants), close_system(plants{p}, 0); end
    fprintf('Built %d models in %s\n', numel(names), tempDir);
end
