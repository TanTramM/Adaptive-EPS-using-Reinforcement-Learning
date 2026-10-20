function result = run_mappid_six(action, workerId, nWorkers)
%RUN_MAPPID_SIX Independent Map(2) -> MapPID(6) deterministic search.
% Actions: check, map, mapselect, S1, S2, select. Existing nine-variable
% jobs and the Map frame's JSON/results are never used as selected inputs.
if nargin < 2, workerId = 1; end
if nargin < 3, nWorkers = 1; end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;
action = lower(char(action));
result = [];
switch action
    case 'check'
        U = [zeros(1,6); ones(1,6); .5*ones(1,6)];
        for k = 1:size(U,1)
            u = U(k,:); back = encode(decode(u,false),false);
            assert(max(abs(back-u)) < 1e-10, 'Six-variable roundtrip failed.');
        end
        off = decode(zeros(1,6),false); assert(off(1)==0);
        fprintf('MAPPID_SIX_CHECK_PASS: 2 Map + 4 PID variables, isolated outputs.\n');
    case 'smoke'
        root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
        P=jsondecode(fileread(fullfile(root,'data','pid.json'))); p=P.design;
        x=[0,1,p.Kp,p.Ki,p.Kd,p.Tf];
        o=evaluate(x,30000,'',false);
        assert(o.simulated==1 && isfinite(o.R) && isfinite(o.S), ...
            'Six-variable PID-only simulation failed.');
        V=mappid_variables(calibrate_map(false),design(x,false));
        assert(all(V.MapPID_table(:)==0) && V.MapPID_Kaw==p.Ki/p.Kp);
        fprintf('MAPPID_SIX_SMOKE_PASS J %.8g R %.8g S %.8g\n',o.J,o.R,o.S);
        result=o;
    case 'map'
        s = specification(true); s.tag = 'grid'; s.free = 1:2;
        s.u0 = [.5 .5]; s.coarse = true; s.hStart = 1/6;
        result = grid_search(s,workerId,nWorkers);
    case 'mapselect'
        result = choose(true);
    case {'s1','s2'}
        result = alternate(upper(action),workerId,nWorkers);
    case 'select'
        for start = {'S1','S2'}
            assert(isfile(fullfile(output(false),[start{1} '_summary.mat'])), ...
                'run_mappid_six:missingStart','Missing completed %s.',start{1});
        end
        result = choose(false);
    case {'loadmap','load'}
        isMap=strcmp(action,'loadmap');
        f=fullfile(output(isMap),'selected.json');
        assert(isfile(f),'run_mappid_six:unselected','No selected design: %s',f);
        P=jsondecode(fileread(f));
        assert(strcmp(P.profile,'Map2_MapPID6_v1') && P.selection.margin.pass);
        d=P.design; initialize(isMap,d); [Cal,~,~]=context();
        if isMap, V=map_variables(Cal,d); else, V=mappid_variables(Cal,d); end
        fn=fieldnames(V);
        for k=1:numel(fn), assignin('base',fn{k},V.(fn{k})); end
        result=d;
    otherwise
        error('run_mappid_six:action','Unknown action %s.',action);
end
end

function p = output(isMap)
if isMap, p = fullfile(result_dir('Map','Calib'),'TwoParam');
else, p = fullfile(result_dir('MapPID','Calib'),'SixParam'); end
if ~isfolder(p), mkdir(p); end
end

function vn = variables(isMap)
vn = {'K','g_min'};
if ~isMap, vn = [vn {'Kp','Ki','Kd','Tf'}]; end
end

