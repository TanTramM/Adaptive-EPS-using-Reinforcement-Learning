%% load_map.m
% Base workspace variables of the Map controller (Map_Ts_ctrl, Map_v_bp, Map_Ts_bp, Map_table, Map_H_num/den) from data/map.json
% (the design written by Controllers/Map/script/design_map.m), and the Plant, Ref, Sensors, AssistLimit and Actuator variables through
% load_plant, load_ref, load_sensors, load_assistlimit, load_actuator. One slope limit K_max and one lead for every speed.
%
% Usage: run this SCRIPT before building or simulating Map / Model_Map.
%   >> run('<Model>/Controllers/Map/load_map.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/Controllers/Map/)
addpath(modelDir); setup_paths;

run(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'));
run(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'));
run(fullfile(modelDir, 'PRSM', 'Sensors', 'load_sensors.m'));
run(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'));
run(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'));

J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
assert(isfield(J, 'design'), 'data/map.json has no design yet - run design_map.m (or set the field by hand)');

Cal = calibrate_map_cached();
V = map_variables(Cal, J.design);
fn = fieldnames(V);
for i = 1:numel(fn)
    assignin('base', fn{i}, V.(fn{i}));
end

fprintf('load_map: K_max = %g, lead z %g p %g rad/s, dead zone %g N.m, Ts_ctrl %g ms\n', ...
    J.design.Kmax, J.design.lead.z, J.design.lead.p, J.design.Ts0, 1000 * J.design.Ts_ctrl);

