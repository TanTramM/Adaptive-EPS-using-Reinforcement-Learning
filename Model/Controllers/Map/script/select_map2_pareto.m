function sel = select_map2_pareto(writeJson)
%SELECT_MAP2_PARETO Select the Map design from the (K, g_min) grid (PhuongPhap_TimThamSo.txt 14.5).
%   If any pair passes every gate (rule R1) the selection uses e_max = 10 %; otherwise it uses only the safety gates (erelMax = Inf) and the design is
%   labelled "safe, fails e_rel" in map.json (x_design_note). A pair that fails a safety gate is never chosen.
if nargin < 1, writeJson = false; end
spec = map2_grid_spec();
files = dir(fullfile(spec.outDir, 'Map_CALIB_grid2_w*_s00000.csv')); P = table();
for i = 1:numel(files), P = [P; readtable(fullfile(files(i).folder, files(i).name))]; end %#ok<AGROW>
r1 = P.simulated == 1 & P.c1 <= 0 & P.c2 <= 0 & P.c3 <= 0 & P.c4 <= 0 & isfinite(P.J);
% A pair that passes e_rel but fails calib_margin is not a design that passes every gate (14.0: never choose a pair that fails a safety gate).
if any(r1 & P.pass_margin == 1)
    spec.erelMax = 10;
    spec.designNote = 'two-variable grid (K, g_min): passes all gates including e_rel <= 10 %; 2026-10-21';
else
    spec.erelMax = Inf;
    spec.designNote = 'two-variable grid (K, g_min): safe, fails e_rel (every pair with e_rel <= 10 % fails calib_margin, gain x2 ratio about 3.6 > 2); chosen among the pairs passing the safety gates; 2026-10-21';
end
fprintf('select_map2_pareto: erelMax = %g\n', spec.erelMax);
spec.ruleText = 'deterministic coarse (13x13) to fine grid on (K, g_min), feasible Pareto (R,S), J=R*S with 3% tie by maximum PM, calib_margin; 2026-10-21';
sel = select_pareto(spec, writeJson);
end
