function T = rl_angle_table()
%RL_ANGLE_TABLE Steady steering-wheel angle that gives a target lateral acceleration on the dry road with ideal assist.
%
%   T = rl_angle_table()    T.v [km/h], T.ay [g], T.th [rad] (numel(T.v) x numel(T.ay)), T.aylim_dry_g(v) helper data
%
%   Same construction as the standard test cases (Model/Sim/script/test_cases.m, steadyAngleTable): the driver is a
%   steering-angle source and the angle is controller INDEPENDENT, theta1_ss = n_st*delta_f + T_d,ref/K, where delta_f
%   gives the target a_y in steady state on the dry road (mu = 0.8). Used by the RL training scenarios so they are built
%   the same way as the test cases (but with other values, see rl_scenario_random.m). The table is computed once per
%   MATLAB session (persistent cache), about 2 s.
%   Also returns the dry-road lateral acceleration limit a_y,max(v, 0.8) of data/plant_limits.json (T.aylim_v_kmh,
%   T.aylim_g) used to keep the training targets reachable.

persistent cache
if ~isempty(cache)
    T = cache;
    return;
end
scriptDir = fileparts(mfilename('fullpath'));   % RL/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
P   = loadPlant(modelDir);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
T.v  = (20:5:100)';
T.ay = 0:0.01:0.4;
T.th = zeros(numel(T.v), numel(T.ay));
opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
for i = 1:numel(T.v)
    v = T.v(i) / 3.6; z = [0; 0; 0];
    for j = 2:numel(T.ay)
        ay = T.ay(j) * P.g;
        [z, ~, flag] = fsolve(@(z) res(P, z, v, ay), z, opt);
        assert(flag > 0, 'no dry-road steady state at %g km/h, %g g', T.v(i), T.ay(j));
        Td = interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', T.ay(j), T.v(i), 'linear');
        T.th(i, j) = P.n_st * z(3) + Td / P.K;
    end
end
bnd = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
T.aylim_v_kmh = T.v;
T.aylim_g = interp2(bnd.a_y.mu, bnd.a_y.v_kmh, bnd.a_y.table, 0.8 * ones(size(T.v)), T.v, 'linear');
cache = T;
end

function r = res(P, z, v, ay)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    alpha_r = -z(1) + P.l_r * z(2) / v;
    Fyf = mf(P, alpha_f, 0.8 * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, 0.8 * P.F_zr, P.C_r);
    r = [(Fyf + Fyr) / (P.m * v) - z(2); P.l_f * Fyf - P.l_r * Fyr; (Fyf + Fyr) / P.m - ay];
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function P = loadPlant(modelDir)
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    P = struct();
    for grp = {'cum1', 'cum2'}
        fn = fieldnames(raw.(grp{1}));
        for i = 1:numel(fn)
            P.(fn{i}) = raw.(grp{1}).(fn{i}).value;
        end
    end
    L = P.l_f + P.l_r;
    P.F_zf = P.m * P.g * P.l_r / L;
    P.F_zr = P.m * P.g * P.l_f / L;
end
