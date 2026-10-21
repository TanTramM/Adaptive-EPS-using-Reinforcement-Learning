function prepare_map2_dense_resume()
% Prepare only keys absent from every completed Map2 Dense checkpoint.
scriptDir=fileparts(mfilename('fullpath')); modelDir=fileparts(fileparts(fileparts(scriptDir))); addpath(modelDir); setup_paths;
outDir=fullfile(result_dir('Map','Calib'),'TwoParamDense');
M=readtable(fullfile(outDir,'Map2_Dense_manifest.csv'),'TextType','string');
F=dir(fullfile(outDir,'Map2_Dense_measurements*.csv')); seen=string.empty;
for i=1:numel(F), A=readtable(fullfile(F(i).folder,F(i).name),'TextType','string'); seen=[seen;string(A.key)]; end %#ok<AGROW>
R=M(~ismember(string(M.key),unique(seen)),:);
assert(~isempty(R),'prepare_map2_dense_resume:none','No missing Map2 Dense keys.');
writetable(R,fullfile(outDir,'Map2_Dense_resume_manifest.csv'));
fprintf('MAP2_DENSE_RESUME_MANIFEST %d\n',height(R));
end
