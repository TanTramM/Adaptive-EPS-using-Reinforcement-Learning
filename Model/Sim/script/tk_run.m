function [L, m] = tk_run(mdl, level, seed, vars)
%TK_RUN Run the calibration case TK (test_cases('TK')) on a closed-loop model and score it. Shared by every controller tuning.
%
%   [L, m] = tk_run('Model_SMC_s', 'high', 91001, struct('lambda', 100, 'Phi', 1.5))
%
%   mdl    closed-loop model built by build_closed_loop (already built; its base-workspace variables loaded by load_<ctrl>.m)
%   level  sensor level 'none' | 'high' (data/sensors.json), seed = noise seed (91001... for tuning: outside the training range of
%          RL, 1-9999, and the scoring range of the comparisons, 90001-90010)
%   vars   struct of base-workspace variables overridden for this run only (Simulink.SimulationInput.setVariable); [] for none
%   L      logged TRUE signals on the 1 ms grid of the case: t, T_s, T_d_ref, e_T, T_a (applied), T_a_cmd (controller command)
%   m      scores on the TRUE signals, first 2 s not scored (Documents/Map_6_8/map.txt section 2.5, equation (16)):
%            R       RMS e_T over all scored windows of TK [N.m]                  (response)
%            S       RMS of T_a high-passed at 5 Hz over the whole case [N.m]     (smoothness: what no driver command explains)
%            TV      total variation of T_a per second [N.m/s]
%            maxTa   largest |T_a| [N.m]
%            erel    steady accuracy: worst over the hard-cornering windows of |mean e_T| / mean |T_d,ref| [%]
%            Scmd    the same high-pass RMS of the controller command T_a_cmd [N.m] (shows chattering that the motor limit hides)

S = test_cases('TK');
assignin('base', 'sc_theta1', [S.t S.theta1]);
assignin('base', 'sc_v',      [S.t S.v]);
assignin('base', 'sc_mu',     [S.t S.mu]);
modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/
if ~bdIsLoaded(mdl), load_system(mdl); end
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime', sprintf('%.15g', S.t(end)));
V = sensor_noise_vars(level, seed);
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

function m = tk_score(L, S)
    win = S.win;
    w = L.t >= 2;
    inResp = false(size(L.t));
    for j = 1:numel(win), inResp = inResp | (L.t >= win(j).t0 & L.t <= win(j).t1); end
    m.R = sqrt(mean(L.e_T(inResp).^2));
    dt = L.t(2) - L.t(1);
    a = dt / (1 / (2 * pi * 5) + dt);
    hp = L.T_a - filter(a, [1 -(1 - a)], L.T_a);
    m.S = sqrt(mean(hp(w).^2));
    hc = L.T_a_cmd - filter(a, [1 -(1 - a)], L.T_a_cmd);
    m.Scmd = sqrt(mean(hc(w).^2));
    m.TV = sum(abs(diff(L.T_a(w)))) / (L.t(end) - 2);
    m.maxTa = max(abs(L.T_a(w)));
    er = [];
    for j = find(startsWith({win.label}, 'steady'))
        in = L.t >= win(j).t0 & L.t <= win(j).t1;
        er(end+1) = 100 * abs(mean(L.e_T(in))) / max(mean(abs(L.T_d_ref(in))), eps); %#ok<AGROW>
    end
    m.erel = max(er);
end