function x = decode(u,isMap)
u = min(max(u(:)',0),1);
if isMap
    K = 5*(16/5)^u(1);
    x = [K,1/sqrt(2)+(1-1/sqrt(2))*u(2)];
else
    expanded = mappid_u2x([u(1),.5,0,.5,1,u(3:6)]);
    x = [expanded(1),1/sqrt(2)+(1-1/sqrt(2))*u(2),expanded(6:9)];
end
end

function u = encode(x,isMap)
g = (x(2)-1/sqrt(2))/(1-1/sqrt(2));
if isMap, u = [log(x(1)/5)/log(16/5),g];
else
    expanded = mappid_x2u([x(1),50,1,20,1,x(3:6)]);
    u = [expanded(1),g,expanded(6:9)];
end
u = min(max(u,0),1);
end

function s = specification(isMap)
vn = variables(isMap);
s = struct('name',controller(isMap),'n',numel(vn),'vn',{vn}, ...
    'u2x',@(u)decode(u,isMap),'x2u',@(x)encode(x,isMap), ...
    'evalFcn',@(x,seed,file)evaluate(x,seed,file,isMap), ...
    'seed',30000*~isMap,'seed0',30000*~isMap, ...
    'seeds',(1:5)+30000*~isMap,'outDir',output(isMap), ...
    'marginFcn',@(x)margin(x,isMap),'toDesign',@(x)design(x,isMap), ...
    'jsonPath',fullfile(output(isMap),'selected.json'), ...
    'PMfin',30,'GMfin',2,'erelMax',10,'marginWorkers',1);
end

function name = controller(isMap)
if isMap, name = 'Map'; else, name = 'MapPID'; end
end

function [Cal,Gj,w] = context()
persistent C G W
if isempty(C)
    C = calibrate_map(false);
    % Immutable plant frequency responses are common physical input, not a
    % selected Map design. Reuse their existing cache when present.
    [G,W] = map_opt_plants();
end
Cal = C; Gj = G; w = W;
end

function d = design(x,isMap)
[~,Gj,w] = context();
cacheDir = fullfile(output(true),'Compensators');
if ~isfolder(cacheDir), mkdir(cacheDir); end
key = sprintf('K%.12g_g%.12g',x(1),x(2));
cache = fullfile(cacheDir,[key '.mat']);
if isfile(cache)
    q = load(cache,'D'); D = q.D;
elseif x(1) == 0
    D = struct('ok',1,'z',50,'p',50,'z1',20,'p1',20,'nTried',0);
else
    fprintf('SixParam: designing compensator for K=%.8g g_min=%.8g\n',x(1),x(2));
    D = design_leadlag(Gj,w,x(1),x(2)<1-1e-10,[x(2),2*pi*2]);
    % Represent a disabled lag with finite equal pole/zero values. The
    % physical transfer function is unchanged and JSON stays portable.
    if D.ok && ~isfinite(D.z1), D.z1 = 20; D.p1 = 20; end
    tmp = [tempname(cacheDir) '.mat']; save(tmp,'D');
    [ok,msg] = movefile(tmp,cache,'f'); assert(ok,'%s',msg);
end
assert(D.ok,'run_mappid_six:noCompensator','No compensator for K %.8g, g_min %.8g.',x(1),x(2));
d = struct('Ts_ctrl',.001,'Ts0',.3,'Kmax',x(1),'g_min',x(2), ...
    'lead',struct('z',D.z,'p',D.p),'lag',struct('z1',D.z1,'p1',D.p1));
if ~isMap
    d.Kp=x(3); d.Ki=x(4); d.Kd=x(5); d.Tf=x(6);
    d.Kaw=d.Ki/(d.Kp+d.Kmax);
end
end

function initialize(isMap,d)
persistent mapReady pidReady
if (isMap && isempty(mapReady)) || (~isMap && isempty(pidReady))
    root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    for part = {'Plant','Ref','Sensors','AssistLimit','Actuator'}
        f = fullfile(root,'PRSM',part{1},['load_' lower(part{1}) '.m']);
        evalin('base',sprintf('run(''%s'')',strrep(f,'''','''''')));
    end
    [Cal,~,~] = context();
    if isMap, V=map_variables(Cal,d); else, V=mappid_variables(Cal,d); end
    fn=fieldnames(V);
    for k=1:numel(fn), assignin('base',fn{k},V.(fn{k})); end
    if isMap, mapReady=true; else, pidReady=true; end
end
end

function o = evaluate(x,seed,file,isMap)
vn=variables(isMap); x=x(:)';
if ~isempty(file) && isfile(file)
    T=readtable(file); hit=T.seed==seed;
    hit=hit & all(abs(T{:,vn}-x)<=1e-9.*max(1,abs(x)),2);
    if any(hit), o=fromRow(T(find(hit,1),:),x,seed); return; end
end
t=tic;
o=struct('x',x,'seed',seed,'J',Inf,'R',NaN,'S',NaN,'TV',NaN, ...
    'erel',NaN,'rev',NaN,'PM',NaN,'GM',NaN,'HF',NaN, ...
    'lagGain2Hz',NaN,'simulated',0,'c',[1 0 0 0],'cached',false);
try, d=design(x,isMap);
catch ME
    if ~strcmp(ME.identifier,'run_mappid_six:noCompensator'), rethrow(ME); end
    append(); return;
end
[Cal,Gj,w]=context();
if isMap, R=map_opt_margins(Gj,w,d); else, R=mappid_margins(Gj,w,d); end
o.PM=R.PM; o.GM=R.GM; o.HF=R.HF;
o.lagGain2Hz=abs((1+1i*4*pi/d.lag.z1)/(1+1i*4*pi/d.lag.p1));
pm=R.PM; if ~R.stable, pm=-180; end
o.c=[30-pm,2-R.GM,1/sqrt(2)-o.lagGain2Hz,0];
if any(o.c(1:3)>1e-10), append(); return; end
initialize(isMap,d);
if isMap, V=map_variables(Cal,d); else, V=mappid_variables(Cal,d); end
cleanup=onCleanup(@()Simulink.sdi.clear);
[~,m]=calib_run(['Model_' controller(isMap)],seed,V);
o.R=m.R; o.S=m.S; o.TV=m.TV; o.erel=m.erel; o.rev=m.rev; o.simulated=1;
o.c(4)=m.erel-10; if all(o.c<=1e-10), o.J=m.R*m.S; end
append();
    function append()
        if isempty(file), return; end
        row=array2table(x,'VariableNames',vn);
        row.seed=seed; row.J=o.J; row.R_pct=o.R; row.S_Nm=o.S;
        row.TV=o.TV; row.erel_pct=o.erel; row.rev_pct=o.rev;
        row.PM_deg=o.PM; row.GM=o.GM; row.HF=o.HF;
        row.lagGain2Hz=o.lagGain2Hz; row.simulated=o.simulated;
        for j=1:4, row.(['c' num2str(j)])=o.c(j); end
        row.seconds=toc(t);
        if isfile(file), writetable(row,file,'WriteMode','append','WriteVariableNames',false);
        else, writetable(row,file); end
        fprintf('%s [%s] J %.7g e_rel %.5g PM %.4g\n',controller(isMap),num2str(x),o.J,o.erel,o.PM);
    end
end

function o=fromRow(r,x,seed)
o=struct('x',x,'seed',seed,'J',r.J,'R',r.R_pct,'S',r.S_Nm,'TV',r.TV, ...
    'erel',r.erel_pct,'rev',r.rev_pct,'PM',r.PM_deg,'GM',r.GM, ...
    'HF',r.HF,'lagGain2Hz',r.lagGain2Hz,'simulated',r.simulated, ...
    'c',[r.c1 r.c2 r.c3 r.c4],'cached',true);
end

function M=margin(x,isMap)
d=design(x,isMap); initialize(isMap,d); [Cal,~,~]=context();
if isMap, V=map_variables(Cal,d); else, V=mappid_variables(Cal,d); end
cleanup=onCleanup(@()Simulink.sdi.clear);
M=calib_margin(['Model_' controller(isMap)],1+30000*~isMap,V);
assert(isfinite(M.ratio_gain),'run_mappid_six:marginExecution', ...
    'Nonfinite margin result: inspect simulation before rejecting this design.');
end

function sel=choose(isMap)
s=specification(isMap); sel=select_pareto(s,false);
if ~isMap
    for start={'S1','S2'}
        files=dir(fullfile(output(false),sprintf('MapPID_CALIB_%s*_w*_s30000.csv',start{1})));
        T=table();
        for k=1:numel(files), T=[T;readtable(fullfile(files(k).folder,files(k).name))]; end %#ok<AGROW>
        ok=T.simulated==1 & all(T{:,{'c1','c2','c3','c4'}}<=0,2) & isfinite(T.J);
        best=Inf; if any(ok), best=min(T.J(ok)); end
        sel.(start{1})=struct('bestJ',best);
    end
    sel.twoRegions=isfinite(sel.S1.bestJ) && isfinite(sel.S2.bestJ) && ...
        abs(sel.S1.bestJ-sel.S2.bestJ)/min(sel.S1.bestJ,sel.S2.bestJ)>=.03;
    sel.noMap=sel.x(1)==0;
    u=encode(sel.x,false); sel.pidNearOff=all(u(3:5)<=.01);
    sel.noLead=abs(sel.design.lead.p/sel.design.lead.z-1)<1e-9;
    sel.noLag=abs(sel.design.lag.p1/sel.design.lag.z1-1)<1e-9;
    fprintf('SixParam regions: S1 best J %.8g; S2 best J %.8g; separated >=3%%: %d\n', ...
        sel.S1.bestJ,sel.S2.bestJ,sel.twoRegions);
end
J=struct('profile','Map2_MapPID6_v1','variables',{variables(isMap)}, ...
    'x',sel.x,'design',sel.design,'selection',sel, ...
    'rule','block grid; J=R*S; 3 percent PM tie; full original gates; five-seed report', ...
    'date',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
file=fullfile(output(isMap),'selected.json'); tmp=[tempname(output(isMap)) '.json'];
fid=fopen(tmp,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(J,'PrettyPrint',true)); fclose(fid);
[ok,msg]=movefile(tmp,file,'f'); assert(ok,'%s',msg);
save(fullfile(output(isMap),'selection.mat'),'sel');
end

function summary=alternate(start,workerId,nWorkers)
s=specification(false);
if strcmp(start,'S1')
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    pidPick=fullfile(result_dir('PID','Calib'),'PID_CALIB_pick_s10000.csv');
    assert(isfile(pidPick),'Selected PID is missing.');
    P=jsondecode(fileread(fullfile(root,'data','pid.json'))); p=P.design;
    u=encode([0,1,p.Kp,p.Ki,p.Kd,p.Tf],false); blocks=[1 2 1 2 1 2];
else
    f=fullfile(output(true),'selected.json');
    assert(isfile(f),'run_mappid_six:missingMap','Independent Map(2) has no valid selection yet.');
    P=jsondecode(fileread(f));
    assert(strcmp(P.profile,'Map2_MapPID6_v1') && P.selection.margin.pass);
    u=encode([P.x(:)',1e-3,.1,0,sqrt(.001*.0796)],false);
    blocks=[2 1 2 1 2 1];
end
unchanged=0; scans=cell(0,1);
for stage=1:6
    if blocks(stage)==1, s.free=1:2; letter='A'; else, s.free=3:6; letter='B'; end
    s.tag=sprintf('%s%s%d',start,letter,ceil(stage/2)); s.u0=u;
    s.coarse=stage<=2; s.hStart=1/12; if s.coarse, s.hStart=1/6; end
    scan=grid_search(s,workerId,nWorkers); next=scan.centerU;
    if max(abs(next-u))<=1e-10, unchanged=unchanged+1; else, unchanged=0; end
    u=next; scans{end+1}=scan; %#ok<AGROW>
    if unchanged>=2, break; end
end
summary=struct('profile','Map2_MapPID6_v1','start',start,'nScans',numel(scans), ...
    'u',u,'x',decode(u,false),'scans',{scans});
if workerId==1, save(fullfile(output(false),[start '_summary.mat']),'summary'); end
end
