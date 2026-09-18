%% build_cum3.m
% Dung Simulink API de dung khoi Cum 3 (dong luc hoc than xe 2-DOF) thanh 1
% subsystem rieng, luu thanh Bike2DOF_s.mdl NGAY TRONG thu muc Plant/ - hau
% to "_s" de phan biet voi ban da tu format tay (Bike2DOF.mdl, cung thu
% muc). Khop dung Documents/Cum3_2DOF.txt, PT(1)-(5):
%
%   x3_dot = beta_dot  = (F_yf + F_yr)/(m*v) - x4
%   x4_dot = gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz
%   a_y    = (F_yf + F_yr)/m            (dau ra phu, PT(3))
%
% Quy uoc dung khoi (giong build_cum1.m, build_cum2.m):
%   - Moi khoi giu NGUYEN kich thuoc mac dinh - chi doi VI TRI (dichKhoi()).
%   - Phep nhan/chia dung khoi Product (khong dung Gain). Chia = Product
%     voi Inputs='*/'.
%   - Tham so tho (m, l_f, l_r, Iz) la khoi Constant rieng, tham chieu ten
%     bien base workspace - m, l_f, l_r DUNG LAI dung ten bien da nap o
%     Cum 2 (khong dinh nghia lai gia tri).
%
% Tham so lay tu base workspace - chay Model/load_params.m TRUOC khi build.
%
% Cach dung (chay tu thu muc nay, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum3
%   (model Bike2DOF_s.mdl duoc tao trong thu muc Plant/)

modelName = 'Bike2DOF_s';

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

sub = [modelName '/Cum3_2DOF'];
add_block('simulink/Ports & Subsystems/Subsystem', sub);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);
delete_block([sub '/Out1']);
dichKhoi(sub, 50, 50);

%% ----- Dau vao: F_yf, F_yr, v -----
in_Fyf = addIn(sub, 'F_yf', 1, 40, 40);
in_Fyr = addIn(sub, 'F_yr', 2, 40, 120);
in_v   = addIn(sub, 'v',    3, 40, 200);

%% ----- Dau ra: beta (x3), gamma (x4), a_y -----
out_beta  = addOut(sub, 'beta',  1, 700, 40);
out_gamma = addOut(sub, 'gamma', 2, 700, 200);
out_ay    = addOut(sub, 'a_y',   3, 700, 340);

%% ----- Hang so tham so tho -----
c_m   = addConst(sub, 'Const_m',   'm',   120, 340);
c_lf  = addConst(sub, 'Const_l_f', 'l_f', 300, 260);
c_lr  = addConst(sub, 'Const_l_r', 'l_r', 300, 420);
c_Iz  = addConst(sub, 'Const_Iz',  'Iz',  460, 260);

%% ----- F_yf + F_yr (dung o ca PT(4) va PT(3)) -----
a_Fsum = addAdd(sub, 'Sum_Fyf_Fyr', '++', 120, 80);

%% ----- x3_dot = (F_yf+F_yr)/(m*v) - x4 -----
p_mv    = addProd(sub, 'Product_mv',    '**', 200, 300);
p_div1  = addProd(sub, 'Divide_Fsum_mv','*/', 280, 80);
a_x3dot = addAdd(sub, 'Sum_x3dot',      '+-', 360, 100);
i_x3    = addBlock(sub, 'Integrator_x3', 'simulink/Continuous/Integrator', 440, 40);

%% ----- x4_dot = (l_f*F_yf - l_r*F_yr)/Iz -----
p_lfFyf = addProd(sub, 'Product_lf_Fyf', '**', 380, 220);
p_lrFyr = addProd(sub, 'Product_lr_Fyr', '**', 380, 400);
a_mom   = addAdd(sub, 'Sum_moment',      '+-', 460, 320);
p_div2  = addProd(sub, 'Divide_moment_Iz','*/', 540, 320);
i_x4    = addBlock(sub, 'Integrator_x4', 'simulink/Continuous/Integrator', 600, 200);

%% ----- a_y = (F_yf+F_yr)/m -----
p_ay = addProd(sub, 'Divide_Fsum_m', '*/', 200, 500);

%% ----- Noi day -----
add_line(sub, [in_Fyf '/1'], [a_Fsum '/1'], 'autorouting', 'on');
add_line(sub, [in_Fyr '/1'], [a_Fsum '/2'], 'autorouting', 'on');

add_line(sub, [c_m '/1'], [p_mv '/1'], 'autorouting', 'on');
add_line(sub, [in_v '/1'],[p_mv '/2'], 'autorouting', 'on');
add_line(sub, [a_Fsum '/1'], [p_div1 '/1'], 'autorouting', 'on');
add_line(sub, [p_mv '/1'],   [p_div1 '/2'], 'autorouting', 'on');
add_line(sub, [p_div1 '/1'], [a_x3dot '/1'], 'autorouting', 'on');
add_line(sub, [i_x4 '/1'],   [a_x3dot '/2'], 'autorouting', 'on');
add_line(sub, [a_x3dot '/1'],[i_x3 '/1'], 'autorouting', 'on');
add_line(sub, [i_x3 '/1'], [out_beta '/1'], 'autorouting', 'on');

add_line(sub, [c_lf '/1'],   [p_lfFyf '/1'], 'autorouting', 'on');
add_line(sub, [in_Fyf '/1'], [p_lfFyf '/2'], 'autorouting', 'on');
add_line(sub, [c_lr '/1'],   [p_lrFyr '/1'], 'autorouting', 'on');
add_line(sub, [in_Fyr '/1'], [p_lrFyr '/2'], 'autorouting', 'on');
add_line(sub, [p_lfFyf '/1'], [a_mom '/1'], 'autorouting', 'on');
add_line(sub, [p_lrFyr '/1'], [a_mom '/2'], 'autorouting', 'on');
add_line(sub, [a_mom '/1'], [p_div2 '/1'], 'autorouting', 'on');
add_line(sub, [c_Iz '/1'],  [p_div2 '/2'], 'autorouting', 'on');
add_line(sub, [p_div2 '/1'],[i_x4 '/1'], 'autorouting', 'on');
add_line(sub, [i_x4 '/1'], [out_gamma '/1'], 'autorouting', 'on');

add_line(sub, [a_Fsum '/1'], [p_ay '/1'], 'autorouting', 'on');
add_line(sub, [c_m '/1'],    [p_ay '/2'], 'autorouting', 'on');
add_line(sub, [p_ay '/1'], [out_ay '/1'], 'autorouting', 'on');

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

function h = addBlock(sub, name, blockType, x, y)
    full = [sub '/' name];
    add_block(blockType, full);
    dichKhoi(full, x, y);
    h = name;
end
