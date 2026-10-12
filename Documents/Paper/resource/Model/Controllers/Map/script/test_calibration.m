function test_calibration()
%TEST_CALIBRATION Verify the dry-road calibration of the Map (calibrate_map.m). Self-contained: parameters read straight from data/params.json.
%
%   Reads the stored result (Result/Controllers/Map/Design/Map_calibration_points.csv and data/map.json), run calibrate_map first.
%   (a) every point: T_r re-solved by a DIFFERENT method (fsolve on the three steady equations in beta, gamma, delta_f, with its own tire model),
%       residuals of the three equations < 1e-8, T_r agrees with the stored value to 1e-6 N.m;
%   (b) T_s,cal + T_a,cal = T_r at every point, and T_s,cal equals the set value from ref.json (independent interp2);
%   (c) the Plant.mdl itself: with T_a = T_a,cal and the steering wheel angle that the independent Newton solution requires, the Plant settles
%       with T_s = T_s,cal and a_y = the target at 6 points (20, 60, 100 km/h; two a_y each);
%   (d) T_s,cal and T_a,cal increase with a_y, T_a,cal >= 0, grid counts as designed, data/map.json holds the same points as the csv;
%       the assist limit of ref.json is T_a,max = T_a,req + F with F = T_f (params.json), T_a,cal <= T_a,req (so at least F below T_a,max)
%       and within 0.1 N.m of T_a,req at the top of the grid.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
addpath(modelDir); setup_paths;
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn), P.(fn{i}) = raw.(grp{1}).(fn{i}).value; end
end
P.Iz = raw.cum3.Iz.value; L = P.l_f + P.l_r;
P.F_zf = P.m * P.g * P.l_r / L; P.F_zr = P.m * P.g * P.l_f / L;
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
T = readtable(fullfile(result_dir('Map', 'Design'), 'Map_calibration_points.csv'));
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));

%% (a) + (b) every point
opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-12, 'StepTolerance', 1e-12, 'OptimalityTolerance', 1e-12);
maxRes = 0; maxTr = 0; maxId = 0; maxRef = 0;
for k = 1:height(T)
    v = T.v_kmh(k) / 3.6; ay = T.ay_g(k) * P.g;
    if k > 1 && T.v_kmh(k) == T.v_kmh(k - 1), z0 = zPrev; else, z0 = [0; ay / v; 0.02]; end   % continuation along a_y at one speed
    z = fsolve(@(z) resid(P, z, v, ay), z0, opt);
    r = resid(P, z, v, ay);
    zPrev = z;
    assert(norm(r) < 1e-8, 'fsolve did not converge at point %d (residual %.3g)', k, norm(r));
    [~, ~, ~, ~, Tr] = tires(P, z(1), z(2), z(3), v);
    maxRes = max(maxRes, norm(r));
    maxTr = max(maxTr, abs(Tr - T.Tr_Nm(k)));
    maxId = max(maxId, abs(T.Ts_cal_Nm(k) + T.Ta_cal_Nm(k) - T.Tr_Nm(k)));
    Td = interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', T.ay_g(k), T.v_kmh(k), 'linear');
    maxRef = max(maxRef, abs(Td - T.Ts_cal_Nm(k)));
end
assert(maxRes < 1e-8, '(a) residual of the steady equations %.3g', maxRes);
assert(maxTr < 1e-6, '(a) T_r differs from the independent solution by %.3g N.m', maxTr);
assert(maxId < 1e-9, '(b) T_s + T_a ~= T_r, max %.3g', maxId);
assert(maxRef < 1e-9, '(b) T_s,cal differs from the set value, max %.3g', maxRef);
fprintf('[Map calibration] (a) %d points: T_r matches fsolve to %.2g N.m (residual %.2g); (b) T_s+T_a = T_r to %.2g, T_s,cal = T_d,ref to %.2g\n', ...
    height(T), maxTr, maxRes, maxId, maxRef);

%% (d) structure
sp = unique(T.v_kmh)';
assert(isequal(sp, 20:5:100), '(d) speed grid');
lim = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
muCol = find(abs(lim.a_y.mu - 0.8) < 1e-9);
nExp = 0;
for v = sp
    m = T.v_kmh == v;
    ay = T.ay_g(m); Ts = T.Ts_cal_Nm(m); Ta = T.Ta_cal_Nm(m);
    ayTop = min(interp1(lim.a_y.v_kmh, lim.a_y.table(:, muCol), v), 0.4);
    assert(abs(ay(1) - 0.1) < 1e-12 && all(abs(diff(ay) - 0.005) < 1e-9) && ay(end) <= ayTop + 1e-9 && ay(end) > ayTop - 0.005 - 1e-9, '(d) a_y grid at %g km/h', v);
    assert(all(diff(Ts) > 0), '(d) T_s,cal not increasing at %g km/h', v);
    assert(all(diff(Ta) > 0), '(d) T_a,cal not increasing at %g km/h', v);
    assert(all(Ta >= 0), '(d) negative T_a,cal at %g km/h', v);
    nExp = nExp + numel(ay);
