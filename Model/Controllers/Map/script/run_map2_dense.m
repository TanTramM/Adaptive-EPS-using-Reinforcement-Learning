function run_map2_dense(workerId, nWorkers, manifestPath, outputTag)
%RUN_MAP2_DENSE Evaluate the fixed Map2_Dense_v1 (K,g_min) family.
% Each worker writes only its own resumable CSV.  No controller JSON is changed.
if nargin < 1, workerId = 1; end
if nargin < 2, nWorkers = 1; end
if nargin < 3 || isempty(manifestPath), manifestPath = ''; end
if nargin < 4 || isempty(outputTag), outputTag = ''; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir = fullfile(result_dir('Map', 'Calib'), 'TwoParamDense');
if ~exist(outDir, 'dir'), mkdir(outDir); end
if isempty(manifestPath), manifestPath = fullfile(outDir, 'Map2_Dense_manifest.csv'); end
if ~exist(manifestPath, 'file'), error('run_map2_dense:manifest', 'Run prepare_map2_dense first.'); end
M = readtable(manifestPath, 'TextType', 'string');
ix = find(mod((1:height(M)) - 1, nWorkers) + 1 == workerId);
if isempty(outputTag)
    csvPath = fullfile(outDir, sprintf('Map2_Dense_measurements_w%d.csv', workerId));
else
    csvPath = fullfile(outDir, sprintf('Map2_Dense_measurements_%s_w%d.csv', outputTag, workerId));
end
if exist(csvPath, 'file'), T = readtable(csvPath, 'TextType', 'string'); else, T = table(); end
done = string.empty;
if ~isempty(T), done = T.key; end
Cal = calibrate_map_cached();
assignin('base', 'Map_calibration_override', Cal);
run(fullfile(modelDir, 'Controllers', 'Map', 'load_map.m'));
[Gj, w] = linearResponses();
for q = ix(:)'
    key = M.key(q);
    if any(done == key), continue; end
    t0 = tic; D = synthesize(M(q,:), Gj, w);
    R = blankRow(M(q,:), D);
    if D.ok
        d = struct('Ts_ctrl', 1e-3, 'Ts0', 0.3, 'Kmax', M.K(q), ...
            'lead', struct('z', D.z, 'p', D.p), 'lag', struct('z1', D.z1, 'p1', D.p1));
        V = map_variables(Cal, d);
        [~, m0] = runOne(V, 0, 1, 0); [~, m1] = runOne(V, 1, 1, 0);
        [~, mg] = runOne(V, 1, 2, 0); [~, md] = runOne(V, 1, 1, .001);
        R = fillMetrics(R, m0, m1, mg, md);
    end
    R.seconds = toc(t0);
    % A resumed CSV is read as string/double, whereas struct2table keeps a
    % char key and logical flags. Normalize before vertcat so retry is truly
    % resumable rather than failing after its next completed candidate.
    U = struct2table(R); U = checkpointSchema(U);
    if isempty(T), T = U; else, T = checkpointSchema(T); T = [T; U]; end %#ok<AGROW>
    writetable(T, csvPath); done(end+1) = key; %#ok<AGROW>
    fprintf('MAP2_DENSE worker %d: %d/%d %s complete\n', workerId, find(ix == q), numel(ix), key);
end
fprintf('MAP2_DENSE_WORKER_DONE %d\n', workerId);
end

function T=checkpointSchema(T)
T.key=string(T.key);
for n={'is_baseline','synth_ok','finite_nominal','finite_gain','finite_delay'}
    if ismember(n{1},T.Properties.VariableNames), T.(n{1})=double(T.(n{1})); end
end
end

function [L,m] = runOne(V, seed, gain, delay)
V.act_gain_mult = gain; V.ctrl_delay = delay;
[L,m] = calib_run('Model_Map', seed, V); Simulink.sdi.clear;
end

function [Gj,w] = linearResponses()
P = map_params(); Cal = calibrate_map_cached(); ops = map_op_points();
w = logspace(-1,5,3000)'; Gj = cell(numel(Cal.v_kmh)*size(ops,1),1); k=1;
for iv=1:numel(Cal.v_kmh), for io=1:size(ops,1)
    Gj{k}=squeeze(freqresp(map_plant_lin(P,Cal.v_kmh(iv)/3.6,ops(io,1)*P.g,ops(io,2)),w)); k=k+1;
end, end
end

function D = synthesize(r,Gj,w)
if r.is_baseline
    D = struct('ok',1,'z',33.5009375175479,'p',600.10834977333,'z1',28.1275792678243,'p1',10.6884801217732,'PM',NaN,'GM',NaN,'HF',NaN,'nTried',0);
    X = map_margins_batch(Gj{1},w,r.K,D.z,D.p,D.z1,D.p1); %#ok<NASGU>
    return
end
D0 = design_leadlag(Gj,w,r.K,r.g_min < 1,[r.g_min 12.57]);
D = struct('ok',D0.ok,'z',D0.z,'p',D0.p,'z1',D0.z1,'p1',D0.p1,'PM',D0.PM,'GM',D0.GM,'HF',D0.HF,'nTried',D0.nTried);
end

function R = blankRow(r,D)
R = struct('key',char(r.key),'is_baseline',r.is_baseline,'K',r.K,'g_min',r.g_min,'synth_ok',D.ok,'z',D.z,'p',D.p,'z1',D.z1,'p1',D.p1,'PM_deg',D.PM,'GM',D.GM,'HF',D.HF,'n_synth_tried',D.nTried, ...
 'lagGain2Hz',NaN,'R0_pct',NaN,'S0_Nm',NaN,'J0',NaN,'TV0',NaN,'erel0_pct',NaN,'R0_static',NaN,'R0_dyn',NaN,'R0_mu',NaN,'R1_pct',NaN,'Rgain_pct',NaN,'Rdelay_pct',NaN,'ratio_gain',NaN,'ratio_delay',NaN,'finite_nominal',false,'finite_gain',false,'finite_delay',false,'seconds',NaN);
end

function R=fillMetrics(R,m0,m1,mg,md)
R.lagGain2Hz=abs((1+1i*12.57/R.z1)/(1+1i*12.57/R.p1));
R.R0_pct=m0.R; R.S0_Nm=m0.S; R.J0=m0.R*m0.S; R.TV0=m0.TV; R.erel0_pct=m0.erel;
R.R0_static=m0.Rg.static; R.R0_dyn=m0.Rg.dyn; R.R0_mu=m0.Rg.mu;
R.R1_pct=m1.R; R.Rgain_pct=mg.R; R.Rdelay_pct=md.R; R.ratio_gain=mg.R/m1.R; R.ratio_delay=md.R/m1.R;
R.finite_nominal=isfinite(m0.R); R.finite_gain=isfinite(mg.R); R.finite_delay=isfinite(md.R);
end

