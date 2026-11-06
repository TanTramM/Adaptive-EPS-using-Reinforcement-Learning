function check_vdb_setup()
%CHECK_VDB_SETUP Checkpoint C0 of Documents/Shared/KeHoach_Plant_VDB.txt: items R2 (licenses), R4 (temp folder), R5 (tests of the existing
%   Plant), R6 (parameters), R7 (limits of the VDB blocks). Writes Result/PRSM/Plant_VDB/Plant_VDB_c0_report.txt.
%   Read-only for the repo: it does not change any model, parameter or result of the existing Plant.
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    repo = fileparts(modelDir);
    addpath(fullfile(modelDir, 'shared')); setup_paths;
    outDir = result_dir('Plant_VDB');
    fid = fopen(fullfile(outDir, 'Plant_VDB_c0_report.txt'), 'w'); say = @(varargin) fprintf(fid, varargin{:});

    % R2 licenses and libraries
    say('R2 licenses\n');
    for f = {'Vehicle_Dynamics_Blockset', 'Simscape', 'Simulink', 'Virtual_Reality_Toolbox'}
        ok = license('checkout', f{1}); say('  %-28s %s\n', f{1}, tern(ok, 'OK', 'NOT AVAILABLE'));
    end
    say('  MATLAB %s\n', version);
    try, load_system('vehdynlibeom'); load_system('vehdynlibtire'); say('  libraries vehdynlibeom, vehdynlibtire load: OK\n'); catch ME, say('  libraries: FAIL %s\n', ME.message); end

    % R4 temp folder
    tmp = use_sim_tmp;
    say('R4 TEMP/TMP of this MATLAB session = %s, Simulink cache folder = %s\n', getenv('TEMP'), tmp);
    say('   (the setting lasts for the session; every run script calls use_sim_tmp and Simulink.sdi.clear)\n');

    % R6 parameter table, straight from params.json
    raw = jsondecode(fileread(fullfile(modelDir, 'shared', 'data', 'params.json')));
    m = raw.cum2.m.value; a = raw.cum2.l_f.value; b = raw.cum2.l_r.value; g = raw.cum2.g.value; Iz = raw.cum3.Iz.value;
    Fzf = m*g*b/(a+b);
    say('R6 parameters from data/params.json\n');
    say('  m = %g kg, a = l_f = %g m, b = l_r = %g m, Izz = %g kg.m2, g = %g\n', m, a, b, Iz, g);
    say('  C_alpha_f = %g, C_r = %g N/rad (whole axle), C = %g, E = %g\n', raw.cum2.C_alpha_f.value, raw.cum2.C_r.value, raw.cum2.C.value, raw.cum2.E.value);
    say('  F_zf = %.1f N, F_zr = %.1f N; one front wheel = %.1f N\n', Fzf, m*g*a/(a+b), Fzf/2);
    say('  e_p0 = %g m, t_0 = %g m (pneumatic trail, shrinks with slip and mu), caster e_c = e_p0 - t_0 = %g m (constant), n_st = %g\n', ...
        raw.cum2.e_p0.value, raw.cum2.t_0.value, raw.cum2.e_p0.value - raw.cum2.t_0.value, raw.cum2.n_st.value);

    % R7 default limits of the VDB blocks on this release (read from a temporary, unsaved model)
    tmpm = 'tmp_c0'; new_system(tmpm);
    blk = [tmpm '/Tire']; add_block('vehdynlibtire/Combined Slip Wheel 2DOF', blk);
    try, set_param(blk, 'tireType', 'Light passenger car 205/60R15'); catch, end
    say('R7 limits of Combined Slip Wheel 2DOF on this release (preset Light passenger car 205/60R15)\n');
    for p = {'FZMIN', 'FZMAX', 'ALPMAX', 'ALPMIN', 'VXLOW', 'FNOMIN', 'UNLOADED_RADIUS', 'MASS', 'LATERAL_STIFFNESS', 'PKY1', 'PDY1', 'PCY1', 'PEY1', 'plySteer', 'turnslip'}
        try, say('  %-18s = %s\n', p{1}, get_param(blk, p{1})); catch, say('  %-18s : not readable\n', p{1}); end
    end
    say('  -> compare FZMAX with one front wheel F_z = %.1f N and with the whole axle %.1f N\n', Fzf/2, Fzf);
    bdc = [tmpm '/Body']; add_block('vehdynlibeom/Vehicle Body 3DOF Single Track', bdc);
    for p = {'Fznom', 'Fxtire_sat', 'Fytire_sat', 'xdot_tol', 'Cy_f', 'Cy_r', 'sigma_f', 'sigma_r', 'mu', 'h'}
        try, say('  3DOF %-12s = %s\n', p{1}, get_param(bdc, p{1})); catch, end
    end
    close_system(tmpm, 0);

    % R5 tests of the existing Plant (they must all PASS before any comparison; the Plant is not modified)
    [~, head] = system(sprintf('git -C "%s" rev-parse --short HEAD', repo));
    say('R5 tests of the existing Plant (git HEAD %s)\n', strtrim(head));
    run(fullfile(modelDir, 'original', 'PRSM', 'Plant', 'load_plant.m'));
    tests = {'test_cum1', 'test_cum2', 'test_cum3', 'test_plant'};
    for i = 1:numel(tests)
        t0 = tic;
        try
            txt = evalc(tests{i});
            say('  %-10s %s (%.0f s): %s\n', tests{i}, tern(contains(txt, 'PASS') && ~contains(txt, 'FAIL'), 'PASS', 'NOT PASS'), toc(t0), strtrim(lastLine(txt)));
        catch ME
            say('  %-10s ERROR: %s\n', tests{i}, ME.message);
        end
    end
    fclose(fid);
    type(fullfile(outDir, 'Plant_VDB_c0_report.txt'));
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end

function l = lastLine(t)
    L = splitlines(strtrim(t)); l = L{end};
end
