function T = map_bangbang_scan(candFile, outFile, limitFraction)
%MAP_BANGBANG_SCAN Evaluate the no-bang-bang gate (tk_bangbang.m) for Map candidates on case TK (117 s).
%
%   T = map_bangbang_scan()
%   T = map_bangbang_scan(candFile, outFile, limitFraction)
%
%   Checks whether sensor noise pushes the controller command T_a_cmd to the assist limit T_a,max(v).
%   Runs case TK twice (ideal sensors and noisy sensors with local seed 00000).
%   delta = f_sat_noisy - f_sat_ideal <= limitFraction (default 0.01 = 1%).
%   Resumable: K values already present in outFile are skipped.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

outDir = result_dir('Map', 'Design');
if nargin < 1 || isempty(candFile)
    candFile = fullfile(outDir, 'Map_candidates_TK.csv');
end
if nargin < 2 || isempty(outFile)
    outFile = fullfile(outDir, 'Map_bangbang_by_K.csv');
end
if nargin < 3 || isempty(limitFraction)
    limitFraction = 0.01;
end

if ~exist(candFile, 'file')
    error('map_bangbang_scan:missing_cand', 'Candidates file not found: %s', candFile);
end
C = readtable(candFile);

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
Cal = calibrate_map_cached();
mdl = 'Model_Map';
if ~bdIsLoaded(mdl), load_system(mdl); end

rows = [];
if exist(outFile, 'file')
    try
        oldT = readtable(outFile);
        rows = table2array(oldT(:, {'K', 'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'pass_no_bangbang'}));
    catch
        rows = [];
    end
end

for i = 1:height(C)
    kVal = C.K(i);
    if ~isempty(rows) && any(abs(rows(:, 1) - kVal) < 1e-6)
        continue;
    end
    
    zVal = C.z_rad_s(i);
    pVal = C.p_rad_s(i);
    if isnan(zVal) || isnan(pVal)
        % Unstable candidate without lead
        rows = [rows; kVal, NaN, NaN, NaN, 0]; %#ok<AGROW>
        continue;
    end
    
    d = struct('Ts_ctrl', 0.001, 'Ts0', 0.3, 'Kmax', kVal, 'lead', struct('z', zVal, 'p', pVal));
    vars = map_variables(Cal, d);
    
    B = tk_bangbang(mdl, 00000, vars, limitFraction);
    rows = [rows; kVal, B.f_ideal, B.f_noisy, B.delta, double(B.pass)]; %#ok<AGROW>
    
    fprintf('map_bangbang_scan: K=%.2f | f_ideal=%.4f, f_noisy=%.4f, delta=%.4f, pass=%d\n', ...
        kVal, B.f_ideal, B.f_noisy, B.delta, B.pass);
    
    outT = array2table(sortrows(rows, 1), 'VariableNames', ...
        {'K', 'f_sat_ideal', 'f_sat_noisy', 'f_sat_delta', 'pass_no_bangbang'});
    writetable(outT, outFile);
end

T = readtable(outFile);
end

