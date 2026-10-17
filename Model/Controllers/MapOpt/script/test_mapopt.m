function test_mapopt()
%TEST_MAPOPT Verify MapOpt.mdl (a copy of Map.mdl with the variable prefix Map_ renamed MapOpt_) and the MapOpt tools (DieuKhien_MapOpt.txt Phase E).
%   (1) Open loop on the 1 ms grid: for two designs (the design of data/map.json, and a design with a no-lead, no-lag stage and another with strong stages) the output of
%       MapOpt.mdl with variables from mapopt_variables equals the output of Map.mdl with variables from map_variables (the old model, untouched) to 1e-12 N.m, on a
%       synthetic T_s (crossing the dead zone and the whole table) and a speed step. The Map model itself is tested by test_map.m against an independent recursion.
%   (2) With p = z and p1 = z1 the compensator is the identity: the steady output equals the table value; the Tustin numerator and denominator are equal.
%   (3) mapopt_u2x and mapopt_x2u round trip to 1e-9 on 1000 random points; every u gives a realizable design (p <= 3142 rad/s, p >= z, p1 >= 3, p1 <= z1).
%   (4) mapopt_margins on the old Map design reproduces PM 45.292 deg and GM 5.674 (map.json) to 1e-3.
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'), '\', '/')));
evalin('base', sprintf('run("%s");', strrep(fullfile(modelDir, 'Controllers', 'MapOpt', 'load_mapopt.m'), '\', '/')));
Jm = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json'))); dm = Jm.design;
Cal = evalin('base', 'calibrate_map_cached()');
Ts = 1e-3;

%% (1) MapOpt.mdl equals Map.mdl
designs = {struct('Ts_ctrl', Ts, 'Ts0', dm.Ts0, 'Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag), ...
           struct('Ts_ctrl', Ts, 'Ts0', dm.Ts0, 'Kmax', 7.3, 'lead', struct('z', 40, 'p', 40), 'lag', struct('z1', 25, 'p1', 25)), ...
           struct('Ts_ctrl', Ts, 'Ts0', dm.Ts0, 'Kmax', 4.2, 'lead', struct('z', 12, 'p', 900), 'lag', struct('z1', 90, 'p1', 6))};
t = (0:Ts:6)'; n = numel(t);
T_s = 1.5 + 1.3 * sin(2*pi*0.7*t) + 0.2 * sin(2*pi*13*t);
v = 16 + 8 * (t > 3) + 3 * sin(2*pi*0.1*t);
yy = cell(1, 2);
for im = 1:2
    mdl = {'Map', 'MapOpt'}; mdl = mdl{im};
    harness = ['test_mapopt_harness_' mdl];
    if bdIsLoaded(harness), close_system(harness, 0); end
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    load_system(fullfile(modelDir, 'Controllers', mdl, [mdl '.mdl']));
    new_system(harness);
    add_block([mdl '/' mdl], [harness '/DUT']);
    add_block('simulink/Sources/From Workspace', [harness '/FW_Ts'], 'VariableName', 'tmo_Ts', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_block('simulink/Sources/From Workspace', [harness '/FW_v'], 'VariableName', 'tmo_v', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
    add_block('simulink/Sinks/To Workspace', [harness '/Out'], 'VariableName', 'tmo_out', 'SaveFormat', 'Timeseries');
    add_line(harness, 'FW_Ts/1', portRef([harness '/DUT'], 'T_s'));
    add_line(harness, 'FW_v/1', portRef([harness '/DUT'], 'v'));
    add_line(harness, portRef([harness '/DUT'], 'T_a'), 'Out/1');
    set_param(harness, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', num2str(Ts), 'StopTime', num2str(t(end)));
    assignin('base', 'tmo_Ts', [t T_s]); assignin('base', 'tmo_v', [t v]);
    yy{im} = zeros(n, numel(designs));
    for id = 1:numel(designs)
        if im == 1, V = map_variables(Cal, designs{id}); else, V = mapopt_variables(Cal, designs{id}); end
        fn = fieldnames(V);
        for k = 1:numel(fn), assignin('base', fn{k}, V.(fn{k})); end
        so = sim(harness);
        ts = so.get('tmo_out'); yy{im}(:, id) = reshape(squeeze(ts.Data), [], 1);
    end
    close_system(harness, 0); close_system(mdl, 0);
end
err = max(abs(yy{1}(:) - yy{2}(:)));
fprintf('[MapOpt] (1) MapOpt.mdl equals Map.mdl on %d designs, max difference %.3g N.m\n', numel(designs), err);
assert(err < 1e-12, 'MapOpt.mdl differs from Map.mdl by %.3g', err);
evalin('base', 'clear tmo_Ts tmo_v');

%% (2) identity compensator
V = mapopt_variables(Cal, designs{2});
assert(max(abs(V.MapOpt_H_num - V.MapOpt_H_den)) < 1e-12, 'no lead and no lag must give numerator = denominator');
fprintf('[MapOpt] (2) p = z and p1 = z1 give the identity compensator (num = den)\n');

%% (3) round trip and realizability
rng(7); worst = 0;
for k = 1:1000
    u = rand(1, 5); x = mapopt_u2x(u);
    worst = max(worst, max(abs(mapopt_x2u(x) - u)));
    assert(x(2) * x(3) <= pi / Ts * (1 + 1e-9) && x(3) >= 1 && x(4) * x(5) >= 3 * (1 - 1e-9) && x(5) <= 1, 'u2x gave an unrealizable design');
end
assert(worst < 1e-9, 'u2x/x2u round trip error %.3g', worst);
fprintf('[MapOpt] (3) u2x / x2u round trip %.2g, designs realizable\n', worst);

%% (4) margins of the old design
[Gj, w] = mapopt_plants();
R = mapopt_margins(Gj, w, struct('Kmax', dm.Kmax, 'lead', dm.lead, 'lag', dm.lag));
fprintf('[MapOpt] (4) margins of the old Map design: PM %.3f deg (map.json %.3f), GM %.3f (%.3f)\n', R.PM, dm.PM_deg, R.GM, dm.GM);
assert(abs(R.PM - dm.PM_deg) < 1e-3 && abs(R.GM - dm.GM) < 1e-3, 'margins differ from map.json');
fprintf('[MapOpt] TEST PASS\n');
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
