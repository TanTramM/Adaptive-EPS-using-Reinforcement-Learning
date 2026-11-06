function run_ssw_temp(ctrl, tag, seed)
%RUN_SSW_TEMP Run the SSW cases (STEADY, SLIP, WEAVE) of one temporary VDB loop and write the results in Model/VDB/temp_test/<ctrl>/Result/ (NOT in Result/).
%   run_ssw_temp('Map', 'VDBTire', 99987)   loop Model_<ctrl>_<tag>.slx, run seed 99987 (the seed of the paper SSW figures, Result/Compare/SSW_summary/fullrate/*_s99987.csv)
%   Uses the shared run_cases (metrics and 10 ms signals) and export_ssw_signals (1 ms signals) with their optional output folder, so the numbers are made exactly as for the
%   original controller; the controller parameters are those of the original loader (load_<ctrl>.m); load_plant_vdb adds vdb_v0, set per case to v(0).
%   Files (name = <ctrl>_<tag>): <name>_metrics_s<seed>.csv, <name>_<CASE>_sig_s<seed>.csv (10 ms), <name>_<CASE>_sig1ms_s<seed>.csv (1 ms).
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(tempDir));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    addpath(fullfile(tempDir, ctrl));
    loader = ['load_' lower(ctrl)];
    evalin('base', loader); evalin('base', 'load_plant_vdb');
    name = [ctrl '_' tag];
    outDir = fullfile(tempDir, ctrl, 'Result');
    run_cases(name, seed, 'SSW', outDir);
    export_ssw_signals(name, seed, outDir);
    fprintf('run_ssw_temp: %s seed %d written to %s\n', name, seed, outDir);
end
