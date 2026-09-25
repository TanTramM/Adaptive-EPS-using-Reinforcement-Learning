function save_run_results(ctrlName, tag, data)
%SAVE_RUN_RESULTS Save the signals and a time-response figure of ONE run of a
%controller closed loop (Model_<ctrlName>_s.mdl) into Result/<ctrlName>/.
%
%   save_run_results('PID', 'S1_hold_angle_mu_step')            % data from base workspace
%   save_run_results('PID', 'S1_hold_angle_mu_step', dataStruct) % data given
%
%   Files (folder Result/<ctrlName>/):
%     <ctrlName>_<tag>_signals.csv        t, T_s, T_d_ref, e_T, T_a, a_y (10 ms grid)
%     <ctrlName>_<tag>_time_response.png  T_s vs T_d_ref, e_T, T_a
%
%   data (optional): struct with column vectors t, T_s, T_d_ref, e_T, T_a, a_y.
%   Without it the signals are read from the base-workspace timeseries
%   log_T_s, log_T_d_ref, log_e_T, log_T_a, log_a_y written by the model's
%   To Workspace blocks when it is run by hand (Run button). If they are
%   absent the function returns silently, so it is safe as the model's
%   StopFcn while scripts run the model through sim() with an output object.

    if nargin < 2 || isempty(tag)
        tag = 'manual_run';
    end
    names = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y'};

    if nargin < 3
        for i = 1:numel(names)
            if evalin('base', ['exist(''log_' names{i} ''', ''var'')']) ~= 1
                return;
            end
        end
        ts = cell(1, numel(names));
        for i = 1:numel(names)
            ts{i} = evalin('base', ['log_' names{i}]);
        end
        tg = (0:0.01:ts{1}.Time(end))';
        data.t = tg;
        for i = 1:numel(names)
            [tu, iu] = unique(ts{i}.Time, 'last');
            method = 'linear';
            if strcmp(names{i}, 'T_a')
                method = 'previous';   % T_a is held between controller samples
            end
            data.(names{i}) = interp1(tu, squeeze(ts{i}.Data(iu)), tg, method, 'extrap');
        end
    else
        step = max(1, round(0.01 / (data.t(2) - data.t(1))));   % 10 ms grid
        idx = 1:step:numel(data.t);
        data.t = data.t(idx);
        for i = 1:numel(names)
            data.(names{i}) = data.(names{i})(idx);
        end
    end

    outDir = result_dir(ctrlName);
    base = sprintf('%s_%s', ctrlName, tag);

    T = table(data.t(:), data.T_s(:), data.T_d_ref(:), data.e_T(:), data.T_a(:), data.a_y(:), ...
        'VariableNames', {'t_s', 'T_s_Nm', 'T_d_ref_Nm', 'e_T_Nm', 'T_a_Nm', 'a_y_mps2'});
    writetable(T, fullfile(outDir, [base '_signals.csv']));

    fig = figure('Visible', 'off', 'Position', [100 100 900 700]);
    subplot(3, 1, 1);
    plot(data.t, data.T_s, 'b', data.t, data.T_d_ref, 'r--'); grid on;
    ylabel('N.m'); legend('T_s (measured)', 'T_{d,ref}'); title([ctrlName ' - ' strrep(tag, '_', ' ')]);
    subplot(3, 1, 2);
    plot(data.t, data.e_T, 'k'); grid on; ylabel('e_T [N.m]'); title('e_T = T_s - T_{d,ref}');
    subplot(3, 1, 3);
    plot(data.t, data.T_a, 'm'); grid on; ylabel('T_a [N.m]'); xlabel('t [s]'); title('assist torque T_a');
    exportgraphics(fig, fullfile(outDir, [base '_time_response.png']), 'Resolution', 120);
    close(fig);
    fprintf('save_run_results: saved %s_signals.csv and %s_time_response.png in %s\n', base, base, outDir);
end
