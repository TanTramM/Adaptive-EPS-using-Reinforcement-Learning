function inspect_dynsteer_wiring()
%INSPECT_DYNSTEER_WIRING Read-only: wiring of the VDB 'Dynamic Steering' block (R2023a). Where does the assist torque enter, what is in the Info bus,
%   is there a torsion-bar torque signal. Output: Model/VDB/temp_test/Steering/Result/Steering_dynsteer_wiring.txt. No simulation is run.
    scriptDir = fileparts(mfilename('fullpath'));
    outDir = fullfile(fileparts(scriptDir), 'Result');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    fid = fopen(fullfile(outDir, 'Steering_dynsteer_wiring.txt'), 'w');
    cleaner = onCleanup(@() fclose(fid));
    load_system('vehdynlibsteering');
    p = 'vehdynlibsteering/Dynamic Steering';
    dump(fid, p, 'TOP', {'Add', 'Bus Creator', 'Bus Selector', 'Goto', 'Goto1', 'Goto4', 'Goto5', 'Goto6', 'Goto7', 'Goto8', 'Goto9', 'Goto10', 'Goto11', 'Goto12', 'Goto13'});
    subs = {'TrqInertia', 'PowerAssist', 'TrqInertia/Column', 'TrqInertia/Shaft', 'TrqInertia/Backlash1', 'TrqInertia/Friction'};
    for i = 1:numel(subs)
        dump(fid, [p '/' subs{i}], subs{i}, {});
    end
    % what feeds the two sub-blocks at the top level, and every Info bus element
    fprintf(fid, '\n===== TOP connections of the two sub-blocks, From tags, Info bus elements\n');
    for nm = {'PowerAssist', 'TrqInertia', 'AckermanConstantRatio'}
        h = get_param([p '/' nm{1}], 'LineHandles');
        for k = 1:numel(h.Inport)
            if h.Inport(k) < 0, fprintf(fid, '%s in%d <- (none)\n', nm{1}, k); continue; end
            sb = get_param(h.Inport(k), 'SrcBlockHandle');
            fprintf(fid, '%s in%d <- %s {%s}', nm{1}, k, strrep(get_param(sb, 'Name'), newline, ' '), get_param(h.Inport(k), 'Name'));
            if strcmp(get_param(sb, 'BlockType'), 'From'), fprintf(fid, ' tag=%s', get_param(sb, 'GotoTag')); end
            fprintf(fid, '\n');
        end
    end
    fr = find_system(p, 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'From');
    for i = 1:numel(fr), fprintf(fid, 'From %-8s tag=%s\n', get_param(fr{i}, 'Name'), get_param(fr{i}, 'GotoTag')); end
    bc = find_system(p, 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'BusCreator');
    for i = 1:numel(bc)
        h = get_param(bc{i}, 'LineHandles');
        names = cell(1, numel(h.Inport));
        for k = 1:numel(h.Inport), names{k} = get_param(h.Inport(k), 'Name'); end
        fprintf(fid, 'BusCreator %s: %s\n', strrep(get_param(bc{i}, 'Name'), newline, ' '), strjoin(names, ', '));
    end
    disp(fileread(fullfile(outDir, 'Steering_dynsteer_wiring.txt')));
end

function dump(fid, sys, label, onlyNames)
    fprintf(fid, '\n===== %s\n', label);
    b = find_system(sys, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'Type', 'Block');
    for i = 1:numel(b)
        if strcmp(b{i}, sys), continue; end
        nm = strrep(get_param(b{i}, 'Name'), newline, ' ');
        bt = get_param(b{i}, 'BlockType');
        if ~isempty(onlyNames) && ~ismember(nm, onlyNames) && ~strcmp(bt, 'Sum') && ~strcmp(bt, 'BusCreator') && ~strcmp(bt, 'BusSelector'), continue; end
        if any(strcmp(bt, {'SignalSpecification', 'Terminator'})), continue; end
        extra = '';
        switch bt
            case 'Sum', extra = ['signs=' get_param(b{i}, 'Inputs')];
            case 'Gain', extra = ['gain=' get_param(b{i}, 'Gain')];
            case 'Constant', extra = ['value=' get_param(b{i}, 'Value')];
            case {'Goto', 'From'}, extra = ['tag=' get_param(b{i}, 'GotoTag')];
            case 'Product', extra = ['inputs=' get_param(b{i}, 'Inputs')];
            case 'Saturate', extra = ['up=' get_param(b{i}, 'UpperLimit') ' lo=' get_param(b{i}, 'LowerLimit')];
            case 'Integrator', extra = ['ic=' get_param(b{i}, 'InitialCondition')];
        end
        srcs = '';
        try
            lh = get_param(b{i}, 'LineHandles');
            for k = 1:numel(lh.Inport)
                if lh.Inport(k) < 0, srcs = [srcs ' <-(none)']; continue; end %#ok<AGROW>
                sb = get_param(lh.Inport(k), 'SrcBlockHandle');
                ln = get_param(lh.Inport(k), 'Name');
                if sb < 0, srcs = [srcs ' <-?']; else, srcs = [srcs ' <-' strrep(get_param(sb, 'Name'), newline, ' ') '{' ln '}']; end %#ok<AGROW>
            end
        catch
        end
        fprintf(fid, '%-22s %-14s %-28s %s\n', nm, bt, extra, srcs);
    end
end
