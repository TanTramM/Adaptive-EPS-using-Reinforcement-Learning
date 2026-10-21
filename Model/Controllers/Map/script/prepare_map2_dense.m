function M = prepare_map2_dense()
%PREPARE_MAP2_DENSE Create the immutable Map2_Dense_v1 manifest.
scriptDir=fileparts(mfilename('fullpath')); modelDir=fileparts(fileparts(fileparts(scriptDir))); addpath(modelDir); setup_paths;
outDir=fullfile(result_dir('Map','Calib'),'TwoParamDense'); if ~exist(outDir,'dir'), mkdir(outDir); end
path=fullfile(outDir,'Map2_Dense_manifest.csv');
u=(0:16)'/16; K=5*(16/5).^u; g=1/sqrt(2)+(1-1/sqrt(2))*u;
[KK,GG]=ndgrid(K,g); X=[KK(:),GG(:)]; X=[X; 6*ones(17,1),g]; X=unique(round(X,12),'rows','stable');
assert(size(X,1)==306,'prepare_map2_dense:count','Expected 306 Map2 pairs.');
M=table(strings(307,1),false(307,1),[X(:,1);6],[X(:,2);NaN],'VariableNames',{'key','is_baseline','K','g_min'});
for i=1:306, M.key(i)=sprintf('map2_K%.12g_g%.12g',M.K(i),M.g_min(i)); end
M.key(307)='baseline_legacy'; M.is_baseline(307)=true;
writetable(M,path); fprintf('MAP2_DENSE_MANIFEST_DONE %s\n',path);
end
