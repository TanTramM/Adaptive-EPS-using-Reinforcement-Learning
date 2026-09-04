% load_ceps_params-v3.m
% MATLAB script to automatically load CEPS system and vehicle dynamics parameters from JSON

json_file = 'ceps_params.json'; % Change to 'data/ceps_params.json' if needed on your local setup

if exist(json_file, 'file')
    % 1. Read JSON file content
    json_text = fileread(json_file);
    data = jsondecode(json_text);
    
    % 2. Automatically load all measured physical parameters using dynamic field loading
    fields_measured = fieldnames(data.measured_physical_parameters);
    for i = 1:numel(fields_measured)
        field_name = fields_measured{i};
        assignin('base', field_name, data.measured_physical_parameters.(field_name));
    end
    
    % 3. Automatically load derived dynamic parameters for Section 3.1
    fields_derived31 = fieldnames(data.steering_column_derived_dynamics);
    for i = 1:numel(fields_derived31)
        field_name = fields_derived31{i};
        assignin('base', field_name, data.steering_column_derived_dynamics.(field_name));
    end
    
    % 4. Automatically load derived dynamic parameters for Section 3.2
    fields_derived32 = fieldnames(data.torsion_bar_derived_dynamics);
    for i = 1:numel(fields_derived32)
        field_name = fields_derived32{i};
        assignin('base', field_name, data.torsion_bar_derived_dynamics.(field_name));
    end
    
    disp('==================================================================');
    disp('  PHYSICAL AND DERIVED PARAMETERS (SECTIONS 3.1 & 3.2) LOADED');
    disp('==================================================================');
else
    error('File %s not found! Please check the path.', json_file);
end