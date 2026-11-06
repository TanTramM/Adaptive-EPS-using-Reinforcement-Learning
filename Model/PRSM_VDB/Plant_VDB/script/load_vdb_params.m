function P = load_vdb_params(modelDir)
%LOAD_VDB_PARAMS Plant parameters needed by the Plant_VDB tests, read straight from params.json (no hand-typed numbers).
%   Fields: m, a (= l_f), b (= l_r), g, Iz, Ca (axle cornering stiffness, N/rad), C, E (Magic Formula), n (steering ratio), ep0, t0, ec = ep0 - t0,
%   Fzf, Fzr (static axle loads, N).
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    P = struct('m', raw.cum2.m.value, 'a', raw.cum2.l_f.value, 'b', raw.cum2.l_r.value, 'g', raw.cum2.g.value, 'Iz', raw.cum3.Iz.value, ...
        'Ca', raw.cum2.C_alpha_f.value, 'C', raw.cum2.C.value, 'E', raw.cum2.E.value, 'n', raw.cum2.n_st.value, ...
        'ep0', raw.cum2.e_p0.value, 't0', raw.cum2.t_0.value);
    P.ec = P.ep0 - P.t0;
    P.Fzf = P.m * P.g * P.b / (P.a + P.b);
    P.Fzr = P.m * P.g * P.a / (P.a + P.b);
end
