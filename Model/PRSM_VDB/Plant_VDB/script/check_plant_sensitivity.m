function check_plant_sensitivity()
%CHECK_PLANT_SENSITIVITY Sensitivity of the PLANT itself on the SLIP baseline (T_a = 0) after the mu step to 0.24 (plan 10.10 step 4; plan section 11, step K8).
%   Runs the Plant four times up to 66.4 s: reference, relative tolerance 1e-9, Iz x (1 + 1e-4), m x (1 + 1e-4). A small change of the tolerance or of a
%   parameter must move gamma by far less than the difference seen between the unfixed VDB body and the Plant (0.145 rad/s at 66 s); otherwise the Plant itself would be
%   too sensitive to be compared with anything. Output: Result/PRSM/Plant_VDB/Plant_VDB_K8_plant_sensitivity.txt
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    addpath(modelDir); setup_paths; use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    fid = fopen(fullfile(outDir, 'Plant_VDB_K8_plant_sensitivity.txt'), 'w');
    load_plant;
    S = load(fullfile(outDir, 'baseline', 'Plant_SLIP_Ta0.mat'));
    k = S.t <= 66.4; t = S.t(k);
    runs = {'ref', 1e-6, 1, 1; 'tol1e-9', 1e-9, 1, 1; 'Iz+1e-4', 1e-6, 1.0001, 1; 'm+1e-4', 1e-6, 1, 1.0001};
    G = cell(size(runs, 1), 1);
    Iz0 = evalin('base', 'Iz'); m0 = evalin('base', 'm');
    for r = 1:size(runs, 1)
        assignin('base', 'Iz', Iz0 * runs{r, 3}); assignin('base', 'm', m0 * runs{r, 4});
        mdl = 'tmp_sens'; if bdIsLoaded(mdl), close_system(mdl, 0); end
        load_system(fullfile(modelDir, 'PRSM', 'Plant', 'Plant.mdl')); new_system(mdl);
        add_block('Plant/Plant', [mdl '/DUT']); close_system('Plant', 0);
        dut = [mdl '/DUT']; vars = {'theta1', 'T_a', 'v', 'mu'}; ph = get_param(dut, 'PortHandles');
        for i = 1:4
            assignin('base', ['sp_' vars{i}], [t, S.(vars{i})(k)]);
            b = [mdl '/src_' vars{i}]; add_block('simulink/Sources/From Workspace', b, 'VariableName', ['sp_' vars{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
            nb = find_system(dut, 'SearchDepth', 1, 'BlockType', 'Inport', 'Name', vars{i});
            add_line(mdl, get_param(b, 'PortHandles').Outport(1), ph.Inport(str2double(get_param(nb{1}, 'Port'))));
        end
        nb = find_system(dut, 'SearchDepth', 1, 'BlockType', 'Outport', 'Name', 'gamma');
        tw = [mdl '/log_g']; add_block('simulink/Sinks/To Workspace', tw, 'VariableName', 'sp_gam', 'SaveFormat', 'Timeseries');
        add_line(mdl, ph.Outport(str2double(get_param(nb{1}, 'Port'))), get_param(tw, 'PortHandles').Inport(1));
        set_param(mdl, 'Solver', 'VariableStepAuto', 'StopTime', '66.4', 'MaxStep', '0.002', 'RelTol', num2str(runs{r, 2}), 'SaveOutput', 'off', 'ReturnWorkspaceOutputs', 'on');
        Simulink.sdi.clear; o = sim(Simulink.SimulationInput(mdl));
        G{r} = interp1(o.sp_gam.Time, squeeze(o.sp_gam.Data), t); close_system(mdl, 0);
    end
    assignin('base', 'Iz', Iz0); assignin('base', 'm', m0);
    fprintf(fid, 'K8 Plant sensitivity on SLIP (T_a = 0), %s\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    for T = [60 62 63 64 65 66 66.4]
        i = find(t >= T, 1); fprintf(fid, 't=%.1f gamma:', T);
        for r = 1:size(runs, 1), fprintf(fid, '  %s %.5f', runs{r, 1}, G{r}(i)); end
        fprintf(fid, '\n');
    end
    fprintf(fid, 'max |gamma - ref| over 60-66.4 s: ');
    w = t >= 60; for r = 2:size(runs, 1), fprintf(fid, '%s %.2e   ', runs{r, 1}, max(abs(G{r}(w) - G{1}(w)))); end
    fprintf(fid, '\n'); fclose(fid);
    type(fullfile(outDir, 'Plant_VDB_K8_plant_sensitivity.txt'));
end
