function summarize_friction()
%SUMMARIZE_FRICTION Tables and answers Q1-Q4 of Documents/Shared/KeHoach_MaSatCotLai.txt (sections 3 and 4). Reads, never runs a simulation.
%
%   Friction_SSW_whole.csv      Ctrl, Case, Seed, ERMS_nom, ERMS_Tf0, dERMS_pct (+ rows mean and sd, sample sd n-1)
%   Friction_SSW_windows.csv    Ctrl, Case, Window, Seed, eps_nom_pct, eps_Tf0_pct, eps_static_pct (+ rows mean and sd)
%   Map_CALIB_erel_friction.csv Label, Seed, erelSigned_nom, erelSigned_Tf0, erel_static (+ summary rows)
%   Friction_answers.txt        Q1-Q4 by the reading rules of section 4 (fixed before the runs)
%
%   Nominal data = Result/Controllers/<Ctrl>/Cases_ssw/<Ctrl>_metrics_s<seed>.csv (R0 confirmed they equal a fresh nominal run).
%   eps = column Mean_eT_signed_pct_of_Tdref of the window rows (equation 5.2). Static references (fixed before the runs):
%     STEADY windows: ch5_static.csv, matched by (v, a_y) from the label v<km/h>a0p<digits>[l|r].
%     SLIP windows ramp_dn and ramp_up: mean of ch5_static_ramp.csv over 45..90 km/h (the ramps sweep 45-90 and back); min and max are reported too.
%   The four STEADY levels of Q2 (fixed before the runs): v45a0p35l, v65a0p35r, v85a0p38l, v25a0p25r.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
repoDir = fileparts(modelDir);
addpath(fullfile(modelDir, 'shared')); setup_paths;
rootDir = fullfile(repoDir, 'Result', 'Compare', 'Friction');
ctrls = {'Map', 'PID', 'MapPID'}; seeds = 99995:99999; cases = {'STEADY', 'SLIP', 'WEAVE'};
St = readtable(fullfile(repoDir, 'Documents', 'Thesis', 'figures', 'ch5_static.csv'));
Sr = readtable(fullfile(repoDir, 'Documents', 'Thesis', 'figures', 'ch5_static_ramp.csv'));
rampStatic = mean(Sr.eps_static_pct);

%% whole case and windows
Wr = struct('Ctrl', {}, 'Case', {}, 'Seed', {}, 'ERMS_nom', {}, 'ERMS_Tf0', {}, 'dERMS_pct', {});
Xr = struct('Ctrl', {}, 'Case', {}, 'Window', {}, 'Seed', {}, 'eps_nom_pct', {}, 'eps_Tf0_pct', {}, 'eps_static_pct', {});
for ic = 1:numel(ctrls)
    for is = 1:numel(seeds)
        sens = sensor_tag(seeds(is));
        Mn = readtable(fullfile(repoDir, 'Result', 'Controllers', ctrls{ic}, 'Cases_ssw', sprintf('%s_metrics_%s.csv', ctrls{ic}, sens)));
        Mf = readtable(fullfile(rootDir, 'Tf0', sprintf('%s_metrics_%s.csv', ctrls{ic}, sens)));
        assert(isequal(Mn.Window, Mf.Window) && isequal(Mn.Case, Mf.Case), 'summarize_friction: layout differs %s %s', ctrls{ic}, sens);
        for k = 1:height(Mn)
            if strcmp(Mn.Window{k}, 'whole case')
                Wr(end+1) = struct('Ctrl', ctrls{ic}, 'Case', Mn.Case{k}, 'Seed', num2str(seeds(is)), 'ERMS_nom', Mn.RMS_eT_Nm(k), 'ERMS_Tf0', Mf.RMS_eT_Nm(k), ...
                    'dERMS_pct', 100 * (Mf.RMS_eT_Nm(k) - Mn.RMS_eT_Nm(k)) / Mn.RMS_eT_Nm(k)); %#ok<AGROW>
            else
                Xr(end+1) = struct('Ctrl', ctrls{ic}, 'Case', Mn.Case{k}, 'Window', Mn.Window{k}, 'Seed', num2str(seeds(is)), ...
                    'eps_nom_pct', Mn.Mean_eT_signed_pct_of_Tdref(k), 'eps_Tf0_pct', Mf.Mean_eT_signed_pct_of_Tdref(k), ...
                    'eps_static_pct', staticFor(Mn.Case{k}, Mn.Window{k}, St, rampStatic)); %#ok<AGROW>
            end
        end
    end
end
W = struct2table(Wr); X = struct2table(Xr);
writetable(addStats(W, {'Ctrl', 'Case'}, {'ERMS_nom', 'ERMS_Tf0', 'dERMS_pct'}), fullfile(rootDir, 'Friction_SSW_whole.csv'));
writetable(addStats(X, {'Ctrl', 'Case', 'Window'}, {'eps_nom_pct', 'eps_Tf0_pct', 'eps_static_pct'}), fullfile(rootDir, 'Friction_SSW_windows.csv'));

