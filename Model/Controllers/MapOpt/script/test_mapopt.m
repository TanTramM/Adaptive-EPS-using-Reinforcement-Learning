function test_mapopt()
%TEST_MAPOPT Verify MapOpt.mdl (the Map law H(z) sgn(T_s) M(v, |T_s|); built by build_mapopt.m).
%
%   (1) OPEN-LOOP on the 1 ms grid (no plant): synthetic T_s and v; the expected T_a is computed HERE from data/map.json (calibration points and the Map design) with
%   the hand-written table M_k = min(T_a,cal,k, M_(k-1) + Kmax (T_s,k - T_s,k-1)) from the dead zone edge Ts0 (zero inside), interpolated linearly, then the lead x lag by
%   hand (Tustin, convolution): max |Simulink - reference| < 1e-8 N.m, for the Map design of map.json and for a second set of parameters.
%   (2) END-TO-END: with the Map design of map.json, Model_MapOpt and Model_Map give the same CALIB scores (the new controller reproduces Map).
scriptDir = fileparts(mfilename('fullpath'));
ctlDir    = fileparts(scriptDir);
modelDir  = fileparts(fileparts(ctlDir));
addpath(modelDir); setup_paths;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(ctlDir, 'load_mapopt.m'), '\', '/')));
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); cal = Jm.calibration; dm = Jm.design;
Ts = 1e-3;
vrows = [cal.points.v_kmh]'; Tsbp = (0:0.005:5)';
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.3 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v   = 16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t);
harness = 'test_mapopt_harness';
if bdIsLoaded(harness), close_system(harness, 0); end
if bdIsLoaded('MapOpt'), close_system('MapOpt', 0); end
load_system(fullfile(ctlDir, 'MapOpt.mdl'));
subs = find_system('MapOpt', 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'MapOpt must have exactly 1 root subsystem');
new_system(harness);
dut = [harness '/DUT'];
add_block(subs{1}, dut);
sigs = {T_s, v}; names = {'T_s', 'v'};
for i = 1:2
    assignin('base', ['tm_' names{i}], [t sigs{i}]);
    add_block('simulink/Sources/From Workspace', [harness '/FW_' names{i}], 'VariableName', ['tm_' names{i}], 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_line(harness, ['FW_' names{i} '/1'], portRef(dut, names{i}));
    add_block('simulink/Sinks/To Workspace', [harness '/LG_' names{i}], 'VariableName', ['tm_in_' names{i}], 'SaveFormat', 'Timeseries');
    add_line(harness, ['FW_' names{i} '/1'], ['LG_' names{i} '/1']);
end
add_block('simulink/Sinks/To Workspace', [harness '/Ta_out'], 'VariableName', 'tm_Ta_log', 'SaveFormat', 'Timeseries');
add_line(harness, portRef(dut, 'T_a'), 'Ta_out/1');
set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));

cases = struct('name', {'Map design of map.json', 'Kmax 4, lead 25/500, lag 20/8'}, 'Kmax', {dm.Kmax, 4.0}, ...
    'lead', {dm.lead, struct('z', 25, 'p', 500)}, 'lag', {dm.lag, struct('z1', 20, 'p1', 8)});
for ic = 1:numel(cases)
    c = cases(ic);
    d = struct('Ts_ctrl', Ts, 'Ts0', dm.Ts0, 'Kmax', c.Kmax, 'lead', c.lead, 'lag', c.lag);
    V = mapopt_variables(evalin('base', 'calibrate_map_cached()'), d);
    Tab = independentTable(cal, dm.Ts0, c.Kmax, Tsbp);
    errTab = max(abs(V.MapOpt_table(:) - Tab(:)));
    assert(errTab < 1e-9, 'table of mapopt_variables differs from the independent table by %.3g', errTab);
    fn = fieldnames(V);
    for i = 1:numel(fn), assignin('base', fn{i}, V.(fn{i})); end
    so = sim(harness);
    ts = so.get('tm_Ta_log'); Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:);
    assert(numel(Ta_sim) == n, 'unexpected number of samples');
    in = struct();
    for i = 1:2, q = so.get(['tm_in_' names{i}]); in.(names{i}) = reshape(squeeze(q.Data), [], 1); end
    Tamap = sign(in.T_s) .* interp2(Tsbp', vrows' / 3.6, Tab, min(abs(in.T_s), Tsbp(end)), min(max(in.v, vrows(1) / 3.6), vrows(end) / 3.6), 'linear');
    Tamap(abs(in.T_s) <= dm.Ts0) = 0;
    [numH, denH] = compTustin(c.lead, c.lag, Ts);
    Ta_ref = filter(numH, denH, Tamap);
    err = max(abs(Ta_sim - Ta_ref));
    fprintf('[MapOpt] %s: T_a %.3f .. %.3f N.m, max |Simulink - reference| = %.3g N.m, table error %.2g\n', c.name, min(Ta_ref), max(Ta_ref), err, errTab);
    assert(err < 1e-8, '%s: T_a differs from the independent reference by %.3g', c.name, err);
end
close_system(harness, 0); close_system('MapOpt', 0);
evalin('base', 'clear tm_T_s tm_v');

%% end-to-end against Map with the same design
evalin('base', sprintf('run(''%s'');', strrep(fullfile(ctlDir, 'load_mapopt.m'), '\', '/')));
evalin('base', sprintf('run(''%s'');', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
if ~exist(fullfile(ctlDir, 'Model_MapOpt.mdl'), 'file'), build_closed_loop('MapOpt'); end
[~, m1] = calib_run('Model_Map', 0, []);
[~, m2] = calib_run('Model_MapOpt', 0, []);
Simulink.sdi.clear;
rel = max(abs([m1.R - m2.R, m1.S - m2.S, m1.erel - m2.erel]) ./ abs([m1.R, m1.S, max(m1.erel, 1e-3)]));
fprintf('[MapOpt] end-to-end vs Map: R %.6f / %.6f, S %.6f / %.6f, e_rel %.4f / %.4f (relative difference %.2g)\n', m1.R, m2.R, m1.S, m2.S, m1.erel, m2.erel, rel);
assert(rel < 1e-5, 'MapOpt must reproduce Map when given its design');
fprintf('[MapOpt] TEST PASS\n');
end

function Tab = independentTable(cal, Ts0, Kmax, Tsbp)
    nv = numel(cal.points); Tab = zeros(nv, numel(Tsbp));
    for i = 1:nv
        TsP = cal.points(i).Ts_Nm(:); TaP = cal.points(i).Ta_Nm(:);
        keep = [true; diff(TsP) > 1e-9]; TsP = TsP(keep); TaP = TaP(keep);
        bx = [Ts0; TsP]; by = zeros(size(bx));
        for k = 1:numel(TsP), by(k + 1) = max(min(TaP(k), by(k) + Kmax * (bx(k + 1) - bx(k))), 0); end
        y = interp1(bx, by, min(Tsbp, bx(end)), 'linear', 0);
        y(Tsbp <= Ts0) = 0;
        Tab(i, :) = y';
    end
end

function [num, den] = compTustin(lead, lag, Ts)
    a = 2 / Ts;
    stage = @(zz, pp) deal([(a / zz + 1) (1 - a / zz)] / (a / pp + 1), [1 (1 - a / pp) / (a / pp + 1)]);
    [num, den] = stage(lead.z, lead.p);
    if ~isempty(lag)
        [n2, d2] = stage(lag.z1, lag.p1);
        num = conv(num, n2); den = conv(den, d2);
    end
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end
