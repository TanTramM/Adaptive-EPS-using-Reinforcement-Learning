function Cal = calibrate_map()
%CALIBRATE_MAP Dry-road calibration points of the Map: for every speed and lateral acceleration, the sensor torque the driver should feel
%   and the assist torque that gives it. Independent of K_max, of the lead and of any controller.
%
%   Cal = calibrate_map()
%
%   Rest balance of the steering column (theta2_dot = 0): T_s = T_r - T_a. To make T_s equal the set value T_d,ref on the dry road (mu = 0.8):
%     T_s,cal = T_d,ref(v, a_y)                 data/ref.json fine table, linear interpolation (as the Reference block)
%     T_a,cal = T_r(v, a_y, 0.8) - T_d,ref      T_r from the steady cornering state, map_steady_state.m
%   Grid: v = 20:5:100 km/h; a_y = 0.1:0.005:min(a_y,lim(v, mu = 0.8), 0.4) g (0.1 g is the lowest row of the reference table, 0.4 g its
%   highest; a_y,lim from data/plant_limits.json is what the Plant can reach). Also the natural slope between neighbouring points,
%   dT_a/dT_s (the slope the map would need to pass through every point), and the assist limit T_a,max(v) of data/ref.json
%   (T_a,max = T_a,req + F, the demand of the model at a_y,lim plus the margin F = T_f, so T_a,cal stays F below it).
%
%   Cal.v_kmh (17x1); per speed i (cells): Cal.ay_g{i}, Cal.Ts{i}, Cal.Tr{i}, Cal.Ta{i}, Cal.slope{i} (first element NaN); Cal.ay_lim_g(i), Cal.Ta_max(i).
%   Writes Result/Controllers/Map/Design/Map_calibration_points.csv and the "calibration" field of data/map.json.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
addpath(modelDir); setup_paths;
P   = map_params();
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
lim = jsondecode(fileread(fullfile(modelDir, 'data', 'plant_limits.json')));
muCol = find(abs(lim.a_y.mu - 0.8) < 1e-9);
assert(isscalar(muCol), 'plant_limits.json has no mu = 0.8 column');
v_kmh = (20:5:100)';
assert(isequal(ref.Ta_max.v_kmh(:), v_kmh), 'ref.json Ta_max speeds differ from the calibration speeds');
ayGrid = 0.1:0.005:0.4;
n = numel(v_kmh);
Cal = struct('v_kmh', v_kmh, 'ay_g', {cell(n, 1)}, 'Ts', {cell(n, 1)}, 'Tr', {cell(n, 1)}, 'Ta', {cell(n, 1)}, 'slope', {cell(n, 1)}, ...
    'ay_lim_g', zeros(n, 1), 'Ta_max', ref.Ta_max.Ta_max_Nm(:), 'F', ref.Ta_max.F_Nm);
rows = {};
for i = 1:n
    ayLim = interp1(lim.a_y.v_kmh, lim.a_y.table(:, muCol), v_kmh(i));
    Cal.ay_lim_g(i) = ayLim;
    ay = ayGrid(ayGrid <= min(ayLim, 0.4) + 1e-9);
    Ts = zeros(size(ay)); Tr = Ts; Ta = Ts;
    for j = 1:numel(ay)
        S = map_steady_state(P, v_kmh(i) / 3.6, ay(j) * P.g, 0.8);
        Ts(j) = interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ay(j), v_kmh(i), 'linear');
        Tr(j) = S.T_r;
        Ta(j) = S.T_r - Ts(j);
    end
    sl = [NaN, diff(Ta) ./ diff(Ts)];
    Cal.ay_g{i} = ay; Cal.Ts{i} = Ts; Cal.Tr{i} = Tr; Cal.Ta{i} = Ta; Cal.slope{i} = sl;
    for j = 1:numel(ay)
        rows(end+1, :) = {v_kmh(i), ay(j), Ts(j), Tr(j), Ta(j), sl(j), Cal.Ta_max(i), Cal.Ta_max(i) - Ta(j), Ta(j) > Cal.Ta_max(i) + 1e-9}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'v_kmh', 'ay_g', 'Ts_cal_Nm', 'Tr_Nm', 'Ta_cal_Nm', 'natural_slope', 'Ta_max_Nm', 'Ta_margin_Nm', 'Ta_cal_exceeds_Ta_max'});
T.Ta_cal_exceeds_Ta_max = double(T.Ta_cal_exceeds_Ta_max);
outDir = result_dir('Map', 'Design');
writetable(T, fullfile(outDir, 'Map_calibration_points.csv'));

% data/map.json: calibration points (the design, when it exists, is added by the design script)
mp = fullfile(modelDir, 'data', 'map.json');
J = struct();
if exist(mp, 'file'), J = jsondecode(fileread(mp)); end
J.x_note = 'Map controller data. calibration: dry-road points (mu = 0.8) written by Controllers/Map/script/calibrate_map.m (Ts_Nm = T_d,ref, Ta_Nm = assist that gives it).';
pts = struct('v_kmh', cell(n, 1), 'ay_g', [], 'Ts_Nm', [], 'Ta_Nm', []);
for i = 1:n
    pts(i) = struct('v_kmh', v_kmh(i), 'ay_g', Cal.ay_g{i}, 'Ts_Nm', Cal.Ts{i}, 'Ta_Nm', Cal.Ta{i});
end
J.calibration = struct('ay_step_g', 0.005, 'ay_lim_g', Cal.ay_lim_g', 'points', pts);
fid = fopen(mp, 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);

fprintf('calibrate_map: %d speeds, %d points; T_a,cal above T_a,max at %d points; written %s\n', n, height(T), sum(T.Ta_cal_exceeds_Ta_max), outDir);
end
