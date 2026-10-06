function out = calibrate_map(Kmax, outFile)
%CALIBRATE_MAP Design the conventional EPS assist controller (baseline) and write data/map_6_8.json.
%
%   out = calibrate_map()                  two speed tiers, writes data/map_6_8.json: K_max = 8 for v <= 60 km/h, K_max = 6 for v >= 65 km/h
%   out = calibrate_map(Kmax)              one K_max for every speed (scalar) or one per map speed (vector of 17), writes data/map_6_8.json
%   out = calibrate_map(Kmax, outFile)     the same, writes outFile ('' = do not write; used by the K_max sweep)
%   Each distinct K_max has its own lead stage (out.lead for the largest K_max = low speeds, out.lead_hi for the smallest = high speeds).
%   In the model the two lead stages run in parallel and their outputs are blended by the speed between 60 and 65 km/h (out.blend_kmh).
%
%   Documents/Map_6_8/map.txt. The conventional EPS controller of [1] (Lee 2018, Sec. III.A, Fig. 6) is a torque map
%   T_a = sgn(T_s) * M(v, |T_s|) followed by a stabilizing lead compensator; [4] (Multi-Map) and [5] design the
%   map at the dry road (mu = 0.8) and it does not know mu. Steps:
%
%   1. Calibration pairs at mu = 0.8 ([5] Table 5, [4] Eq. (6)): for every speed v = 20:5:100 km/h and every
%      a_y from 0.1 g (lowest a_y of Table 4) to a_y,lim(v) = min(a_y,max(v, 0.8), 0.4 g):
%         T_s target = T_d,ref(v, a_y)          (fine reference table, same as the Reference block)
%         T_a        = T_r(v, a_y, 0.8) - T_d,ref(v, a_y)   (steady state: T_s = T_r - T_a)
%      a_y,lim(v) and T_a,max(v) are read from data/ref.json (Ref/script/make_ta_max.m, Documents/Ref/ref.txt section 1.5).
%   2. Curve per speed: dead band T_a = 0 for |T_s| <= Ts0 (self-chosen (6)); straight line from (Ts0, 0) to the
%      0.1 g pair; then the calibration pairs; slope limited to Kmax (self-chosen (7)); after the last pair the
%      assist keeps rising with slope Kmax up to T_a,max(v), then stays constant (saturation).
%   3. Table: the curves sampled on |T_s| = 0:0.02:5 N.m (linear interpolation in Simulink reproduces them).
%   4. Stabilizing compensator ([1]: phase margin >= 45 deg; one lead stage adds at most about 55 deg, and the
%      uncompensated loop at 1 ms already has about 3 deg, so one stage is enough): H(s) = (s/z + 1)/(s/p + 1),
%      Tustin at Ts_ctrl (self-chosen (8)), designed on the linearized loop of [1] (map replaced by a gain Kv in
%      (0, Kmax], sliding regime of the column: no friction damping), plant T_s/T_a = K/(J_col s^2 + C_col s + K + k_r)
%      with ZOH. Choice: smallest high-frequency gain p/z that gives PM >= 45 deg for every Kv, for k_r of the
%      dry road and k_r = 0. The plant of the design loop includes the motor lag Gm(s) = wm/(s + wm) of the Actuator block
%      (data/actuator.json, Lee 2018 eq. (10)). If no stage gives PM >= 45 deg for this K_max, the stage with the best
%      PM is used and out.lead.feasible = false.
%
%   The Plant equations are re-implemented in plain MATLAB (no Simulink), Documents/Plant/plant.txt Eq. (9)-(24).
%
%   Usage: >> calibrate_map     (writes Model/data/map_6_8.json)

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
if nargin < 2, outFile = fullfile(modelDir, 'data', 'map_6_8.json'); end
wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;   % motor lag corner [rad/s]

P = loadPlant(modelDir);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
assert(isfield(ref, 'fine'), 'data/ref.json has no fine table - run Ref/script/make_ref_table.m first.');
assert(isfield(ref, 'Ta_max'), 'data/ref.json has no Ta_max - run Ref/script/make_ta_max.m first.');
ta = ref.Ta_max;   % a_y,lim(v) and T_a,max(v) of Documents/Ref/ref.txt section 1.5
tdref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ...
    min(max(ay, 0), ref.fine.ay_breakpoints_g(end)), min(max(v, 20), 100), 'linear');

Ts_ctrl = 0.001;      % self-chosen (8)
Ts0     = 0.3;        % self-chosen (6), dead band [N.m]
muCal   = 0.8;
ayLow   = 0.1;        % lowest a_y of Table 4 [g]
vKmh    = 20:5:100;
TsBp    = 0:0.02:5;

