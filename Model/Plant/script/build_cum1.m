%% build_cum1.m
% Dung Simulink API de dung khoi Cum 1 (co cau lai) thanh 1 subsystem rieng,
% luu thanh SteeringColumn_s.mdl NGAY TRONG thu muc Plant/ (thu muc cha cua
% script nay) - hau to "_s" de phan biet voi ban da tu format tay
% (SteeringColumn.mdl, cung thu muc). Khop dung Documents/Cum1_CEPS.txt:
%
%   x1_dot = x2
%   x2_dot = (T_d + T_a - T_r - B_total*x2 - T_f_total*tanh(c*x2)) / J_total
%
% Quy uoc dung khoi:
%   - Moi khoi giu NGUYEN kich thuoc mac dinh khi add_block tao ra - chi
%     doi VI TRI (dich chuyen), khong keo dan/co lai (xem ham dichKhoi()).
%   - Phep nhan dung khoi Product (khong dung Gain).
%   - Phep chia (1/J_total) dung khoi Product o che do chia (Divide).
%   - Ham tanh dung khoi Trigonometric Function (Function=tanh), khong
%     dung Fcn/MATLAB Function.
%
% Tham so (J_total, B_total, T_f_total, c) lay tu base workspace - chay
% Model/load_params.m TRUOC khi build/mo phong.
%
% Cach dung (chay tu thu muc nay, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum1
%   (model SteeringColumn_s.mdl duoc tao trong thu muc Plant/, ngang hang
%   voi SteeringColumn.mdl da format tay)

modelName = 'SteeringColumn_s';

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

%% ----- Subsystem Cum1_SteeringColumn -----
sub = [modelName '/Cum1_SteeringColumn'];
add_block('simulink/Ports & Subsystems/Subsystem', sub);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);
delete_block([sub '/Out1']);
dichKhoi(sub, 50, 50);

% --- Dau vao: T_d, T_a, T_r ---
add_block('simulink/Sources/In1', [sub '/T_d']);
set_param([sub '/T_d'], 'Port', '1');
dichKhoi([sub '/T_d'], 40, 40);

add_block('simulink/Sources/In1', [sub '/T_a']);
set_param([sub '/T_a'], 'Port', '2');
dichKhoi([sub '/T_a'], 40, 120);

add_block('simulink/Sources/In1', [sub '/T_r']);
set_param([sub '/T_r'], 'Port', '3');
dichKhoi([sub '/T_r'], 40, 200);

% --- Dau ra: theta (x1), theta_dot (x2) ---
add_block('simulink/Sinks/Out1', [sub '/theta']);
set_param([sub '/theta'], 'Port', '1');
dichKhoi([sub '/theta'], 620, 40);

add_block('simulink/Sinks/Out1', [sub '/theta_dot']);
set_param([sub '/theta_dot'], 'Port', '2');
dichKhoi([sub '/theta_dot'], 620, 160);

% --- Hang so tham so (doc tu base workspace qua ten bien) ---
add_block('simulink/Sources/Constant', [sub '/Const_B_total']);
set_param([sub '/Const_B_total'], 'Value', 'B_total');
dichKhoi([sub '/Const_B_total'], 200, 260);

add_block('simulink/Sources/Constant', [sub '/Const_c']);
set_param([sub '/Const_c'], 'Value', 'c');
dichKhoi([sub '/Const_c'], 200, 320);

add_block('simulink/Sources/Constant', [sub '/Const_Tf_total']);
set_param([sub '/Const_Tf_total'], 'Value', 'T_f_total');
dichKhoi([sub '/Const_Tf_total'], 340, 380);

add_block('simulink/Sources/Constant', [sub '/Const_J_total']);
set_param([sub '/Const_J_total'], 'Value', 'J_total');
dichKhoi([sub '/Const_J_total'], 420, 200);

% --- Product: B_total * x2 (ma sat nhot) ---
add_block('simulink/Math Operations/Product', [sub '/Product_B']);
dichKhoi([sub '/Product_B'], 260, 220);