end
assert(height(T) == nExp, '(d) point count');
assert(sum(T.Ta_cal_exceeds_Ta_max) == 0, '(d) T_a,cal above T_a,max(v)');
assert(abs(ref.Ta_max.F_Nm - P.T_f) < 1e-12, '(d) F of ref.json is not T_f of params.json');
assert(isequal(ref.Ta_max.v_kmh(:)', 20:5:100), '(d) T_a,max speed grid');
minMargin = inf; maxTopGap = 0;
for i = 1:numel(sp)
    m = T.v_kmh == sp(i);
    reqI = ref.Ta_max.Ta_req_Nm(i);
    assert(abs(ref.Ta_max.Ta_max_Nm(i) - reqI - P.T_f) < 1e-9, '(d) T_a,max ~= T_a,req + T_f at %g km/h', sp(i));
    assert(all(T.Ta_cal_Nm(m) <= reqI + 1e-9), '(d) T_a,cal above T_a,req at %g km/h', sp(i));
    assert(all(abs(T.Ta_max_Nm(m) - ref.Ta_max.Ta_max_Nm(i)) < 1e-12), '(d) T_a,max column of the csv at %g km/h', sp(i));
    minMargin = min(minMargin, min(T.Ta_margin_Nm(m)));
    maxTopGap = max(maxTopGap, reqI - max(T.Ta_cal_Nm(m)));
end
assert(minMargin >= P.T_f - 1e-9, '(d) margin below T_a,max smaller than F: %.4g', minMargin);
assert(maxTopGap < 0.1, '(d) top of the grid too far below T_a,req: %.3g N.m', maxTopGap);
pts = J.calibration.points; nJ = 0;
for i = 1:numel(pts)
    m = T.v_kmh == pts(i).v_kmh;
    assert(max(abs(pts(i).Ta_Nm(:) - T.Ta_cal_Nm(m))) < 1e-12 && max(abs(pts(i).Ts_Nm(:) - T.Ts_cal_Nm(m))) < 1e-12, '(d) map.json differs from csv at %g km/h', pts(i).v_kmh);
    nJ = nJ + numel(pts(i).Ta_Nm);
end
assert(nJ == height(T), '(d) map.json point count');
fprintf('[Map calibration] (d) 17 speeds, %d points, monotonic, T_a,cal >= 0, smallest margin to T_a,max %.3f N.m (F = %.1f), top of grid within %.3f N.m of T_a,req, map.json = csv\n', height(T), minMargin, P.T_f, maxTopGap);

%% (c) the Plant itself
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'), '''', '''''')));
plantDir = fullfile(modelDir, 'PRSM', 'Plant');
if bdIsLoaded('Plant'), close_system('Plant', 0); end
load_system(fullfile(plantDir, 'Plant.mdl'));
subs = find_system('Plant', 'SearchDepth', 1, 'BlockType', 'SubSystem'); assert(numel(subs) == 1);
dut = subs{1};
h = 'test_calibration_harness';
if bdIsLoaded(h), close_system(h, 0); end
new_system(h); open_system(h);
add_block(dut, [h '/DUT']);
ins = {'theta1', 'T_a', 'v', 'mu'};
for i = 1:numel(ins)
    add_block('simulink/Sources/Constant', [h '/' ins{i} '_in']);
    add_line(h, [ins{i} '_in/1'], portRef([h '/DUT'], ins{i}));
end
outs = {'T_s', 'a_y'};
for i = 1:numel(outs)
    add_block('simulink/Sinks/To Workspace', [h '/' outs{i} '_out'], 'VariableName', [outs{i} '_log'], 'SaveFormat', 'Timeseries');
    add_line(h, portRef([h '/DUT'], outs{i}), [outs{i} '_out/1']);
end
set_param(h, 'StopTime', '40', 'MaxStep', '0.01', 'RelTol', '1e-8', 'AbsTol', '1e-10');   % slow friction-limited approach, see test_plant.m
cases = [20 0.10; 20 0.18; 60 0.20; 60 0.40; 100 0.10; 100 0.30];
maxTs = 0; maxAy = 0;
for c = 1:size(cases, 1)
    k = find(abs(T.v_kmh - cases(c, 1)) < 1e-9 & abs(T.ay_g - cases(c, 2)) < 1e-9);
    assert(isscalar(k), 'calibration point not found: %g km/h, %g g', cases(c, 1), cases(c, 2));
    v = cases(c, 1) / 3.6; ay = cases(c, 2) * P.g;
    % independent Newton for the Plant equilibrium that must deliver a_y: unknowns beta, gamma, theta2, theta1 given T_a = T_a,cal
    zs = solveSteady(P, v, ay, opt);                       % [beta; gamma; delta_f] by the (a) method, as a starting point
    z0 = [zs(1); zs(2); P.n_st * zs(3); P.n_st * zs(3) + T.Ts_cal_Nm(k) / P.K];
    z = fsolve(@(z) residPlant(P, z, v, ay, T.Ta_cal_Nm(k)), z0, opt);
    assert(norm(residPlant(P, z, v, ay, T.Ta_cal_Nm(k))) < 1e-8, '(c) fsolve did not converge');
    set_param([h '/theta1_in'], 'Value', sprintf('%.15g', z(4)));
    set_param([h '/T_a_in'],    'Value', sprintf('%.15g', T.Ta_cal_Nm(k)));
    set_param([h '/v_in'],      'Value', sprintf('%.15g', v));
    set_param([h '/mu_in'],     'Value', '0.8');
    so = sim(h);
    Tsend = so.get('T_s_log').Data(end); ayEnd = so.get('a_y_log').Data(end);
    eTs = abs(Tsend - T.Ts_cal_Nm(k)); eAy = abs(ayEnd - ay) / P.g;
    maxTs = max(maxTs, eTs); maxAy = max(maxAy, eAy);
    fprintf('[Map calibration] (c) %5.1f km/h %.2f g: Plant T_s %.5f (cal %.5f), a_y %.5f g (target %.2f)\n', cases(c, 1), cases(c, 2), Tsend, T.Ts_cal_Nm(k), ayEnd / P.g, cases(c, 2));
    assert(eTs < 1e-3, '(c) Plant T_s %.6g vs calibration %.6g', Tsend, T.Ts_cal_Nm(k));
    assert(eAy < 2e-4, '(c) Plant a_y %.6g g vs target %.3g g', ayEnd / P.g, cases(c, 2));
end
close_system(h, 0); close_system('Plant', 0);
fprintf('[Map calibration] (c) Plant.mdl at 6 points: max |T_s - T_s,cal| = %.2g N.m, max |a_y - target| = %.2g g\n', maxTs, maxAy);
fprintf('[Map calibration] TEST PASS\n');
end

function z = solveSteady(P, v, ay, opt)
% fsolve of the three steady equations by continuation in a_y: from 0.02 g up to ay in 12 steps, each step started from the previous solution
    z = [0; 0.2 * P.g / v / 10; 0.01];
    for a = linspace(0.02 * P.g, ay, 12)
        z = fsolve(@(z) resid(P, z, v, a), z, opt);
    end
    assert(norm(resid(P, z, v, ay)) < 1e-9, 'steady solution not found at v = %g m/s, a_y = %g m/s^2', v, ay);
end

%% ===================== independent tire and steady-state model (own copy) =====================
function r = resid(P, z, v, ay)
% z = [beta; gamma; delta_f]; steady equations of the 2-DOF body with a_y given, mu = 0.8
    [~, ~, Fyf, Fyr] = tires(P, z(1), z(2), z(3), v);
    L = P.l_f + P.l_r;   % residuals made dimensionless so that fsolve tolerances mean the same for all three
    r = [((Fyf + Fyr) / (P.m * v) - z(2)) / (ay / v); (P.l_f * Fyf - P.l_r * Fyr) / (P.m * ay * L); ((Fyf + Fyr) / P.m - ay) / ay];
end

function r = residPlant(P, z, v, ay, Ta)
% z = [beta; gamma; theta2; theta1]: Plant equilibrium (beta_dot = gamma_dot = theta2_dot = 0) with the assist Ta applied and a_y = ay
    [~, ~, Fyf, Fyr, Tr] = tires(P, z(1), z(2), z(3) / P.n_st, v);
    L = P.l_f + P.l_r;
    r = [((Fyf + Fyr) / (P.m * v) - z(2)) / (ay / v); (P.l_f * Fyf - P.l_r * Fyr) / (P.m * ay * L); (Tr - Ta - P.K * (z(4) - z(3))) / 10; ((Fyf + Fyr) / P.m - ay) / ay];
end

function [alpha_f, alpha_r, Fyf, Fyr, Tr] = tires(P, beta, gamma, delta_f, v)
    mu = 0.8;
    alpha_f = delta_f - beta - P.l_f * gamma / v;
    alpha_r = -beta + P.l_r * gamma / v;
    Fyf = mf(P, alpha_f, mu * P.F_zf, P.C_alpha_f);
    Fyr = mf(P, alpha_r, mu * P.F_zr, P.C_r);
    e_p = P.e_p0 - P.t_0 + max(0, P.t_0 - sign(alpha_f) * P.t_0 * P.C_alpha_f * tan(alpha_f) / (3 * mu * P.F_zf));
    Tr = e_p / P.n_st * Fyf;
end

function F = mf(P, alpha, D, Calpha)
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName in subPath (found BY NAME, never by assumed order)
    parts = strsplit(subPath, '/');
    nm = parts{end};
    for typ = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', typ{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', nm, get_param(ports{k}, 'Port')); return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
