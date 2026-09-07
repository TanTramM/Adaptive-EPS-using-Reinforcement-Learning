function build_plant()
    model_root = fileparts(mfilename('fullpath'));  % .../Model
    plant_dir  = fullfile(model_root, 'code', 'Plant');
    c_files    = dir(fullfile(plant_dir, '*.c'));

    old_dir = pwd;
    cd(plant_dir);
    try
        for i = 1:numel(c_files)
            fprintf('Compiling %s...\n', c_files(i).name);
            mex(c_files(i).name);
        end
    catch ME
        cd(old_dir);
        rethrow(ME);
    end
    cd(old_dir);
end