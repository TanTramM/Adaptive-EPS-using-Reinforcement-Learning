function startup_project()
% startup_project - Thiet lap moi truong lam viec cho project Adaptive EPS.
%
% Goi ham nay 1 lan (thay vi tu cd/addpath tay) truoc khi chay mo phong:
%   >> startup_project
%
% Hoac gan vao InitFcn cua model (Model Properties > Callbacks > InitFcn)
% de no tu chay moi khi mo/chay .slx, khong con phu thuoc pwd hien tai:
%   [modelDir, ~, ~] = fileparts(get_param(bdroot, 'FileName'));
%   run(fullfile(modelDir, 'startup_project.m'));

    model_root = fileparts(mfilename('fullpath'));  % .../Model

    % Noi chua cac S-Function da bien dich (mex) cua tung cum Plant
    plant_dir = fullfile(model_root, 'code', 'Plant');
    if exist(plant_dir, 'dir')
        addpath(plant_dir);
    end

    % Cho phep goi load_params.m tu bat ky thu muc nao
    addpath(model_root);

    % Nap tham so vao base workspace (bien 'p')
    load_params;

    fprintf('[startup_project] Da addpath "%s" va nap tham so vao workspace.\n', plant_dir);
end
