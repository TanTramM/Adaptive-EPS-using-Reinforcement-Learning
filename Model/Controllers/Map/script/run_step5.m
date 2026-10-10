%% run_step5.m
% Runner script for Step 5: design, plot and test Map controller.

scriptDir = fileparts(mfilename('fullpath'));
modelDir  = fileparts(fileparts(fileparts(scriptDir)));
addpath(modelDir); setup_paths;

fprintf('=======================================================\n');
fprintf('STEP 5: OPTIMIZING & SELECTING MAP CONTROLLER (K_max)\n');
fprintf('=======================================================\n');

t0 = tic;
res = design_map(false);
t_design = toc(t0);
fprintf('design_map completed in %.2f s.\n\n', t_design);

fprintf('Generating Step 5 figures ...\n');
plot_step5();

fprintf('\nRunning test_step5 ...\n');
run(fullfile(scriptDir, 'test_step5.m'));

