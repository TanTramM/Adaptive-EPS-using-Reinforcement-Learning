function ok = test_gates()
%TEST_GATES Test of Gates.mdl (MATLAB Function block built by build_gates.m).
%   A) gates_fcn.m called sample by sample == independent vectorised formulas (the formulas of tk_run.m / tk_block_scores.m);
%   B) the block inside Simulink (fixed 1 ms sample time) on the same signals == A.
%   Self-contained: the signals are synthetic, the reference is computed here, not read from another script.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(scriptDir));
addpath(modelDir); setup_paths;
addpath(scriptDir);

%% synthetic signals on the 1 ms grid of the test cases
Ts = 0.001; t = (0:Ts:12)'; n = numel(t);
T_d_ref = 2 * sin(2*pi*0.3*t);
T_s     = T_d_ref + 0.3*sin(2*pi*1.1*t) + 0.05*sin(2*pi*40*t) + 0.2;
T_a     = 1.5 * sin(2*pi*0.3*t + 0.4) + 0.1*sin(2*pi*25*t);
T_a_cmd = 1.4 * T_a + 0.3*sin(2*pi*60*t);
T_a_lim = max(-2, min(T_a_cmd, 2));               % limit +-2 N.m, so the command is clamped part of the time
winId   = zeros(n, 1); winId(t >= 3 & t <= 5) = 1; winId(t >= 6 & t <= 9) = 2; winId(t >= 10 & t <= 11) = 3;

%% reference (independent of gates_fcn.m)
w = t >= 2;
e = T_s - T_d_ref;
inW = winId > 0;
a = Ts / (1 / (2*pi*5) + Ts);
hp  = T_a     - filter(a, [1 -(1-a)], T_a);
hpc = T_a_cmd - filter(a, [1 -(1-a)], T_a_cmd);
ref.R = sqrt(mean(e(inW).^2));
ref.S = sqrt(mean(hp(w).^2));
ref.S_cmd = sqrt(mean(hpc(w).^2));
ref.TV = sum(abs(diff(T_a(w)))) / (nnz(w) - 1) / Ts;
ref.maxTa = max(abs(T_a(w)));
ref.maxEt = max(abs(e));
ref.satFrac = mean(abs(T_a_cmd(w)) > abs(T_a_lim(w)) + 1e-9);
ref.revFrac = mean(abs(T_s(w)) >= 0.5 & T_a(w) .* T_s(w) < 0);
ref.nonfinite = 0;
ref.erelWin = zeros(32, 1); ref.RWin = zeros(32, 1); ref.refWin = zeros(32, 1); ref.cntWin = zeros(32, 1);
for j = 1:3
    in = winId == j;
    ref.erelWin(j) = 100 * abs(mean(e(in))) / mean(abs(T_d_ref(in)));
    ref.RWin(j) = sqrt(mean(e(in).^2));
    ref.refWin(j) = mean(abs(T_d_ref(in)));
    ref.cntWin(j) = nnz(in);
end
names = {'R', 'S', 'S_cmd', 'TV', 'maxTa', 'maxEt', 'satFrac', 'revFrac', 'nonfinite', 'erelWin', 'RWin', 'refWin', 'cntWin'};

%% A) gates_fcn.m sample by sample
clear gates_fcn
out = cell(1, numel(names));
for i = 1:n
    [out{:}] = gates_fcn(T_s(i), T_d_ref(i), T_a(i), T_a_cmd(i), T_a_lim(i), winId(i));
end
errA = cellfun(@(nm, v) max(abs(v(:) - ref.(nm)(:))), names, out);
fprintf('A) gates_fcn.m vs reference: max abs difference per output\n');
for i = 1:numel(names), fprintf('   %-10s %.3g\n', names{i}, errA(i)); end
fprintf('   exercised: satFrac %.3f, revFrac %.3f, R %.3f, S %.3f (must not be 0)\n', ref.satFrac, ref.revFrac, ref.R, ref.S);
okA = all(errA < 1e-9) && ref.satFrac > 0 && ref.revFrac > 0;
ok_nonfinite = gates_fcn_nan_flag();
fprintf('   non-finite input sets the flag: %d\n', ok_nonfinite);

%% B) the block inside Simulink
gname = 'Gates';
if ~exist(fullfile(modelDir, 'Sim', [gname '.mdl']), 'file'), error('Gates.mdl not built: run build_gates first'); end
load_system(fullfile(modelDir, 'Sim', [gname '.mdl']));
h = 'test_gates_harness';
if bdIsLoaded(h), close_system(h, 0); end
new_system(h);
sigs = {T_s, T_d_ref, T_a, T_a_cmd, T_a_lim, winId};
inNames = {'T_s', 'T_d_ref', 'T_a', 'T_a_cmd', 'T_a_lim', 'winId'};
add_block([gname '/Gates'], [h '/Gates'], 'Position', [300 50 500 400]);
for i = 1:numel(inNames)
    assignin('base', ['tg_' inNames{i}], [t sigs{i}]);
    b = [h '/FW_' inNames{i}];
    add_block('simulink/Sources/From Workspace', b, 'VariableName', ['tg_' inNames{i}], 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value', 'Position', [60 40+50*i 160 70+50*i]);
    add_line(h, ['FW_' inNames{i} '/1'], sprintf('Gates/%d', i));
end
for i = 1:numel(names)
    b = [h '/TW_' names{i}];
    add_block('simulink/Sinks/To Workspace', b, 'VariableName', ['tgo_' names{i}], 'SaveFormat', 'Timeseries', ...
        'Position', [650 20+40*i 750 40+40*i]);
    add_line(h, sprintf('Gates/%d', i), ['TW_' names{i} '/1']);
end
set_param(h, 'StopTime', num2str(t(end)), 'MaxStep', '0.002');
so = sim(Simulink.SimulationInput(h));
errB = zeros(1, numel(names));
for i = 1:numel(names)
    ts = so.get(['tgo_' names{i}]);
    d = squeeze(ts.Data);                       % N x 1 for a scalar output, 32 x N for a 32-vector output
    if size(d, 1) == numel(ts.Time), last = d(end, :); else, last = d(:, end); end
    errB(i) = max(abs(last(:) - ref.(names{i})(:)));
end
fprintf('B) block in Simulink vs reference: max abs difference per output\n');
for i = 1:numel(names), fprintf('   %-10s %.3g\n', names{i}, errB(i)); end
okB = all(errB < 1e-6);
close_system(h, 0); close_system(gname, 0);

ok = okA && ok_nonfinite && okB;
fprintf('test_gates: %s\n', ternary(ok, 'PASS', 'FAIL'));
end

function f = gates_fcn_nan_flag()
% A NaN in any input must set nonfinite = 1 and must not poison the other scores.
clear gates_fcn
for i = 1:3000
    x = 1; if i == 2500, x = NaN; end
    [R, S, ~, ~, ~, ~, ~, ~, nf] = gates_fcn(x, 0, 0.5, 0.5, 0.5, 1); %#ok<ASGLU>
end
f = (nf == 1) && isfinite(S) && isfinite(R);
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
