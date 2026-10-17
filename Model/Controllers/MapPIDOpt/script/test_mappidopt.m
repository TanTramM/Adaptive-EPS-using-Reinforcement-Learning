function test_mappidopt()
%TEST_MAPPIDOPT Verify MapPIDOpt.mdl (MapPID.mdl with the variable prefix MapPID_ renamed MapPIDOpt_) and the MapPIDOpt tools (DieuKhien_MapPID.txt H7).
%   (1) Open loop on the 1 ms grid: for three designs (mappid.json; K = 0 with no lead and no lag = PID alone; a strong design) the output of MapPIDOpt.mdl with the
%       variables of mappidopt_variables equals the output of MapPID.mdl with the variables of mappid_variables to 1e-12 N.m, on a synthetic T_s, v, a_y and an independent
%       T_a_lim (the anti-windup term is active). MapPID.mdl itself is tested against independent recursions by test_mappid.m.
%   (2) mappidopt_u2x / mappidopt_x2u round trip to 1e-9 on 1000 random points; every u gives a realizable design.
%   (3) mappidopt_margins on the design of mappid.json reproduces PM 38.0 deg and GM 6.72 (mappid.json) to 0.05.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapPID', 'load_mappid.m'), '\', '/')));
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapPIDOpt', 'load_mappidopt.m'), '\', '/')));
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); Ts0 = Jm.design.Ts0;
Jx = jsondecode(fileread(fullfile(modelDir, 'data', 'mappid.json'))); q = Jx.design;
Cal = evalin('base', 'calibrate_map_cached()');
Ts = 1e-3;

%% (1) MapPIDOpt.mdl equals MapPID.mdl
designs = {struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', q.Kmax, 'lead', q.lead, 'lag', q.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf), ...
           struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', 0, 'lead', struct('z', 40, 'p', 40), 'lag', struct('z1', 25, 'p1', 25), 'Kp', 1.5, 'Ki', 32, 'Kd', 0.025, 'Tf', 0.0025), ...
           struct('Ts_ctrl', Ts, 'Ts0', Ts0, 'Kmax', 5.2, 'lead', struct('z', 12, 'p', 900), 'lag', struct('z1', 90, 'p1', 6), 'Kp', 0.9, 'Ki', 80, 'Kd', 0.06, 'Tf', 0.004)};
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.3 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v = 16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t);
a_y = 3.0 * sin(2*pi*0.4*t);
T_a_lim = 3.0 * sin(2*pi*0.2*t + 0.5) + 0.4;
sigs = {T_s, v, a_y, T_a_lim}; names = {'T_s', 'v', 'a_y', 'T_a_lim'};
yy = cell(1, 2);
for im = 1:2
    mdl = {'MapPID', 'MapPIDOpt'}; mdl = mdl{im};
    harness = ['test_mappidopt_harness_' mdl];
    if bdIsLoaded(harness), close_system(harness, 0); end
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(modelDir, 'Controllers', mdl, [mdl '.mdl']));
    new_system(harness);
    dut = [harness '/DUT'];
    add_block([mdl '/' mdl], dut);
    for i = 1:numel(names)
        assignin('base', ['tmo_' names{i}], [t sigs{i}]);
        add_block('simulink/Sources/From Workspace', [harness '/FW_' names{i}], 'VariableName', ['tmo_' names{i}], 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
        add_line(harness, ['FW_' names{i} '/1'], portRef(dut, names{i}));
    end
    add_block('simulink/Sinks/To Workspace', [harness '/Out'], 'VariableName', 'tmo_out', 'SaveFormat', 'Timeseries');
    add_line(harness, portRef(dut, 'T_a'), 'Out/1');
    set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));
    yy{im} = zeros(n, numel(designs));
    for id = 1:numel(designs)
        if im == 1, V = mappid_variables(Cal, designs{id}); else, V = mappidopt_variables(Cal, designs{id}); end
        fn = fieldnames(V);
        for k = 1:numel(fn), assignin('base', fn{k}, V.(fn{k})); end
        so = sim(harness);
        ts = so.get('tmo_out'); yy{im}(:, id) = reshape(squeeze(ts.Data), [], 1);
    end
    close_system(harness, 0); close_system(mdl, 0);
end
err = max(abs(yy{1}(:) - yy{2}(:)));
fprintf('[MapPIDOpt] (1) MapPIDOpt.mdl equals MapPID.mdl on %d designs, max difference %.3g N.m\n', numel(designs), err);
assert(err < 1e-12, 'MapPIDOpt.mdl differs from MapPID.mdl by %.3g', err);
evalin('base', 'clear tmo_T_s tmo_v tmo_a_y tmo_T_a_lim');

%% (2) round trip and realizability
rng(7); worst = 0;
for k = 1:1000
    u = rand(1, 9); x = mappidopt_u2x(u);
    x2 = mappidopt_u2x(mappidopt_x2u(x));            % x -> u -> x must give back x (u itself is not unique when K = 0 or Kd = 0)
    worst = max(worst, max(abs(x2 - x) ./ max(abs(x), 1e-12)));
    assert(x(2) * x(3) <= pi / Ts * (1 + 1e-9) && x(3) >= 1 && x(4) * x(5) >= 3 * (1 - 1e-9) && x(5) <= 1 && x(9) <= 0.0796 * (1 + 1e-9) && x(9) >= 1e-3 * (1 - 1e-9), 'u2x gave an unrealizable design');
end
assert(worst < 1e-9, 'u2x/x2u round trip error %.3g', worst);
x0 = mappidopt_u2x(zeros(1, 9));
assert(x0(1) == 0 && x0(8) == 0, 'u = 0 must give K = 0 and Kd = 0');
fprintf('[MapPIDOpt] (2) u2x / x2u round trip %.2g, designs realizable, K = 0 and Kd = 0 reachable\n', worst);

%% (3) margins of the MapPID design
[Gj, w] = mappidopt_plants();
R = mappidopt_margins(Gj, w, struct('Kmax', q.Kmax, 'lead', q.lead, 'lag', q.lag, 'Kp', q.Kp, 'Ki', q.Ki, 'Kd', q.Kd, 'Tf', q.Tf));
fprintf('[MapPIDOpt] (3) margins of the MapPID design: PM %.3f deg (mappid.json %.3f), GM %.3f (%.3f)\n', R.PM, q.PM_deg, R.GM, q.GM);
assert(abs(R.PM - q.PM_deg) < 0.05 && abs(R.GM - q.GM) < 0.05, 'margins differ from mappid.json');
fprintf('[MapPIDOpt] TEST PASS\n');
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