%% CALIB of Map
R = readtable(fullfile(rootDir, 'Friction_CALIB_runs.csv'));
Rn = R(strcmp(R.Variant, 'nom'), :); Rf = R(strcmp(R.Variant, 'Tf0'), :);
C = table(Rn.Label, Rn.Seed, Rn.erelSigned, 'VariableNames', {'Label', 'Seed', 'erelSigned_nom'});
C.erelSigned_Tf0 = nan(height(C), 1);
for k = 1:height(C), C.erelSigned_Tf0(k) = Rf.erelSigned(strcmp(Rf.Label, C.Label{k}) & Rf.Seed == C.Seed(k)); end
labs = unique(C.Label, 'stable');
stat = staticCalib(labs);
C.erel_static = nan(height(C), 1);
for k = 1:height(C), C.erel_static(k) = stat(strcmp(labs, C.Label{k})); end
sd = unique(C.Seed)';
emaxNom = nan(1, numel(sd)); emaxTf0 = emaxNom; labNom = cell(1, numel(sd)); labTf0 = labNom;
for k = 1:numel(sd)
    in = C.Seed == sd(k);
    [emaxNom(k), i1] = max(abs(C.erelSigned_nom(in))); [emaxTf0(k), i2] = max(abs(C.erelSigned_Tf0(in)));
    l = C.Label(in); labNom{k} = l{i1}; labTf0{k} = l{i2};
end
% summary rows are appended as text lines in a second file section: keep the csv rectangular, summary goes into its own csv
writetable(C, fullfile(rootDir, 'Map_CALIB_erel_friction.csv'));
S = table(sd(:), emaxNom(:), labNom(:), emaxTf0(:), labTf0(:), 'VariableNames', {'Seed', 'erelMax_nom', 'window_nom', 'erelMax_Tf0', 'window_Tf0'});
S(end+1, :) = {NaN, mean(emaxNom), {'mean of five seeds'}, mean(emaxTf0), {'mean of five seeds'}};
S(end+1, :) = {NaN, max(emaxNom), {'max over seeds (Table 4.5)'}, max(emaxTf0), {'max over seeds'}};
writetable(S, fullfile(rootDir, 'Map_CALIB_erel_friction_summary.csv'));

%% answers
Xm = groupsummary(X, {'Ctrl', 'Case', 'Window'}, 'mean', {'eps_nom_pct', 'eps_Tf0_pct', 'eps_static_pct'});
Xm.Properties.VariableNames = strrep(Xm.Properties.VariableNames, 'mean_', '');
fid = fopen(fullfile(rootDir, 'Friction_answers.txt'), 'w');
pr = @(varargin) fprintf(fid, varargin{:});
pr('Q1 (SLIP, Map, two speed windows; mean of five seeds; static reference = mean of ch5_static_ramp over 45-90 km/h = %.3f %%, range %.3f .. %.3f)\n', rampStatic, min(Sr.eps_static_pct), max(Sr.eps_static_pct));
ok1 = true; part1 = true;
for w = {'ramp_dn', 'ramp_up'}
    r = Xm(strcmp(Xm.Ctrl, 'Map') & strcmp(Xm.Case, 'SLIP') & strcmp(Xm.Window, w{1}), :);
    sameSign = sign(r.eps_Tf0_pct) == sign(r.eps_static_pct) || abs(r.eps_static_pct) < 1e-9;
    d = abs(r.eps_Tf0_pct - r.eps_static_pct);
    pr('  %s: nominal %.2f %%, Tf0 %.2f %%, static %.2f %%; same sign %d; |Tf0 - static| = %.2f\n', w{1}, r.eps_nom_pct, r.eps_Tf0_pct, r.eps_static_pct, sameSign, d);
    ok1 = ok1 && sameSign && d <= 1; part1 = part1 && sameSign;
end
pr('  ANSWER Q1: %s\n\n', pick(ok1, 'ma sat giai thich duoc', part1, 'giai thich mot phan', 'khong'));

pr('Q2 (STEADY, Map; mean of five seeds)\n');
lv = {'v45a0p35l', 'v65a0p35r', 'v85a0p38l', 'v25a0p25r'}; ok2 = true; half = true;
for k = 1:4
    r = Xm(strcmp(Xm.Ctrl, 'Map') & strcmp(Xm.Case, 'STEADY') & strcmp(Xm.Window, lv{k}), :);
    dn = abs(r.eps_nom_pct - r.eps_static_pct); df = abs(r.eps_Tf0_pct - r.eps_static_pct);
    pr('  %s: nominal %.2f, Tf0 %.2f, static %.2f; gap nominal %.2f -> Tf0 %.2f\n', lv{k}, r.eps_nom_pct, r.eps_Tf0_pct, r.eps_static_pct, dn, df);
    ok2 = ok2 && df <= 1; half = half && df <= 0.5 * dn;
end
pr('  ANSWER Q2: %s\n\n', pick(ok2, 'giai thich duoc', half, 'mot phan', 'khong'));

