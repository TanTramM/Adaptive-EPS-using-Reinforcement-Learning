function report = report_mappid_six_map()
%REPORT_MAPPID_SIX_MAP Audit the finished Map(2) grid without selecting a design.
% Read-only with respect to models, standard JSON and scientific inputs.
% Writes a joined evidence table and an explicitly unselected search report.
scriptDir=fileparts(mfilename('fullpath'));
modelDir=fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
outDir=fullfile(result_dir('Map','Calib'),'TwoParam');
files=dir(fullfile(outDir,'Map_CALIB_grid_w*_s00000.csv'));
T=table();
for k=1:numel(files), T=[T;readtable(fullfile(files(k).folder,files(k).name))]; end %#ok<AGROW>
assert(~isempty(T),'The independent Map(2) grid is absent.');
[~,ids]=unique(round(T{:,{'K','g_min'}},10,'significant'),'rows','stable');
T=T(sort(ids),:);
fail=readtable(fullfile(outDir,'Map_CALIB_margin_failures_s00000.csv'));
T.margin_gain_ratio_seed1=nan(height(T),1);
for k=1:height(T)
    hit=abs(fail.K-T.K(k))<=1e-9*max(1,abs(T.K(k))) & abs(fail.g_min-T.g_min(k))<=1e-9;
    if any(hit), T.margin_gain_ratio_seed1(k)=fail.ratio_gain(find(hit,1)); end
end
ok=T.simulated==1 & all(T{:,{'c1','c2','c3','c4'}}<=0,2) & T.PM_deg>=30 & T.GM>=2;
F=T(ok,:);
assert(~isempty(F) && all(isfinite(F.margin_gain_ratio_seed1)), ...
    'The margin evidence does not cover every nominally feasible design.');
assert(all(F.margin_gain_ratio_seed1>2), ...
    'This failure-only report must not label a passing design as rejected.');
[~,best]=min(F.J); [~,robust]=min(F.margin_gain_ratio_seed1);
report=struct('profile','Map2_MapPID6_v1','grid_complete',true, ...
    'margin_scan_complete',true,'standalone_selected',false, ...
    'search_seed',0,'margin_seed',1,'gain_ratio_limit',2, ...
    'n_evaluated',height(T),'n_simulated',nnz(T.simulated==1), ...
    'n_nominally_feasible',height(F),'n_gain_margin_pass',0, ...
    'nominal_best',table2struct(F(best,:)), ...
    'lowest_gain_ratio',table2struct(F(robust,:)), ...
    'note','No point in this registered grid passes the unchanged gain x2 gate. This is not proof that the entire continuous family is infeasible. No selected Map or S2 initialization is published.', ...
    'date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
key=sprintf('K%.12g_g%.12g',F.K(best),F.g_min(best));
saved=load(fullfile(outDir,'Compensators',[key '.mat']),'D'); D=saved.D;
assert(D.ok);
report.nominal_best_compensator=struct('Kmax',F.K(best),'g_min',F.g_min(best), ...
    'lead',struct('z',D.z,'p',D.p),'lag',struct('z1',D.z1,'p1',D.p1));
writetable(T,fullfile(outDir,'Map_CALIB_grid_margin_report_s00000.csv'));
file=fullfile(outDir,'Map_CALIB_search_report.json');
fid=fopen(file,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); fclose(fid);
fprintf('MAP2_AUDIT: %d evaluated, %d simulated, %d nominally feasible, 0 margin pass; minimum gain ratio %.9g > 2.\n', ...
    height(T),nnz(T.simulated==1),height(F),F.margin_gain_ratio_seed1(robust));
end
