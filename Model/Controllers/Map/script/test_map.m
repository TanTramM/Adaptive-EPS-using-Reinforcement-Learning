function test_map()
%TEST_MAP Verify Map.mdl (Map controller block: dead zone + calibrated assist curve with slope limit, one lead).
%   Self-contained: the expected values are computed here from data/map.json (calibration points and design), NOT with the design scripts.
%
%   Harness: Step sources for T_s and v -> Map -> To Workspace.
%   (1) Steady output (0.45 s after the step) equals sgn(T_s)*M(v,|T_s|) for a grid of T_s (both signs, dead zone, inside and beyond the
%       calibration range) and v (table rows and between rows), where M is rebuilt here from the calibration points with
%       M_k = min(T_a,cal,k, M_(k-1) + Kmax*(T_s,k - T_s,k-1)); between speed rows the table is interpolated linearly.
%   (2) Dynamic: the output samples after a step in T_s follow the Tustin lead (s/z+1)/(s/p+1) at every speed.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '''', '''''')));
J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
d = J.design; cal = J.calibration;
Tsamp = d.Ts_ctrl;

mdlFile = 'Map';
harness = 'test_map_harness';
if bdIsLoaded(harness), close_system(harness, 0); end
load_system(mdlFile);
new_system(harness);
add_block([mdlFile '/Map'], [harness '/Map']);
add_block('simulink/Sources/Step', [harness '/Step_Ts'], 'Time', '0.05', 'Before', '0');
add_block('simulink/Sources/Constant', [harness '/Const_v']);
add_block('simulink/Sinks/To Workspace', [harness '/Out'], 'VariableName', 'y', 'SaveFormat', 'Timeseries');
add_line(harness, 'Step_Ts/1', portRef([harness '/Map'], 'T_s'));
add_line(harness, 'Const_v/1', portRef([harness '/Map'], 'v'));
add_line(harness, portRef([harness '/Map'], 'T_a'), 'Out/1');
set_param(harness, 'StopTime', '0.5', 'MaxStep', '1e-3', 'ReturnWorkspaceOutputs', 'on');
set_param(harness, 'SolverType', 'Variable-step');

%% (1) steady output
vTest  = [20 30 45 60 62.5 65 80 100];            % km/h
TsTest = [-3.0 -1.5 -0.2 0.2 0.3 0.5 1.0 1.8 2.4 2.9 3.4 4.5];   % N.m
maxErr = 0;
for iv = 1:numel(vTest)
    for it = 1:numel(TsTest)
        [~, y] = runOne(harness, vTest(iv) / 3.6, TsTest(it));
        ref = referenceAssist(cal, d, vTest(iv), TsTest(it));
        err = abs(y(end) - ref);
        maxErr = max(maxErr, err);
        assert(err < 1e-6, 'steady output: v=%g km/h, T_s=%g: model %.8g, reference %.8g', vTest(iv), TsTest(it), y(end), ref);
    end
end
fprintf('[Map] (1) steady output matches the independent assist curve on %d points, max error %.2g N.m\n', numel(vTest) * numel(TsTest), maxErr);

%% (2) dynamic: lead step
amp = 2.0;
for vk = [40 62.5 100]
    [t, y] = runOne(harness, vk / 3.6, amp);
    Mv = referenceAssist(cal, d, vk, amp);              % steady value of the map for the step
    exp_ = Mv * leadStep(d.lead.z, d.lead.p, Tsamp, 40);   % samples after the step (sample 0 = first tick of the step)
    got = interp1(t, y, 0.05 + (0:39)' * Tsamp + 1e-6, 'previous');
    e = max(abs(got - exp_));
    assert(e < 1e-6 * max(1, abs(Mv)), 'lead step at %g km/h: max error %.3g', vk, e);
    fprintf('[Map] (2) step response at %g km/h matches the Tustin lead, max error %.2g N.m\n', vk, e);
end
close_system(harness, 0);
close_system(mdlFile, 0);
fprintf('[Map] TEST PASS\n');
end

function [t, y] = runOne(harness, v, Ts)
    set_param([harness '/Step_Ts'], 'After', sprintf('%.15g', Ts));
    set_param([harness '/Const_v'], 'Value', sprintf('%.15g', v));
    so = sim(harness);
    ts = so.get('y');
    t = ts.Time; y = squeeze(ts.Data);
end

function s = leadStep(z, p, Ts, n)
% Unit-step response samples of the Tustin lead (s/z+1)/(s/p+1), by hand: H(q) = (b0 + b1 q^-1)/(1 + a1 q^-1)
    a = 2 / Ts;
    b0 = (a / z + 1) / (a / p + 1); b1 = (1 - a / z) / (a / p + 1); a1 = (1 - a / p) / (a / p + 1);
    s = filter([b0 b1], [1 a1], ones(n, 1));
end

function y = referenceAssist(cal, d, v_kmh, Ts)
% sgn(Ts)*M(v,|Ts|), rows interpolated linearly in v, clamped outside 20..100 km/h.
    a = abs(Ts);
    if isfield(cal, 'points')
        vr = [cal.points.v_kmh]';
        getTs = @(i) cal.points(i).Ts_Nm(:);
        getTa = @(i) cal.points(i).Ta_Nm(:);
    elseif iscell(cal.Ts)
        vr = cal.v_kmh(:);
        getTs = @(i) cal.Ts{i}(:);
        getTa = @(i) cal.Ta{i}(:);
    else
        vr = cal.v_kmh(:);
        getTs = @(i) cal.Ts_Nm{i}(:);
        getTa = @(i) cal.Ta_Nm{i}(:);
    end
    Mrow = zeros(numel(vr), 1);
    for i = 1:numel(vr)
        K = d.Kmax;
        TsP = getTs(i); TaP = getTa(i);
        keep = [true; diff(TsP) > 1e-9]; TsP = TsP(keep); TaP = TaP(keep);
        bx = [d.Ts0; TsP]; by = zeros(size(bx));
        for k = 1:numel(TsP)
            by(k + 1) = max(min(TaP(k), by(k) + K * (bx(k + 1) - bx(k))), 0);
        end
        if a <= d.Ts0, Mrow(i) = 0; else, Mrow(i) = interp1(bx, by, min(a, bx(end))); end
    end
    y = sign(Ts) * interp1(vr, Mrow, min(max(v_kmh, vr(1)), vr(end)));
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end

