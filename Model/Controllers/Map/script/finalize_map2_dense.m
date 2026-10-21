function finalize_map2_dense()
%FINALIZE_MAP2_DENSE Merge checkpoints and make an auditable selection.
% This function deliberately never writes Model/data/map.json.
scriptDir=fileparts(mfilename('fullpath')); modelDir=fileparts(fileparts(fileparts(scriptDir))); addpath(modelDir); setup_paths;
outDir=fullfile(result_dir('Map','Calib'),'TwoParamDense'); F=dir(fullfile(outDir,'Map2_Dense_measurements*.csv'));
assert(~isempty(F),'finalize_map2_dense:noData','No Map2 Dense measurements.');
T=table();
for i=1:numel(F)
 A=readtable(fullfile(F(i).folder,F(i).name),'TextType','string'); if isempty(T),T=A;else,T=[T;A];end %#ok<AGROW>
end
[~,ix]=unique(T.key,'stable'); T=T(ix,:); writetable(T,fullfile(outDir,'Map2_Dense_all_measurements.csv'));
names=T.Properties.VariableNames;
writetable(T(:,intersect({'key','is_baseline','K','g_min','synth_ok','z','p','z1','p1','PM_deg','GM','HF','n_synth_tried','lagGain2Hz','seconds'},names,'stable')),fullfile(outDir,'Map2_Dense_synthesis.csv'));
writetable(T(:,intersect({'key','is_baseline','K','g_min','R0_pct','S0_Nm','J0','TV0','erel0_pct','R0_static','R0_dyn','R0_mu','finite_nominal'},names,'stable')),fullfile(outDir,'Map2_Dense_nominal_seed0.csv'));
writetable(T(:,intersect({'key','is_baseline','K','g_min','R1_pct','Rgain_pct','Rdelay_pct','ratio_gain','ratio_delay','finite_gain','finite_delay'},names,'stable')),fullfile(outDir,'Map2_Dense_stress_seed1.csv'));
req=T.synth_ok==1 & T.finite_nominal==1 & T.finite_gain==1 & T.finite_delay==1;
T.v_PM=violLower(T.PM_deg,30,30); T.v_GM=violLower(T.GM,2,2); T.v_lag=violLower(T.lagGain2Hz,1/sqrt(2),1/sqrt(2));
T.v_erel=violUpper(T.erel0_pct,10,10); T.v_gain=violUpper(T.ratio_gain,2,2); T.v_delay=violUpper(T.ratio_delay,2,2);
V=[T.v_PM T.v_GM T.v_lag T.v_erel T.v_gain T.v_delay]; T.Vmax=max(V,[],2,'omitnan'); T.Vsum=sum(V,2,'omitnan');
T.full_constraints_pass=req & all(isfinite(V),2) & T.Vmax<=1e-9; writetable(T,fullfile(outDir,'Map2_Dense_constraints.csv'));
mapRows=T(~logical(T.is_baseline) & req,:); assert(~isempty(mapRows),'finalize_map2_dense:noFinite','No finite Map2 candidate.');
ok=mapRows(mapRows.full_constraints_pass,:);
if ~isempty(ok)
 j=min(ok.J0); pool=ok(ok.J0<=1.03*j,:); pool=sortrows(pool,{'PM_deg','J0','K','g_min'},{'descend','ascend','ascend','ascend'}); pick=pool(1,:); kind='feasible_selected'; pass=true; pareto=paretoRows(ok,{'R0_pct','S0_Nm','J0'});
else
 pool=sortrows(mapRows,{'Vmax','Vsum','J0','PM_deg','K','g_min'},{'ascend','ascend','ascend','descend','ascend','ascend'}); pick=pool(1,:); kind='compromise_candidate'; pass=false; pareto=paretoRows(mapRows,{'Vmax','Vsum','J0'});
