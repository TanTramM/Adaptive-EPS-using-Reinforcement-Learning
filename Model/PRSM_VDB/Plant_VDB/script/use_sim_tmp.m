function folder = use_sim_tmp()
%USE_SIM_TMP Send MATLAB/Simulink temporary and cache files to drive D (drive C filled up in the past with Simulink SDI *.dmr files).
%   Valid for the current MATLAB session only; every run script of Plant_VDB calls it first and also calls Simulink.sdi.clear before each sim.
%   Falls back to the system temp folder when drive D does not exist.
    if exist('D:\', 'dir')
        folder = 'D:\sim_tmp';
    else
        folder = fullfile(tempdir, 'sim_tmp');
    end
    if ~exist(folder, 'dir'), mkdir(folder); end
    setenv('TEMP', folder); setenv('TMP', folder);
    % Simulink refuses a cache folder equal to the system temp folder, so the cache and the generated code go to sub folders.
    Simulink.fileGenControl('set', 'CacheFolder', fullfile(folder, 'cache'), 'CodeGenFolder', fullfile(folder, 'codegen'), 'createDir', true);
end
