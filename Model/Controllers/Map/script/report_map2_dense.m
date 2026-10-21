function report_map2_dense(pick,pareto,outDir)
%REPORT_MAP2_DENSE Independent nominal seed 1..5 confirmation (Map only).
scriptDir=fileparts(mfilename('fullpath')); modelDir=fileparts(fileparts(fileparts(scriptDir))); addpath(modelDir); setup_paths; Cal=calibrate_map_cached();
reps=pareto; if height(reps)>4, reps=reps(1:4,:); end
all=[pick; reps]; [~,u]=unique(all.key,'stable'); all=all(u,:); Q=table(); errors=strings(0,2);
for i=1:height(all)
 d=struct('Ts_ctrl',1e-3,'Ts0',0.3,'Kmax',all.K(i),'lead',struct('z',all.z(i),'p',all.p(i)),'lag',struct('z1',all.z1(i),'p1',all.p1(i))); V=map_variables(Cal,d);
 for seed=1:5
  try
   [~,m]=calib_run('Model_Map',seed,V); Simulink.sdi.clear;
   r=table(string(all.key(i)),all.K(i),all.g_min(i),seed,m.R,m.S,m.R*m.S,m.TV,m.erel,m.Rg.static,m.Rg.dyn,m.Rg.mu,'VariableNames',{'key','K','g_min','seed','R_pct','S_Nm','J','TV','erel_pct','R_static','R_dyn','R_mu'}); Q=[Q;r]; %#ok<AGROW>
  catch ME
   errors(end+1,:)=[string(all.key(i)),string(getReport(ME,'basic','hyperlinks','off'))]; Simulink.sdi.clear; %#ok<AGROW>
  end
 end
end
writetable(Q,fullfile(outDir,'Map2_Dense_selection_multiseed_nominal.csv'));
if isempty(errors)
 writetable(table(strings(0,1),strings(0,1),'VariableNames',{'key','error'}),fullfile(outDir,'Map2_Dense_report_errors.csv'));
else
 writetable(array2table(errors,'VariableNames',{'key','error'}),fullfile(outDir,'Map2_Dense_report_errors.csv'));
end
fprintf('MAP2_DENSE_REPORT_DONE candidates=%d rows=%d errors=%d\n',height(all),height(Q),size(errors,1));
end