nV = numel(vKmh);
if nargin < 1
    Kv = 8 * (vKmh <= 60) + 6 * (vKmh > 60);    % self-chosen (7): K_max of every map speed (two tiers)
elseif isscalar(Kmax)
    Kv = Kmax * ones(1, nV);
else
    Kv = Kmax(:)';
    assert(numel(Kv) == nV, 'Kmax must be a scalar or have one value per map speed (%d)', nV);
end
TaTable = zeros(nV, numel(TsBp));
cal = struct('ay_g', {}, 'Ts_Nm', {}, 'Ta_Nm', {}, 'Ta_map_Nm', {});
ayLim = zeros(1, nV); TaMax = ayLim;
for j = 1:nV
    v = vKmh(j) / 3.6;
    assert(ta.v_kmh(j) == vKmh(j), 'data/ref.json Ta_max speeds differ from the map speeds');
    ayLim(j) = ta.a_y_lim_g(j);
    ay = unique([ayLow:0.005:ayLim(j), ayLim(j)]);
    Tr = zeros(size(ay));  z = [0; 0; 0.001];
    for i = 1:numel(ay)
        [Tr(i), z] = roadTorque(P, v, ay(i) * P.g, muCal, z);
    end
    Td = tdref(vKmh(j), ay);
    Ta = Tr - Td;
    assert(all(diff(Td) > 0) && all(diff(Ta) > 0), 'calibration pairs are not increasing at %g km/h', vKmh(j));
    assert(Td(1) > Ts0, 'dead band reaches the 0.1 g calibration point at %g km/h', vKmh(j));
    TaMax(j) = ta.Ta_max_Nm(j);
    assert(abs(Ta(end) - TaMax(j)) < 1e-6, 'T_a at a_y,lim differs from the Ref T_a,max at %g km/h', vKmh(j));

    xs = [0, Ts0, Td];  ys = [0, 0, Ta];
    for k = 3:numel(xs)                                   % slope limit
        ys(k) = min(ys(k), ys(k-1) + Kv(j) * (xs(k) - xs(k-1)));
    end
    row = interp1(xs, ys, min(TsBp, xs(end)), 'linear');
    beyond = TsBp > xs(end);
    row(beyond) = min(ys(end) + Kv(j) * (TsBp(beyond) - xs(end)), TaMax(j));
    TaTable(j, :) = row;
    cal(j).ay_g = ay;  cal(j).Ts_Nm = Td;  cal(j).Ta_Nm = Ta;  cal(j).Ta_map_Nm = ys(3:end);
end
assert(all(diff(TaTable, 1, 2) >= -1e-12, 'all'), 'map is not non-decreasing in |T_s|');

% ---- stabilizing compensator ----
kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
KloAll = max(Kv); KhiAll = min(Kv);
leadLo = designStage(P, kr, Ts_ctrl, KloAll, wm);
if KhiAll == KloAll, leadHi = leadLo; else, leadHi = designStage(P, kr, Ts_ctrl, KhiAll, wm); end

out = struct();
out.x_note = ['Conventional EPS assist controller (baseline): torque map T_a = sgn(T_s)*M(v,|T_s|) calibrated at mu = 0.8, ' ...
    'followed by one lead stage (two stages in parallel, blended by the speed). Documents/Map_6_8/map.txt. ' ...
    'Written by Model/Map_6_8/script/calibrate_map.m.'];
out.Ts_ctrl = struct('value', Ts_ctrl, 'unit', 's', 'desc', 'ECU sample time of the assist loop (self-chosen (8))');
out.Ts0 = struct('value', Ts0, 'unit', 'N.m', 'desc', 'dead band of the torque map (self-chosen (6))');
out.Kmax = struct('value', max(Kv), 'unit', '-', 'desc', 'largest slope dT_a/dT_s of the torque map (self-chosen (7))');
out.Kmax_by_speed = Kv;
out.blend_kmh = [60 65];
out.calibration_mu = muCal;
out.v_breakpoints_kmh = vKmh;
out.Ts_breakpoints_Nm = TsBp;
out.Ta_table_Nm = round(TaTable, 9);
out.lead = leadLo;
out.lead_hi = leadHi;
out.calibration = cal;

if ~isempty(outFile)
    fid = fopen(outFile, 'w');
    fwrite(fid, jsonencode(out, 'PrettyPrint', true));
    fclose(fid);
    fprintf('calibrate_map: wrote %s. T_a,max(v) = %s N.m at %s km/h\n', outFile, mat2str(round(TaMax, 3)), mat2str(vKmh));
