function E = map_dry_error(Cal, iv, Kmax, Ts0)
%MAP_DRY_ERROR Steady error of the Map on the dry road (mu = 0.8) at one speed.
%   At each calibration a_y, steering column equilibrium is:
%     T_s = T_r - M(T_s)  <=>  T_s - T_r + M(T_s) = 0.
%   Error e_T = T_s,eq - T_d,ref; pct = 100 * e_T / T_d,ref.
if nargin < 4, Ts0 = 0.3; end
M = map_table(Cal, iv, Kmax, Ts0);
ay = Cal.ay_g{iv}(:);
Ts = Cal.Ts{iv}(:);
Tr = Cal.Tr{iv}(:);
Tsol = zeros(size(Ts));
for k = 1:numel(Ts)
    f = @(x) x - Tr(k) + map_eval(M, x);
    Tsol(k) = fzero(f, [0, Tr(k) + 1]);
end
E.v_kmh = Cal.v_kmh(iv);
E.ay_g = ay;
E.Ts_eq = Tsol;
E.eT = Tsol - Ts;
E.pct = 100 * E.eT ./ Ts;
end

