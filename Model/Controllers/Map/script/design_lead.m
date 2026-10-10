function D = design_lead(Gj, w, K)
%DESIGN_LEAD Best lead (zero z, pole p) for a Map slope limit K over one or several linearized plants.
%
%   D = design_lead(Gj, w, K)    Gj = cell array of frequency responses, w = grid [rad/s]
%   Hard gates: for slopes k = K*[0.25 0.5 0.75 1]:
%     closed loop stable, PM >= 45 deg at all gain crossovers, GM >= 2 for every plant in Gj.
%   Among all (z, p) satisfying gates, returns the one with SMALLEST high-frequency gain K*p/z.
%   Ties go to larger PM.
%   D.ok (0/1), D.z, D.p [rad/s], D.PM, D.GM, D.HF = K*p/z, D.nFeasible, D.wc.
zs = logspace(log10(8), log10(400), 36);
rs = logspace(log10(1.5), log10(120), 40);
kset = K * [0.25 0.5 0.75 1];
best = struct('ok', 0, 'z', NaN, 'p', NaN, 'PM', NaN, 'GM', NaN, 'HF', Inf, 'nFeasible', 0, 'wc', NaN);
n = 0;

for z = zs
    for r = rs
        p = z * r;
        pm = Inf; gm = Inf; wc = 0; ok = true;
        for ik = numel(kset):-1:1                 % highest slope first: rejects most candidates quickly
            for ig = 1:numel(Gj)
                R = map_margins(Gj{ig}, w, kset(ik), z, p);
                if ~R.stable || R.PM < 45 || R.GM < 2
                    ok = false;
                    break;
                end
                pm = min(pm, R.PM);
                gm = min(gm, R.GM);
                if ik == numel(kset), wc = max(wc, R.wc); end
            end
            if ~ok, break; end
        end
        if ~ok, continue; end
        n = n + 1;
        hf = K * r;
        if hf < best.HF - 1e-9 || (abs(hf - best.HF) < 1e-9 && pm > best.PM)
            best = struct('ok', 1, 'z', z, 'p', p, 'PM', pm, 'GM', gm, 'HF', hf, 'nFeasible', 0, 'wc', wc);
        end
    end
end
D = best;
D.nFeasible = n;
end

