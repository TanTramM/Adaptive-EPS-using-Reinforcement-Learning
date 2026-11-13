function run_weave_branches(step, seed)
%RUN_WEAVE_BRANCHES Job B (Documents/Shared/KeHoach_WEAVE_HaiNhanh.txt): run the WEAVE case of Model_MapPID and log the branches of the command.
%
%   run_weave_branches('W1')     log u_map, u_P, u_I, u_D, T_a_cmd (signal logging switched on IN MEMORY only; the model is never saved) -> MapPID_WEAVE_branch_s99999.csv
%   run_weave_branches('W3')     diagnostic runs D1 (Map branch without the lag), D2 (H = 1), D3 (dead zone 0) -> MapPID_WEAVE_diag_<D1|D2|D3>_s99999.csv
%   Diagnostics only: they are NOT controllers, no parameter is re-chosen, nothing is written back to any file.
%   Own cache folder D:\sim_cache\weave (the ROBUST job may run Model_MapPID at the same time); Simulink.sdi.clear after every run; close_system(mdl, 0).
if nargin < 2, seed = 99999; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(fileparts(scriptDir))));   % Model/
addpath(fullfile(modelDir, 'shared')); setup_paths;
addpath(fullfile(modelDir, 'VDB', 'Blocks', 'script'));
use_sim_tmp;
Simulink.fileGenControl('set', 'CacheFolder', 'D:\sim_cache\weave', 'CodeGenFolder', 'D:\sim_cache\weave', 'createDir', true);
free = java.io.File('C:\').getFreeSpace / 2^30;
fprintf('free space on C: %.1f GB\n', free);
assert(free > 10, 'drive C has less than 10 GB free');
evalin('base', sprintf('run(''%s'')', fullfile(modelDir, 'original', 'Controllers', 'MapPID', 'load_mappid.m')));   % in the BASE workspace: the load script overwrites variables such as seed
mdl = 'Model_MapPID';
load_system(mdl);
cleanup = onCleanup(@() close_system(mdl, 0));
outDir = fullfile(fileparts(result_dir('MapPID', 'CasesSSW')), 'Cases_ssw_branch');
if ~isfolder(outDir), mkdir(outDir); end
sens = sensor_tag(seed);
TC = make_cases('SSW'); S = TC(strcmp({TC.tag}, 'WEAVE'));
noiseVars = sensor_noise_vars(seed);
oldFile = fullfile(fileparts(result_dir('MapPID', 'CasesSSW')), 'Cases_ssw_1ms', sprintf('MapPID_WEAVE_sig1ms_%s.csv', sens));
switch step
    case 'W1'
        b = 'Model_MapPID/Model_MapPID/MapPID';
        src = {'u_map', [b '/Cal u_map']; 'u_P', [b '/Prod_P']; 'u_I', [b '/Int_uI']; 'u_D', [b '/Sum_d']; 'T_a_cmd_port', [b '/Sum_Ta']};
        % the four wires into Sum_Ta start at these blocks (found from the model, see the log): Goto tags u_map, u_P, u_I, u_D
        set_param(mdl, 'SignalLogging', 'on');
        for k = 1:size(src, 1)
            ph = get_param(src{k, 2}, 'PortHandles');
            set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', src{k, 1});
        end
        so = runCase(mdl, S, noiseVars);
        L = collect(so, S, {'T_s', 'T_d_ref', 'e_T', 'T_a', 'T_s_meas'}, 'linear');
        L.T_a = collect(so, S, {'T_a'}, 'previous').T_a;
        ls = so.get('logsout');
        for k = 1:size(src, 1)
            L.(src{k, 1}) = holdOn(ls.get(src{k, 1}).Values, S.t);
        end
        L.T_a_cmd = L.T_a_cmd_port;
        Simulink.sdi.clear;
        sumErr = max(abs(L.u_map + L.u_P + L.u_I + L.u_D - L.T_a_cmd));
        W = readtable(oldFile);
        tsErr = max(abs(L.T_s - W.T_s)); eErr = max(abs(L.e_T - W.e_T)); taErr = max(abs(L.T_a - W.T_a));
        fprintf('W1 check (a) max|u_map+u_P+u_I+u_D - T_a_cmd| = %.3g N.m\n', sumErr);
        fprintf('W1 check (b) max|T_s - T_s of the 1 ms file| = %.3g N.m (e_T %.3g, T_a %.3g)\n', tsErr, eErr, taErr);
        assert(sumErr < 1e-9, 'W1: branch sum differs from T_a_cmd');
        assert(tsErr < 1e-9, 'W1: T_s differs from the existing file: logging changed the solution, STOP');
        T = table(S.t, L.T_s, L.T_d_ref, L.e_T, L.u_map, L.u_P, L.u_I, L.u_D, L.T_a_cmd, L.T_a, L.T_s_meas, ...
            'VariableNames', {'t', 'T_s', 'T_d_ref', 'e_T', 'u_map', 'u_P', 'u_I', 'u_D', 'T_a_cmd', 'T_a', 'T_s_meas'});
        writetable(T, fullfile(outDir, sprintf('MapPID_WEAVE_branch_%s.csv', sens)));
        fprintf('W1 written %d rows\n', height(T));
    case 'W3'
        J = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'map.json'))); Jp = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'mappid.json')));
        q = Jp.design;
        d = struct('Ts_ctrl', Jp.Ts_ctrl, 'Ts0', J.design.Ts0, 'Kmax', q.Kmax, 'lead', q.lead, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf);
        if isfield(q, 'lag'), d.lag = q.lag; end
        Cal = calibrate_map_cached();
        V0 = mappid_variables(Cal, d);
        B0 = struct('MapPID_table', evalin('base', 'MapPID_table'), 'MapPID_H_num', evalin('base', 'MapPID_H_num'), 'MapPID_H_den', evalin('base', 'MapPID_H_den'), ...
            'MapPID_Ts_bp', evalin('base', 'MapPID_Ts_bp'), 'MapPID_v_bp', evalin('base', 'MapPID_v_bp'));
        % replica check: the in-memory rebuild with the stored design equals what load_mappid put in the workspace
        fprintf('W3 replica: max|table diff| %.3g, max|H_num diff| %.3g, max|H_den diff| %.3g\n', max(abs(V0.MapPID_table(:) - B0.MapPID_table(:))), ...
            max(abs(V0.MapPID_H_num - B0.MapPID_H_num)), max(abs(V0.MapPID_H_den - B0.MapPID_H_den)));
        base = struct('MapPID_table', B0.MapPID_table, 'MapPID_H_num', B0.MapPID_H_num, 'MapPID_H_den', B0.MapPID_H_den);
        Vlead = mappid_variables(Cal, rmfield(d, 'lag'));
        d0 = d; d0.Ts0 = 0; Vdz = mappid_variables(Cal, d0);
        diag = struct('name', {'D1', 'D2', 'D3'}, ...
            'vars', {struct('MapPID_H_num', Vlead.MapPID_H_num, 'MapPID_H_den', Vlead.MapPID_H_den), ...
                     struct('MapPID_H_num', 1, 'MapPID_H_den', 1), ...
                     struct('MapPID_table', Vdz.MapPID_table)});
        fprintf('D1 H lead only: num %s den %s; table equal to the stored one: %d\n', mat2str(Vlead.MapPID_H_num, 5), mat2str(Vlead.MapPID_H_den, 5), isequal(Vlead.MapPID_table, base.MapPID_table));
        fprintf('D3 table: size %s, same breakpoints %d, first row at |T_s| = 0.1: %.4g (stored %.4g)\n', mat2str(size(Vdz.MapPID_table)), ...
            isequal(Vdz.MapPID_Ts_bp, B0.MapPID_Ts_bp) && isequal(Vdz.MapPID_v_bp, B0.MapPID_v_bp), Vdz.MapPID_table(end, 21), base.MapPID_table(end, 21));
        for k = 1:numel(diag)
            restore(base);
            f = fieldnames(diag(k).vars);
            for i = 1:numel(f), assignin('base', f{i}, diag(k).vars.(f{i})); end
            so = runCase(mdl, S, noiseVars);
            L = collect(so, S, {'T_s', 'T_d_ref', 'e_T', 'T_a'}, 'linear'); L.T_a = collect(so, S, {'T_a'}, 'previous').T_a;
            Simulink.sdi.clear;
            T = table(S.t, L.T_s, L.T_d_ref, L.e_T, L.T_a, 'VariableNames', {'t', 'T_s', 'T_d_ref', 'e_T', 'T_a'});
            writetable(T, fullfile(outDir, sprintf('MapPID_WEAVE_diag_%s_%s.csv', diag(k).name, sens)));
            fprintf('W3 %s done: RMS e_T (t >= 2) %.5f N.m\n', diag(k).name, sqrt(mean(L.e_T(S.t >= 2).^2)));
        end
        restore(base);
    otherwise
        error('run_weave_branches: unknown step %s', step);
end
end

function restore(base)
f = fieldnames(base);
for i = 1:numel(f), assignin('base', f{i}, base.(f{i})); end
end

function so = runCase(mdl, S, noiseVars)
% same as the sub function runCase of export_ssw_signals / run_cases
assignin('base', 'sc_theta1', [S.t S.theta1]);
assignin('base', 'sc_v',      [S.t S.v]);
assignin('base', 'sc_mu',     [S.t S.mu]);
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
fn = fieldnames(noiseVars);
for k = 1:numel(fn), in = in.setVariable(fn{k}, noiseVars.(fn{k})); end
so = sim(in);
end

function L = collect(so, S, names, method)
for i = 1:numel(names)
    ts = so.get(['log_' names{i}]);
    [tu, iu] = unique(ts.Time, 'last');
    L.(names{i}) = interp1(tu, squeeze(ts.Data(iu)), S.t, method, 'extrap');
end
end

function y = holdOn(ts, tq)
% value held from the last sample at or before tq (1e-9 s tolerance against rounding of the grid times)
[tu, iu] = unique(ts.Time, 'last');
y = interp1(tu, squeeze(ts.Data(iu)), tq + 1e-9, 'previous', 'extrap');
end
