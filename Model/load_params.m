% load_params.m
% MATLAB script to load physical parameters from params.json and calculate derived dynamic parameters

json_file = 'params.json';

if exist(json_file, 'file')
    % 1. Read JSON file content
    json_text = fileread(json_file);
    data = jsondecode(json_text);
    
    % 2. Dynamically load all measured physical parameters into the MATLAB Workspace
    fields = fieldnames(data.measured_physical_parameters);
    for idx = 1:numel(fields)
        field_name = fields{idx};
        assignin('base', field_name, data.measured_physical_parameters.(field_name));
    end
    
    % 3. Calculate Derived Dynamics Parameters (Sections 3.1 to 3.4)
    
    % --- SECTION 3.1: Upper Steering Column Dynamics ---
    % Moment of inertia of the steering wheel (thin ring model)
    J_sw = m_sw * r_sw^2; 
    % Moment of inertia of the steering shaft (solid cylinder model)
    J_sh = 0.5 * m_sh * r_sh^2; 
    % Total reduced moment of inertia of the upper column
    j_c = J_sw + J_sh; 
    
    % --- SECTION 3.2: Torsion Bar Elasticity ---
    % Polar moment of inertia of the circular torsion bar cross-section
    I_p = (pi * d_tb^4) / 32; 
    % Torsional stiffness of the torsion bar (material SUP7)
    k_c = (g_st * I_p) / l_tb; 
    
    % --- SECTION 3.3: Motor and Rack-Pinion Dynamics ---
    % Worm gear reduction ratio
    g_w = z2 / z1; 
    % Pinion pitch circle radius
    r_p = c_lk / (2 * pi); 
    % Moment of inertia of the assist motor rotor
    j_m = 0.5 * m_rt * r_rt^2; 
    % Moment of inertia of one front wheel about the kingpin axis
    j_w_rot = m_wh * r_wh^2; 
    % Equivalent linear mass translation from the rotation of both front wheels
    m_w_eq = 2 * (j_w_rot / l_am^2); 
    % Total equivalent mass of the rack and steering assembly
    m_r = m_rraw + m_w_eq; 
    % Total equivalent moment of inertia reduced to the Pinion shaft
    J_p_eq = (g_w^2 * j_m) + (r_p^2 * m_r); 
    % Total equivalent viscous damping coefficient reduced to the Pinion shaft
    B_p_eq = (g_w^2 * b_m) + (r_p^2 * b_r); 
    % Total equivalent dry friction torque reduced to the Pinion shaft
    T_fp_eq = r_p * f_fr; 
    
    % --- SECTION 3.4: Tire Magic Formula and Steering Geometry ---
    % Geometric steering gear ratio
    i_sg = l_am / r_p; 
    % Total trail (Pneumatic trail + Mechanical caster trail)
    t_total = t_p + t_m; 
    % Force ratio coefficient from tire lateral force to rack feedback force
    K_force_ratio = (2 * t_total) / l_am; 
    % Torque ratio coefficient from tire lateral force to pinion feedback torque
    K_torque_ratio = r_p * K_force_ratio; 
    
    % 4. Print Summary to MATLAB Command Window
    disp('==================================================================');
    disp('  CEPS MEASURED PHYSICAL PARAMETERS DYNAMICALLY LOADED');
    disp('==================================================================');
    fprintf('  Upper Column Reduced Inertia (j_c):    %10.6f kg.m2\n', j_c);
    fprintf('  Torsion Bar Stiffness (k_c):          %10.4f N.m/rad\n', k_c);
    fprintf('  Worm Gear Reduction Ratio (g_w):      %10.2f\n', g_w);
    fprintf('  Pinion Pitch Radius (r_p):            %10.4f m\n', r_p);
    fprintf('  Total Rack Eq. Mass (m_r):            %10.2f kg\n', m_r);
    fprintf('  Pinion Eq. Inertia (J_p_eq):          %10.6f kg.m2\n', J_p_eq);
    fprintf('  Pinion Eq. Viscous Damping (B_p_eq):  %10.4f N.m/(rad/s)\n', B_p_eq);
    fprintf('  Pinion Eq. Dry Friction (T_fp_eq):    %10.6f N.m\n', T_fp_eq);
    fprintf('  Steering Gear Ratio (i_sg):           %10.4f\n', i_sg);
    fprintf('  Total Tire Trail (t_total):           %10.4f m\n', t_total);
    fprintf('  Tire-to-Rack Force Ratio:             %10.4f\n', K_force_ratio);
    fprintf('  Tire-to-Pinion Torque Ratio:          %10.6f\n', K_torque_ratio);
    disp('==================================================================');
    disp('  ALL CEPS DERIVED PARAMETERS CALCULATED AND INTEGRATED SUCCESSFULLY');
    disp('==================================================================');
else
    error('File %s not found! Please check the path.', json_file);
end