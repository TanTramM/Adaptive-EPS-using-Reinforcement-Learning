function export_ssw_signals(ctrlName, runSeed)
%EXPORT_SSW_SIGNALS Run the SSW scoring cases (STEADY, SLIP, WEAVE) of ONE controller and save the signals at the full 1 ms rate.
%
%   export_ssw_signals('MapPID', 99999)
%
%   Same model, parameters, cases and noise as run_cases(ctrlName, runSeed, 'SSW'), which stores only every tenth sample. This function writes
%   Result/Controllers/<ctrl>/Cases_ssw_1ms/<ctrl>_<CASE>_sig1ms_<sens>.csv with t, v, mu, T_s, T_d_ref, e_T, T_a (every 1 ms sample) and
%   leaves the existing metrics and 10 ms files untouched. Run load_<ctrl> in the base workspace first; Simulink.sdi.clear after every case.

scriptDir = fileparts(mfilename('fullpath'));   % Sim/script
modelDir  = fileparts(fileparts(scriptDir));    % Model/
addpath(modelDir); setup_paths;
noiseVars = sensor_noise_vars(runSeed);
sens = sensor_tag(runSeed);
outDir = fullfile(fileparts(result_dir(ctrlName, 'CasesSSW')), 'Cases_ssw_1ms');
if ~isfolder(outDir), mkdir(outDir); end
mdl = ['Model_' ctrlName];
TC = make_cases('SSW');
for k = 1:numel(TC)
    S = TC(k);
    L = runCase(mdl, S, noiseVars);
    T = table(L.t, L.v, L.mu, L.T_s, L.T_d_ref, L.e_T, L.T_a, 'VariableNames', {'t', 'v_mps', 'mu', 'T_s', 'T_d_ref', 'e_T', 'T_a'});
    writetable(T, fullfile(outDir, sprintf('%s_%s_sig1ms_%s.csv', ctrlName, S.tag, sens)));
    Simulink.sdi.clear;
    fprintf('export_ssw_signals: %s %s seed %d done (RMS e_T %.4f N.m)\n', ctrlName, S.tag, runSeed, sqrt(mean(L.e_T(L.t >= 2).^2)));
end
end

function L = runCase(mdl, S, noiseVars)
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_v',      [S.t S.v]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    if ~bdIsLoaded(mdl), load_system(mdl); end
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    fn = fieldnames(noiseVars);
    for k = 1:numel(fn)
        in = in.setVariable(fn{k}, noiseVars.(fn{k}));
    end
    so = sim(in);
    L.t = S.t; L.v = S.v; L.mu = S.mu;
    names = {'T_s', 'T_d_ref', 'e_T', 'T_a'};
    for i = 1:numel(names)
        ts = so.get(['log_' names{i}]);
        [tu, iu] = unique(ts.Time, 'last');
        method = 'linear';
        if strcmp(names{i}, 'T_a'), method = 'previous'; end   % held between controller samples, as in run_cases
        L.(names{i}) = interp1(tu, squeeze(ts.Data(iu)), S.t, method, 'extrap');
    end
end
