% load_params.m
% MATLAB script to load nominal CEPS parameters and pre-calculate 
% derived parameters once for the S-Function simulation.

% Xac dinh duong dan tuyet doi theo vi tri cua chinh file nay, khong phu
% thuoc thu muc lam viec (pwd) hien tai cua MATLAB.
script_dir = fileparts(mfilename('fullpath'));
json_file = fullfile(script_dir, 'data', 'params.json');

if exist(json_file, 'file')
    % 1. Read JSON file content
    json_text = fileread(json_file);
    data = jsondecode(json_text);
    
    % Initialize parameter structure
    p = struct();
    
    % 2. Load Nominal Parameters for all blocks
    % Block 1: Steering Column
    p.m_sw = data.block1_steering_column.m_sw;
    p.r_sw = data.block1_steering_column.r_sw;
    p.m_sh = data.block1_steering_column.m_sh;
    p.r_sh = data.block1_steering_column.r_sh;
    p.b_c  = data.block1_steering_column.b_c;
    p.t_fc = data.block1_steering_column.t_fc;
    p.m_rt = data.block1_steering_column.m_rt;
    p.r_rt = data.block1_steering_column.r_rt;
    p.z1   = data.block1_steering_column.z1;
    p.z2   = data.block1_steering_column.z2;
    p.j_m  = data.block1_steering_column.j_m;
    p.b_m  = data.block1_steering_column.b_m;
    p.m_rraw = data.block1_steering_column.m_rraw;
    p.m_wh   = data.block1_steering_column.m_wh;
    p.r_wh   = data.block1_steering_column.r_wh;
    p.l_am   = data.block1_steering_column.l_am;
    p.b_r    = data.block1_steering_column.b_r;
    p.T_fp_eq = data.block1_steering_column.T_fp_eq;
    p.r_p    = data.block1_steering_column.r_p;

    % Block 2: Tire & Pacejka (Load as nominal)
    p.t_p = data.block2_tire_pacejka.t_p;
    p.t_m = data.block2_tire_pacejka.t_m;
    p.B   = data.block2_tire_pacejka.B;
    p.C   = data.block2_tire_pacejka.C;
    p.D   = data.block2_tire_pacejka.D;
    p.E   = data.block2_tire_pacejka.E;

    % Block 3: Vehicle Dynamics (Load as nominal)
    p.m    = data.block3_vehicle_dynamics.m;
    p.l_f  = data.block3_vehicle_dynamics.l_f;
    p.l_r  = data.block3_vehicle_dynamics.l_r;
    p.k_zz = data.block3_vehicle_dynamics.k_zz;
    p.C_r  = data.block3_vehicle_dynamics.C_r;

    % Test Scenario
    p.v  = data.test_scenario.v;
    p.mu = data.test_scenario.mu;

    % 3. Pre-calculate Derived Parameters for Block 1 (Steering Column)
    % Mô-men quán tính vành vô-lăng
    p.J_sw = p.m_sw * (p.r_sw ^ 2);
    
    % Mô-men quán tính trục lái trên
    p.J_sh = 0.5 * p.m_sh * (p.r_sh ^ 2);
    
    % Tổng mô-men quán tính trục vô-lăng và cột lái trên
    p.J_c = p.J_sw + p.J_sh;
    
    % Tỉ số truyền hộp số giảm tốc trục vít - bánh vít
    p.g_w = p.z2 / p.z1;
    
    % Khối lượng quy đổi của cơ cấu thước lái thước lái
    p.m_r = p.m_rraw + 2 * p.m_wh * ((p.r_wh / p.l_am) ^ 2);
    
    % Mô-men quán tính bánh răng pinion dưới
    p.J_p = 0.5 * p.m_rt * (p.r_rt ^ 2);
    
    % Tổng mô-men quán tính quy đổi về trục Pinion dưới
    p.J_p_eq = p.J_p + (p.g_w ^ 2) * p.j_m + (p.r_p ^ 2) * p.m_r;
    
    % Tổng hệ số ma sát nhớt quy đổi tại cơ cấu pinion thước lái dưới
    p.B_p_eq = (p.g_w ^ 2) * p.b_m + (p.r_p ^ 2) * p.b_r;
    
    % Các thông số gộp cho mô hình trục lái cứng hợp nhất
    p.J_total = p.J_c + p.J_p_eq;
    p.B_total = p.b_c + p.B_p_eq;
    p.T_f_total = p.t_fc + p.T_fp_eq;
    
    % Hồi tiếp cánh tay đòn hình học lái (Sử dụng cho Block 2)
    p.K_torque_ratio = 2 * p.r_p * (p.t_p + p.t_m) / p.l_am;

    % Assign parameter structure 'p' to MATLAB base workspace
    assignin('base', 'p', p);
    
    disp('==================================================================');
    disp('  NOMINAL PARAMETERS LOADED & BLOCK 1 DERIVED SYSTEM CALCULATED   ');
    disp('==================================================================');
else
    error('File %s not found! Please check the path.', json_file);
end