pr('Q3 (CALIB, Map, five seeds 99990-99994)\n');
for k = 1:numel(sd), pr('  seed %d: nominal %.4f %% in %s; Tf0 %.4f %% in %s\n', sd(k), emaxNom(k), labNom{k}, emaxTf0(k), labTf0{k}); end
pr('  e_rel,max nominal: mean %.4f, max %.4f (Table 4.5: 26.2366); Tf0: mean %.4f, max %.4f; analytic static maximum 5.73 -> threshold 6.73 on the mean\n', mean(emaxNom), max(emaxNom), mean(emaxTf0), max(emaxTf0));
pr('  ANSWER Q3: %s\n\n', pick(mean(emaxTf0) <= 6.73, 'do ma sat', false, '', 'nguyen nhan khac, chua ro'));

pr('Q4 (report only: dERMS_pct = 100 (E_Tf0 - E_nom)/E_nom, mean of five seeds; sd in brackets)\n');
Wm = groupsummary(W, {'Ctrl', 'Case'}, {'mean', 'std'}, 'dERMS_pct');
for ic = 1:numel(ctrls)
    for icase = 1:numel(cases)
        r = Wm(strcmp(Wm.Ctrl, ctrls{ic}) & strcmp(Wm.Case, cases{icase}), :);
        pr('  %-6s %-6s dERMS %+.2f %% (sd %.2f)\n', ctrls{ic}, cases{icase}, r.mean_dERMS_pct, r.std_dERMS_pct);
    end
end
fclose(fid);
disp(fileread(fullfile(rootDir, 'Friction_answers.txt')));
end

%% ---------------------------------------------------------------- helpers
function s = staticFor(caseName, win, St, rampStatic)
    s = NaN;
    if strcmp(caseName, 'STEADY')
        t = regexp(win, '^v(\d+)a0p(\d+)[lr]$', 'tokens', 'once');
        if ~isempty(t)
            v = str2double(t{1}); ay = str2double(['0.' t{2}]);
            i = find(St.v_kmh == v & abs(St.ay_g - ay) < 1e-9);
            if ~isempty(i), s = St.eps_static_pct(i); end
        end
    elseif strcmp(caseName, 'SLIP') && any(strcmp(win, {'ramp_dn', 'ramp_up'}))
        s = rampStatic;
    end
end
function T = addStats(T, keys, vals)
    % append rows 'mean' and 'sd' (sample, n-1) per key group
    seedCol = 'Seed';
    out = T;
    g = unique(T(:, keys), 'rows', 'stable');
    for i = 1:height(g)
        in = true(height(T), 1);
        for k = 1:numel(keys), in = in & strcmp(T.(keys{k}), g.(keys{k}){i}); end
        for stat = {'mean', 'sd'}
            row = T(find(in, 1), :); row.(seedCol) = {stat{1}};
            for j = 1:numel(vals)
                x = T.(vals{j})(in);
                if strcmp(stat{1}, 'mean'), row.(vals{j}) = mean(x); else, row.(vals{j}) = std(x); end
            end
            out = [out; row]; %#ok<AGROW>
        end
    end
    T = out;
end
function s = staticCalib(labs)
    % signed analytic static error of Map [%] at each static window label (same method as tools/make_fig_thesis_ch3.m): mu 0.8, no friction
    repoDir = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
    dataDir = fullfile(repoDir, 'Model', 'shared', 'data');
    P = map_params();
    J = jsondecode(fileread(fullfile(dataDir, 'map.json'), 'Encoding', 'UTF-8')); d = J.design;
    ref = jsondecode(fileread(fullfile(dataDir, 'ref.json'), 'Encoding', 'UTF-8'));
    Cal = calibrate_map(false);
    tref = @(v, ay) interp2(ref.fine.ay_breakpoints_g(:)', ref.fine.v_breakpoints_kmh(:), ref.fine.table_Nm', ay, v, 'linear');
    s = nan(numel(labs), 1);
    for k = 1:numel(labs)
        t = regexp(labs{k}, '^static_v(\d+)_a(?:pos|neg)0p(\d+)', 'tokens', 'once');
        assert(~isempty(t), 'summarize_friction: unexpected static label %s', labs{k});
        v = str2double(t{1}); ay = str2double(['0.' t{2}]);
        M = map_table(Cal, find(Cal.v_kmh == v), d.Kmax, d.Ts0);
        Tref = tref(v, ay); Tr = map_steady_state(P, v / 3.6, ay * P.g, 0.8).T_r;
        Ts = fzero(@(x) x + map_eval(M, x) - Tr, [0, Tr]);
        s(k) = 100 * (Ts - Tref) / Tref;
    end
end
function r = pick(varargin)
    % pick(cond1, text1, cond2, text2, ..., elseText)
    r = varargin{end};
    for k = 1:2:numel(varargin) - 1
        if varargin{k}, r = varargin{k + 1}; return; end
    end
end
