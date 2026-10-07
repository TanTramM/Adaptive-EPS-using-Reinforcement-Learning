%% load_ref.m
% Doc du lieu tham chieu T_d,ref(v,a_y) tu data/ref.json (RIENG, khong
% chung voi params.json/load_params.m), doi don vi sang SI, day vao base
% workspace cho model Reference (2-D Lookup Table) tham chieu THANG qua
% ten bien - model Reference CHI DOC, khong tu tinh/nhung so lieu.
%
% Bien tao ra o base workspace:
%   Tdref_v_bp_ms   - breakpoint truc v, don vi m/s (5 diem)
%   Tdref_ay_bp_ms2 - breakpoint truc a_y, don vi m/s^2 (4 diem)
%   Tdref_table     - bang T_d,ref [N.m], kich thuoc 5x4 (hang=v, cot=a_y,
%                     DA CHUYEN VI so voi table_Nm trong ref.json vi
%                     ref.json luu theo bo cuc goc cua Bang 4: hang=a_y)
%
% Cach dung: chay script nay TRUOC khi build/mo phong model Reference.
% Chay duoc tu bat ky thu muc lam viec nao (duong dan tuyet doi theo vi
% tri script).
%   >> load_ref
%   >> build_reference

scriptDir = fileparts(mfilename('fullpath'));   % Model/
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'ref.json')));

v_bp_kmh  = raw.v_breakpoints_kmh(:)';
ay_bp_g   = raw.ay_breakpoints_g(:)';
table_Nm  = raw.table_Nm;   % hang=a_y (4), cot=v (5) - dung bo cuc goc

Tdref_v_bp_ms   = v_bp_kmh / 3.6;
Tdref_ay_bp_ms2 = ay_bp_g * 9.81;
Tdref_table     = table_Nm';   % chuyen vi -> hang=v (5), cot=a_y (4)

assignin('base', 'Tdref_v_bp_ms',   Tdref_v_bp_ms);
assignin('base', 'Tdref_ay_bp_ms2', Tdref_ay_bp_ms2);
assignin('base', 'Tdref_table',     Tdref_table);

fprintf('Da nap data/ref.json: v_bp=[%s] m/s, ay_bp=[%s] m/s^2, table %dx%d\n', ...
    num2str(Tdref_v_bp_ms), num2str(Tdref_ay_bp_ms2), size(Tdref_table,1), size(Tdref_table,2));
