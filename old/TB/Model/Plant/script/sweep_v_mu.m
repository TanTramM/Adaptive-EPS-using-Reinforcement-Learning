function sweep_v_mu(modelFileName)
%SWEEP_V_MU Quet Plant qua nhieu (v, mu), kiem tra hien tuong over-assist:
%   T_r (mo-men can mat duong) phai GIAM khi mu GIAM, cung 1 dieu kien lai
%   (T_d, v co dinh) - day la co che vat ly cot loi can co truoc khi thiet
%   ke bo dieu khien bu over-assist.
%
%   sweep_v_mu() - quet tren Plant_s.mdl (mac dinh).
%   sweep_v_mu('Plant') - quet tren ban da tu format tay.
%
%   Voi moi (v, mu): cap T_d CO DINH (buoc nhay), T_a=0, mo phong den xac
%   lap (steady state), doc theta/beta/gamma xac lap tu Plant, roi tinh
%   LAI T_r bang dung cong thuc giai tich PT(1)-(11) (Cum2_Pacejka.txt) -
%   khong doi Plant (khong them Outport T_r) de khong anh huong giao dien
%   da kiem chung o test_plant.m. Cong thuc nay da duoc test_cum2.m xac
%   nhan khop tuyet doi voi khoi Tires that.
%
%   Dai gia tri:
%     v  = {20,40,60,80,100} km/h  (khop luoi Bang 4, [7])
%     mu = {0.2,0.4,0.6,0.8}       (dai tham khao cua [6] Multi-Map EPS)
%
%   Ket qua: in bang T_r, a_y, T_d_ref(v,a_y) ([7]) cho tung (v,mu); ve 1
%   do thi T_r(t) chong len nhau qua 4 muc mu (v co dinh) luu thanh PNG.

if nargin < 1
    modelFileName = 'Plant_s';
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(plantDir);                % Model/

raw = jsondecode(fileread(fullfile(modelDir, 'data', 'params.json')));
p2 = raw.cum2;
m_ = p2.m.value; l_f = p2.l_f.value; l_r = p2.l_r.value; g_ = p2.g.value;
C_alpha_f = p2.C_alpha_f.value; C_r = p2.C_r.value;
C_ = p2.C.value; E_ = p2.E.value; n_st = p2.n_st.value; e_p0 = p2.e_p0.value;

rawRef = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
v_bp_ms   = rawRef.v_breakpoints_kmh(:)' / 3.6;
ay_bp_ms2 = rawRef.ay_breakpoints_g(:)' * 9.81;
tableData = rawRef.table_Nm;   % hang=a_y(4), cot=v(5)

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));
dut = subsystemDuyNhat(modelFileName);

v_list_kmh = [20 40 60 80 100];
mu_list    = [0.2 0.4 0.6 0.8];
T_d_fixed  = 3;    % N.m - dieu kien lai co dinh, giu nguyen qua moi (v,mu)
Tstop      = 8;    % du dai de x2 (theta_dot) tien ve gan 0 (xac lap)

nV = numel(v_list_kmh);
nMu = numel(mu_list);
Tr_grid = zeros(nV, nMu);
ay_grid = zeros(nV, nMu);
Tdref_grid = zeros(nV, nMu);

harnessName = 'sweep_plant_harness';

fprintf('%-10s %-6s %-12s %-12s %-12s\n', 'v(km/h)', 'mu', 'T_r(N.m)', 'a_y(m/s^2)', 'T_d,ref(N.m)');

