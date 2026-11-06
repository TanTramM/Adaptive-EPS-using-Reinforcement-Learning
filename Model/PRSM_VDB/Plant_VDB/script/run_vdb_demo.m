function run_vdb_demo(mdl)
%RUN_VDB_DEMO Simulate VDBDemo.slx (built by build_vdb_demo) and save two figures and a short report in Result/PRSM/Plant_VDB/:
%   Plant_VDB_demo_bodyA.png, Plant_VDB_demo_tireB.png, Plant_VDB_demo_report.txt.
%   Chain A is compared with the textbook steady-state yaw rate of the bicycle model; chain B sweeps the friction scale factor LMUY.
    if nargin < 1, mdl = 'VDBDemo'; end
    warning('off', 'all');
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    plantDir = fileparts(scriptDir);
    addpath(modelDir); setup_paths;
    use_sim_tmp;
    outDir = result_dir('Plant_VDB');
    raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
    m = raw.cum2.m.value; a = raw.cum2.l_f.value; b = raw.cum2.l_r.value; g = raw.cum2.g.value;
    Cf = raw.cum2.C_alpha_f.value; Cr = raw.cum2.C_r.value;
    load_system(fullfile(plantDir, [mdl '.slx']));
    fid = fopen(fullfile(outDir, 'Plant_VDB_demo_report.txt'), 'w');
    say = @(varargin) fprintf(fid, varargin{:});

    %% Chain A: steady yaw rate of the 3DOF body against the textbook bicycle formula
    Simulink.sdi.clear;
    tic; out = sim(Simulink.SimulationInput(mdl)); tsim = toc;
    r = out.A_r; v = 20; delta = 0.02; L = a + b;
    % Steady state of the bicycle model: r = v*delta/(L + Kus*v^2), Kus = m*(b/C_front - a/C_rear)/L with C the AXLE stiffness.
    Kus_axle = m * (b / Cf - a / Cr) / L;            % if the block value Cy were the axle stiffness
    r_axle = v * delta / (L + Kus_axle * v^2);
    Kus_wheel = m * (b / (2*Cf) - a / (2*Cr)) / L;   % if the block value Cy were the stiffness of ONE wheel (axle = 2*Cy)
    r_wheel = v * delta / (L + Kus_wheel * v^2);
    % The block multiplies the stiffness by Fz/Fznom (Fznom = 5000 N by default); test this hypothesis too.
    Fzn = str2double(get_param([mdl '/Body3DOF'], 'Fznom'));
    cf = Cf * (m*g*b/L) / Fzn; cr = Cr * (m*g*a/L) / Fzn;
    r_fz = v * delta / (L + m * (b / cf - a / cr) / L * v^2);
    r_end = r.Data(end);
    say('Chain A (3DOF Single Track, velocity mode, v=20 m/s, step front steer 0.02 rad, Cy_f=%g, Cy_r=%g N/rad)\n', Cf, Cr);
    say('  sim wall time %.1f s for 10 s\n', tsim);
    say('  yaw rate at 10 s                      : %.5f rad/s\n', r_end);
    say('  bicycle formula, Cy = AXLE stiffness  : %.5f rad/s  (diff %+.2f %%)\n', r_axle, 100*(r_end/r_axle - 1));
    say('  bicycle formula, Cy = WHEEL stiffness : %.5f rad/s  (diff %+.2f %%)\n', r_wheel, 100*(r_end/r_wheel - 1));
    say('  bicycle formula, Cy*Fz/Fznom per axle : %.5f rad/s  (diff %+.2f %%), effective stiffness %.0f and %.0f N/rad\n', r_fz, 100*(r_end/r_fz - 1), cf, cr);
    say('  xdot at 10 s = %.4f m/s (input 20)\n\n', out.A_xdot.Data(end));
    f1 = figure('Visible', 'off', 'Position', [100 100 900 600]);
    subplot(2,1,1); plot(r.Time, r.Data, 'LineWidth', 1.4); hold on; yline(r_axle, '--r'); yline(r_wheel, ':k'); yline(r_fz, '-.m'); grid on;
    ylabel('yaw rate r (rad/s)'); legend('Body3DOF', 'Cy = axle', 'Cy = wheel', 'Cy*Fz/Fznom', 'Location', 'southeast');
    title('Vehicle Body 3DOF Single Track: step front steer 0.02 rad at 1 s, v = 20 m/s');
    subplot(2,1,2); plot(out.A_ydot.Time, out.A_ydot.Data, 'LineWidth', 1.4); grid on; ylabel('lateral velocity ydot (m/s)'); xlabel('time (s)');
    saveas(f1, fullfile(outDir, 'Plant_VDB_demo_bodyA.png')); close(f1);

    %% Chain B: one Combined Slip Wheel 2DOF, Fy and Mz against slip angle, several LMUY
    Fz0 = m * g * b / (a + b) / 2;
    lmu = [1 0.5 0.3]; col = lines(numel(lmu));
    f2 = figure('Visible', 'off', 'Position', [100 100 1000 650]);
    say('Chain B (Combined Slip Wheel 2DOF, Vx=20 m/s, Fz set from outside = %.0f N, one front wheel)\n', Fz0);
    for i = 1:numel(lmu)
        Simulink.sdi.clear;
        si = Simulink.SimulationInput(mdl); si = si.setVariable('LMUY', lmu(i), 'Workspace', mdl);
        o = sim(si);
        t = o.B_Fy.Time; vy = -3 + 0.6 * t; alpha = atan2(vy, 20);   % alpha = atan(Vy/Vx); the Plant uses the opposite sign (R8 of the plan)
        fy = o.B_Fy.Data; mz = o.B_Mz.Data; fz = o.B_Fz.Data;
        [~, ip] = max(abs(fy));
        k0 = find(abs(alpha) < 0.002); slope = polyfit(alpha(k0), fy(k0), 1);
        say('  LMUY %.2f : Fz at end %.0f N, peak |Fy| %.0f N (mu*Fz = %.0f N) at alpha %.3f rad, slope at 0 = %.0f N/rad, max|Mz| %.1f N.m\n', ...
            lmu(i), fz(end), abs(fy(ip)), lmu(i)*Fz0, alpha(ip), slope(1), max(abs(mz)));
        subplot(2,2,[1 3]); plot(alpha, fy, 'Color', col(i,:), 'LineWidth', 1.4); hold on;
        subplot(2,2,2); plot(alpha, mz, 'Color', col(i,:), 'LineWidth', 1.4); hold on;
        subplot(2,2,4); plot(t, fz, 'Color', col(i,:), 'LineWidth', 1.4); hold on;
    end
    subplot(2,2,[1 3]); grid on; xlabel('slip angle alpha = atan(Vy/Vx) (rad)'); ylabel('Fy (N)'); legend(arrayfun(@(x) sprintf('LMUY = %.1f', x), lmu, 'UniformOutput', false));
    title('Combined Slip Wheel 2DOF: lateral force');
    subplot(2,2,2); grid on; xlabel('alpha (rad)'); ylabel('Mz (N.m)'); title('aligning moment');
    subplot(2,2,4); grid on; xlabel('time (s)'); ylabel('Fz (N)'); title('vertical load (stays at the value set from outside)');
    saveas(f2, fullfile(outDir, 'Plant_VDB_demo_tireB.png')); close(f2);
    say('\nTo check by hand: sign of Fy and Mz against alpha (Plant_VDB_demo_tireB.png), and whether LMUY changes the slope at 0 (Plant: slope must not change with mu).\n');
    fclose(fid);
    close_system(mdl, 0);
    type(fullfile(outDir, 'Plant_VDB_demo_report.txt'));
end
