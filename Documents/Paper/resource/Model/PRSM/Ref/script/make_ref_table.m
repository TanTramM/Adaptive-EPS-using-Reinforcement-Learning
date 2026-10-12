function make_ref_table()
%MAKE_REF_TABLE Build the fine reference table T_d,ref(v, a_y) from Table 4 of [5] and store it in data/ref.json.
%
%   Documents/Ref/ref.txt section 1.3:
%     - add the point a_y = 0 -> T_d,ref = 0 at every speed (self-chosen (4)),
%     - interpolate with monotone piecewise-cubic Hermite polynomials (PCHIP, self-chosen (5)), first along a_y at
%       each source speed, then along v,
%     - sample on the grid v = 20:5:100 km/h, a_y = 0:0.025:0.4 g.
%   The Reference block interpolates this fine table linearly and multiplies by sgn(a_y) (odd in a_y).
%   The source table (fields v_breakpoints_kmh, ay_breakpoints_g, table_Nm) is kept unchanged; the result is
%   written to the field "fine".
%
%   Usage: >> make_ref_table     (then run load_ref)

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
modelDir  = fileparts(fileparts(fileparts(scriptDir)));   % Model/
jsonPath  = fullfile(modelDir, 'data', 'ref.json');
raw = jsondecode(fileread(jsonPath));

v0 = raw.v_breakpoints_kmh(:);
a0 = [0; raw.ay_breakpoints_g(:)];
T0 = [zeros(1, numel(v0)); raw.table_Nm];      % rows a_y, columns v

vF = (20:5:100)';
aF = (0:0.025:0.4)';
A  = interp1(a0, T0, aF, 'pchip');             % along a_y at each source speed: numel(aF) x numel(v0)
TF = interp1(v0, A', vF, 'pchip')';            % along v: numel(aF) x numel(vF)

raw.fine = struct( ...
    'x_note', ['Fine table of Documents/Ref/ref.txt section 1.3: Table 4 plus a_y = 0 -> 0, PCHIP along a_y then v. ' ...
               'Rows = ay_breakpoints_g, columns = v_breakpoints_kmh. Written by Model/Ref/script/make_ref_table.m.'], ...
    'v_breakpoints_kmh', vF', ...
    'ay_breakpoints_g', aF', ...
    'table_Nm', round(TF, 6));

fid = fopen(jsonPath, 'w');
fwrite(fid, jsonencode(raw, 'PrettyPrint', true));
fclose(fid);
fprintf('make_ref_table: wrote fine table %dx%d (a_y x v) to data/ref.json\n', numel(aF), numel(vF));
end
