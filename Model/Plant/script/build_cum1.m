%% build_cum1.m
% Dung Simulink API de dung khoi Cum 1 (co cau lai, CO THANH XOAN, 2 khoi
% quan tinh) thanh 1 subsystem rieng, luu thanh SteeringColumn_s.mdl NGAY
% TRONG thu muc Plant/ (thu muc cha cua script nay) - hau to "_s" de phan
% biet voi ban se tu format tay (SteeringColumn.mdl, cung thu muc). Khop
% dung Documents/Cum1_CEPS.txt:
%
%   PT(1) - khoi J1 (vo-lang):
%     x1_dot = x2
%     x2_dot = (T_d - K*(x1-x3) - C1*x2) / J1
%   PT(2) - khoi J2 (cot lai/pinion):
%     x3_dot = x4
%     x4_dot = (T_a - T_r - T_f*tanh(c*x4) - C2*x4 - K*(x3-x1)) / J2
%   Dau ra cam bien (CV, Blueprint muc 1.3):
%     T_s = K*(x1-x3)
%
% x1=theta1 (vo-lang), x3=theta2 (cot lai/pinion). T_s KHAC T_d (mo-men tay
% tai xe, ngoai sinh, khong do duoc - xem Cum1_CEPS.txt dau file).
%
% CAU TRUC PHAN CAP (moi - 1 subsystem con cho MOI phuong trinh vi phan):
%
%   Cum1_SteeringColumn
%     In : T_d, T_a, T_r          Out: theta1, theta1_dot, theta2,
%                                      theta2_dot, T_s
%     |
%     +-- Upper   (PT(1), khoi J1)
%     |     In : T_d, theta2      Out: theta1, theta1_dot, T_s
%     |     (T_s tinh o day vi Upper da co san hieu x1-x3 cho so hang lo xo)
%     |
%     +-- Lower   (PT(2), khoi J2)
%           In : T_a, T_r, theta1 Out: theta2, theta2_dot
%
%   2 tin hieu ghep cheo (theta1 -> Lower, theta2 -> Upper) tao vong hoi
%   tiep giua 2 subsystem - noi bang Goto/From cho khoi roi day.
%
% Quy uoc dung khoi:
%   - Moi khoi giu NGUYEN kich thuoc mac dinh khi add_block tao ra - chi
%     doi VI TRI (dich chuyen), khong keo dan/co lai (xem ham dichKhoi()).
%   - Phep nhan dung khoi Product (khong dung Gain).
%   - Phep chia (1/J1, 1/J2) dung khoi Product o che do chia (Divide).
%   - Ham tanh dung khoi Trigonometric Function (Function=tanh), khong
%     dung Fcn/MATLAB Function.
%   - Khoi Constant KHONG dat ten rieng - de ten mac dinh (Constant,
%     Constant1, ...), chi dat truong Value bang TEN BIEN base workspace.
%   - Goto/From deu de TagVisibility='local' (KHONG global/scoped): tag chi
%     nhin thay trong dung 1 cap he thong, nen tag trung ten o cap khac
%     (vd x1/x2 trong Upper vs x3/x4 trong Lower) khong va cham nhau.
%
% Tham so (K, J1, C1, J2, C2, T_f, c) lay tu base workspace - chay
% Model/load_params.m TRUOC khi build/mo phong.
%
% Cach dung (chay tu thu muc nay, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum1

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

%% ===================== Subsystem goc: Cum1_SteeringColumn ==============
sub = [modelName '/Cum1_SteeringColumn'];
taoSubsystem(sub);
dichKhoi(sub, 50, 50);

% --- Cong vao cap cum ---
themIn(sub, 'T_d', 1,  40,  60);
themIn(sub, 'T_a', 2,  40, 380);
themIn(sub, 'T_r', 3,  40, 440);

% --- Cong ra cap cum ---
themOut(sub, 'theta1',     1, 760,  60);
themOut(sub, 'theta1_dot', 2, 760, 130);
themOut(sub, 'T_s',        3, 760, 200);
themOut(sub, 'theta2',     4, 760, 380);
themOut(sub, 'theta2_dot', 5, 760, 450);

%% ===================== Subsystem UPPER - PT(1), khoi J1 ================
up = [sub '/Upper'];
taoSubsystem(up);
dichKhoi(up, 320, 60);
xayUpper(up);

%% ===================== Subsystem LOWER - PT(2), khoi J2 ================
lo = [sub '/Lower'];
taoSubsystem(lo);
dichKhoi(lo, 320, 380);
xayLower(lo);

%% ===================== Noi day cap cum ================================
% Vao thang tung subsystem
add_line(sub, 'T_d/1', 'Upper/1', 'autorouting', 'on');
add_line(sub, 'T_a/1', 'Lower/1', 'autorouting', 'on');
add_line(sub, 'T_r/1', 'Lower/2', 'autorouting', 'on');

% theta1 (Upper ra) -> Goto ; From -> Lower va cong ra cum
g_th1 = themGoto(sub, 'theta1', 520,  60);
add_line(sub, 'Upper/1', [g_th1 '/1'], 'autorouting', 'on');
f_th1a = themFrom(sub, 'theta1', 250, 470);
add_line(sub, [f_th1a '/1'], 'Lower/3', 'autorouting', 'on');
f_th1b = themFrom(sub, 'theta1', 660,  60);
add_line(sub, [f_th1b '/1'], 'theta1/1', 'autorouting', 'on');

% theta2 (Lower ra) -> Goto ; From -> Upper va cong ra cum
g_th2 = themGoto(sub, 'theta2', 520, 380);
add_line(sub, 'Lower/1', [g_th2 '/1'], 'autorouting', 'on');
f_th2a = themFrom(sub, 'theta2', 250, 150);
add_line(sub, [f_th2a '/1'], 'Upper/2', 'autorouting', 'on');
f_th2b = themFrom(sub, 'theta2', 660, 380);
add_line(sub, [f_th2b '/1'], 'theta2/1', 'autorouting', 'on');

% Cac dau ra con lai: noi thang (chi 1 dich den, khong can Goto/From)
add_line(sub, 'Upper/2', 'theta1_dot/1', 'autorouting', 'on');
add_line(sub, 'Upper/3', 'T_s/1',        'autorouting', 'on');
add_line(sub, 'Lower/2', 'theta2_dot/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Da tao: %s\n', modelPath);

%% ===================== Xay subsystem UPPER ============================
function xayUpper(up)
% PT(1): x2_dot = (T_d - K*(x1-x3) - C1*x2)/J1 ; x1_dot = x2
%        T_s    = K*(x1-x3)   (tinh luon o day, tai dung hieu x1-x3)
    themIn(up, 'T_d',    1,  40,  60);
    themIn(up, 'theta2', 2,  40, 320);

    themOut(up, 'theta1',     1, 780,  60);
    themOut(up, 'theta1_dot', 2, 780, 140);
    themOut(up, 'T_s',        3, 780, 330);

    hK  = themHang(up, 'K',  180, 380);
    hC1 = themHang(up, 'C1', 180, 230);
    hJ1 = themHang(up, 'J1', 330, 140);

    % x1 - x3 (x3 lay tu cong vao theta2)
    add_block('simulink/Math Operations/Add', [up '/Sub_dTheta']);
    set_param([up '/Sub_dTheta'], 'Inputs', '+-');
    dichKhoi([up '/Sub_dTheta'], 180, 310);

    % K*(x1-x3)  -> vua la so hang lo xo, vua la T_s
    add_block('simulink/Math Operations/Product', [up '/Prod_K']);
    dichKhoi([up '/Prod_K'], 260, 330);

    % C1*x2
    add_block('simulink/Math Operations/Product', [up '/Prod_C1']);
    dichKhoi([up '/Prod_C1'], 260, 220);

    % T_d - K*(x1-x3) - C1*x2
    add_block('simulink/Math Operations/Add', [up '/Sum1']);
    set_param([up '/Sum1'], 'Inputs', '+--');
    dichKhoi([up '/Sum1'], 350, 60);

    % ( ... ) / J1
    add_block('simulink/Math Operations/Product', [up '/Div_J1']);
    set_param([up '/Div_J1'], 'Inputs', '*/');
    dichKhoi([up '/Div_J1'], 430, 60);

    add_block('simulink/Continuous/Integrator', [up '/Int_x2']);
    dichKhoi([up '/Int_x2'], 500, 60);

    add_block('simulink/Continuous/Integrator', [up '/Int_x1']);
    dichKhoi([up '/Int_x1'], 660, 60);

    % --- Goto/From cho 2 bien trang thai (local) ---
    g_x2 = themGoto(up, 'x2', 560,  60);
    g_x1 = themGoto(up, 'x1', 720,  60);

    f_x2_int = themFrom(up, 'x2', 610,  60);   % -> Int_x1
    f_x2_c1  = themFrom(up, 'x2', 180, 190);   % -> Prod_C1
    f_x2_out = themFrom(up, 'x2', 720, 140);   % -> Out theta1_dot
    f_x1_sub = themFrom(up, 'x1', 110, 300);   % -> Sub_dTheta
    f_x1_out = themFrom(up, 'x1', 720, 200);   % -> Out theta1

    %% --- Noi day trong Upper ---
    add_line(up, [f_x1_sub '/1'], 'Sub_dTheta/1', 'autorouting', 'on');
    add_line(up, 'theta2/1',      'Sub_dTheta/2', 'autorouting', 'on');
    add_line(up, 'Sub_dTheta/1',  'Prod_K/1',     'autorouting', 'on');
    add_line(up, [hK '/1'],       'Prod_K/2',     'autorouting', 'on');

    add_line(up, [f_x2_c1 '/1'], 'Prod_C1/1', 'autorouting', 'on');
    add_line(up, [hC1 '/1'],     'Prod_C1/2', 'autorouting', 'on');

    add_line(up, 'T_d/1',     'Sum1/1', 'autorouting', 'on');
    add_line(up, 'Prod_K/1',  'Sum1/2', 'autorouting', 'on');
    add_line(up, 'Prod_C1/1', 'Sum1/3', 'autorouting', 'on');

    add_line(up, 'Sum1/1',    'Div_J1/1', 'autorouting', 'on');
    add_line(up, [hJ1 '/1'],  'Div_J1/2', 'autorouting', 'on');
    add_line(up, 'Div_J1/1',  'Int_x2/1', 'autorouting', 'on');

    add_line(up, 'Int_x2/1',       [g_x2 '/1'],  'autorouting', 'on');
    add_line(up, [f_x2_int '/1'],  'Int_x1/1',   'autorouting', 'on');
    add_line(up, 'Int_x1/1',       [g_x1 '/1'],  'autorouting', 'on');

    add_line(up, [f_x2_out '/1'], 'theta1_dot/1', 'autorouting', 'on');
    add_line(up, [f_x1_out '/1'], 'theta1/1',     'autorouting', 'on');
    add_line(up, 'Prod_K/1',      'T_s/1',        'autorouting', 'on');
end

%% ===================== Xay subsystem LOWER ============================
function xayLower(lo)
% PT(2): x4_dot = (T_a - T_r - T_f*tanh(c*x4) - C2*x4 - K*(x3-x1))/J2
%        x3_dot = x4
    themIn(lo, 'T_a',    1,  40,  60);
    themIn(lo, 'T_r',    2,  40, 120);
    themIn(lo, 'theta1', 3,  40, 420);

    themOut(lo, 'theta2',     1, 780,  60);
    themOut(lo, 'theta2_dot', 2, 780, 140);

    hK  = themHang(lo, 'K',   180, 480);
    hC2 = themHang(lo, 'C2',  180, 330);
    hc  = themHang(lo, 'c',   180, 250);
    hTf = themHang(lo, 'T_f', 330, 210);
    hJ2 = themHang(lo, 'J2',  430, 140);

    % x3 - x1 (x1 lay tu cong vao theta1)
    add_block('simulink/Math Operations/Add', [lo '/Sub_dTheta']);
    set_param([lo '/Sub_dTheta'], 'Inputs', '+-');
    dichKhoi([lo '/Sub_dTheta'], 180, 410);

    add_block('simulink/Math Operations/Product', [lo '/Prod_K']);
    dichKhoi([lo '/Prod_K'], 260, 430);

    add_block('simulink/Math Operations/Product', [lo '/Prod_C2']);
    dichKhoi([lo '/Prod_C2'], 260, 320);

    % c*x4 -> tanh -> T_f*tanh(c*x4)
    add_block('simulink/Math Operations/Product', [lo '/Prod_c']);
    dichKhoi([lo '/Prod_c'], 260, 240);

    add_block('simulink/Math Operations/Trigonometric Function', [lo '/Tanh']);
    set_param([lo '/Tanh'], 'Operator', 'tanh');
    dichKhoi([lo '/Tanh'], 330, 250);

    add_block('simulink/Math Operations/Product', [lo '/Prod_Tf']);
    dichKhoi([lo '/Prod_Tf'], 400, 230);

    % T_a - T_r - T_f*tanh(c*x4) - C2*x4 - K*(x3-x1)
    add_block('simulink/Math Operations/Add', [lo '/Sum2']);
    set_param([lo '/Sum2'], 'Inputs', '+----');
    dichKhoi([lo '/Sum2'], 470, 60);

    add_block('simulink/Math Operations/Product', [lo '/Div_J2']);
    set_param([lo '/Div_J2'], 'Inputs', '*/');
    dichKhoi([lo '/Div_J2'], 540, 60);

    add_block('simulink/Continuous/Integrator', [lo '/Int_x4']);
    dichKhoi([lo '/Int_x4'], 600, 60);

    add_block('simulink/Continuous/Integrator', [lo '/Int_x3']);
    dichKhoi([lo '/Int_x3'], 720, 60);

    % --- Goto/From cho 2 bien trang thai (local) ---
    g_x4 = themGoto(lo, 'x4', 650,  60);
    g_x3 = themGoto(lo, 'x3', 770,  60);

    f_x4_int = themFrom(lo, 'x4', 690,  60);   % -> Int_x3
    f_x4_c2  = themFrom(lo, 'x4', 110, 310);   % -> Prod_C2
    f_x4_c   = themFrom(lo, 'x4', 110, 230);   % -> Prod_c
    f_x4_out = themFrom(lo, 'x4', 720, 140);   % -> Out theta2_dot
    f_x3_sub = themFrom(lo, 'x3', 110, 400);   % -> Sub_dTheta
    f_x3_out = themFrom(lo, 'x3', 720, 200);   % -> Out theta2

    %% --- Noi day trong Lower ---
    add_line(lo, [f_x3_sub '/1'], 'Sub_dTheta/1', 'autorouting', 'on');
    add_line(lo, 'theta1/1',      'Sub_dTheta/2', 'autorouting', 'on');
    add_line(lo, 'Sub_dTheta/1',  'Prod_K/1',     'autorouting', 'on');
    add_line(lo, [hK '/1'],       'Prod_K/2',     'autorouting', 'on');

    add_line(lo, [f_x4_c2 '/1'], 'Prod_C2/1', 'autorouting', 'on');
    add_line(lo, [hC2 '/1'],     'Prod_C2/2', 'autorouting', 'on');

    add_line(lo, [f_x4_c '/1'], 'Prod_c/1', 'autorouting', 'on');
    add_line(lo, [hc '/1'],     'Prod_c/2', 'autorouting', 'on');
    add_line(lo, 'Prod_c/1',    'Tanh/1',   'autorouting', 'on');
    add_line(lo, 'Tanh/1',      'Prod_Tf/1', 'autorouting', 'on');
    add_line(lo, [hTf '/1'],    'Prod_Tf/2', 'autorouting', 'on');

    add_line(lo, 'T_a/1',     'Sum2/1', 'autorouting', 'on');
    add_line(lo, 'T_r/1',     'Sum2/2', 'autorouting', 'on');
    add_line(lo, 'Prod_Tf/1', 'Sum2/3', 'autorouting', 'on');
    add_line(lo, 'Prod_C2/1', 'Sum2/4', 'autorouting', 'on');
    add_line(lo, 'Prod_K/1',  'Sum2/5', 'autorouting', 'on');

    add_line(lo, 'Sum2/1',   'Div_J2/1', 'autorouting', 'on');
    add_line(lo, [hJ2 '/1'], 'Div_J2/2', 'autorouting', 'on');
    add_line(lo, 'Div_J2/1', 'Int_x4/1', 'autorouting', 'on');

    add_line(lo, 'Int_x4/1',      [g_x4 '/1'], 'autorouting', 'on');
    add_line(lo, [f_x4_int '/1'], 'Int_x3/1',  'autorouting', 'on');
    add_line(lo, 'Int_x3/1',      [g_x3 '/1'], 'autorouting', 'on');

    add_line(lo, [f_x4_out '/1'], 'theta2_dot/1', 'autorouting', 'on');
    add_line(lo, [f_x3_out '/1'], 'theta2/1',     'autorouting', 'on');
end

%% ===================== Ham tien ich ===================================
function dichKhoi(blk, x, y)
% Dich chuyen khoi ve (x,y), GIU NGUYEN kich thuoc mac dinh.
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function taoSubsystem(path)
% Tao 1 Subsystem rong (bo cap In1->Out1 mac dinh).
    add_block('simulink/Ports & Subsystems/Subsystem', path);
    delete_line(path, 'In1/1', 'Out1/1');
    delete_block([path '/In1']);
    delete_block([path '/Out1']);
end

function themIn(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sources/In1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
end

function themOut(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sinks/Out1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
end

function nm = themHang(sys, bienBaseWs, x, y)
% Them khoi Constant KHONG dat ten rieng (de ten mac dinh Constant,
% Constant1, ...), Value tro THANG toi ten bien trong base workspace.
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'Value', bienBaseWs);
    dichKhoi(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = themGoto(sys, tag, x, y)
% Goto pham vi LOCAL (khong global/scoped).
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    dichKhoi(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = themFrom(sys, tag, x, y)
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    dichKhoi(h, x, y);
    nm = get_param(h, 'Name');
end
