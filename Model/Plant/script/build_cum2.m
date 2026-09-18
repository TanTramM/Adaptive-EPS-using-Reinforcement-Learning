%% build_cum2.m
% Dung Simulink API de dung khoi Cum 2 (tuong tac lop Pacejka) thanh 1
% subsystem rieng, luu thanh Tires_s.mdl NGAY TRONG thu muc Plant/ - hau
% to "_s" de phan biet voi ban da tu format tay (Tires.mdl, cung thu muc).
% Khop dung Documents/Cum2_Pacejka.txt, PT(1)-(11):
%
%   delta_f = theta/n_st
%   alpha_f = delta_f - beta - l_f*gamma/v
%   alpha_r = -beta + l_r*gamma/v
%   F_zf    = m*g*l_r/(l_f+l_r)
%   D       = mu*F_zf
%   B       = C_alpha_f/(C*D)
%   F_yf    = D*sin(C*atan(B*alpha_f - E*(B*alpha_f - atan(B*alpha_f))))
%   F_yr    = C_r*alpha_r
%   e_p     = e_p0 - sgn(alpha_f)*e_p0*C_alpha_f*tan(alpha_f)/(3*mu*F_zf)
%   K_tr    = e_p/n_st
%   T_r     = K_tr*F_yf
%
% Quy uoc dung khoi (giong build_cum1.m):
%   - Moi khoi giu NGUYEN kich thuoc mac dinh - chi doi VI TRI, khong keo
%     dan/co lai (ham dichKhoi()).
%   - Phep nhan/chia dung khoi Product (khong dung Gain). Chia = Product
%     voi Inputs='*/'.
%   - sin/atan/tan dung khoi Trigonometric Function (khong dung Fcn).
%   - sgn(.) dung khoi Sign (Math Operations/Sign).
%   - Moi tham so tho (m,g,l_f,l_r,C_alpha_f,C_r,C,E,n_st,e_p0) la 1 khoi
%     Constant rieng, tham chieu ten bien base workspace - KHONG giau cong
%     thuc trong 1 bieu thuc gop.
%
% Tham so lay tu base workspace - chay Model/load_params.m TRUOC khi build.
%
% Cach dung (chay tu thu muc nay, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum2
%   (model Tires_s.mdl duoc tao trong thu muc Plant/)

modelName = 'Tires_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelPath = fullfile(plantDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/Tires'];
add_block('simulink/Ports & Subsystems/Subsystem', sub);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);
delete_block([sub '/Out1']);
dichKhoi(sub, 50, 50);

%% ----- Dau vao: theta, beta, gamma, v, mu -----
in_theta = addIn(sub, 'theta', 1, 40, 40);
in_beta  = addIn(sub, 'beta',  2, 40, 120);
in_gamma = addIn(sub, 'gamma', 3, 40, 200);
in_v     = addIn(sub, 'v',     4, 40, 280);
in_mu    = addIn(sub, 'mu',    5, 40, 360);

%% ----- Dau ra: F_yf, F_yr, T_r -----
out_Fyf = addOut(sub, 'F_yf', 1, 1400, 240);
out_Fyr = addOut(sub, 'F_yr', 2, 1400, 400);
out_Tr  = addOut(sub, 'T_r',  3, 1400, 700);

%% ----- Hang so tham so tho -----
c_n_st  = addConst(sub, 'Const_n_st',  'n_st',       120, 40);
c_lf    = addConst(sub, 'Const_l_f',   'l_f',        120, 460);
c_lr1   = addConst(sub, 'Const_l_r_1', 'l_r',        120, 540);
c_lr2   = addConst(sub, 'Const_l_r_2', 'l_r',         40, 620);
c_m     = addConst(sub, 'Const_m',     'm',           40, 700);
c_g     = addConst(sub, 'Const_g',     'g',           40, 780);
c_lf2   = addConst(sub, 'Const_l_f_2', 'l_f',        120, 860);
c_C1    = addConst(sub, 'Const_C_1',   'C',          600, 100);
c_C2    = addConst(sub, 'Const_C_2',   'C',          900, 100);
c_E     = addConst(sub, 'Const_E',     'E',          700, 300);
c_Calphaf1 = addConst(sub, 'Const_Calphaf_1', 'C_alpha_f', 700, 500);
c_Calphaf2 = addConst(sub, 'Const_Calphaf_2', 'C_alpha_f', 900, 900);
c_Cr    = addConst(sub, 'Const_C_r',   'C_r',        900, 400);
c_ep0   = addConst(sub, 'Const_e_p0',  'e_p0',       900, 960);
c_three = addConst(sub, 'Const_3',     '3',          700, 940);

