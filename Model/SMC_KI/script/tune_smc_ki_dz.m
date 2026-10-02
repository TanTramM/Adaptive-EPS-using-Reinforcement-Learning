function tune_smc_ki_dz()
%TUNE_SMC_KI_DZ Integral SMC with a wider boundary layer: noise gain from the torque sensor to T_a not above the Map's. Writes data/smc_ki_dz.json.
%
%   Same rule as the PIDF (tune_pidf.m): the noise gain of the controller, from white noise on the measured torque T_s to T_a,
%   must not exceed the Map's (K_max x rms gain of the Map lead stage, data/map.json). lambda, tau_f, k_sw, k_I and Ts are kept
%   from data/smc_ki.json; only the boundary-layer width Phi is widened.
%   Inside the boundary layer the SMC is linear with gain G = k_sw/Phi; T_s enters T_a through T_eq (-T_s) and through
%   -J_col*G*s with s containing -(lambda/K)*e_T, e_T = T_s - T_d,ref, so the (static, all frequencies) gain from T_s to T_a is
%       |J_col*G*lambda/K - 1|   ->   G_max = (budget + 1)*K/(J_col*lambda),   Phi = k_sw/G_max
%   (the integral path k_I*z is a slow low-pass and is neglected). The larger static error of the wider layer is removed by the
%   integral action k_I. Not covered by this rule: the noise of theta1 and theta2_dot, which the Map and the PID do not read.

scriptDir = fileparts(mfilename('fullpath'));   % SMC_KI/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
src = jsondecode(fileread(fullfile(modelDir, 'data', 'smc_ki.json')));
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
mp  = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
K = raw.cum1.K.value; J = raw.cum1.J_col.value;
Ts = src.Ts_ctrl.value;
H = tf(mp.lead.num(:)', mp.lead.den(:)', Ts)^mp.lead.stages;
th = linspace(1e-4, pi, 4000);
budget = mp.Kmax.value * sqrt(mean(abs(squeeze(freqresp(H, th / Ts))).^2));
lam = src.lambda.value; ksw = src.k_sw.value;
Gold = ksw / src.Phi.value;
Gmax = (budget + 1) * K / (J * lam);
Phi = ksw / Gmax;
assert(ksw * Ts / Phi < 1, 'boundary layer too thin for the sample time');

out = src;
out.x_note = ['Integral SMC with a wider boundary layer (Documents/Sim/SoSanh_DieuChinh.txt): Phi chosen so that the noise gain from ' ...
    'the torque sensor to T_a does not exceed the Map''s; other values as data/smc_ki.json. Written by Model/SMC_KI/script/tune_smc_ki_dz.m.'];
out.Phi.value = Phi;
out.Phi.desc = sprintf('Boundary-layer width, widened from %.3g so that |J_col*(k_sw/Phi)*lambda/K - 1| <= Map noise gain %.1f', src.Phi.value, budget);
out.Phi.ref = 'tune_smc_ki_dz.m';
out.design = struct('noise_gain_budget_map', budget, 'noise_gain_old', abs(J * Gold * lam / K - 1), ...
    'noise_gain_new', abs(J * Gmax * lam / K - 1), 'layer_gain_old', Gold, 'layer_gain_new', Gmax, ...
    'static_error_factor_without_integral', Gold / Gmax);
fid = fopen(fullfile(modelDir, 'data', 'smc_ki_dz.json'), 'w', 'n', 'UTF-8');
txt = jsonencode(out, 'PrettyPrint', true);
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('tune_smc_ki_dz: Map noise gain %.1f; layer gain %.0f -> %.0f, Phi %.3g -> %.4g, noise gain %.1f -> %.1f; static error without integral x%.2f\n', ...
    budget, Gold, Gmax, src.Phi.value, Phi, out.design.noise_gain_old, out.design.noise_gain_new, Gold / Gmax);
end
