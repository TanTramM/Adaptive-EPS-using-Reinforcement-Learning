function V = map_variables(Cal, d)
%MAP_VARIABLES Base-workspace variables of the Map controller block from design d (struct) and calibration Cal (calibrate_map).
%
%   d.Ts_ctrl         controller sample time [s]
%   d.Ts0             dead zone edge [N.m]
%   d.Kmax            slope limit of the assist curve, the same at every speed
%   d.lead            struct with fields z, p [rad/s]
%   V.Map_Ts_ctrl, V.Map_v_bp [m/s], V.Map_Ts_bp [N.m], V.Map_table (rows = speeds, cols = |T_s|) [N.m], V.Map_H_num/den
%   (Tustin of H(s) = (s/z+1)/(s/p+1) at Ts_ctrl).
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
[V.Map_H_num, V.Map_H_den] = lead_tustin(d.lead.z, d.lead.p, d.Ts_ctrl);
end

function [num, den] = lead_tustin(z, p, Ts)
    Hd = c2d(tf([1 / z 1], [1 / p 1]), Ts, 'tustin');
    [num, den] = tfdata(Hd, 'v');
end