%% ----- Muc 1: Goc truot lop -----
p_delta = addProd(sub, 'Divide_delta', '*/', 200, 40);

p_lfgamma = addProd(sub, 'Product_lf_gamma', '**', 200, 480);
p_lfgamma_v = addProd(sub, 'Divide_lfgamma_v', '*/', 280, 480);

a_alphaf = addAdd(sub, 'Sum_alpha_f', '+--', 400, 220);

p_lrgamma = addProd(sub, 'Product_lr_gamma', '**', 200, 560);
p_lrgamma_v = addProd(sub, 'Divide_lrgamma_v', '*/', 280, 560);

a_alphar = addAdd(sub, 'Sum_alpha_r', '-+', 400, 340);

%% ----- Muc 2: Tai trong tinh F_zf va luc ben lop -----
p_mg   = addProd(sub, 'Product_mg',   '**', 120, 700);
p_mglr = addProd(sub, 'Product_mglr', '**', 200, 700);
a_lflr = addAdd(sub, 'Sum_lf_lr',     '++', 200, 860);
p_Fzf  = addProd(sub, 'Divide_Fzf',   '*/', 280, 780);

p_D = addProd(sub, 'Product_D', '**', 460, 460);

p_CD = addProd(sub, 'Product_CD', '**', 540, 200);
p_B  = addProd(sub, 'Divide_B',   '*/', 620, 200);

p_u = addProd(sub, 'Product_u', '**', 700, 220);

t_atanu = addTrig(sub, 'Trig_atan_u', 'atan', 780, 160);

a_term1 = addAdd(sub, 'Sum_term1', '+-', 860, 190);

p_term2 = addProd(sub, 'Product_term2', '**', 940, 280);

a_term3 = addAdd(sub, 'Sum_term3', '+-', 1020, 230);

t_atanterm3 = addTrig(sub, 'Trig_atan_term3', 'atan', 1100, 230);

p_term4 = addProd(sub, 'Product_term4', '**', 1180, 160);

t_sinterm4 = addTrig(sub, 'Trig_sin_term4', 'sin', 1260, 160);

p_Fyf = addProd(sub, 'Product_Fyf', '**', 1340, 240);

p_Fyr = addProd(sub, 'Product_Fyr', '**', 1000, 380);

%% ----- Muc 3: Mo-men phan hoi T_r -----
s_sgn = addSign(sub, 'Sign_alpha_f', 700, 620);

t_tanaf = addTrig(sub, 'Trig_tan_alpha_f', 'tan', 700, 700);

p_epC = addProd(sub, 'Product_ep0_Calphaf', '**', 980, 900);

p_numer = addProd(sub, 'Product_numer', '***', 1060, 720);

p_3Fzf = addProd(sub, 'Product_3Fzf', '**', 780, 850);

p_denom = addProd(sub, 'Product_denom', '**', 860, 620);

p_frac = addProd(sub, 'Divide_frac', '*/', 1140, 660);

a_ep = addAdd(sub, 'Sum_e_p', '+-', 1220, 700);

p_Ktr = addProd(sub, 'Divide_Ktr', '*/', 1300, 720);

p_Tr = addProd(sub, 'Product_Tr', '**', 1370, 700);

%% ----- Noi day -----
add_line(sub, [in_theta '/1'], [p_delta '/1'], 'autorouting', 'on');
add_line(sub, [c_n_st '/1'],   [p_delta '/2'], 'autorouting', 'on');

