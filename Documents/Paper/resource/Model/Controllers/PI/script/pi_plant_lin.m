function [G1c, G0c, info] = pi_plant_lin()
%PI_PLANT_LIN Linearized assist loop plant T_a -> T_s at held steering angle, built from data/params.json and data/actuator.json only.
%
%   [G1c, G0c, info] = pi_plant_lin()
%     G1c  dry road (small slip): K / (J_col s^2 + C_col s + K + k_r) * Gm(s),  k_r = e_p0*C_alpha_f/n_st^2
%     G0c  saturated tire:        same with k_r = 0
%     Gm(s) = wm/(s + wm)   motor lag (data/actuator.json)
%   The sign (T_a lowers T_s) is carried by the feedback convention: the loop is L = C*G with e = T_s - T_d,ref and T_a = C*e.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
P = struct();
for grp = {'cum1', 'cum2'}
    fn = fieldnames(raw.(grp{1}));
    for i = 1:numel(fn), P.(fn{i}) = raw.(grp{1}).(fn{i}).value; end
end
wm = 2 * pi * jsondecode(fileread(fullfile(modelDir, 'data', 'actuator.json'))).fm.value;
kr = P.e_p0 * P.C_alpha_f / P.n_st^2;
Gm = tf(wm, [1 wm]);
G1c = tf(P.K, [P.J_col, P.C_col, P.K + kr]) * Gm;
G0c = tf(P.K, [P.J_col, P.C_col, P.K]) * Gm;
info = struct('K', P.K, 'J_col', P.J_col, 'C_col', P.C_col, 'kr', kr, 'wm', wm);
end

