function m = tk_score(L, S)
%TK_SCORE Scores of the design case TK on logged TRUE signals (QuyChuan.txt part 4). Separate file so that it can be tested without a model.
%
%   m = tk_score(L, S)     L: struct with t, T_s, T_d_ref, e_T, T_a, T_a_cmd on the 1 ms grid of S; S: test_cases('TK')
%   Fields of m: see tk_run.m (R, Rg, RgNm, S, Scmd, TV, maxTa, erel, erelWin, erelSigned, erelLabel, rev). First 2 s are not scored.
    win = S.win; lab = {win.label};
    w = L.t >= 2;
    dt = L.t(2) - L.t(1);
    a = dt / (1 / (2 * pi * 5) + dt);
    grp = {'static', 'dyn', 'small', 'mu'};
    pre = {'static', 'sine', 'small', 'mu'};
    m.Rg = struct(); m.RgNm = struct();
    Rv = zeros(1, 4);
    for g = 1:4
        in = false(size(L.t));
        for j = find(startsWith(lab, pre{g})), in = in | (L.t >= win(j).t0 & L.t <= win(j).t1); end
        m.RgNm.(grp{g}) = sqrt(mean(L.e_T(in).^2));
        Rv(g) = 100 * m.RgNm.(grp{g}) / max(mean(abs(L.T_d_ref(in))), eps);
        m.Rg.(grp{g}) = Rv(g);
    end
    m.R = mean(Rv);
    hp = L.T_a - filter(a, [1 -(1 - a)], L.T_a);
    m.S = sqrt(mean(hp(w).^2));
    hc = L.T_a_cmd - filter(a, [1 -(1 - a)], L.T_a_cmd);
    m.Scmd = sqrt(mean(hc(w).^2));
    m.TV = sum(abs(diff(L.T_a(w)))) / (L.t(end) - 2);
    m.maxTa = max(abs(L.T_a(w)));
    js = find(startsWith(lab, 'static'));
    m.erelLabel = lab(js); m.erelWin = zeros(1, numel(js)); m.erelSigned = zeros(1, numel(js));
    for k = 1:numel(js)
        in = L.t >= win(js(k)).t0 & L.t <= win(js(k)).t1;
        m.erelSigned(k) = 100 * mean(L.e_T(in)) / max(mean(abs(L.T_d_ref(in))), eps);
        m.erelWin(k) = abs(m.erelSigned(k));
    end
    m.erel = max(m.erelWin);
    m.rev = mean(abs(L.T_s(w)) >= 0.5 & L.T_a(w) .* L.T_s(w) < 0);
end
