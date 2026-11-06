%% load_plant_vdb.m
% Variables for the VDB Plant (Plant_VDB.slx, Tires_VDB.slx, Bike2DOF_VDB.slx): the same parameters as the original Plant (data/params.json, through
% load_plant.m of Model/original/PRSM/Plant, one source of data), plus the initial speed of the VDB blocks.
% Usage: run this SCRIPT (not a function) before building or simulating any VDB model; the variables live in the base workspace.
%   vdb_v0 : initial speed (m/s) of the VDB body and of the VDB wheels (their states start at this rolling speed); a run script sets it to v(0) of the case.

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/VDB/Plants/)
addpath(fullfile(modelDir, 'shared')); setup_paths;
run(fullfile(modelDir, 'original', 'PRSM', 'Plant', 'load_plant.m'));
assignin('base', 'vdb_v0', 20);
fprintf('load_plant_vdb: vdb_v0 = 20 m/s\n');