add_line(sub, [c_lf '/1'],    [p_lfgamma '/1'], 'autorouting', 'on');
add_line(sub, [in_gamma '/1'],[p_lfgamma '/2'], 'autorouting', 'on');
add_line(sub, [p_lfgamma '/1'], [p_lfgamma_v '/1'], 'autorouting', 'on');
add_line(sub, [in_v '/1'],     [p_lfgamma_v '/2'], 'autorouting', 'on');

add_line(sub, [p_delta '/1'],   [a_alphaf '/1'], 'autorouting', 'on');
add_line(sub, [in_beta '/1'],   [a_alphaf '/2'], 'autorouting', 'on');
add_line(sub, [p_lfgamma_v '/1'],[a_alphaf '/3'], 'autorouting', 'on');

add_line(sub, [c_lr1 '/1'],   [p_lrgamma '/1'], 'autorouting', 'on');
add_line(sub, [in_gamma '/1'],[p_lrgamma '/2'], 'autorouting', 'on');
add_line(sub, [p_lrgamma '/1'], [p_lrgamma_v '/1'], 'autorouting', 'on');
add_line(sub, [in_v '/1'],     [p_lrgamma_v '/2'], 'autorouting', 'on');

add_line(sub, [in_beta '/1'],    [a_alphar '/1'], 'autorouting', 'on');
add_line(sub, [p_lrgamma_v '/1'],[a_alphar '/2'], 'autorouting', 'on');

add_line(sub, [c_m '/1'], [p_mg '/1'], 'autorouting', 'on');
add_line(sub, [c_g '/1'], [p_mg '/2'], 'autorouting', 'on');
add_line(sub, [p_mg '/1'],  [p_mglr '/1'], 'autorouting', 'on');
add_line(sub, [c_lr2 '/1'], [p_mglr '/2'], 'autorouting', 'on');
add_line(sub, [c_lf2 '/1'], [a_lflr '/1'], 'autorouting', 'on');
add_line(sub, [c_lr2 '/1'], [a_lflr '/2'], 'autorouting', 'on');
add_line(sub, [p_mglr '/1'], [p_Fzf '/1'], 'autorouting', 'on');
add_line(sub, [a_lflr '/1'], [p_Fzf '/2'], 'autorouting', 'on');

add_line(sub, [in_mu '/1'], [p_D '/1'], 'autorouting', 'on');
add_line(sub, [p_Fzf '/1'], [p_D '/2'], 'autorouting', 'on');

add_line(sub, [c_C1 '/1'], [p_CD '/1'], 'autorouting', 'on');
add_line(sub, [p_D  '/1'], [p_CD '/2'], 'autorouting', 'on');
add_line(sub, [c_Calphaf1 '/1'], [p_B '/1'], 'autorouting', 'on');
add_line(sub, [p_CD '/1'],       [p_B '/2'], 'autorouting', 'on');

add_line(sub, [p_B '/1'],     [p_u '/1'], 'autorouting', 'on');
add_line(sub, [a_alphaf '/1'],[p_u '/2'], 'autorouting', 'on');

add_line(sub, [p_u '/1'], [t_atanu '/1'], 'autorouting', 'on');
add_line(sub, [p_u '/1'], [a_term1 '/1'], 'autorouting', 'on');
add_line(sub, [t_atanu '/1'], [a_term1 '/2'], 'autorouting', 'on');
add_line(sub, [c_E '/1'],     [p_term2 '/1'], 'autorouting', 'on');
add_line(sub, [a_term1 '/1'], [p_term2 '/2'], 'autorouting', 'on');
add_line(sub, [p_u '/1'],     [a_term3 '/1'], 'autorouting', 'on');
add_line(sub, [p_term2 '/1'], [a_term3 '/2'], 'autorouting', 'on');
add_line(sub, [a_term3 '/1'], [t_atanterm3 '/1'], 'autorouting', 'on');
add_line(sub, [c_C2 '/1'],        [p_term4 '/1'], 'autorouting', 'on');
add_line(sub, [t_atanterm3 '/1'], [p_term4 '/2'], 'autorouting', 'on');
add_line(sub, [p_term4 '/1'], [t_sinterm4 '/1'], 'autorouting', 'on');
add_line(sub, [p_D '/1'],         [p_Fyf '/1'], 'autorouting', 'on');
add_line(sub, [t_sinterm4 '/1'],  [p_Fyf '/2'], 'autorouting', 'on');
add_line(sub, [p_Fyf '/1'], [out_Fyf '/1'], 'autorouting', 'on');

