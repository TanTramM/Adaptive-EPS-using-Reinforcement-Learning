function calibrate_map()
%CALIBRATE_MAP Calibrate the static EPS assist map (lookup table) at mu = 0.8 and write data/map.json.
%
%   The traditional EPS map is a 2-D lookup table T_a = f(v, T_s): it reads the vehicle speed and the sensed
%   steering torque and knows nothing about mu (Multi-Map [6]: the traditional assist characteristic is designed
%   for the maximum front axle load and mu = 0.8; [7] Fig. 3: assist torque versus ideal steering wheel torque
%   per speed). Real maps are calibrated on the vehicle by test drivers. Here the calibration is done on the
%   Plant equations instead, at the dry road mu = 0.8:
%
%     for every breakpoint speed v and every lateral acceleration a_y of Table 4 (data/ref.json):
%       T_s target = T_d,ref(v, a_y)                      (Table 4, the ideal steering wheel torque)
%       T_r        = steady-state road torque at (v, a_y, mu = 0.8)   (Plant equations, small-angle model)
%       T_a        = T_r - T_d,ref                          (steady state: T_s = T_r - T_a)
%
%   Per speed, the curve T_a(T_s) is the piecewise-linear curve through (0, 0) and the four calibration pairs
%   (T_s, T_a), saturated at the last pair (the maximum assist T_a,max(v), corresponding to a_y = 0.4 g). Across
%   speed the curves are interpolated linearly at the same T_s. The result is stored as a table on the grid
%   (v breakpoints) x (union of all calibration T_s values), on which linear interpolation reproduces this map
%   exactly. T_a is odd in T_s: the Simulink block uses |T_s| and sgn(T_s).
%
%   The Plant equations are re-implemented here in plain MATLAB (no Simulink): Documents/Cum2_Pacejka.txt
%   Eq.(1)-(14) (small-angle slip angles, Magic Formula on both axles, e_p floored at 0) and Cum3_2DOF.txt.
%
%   Usage: >> calibrate_map     (writes Model/data/map.json)

scriptDir = fileparts(mfilename('fullpath'));   % Map/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/

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

ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
vKmh  = ref.v_breakpoints_kmh(:)';
ayG   = ref.ay_breakpoints_g(:);
TdTab = ref.table_Nm;                 % rows a_y, columns v
muCal = 0.8;

nA = numel(ayG);
nV = numel(vKmh);
TsCal = TdTab;                         % T_s target = Table 4
TaCal = zeros(nA, nV);
for j = 1:nV
    for i = 1:nA
        Tr = roadTorque(P, vKmh(j)/3.6, ayG(i), muCal);
        TaCal(i, j) = Tr - TdTab(i, j);
    end
end
assert(all(TaCal(:) > 0), 'Calibration gives a non-positive T_a: the map would need negative assist');
assert(all(diff(TaCal, 1, 1) > 0, 'all'), 'T_a must increase with T_s (a_y) at every speed');

TsBp = unique([0; TsCal(:)])';
TaTable = zeros(nV, numel(TsBp));
for j = 1:nV
    x = [0; TsCal(:, j)];
    y = [0; TaCal(:, j)];
    for k = 1:numel(TsBp)
        if TsBp(k) >= x(end)
            TaTable(j, k) = y(end);
        else
            TaTable(j, k) = interp1(x, y, TsBp(k), 'linear');
        end
    end
end

out = struct();
out.x_note = ['Static EPS assist map T_a = f(v, |T_s|) (odd in T_s), calibrated at mu = 0.8 from Table 4 on the Plant equations ' ...
    '(Model/Map/script/calibrate_map.m). Rows of Ta_table_Nm = v_breakpoints_kmh, columns = Ts_breakpoints_Nm. ' ...
    'Documents/DieuKhien_Map.txt.'];
out.Ts_ctrl = struct('value', 0.01, 'unit', 's', 'desc', 'ECU sample time, same as the PID and SMC controllers');
out.v_breakpoints_kmh = vKmh;
out.Ts_breakpoints_Nm = TsBp;
out.Ta_table_Nm = TaTable;
out.calibration_ay_g = ayG';
out.calibration_Ts_Nm = TsCal;
out.calibration_Ta_Nm = TaCal;
out.calibration_mu = muCal;

fid = fopen(fullfile(modelDir, 'data', 'map.json'), 'w');
fwrite(fid, jsonencode(out, 'PrettyPrint', true));
fclose(fid);

fprintf('calibrate_map: wrote data/map.json (%d speeds x %d T_s breakpoints). T_a,max(v) = %s N.m at %s km/h\n', ...
    nV, numel(TsBp), mat2str(round(TaCal(end, :), 3)), mat2str(vKmh));
end

%% ===================== Plant steady state (plain MATLAB) ================
function Tr = roadTorque(P, v, ayG, mu)
% Steady-state road reaction torque T_r at lateral acceleration ayG (in g), speed v, friction mu.
% Solves beta, gamma, delta_f from the two 2-DOF equilibrium equations and a_y = target (continuation on a_y).
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-13, 'StepTolerance', 1e-13);
    z = [0.001; 0.01; 0.001];   % [beta; gamma; delta_f]
    for a = unique([0.01:0.01:ayG, ayG])
        F = @(z) [ (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / (P.m * v) - z(2);
                   (P.l_f * fyf(z, v, P, mu) - P.l_r * fyr(z, v, P, mu)) / P.Iz;
                   (fyf(z, v, P, mu) + fyr(z, v, P, mu)) / P.m - a * 9.81 ];
        [z, ~, flag] = fsolve(F, z, opt);
        assert(flag > 0, 'no steady state at v = %g m/s, mu = %g, a_y = %g g', v, mu, a);
    end
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    e_p = max(0, P.e_p0 - sign(alpha_f) * P.e_p0 * P.C_alpha_f * tan(alpha_f) / (3 * mu * P.F_zf));
    Tr = e_p / P.n_st * fyf(z, v, P, mu);
end

function F = magicFormula(P, alpha, mu, Fz, Calpha)
    D = mu * Fz;
    B = Calpha / (P.C * D);
    u = B * alpha;
    F = D * sin(P.C * atan(u - P.E * (u - atan(u))));
end

function F = fyf(z, v, P, mu)
    alpha_f = z(3) - z(1) - P.l_f * z(2) / v;
    F = magicFormula(P, alpha_f, mu, P.F_zf, P.C_alpha_f);
end

function F = fyr(z, v, P, mu)
    alpha_r = -z(1) + P.l_r * z(2) / v;
    F = magicFormula(P, alpha_r, mu, P.F_zr, P.C_r);
end
