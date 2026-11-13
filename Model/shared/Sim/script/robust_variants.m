function out = robust_variants(name)
%ROBUST_VARIANTS Single source of the Plant-parameter variants of the robustness study (Documents/Shared/KeHoach_DoBenThamSo.txt, section 1).
%
%   names = robust_variants()        cell array of the 17 variant names, 'nom' first, then <Code>p20 and <Code>m20 for the 8 groups
%   A     = robust_variants(name)    cell array {var, value; ...} of base-workspace assignments for the variant. Call it AFTER load_<ctrl>
%                                    has loaded the nominal values into the base workspace; then assign A in the base workspace and run load_derived.
%   groups = robust_variants('groups')   cell array of the 8 group codes
%
%   Every group changes by the same level (+-20 %) of the nominal value:
%     Tf     T_f                      Jcol   J_col                  Ccol   C_col
%     Mass   m and Iz together       Calpha C_alpha_f and C_r together
%     Trail  t_0 with e_c kept (e_p0' = e_c + t_0')       Caster e_c changed with t_0 kept (e_p0' = e_c' + t_0)
%     Motor  motor_wm
%   K, n_st, l_f, l_r, C, E, c, g are not changed.

level = 0.2;
groups = {'Tf', 'Jcol', 'Ccol', 'Mass', 'Calpha', 'Trail', 'Caster', 'Motor'};
if nargin == 0
    out = {'nom'};
    for i = 1:numel(groups), out{end+1} = [groups{i} 'p20']; out{end+1} = [groups{i} 'm20']; end %#ok<AGROW>
    return
end
if strcmp(name, 'groups'), out = groups; return; end
if strcmp(name, 'nom'), out = cell(0, 2); return; end

assert(numel(name) > 3 && any(strcmp(name(end-2:end), {'p20', 'm20'})), 'robust_variants: bad variant name %s', name);
code = name(1:end-3);
f = 1 + level * (2 * strcmp(name(end-2:end), 'p20') - 1);
b = @(v) evalin('base', v);
switch code
    case 'Tf',     out = {'T_f', b('T_f') * f};
    case 'Jcol',   out = {'J_col', b('J_col') * f};
    case 'Ccol',   out = {'C_col', b('C_col') * f};
    case 'Mass',   out = {'m', b('m') * f; 'Iz', b('Iz') * f};
    case 'Calpha', out = {'C_alpha_f', b('C_alpha_f') * f; 'C_r', b('C_r') * f};
    case 'Trail'
        ec = b('e_p0') - b('t_0'); t0 = b('t_0') * f;
        out = {'t_0', t0; 'e_p0', ec + t0};
    case 'Caster'
        ec = (b('e_p0') - b('t_0')) * f;
        out = {'e_p0', ec + b('t_0')};
    case 'Motor',  out = {'motor_wm', b('motor_wm') * f};
    otherwise, error('robust_variants: unknown group %s', code);
end
end
