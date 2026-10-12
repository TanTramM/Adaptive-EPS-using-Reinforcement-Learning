function M = map_table(Cal, iv, Kmax, Ts0)
%MAP_TABLE Assist curve M(|T_s|) at one speed for slope limit Kmax (Documents/Thesis/map.txt section 2.2).
%
%   M = map_table(Cal, iv, Kmax, Ts0)
%     Cal   = calibrate_map output
%     iv    = index of speed in Cal.v_kmh (1..17)
%     Kmax  = slope limit
%     Ts0   = dead zone threshold (default 0.3 N.m)
%
%   Returns struct M:
%     M.Ts    = breakpoints (ascending, starting at Ts0)
%     M.Ta    = assist torque at breakpoints
%     M.Kmax  = Kmax
%     M.Ts0   = Ts0
%     M.v_kmh = Cal.v_kmh(iv)
if nargin < 4, Ts0 = 0.3; end
Ts = Cal.Ts{iv}(:);
Ta = Cal.Ta{iv}(:);
keep = [true; diff(Ts) > 1e-9];          % strictly increasing breakpoints
Ts = Ts(keep);
Ta = Ta(keep);

M.Ts = [Ts0; Ts];
M.Ta = zeros(size(M.Ts));
for k = 1:numel(Ts)
    M.Ta(k + 1) = min(Ta(k), M.Ta(k) + Kmax * (M.Ts(k + 1) - M.Ts(k)));
end
M.Ta = max(M.Ta, 0);
M.Kmax = Kmax;
M.Ts0 = Ts0;
M.v_kmh = Cal.v_kmh(iv);
end

