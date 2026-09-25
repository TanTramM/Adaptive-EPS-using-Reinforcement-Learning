%% load_ref.m
% Read the reference data T_d,ref(v,a_y) from data/ref.json (SEPARATE from
% params.json/load_plant.m), convert units to SI, and push it into the
% base workspace so the Reference model (2-D Lookup Table) references it
% DIRECTLY by variable name - the Reference model only READS, it does not
% compute or embed any numbers.
%
% Variables created in the base workspace:
%   Tdref_v_bp_ms   - v-axis breakpoints, m/s (5 points)
%   Tdref_ay_bp_ms2 - a_y-axis breakpoints, m/s^2 (4 points)
%   Tdref_table     - T_d,ref table [N.m], size 5x4 (row=v, column=a_y,
%                     TRANSPOSED relative to table_Nm in ref.json, which
%                     keeps the original layout of Table 4: row=a_y)
%
% Usage: run this script BEFORE building/simulating the Reference model.
% Works from any current working directory (absolute path from the
% script's own location).
%   >> load_ref
%   >> build_reference

scriptDir = fileparts(mfilename('fullpath'));   % Model/
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'ref.json')));

v_bp_kmh  = raw.v_breakpoints_kmh(:)';
ay_bp_g   = raw.ay_breakpoints_g(:)';
table_Nm  = raw.table_Nm;   % row=a_y (4), column=v (5) - original layout

Tdref_v_bp_ms   = v_bp_kmh / 3.6;
Tdref_ay_bp_ms2 = ay_bp_g * 9.81;
Tdref_table     = table_Nm';   % transpose -> row=v (5), column=a_y (4)

assignin('base', 'Tdref_v_bp_ms',   Tdref_v_bp_ms);
assignin('base', 'Tdref_ay_bp_ms2', Tdref_ay_bp_ms2);
assignin('base', 'Tdref_table',     Tdref_table);

fprintf('Loaded data/ref.json: v_bp=[%s] m/s, ay_bp=[%s] m/s^2, table %dx%d\n', ...
    num2str(Tdref_v_bp_ms), num2str(Tdref_ay_bp_ms2), size(Tdref_table,1), size(Tdref_table,2));
