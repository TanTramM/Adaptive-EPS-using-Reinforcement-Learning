function test_mappid()
%TEST_MAPPID Verify MapPID.mdl (Map branch + PID branch in parallel, anti-windup on the total command; built by build_mappid.m).
%
%   Requires the root subsystem to expose ports named: In: T_s, v, a_y, T_a_lim | Out: T_a. OPEN-LOOP test on the 1 ms grid (no plant): synthetic
%   T_s, v, a_y and an independent T_a_lim (so the anti-windup term is active). The expected T_a is computed HERE from data/map.json (calibration
%   points and Map design), data/ref.json and the hand-written recursions, not from the base-workspace variables of the model:
%     u_map[k]  = lead-lag (Tustin, by hand) of sgn(T_s) M(v, |T_s|),  M_k = min(T_a,cal,k, M_(k-1) + Kmax (T_s,k - T_s,k-1)), dead zone Ts0
%     e[k] = T_s[k] - T_d,ref(v[k], a_y[k]),  d[k] = a d[k-1] + b (T_s[k] - T_s[k-1]),  a = Tf/(Tf+Ts), b = Kd/(Tf+Ts)
%     T_a[k] = u_map[k] + Kp e[k] + u_I[k] + d[k],   u_I[k+1] = u_I[k] + Ts (Ki e[k] + Kaw (T_a_lim[k] - T_a[k]))
%   Three runs: (a) PID gains 0 -> the Map alone; (b) table 0 -> the PID alone with Kaw; (c) both branches, Kp, Ki, Kd, Tf, Kmax and a lag of the
%   test, with T_a_lim clamping part of the time. Also (d): the table built by mappid_variables equals the independent table at every grid point,
%   and (e) Kaw = Ki / (Kp + Kmax).
scriptDir = fileparts(mfilename('fullpath'));   % MapPID/script
ctlDir    = fileparts(scriptDir);               % MapPID/
modelDir  = fileparts(fileparts(ctlDir));       % Model/
addpath(modelDir); setup_paths;
evalin('base', sprintf('run(''%s'');', strrep(fullfile(ctlDir, 'load_mappid.m'), '\', '/')));
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); cal = Jm.calibration; dm = Jm.design;
Ts = 1e-3;

%% independent Map table on the grid of the model (speed rows of the calibration x 0:0.005:5 N.m) for a slope limit
vrows = [cal.points.v_kmh]';
Tsbp = (0:0.005:5)';
mkTable = @(Kmax) independentTable(cal, dm.Ts0, Kmax, Tsbp);

%% synthetic inputs
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.3 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);       % crosses the dead zone and the whole table
v   = 16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t);                    % m/s
a_y = 3.0 * sin(2*pi*0.4*t);                                      % m/s^2, both signs
T_a_lim = 3.0 * sin(2*pi*0.2*t + 0.5) + 0.4;                      % independent of T_a: the anti-windup term is active

harness = 'test_mappid_harness';
mdlFile = 'MapPID';
if bdIsLoaded(harness), close_system(harness, 0); end
if bdIsLoaded(mdlFile), close_system(mdlFile, 0); end
load_system(fullfile(ctlDir, [mdlFile '.mdl']));
subs = find_system(mdlFile, 'SearchDepth', 1, 'BlockType', 'SubSystem');
assert(numel(subs) == 1, 'MapPID must have exactly 1 root subsystem');
new_system(harness);
dut = [harness '/DUT'];
add_block(subs{1}, dut);
sigs = {T_s, v, a_y, T_a_lim}; names = {'T_s', 'v', 'a_y', 'T_a_lim'};
for i = 1:numel(names)
    assignin('base', ['tm_' names{i}], [t sigs{i}]);
    b = [harness '/FW_' names{i}];
    add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tm_' names{i}], 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_line(harness, ['FW_' names{i} '/1'], portRef(dut, names{i}));
    b = [harness '/LG_' names{i}];
    add_block('simulink/Sinks/To Workspace', b, 'VariableName', ['tm_in_' names{i}], 'SaveFormat', 'Timeseries');
    add_line(harness, ['FW_' names{i} '/1'], ['LG_' names{i} '/1']);
end
add_block('simulink/Sinks/To Workspace', [harness '/Ta_out'], 'VariableName', 'tm_Ta_log', 'SaveFormat', 'Timeseries');
add_line(harness, portRef(dut, 'T_a'), 'Ta_out/1');
set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp = rawRef.fine.v_breakpoints_kmh(:)' / 3.6; ay_bp = rawRef.fine.ay_breakpoints_g(:)' * 9.81; tab = rawRef.fine.table_Nm';

% each case: Kmax, lead, lag (empty = none), gains, table scale (0 switches the Map branch off)
cases = struct( ...
    'name', {'(a) Map alone', '(b) PID alone', '(c) Map + PID, lead-lag, clamped'}, ...
    'Kmax', {dm.Kmax, 6.5, 4.0}, ...
    'lead', {dm.lead, struct('z', 40, 'p', 700), struct('z', 25, 'p', 500)}, ...
    'lag',  {dm.lag, struct('z1', 30, 'p1', 12), struct('z1', 20, 'p1', 8)}, ...
    'Kp',   {0, 0.7, 0.5}, 'Ki', {0, 12, 20}, 'Kd', {0, 0.02, 0.01}, 'Tf', {0.005, 0.008, 0.004}, 'scale', {1, 0, 1});
