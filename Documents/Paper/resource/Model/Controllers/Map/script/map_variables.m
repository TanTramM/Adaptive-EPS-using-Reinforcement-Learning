function V = map_variables(Cal, d)
%MAP_VARIABLES Base-workspace variables of the Map controller block from design d (struct) and calibration Cal (calibrate_map).
%
%   d.Ts_ctrl         controller sample time [s]
%   d.Ts0             dead zone edge [N.m]
%   d.Kmax            slope limit of the assist curve, the same at every speed
%   d.lead            struct with fields z, p [rad/s]       (s/z+1)/(s/p+1), p > z
%   d.lag             OPTIONAL struct with fields z1, p1 [rad/s] (s/z1+1)/(s/p1+1), p1 < z1; absent, empty or non-finite = lead only
%   V.Map_Ts_ctrl, V.Map_v_bp [m/s], V.Map_Ts_bp [N.m], V.Map_table (rows = speeds, cols = |T_s|) [N.m], V.Map_H_num/den
%   (Tustin at Ts_ctrl of H(s) = lead(s) * lag(s); second order with the lag, first order without).
scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));

if nargin < 2
    J = jsondecode(fileread(fullfile(modelDir, 'data', 'map.json')));
    d = J.design;
end
if nargin < 1
    addpath(modelDir); setup_paths;
    Cal = calibrate_map_cached();
end

Tsbp = (0:0.005:5)';
tab = zeros(numel(Cal.v_kmh), numel(Tsbp));
for iv = 1:numel(Cal.v_kmh)
    M = map_table(Cal, iv, d.Kmax, d.Ts0);
    tab(iv, :) = map_eval(M, Tsbp)';
end

V.Map_Ts_ctrl = d.Ts_ctrl;
V.Map_v_bp = Cal.v_kmh(:)' / 3.6;
V.Map_Ts_bp = Tsbp(:)';
V.Map_table = tab;
[V.Map_H_num, V.Map_H_den] = comp_tustin(d);
end

function [num, den] = comp_tustin(d)
    H = tf([1 / d.lead.z 1], [1 / d.lead.p 1]);
    if isfield(d, 'lag') && ~isempty(d.lag) && isfield(d.lag, 'z1') && isfinite(d.lag.z1) && isfinite(d.lag.p1)
        H = H * tf([1 / d.lag.z1 1], [1 / d.lag.p1 1]);
    end
    Hd = c2d(H, d.Ts_ctrl, 'tustin');
    [num, den] = tfdata(Hd, 'v');
end