add_line(sub, [c_Cr '/1'],    [p_Fyr '/1'], 'autorouting', 'on');
add_line(sub, [a_alphar '/1'],[p_Fyr '/2'], 'autorouting', 'on');
add_line(sub, [p_Fyr '/1'], [out_Fyr '/1'], 'autorouting', 'on');

add_line(sub, [a_alphaf '/1'], [s_sgn '/1'], 'autorouting', 'on');
add_line(sub, [a_alphaf '/1'], [t_tanaf '/1'], 'autorouting', 'on');
add_line(sub, [c_ep0 '/1'],       [p_epC '/1'], 'autorouting', 'on');
add_line(sub, [c_Calphaf2 '/1'],  [p_epC '/2'], 'autorouting', 'on');
add_line(sub, [s_sgn '/1'],   [p_numer '/1'], 'autorouting', 'on');
add_line(sub, [p_epC '/1'],   [p_numer '/2'], 'autorouting', 'on');
add_line(sub, [t_tanaf '/1'], [p_numer '/3'], 'autorouting', 'on');
add_line(sub, [c_three '/1'], [p_3Fzf '/1'], 'autorouting', 'on');
add_line(sub, [p_Fzf '/1'],   [p_3Fzf '/2'], 'autorouting', 'on');
add_line(sub, [in_mu '/1'],   [p_denom '/1'], 'autorouting', 'on');
add_line(sub, [p_3Fzf '/1'],  [p_denom '/2'], 'autorouting', 'on');
add_line(sub, [p_numer '/1'], [p_frac '/1'], 'autorouting', 'on');
add_line(sub, [p_denom '/1'], [p_frac '/2'], 'autorouting', 'on');
add_line(sub, [c_ep0 '/1'],  [a_ep '/1'], 'autorouting', 'on');
add_line(sub, [p_frac '/1'], [a_ep '/2'], 'autorouting', 'on');

add_line(sub, [a_ep '/1'],   [p_Ktr '/1'], 'autorouting', 'on');
add_line(sub, [c_n_st '/1'], [p_Ktr '/2'], 'autorouting', 'on');
add_line(sub, [p_Ktr '/1'],  [p_Tr '/1'], 'autorouting', 'on');
add_line(sub, [p_Fyf '/1'],  [p_Tr '/2'], 'autorouting', 'on');
add_line(sub, [p_Tr '/1'], [out_Tr '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Da tao: %s\n', modelPath);

%% ===================== Ham tien ich (giu kich thuoc mac dinh) =====================
function dichKhoi(blockPath, x, y)
    pos = get_param(blockPath, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blockPath, 'Position', [x, y, x + w, y + h]);
end

function h = addIn(sub, name, port, x, y)
    full = [sub '/' name];
    add_block('simulink/Sources/In1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
    h = name;
end

function h = addOut(sub, name, port, x, y)
    full = [sub '/' name];
    add_block('simulink/Sinks/Out1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
    h = name;
end

function h = addConst(sub, name, value, x, y)
    full = [sub '/' name];
    add_block('simulink/Sources/Constant', full);
    set_param(full, 'Value', value);
    dichKhoi(full, x, y);
    h = name;
end

function h = addProd(sub, name, inputsStr, x, y)
    full = [sub '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', inputsStr);
    dichKhoi(full, x, y);
    h = name;
end

function h = addAdd(sub, name, inputsStr, x, y)
    full = [sub '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    dichKhoi(full, x, y);
    h = name;
end

function h = addTrig(sub, name, op, x, y)
    full = [sub '/' name];
    add_block('simulink/Math Operations/Trigonometric Function', full);
    set_param(full, 'Operator', op);
    dichKhoi(full, x, y);
    h = name;
end

function h = addSign(sub, name, x, y)
    full = [sub '/' name];
    add_block('simulink/Math Operations/Sign', full);
    dichKhoi(full, x, y);
    h = name;
end
