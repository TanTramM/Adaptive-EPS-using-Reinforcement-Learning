function make_ta_max()
%MAKE_TA_MAX Assist-torque limit T_a,max(v) and its lateral-acceleration limit a_y,lim(v); written to data/ref.json (field Ta_max).
%
%   Documents/Ref/ref.txt section 1.5, Eq. (4)-(6). At steady state T_s = T_r - T_a (plant.txt Eq. (6)), so the assist that
%   makes T_s equal to the wanted torque is  T_a,req = T_r(v, a_y, 0.8) - T_d,ref(v, a_y)  and
%       T_a,max(v) = max over 0 <= a_y <= a_y,lim(v) of T_a,req,    a_y,lim(v) = min(a_y,max(v, 0.8), 0.4 g).
%   a_y,max(v, 0.8) is read from data/plant_limits.json (Plant/script/make_plant_limits.m), T_d,ref from the fine table of
%   data/ref.json (make_ref_table.m); T_r is the steady-state road torque of the Plant, solved in plain MATLAB from
%   data/params.json. T_a,req increases with a_y, so the maximum is at a_y,lim; this is checked on a 0.025 g grid.
%   Safety margin (QuyChuan.txt 2.3): the motor limit is the demand PLUS the bound F of the uncertainty that the model leaves out,
%       T_a,max(v) = T_a,req(v at a_y,lim) + F,     F = T_f (dry Coulomb friction of the column, data/params.json)
%   after Slotine and Li, Applied Nonlinear Control, section 7.1.3 equations (7.14)-(7.15): control magnitude u = u_hat - k sgn(s) with
%   k = F + eta, F = bound of the modelling error, eta > 0 the reaching margin of the controller (not of the motor, so eta is not added
%   here); section 7.5 lists friction among the uncertainties. The gain margin beta of equations (7.16)-(7.20) is 1 because the Actuator
%   motor gain is 1 in this model. Nguyen et al. (CEPS ANFIS-FOC, equations (12) and (14)) require motor capability >= max T_a,req.
%   T_a,req alone is kept in Ta_req_Nm. Used by the AssistLimit block (every controller and the Actuator read the limit from it).
%   Saves Result/Reference/Reference_Ta_max_by_speed_mu0p8.csv.
%
%   Run order: make_plant_limits (Plant), make_ref_table (Ref), then this script.
%   Usage: >> make_ta_max

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
addpath(modelDir); setup_paths;                              % result_dir

P = loadPlant(modelDir);
jsonPath = fullfile(modelDir, 'data', 'ref.json');
ref = jsondecode(fileread(jsonPath));
assert(isfield(ref, 'fine'), 'data/ref.json has no fine table - run Ref/script/make_ref_table.m first.');
lim = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
tdref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ...
    min(max(ay, 0), ref.fine.ay_breakpoints_g(end)), min(max(v, 20), 100), 'linear');

muCal = 0.8;
vKmh  = ref.fine.v_breakpoints_kmh(:)';
nV = numel(vKmh);
ayMax = zeros(1, nV); ayLim = ayMax; TrTop = ayMax; TdTop = ayMax; TaReq = ayMax;
F = P.T_f;                                     % bound of the uncertainty left out of the model [N.m]: dry friction of the column
for j = 1:nV
    v = vKmh(j) / 3.6;
    ayMax(j) = interp2(lim.a_y.mu(:)', lim.a_y.v_kmh(:), lim.a_y.table, muCal, vKmh(j), 'linear');
    ayLim(j) = min(ayMax(j), 0.4);
    lv = unique([0.1:0.025:ayLim(j), ayLim(j)]);
    Tr = zeros(size(lv)); z = [0; 0; 0.001];
    for i = 1:numel(lv)
        [Tr(i), z] = roadTorque(P, v, lv(i) * P.g, muCal, z);
    end
    Td = tdref(vKmh(j), lv);
    Ta = Tr - Td;
    assert(all(diff(Ta) > 0), 'T_a,req is not increasing with a_y at %g km/h', vKmh(j));
    TaReq(j) = Ta(end); TrTop(j) = Tr(end); TdTop(j) = Td(end);
end
TaMax = TaReq + F;

ref.Ta_max = struct( ...
    'x_note', ['Assist limit of Documents/Thesis/ref.txt section 1.5 (Eq. (4)-(7), Table 3), mu = 0.8: a_y,max from data/plant_limits.json, ' ...
               'a_y,lim = min(a_y,max, 0.4 g), Ta_req_Nm = T_r - T_d,ref at a_y,lim [N.m] (demand of the model), F_Nm = bound of the uncertainty ' ...
               'left out of the model = dry friction T_f, Ta_max_Nm = Ta_req_Nm + F_Nm (Slotine and Li 7.15). Written by Model/PRSM/Ref/script/make_ta_max.m.'], ...
    'v_kmh', vKmh, 'a_y_max_g', ayMax, 'a_y_lim_g', ayLim, 'T_r_top_Nm', TrTop, 'T_d_ref_top_Nm', TdTop, 'Ta_req_Nm', TaReq, ...
    'F_Nm', F, 'Ta_max_Nm', TaMax);
fid = fopen(jsonPath, 'w');
fwrite(fid, jsonencode(ref, 'PrettyPrint', true));
fclose(fid);

T = table(vKmh(:), ayMax(:), ayLim(:), TrTop(:), TdTop(:), TaReq(:), repmat(F, nV, 1), TaMax(:), 'VariableNames', ...
    {'v_kmh', 'a_y_max_g', 'a_y_lim_g', 'T_r_Nm', 'T_d_ref_Nm', 'Ta_req_Nm', 'F_Nm', 'Ta_max_Nm'});
writetable(T, fullfile(result_dir('Reference'), 'Reference_Ta_max_by_speed_mu0p8.csv'));
fprintf('make_ta_max: wrote data/ref.json field Ta_max. F = %g N.m, T_a,req = %s, T_a,max = %s N.m at %s km/h\n', F, mat2str(round(TaReq, 3)), mat2str(round(TaMax, 3)), mat2str(vKmh));
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
