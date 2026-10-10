%% load_assistlimit.m
% Base workspace variables of the AssistLimit block (Model/PRSM/AssistLimit/script/build_assistlimit.m): the assist limit T_a,max(v) of the
% Ref, Tamax_v_bp_ms [m/s] and Tamax_table [N.m] (data/ref.json field Ta_max, through load_ref.m). The table already contains the safety margin
% (T_a,max = demand + F, F = T_f; Model/PRSM/Ref/script/make_ta_max.m).
%
% Usage: run this SCRIPT from any folder: >> run('<Model>/PRSM/AssistLimit/load_assistlimit.m')

modelDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % Model/ (this file is Model/PRSM/AssistLimit/)
addpath(modelDir); setup_paths;
load_ref;
