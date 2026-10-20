function test_mappid_six_selector()
%TEST_MAPPID_SIX_SELECTOR Check ordered parallel margin fallback on mock data.
% No plant simulation or real search CSV/JSON is modified. Run after the Map
% workers exit, so the temporary two-worker pool does not compete for RAM.
testDir=fullfile(tempdir,['AdaptiveEPS_selector_' char(java.util.UUID.randomUUID)]);
mkdir(testDir);
K=(1:3)'; seed=zeros(3,1); simulated=ones(3,1);
R_pct=K; S_Nm=1.2-.2*K; J=R_pct.*S_Nm;
PM_deg=[50;45;40]; GM=3*ones(3,1); erel_pct=zeros(3,1);
c1=-ones(3,1); c2=c1; c3=c1; c4=c1;
T=table(K,seed,simulated,R_pct,S_Nm,J,PM_deg,GM,erel_pct,c1,c2,c3,c4);
writetable(T,fullfile(testDir,'SixTest_CALIB_grid_w1_s00000.csv'));
s=struct('name','SixTest','outDir',testDir,'vn',{{'K'}}, ...
    'seed0',0,'seeds',1:5,'evalFcn',@mockEval,'marginFcn',@mockMargin, ...
    'toDesign',@(x)struct('K',x(1)),'jsonPath',fullfile(testDir,'unused.json'), ...
    'marginWorkers',2,'PMfin',30,'GMfin',2,'erelMax',10);
sel=select_pareto(s,false);
assert(sel.x==2 && sel.margin.pass && sel.nFeasible==3, ...
    'test_mappid_six_selector:wrongPick','Parallel fallback must choose rank 2.');
cache=readtable(fullfile(testDir,'SixTest_CALIB_margin_failures_s00000.csv'));
assert(height(cache)==1 && cache.K==1,'Margin cache contains an invalid rejection.');
assert(~isfile(s.jsonPath),'The selector must not write the standard JSON.');
fprintf('MAPPID_SIX_SELECTOR_TEST_PASS: two workers; rank 1 rejected, rank 2 chosen.\n');
end

function o=mockEval(x,~,~)
o=struct('R',x(1),'S',1.2-.2*x(1),'erel',0);
end

function M=mockMargin(x)
assert(~isempty(getCurrentTask()),'test_mappid_six_selector:notParallel', ...
    'This verification requires execution on an actual parallel worker.');
M=struct('pass',x(1)>1,'ratio_gain',1+2*(x(1)==1),'ratio_delay',1);
end
