%% build_reference.m
% Dung khoi "Reference" (T_d,ref(v,a_y)) va sai so dieu khien e_T, khop
% Blueprint_OverAssist_RL.txt muc 1.3 (CV = e_T = T_d - T_d,ref) va so do
% khoi trang 3 Thesis.pdf (block "Reference" nhan v + tin hieu phan hoi,
% cong voi nut tru cho T_d).
%
%   T_d,ref(v, a_y) = noi suy 2D tren Bang 4 [7] (Road_Identification_BP-NN.pdf)
%   e_T = T_d - T_d,ref
%
% Du lieu Bang 4 (v_bp, a_y_bp, bang so) KHONG nhung cung trong script nay
% - doc tu Model/data/ref.json qua Model/load_ref.m (rieng, khong chung
% Model/load_params.m), khoi 2-D Lookup Table CHI THAM CHIEU TEN BIEN base
% workspace (Tdref_v_bp_ms, Tdref_ay_bp_ms2, Tdref_table) - sua so lieu chi
% can sua data/ref.json + chay lai load_ref, KHONG can sua file build nay.
%
% Bang 4 chi co du lieu a_y DUONG (do do lon |a_y|, khong phan biet chieu
% quay). QUYET DINH KY THUAT (tu chon, khong tu nguon): tra bang theo
% |a_y|, sau do nhan lai dau sign(a_y) de T_d,ref cung dau voi T_d thuc te
% (mo-men tay lai doi chieu theo chieu quay vo-lang).
%
% Quy uoc dung khoi (giong build_cum1/2/3.m):
%   - Moi khoi giu NGUYEN kich thuoc mac dinh - chi doi VI TRI (dichKhoi()).
%   - Phep nhan dung khoi Product (khong dung Gain).
%   - abs(.) dung khoi Abs, sgn(.) dung khoi Sign (khong dung Fcn).
%   - Noi suy 2D dung khoi chuan "2-D Lookup Table".
%
% Cach dung (chay tu thu muc nay, Ref/script/):
%   >> run('../../load_ref.m')
%   >> build_reference
%   (model Reference_s.mdl duoc tao trong thu muc Ref/, hau to "_s" de
%   phan biet voi ban tu format tay - neu co - cung ten khong hau to)

modelName = 'Reference_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Ref/script
refDir    = fileparts(scriptDir);               % Ref/
modelPath = fullfile(refDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

sub = [modelName '/Reference'];
add_block('simulink/Ports & Subsystems/Subsystem', sub);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);
delete_block([sub '/Out1']);
dichKhoi(sub, 50, 50);

%% ----- Dau vao: T_d, v, a_y -----
in_Td = addIn(sub, 'T_d', 1, 40, 40);
in_v  = addIn(sub, 'v',   2, 40, 200);
in_ay = addIn(sub, 'a_y', 3, 40, 360);

%% ----- Dau ra: T_d_ref, e_T -----
out_Tdref = addOut(sub, 'T_d_ref', 1, 700, 200);
out_eT    = addOut(sub, 'e_T',     2, 900, 60);

%% ----- |a_y| va sgn(a_y) -----
b_abs = addBlock(sub, 'Abs_ay', 'simulink/Math Operations/Abs', 200, 360);
b_sgn = addBlock(sub, 'Sign_ay', 'simulink/Math Operations/Sign', 200, 460);

%% ----- T_d,ref(v, |a_y|) - 2-D Lookup Table, doc ten bien tu load_ref.m -----
assert(evalin('base', 'exist(''Tdref_table'', ''var'')') == 1, ...
    'Chua nap ref.json - chay load_ref truoc khi build_reference.');

b_lut = addBlock(sub, 'LUT_Tdref', 'simulink/Lookup Tables/2-D Lookup Table', 320, 200);
lutFull = [sub '/' b_lut];
set_param(lutFull, 'Table', 'Tdref_table');
set_param(lutFull, 'BreakpointsForDimension1', 'Tdref_v_bp_ms');
set_param(lutFull, 'BreakpointsForDimension2', 'Tdref_ay_bp_ms2');
set_param(lutFull, 'InterpMethod', 'Linear');
set_param(lutFull, 'ExtrapMethod', 'Clip');

%% ----- T_d_ref = sgn(a_y) * LUT(v, |a_y|) -----
p_Tdref = addProd(sub, 'Product_Tdref', '**', 500, 200);

%% ----- e_T = T_d - T_d_ref -----
a_eT = addAdd(sub, 'Sum_eT', '+-', 780, 100);

%% ----- Noi day -----
add_line(sub, [in_ay '/1'], [b_abs '/1'], 'autorouting', 'on');
add_line(sub, [in_ay '/1'], [b_sgn '/1'], 'autorouting', 'on');

add_line(sub, [in_v '/1'],  [b_lut '/1'], 'autorouting', 'on');
add_line(sub, [b_abs '/1'], [b_lut '/2'], 'autorouting', 'on');

add_line(sub, [b_sgn '/1'], [p_Tdref '/1'], 'autorouting', 'on');
add_line(sub, [b_lut '/1'], [p_Tdref '/2'], 'autorouting', 'on');
add_line(sub, [p_Tdref '/1'], [out_Tdref '/1'], 'autorouting', 'on');

add_line(sub, [in_Td '/1'],   [a_eT '/1'], 'autorouting', 'on');
add_line(sub, [p_Tdref '/1'], [a_eT '/2'], 'autorouting', 'on');
add_line(sub, [a_eT '/1'], [out_eT '/1'], 'autorouting', 'on');

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