% --- Product: c * x2 (dau vao ham tanh) ---
add_block('simulink/Math Operations/Product', [sub '/Product_c']);
dichKhoi([sub '/Product_c'], 260, 300);

% --- Trigonometric Function: tanh(c*x2) - khoi ham dang hoang, khong Fcn ---
add_block('simulink/Math Operations/Trigonometric Function', [sub '/Tanh']);
set_param([sub '/Tanh'], 'Operator', 'tanh');
dichKhoi([sub '/Tanh'], 320, 300);

% --- Product: T_f_total * tanh(c*x2) ---
add_block('simulink/Math Operations/Product', [sub '/Product_Tf']);
dichKhoi([sub '/Product_Tf'], 380, 340);

% --- Sum: T_d + T_a - T_r - B_total*x2 - T_f_total*tanh(c*x2) ---
add_block('simulink/Math Operations/Add', [sub '/SumTorque']);
set_param([sub '/SumTorque'], 'Inputs', '++---');
dichKhoi([sub '/SumTorque'], 340, 100);
% Thu tu cong: 1=T_d(+) 2=T_a(+) 3=T_r(-) 4=B_total*x2(-) 5=Tf_total*tanh(c*x2)(-)

% --- Product (che do chia - Divide): SumTorque / J_total ---
add_block('simulink/Math Operations/Product', [sub '/Divide_J']);
set_param([sub '/Divide_J'], 'Inputs', '*/');
dichKhoi([sub '/Divide_J'], 460, 100);

% --- Integrator x2_dot -> x2 (theta_dot) ---
add_block('simulink/Continuous/Integrator', [sub '/Integrator_x2']);
dichKhoi([sub '/Integrator_x2'], 520, 100);

% --- Integrator x1_dot(=x2) -> x1 (theta) ---
add_block('simulink/Continuous/Integrator', [sub '/Integrator_x1']);
dichKhoi([sub '/Integrator_x1'], 580, 40);

%% ----- Noi day -----
add_line(sub, 'T_d/1', 'SumTorque/1', 'autorouting', 'on');
add_line(sub, 'T_a/1', 'SumTorque/2', 'autorouting', 'on');
add_line(sub, 'T_r/1', 'SumTorque/3', 'autorouting', 'on');

add_line(sub, 'Integrator_x2/1', 'Product_B/1', 'autorouting', 'on');
add_line(sub, 'Const_B_total/1', 'Product_B/2', 'autorouting', 'on');
add_line(sub, 'Product_B/1', 'SumTorque/4', 'autorouting', 'on');

add_line(sub, 'Integrator_x2/1', 'Product_c/1', 'autorouting', 'on');
add_line(sub, 'Const_c/1', 'Product_c/2', 'autorouting', 'on');
add_line(sub, 'Product_c/1', 'Tanh/1', 'autorouting', 'on');
add_line(sub, 'Tanh/1', 'Product_Tf/1', 'autorouting', 'on');
add_line(sub, 'Const_Tf_total/1', 'Product_Tf/2', 'autorouting', 'on');
add_line(sub, 'Product_Tf/1', 'SumTorque/5', 'autorouting', 'on');

add_line(sub, 'SumTorque/1', 'Divide_J/1', 'autorouting', 'on');
add_line(sub, 'Const_J_total/1', 'Divide_J/2', 'autorouting', 'on');
add_line(sub, 'Divide_J/1', 'Integrator_x2/1', 'autorouting', 'on');

add_line(sub, 'Integrator_x2/1', 'Integrator_x1/1', 'autorouting', 'on');
add_line(sub, 'Integrator_x2/1', 'theta_dot/1', 'autorouting', 'on');
add_line(sub, 'Integrator_x1/1', 'theta/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Da tao: %s\n', modelPath);

%% ----- Ham tien ich: dich chuyen khoi ve (x,y), GIU NGUYEN kich thuoc -----
function dichKhoi(blockPath, x, y)
    pos = get_param(blockPath, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blockPath, 'Position', [x, y, x + w, y + h]);
end
