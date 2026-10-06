function test_sensors(modelName)
%TEST_SENSORS Check the Sensors subsystem (add_sensors.m): on its own, then inside a closed-loop model.
%
%   test_sensors            % closed-loop part on Model_PID_s
%   test_sensors('Model_Map_6_8_s')
%
%   Run first: run('<Model>/load_pid.m') (or load_map_6_8.m) and the matching build_model_*.m.
%   Part A, Sensors alone (harness model built here, signals T_s, a_y, v; reference values computed independently from
%   data/sensors.json):
%     (1) level 'none': measured = input exactly (chain bypassed);
%     (2) level 'low' with a ramp input: measured is an integer multiple of the resolution step; it is constant inside every
%         update period (10 ms for a_y and v; 1 ms for T_s is the logging grid itself); the error to the input stays within one half
%         step plus the input change inside the period; and the value does change (at least 5 distinct values over the ramp);
%     (3) level 'high' with a constant input: mean and std of (measured - input) match a Monte Carlo of
%         step*round((c + sigma*n)/step) - c computed here (std within 8%, mean within 5 standard errors);
%     (4) same seed repeats the measured sequence, another seed is uncorrelated (|corr| < 0.1); noise of different signals is
%         uncorrelated.
%   Part B, closed loop (modelName): level 'none' gives log_*_meas == log_* exactly; the logged e_T equals T_s - T_d_ref on
%   TRUE values to 1e-9 at every level; level 'high' runs without NaN.
if nargin < 1, modelName = 'Model_PID_s'; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir);
jr = jsondecode(fileread(fullfile(modelDir, 'data', 'sensors.json')));
sig = {'T_s', 'a_y', 'v'};
step = cellfun(@(s) jr.signals.(s).resolution, sig);
per  = cellfun(@(s) jr.signals.(s).update_period, sig);
sigH = cellfun(@(s) highSigma(jr.signals.(s)), sig);

%% ---------------- Part A: Sensors alone ----------------
tEnd = 30; g = (0:1e-3:tEnd)' + 0.5e-3;          % grid at the middle of every 1 ms step
cst = [2.2034, 1.9234, 20];                      % constant inputs (not on the quantizer grid, except v = 20 m/s which is)
slope = [0.2, 0.05, 0.3];                        % ramp slopes (units/s)
A0 = runHarness('none', 90001, cst, [], g, sig, tEnd);
for i = 1:3
    assert(max(abs(A0.(sig{i}) - cst(i))) == 0, '(1) level none: %s measured differs from the input', sig{i});
end
R = runHarness('low', 90001, zeros(1, 3), slope, g, sig, tEnd);
nDistinct = zeros(1, 3);
for i = 1:3
    m = R.(sig{i}); u = slope(i) * g;
    assert(max(abs(m / step(i) - round(m / step(i)))) < 1e-6, '(2) %s measured is not a multiple of the step', sig{i});
    blk = floor(g / per(i));
    for b = unique(blk)'
        k = blk == b;
        assert(max(m(k)) - min(m(k)) == 0, '(2) %s measured changes inside an update period (block %d)', sig{i}, b);
        assert(max(abs(m(k) - u(k))) <= step(i) / 2 + slope(i) * per(i) + 1e-9, '(2) %s error beyond half a step plus the input change', sig{i});
    end
    nDistinct(i) = numel(unique(m));
    assert(nDistinct(i) >= 5, '(2) %s measured does not change over the ramp', sig{i});
end
H1 = runHarness('high', 90001, cst, [], g, sig, tEnd);
H2 = runHarness('high', 90001, cst, [], g, sig, tEnd);
H3 = runHarness('high', 90002, cst, [], g, sig, tEnd);
rng(1); nMC = 2e5;
dAll = cell(1, 3);
for i = 1:3
    idx = floor(per(i) / 1e-3) * (0:floor(tEnd / per(i)) - 1)' + 1 + floor(per(i) / 1e-3 / 2);   % middle of every update period
    d = H1.(sig{i})(idx) - cst(i);
    e = step(i) * round((cst(i) + sigH(i) * randn(nMC, 1)) / step(i)) - cst(i);
    assert(abs(std(d) / std(e) - 1) < 0.08, '(3) %s noise std %.4g, expected %.4g', sig{i}, std(d), std(e));
    assert(abs(mean(d) - mean(e)) < 5 * std(e) / sqrt(numel(d)) + 1e-12, '(3) %s noise mean %.4g, expected %.4g', sig{i}, mean(d), mean(e));
    assert(isequal(H1.(sig{i}), H2.(sig{i})), '(4) same seed does not repeat (%s)', sig{i});
    d3 = H3.(sig{i})(idx) - cst(i);
    assert(abs(corr(d, d3)) < 0.1, '(4) different seeds correlated %.3f (%s)', corr(d, d3), sig{i});
    dAll{i} = d;
