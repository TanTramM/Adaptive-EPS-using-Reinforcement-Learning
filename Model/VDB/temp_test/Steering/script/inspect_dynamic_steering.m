function inspect_dynamic_steering()
%INSPECT_DYNAMIC_STEERING Read-only look at the Vehicle Dynamics Blockset block 'Dynamic Steering' (R2023a): ports, dialog options, inner structure.
%   Question to answer before any use as an independent steering-system reference (2026-11-10):
%     1. does it output the torsion-bar (steering column) torque T_s?
%     2. can the built-in assist be replaced by an external motor torque T_a?
%     3. units and signs of the ports.
%   Output: Model/VDB/temp_test/Steering/Result/Steering_dynsteer_inspect.txt. No simulation is run.
    scriptDir = fileparts(mfilename('fullpath'));
    steerDir = fileparts(scriptDir);
    outDir = fullfile(steerDir, 'Result');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    fid = fopen(fullfile(outDir, 'Steering_dynsteer_inspect.txt'), 'w');
    cleaner = onCleanup(@() fclose(fid));
    load_system('vehdynlibsteering');
    p = 'vehdynlibsteering/Dynamic Steering';
    fprintf(fid, 'MATLAB %s, block %s\n\n', version, p);
    fprintf(fid, '--- mask description\n%s\n\n', get_param(p, 'MaskDescription'));
    fprintf(fid, '--- mask type, help, display text\n%s\n%s\n\n', get_param(p, 'MaskType'), get_param(p, 'MaskDisplay'));
    % dialog parameters: name, prompt, value, options
    dp = get_param(p, 'DialogParameters');
    names = fieldnames(dp);
    fprintf(fid, '--- dialog parameters (%d)\n', numel(names));
    for i = 1:numel(names)
        s = dp.(names{i});
        opt = '';
        if isfield(s, 'TypeOptions') && ~isempty(s.TypeOptions), opt = strjoin(s.TypeOptions, ','); end
        try, v = get_param(p, names{i}); catch, v = '?'; end
        fprintf(fid, '%-14s | %-45s | value=%s | opts=%s\n', names{i}, s.Prompt, v, opt);
    end
    % top-level ports of the library block
    ph = get_param(p, 'PortHandles');
    fprintf(fid, '\n--- port counts: in=%d out=%d\n', numel(ph.Inport), numel(ph.Outport));
    ib = find_system(p, 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'Inport');
    ob = find_system(p, 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'Outport');
    for i = 1:numel(ib), fprintf(fid, 'IN  %s (port %s)\n', get_param(ib{i}, 'Name'), get_param(ib{i}, 'Port')); end
    for i = 1:numel(ob), fprintf(fid, 'OUT %s (port %s)\n', get_param(ob{i}, 'Name'), get_param(ob{i}, 'Port')); end
    % inner blocks (names only) down to depth 2
    fprintf(fid, '\n--- inner blocks, depth 1 and 2\n');
    b = find_system(p, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 2, 'Type', 'Block');
    for i = 1:numel(b)
        fprintf(fid, '%s | %s\n', strrep(b{i}, [p '/'], ''), get_param(b{i}, 'BlockType'));
    end
    disp(fileread(fullfile(outDir, 'Steering_dynsteer_inspect.txt')));
end
