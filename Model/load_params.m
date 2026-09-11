% load_params.m
% Load nominal CEPS parameters from data/params.json and pre-calculate every
% derived parameter ONCE (not per simulation step). The result is a single
% struct 'p' published to the base workspace, read by the S-Function blocks'
% "Parameters" fields (see Model/code/Plant/*.c).

%% 1. Locate and read the JSON parameter file
% Resolved relative to this script's own location, not MATLAB's current
% working directory (pwd), so this works regardless of where it's called from.
script_dir = fileparts(mfilename('fullpath'));
json_file = fullfile(script_dir, 'data', 'params.json');

if ~exist(json_file, 'file')
    error('File %s not found! Please check the path.', json_file);
end

json_text = fileread(json_file);
data = jsondecode(json_text);
p = struct();

%% 2. Raw parameters - Block 1: Rigid Steering Dynamics (thesis eq. 1-12)
p.m_sw    = data.block1_steering_column.m_sw;
p.r_sw    = data.block1_steering_column.r_sw;
p.m_sh    = data.block1_steering_column.m_sh;
p.r_sh    = data.block1_steering_column.r_sh;
p.b_c     = data.block1_steering_column.b_c;
p.t_fc    = data.block1_steering_column.t_fc;
p.m_rt    = data.block1_steering_column.m_rt;
p.r_rt    = data.block1_steering_column.r_rt;
p.z1      = data.block1_steering_column.z1;
p.z2      = data.block1_steering_column.z2;
p.b_m     = data.block1_steering_column.b_m;
p.m_rraw  = data.block1_steering_column.m_rraw;
p.m_wh    = data.block1_steering_column.m_wh;
p.r_wh    = data.block1_steering_column.r_wh;
p.l_am    = data.block1_steering_column.l_am;
p.b_r     = data.block1_steering_column.b_r;
p.T_fp_eq = data.block1_steering_column.T_fp_eq;
p.r_p     = data.block1_steering_column.r_p;

%% 3. Raw parameters - Block 2: Pacejka Tire Dynamics (thesis eq. 13-24)
p.t_p       = data.block2_tire_pacejka.t_p;
p.t_m       = data.block2_tire_pacejka.t_m;
p.C_alpha_f = data.block2_tire_pacejka.C_alpha_f;
p.C         = data.block2_tire_pacejka.C;
p.E         = data.block2_tire_pacejka.E;

%% 4. Raw parameters - Block 3: Vehicle Dynamics, Bicycle 2-DOF (thesis eq. 25-37)
p.m    = data.block3_vehicle_dynamics.m;
p.l_f  = data.block3_vehicle_dynamics.l_f;
p.l_r  = data.block3_vehicle_dynamics.l_r;
p.k_zz = data.block3_vehicle_dynamics.k_zz;
p.C_r  = data.block3_vehicle_dynamics.C_r;

%% 5. Test scenario (driving condition) parameters
p.v  = data.test_scenario.v;
p.mu = data.test_scenario.mu;

%% 6. Derived parameters - Block 1 (Rigid Steering Dynamics, eq. 5-7)
% Steering wheel rim moment of inertia
p.J_sw = p.m_sw * (p.r_sw ^ 2);

% Upper steering shaft moment of inertia
p.J_sh = 0.5 * p.m_sh * (p.r_sh ^ 2);

% Combined moment of inertia of the steering wheel + upper column
p.J_c = p.J_sw + p.J_sh;

% Worm/worm-wheel gearbox reduction ratio
p.g_w = p.z2 / p.z1;

% Equivalent mass of the rack-and-pinion mechanism, reflected to the rack
p.m_r = p.m_rraw + 2 * p.m_wh * ((p.r_wh / p.l_am) ^ 2);

% Assist motor rotor inertia (solid cylinder). This is the ONLY place the
% rotor enters J_total: it must be reflected through the gearbox ratio below,
% never added again un-geared.
p.J_m = 0.5 * p.m_rt * (p.r_rt ^ 2);

% Total moment of inertia reflected to the lower pinion shaft
p.J_p_eq = (p.g_w ^ 2) * p.J_m + (p.r_p ^ 2) * p.m_r;

% Total equivalent viscous friction reflected to the lower pinion shaft
p.B_p_eq = (p.g_w ^ 2) * p.b_m + (p.r_p ^ 2) * p.b_r;

% Lumped parameters for the unified rigid steering shaft model.
% These 3 are exactly the "Parameters" field of the SteeringColumn S-Function.
p.J_total   = p.J_c + p.J_p_eq;
p.B_total   = p.b_c + p.B_p_eq;
p.T_f_total = p.t_fc + p.T_fp_eq;

%% 7. Derived parameters - Block 2 (Pacejka Tire Dynamics, eq. 21-22)
% K_tr (eq. 22): converts the PER-WHEEL front tire lateral force into the road
% feedback torque felt at the steering column. The factor 2 accounts for both
% front wheels on that torque path.
p.K_torque_ratio = 2 * p.r_p * (p.t_p + p.t_m) / p.l_am;

% F_zf (eq. 21): static vertical load on ONE front wheel (needs m, l_f, l_r
% from Block 3, loaded in section 4 above). Fixed at init; the Pacejka peak
% factor D_f = mu * F_zf (eq. 18) is then computed per-step inside
% TirePacejka.c since mu is a live input, not a constant.
p.F_zf = (p.m * 9.81 * p.l_r) / (2 * (p.l_f + p.l_r));

%% 8. Derived parameters - Block 3 (Vehicle Dynamics, eq. 29)
% Vehicle yaw moment of inertia about the vertical axis through the CG
p.I_z = p.m * (p.k_zz ^ 2);

%% 9. Publish to base workspace
assignin('base', 'p', p);

disp('==================================================================');
disp('  NOMINAL PARAMETERS LOADED & DERIVED PARAMETERS PRE-CALCULATED   ');
disp('==================================================================');
