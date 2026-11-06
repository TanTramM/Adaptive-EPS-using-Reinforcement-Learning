function smoke_temp_test(tEnd)
%SMOKE_TEMP_TEST Short run of the nine temporary loops of build_temp_test.m and of the three original loops on the same simple input, to see whether anything is wrong.
%   smoke_temp_test([tEnd])   tEnd in s (default 4). Input: theta1 steps from 0 to 0.15 rad at 0.5 s, v = 20 m/s, mu = 0.8, ideal sensors. NOT one of the scoring cases (no SSW).
%   Prints, for every VDB loop, the relative RMS difference of T_s and T_a to the original loop of the same controller (RMS difference / max |original|), and a finite-value check.
%   The controller parameters are those of the original loaders (load_<ctrl>.m); load_plant_vdb adds vdb_v0. Nothing is written to Result/.
    if nargin < 1, tEnd = 4; end
    scriptDir = fileparts(mfilename('fullpath'));
    tempDir = fileparts(scriptDir);
    modelDir = fileparts(fileparts(tempDir));
    addpath(fullfile(modelDir, 'shared')); setup_paths; use_sim_tmp;
    warning('off', 'all');
    t = (0:0.001:tEnd)';
    ctrls = {'Map', 'PID', 'MapPID'}; loaders = {'load_map', 'load_pid', 'load_mappid'};
    tags = {'VDBTire', 'VDBBody', 'VDBTireBody'};
    for c = 1:numel(ctrls)
        evalin('base', loaders{c}); evalin('base', 'load_plant_vdb');
        assignin('base', 'sc_theta1', [t, 0.15 * (t >= 0.5)]);
        assignin('base', 'sc_v', [t, 20 * ones(size(t))]);
        assignin('base', 'sc_mu', [t, 0.8 * ones(size(t))]);
        ref = runLoop(fullfile(modelDir, 'original', 'Controllers', ctrls{c}, ['Model_' ctrls{c} '.mdl']), tEnd);
        fprintf('%-7s original: T_s end %.4f N.m, T_a end %.4f N.m\n', ctrls{c}, ref.T_s(end), ref.T_a(end));
        for k = 1:numel(tags)
            f = fullfile(tempDir, ctrls{c}, ['Model_' ctrls{c} '_' tags{k} '.slx']);
            try
                r = runLoop(f, tEnd);
                eTs = sqrt(mean((r.T_s - ref.T_s).^2)) / max(abs(ref.T_s)); eTa = sqrt(mean((r.T_a - ref.T_a).^2)) / max(abs(ref.T_a));
                fprintf('%-7s %-11s: T_s diff %.4f %%, T_a diff %.4f %%, finite %d\n', ctrls{c}, tags{k}, 100 * eTs, 100 * eTa, all(isfinite([r.T_s; r.T_a])));
            catch ME
                fprintf('%-7s %-11s: RUN ERROR: %s\n', ctrls{c}, tags{k}, strtrim(ME.message(1:min(250, numel(ME.message)))));
            end
        end
    end
end

function L = runLoop(file, tEnd)
    [~, mdl] = fileparts(file);
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(file);
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', tEnd));
    Simulink.sdi.clear; so = sim(in);
    t = (0:0.001:tEnd)';
    for nm = {'T_s', 'T_a'}
        ts = so.get(['log_' nm{1}]); [tu, iu] = unique(ts.Time, 'last');
        L.(nm{1}) = interp1(tu, squeeze(ts.Data(iu)), t, 'linear', 'extrap');
    end
    close_system(mdl, 0);
end