end
for L = {leadLo, leadHi}
    fprintf('  lead compensator (K_max %g): 1 stage, zero %g rad/s, pole %g rad/s, min PM %.1f deg, min GM %.2f over Kv in (0, %g]\n', ...
        L{1}.K_max, L{1}.zero_rad_s, L{1}.pole_rad_s, L{1}.min_phase_margin_deg, L{1}.min_gain_margin, L{1}.K_max);
end
end

%% ===================== Compensator design ===============================
function L = designStage(P, kr, T, Kmax, wm)
    [zl, pl, pmMin, gmMin, feasible] = designLead(P, kr, T, Kmax, wm);
    [num, den] = tfdata(c2d(tf([1/zl 1], [1/pl 1]), T, 'tustin'), 'v');
    L = struct('K_max', Kmax, 'zero_rad_s', zl, 'pole_rad_s', pl, 'stages', 1, 'num', num, 'den', den, ...
        'min_phase_margin_deg', pmMin, 'min_gain_margin', gmMin, 'k_r_Nm_per_rad', kr, 'feasible', feasible, 'motor_wm_rad_s', wm);
end

function [zBest, pBest, pmBest, gmBest, feasible] = designLead(P, kr, T, Kmax, wm)
    Kvs = linspace(0.5, Kmax, 12);
    Gm = tf(wm, [1 wm]);   % motor lag
    G = {c2d(tf(P.K, [P.J_col, P.C_col, P.K + kr]) * Gm, T, 'zoh'), c2d(tf(P.K, [P.J_col, P.C_col, P.K]) * Gm, T, 'zoh')};
    best = [inf, 0, 0, 0, 0];   % [hf gain, -pmMin, z, p, gmMin]
    fallback = [-inf, 0, 0, 0, 0];   % [pmMin, r, z, p, gmMin] of the stable stage with the best PM
    for zl = 10:10:150
        for r = 2:1:60
            pl = r * zl;
            if pl > 0.4 * pi / T, continue; end
            H = c2d(tf([1/zl 1], [1/pl 1]), T, 'tustin');
            pmMin = inf; gmMin = inf; ok = true;
            for g = 1:numel(G)
                for Kv = Kvs
                    L = Kv * H * G{g};
                    if ~isstable(feedback(L, 1)), ok = false; break; end
                    [gm, pm] = margin(L);
                    pmMin = min(pmMin, pm); gmMin = min(gmMin, gm);
                end
                if ~ok, break; end
            end
            if ok && pmMin > fallback(1), fallback = [pmMin, r, zl, pl, gmMin]; end
            if ok && pmMin >= 45
                cand = [r, -pmMin, zl, pl, gmMin];
                if cand(1) < best(1) || (cand(1) == best(1) && cand(2) < best(2))
                    best = cand;
                end
            end
        end
    end
    feasible = isfinite(best(1));
    if feasible
        zBest = best(3); pBest = best(4); pmBest = -best(2); gmBest = best(5);
    else
        assert(isfinite(fallback(1)), 'no stable lead compensator up to Kmax = %g', Kmax);
        zBest = fallback(3); pBest = fallback(4); pmBest = fallback(1); gmBest = fallback(5);
    end
end

%% ===================== Plant steady state (plain MATLAB) ================
function P = loadPlant(modelDir)
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

function [Tr, z] = roadTorque(P, v, ay, mu, z0)
% Steady-state T_r at lateral acceleration ay [m/s^2]; unknowns z = [beta; gamma; delta_f].
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    [z, ~, flag] = fsolve(@(z) [steadyRes(P, z(1:2), z(3), v, mu); axleSum(P, z, v, mu) / P.m - ay], z0, opt);
    assert(flag > 0, 'no steady state at v = %g m/s, a_y = %g m/s^2', v, ay);
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3*mu*P.F_zf));
    Tr = e_p / P.n_st * magicFormula(P, alpha_f, mu, P.F_zf, P.C_alpha_f);
end

function r = steadyRes(P, x, df, v, mu)
    [Fyf, Fyr] = forces(P, x(1), x(2), df, v, mu);
    r = [(Fyf + Fyr) / (P.m * v) - x(2); P.l_f * Fyf - P.l_r * Fyr];
end

function F = axleSum(P, z, v, mu)
    [Fyf, Fyr] = forces(P, z(1), z(2), z(3), v, mu);
    F = Fyf + Fyr;
end

function [Fyf, Fyr] = forces(P, beta, gamma, df, v, mu)
    alpha_f = df - beta - P.l_f * gamma / v;
    alpha_r = -beta + P.l_r * gamma / v;
    Fyf = magicFormula(P, alpha_f, mu, P.F_zf, P.C_alpha_f);
    Fyr = magicFormula(P, alpha_r, mu, P.F_zr, P.C_r);
end

function F = magicFormula(P, alpha, mu, Fz, Calpha)
    D = mu * Fz;
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end
