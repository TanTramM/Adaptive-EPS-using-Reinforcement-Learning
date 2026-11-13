function ok = check_robust_variables()
%CHECK_ROBUST_VARIABLES Check R0 of KeHoach_DoBenThamSo.txt: the variables of every variant, no simulation.
%   Loads the nominal values from data/params.json and actuator.json independently, applies each variant through the same path the run uses
%   (load_map, assign, load_derived), and compares with the expected values. Writes Result/Compare/Robust/Robust_R0_variables.txt.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(fullfile(modelDir, 'shared')); setup_paths;

raw = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'params.json')));
nomv = struct();
for blk = {'cum1', 'cum2', 'cum3'}
    fn = fieldnames(raw.(blk{1}));
    for i = 1:numel(fn)
        if isfield(raw.(blk{1}).(fn{i}), 'value'), nomv.(fn{i}) = raw.(blk{1}).(fn{i}).value; end
    end
end
act = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'actuator.json')));
nomv.motor_wm = 2 * pi * act.fm.value;
nomv.F_zf = nomv.m * nomv.g * nomv.l_r / (nomv.l_f + nomv.l_r);
nomv.F_zr = nomv.m * nomv.g * nomv.l_f / (nomv.l_f + nomv.l_r);
nomv.e_c = nomv.e_p0 - nomv.t_0;

vars = {'T_f', 'J_col', 'C_col', 'm', 'Iz', 'C_alpha_f', 'C_r', 't_0', 'e_p0', 'e_c', 'motor_wm', 'F_zf', 'F_zr'};
names = robust_variants();
outDir = fullfile(fileparts(fileparts(modelDir)), 'Result', 'Compare', 'Robust');
if ~isfolder(outDir), mkdir(outDir); end
lines = {sprintf('R0 robust variables, %s', datestr(now, 'yyyy-mm-dd HH:MM')), ...
         sprintf('%-10s %s', 'variant', strjoin(cellfun(@(s) sprintf('%12s', s), vars, 'UniformOutput', false), ' '))};
ok = true;
for k = 1:numel(names)
    evalin('base', 'clear all_dummy_never'); %#ok<*EVLC>
    evalin('base', 'load_map;');
    A = robust_variants(names{k});
    for j = 1:size(A, 1), assignin('base', A{j, 1}, A{j, 2}); end
    evalin('base', 'load_derived;');
    got = struct(); for i = 1:numel(vars), got.(vars{i}) = evalin('base', vars{i}); end
    % expected values, from the independent nominal copy
    ex = nomv; code = names{k}; f = 1;
    if ~strcmp(code, 'nom'), f = 1 + 0.2 * (2 * strcmp(code(end-2:end), 'p20') - 1); code = code(1:end-3); end
    switch code
        case 'Tf', ex.T_f = nomv.T_f * f;
        case 'Jcol', ex.J_col = nomv.J_col * f;
        case 'Ccol', ex.C_col = nomv.C_col * f;
        case 'Mass', ex.m = nomv.m * f; ex.Iz = nomv.Iz * f; ex.F_zf = nomv.F_zf * f; ex.F_zr = nomv.F_zr * f;
        case 'Calpha', ex.C_alpha_f = nomv.C_alpha_f * f; ex.C_r = nomv.C_r * f;
        case 'Trail', ex.t_0 = nomv.t_0 * f; ex.e_p0 = nomv.e_c + ex.t_0; ex.e_c = nomv.e_c;
        case 'Caster', ex.e_c = nomv.e_c * f; ex.e_p0 = ex.e_c + nomv.t_0;
        case 'Motor', ex.motor_wm = nomv.motor_wm * f;
    end
    bad = {};
    for i = 1:numel(vars)
        if abs(got.(vars{i}) - ex.(vars{i})) / abs(ex.(vars{i})) >= 1e-12, bad{end+1} = vars{i}; end %#ok<AGROW>
    end
    lines{end+1} = sprintf('%-10s %s %s', names{k}, strjoin(arrayfun(@(i) sprintf('%12.6g', got.(vars{i})), 1:numel(vars), 'UniformOutput', false), ' '), ...
        ternary(isempty(bad), 'OK', ['FAIL: ' strjoin(bad, ',')])); %#ok<AGROW>
    if ~isempty(bad), ok = false; end
end
lines{end+1} = ternary(ok, '[check_robust_variables] R0 PASS (all variables within 1e-12 of the independent expectation)', '[check_robust_variables] R0 FAIL');
fid = fopen(fullfile(outDir, 'Robust_R0_variables.txt'), 'w'); fprintf(fid, '%s\n', lines{:}); fclose(fid);
fprintf('%s\n', lines{:});
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
