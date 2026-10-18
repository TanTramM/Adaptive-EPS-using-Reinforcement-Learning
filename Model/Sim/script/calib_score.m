function m = calib_score(L, S)
%CALIB_SCORE Scores of the design case CALIB v2 on logged TRUE signals (QuyChuan.txt part 4). Separate file so that it can be tested without a model.
%
%   m = calib_score(L, S)     L: struct with t, T_s, T_d_ref, e_T, T_a, T_a_cmd on the 1 ms grid of S; S: make_cases('CALIB')
%   Groups of windows (labels, make_cases.m buildCALIB):
%     static  static_*          steady cornering, the last 1 s of each level of the staircase
%     dyn     trans_*, sine_*   the transient of each level (ramp + 1 s) and the sine through 0 (0.5 Hz and 1 Hz)
%     mu      mu_drop, mu_rise  the 2 s after each mu step
%   R_g = 100 RMS(e_T) / mean|T_d,ref| over the windows of group g (m.Rg.<g> in %, m.RgNm.<g> the RMS in N.m).
%   R = geometric mean of the three group errors, each floored at 1 % (R_FLOOR): a 10 % better group counts the same however large it is, and no
%   group below the resolution of the sensors (T_s step 0.01 N.m, a_y step 0.01 g, about 1 % of T_d,ref) can dominate by shrinking further.
%   Other fields: S (RMS of T_a high-passed at 5 Hz, scored from 2 s), Scmd (the same for T_a_cmd), TV (total variation of T_a per second),
%   maxTa, erel (worst |mean e_T| / mean|T_d,ref| over the static windows [%]; per window erelWin, signed erelSigned, labels erelLabel),
%   rev (fraction of scored samples with |T_s| >= 0.5 N.m and T_a against T_s). eextSigned and eextLabel are kept empty (no window above 0.3 g).
%   EREL_DEN_FLOOR (N.m) floors the denominator of e_rel; 0 = off (QuyChuan 5.3: a floor of 1.2 N.m = a gate of 0.06 N.m at 5 % is under discussion).
    R_FLOOR = 1; EREL_DEN_FLOOR = 0;
    win = S.win; lab = {win.label};
    w = L.t >= 2;
    dt = L.t(2) - L.t(1);
    a = dt / (1 / (2 * pi * 5) + dt);
    grp = {'static', 'dyn', 'mu'};
    pre = {{'static'}, {'trans', 'sine'}, {'mu'}};
    m.Rg = struct(); m.RgNm = struct();
    Rv = zeros(1, 3);
    for g = 1:3
        in = false(size(L.t));
        for j = find(startsWith(lab, pre{g})), in = in | (L.t >= win(j).t0 & L.t <= win(j).t1); end
        m.RgNm.(grp{g}) = sqrt(mean(L.e_T(in).^2));
        Rv(g) = 100 * m.RgNm.(grp{g}) / max(mean(abs(L.T_d_ref(in))), eps);
        m.Rg.(grp{g}) = Rv(g);
    end
    m.R = exp(mean(log(max(Rv, R_FLOOR))));
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
        m.erelSigned(k) = 100 * mean(L.e_T(in)) / max(mean(abs(L.T_d_ref(in))), max(EREL_DEN_FLOOR, eps));
        m.erelWin(k) = abs(m.erelSigned(k));
    end
    m.erel = max(m.erelWin);
    m.eextLabel = {}; m.eextSigned = zeros(1, 0);
    m.rev = mean(abs(L.T_s(w)) >= 0.5 & L.T_a(w) .* L.T_s(w) < 0);
end
