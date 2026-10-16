function V = mapopt_variables(Cal, d)
%MAPOPT_VARIABLES Base-workspace variables of the MapOpt controller block from a design d (struct) and the calibration Cal (calibrate_map).
%   d.Ts_ctrl [s], d.Ts0 dead zone edge [N.m], d.Kmax slope limit, d.lead struct z, p [rad/s], d.lag struct z1, p1 [rad/s] (optional)
%   V.MapOpt_Ts_ctrl, _v_bp [m/s], _Ts_bp [N.m], _table, _H_num, _H_den (Tustin of lead x lag). The Map helper map_variables is reused (it lives in
%   Controllers/Map/script; the same reuse as MapPID, reported in the log); only its names are changed from Map_ to MapOpt_.
keep = {'Ts_ctrl', 'Ts0', 'Kmax', 'lead', 'lag'};
f = fieldnames(d);
for i = 1:numel(f), if ~any(strcmp(f{i}, keep)), d = rmfield(d, f{i}); end, end
M = map_variables(Cal, d);
fn = fieldnames(M);
for i = 1:numel(fn), V.(['MapOpt_' fn{i}(5:end)]) = M.(fn{i}); end
end
