function names = build_vdb_io(overwrite)
%BUILD_VDB_IO Build the two stand-alone analysis models of plan section 12 (interface test of the VDB blocks), one block per model:
%   VDBBody.mdl : 'Vehicle Body 3DOF Single Track', configured by vdb_body_config.m
%   VDBTire.mdl : 'Combined Slip Wheel 2DOF' (front half axle, Plant-matched Magic Formula), configured by vdb_tire_config.m
%   Every input port is fed by a From Workspace block (variable in_<port>, a timeseries; defaults are created in the base workspace by
%   load_vdb_io_defaults.m so that the model runs as it is). Every output port goes to a To Workspace block (variable out_<port>, timeseries).
%   The Info bus is NOT logged whole (an 11.7 GB run was seen): a Bus Selector picks only the fields of the interface ledger, each to a To Workspace
%   block (variable info_<field>). overwrite = false (default) never overwrites: an existing name gets _1, _2, ...
    if nargin < 1, overwrite = false; end
    scriptDir = fileparts(mfilename('fullpath'));
    analyzeDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(analyzeDir));
    addpath(modelDir); setup_paths;
    addpath(fullfile(modelDir, 'PRSM_VDB', 'Plant_VDB', 'script'));
    use_sim_tmp;
    load_plant;
    P = load_vdb_params(modelDir);
    load_system('vehdynlibeom'); load_system('vehdynlibtire');
    names = {build_one('VDBBody', 'vehdynlibeom/Vehicle Body 3DOF Single Track', analyzeDir, overwrite, P), ...
             build_one('VDBTire', 'vehdynlibtire/Combined Slip Wheel 2DOF', analyzeDir, overwrite, P)};
    fprintf('Built: %s\n', strjoin(names, ', '));
end

function name = build_one(base, lib, analyzeDir, overwrite, P)
    name = base; k = 0;
    if ~overwrite
        while exist(fullfile(analyzeDir, [name '.mdl']), 'file'), k = k + 1; name = sprintf('%s_%d', base, k); end
    end
    if bdIsLoaded(name), close_system(name, 0); end
    new_system(name);
    blk = [name '/' base]; add_block(lib, blk, 'Position', [400 100 560 100 + 30 * 10]);
    if strcmp(base, 'VDBBody')
        vdb_body_config(blk, struct('m', 'm', 'a', 'l_f', 'b', 'l_r', 'Iz', 'Iz'), 20);
        infoFields = {'BdyFrm.Cg.Acc.ay', 'ay'; 'BdyFrm.Cg.Ang.Beta', 'Beta'; 'BdyFrm.Forces.Ext.Fx', 'ExtFx'; 'BdyFrm.Forces.Ext.Fy', 'ExtFy'; ...
                      'BdyFrm.Forces.Ext.Fz', 'ExtFz'; 'BdyFrm.Moments.Ext.Mx', 'ExtMx'; 'BdyFrm.Moments.Ext.My', 'ExtMy'; 'BdyFrm.Moments.Ext.Mz', 'ExtMz'};
    else
        vdb_tire_config(blk, P, 'front', 20);
        infoFields = {'Alpha', 'Alpha'; 'Kappa', 'Kappa'};
    end
    ph = get_param(blk, 'PortHandles');
    inNames = portNames(blk, 'Inport'); outNames = portNames(blk, 'Outport');
    y0 = 60;
    for i = 1:numel(inNames)
        fw = sprintf('%s/From_%s', name, inNames{i});
        add_block('simulink/Sources/From Workspace', fw, 'VariableName', ['in_' inNames{i}], 'Interpolate', 'on', ...
            'OutputAfterFinalValue', 'Holding final value', 'Position', [60 y0 + 60 * (i - 1) 190 y0 + 60 * (i - 1) + 30]);
        add_line(name, get_param(fw, 'PortHandles').Outport(1), ph.Inport(i));
    end
    y1 = 60; bsDone = false;
    for i = 1:numel(outNames)
        if strcmp(outNames{i}, 'Info')
            bs = [name '/BusSel_Info'];
            add_block('simulink/Signal Routing/Bus Selector', bs, 'Position', [650 y1 + 60 * (i - 1) 655 y1 + 60 * (i - 1) + 40 + 14 * size(infoFields, 1)]);
            add_line(name, ph.Outport(i), get_param(bs, 'PortHandles').Inport(1));
            set_param(bs, 'OutputSignals', strjoin(infoFields(:, 1)', ','));
            bph = get_param(bs, 'PortHandles');
            for j = 1:size(infoFields, 1)
                tw = sprintf('%s/ToWs_info_%s', name, infoFields{j, 2});
                add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['info_' infoFields{j, 2}], 'SaveFormat', 'Timeseries', ...
                    'Position', [760 y1 + 60 * (i - 1) + 30 * (j - 1) 900 y1 + 60 * (i - 1) + 30 * (j - 1) + 20]);
                add_line(name, bph.Outport(j), get_param(tw, 'PortHandles').Inport(1));
            end
            bsDone = true;
        else
            tw = sprintf('%s/ToWs_%s', name, outNames{i});
            yy = 60 + 60 * (i - 1) + 30 * (bsDone * size(infoFields, 1));
            add_block('simulink/Sinks/To Workspace', tw, 'VariableName', ['out_' outNames{i}], 'SaveFormat', 'Timeseries', ...
                'Position', [760 yy 900 yy + 20]);
            add_line(name, ph.Outport(i), get_param(tw, 'PortHandles').Inport(1));
        end
    end
    set_param(name, 'Solver', 'VariableStepAuto', 'MaxStep', '0.002', 'RelTol', '1e-6', 'StopTime', '10', 'ReturnWorkspaceOutputs', 'off');
    save_system(name, fullfile(analyzeDir, [name '.mdl']));
    close_system(name, 0);
end

function n = portNames(blk, kind)
    b = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', kind);
    idx = cellfun(@(x) str2double(get_param(x, 'Port')), b);
    [~, o] = sort(idx); b = b(o);
    n = cellfun(@(x) get_param(x, 'Name'), b, 'UniformOutput', false);
end
