% load_params.m
% MATLAB script to automatically load CEPS system and vehicle dynamics parameters from JSON

json_file = 'data/params.json';

if exist(json_file, 'file')
    % 1. Read JSON file content
    json_text = fileread(json_file);
    data = jsondecode(json_text);
    
    % 2. Automatically load all categories and parameters dynamically
    categories = fieldnames(data);
    for idx_cat = 1:numel(categories)
        category_name = categories{idx_cat};
        category_struct = data.(category_name);
        
        % Load all nested fields within the current physical category
        fields = fieldnames(category_struct);
        for idx_field = 1:numel(fields)
            field_name = fields{idx_field};
            assignin('base', field_name, category_struct.(field_name));
        end
    end
    
    disp('==================================================================');
    disp('  ALL PHYSICAL AND DERIVED CEPS PARAMETERS LOADED SUCCESSFULLY');
    disp('==================================================================');
else
    error('File %s not found! Please check the path.', json_file);
end