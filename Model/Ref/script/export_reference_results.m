function export_reference_results()
%EXPORT_REFERENCE_RESULTS Save the reference torque T_d,ref(v, a_y) of the
%Reference block (Table 4 of [7], data/ref.json) as a figure and a table.
%
%   Reads data/ref.json directly (independent of the base workspace) and
%   saves to <repo>/Result/Reference/:
%     Reference_Tdref_table4_vs_ay_by_speed.png   T_d,ref vs a_y, one line per speed
%     Reference_Tdref_table4_long_format.csv      v_kmh, ay_g, Tdref_Nm (all 20 cells)

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir);                              % result_dir

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_kmh = raw.v_breakpoints_kmh(:)';
ay_g  = raw.ay_breakpoints_g(:)';
tbl   = raw.table_Nm;          % row = a_y, column = v

outDir = result_dir('Reference');

[V, A] = meshgrid(v_kmh, ay_g);
T = table(V(:), A(:), tbl(:), 'VariableNames', {'v_kmh', 'ay_g', 'Tdref_Nm'});
writetable(T, fullfile(outDir, 'Reference_Tdref_table4_long_format.csv'));

fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
plot(ay_g, tbl, 'o-'); grid on;
legend(arrayfun(@(v) sprintf('%d km/h', v), v_kmh, 'UniformOutput', false), 'Location', 'northwest');
xlabel('a_y [g]'); ylabel('T_{d,ref} [N.m]');
title('Reference torque T_{d,ref}(v, a_y), Table 4 of [7]');
exportgraphics(fig, fullfile(outDir, 'Reference_Tdref_table4_vs_ay_by_speed.png'), 'Resolution', 120);
close(fig);
fprintf('export_reference_results: saved 2 files in %s\n', outDir);
end
