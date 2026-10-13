function D = tune_mappid_linear(noiseTargets, nStart)
%TUNE_MAPPID_LINEAR O3 of DieuKhien_MapPID.txt: starting points for the global search by systune on the LINEAR loop (no simulation).
%
%   D = tune_mappid_linear()                    five noise targets, 10 random starts each
%   D = tune_mappid_linear(noiseTargets, nStart)
%   Loop (continuous approximation, as mappid_margins): L = P (f K H + C),  P = -G Gm exp(-s 1 ms) (Pade 2), G = linearized Plant T_a -> T_s
%   (map_plant_lin), Gm = motor 100 Hz, H = (Tz s + 1)/(Tp s + 1) (Tz1 s + 1)/(Tp1 s + 1) lead x lag of the Map branch, C = tunable PID with filter Tf.
%   Plants: 5 speeds (20, 40, 60, 80, 100 km/h) x the 4 operating points of map_op_points; slopes f = 0, 0.5, 1 (k = f K): 60 models in one systune call.
%   Nine tunable parameters: K [0 16], Tz [2e-3 0.2], Tp [3.2e-4 0.18], Tz1 [1/120 1/8], Tp1 [0.05 0.33], Kp [0 3], Ki [0 200], Kd [0 0.05], Tf [1e-3 0.02].
%   Requirements (one design per noise target N): hard  Margins at the plant input (GM 1.5, PM 15 deg), hard Gain n -> u <= N (noise at the measurement
%   to the command: the high-frequency gain), soft Sensitivity at the output with the weight WS (small error in the steering band 0-2 Hz, the proxy of R).
%   The mapping noise target -> S is learned later from the simulation of the five designs (O3 end). Output: Result/Controllers/MapPID/Design/MapPID_systune.csv
%   with the nine variables in the format of mappid_eval ([K z p/z z1 p1/z1 Kp Ki Kd Tf]), the linear margins over all 68 plants and the systune values.
if nargin < 1 || isempty(noiseTargets), noiseTargets = [4 8 16 32 64]; end
if nargin < 2 || isempty(nStart), nStart = 10; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = result_dir('MapPID', 'Design');
[Gj, w] = mappid_plants();
P0 = map_params(); Cal = calibrate_map_cached(); ops = map_op_points();
speeds = [20 40 60 80 100];
wm = 2 * pi * 100;
Gm = tf(wm, [1 wm]);
Dly = pade(tf(1, 1, 'IODelay', 1e-3), 2);
Pset = {};
for v = speeds
    for i = 1:size(ops, 1)
        G = map_plant_lin(P0, v / 3.6, ops(i, 1) * P0.g, ops(i, 2));
        Pset{end + 1} = -ss(G) * Gm * Dly; %#ok<AGROW>
    end
end
fprintf('tune_mappid_linear: %d plants, noise targets %s, %d random starts\n', numel(Pset), mat2str(noiseTargets), nStart);

%% tunable controller (shared by every model)
K  = realp('K', 5);      K.Minimum = 0;      K.Maximum = 16;
Tz = realp('Tz', 0.02);  Tz.Minimum = 2e-3;  Tz.Maximum = 0.2;
Tp = realp('Tp', 0.002); Tp.Minimum = 3.2e-4; Tp.Maximum = 0.18;
Tz1 = realp('Tz1', 0.04); Tz1.Minimum = 1 / 120; Tz1.Maximum = 1 / 8;
Tp1 = realp('Tp1', 0.1); Tp1.Minimum = 0.05;  Tp1.Maximum = 0.33;
Cpid = tunablePID('C', 'PID');
Cpid.Kp.Value = 1; Cpid.Ki.Value = 20; Cpid.Kd.Value = 0.01; Cpid.Tf.Value = 0.003;
Cpid.Kp.Minimum = 0; Cpid.Kp.Maximum = 3; Cpid.Ki.Minimum = 0; Cpid.Ki.Maximum = 200;
Cpid.Kd.Minimum = 0; Cpid.Kd.Maximum = 0.05; Cpid.Tf.Minimum = 1e-3; Cpid.Tf.Maximum = 0.02;
s = tf('s');
H = ((Tz * s + 1) / (Tp * s + 1)) * ((Tz1 * s + 1) / (Tp1 * s + 1));
facs = [0 0.5 1];
APu = AnalysisPoint('u'); APy = AnalysisPoint('y');
Pall = []; Call = [];
for ip = 1:numel(Pset)
    for f = facs
        Pi = Pset{ip}; Pi.InputName = 'u'; Pi.OutputName = 'yp';
        Cs = f * K * H + Cpid; Cs.InputName = 'e'; Cs.OutputName = 'uc';
        if isempty(Pall), Pall = Pi; Call = Cs; else, Pall = stack(1, Pall, Pi); Call = stack(1, Call, Cs); end %#ok<AGROW>
    end
