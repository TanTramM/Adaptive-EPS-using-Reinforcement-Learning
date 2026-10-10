function [L, m] = tk_run(mdl, runSeed, vars)
%TK_RUN Run the calibration case TK (test_cases('TK')) on a closed-loop model and score it. Shared by every controller tuning.
%
%   [L, m] = tk_run('Model_Map', 0, struct('Kmax', 8))
%
%   mdl    closed-loop model built by build_closed_loop (already built; its base-workspace variables loaded by load_<ctrl>.m)
%   runSeed  [] = ideal sensors, a number = noisy sensors with that run seed (data/sensors.json). Tuning seeds come from the controller's own
%            range (Map 0-9999, PI 10000-19999, SMC 20000-29999); 99999, 99998... are reserved for scoring the standard test cases.
%   vars   struct of base-workspace variables overridden for this run only (Simulink.SimulationInput.setVariable); [] for none
%   L      logged TRUE signals on the 1 ms grid of the case: t, T_s, T_d_ref, e_T, T_a (applied), T_a_cmd (controller command)
%   m      scores on the TRUE signals, first 2 s not scored (QuyChuan.txt part 4):
%            R       response error [%]: mean of the four group errors R_g = 100 RMS(e_T) / mean|T_d,ref| over the windows of group g
%                    (static = steady cornering 0.1-0.4 g, dyn = sine, small = small corrections, mu = the 2 s after each mu step);
%                    equal weights; the groups are in m.Rg (struct) and m.RgNm (RMS e_T in N.m)
%            S       RMS of T_a high-passed at 5 Hz over the whole case [N.m]     (smoothness: what no driver command explains)
%            Scmd    the same high-pass RMS of the controller command T_a_cmd [N.m] (shows chattering that the motor limit hides)
%            TV      total variation of T_a per second [N.m/s]
%            maxTa   largest |T_a| [N.m]
%            erel    steady accuracy [%]: worst over the static windows of 100 |mean e_T| / mean |T_d,ref|; per window in m.erelWin
%                    (labels in m.erelLabel); m.erelSigned = the same with the sign of mean e_T (negative = over-assist)
%            rev     reverse assist: fraction of scored samples with |T_s| >= 0.5 N.m and T_a against T_s [-]

S = test_cases('TK');
assignin('base', 'sc_theta1', [S.t S.theta1]);
assignin('base', 'sc_v',      [S.t S.v]);
assignin('base', 'sc_mu',     [S.t S.mu]);
modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
if ~bdIsLoaded(mdl), load_system(mdl); end
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
V = sensor_noise_vars(runSeed);
fn = fieldnames(V);
for k = 1:numel(fn), in = in.setVariable(fn{k}, V.(fn{k})); end
if ~isempty(vars)
    fn = fieldnames(vars);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, vars.(fn{k})); end
end
so = sim(in);
L.t = S.t;
for nm = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'T_a_cmd'}
    ts = so.get(['log_' nm{1}]);
    [tu, iu] = unique(ts.Time, 'last');
    L.(nm{1}) = interp1(tu, squeeze(ts.Data(iu)), S.t, 'linear', 'extrap');
end
m = tk_score(L, S);
end
