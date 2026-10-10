function [R, bounds] = identify_plant()
%IDENTIFY_PLANT Step P3 of the PI plan:
%   (1) Measure the assist-loop plant T_a -> T_s on PRSM and compare it with the linear design model.
%   (2) Compute resonance characteristics and Bode response of G1c and G0c.
%   (3) Determine the theoretical linear stability boundary under stress (gain x2, delay +1 ms)
%       to establish the rigorous bounds for the PI parameter grid (QuyChuan 6.1).
%
%   Outputs:
%     R       table of step response identification at 30, 60, 100 km/h
%     bounds  struct with max feasible Kp and Ki under stress condition

scriptDir = fileparts(mfilename('fullpath'));
ctlDir    = fileparts(scriptDir);                       % PI/
modelDir  = fileparts(fileparts(ctlDir));               % Model/
addpath(modelDir); setup_paths;

evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'PRSM', 'Plant', 'load_plant.m'), '\', '/')));
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'PRSM', 'Ref', 'load_ref.m'), '\', '/')));
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'PRSM', 'AssistLimit', 'load_assistlimit.m'), '\', '/')));
evalin('base', sprintf('run(''%s'')', strrep(fullfile(modelDir, 'PRSM', 'Actuator', 'load_actuator.m'), '\', '/')));

outDir = result_dir('PI', 'Design');

%% 1. Linear Plant Models & Resonance Analysis
[G1c, G0c, info] = pi_plant_lin();
writePlantInfo(G1c, G0c, info, fullfile(outDir, 'PI_plant_resonance.csv'));
plotBode(G1c, G0c, info, fullfile(outDir, 'PI_plant_bode.png'));

%% 2. PRSM Step Response Identification (Plant + AssistLimit + Actuator)
speeds = [30 60 100];            % km/h
amp = 0.3; tStep = 0.1; tEnd = 0.6;
tm = (0:0.0005:tEnd - tStep)';
ym = step(G1c, tm) * amp;         % linear model step response

files = {fullfile(modelDir, 'PRSM', 'Plant', 'Plant.mdl'), ...
         fullfile(modelDir, 'PRSM', 'AssistLimit', 'AssistLimit.mdl'), ...
         fullfile(modelDir, 'PRSM', 'Actuator', 'Actuator.mdl')};
roots = cell(1, 3);
for i = 1:3
    [~, nm] = fileparts(files{i});
    if bdIsLoaded(nm), close_system(nm, 0); end
    load_system(files{i});
    subs = find_system(nm, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem', nm);
    roots{i} = subs{1};
end

h = 'identify_plant_harness';
if bdIsLoaded(h), close_system(h, 0); end
new_system(h);
add_block(roots{1}, [h '/Plant']);
add_block(roots{2}, [h '/AssistLimit']);
add_block(roots{3}, [h '/Actuator']);

src = {'theta1', 'v', 'mu', 'Ta_cmd'};
for i = 1:numel(src)
    add_block('simulink/Sources/From Workspace', [h '/' src{i}]);
    set_param([h '/' src{i}], 'VariableName', ['idp_' src{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
end
add_line(h, 'theta1/1', portRef([h '/Plant'], 'theta1'));
add_line(h, 'mu/1', portRef([h '/Plant'], 'mu'));

add_block('simulink/Signal Routing/Goto', [h '/Goto_v'], 'GotoTag', 'v', 'TagVisibility', 'local');
add_line(h, 'v/1', 'Goto_v/1');
for k = 1:2
    add_block('simulink/Signal Routing/From', [h '/From_v' num2str(k)], 'GotoTag', 'v');
end
add_line(h, 'From_v1/1', portRef([h '/Plant'], 'v'));
add_line(h, 'From_v2/1', portRef([h '/AssistLimit'], 'v'));

% AssistLimit -> Actuator T_a_max
add_line(h, portRef([h '/AssistLimit'], 'T_a_max'), portRef([h '/Actuator'], 'T_a_max'));

% Command to Actuator
add_line(h, 'Ta_cmd/1', portRef([h '/Actuator'], 'T_a_cmd'));

% Actuator output to Plant
add_line(h, portRef([h '/Actuator'], 'T_a'), portRef([h '/Plant'], 'T_a'));

% Plant Ts to To Workspace
add_block('simulink/Sinks/To Workspace', [h '/Out_Ts'], 'VariableName', 'idp_Ts', 'SaveFormat', 'Timeseries');
add_line(h, portRef([h '/Plant'], 'T_s'), 'Out_Ts/1');

% Terminators for unused outputs
for p = {'T_a_lim'}
    add_block('simulink/Sinks/Terminator', [h '/Term_' p{1}]);
    add_line(h, portRef([h '/Actuator'], p{1}), ['Term_' p{1} '/1']);
end
for p = {'a_y', 'gamma', 'theta2_dot'}
    add_block('simulink/Sinks/Terminator', [h '/Term_' p{1}]);
    add_line(h, portRef([h '/Plant'], p{1}), ['Term_' p{1} '/1']);
end

set_param(h, 'StopTime', num2str(tEnd), 'MaxStep', '5e-4', 'RelTol', '1e-8', 'ReturnWorkspaceOutputs', 'on');

tg = (0:0.0005:tEnd)';
rows = zeros(numel(speeds), 8);
f = figure('Visible', 'off', 'Position', [50 50 900 700]);
for is = 1:numel(speeds)
    assignin('base', 'idp_theta1', [tg zeros(size(tg))]);
    assignin('base', 'idp_v',      [tg speeds(is) / 3.6 * ones(size(tg))]);
    assignin('base', 'idp_mu',     [tg 0.8 * ones(size(tg))]);
    assignin('base', 'idp_Ta_cmd', [tg amp * (tg >= tStep)]);
    in = Simulink.SimulationInput(h);
    in = in.setVariable('T_f', 0);
    so = sim(in);
    ts = so.get('idp_Ts');
    [tu, iu] = unique(ts.Time, 'last');
    ms = -interp1(tu, squeeze(ts.Data(iu)), tm + tStep, 'linear', 'extrap');     % measured change of T_s (sign reversed)
    ms = ms - (-interp1(tu, squeeze(ts.Data(iu)), 0.5 * tStep, 'linear'));       % remove offset before step
    w = tm >= 0.25 & tm <= 0.30;
    dcM = mean(ms(w)) / amp; dcG = mean(ym(w)) / amp;
    [tpM, fM] = ringing(tm, ms); [tpG, fG] = ringing(tm, ym);
    rm = 100 * sqrt(mean((ms - ym).^2)) / max(abs(ym));
    rows(is, :) = [speeds(is), dcM, dcG, tpM, tpG, fM, fG, rm];
    subplot(numel(speeds), 1, is); plot(tm, ms, 'LineWidth', 1.4); hold on; plot(tm, ym, '--', 'LineWidth', 1.4); grid on;
    ylabel(sprintf('-\\Delta T_s [N.m], %d km/h', speeds(is)));
    if is == 1
        legend('PRSM (T_f = 0)', 'linear model G_1', 'Location', 'southeast');
        title(sprintf('Step of %.1f N.m on T_a: measured on PRSM vs linear model', amp));
    end
    if is == numel(speeds), xlabel('time after step [s]'); end
    fprintf('identify_plant: v %3d km/h  dc %.3f (model %.3f)  t_peak %.4f s (model %.4f)  f_ring %.2f Hz (model %.2f)  rmse %.1f %%\n', ...
        speeds(is), dcM, dcG, tpM, tpG, fM, fG, rm);
end
exportgraphics(f, fullfile(outDir, 'PI_plant_identification.png'), 'Resolution', 130); close(f);
R = array2table(rows, 'VariableNames', {'v_kmh', 'dc_measured', 'dc_model', 't_peak_measured_s', 't_peak_model_s', 'f_ring_measured_Hz', 'f_ring_model_Hz', 'rmse_pct'});
writetable(R, fullfile(outDir, 'PI_plant_identification.csv'));

close_system(h, 0);
close_system('Plant', 0); close_system('AssistLimit', 0); close_system('Actuator', 0);
evalin('base', 'clear idp_theta1 idp_v idp_mu idp_Ta_cmd idp_Ts');

%% 3. Stability Boundary Under Stress Condition (Gain x2, Delay +1 ms)
Ts = 0.001;
G1d = c2d(G1c, Ts, 'zoh');
G0d = c2d(G0c, Ts, 'zoh');
z = tf('z', Ts);

Kp_scan = 0.02:0.02:2.0;
Ki_scan = 0.5:0.5:50;
stable_mat = false(numel(Kp_scan), numel(Ki_scan));
for ikp = 1:numel(Kp_scan)
    kp = Kp_scan(ikp);
    for iki = 1:numel(Ki_scan)
        ki = Ki_scan(iki);
        C = tf([kp, -(kp - ki * Ts)], [1 -1], Ts);
        L1_stress = 2 * (1 / z) * C * G1d;
        L0_stress = 2 * (1 / z) * C * G0d;
        if isstable(feedback(L1_stress, 1)) && isstable(feedback(L0_stress, 1))
            stable_mat(ikp, iki) = true;
        end
    end
end

[kp_idx, ki_idx] = find(stable_mat);
bounds.max_Kp = max(Kp_scan(kp_idx));
bounds.max_Ki = max(Ki_scan(ki_idx));

% Find boundary curve: Ki_max for each Kp
boundary_rows = zeros(numel(Kp_scan), 2);
for ikp = 1:numel(Kp_scan)
    valid_ki = Ki_scan(stable_mat(ikp, :));
    if ~isempty(valid_ki)
        boundary_rows(ikp, :) = [Kp_scan(ikp), max(valid_ki)];
    else
        boundary_rows(ikp, :) = [Kp_scan(ikp), 0];
    end
end
T_boundary = array2table(boundary_rows, 'VariableNames', {'Kp', 'max_Ki_under_stress'});
writetable(T_boundary, fullfile(outDir, 'PI_stability_boundary.csv'));

f_bound = figure('Visible', 'off', 'Position', [100 100 800 600]);
plot(boundary_rows(:, 1), boundary_rows(:, 2), 'b-', 'LineWidth', 2); grid on; hold on;
area(boundary_rows(:, 1), boundary_rows(:, 2), 'FaceColor', [0.8 0.9 1.0], 'EdgeColor', 'b', 'LineWidth', 1.5);
xlabel('K_p [N.m / N.m]'); ylabel('K_i [s^{-1}]');
title('Linear Stability Boundary under Stress (Actuator Gain \times 2, Delay +1 ms)');
text(0.3, 5, 'Feasible Region under Stress Gate (5.2)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0.2 0.7]);
xlim([0 2.0]); ylim([0 40]);
exportgraphics(f_bound, fullfile(outDir, 'PI_stability_boundary.png'), 'Resolution', 130); close(f_bound);

fprintf('identify_plant: Linear stability bound under stress: max Kp = %.2f, max Ki = %.1f 1/s\n', bounds.max_Kp, bounds.max_Ki);
end

%% Helper functions
function writePlantInfo(G1c, G0c, info, file)
    w = logspace(0, 3.2, 8000);
    nm = {'dry road'; 'saturated tire'}; kr = [info.kr; 0]; Gs = {G1c, G0c};
    dc = zeros(2, 1); pk = dc; wp = dc; zeta = dc; wn = dc; w180 = dc;
    for q = 1:2
        mag = squeeze(abs(freqresp(Gs{q}, w))); ph = squeeze(angle(freqresp(Gs{q}, w)));
        dc(q) = mag(1); [pk(q), i] = max(mag); wp(q) = w(i);
        zeta(q) = info.C_col / (2 * sqrt((info.K + kr(q)) * info.J_col));
        wn(q) = sqrt((info.K + kr(q)) / info.J_col);
        k = find(unwrap(ph) <= -pi, 1);
        if ~isempty(k), w180(q) = w(k); else, w180(q) = NaN; end
    end
    writetable(table(nm, kr, dc, wn, zeta, pk, 20 * log10(pk), wp, w180, 'VariableNames', {'plant', 'k_r_Nm_per_rad', 'dc_gain', 'omega_n_rad_s', ...
        'zeta_column', 'peak_gain', 'peak_dB', 'peak_rad_s', 'phase_minus180_rad_s'}), file);
end

function plotBode(G1c, G0c, info, file)
    w = logspace(0, 3.2, 600);
    f = figure('Visible', 'off', 'Position', [50 50 1000 750]);
    for k = 1:2
        if k == 1, G = G1c; nm = sprintf('dry road, k_r = %.1f N.m/rad', info.kr); c = [0.165 0.471 0.839];
        else, G = G0c; nm = 'saturated tire, k_r = 0'; c = [0.85 0.33 0.1]; end
        [mag, ph] = bode(G, w);
        subplot(2, 1, 1); semilogx(w, 20 * log10(squeeze(mag)), 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm); hold on;
        subplot(2, 1, 2); semilogx(w, squeeze(ph), 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm); hold on;
    end
    subplot(2, 1, 1); grid on; ylabel('|G| [dB]'); legend('Location', 'southwest'); title('Plant of the assist loop: T_a to T_s, with motor lag (held steering angle)');
    subplot(2, 1, 2); grid on; ylabel('phase [deg]'); xlabel('\omega [rad/s]'); yline(-180, 'k--');
    exportgraphics(f, file, 'Resolution', 130); close(f);
end

function [tp, f] = ringing(t, y)
    d = diff(y);
    imax = find(d(1:end-1) > 0 & d(2:end) <= 0, 1);
    if isempty(imax)
        tp = NaN; f = NaN; return;
    end
    tp = t(imax + 1);
    imin = find(d(imax+1:end-1) < 0 & d(imax+2:end) >= 0, 1) + imax + 1;
    if isempty(imin)
        f = NaN; return;
    end
    f = 1 / (2 * (t(imin + 1) - tp));
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', parts{end}, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
end

