function make_plant_limits()
%MAKE_PLANT_LIMITS Maximum steady-state lateral acceleration a_y,max(v, mu) of the Plant and write data/plant_limits.json.
%
%   Documents/Plant/plant.txt section 6.2 (Eq. (32), Table 5): a_y,max(v, mu) = min(mu*g, a_y,10deg(v, mu)), where
%   a_y,10deg is the steady-state lateral acceleration at which max(|delta_f|, |beta|) reaches 10 degrees (small-angle
%   limit of the model). The steady branch is swept in delta_f and solved with the Plant equations (Eq. (9)-(16), (23),
%   (24)) in plain MATLAB, parameters read from data/params.json. Grid: v = 20:5:100 km/h, mu = 0.2:0.1:0.8.
%   This is a property of the Plant alone; the assist limit T_a,max(v) built on it lives in Ref/script/make_ta_max.m.
%
%   Usage: >> make_plant_limits      (writes Model/data/plant_limits.json)

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/

P = loadPlant(modelDir);
vKmh   = 20:5:100;
muList = 0.2:0.1:0.8;
A = zeros(numel(vKmh), numel(muList));
for i = 1:numel(vKmh)
    for j = 1:numel(muList)
        A(i, j) = aymaxSmallAngle(P, vKmh(i) / 3.6, muList(j));
    end
end

out = struct();
out.x_note = ['Plant limits, Documents/Plant/plant.txt section 6.2 Table 5. a_y: maximum steady-state lateral acceleration [g], ' ...
    'table(v, mu) = min(mu*g, a_y where max(|delta_f|,|beta|) = 10 deg); rows = v_kmh, columns = mu. ' ...
    'Written by Model/Plant/script/make_plant_limits.m; regenerate after any change of the Plant parameters.'];
out.a_y = struct('unit', 'g', 'v_kmh', vKmh, 'mu', muList, 'table', A);

fid = fopen(fullfile(modelDir, 'data', 'plant_limits.json'), 'w');
fwrite(fid, jsonencode(out, 'PrettyPrint', true));
fclose(fid);
fprintf('make_plant_limits: wrote data/plant_limits.json. a_y,max at mu = 0.8 [g]: %s\n', mat2str(round(A(:, end)', 3)));
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

function a = aymaxSmallAngle(P, v, mu)
% a_y,max = min(mu*g, a_y where max(|delta_f|, |beta|) = 10 deg) [g], steady branch swept in delta_f.
    opt = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', 1e-12, 'StepTolerance', 1e-12);
    d = linspace(1e-4, 0.35, 1600); ayv = nan(size(d)); ang = nan(size(d)); x = [0; 0];
    for k = 1:numel(d)
        [x, ~, flag] = fsolve(@(x) steadyRes(P, x, d(k), v, mu), x, opt);
        if flag <= 0, break; end
        ayv(k) = axleSum(P, [x; d(k)], v, mu) / P.m;
        ang(k) = max(abs(d(k)), abs(x(1)));
        if k > 1 && ayv(k) < ayv(k-1), break; end
    end
    [~, ipk] = max(ayv);
    i10 = find(ang >= 10 * pi / 180, 1);
    if ~isempty(i10) && i10 <= ipk
        a = interp1(ang(i10-1:i10), ayv(i10-1:i10), 10 * pi / 180) / P.g;
    else
        a = mu;
    end
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