end
writetable(pareto,fullfile(outDir,'Map2_Dense_violation_pareto.csv'));
writetable(pick,fullfile(outDir,['Map2_Dense_' kind '.csv']));
S=table2struct(pick); S.profile='Map2_Dense_v1'; S.full_constraints_pass=pass; S.n_manifest=307; S.n_map2=height(mapRows); S.n_full_pass=height(ok); S.kind=kind; writeJson(S,fullfile(outDir,['Map2_Dense_' kind '.json']));
summary=struct('profile','Map2_Dense_v1','selection_kind',kind,'full_constraints_pass',pass,'n_manifest',307,'n_measured',height(T),'n_map2_finite',height(mapRows),'n_full_pass',height(ok),'selected_key',char(pick.key),'selected_K',pick.K,'selected_g_min',pick.g_min);
writeJson(summary,fullfile(outDir,'Map2_Dense_selection_summary.json'));
save(fullfile(outDir,['Map2_Dense_' kind '.mat']),'pick','S','summary','pareto');
errPath=fullfile(outDir,'Map2_Dense_execution_errors.csv');
if ~isfile(errPath), writetable(table(strings(0,1),strings(0,1),strings(0,1),'VariableNames',{'worker','classification','detail'}),errPath); end
report_map2_dense(pick,pareto,outDir);
writeReport(T,pick,kind,pass,mapRows,ok,pareto,outDir);
fprintf('MAP2_DENSE_FINAL_DONE %s pass=%d\n',kind,pass);
end

function v=violLower(x,limit,scale), v=max(0,(limit-x)/scale); v(~isfinite(v))=Inf; end
function v=violUpper(x,limit,scale), v=max(0,(x-limit)/scale); v(~isfinite(v))=Inf; end
function writeJson(S,path), fid=fopen(path,'w'); assert(fid>0,'Cannot write %s',path); c=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(S,'PrettyPrint',true)); end
function P=paretoRows(T,vars)
X=T{:,vars}; keep=true(height(T),1);
for i=1:height(T), for j=1:height(T), if i~=j && all(X(j,:)<=X(i,:)) && any(X(j,:)<X(i,:)), keep(i)=false; break; end, end, end
P=sortrows(T(keep,:),vars,'ascend');
end
function writeReport(T,pick,kind,pass,mapRows,ok,pareto,outDir)
fid=fopen(fullfile(outDir,'Map2_Dense_report.md'),'w'); assert(fid>0); c=onCleanup(@()fclose(fid));
fprintf(fid,'# Map2 Dense v1 final report\n\n');
fprintf(fid,'Selection: **%s**. Full constraints pass: **%d**. `map.json` was not modified.\n\n',kind,pass);
fprintf(fid,'| Item | Value |\n|---|---:|\n');
fprintf(fid,'| Manifest rows (Map2 + legacy baseline) | %d |\n| Measured unique rows | %d |\n| Finite Map2 rows | %d |\n| Full-pass Map2 rows | %d |\n',307,height(T),height(mapRows),height(ok));
fprintf(fid,'\n## Selected candidate\n\n| K | g_min | PM (deg) | GM | lag @2 Hz | e_rel (%%) | gain ratio | delay ratio | J | Vmax |\n|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
fprintf(fid,'| %.12g | %.12g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n',pick.K,pick.g_min,pick.PM_deg,pick.GM,pick.lagGain2Hz,pick.erel0_pct,pick.ratio_gain,pick.ratio_delay,pick.J0,pick.Vmax);
b=T(logical(T.is_baseline),:); if ~isempty(b)
 fprintf(fid,'\n## Legacy baseline (report-only)\n\n| K | g_min | e_rel (%%) | gain ratio | delay ratio | J |\n|---:|---:|---:|---:|---:|---:|\n');
 fprintf(fid,'| %.12g | %.12g | %.6g | %.6g | %.6g | %.6g |\n',b.K(1),b.g_min(1),b.erel0_pct(1),b.ratio_gain(1),b.ratio_delay(1),b.J0(1));
end
fprintf(fid,'\n## Pareto / violation surface\n\nThe full K--g_min surface and each gate are in `Map2_Dense_constraints.csv`; nondominated rows are in `Map2_Dense_violation_pareto.csv` (%d rows). Multi-seed nominal confirmation for selected and up to four representatives is in `Map2_Dense_selection_multiseed_nominal.csv`.\n',height(pareto));
end