end
n10 = min(cellfun(@numel, dAll));
assert(abs(corr(dAll{1}(1:n10), dAll{2}(1:n10))) < 0.1 && abs(corr(dAll{1}(1:n10), dAll{3}(1:n10))) < 0.1 && abs(corr(dAll{2}(1:n10), dAll{3}(1:n10))) < 0.1, '(4) noise of different signals correlated');

%% ---------------- Part B: closed loop ----------------
t = (0:1e-3:30)';
assignin('base', 'sc_theta1', [t, 0.3 * (1 - cos(pi * min(t, 1))) / 2]);
assignin('base', 'sc_v', [t, 20 * ones(size(t))]);
assignin('base', 'sc_mu', [t, 0.8 * ones(size(t))]);
if ~bdIsLoaded(modelName), load_system(fullfile(modelDir, [modelName '.mdl'])); end
w = t >= 2 & t <= 29;
for lv = {'none', 'low', 'high'}
    L = runLoop(modelName, lv{1}, 90001);
    assert(max(abs(L.e_T - (L.T_s - L.T_d_ref))) < 1e-9, '(B) logged e_T ~= T_s - T_d_ref at level %s', lv{1});
    assert(all(isfinite(L.T_s)) && all(isfinite(L.T_a)), '(B) NaN at level %s', lv{1});
    if strcmp(lv{1}, 'none')
        assert(max(abs(L.T_s_meas(w) - L.T_s(w))) == 0 && max(abs(L.a_y_meas(w) - L.a_y(w))) == 0, '(B) level none: measured ~= true');
    else
        assert(max(abs(L.T_s_meas(w) - L.T_s(w))) > 0, '(B) level %s: measured equals true', lv{1});
    end
end
fprintf('[%s] TEST PASS: Sensors alone: none = bypass; low = quantized (steps T_s %.3g, a_y %.3g, v %.3g) and held (%g, %g, %g s); high noise std/mean match Monte Carlo; seeds repeat/uncorrelated. Closed loop: e_T = T_s - T_d_ref on true values at every level\n', ...
    modelName, step(1), step(2), step(3), per(1), per(2), per(3));
end

function s = highSigma(r)
    if isfield(r, 'sigma_high'), s = r.sigma_high; else, s = r.resolution; end
end

function L = runHarness(level, seed, cst, slope, g, sig, tEnd)
    mdl = 'test_sensors_harness';
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    add_sensors(mdl, sig, 200, 50);
    for i = 1:numel(sig)
        src = ['Src_' sig{i}];
        if isempty(slope)
            add_block('simulink/Sources/Constant', [mdl '/' src], 'Value', num2str(cst(i), 17));
        else
            add_block('simulink/Sources/Ramp', [mdl '/' src], 'Slope', num2str(slope(i), 17), 'Start', '0', 'X0', '0');
        end
        set_param([mdl '/' src], 'Position', [20 50 + 160 * (i - 1) 70 80 + 160 * (i - 1)]);
        lg = ['Log_' sig{i}];
        add_block('simulink/Sinks/To Workspace', [mdl '/' lg], 'VariableName', ['y_' sig{i}], 'SaveFormat', 'Timeseries');
        set_param([mdl '/' lg], 'Position', [600 50 + 160 * (i - 1) 680 80 + 160 * (i - 1)]);
        add_line(mdl, [src '/1'], ['Sensors/' num2str(i)]);
        add_line(mdl, ['Sensors/' num2str(i)], [lg '/1']);
    end
    set_param(mdl, 'StopTime', num2str(tEnd), 'MaxStep', '1e-3', 'ReturnWorkspaceOutputs', 'on');
    V = sensor_noise_vars(level, seed);
    in = Simulink.SimulationInput(mdl);
    fn = fieldnames(V);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, V.(fn{k})); end
    so = sim(in);
    for i = 1:numel(sig)
        ts = so.get(['y_' sig{i}]);
        [tu, iu] = unique(ts.Time, 'last');
        L.(sig{i}) = interp1(tu, squeeze(ts.Data(iu)), g, 'previous', 'extrap');
    end
    close_system(mdl, 0);
end

function L = runLoop(modelName, level, seed)
    V = sensor_noise_vars(level, seed);
    in = Simulink.SimulationInput(modelName);
    in = in.setModelParameter('StopTime', '30');
    fn = fieldnames(V);
    for k = 1:numel(fn), in = in.setVariable(fn{k}, V.(fn{k})); end
    so = sim(in);
    t = (0:1e-3:30)';
    names = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y', 'T_s_meas', 'a_y_meas', 'v_meas'};
    for i = 1:numel(names)
        ts = so.get(['log_' names{i}]);
        [tu, iu] = unique(ts.Time, 'last');
        L.(names{i}) = interp1(tu, squeeze(ts.Data(iu)), t, 'previous', 'extrap');
    end
end
