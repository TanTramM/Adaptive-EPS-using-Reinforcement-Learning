%% load_params.m
% Doc tham so tho tu data/params.json (Cum 1+2+3), day thang vao base
% workspace de cac model Simulink (Plant/*.mdl) tham chieu truc tiep theo
% ten bien.
%
% KHONG con buoc tinh ky hieu gop trung gian (J_total, B_total, T_f_total,
% Ktr...) tu tham so con - cac gia tri nay da la TRUC TIEP tham so trong
% params.json (theo phuong phap system-identification cua [1] Lee et al.
% 2018, xem Documents/Cum1_CEPS.txt). Cac dai luong dai so cua Cum 2/3
% (delta_f, alpha_f, F_yf, T_r, beta_dot, gamma_dot...) tinh o Simulink
% block moi buoc mo phong, khong tinh san o day.
%
% Cach dung: chay script nay (khong phai function) TRUOC khi build/mo
% phong bat ky model nao trong Plant/, vi bien tao ra se nam o base
% workspace. Chay duoc tu bat ky thu muc lam viec nao (duong dan tuyet
% doi theo vi tri script).

scriptDir = fileparts(mfilename('fullpath'));   % Model/
raw = jsondecode(fileread(fullfile(scriptDir, 'data', 'params.json')));

%% ===================== CUM 1 - CO CAU LAI =====================
p1 = raw.cum1;
fn = fieldnames(p1);
for i = 1:numel(fn)
    assignin('base', fn{i}, p1.(fn{i}).value);
end

%% ===================== CUM 2 - LOP PACEJKA =====================
p2 = raw.cum2;
fn = fieldnames(p2);
for i = 1:numel(fn)
    assignin('base', fn{i}, p2.(fn{i}).value);
end

%% ===================== CUM 3 - THAN XE 2-DOF =====================
% m, l_f, l_r da nap o Cum 2 (dung lai, khong dinh nghia lai - xem
% "_cum3_reused_from_cum2" trong params.json). Chi nap them Iz.
p3 = raw.cum3;
fn = fieldnames(p3);
for i = 1:numel(fn)
    assignin('base', fn{i}, p3.(fn{i}).value);
end

fprintf('Da nap tham so plant (data/params.json): Cum1 [%s], Cum2 [%s], Cum3 [%s] (+ m,l_f,l_r dung lai tu Cum2)\n', ...
    strjoin(fieldnames(raw.cum1), ', '), strjoin(fieldnames(raw.cum2), ', '), strjoin(fieldnames(raw.cum3), ', '));
