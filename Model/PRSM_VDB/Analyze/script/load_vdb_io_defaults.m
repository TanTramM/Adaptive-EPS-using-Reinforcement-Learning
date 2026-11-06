% LOAD_VDB_IO_DEFAULTS Put default input timeseries (variables in_<port>) for VDBBody.mdl and VDBTire.mdl into the base workspace, so that both models run as they are.
% Defaults: body at 20 m/s with no force and no moment; tire (front half axle) at 20 m/s, zero slip, load = static front half-axle load, mu = 1 in
% ScaleFctrs(3), the other 26 scale factors as in the Plant-matched configuration ([1;1;mu;0;ones(23,1)]). Replace any in_<port> to drive a case.
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths; load_plant;
P = load_vdb_params(modelDir);
tt = [0; 10];
mk = @(v) timeseries(repmat(v(:)', 2, 1), tt);
% body
in_WhlAngF = mk(0); in_xdotin = mk(20); in_FExt = mk([0 0 0]); in_MExt = mk([0 0 0]);
% tire
in_BrkPrs = mk(0); in_AxlTrq = mk(0); in_Vx = mk(20); in_Vy = mk(0); in_Camber = mk(0); in_YawRate = mk(0);
in_Prs = mk(220000); in_Gnd = mk(0); in_Fext = mk(P.Fzf / 2); in_ScaleFctrs = mk([1 1 1 0 ones(1, 23)]);