for ic = 1:numel(cases)
    c = cases(ic);
    d = struct('Ts_ctrl', Ts, 'Ts0', dm.Ts0, 'Kmax', c.Kmax, 'lead', c.lead, 'lag', c.lag, 'Kp', c.Kp, 'Ki', c.Ki, 'Kd', c.Kd, 'Tf', c.Tf);
    V = mappid_variables(evalin('base', 'calibrate_map_cached()'), d);
    % (d) the table of mappid_variables equals the independent table on the grid points
    Tab = mkTable(c.Kmax);
    errTab = max(abs(V.MapPID_table(:) - Tab(:)));
    assert(errTab < 1e-9, 'table of mappid_variables differs from the independent table by %.3g', errTab);
    assert(abs(V.MapPID_Kaw - ternary(c.Ki > 0 && c.Kp + c.Kmax > 0, c.Ki / (c.Kp + c.Kmax), 0)) < 1e-12, 'Kaw must be Ki/(Kp+Kmax)');   % (e)
    fn = fieldnames(V);
    for i = 1:numel(fn), assignin('base', fn{i}, V.(fn{i})); end
    if c.scale == 0, assignin('base', 'MapPID_table', zeros(size(V.MapPID_table))); end
    so = sim(harness);
    ts = so.get('tm_Ta_log'); Ta_sim = squeeze(ts.Data); Ta_sim = Ta_sim(:); tg = ts.Time(:);
    assert(numel(tg) == n, 'unexpected number of samples');
    in = struct();
    for i = 1:numel(names)
        q = so.get(['tm_in_' names{i}]); in.(names{i}) = reshape(squeeze(q.Data), [], 1);
    end

    % ---- independent expected output
    Td = sign(in.a_y) .* interp2(ay_bp, v_bp, tab, min(abs(in.a_y), ay_bp(end)), min(max(in.v, v_bp(1)), v_bp(end)), 'linear');
    Mtab = c.scale * Tab;                                           % rows = speeds, cols = Tsbp
    Tamap = sign(in.T_s) .* interp2(Tsbp', vrows' / 3.6, Mtab, min(abs(in.T_s), Tsbp(end)), min(max(in.v, vrows(1) / 3.6), vrows(end) / 3.6), 'linear');
    Tamap(abs(in.T_s) <= dm.Ts0) = 0;
    [numH, denH] = compTustin(c.lead, c.lag, Ts);
    umap = filter(numH, denH, Tamap);
    Ta_ref = zeros(n, 1); uI = 0; dk = 0; Tsp = 0; a = c.Tf / (c.Tf + Ts); b = c.Kd / (c.Tf + Ts);
    Kaw = ternary(c.Ki > 0 && c.Kp + c.Kmax > 0, c.Ki / (c.Kp + c.Kmax), 0);
    for k = 1:n
        e = in.T_s(k) - Td(k);
        dk = a * dk + b * (in.T_s(k) - Tsp); Tsp = in.T_s(k);
        Ta_ref(k) = umap(k) + c.Kp * e + uI + dk;
        uI = uI + Ts * (c.Ki * e + Kaw * (in.T_a_lim(k) - Ta_ref(k)));
    end
    err = max(abs(Ta_sim - Ta_ref));
    fprintf('[MapPID] %s: T_a %.3f .. %.3f N.m, max |Simulink - reference| = %.3g N.m, table error %.2g\n', c.name, min(Ta_ref), max(Ta_ref), err, errTab);
    assert(err < 1e-8, '%s: T_a differs from the independent reference by %.3g', c.name, err);
    if ic == 3
        assert(max(abs(in.T_a_lim - Ta_ref)) > 1, 'case (c) must exercise the anti-windup term');
    end
end

% structure: the integrator is a discrete forward-Euler integrator at the controller period
integ = find_system(dut, 'BlockType', 'DiscreteIntegrator');
assert(numel(integ) == 1 && strcmp(get_param(integ{1}, 'IntegratorMethod'), 'Integration: Forward Euler'), 'the integrator must be a forward-Euler discrete-time integrator');
close_system(harness, 0); close_system(mdlFile, 0);
evalin('base', 'clear tm_T_s tm_v tm_a_y tm_T_a_lim');
fprintf('[MapPID] TEST PASS: Map branch, PID branch and anti-windup on the total command match the independent recursions\n');
end

function Tab = independentTable(cal, Ts0, Kmax, Tsbp)
% M(v_row, |T_s|) on the grid: M_k = min(T_a,cal,k, M_(k-1) + Kmax (T_s,k - T_s,k-1)) from the dead zone edge, zero in the dead zone, linear between breakpoints.
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
% lead (s/z+1)/(s/p+1) times the lag (s/z1+1)/(s/p1+1) (when given), each stage Tustin by hand, multiplied by convolution.
    a = 2 / Ts;
    stage = @(zz, pp) deal([(a / zz + 1) (1 - a / zz)] / (a / pp + 1), [1 (1 - a / pp) / (a / pp + 1)]);
    [num, den] = stage(lead.z, lead.p);
    if ~isempty(lag)
        [n2, d2] = stage(lag.z1, lag.p1);
        num = conv(num, n2); den = conv(den, d2);
    end
end

function y = ternary(cond, a, b)
    if cond, y = a; else, y = b; end
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName inside subPath - wiring by NAME.
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
