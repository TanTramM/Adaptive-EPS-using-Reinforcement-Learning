function [Gj, w, info] = mappidlag_plants()
%MAPPIDLAG_PLANTS Frequency responses of the 68 linearized Plants (17 speeds 20-100 km/h x the 4 operating points of map_op_points) from T_a to T_s,
%   on the grid w = logspace(-1, 5, 3000) rad/s: the same set the Map compensator was designed on (sweep_leadlag.m) and the MapPID design used.
%   Cached in Result/Controllers/MapPIDLag/Design/MapPIDLag_plants.mat (computing the 68 steady states takes a few minutes; run this function once
%   BEFORE starting several MATLAB sessions, so that they do not all write the cache at the same time).
%   Gj{i} = squeeze(freqresp(G_i, w)) (column); info.v_kmh, info.ay_g, info.mu (68 x 1) describe plant i.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
cacheFile = fullfile(result_dir('MapPIDLag', 'Design'), 'MapPIDLag_plants.mat');
if exist(cacheFile, 'file')
    S = load(cacheFile); Gj = S.Gj; w = S.w; info = S.info; return;
end
P   = map_params();
Cal = calibrate_map_cached();
ops = map_op_points();
w   = logspace(-1, 5, 3000)';
n = numel(Cal.v_kmh) * size(ops, 1);
Gj = cell(n, 1); info = struct('v_kmh', zeros(n, 1), 'ay_g', zeros(n, 1), 'mu', zeros(n, 1)); idx = 1;
fprintf('mappidlag_plants: frequency responses of %d plants...\n', n);
for iv = 1:numel(Cal.v_kmh)
    for i = 1:size(ops, 1)
        G = map_plant_lin(P, Cal.v_kmh(iv) / 3.6, ops(i, 1) * P.g, ops(i, 2));
        Gj{idx} = squeeze(freqresp(G, w));
        info.v_kmh(idx) = Cal.v_kmh(iv); info.ay_g(idx) = ops(i, 1); info.mu(idx) = ops(i, 2); idx = idx + 1;
    end
end
save(cacheFile, 'Gj', 'w', 'info');
end
