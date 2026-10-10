function P = map_params()
%MAP_PARAMS Plant parameters straight from data/params.json (independent of the base workspace), for the Map design scripts.
%   P.K, J_col, C_col, T_f, c (steering column), m, l_f, l_r, n_st, C, E, C_alpha_f, C_r, e_p0, t_0, g (tires and body), Iz (yaw inertia),
%   and the static axle loads F_zf = m*g*l_r/L, F_zr = m*g*l_f/L with L = l_f + l_r.
modelDir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));   % Model/ (this file is Model/Controllers/Map/script/)
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn)
        P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
    end
end
P.Iz = raw.cum3.Iz.value;
L = P.l_f + P.l_r;
P.F_zf = P.m * P.g * P.l_r / L;
P.F_zr = P.m * P.g * P.l_f / L;
end
