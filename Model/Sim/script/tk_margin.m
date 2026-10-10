function res = tk_margin(mdl, runSeed, vars, m_nom)
%TK_MARGIN Verify stability margins by simulation on case TK (QuyChuan.txt 5.2).
%
%   res = tk_margin(mdl, runSeed, vars, m_nom)
%
%   Shared simulation-based stability margin check for all controllers (PI, PID, SMC, RL).
%   Runs case TK under two stress conditions:
%     (a) Actuator gain doubled: act_gain_mult = 2, ctrl_delay = 0
%     (b) Pure controller delay +1 ms (one control period): act_gain_mult = 1, ctrl_delay = 0.001 s
%   Both must remain stable. Unstable is defined as non-finite signals (NaN/Inf) or R increasing
%   by more than 2.0x relative to the nominal run (QuyChuan 5.2).
%
%   Inputs:
%     mdl      closed-loop model name, e.g. 'Model_PI' or controller name 'PI'
%     runSeed  sensor noise seed (e.g. 10000) or [] for ideal sensors
%     vars     struct of controller variables (e.g. gains) or []
%     m_nom    (optional) struct of nominal scores from tk_run; if omitted, tk_run is called
%
%   Outputs (struct res):
%     pass         true if both (a) and (b) pass at the 2.0x threshold
%     pass_gain    true if gain x2 test passes (ratio_gain <= 2.0)
%     pass_delay   true if delay +1 ms test passes (ratio_delay <= 2.0)
%     R_nom        nominal R [%]
%     R_gain       R with actuator gain x2 [%]
%     R_delay      R with controller delay +1 ms [%]
%     ratio_gain   R_gain / R_nom
%     ratio_delay  R_delay / R_nom
%     stable_gain  boolean: simulation finished and signals were finite
%     stable_delay boolean: simulation finished and signals were finite
%     sensitivity  struct with pass flags for 1.5x, 2.0x, 3.0x thresholds

if nargin < 2, runSeed = []; end
if nargin < 3, vars = []; end
if isempty(vars), vars = struct(); end

if ~startsWith(mdl, 'Model_')
    mdl = ['Model_' mdl];
end

% 1. Nominal run (if not provided)
if nargin < 4 || isempty(m_nom)
    vars_nom = vars;
    vars_nom.act_gain_mult = 1;
    vars_nom.ctrl_delay = 0;
    try
        [~, m_nom] = tk_run(mdl, runSeed, vars_nom);
        res.stable_nom = isfinite(m_nom.R) && (m_nom.R > 0);
    catch ME
        warning('tk_margin:nominal_failed', 'Nominal run failed: %s', ME.message);
        m_nom = struct('R', Inf);
        res.stable_nom = false;
    end
else
    res.stable_nom = isfinite(m_nom.R) && (m_nom.R > 0);
end
res.R_nom = m_nom.R;

if ~res.stable_nom
    res.pass = false;
    res.pass_gain = false;
    res.pass_delay = false;
    res.R_gain = Inf;
    res.R_delay = Inf;
    res.ratio_gain = Inf;
    res.ratio_delay = Inf;
    res.stable_gain = false;
    res.stable_delay = false;
    res.sensitivity = struct('gain_1p5', false, 'gain_2p0', false, 'gain_3p0', false, ...
                             'delay_1p5', false, 'delay_2p0', false, 'delay_3p0', false);
    return;
end

% 2. Condition (a): Actuator gain doubled
vars_gain = vars;
vars_gain.act_gain_mult = 2;
vars_gain.ctrl_delay = 0;
try
    [~, m_gain] = tk_run(mdl, runSeed, vars_gain);
    res.stable_gain = isfinite(m_gain.R) && (m_gain.R > 0);
    res.R_gain = m_gain.R;
    res.ratio_gain = m_gain.R / res.R_nom;
catch ME
    res.stable_gain = false;
    res.R_gain = Inf;
    res.ratio_gain = Inf;
end
res.pass_gain = res.stable_gain && (res.ratio_gain <= 2.0);

% 3. Condition (b): Pure transport delay +1 ms
vars_delay = vars;
vars_delay.act_gain_mult = 1;
vars_delay.ctrl_delay = 0.001;   % 1 ms = 1 control period
try
    [~, m_delay] = tk_run(mdl, runSeed, vars_delay);
    res.stable_delay = isfinite(m_delay.R) && (m_delay.R > 0);
    res.R_delay = m_delay.R;
    res.ratio_delay = m_delay.R / res.R_nom;
catch ME
    res.stable_delay = false;
    res.R_delay = Inf;
    res.ratio_delay = Inf;
end
res.pass_delay = res.stable_delay && (res.ratio_delay <= 2.0);

% 4. Primary pass flag & sensitivity
res.pass = res.pass_gain && res.pass_delay;

res.sensitivity = struct(...
    'gain_1p5',  res.stable_gain  && (res.ratio_gain  <= 1.5), ...
    'gain_2p0',  res.pass_gain, ...
    'gain_3p0',  res.stable_gain  && (res.ratio_gain  <= 3.0), ...
    'delay_1p5', res.stable_delay && (res.ratio_delay <= 1.5), ...
    'delay_2p0', res.pass_delay, ...
    'delay_3p0', res.stable_delay && (res.ratio_delay <= 3.0));

strGain = 'FAIL'; if res.pass_gain, strGain = 'PASS'; end
strDelay = 'FAIL'; if res.pass_delay, strDelay = 'PASS'; end
strOverall = 'FAIL'; if res.pass, strOverall = 'PASS'; end

fprintf('[tk_margin] %s: Gain x2 R=%.2f%% (x%.2f, %s) | Delay +1ms R=%.2f%% (x%.2f, %s) => Margin: %s\n', ...
    mdl, res.R_gain, res.ratio_gain, strGain, res.R_delay, res.ratio_delay, strDelay, strOverall);

end