for iv = 1:nV
    v_kmh = v_list_kmh(iv);
    v_ms  = v_kmh / 3.6;
    for imu = 1:nMu
        mu_val = mu_list(imu);

        if bdIsLoaded(harnessName)
            close_system(harnessName, 0);
        end
        new_system(harnessName);
        open_system(harnessName);

        add_block(dut, [harnessName '/DUT']);
        set_param([harnessName '/DUT'], 'Position', [250 100 450 400]);
        dutH = [harnessName '/DUT'];

        add_block('simulink/Sources/Step', [harnessName '/Td_step']);
        set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', num2str(T_d_fixed), ...
            'Before', '0', 'Position', [50 110 80 130]);
        add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
        set_param([harnessName '/Ta_zero'], 'Value', '0', 'Position', [50 160 80 180]);
        add_block('simulink/Sources/Constant', [harnessName '/v_const']);
        set_param([harnessName '/v_const'], 'Value', num2str(v_ms), 'Position', [50 210 80 230]);
        add_block('simulink/Sources/Constant', [harnessName '/mu_const']);
        set_param([harnessName '/mu_const'], 'Value', num2str(mu_val), 'Position', [50 260 80 280]);

        outs = {'theta', 'beta', 'gamma', 'a_y'};
        for i = 1:numel(outs)
            blk = [harnessName '/' outs{i} '_out'];
            add_block('simulink/Sinks/To Workspace', blk);
            set_param(blk, 'VariableName', [outs{i} '_log'], 'Position', [550 (100+60*i) 620 (120+60*i)]);
            add_line(harnessName, portRef(dutH, outs{i}), [outs{i} '_out/1'], 'autorouting', 'on');
        end
        add_line(harnessName, 'Td_step/1', portRef(dutH, 'T_d'), 'autorouting', 'on');
        add_line(harnessName, 'Ta_zero/1', portRef(dutH, 'T_a'), 'autorouting', 'on');
        add_line(harnessName, 'v_const/1', portRef(dutH, 'v'), 'autorouting', 'on');
        add_line(harnessName, 'mu_const/1',portRef(dutH, 'mu'), 'autorouting', 'on');

        set_param(harnessName, 'StopTime', num2str(Tstop));
        simOut = sim(harnessName);

        theta_end = simOut.get('theta_log').Data(end);
        beta_end  = simOut.get('beta_log').Data(end);
        gamma_end = simOut.get('gamma_log').Data(end);
        ay_end    = simOut.get('a_y_log').Data(end);

        T_r_end = analytic_Tr(theta_end, beta_end, gamma_end, v_ms, mu_val, ...
            m_, l_f, l_r, g_, C_alpha_f, C_r, C_, E_, n_st, e_p0);

        v_clip  = min(max(v_ms, min(v_bp_ms)), max(v_bp_ms));
        ay_clip = min(max(abs(ay_end), min(ay_bp_ms2)), max(ay_bp_ms2));
        Tdref_end = sign(ay_end) * interp2(ay_bp_ms2, v_bp_ms, tableData', ay_clip, v_clip, 'linear');

        Tr_grid(iv, imu) = T_r_end;
        ay_grid(iv, imu) = ay_end;
        Tdref_grid(iv, imu) = Tdref_end;

        fprintf('%-10g %-6.2g %-12.6g %-12.6g %-12.6g\n', v_kmh, mu_val, T_r_end, ay_end, Tdref_end);

        close_system(harnessName, 0);
    end
end
close_system(modelFileName, 0);

%% ----- Kiem tra: T_r phai TANG DAN theo mu (cung 1 v) -----
for iv = 1:nV
    row = Tr_grid(iv, :);
    assert(all(diff(abs(row)) >= -1e-9), ...
        '|T_r| khong tang dan theo mu tai v=%g km/h: %s', v_list_kmh(iv), mat2str(row));
end
fprintf('\nKIEM TRA PASS: |T_r| tang dan theo mu tai moi v - dung co che vat ly ky vong\n');
fprintf('(mu giam -> T_r giam -> neu bo dieu khien van gia dinh mu danh dinh thi se "tro luc thua").\n');

%% ----- Ve T_r(t) chong 4 muc mu tai 1 v dai dien -----
v_plot_kmh = 60;
v_plot_ms  = v_plot_kmh / 3.6;
fig = figure('Visible', 'off');
hold on;
colors = lines(nMu);
for imu = 1:nMu
    mu_val = mu_list(imu);
    if bdIsLoaded(harnessName)
        close_system(harnessName, 0);
    end
    load_system(fullfile(plantDir, [modelFileName '.mdl']));
    new_system(harnessName);
    open_system(harnessName);
    add_block(dut, [harnessName '/DUT']);
    dutH = [harnessName '/DUT'];
    add_block('simulink/Sources/Step', [harnessName '/Td_step']);
    set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', num2str(T_d_fixed), 'Before', '0');
    add_block('simulink/Sources/Constant', [harnessName '/Ta_zero']);
    set_param([harnessName '/Ta_zero'], 'Value', '0');
    add_block('simulink/Sources/Constant', [harnessName '/v_const']);
    set_param([harnessName '/v_const'], 'Value', num2str(v_plot_ms));
    add_block('simulink/Sources/Constant', [harnessName '/mu_const']);
    set_param([harnessName '/mu_const'], 'Value', num2str(mu_val));
    outs = {'theta', 'beta', 'gamma'};
    for i = 1:numel(outs)
        blk = [harnessName '/' outs{i} '_out'];
        add_block('simulink/Sinks/To Workspace', blk);
        set_param(blk, 'VariableName', [outs{i} '_log']);
        add_line(harnessName, portRef(dutH, outs{i}), [outs{i} '_out/1'], 'autorouting', 'on');
    end
    add_line(harnessName, 'Td_step/1', portRef(dutH, 'T_d'), 'autorouting', 'on');
    add_line(harnessName, 'Ta_zero/1', portRef(dutH, 'T_a'), 'autorouting', 'on');
    add_line(harnessName, 'v_const/1', portRef(dutH, 'v'), 'autorouting', 'on');
    add_line(harnessName, 'mu_const/1',portRef(dutH, 'mu'), 'autorouting', 'on');
    set_param(harnessName, 'StopTime', num2str(Tstop));
    simOut = sim(harnessName);

    tVec = simOut.get('theta_log').Time;
    thetaVec = simOut.get('theta_log').Data;
    betaVec  = simOut.get('beta_log').Data;
    gammaVec = simOut.get('gamma_log').Data;
    TrVec = arrayfun(@(k) analytic_Tr(thetaVec(k), betaVec(k), gammaVec(k), v_plot_ms, mu_val, ...
        m_, l_f, l_r, g_, C_alpha_f, C_r, C_, E_, n_st, e_p0), 1:numel(tVec));

    plot(tVec, TrVec, 'Color', colors(imu,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('\\mu=%.1f', mu_val));

    close_system(harnessName, 0);
    close_system(modelFileName, 0);
end
xlabel('t (s)'); ylabel('T_r (N.m)');
title(sprintf('T_r(t) theo mu tai v=%g km/h, T_d buoc nhay %g N.m', v_plot_kmh, T_d_fixed));
legend('show', 'Location', 'best');
grid on;
outPng = fullfile(scriptDir, 'sweep_Tr_vs_mu.png');
saveas(fig, outPng);
close(fig);
fprintf('Da luu do thi: %s\n', outPng);

end

%% ===================== Ham tien ich =====================
function T_r = analytic_Tr(theta, beta, gamma, v, mu, m_, l_f, l_r, g_, C_alpha_f, C_r, C_, E_, n_st, e_p0)
    delta_f = theta / n_st;
    alpha_f = delta_f - beta - l_f*gamma/v;
    F_zf = m_*g_*l_r / (l_f + l_r);
    D = mu * F_zf;
    B = C_alpha_f / (C_ * D);
    F_yf = D * sin(C_ * atan(B*alpha_f - E_*(B*alpha_f - atan(B*alpha_f))));
    e_p = e_p0 - sign(alpha_f) * e_p0 * C_alpha_f * tan(alpha_f) / (3*mu*F_zf);
    K_tr = e_p / n_st;
    T_r = K_tr * F_yf;
end

function subPath = subsystemDuyNhat(modelFileName)
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s phai co dung 1 subsystem cap goc, tim thay %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(ports)
        if strcmp(get_param(ports{k}, 'Name'), portName)
            ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
            return;
        end
    end
    error('Khong tim thay cong ten "%s" trong %s', portName, subPath);
end