end
APu.InputName = 'uc'; APu.OutputName = 'u';
APy.InputName = 'yp'; APy.OutputName = 'y';
S1 = sumblk('ym = y + n'); S2 = sumblk('e = r - ym');
T0 = connect(Call, APu, Pall, APy, S1, S2, {'r', 'n'}, {'ym'});
WS = makeweight(8, [12 1], 0.4);              % |S| <= 1/8 at DC, crossover 12 rad/s (about 2 Hz), 0.4 above: error small in the steering band
ReqS = TuningGoal.Sensitivity('y', WS);
ReqM = TuningGoal.Margins('u', 20 * log10(1.5), 15);
opt = systuneOptions('RandomStart', nStart, 'Display', 'off');
rows = [];
for N = noiseTargets
    ReqN = TuningGoal.Gain('n', 'u', N);
    tStart = tic;
    try
        [Tt, fSoft, gHard] = systune(T0, ReqS, [ReqM, ReqN], opt);
    catch ME
        fprintf('  noise target %g: systune failed: %s\n', N, ME.message); continue;
    end
    B = getBlockValue(Tt);
    Kv = B.K; TzV = B.Tz; TpV = B.Tp; Tz1V = B.Tz1; Tp1V = B.Tp1;
    Cv = B.C;
    z = 1 / TzV; p = 1 / TpV; z1 = 1 / Tz1V; p1 = 1 / Tp1V;
    x = [Kv, z, p / z, z1, p1 / z1, Cv.Kp, Cv.Ki, Cv.Kd, Cv.Tf];
    d = struct('Kmax', Kv, 'lead', struct('z', z, 'p', p), 'lag', struct('z1', z1, 'p1', p1), 'Kp', x(6), 'Ki', x(7), 'Kd', x(8), 'Tf', x(9));
    Rm = mappid_margins(Gj, w, d);
    lagGain = abs((1 + 1i * 2 * pi * 2 / z1) / (1 + 1i * 2 * pi * 2 / p1));
    fprintf('  noise target %g: soft %.3f, hard %.3f | K %.2f lead (%.1f, %.1f) lag (%.1f, %.1f) Kp %.3f Ki %.2f Kd %.4f Tf %.4f | 68-plant PM %.1f GM %.2f HF %.1f lag2Hz %.3f (%.0f s)\n', ...
        N, fSoft, max(gHard), Kv, z, p, z1, p1, x(6), x(7), x(8), x(9), Rm.PM, Rm.GM, Rm.HF, lagGain, toc(tStart));
    rows = [rows; N, x, fSoft, max(gHard), Rm.PM, Rm.GM, Rm.HF, lagGain, double(Rm.stable)]; %#ok<AGROW>
end
if isempty(rows), error('tune_mappid_linear:none', 'systune produced no design'); end
names = {'noise_target', 'K', 'z', 'p_over_z', 'z1', 'p1_over_z1', 'Kp', 'Ki', 'Kd', 'Tf', 'soft', 'hard', 'PM_deg', 'GM', 'HF', 'lagGain2Hz', 'stable'};
D = array2table(rows, 'VariableNames', names);
writetable(D, fullfile(outDir, 'MapPID_systune.csv'));
end
