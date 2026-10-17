function V = mapopt_variables(Cal, d)
%MAPOPT_VARIABLES Base-workspace variables of the MapOpt block from a design d (struct) and the calibration Cal (calibrate_map).
%
%   d.Ts_ctrl  controller sample time [s]   d.Ts0  dead zone edge [N.m]   d.Kmax  slope limit of the assist table
%   d.lead     struct z, p [rad/s]: (s/z + 1)/(s/p + 1), p >= z (p = z: no lead)
%   d.lag      struct z1, p1 [rad/s]: (s/z1 + 1)/(s/p1 + 1), p1 <= z1 (p1 = z1: no lag)
%   V.MapOpt_Ts_ctrl, V.MapOpt_v_bp, V.MapOpt_Ts_bp, V.MapOpt_table, V.MapOpt_H_num/den: the variables of map_variables (Controllers/Map/script, reused) renamed.
M = map_variables(Cal, d);
fn = fieldnames(M);
for i = 1:numel(fn)
    V.(['MapOpt_' fn{i}(5:end)]) = M.(fn{i});          % Map_xxx -> MapOpt_xxx
end
end
