function sc = calib_block_scores(L, S, blocks)
%CALIB_BLOCK_SCORES Scores of the design case CALIB v2 per speed block (S.blk: nine blocks 20, 30, ..., 100 km/h, make_cases.m).
%
%   sc = calib_block_scores(L, S, [20 60 100])      L: logged signals of calib_run.m, S: make_cases('CALIB')
%   sc.R     response error of the block [%]: geometric mean of the group errors (static, dyn, mu; floor 1 %) over the windows of each group that the
%            block contains (the mu group only exists in the 60 km/h block); same definition as calib_score.m
%   sc.S     RMS of T_a high-passed at 5 Hz over the block (first 2 s of the case not scored) [N.m]
%   sc.TV    total variation of T_a per second over the block [N.m/s]
%   sc.erel  steady accuracy of the block: worst |mean e_T| / mean |T_d,ref| over its static windows [%]
R_FLOOR = 1;
dt = L.t(2) - L.t(1); a = dt / (1 / (2 * pi * 5) + dt);
hp = L.T_a - filter(a, [1 -(1 - a)], L.T_a);
nb = numel(blocks);
sc = struct('R', zeros(1, nb), 'S', zeros(1, nb), 'TV', zeros(1, nb), 'erel', zeros(1, nb));
lab = {S.win.label};
pre = {{'static'}, {'trans', 'sine'}, {'mu'}};
for b = 1:nb
    kb = find([S.blk.speed] == blocks(b), 1);
    T0 = S.blk(kb).t0; T1 = S.blk(kb).t1;
    inb = L.t >= max(T0, 2) & L.t < T1;
    inBlk = [S.win.t0] >= T0 - 1e-9 & [S.win.t1] <= T1 + 1e-9;
    Rv = [];
    for g = 1:3
        js = find(startsWith(lab, pre{g}) & inBlk);
        if isempty(js), continue; end
        in = false(size(L.t));
        for j = js, in = in | (L.t >= S.win(j).t0 & L.t <= S.win(j).t1); end
        Rv(end+1) = 100 * sqrt(mean(L.e_T(in).^2)) / max(mean(abs(L.T_d_ref(in))), eps); %#ok<AGROW>
    end
    sc.R(b) = exp(mean(log(max(Rv, R_FLOOR))));
    sc.S(b) = sqrt(mean(hp(inb).^2));
    sc.TV(b) = sum(abs(diff(L.T_a(inb)))) / (nnz(inb) * dt);
    er = [];
    for j = find(startsWith(lab, 'static') & inBlk)
        in = L.t >= S.win(j).t0 & L.t <= S.win(j).t1;
        er(end+1) = 100 * abs(mean(L.e_T(in))) / max(mean(abs(L.T_d_ref(in))), eps); %#ok<AGROW>
    end
    sc.erel(b) = max(er);
end
end
