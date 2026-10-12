%% load_ref.m
% Read the reference table T_d,ref(v, a_y) from data/ref.json (SEPARATE from
% params.json/load_plant.m), convert units to SI, and push it into the base
% workspace so the Reference model (2-D Lookup Table) references it DIRECTLY
% by variable name - the Reference model only READS, it does not compute or
% embed any numbers.
%
% The table used is the FINE table (field "fine" of ref.json, written by
% Ref/script/make_ref_table.m, Documents/Ref/ref.txt section 1.3): Table 4 of
% [5] plus the point a_y = 0 -> 0, PCHIP-interpolated onto v = 20:5:100 km/h,
% a_y = 0:0.025:0.4 g. The block interpolates it linearly and multiplies by
% sgn(a_y); because the table contains a_y = 0 -> 0, T_d,ref is continuous
% when a_y changes sign.
%
% Variables created in the base workspace:
%   Tdref_v_bp_ms   - v-axis breakpoints, m/s (17 points)
%   Tdref_ay_bp_ms2 - a_y-axis breakpoints, m/s^2 (17 points)
%   Tamax_v_bp_ms, Tamax_table - assist limit T_a,max(v): speed breakpoints [m/s] and values [N.m] (only if ref.json has Ta_max)
%   Tdref_table     - T_d,ref table [N.m], row = v, column = a_y (TRANSPOSED
%                     relative to fine.table_Nm in ref.json, whose rows are a_y)
%
% Usage: run this script BEFORE building/simulating the Reference model.
% Works from any current working directory.
%   >> load_ref
%   >> build_reference

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/PRSM/Ref/)
addpath(modelDir); setup_paths;
raw = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
assert(isfield(raw, 'fine'), 'data/ref.json has no fine table - run Ref/script/make_ref_table.m first.');

Tdref_v_bp_ms   = raw.fine.v_breakpoints_kmh(:)' / 3.6;
Tdref_ay_bp_ms2 = raw.fine.ay_breakpoints_g(:)' * 9.81;
Tdref_table     = raw.fine.table_Nm';   % transpose -> row = v, column = a_y

assignin('base', 'Tdref_v_bp_ms',   Tdref_v_bp_ms);
assignin('base', 'Tdref_ay_bp_ms2', Tdref_ay_bp_ms2);
assignin('base', 'Tdref_table',     Tdref_table);

% Assist limit T_a,max(v) (Documents/Ref/ref.txt section 1.5), written by Ref/script/make_ta_max.m; used by the controllers.
if isfield(raw, 'Ta_max')
    assignin('base', 'Tamax_v_bp_ms', raw.Ta_max.v_kmh(:)' / 3.6);
    assignin('base', 'Tamax_table',   raw.Ta_max.Ta_max_Nm(:)');
end

fprintf('Loaded data/ref.json (fine table): %d speeds x %d a_y points, T_d,ref(0) = 0\n', ...
    size(Tdref_table, 1), size(Tdref_table, 2));
