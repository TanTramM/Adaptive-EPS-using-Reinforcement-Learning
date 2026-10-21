function R = check_drews(ctrlName)
%CHECK_DREWS Feasibility check of the DREWS v2 cases (KeHoach_DREWS_v2.txt 1.6 and 3.3): can the open-loop driver follow every segment?
%
%   R = check_drews('PID')     run load_<ctrl> first; ideal sensors; ONE controller is used only to make the closed loop run (the check is about the driver
%                              and the grip, not about the controller: the numbers must not be used to adjust a case in favour of any controller)
%
%   Per case: duration (must be 60.000 s), largest hand-wheel angle, largest grip use |a_y| / (mu g) of the TARGET and of the ACHIEVED a_y, and per window the
%   achieved mean a_y against the target mean (the achieved a_y is the Plant output, so it includes the effect of the controller on the column torque).
%   Writes Result/Compare/DREWS_v2_check/DREWS_v2_check_<ctrl>_windows.csv and ..._cases.csv.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
mdl = ['Model_' ctrlName];
g = 9.81;
TC = make_cases();
outDir = result_dir('Compare', 'DREWS_v2_check');
rowsC = {}; rowsW = {};
for k = 1:numel(TC)
    S = TC(k);
    assignin('base', 'sc_theta1', [S.t S.theta1]);
    assignin('base', 'sc_v',      [S.t S.v]);
    assignin('base', 'sc_mu',     [S.t S.mu]);
    if ~bdIsLoaded(mdl), load_system(mdl); end
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
    so = sim(in);
    ts = so.get('log_a_y'); [tu, iu] = unique(ts.Time, 'last');
    ay = interp1(tu, squeeze(ts.Data(iu)), S.t, 'linear', 'extrap');   % m/s^2
    tT = so.get('log_T_d_ref'); [tu, iu] = unique(tT.Time, 'last');
    Td = interp1(tu, squeeze(tT.Data(iu)), S.t, 'linear', 'extrap');
    Simulink.sdi.clear;
    ayg = ay / g;
    w = S.t >= 2;
    useT = abs(S.ayTarget) ./ S.mu;
    useA = abs(ayg) ./ S.mu;
    rowsC(end+1, :) = {S.tag, S.t(end), max(abs(S.theta1)) * 180 / pi, max(useT(w)), max(useA(w)), max(abs(ayg(w))), min(S.v) * 3.6, max(S.v) * 3.6, min(S.mu), max(S.mu)}; %#ok<AGROW>
    for j = 1:numel(S.win)
        in = S.t >= S.win(j).t0 & S.t <= S.win(j).t1;
        tg = mean(S.ayTarget(in)); ac = mean(ayg(in));
        rowsW(end+1, :) = {S.tag, S.win(j).label, S.win(j).t0, S.win(j).t1, tg, ac, 100 * (abs(ac) - abs(tg)) / max(abs(tg), 0.02), max(abs(S.ayTarget(in))), max(abs(ayg(in))), 100 * (max(abs(ayg(in))) / max(max(abs(S.ayTarget(in))), 1e-9) - 1), max(abs(Td(in))), max(useT(in)), max(useA(in)), mean(S.mu(in))}; %#ok<AGROW>
    end
    fprintf('check_drews: %s done\n', S.tag);
end
Rc = cell2table(rowsC, 'VariableNames', {'Case', 'Duration_s', 'MaxHandWheel_deg', 'MaxGripUseTarget', 'MaxGripUseAchieved', 'MaxAy_g', 'Vmin_kmh', 'Vmax_kmh', 'MuMin', 'MuMax'});
Rw = cell2table(rowsW, 'VariableNames', {'Case', 'Window', 't0', 't1', 'AyTargetMean_g', 'AyAchievedMean_g', 'AyErr_pct_of_target', 'AyTargetPeak_g', 'AyAchievedPeak_g', 'AyPeakErr_pct', 'TdRefPeak_Nm', 'GripUseTargetMax', 'GripUseAchievedMax', 'MuMean'});
writetable(Rc, fullfile(outDir, sprintf('DREWS_v2_check_%s_cases.csv', ctrlName)));
writetable(Rw, fullfile(outDir, sprintf('DREWS_v2_check_%s_windows.csv', ctrlName)));
R.cases = Rc; R.windows = Rw;
disp(Rc); disp(Rw);
evalin('base', 'clear sc_theta1 sc_v sc_mu');
end
