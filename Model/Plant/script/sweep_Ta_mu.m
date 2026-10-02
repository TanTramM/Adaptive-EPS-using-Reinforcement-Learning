function sweep_Ta_mu(modelFileName)
%SWEEP_TA_MU Quet Plant qua 10 muc T_a (tro luc) x 5 muc mu, v CO DINH,
%   T_d CO DINH - khac voi sweep_v_mu.m (T_a=0, khong tro luc), o day mo
%   phong GAN VOI tinh huong EPS thuc te hon: co tro luc T_a hoat dong,
%   khien goc lai/a_y dat duoc LON HON, boc lo ro hon vung phi tuyen cua
%   Pacejka.
%
%   QUAN TRONG - PHAM VI KET QUA: script nay CHI do DO NHAY cua T_r theo
%   mu, tai CUNG 1 cap (T_d,T_a) co dinh - tuc "voi cung 1 muc mo-men lai
%   tong, T_r khac nhau bao nhieu % giua duong bam tot va duong tron".
%   Day KHONG PHAI "% over-assist" theo dung nghia - muon tinh dung
%   over-assist can co 1 ban do tro luc/controller T_a=f(T_d,v) CU THE de
%   so sanh T_r THUC TE voi T_r "dang le phai co" duoi cung 1 chinh sach
%   tro luc do - CHUA CO (chua lam Controller). Ket qua o day chi la CAN
%   CU VAT LY (do nhay cua plant) cho thay hieu ung nay TON TAI va TANG
%   theo muc tro luc, chua phai con so over-assist chinh thuc.
%
%   sweep_Ta_mu() - quet tren Plant_s.mdl (mac dinh).
%   sweep_Ta_mu('Plant') - quet tren ban da tu format tay.
%
%   Dai gia tri:
%     T_a = tu dong do nguong on dinh vong ho (bisection, xem duoi), 10
%           muc trai deu tu 0 den 90% nguong do
%     mu  = {0.2,0.4,0.6,0.8,1.0} (5 muc, mo rong them 1.0 - gioi han vat
%           ly hop ly cho duong nhua kho theo Pacejka/Rajamani)
%     v   = 60 km/h (co dinh, dai dien - doi duoc qua bien v_fix_kmh)
%     T_d = 3 N.m (co dinh, dai dien luc tay con lai cua tai xe khi co
%           tro luc - xem sweep_v_mu.m de doi chieu truong hop T_a=0)
%
%   Cung logic doc T_r nhu sweep_v_mu.m: mo phong den t=Tstop, doc
%   theta/beta/gamma xac lap TU PLANT, roi TINH LAI T_r bang dung cong
%   thuc giai tich PT(1)-(11) (da duoc test_cum2.m xac nhan khop tuyet
%   doi voi khoi Tires that) - KHONG doi giao dien Plant.
%
%   LUU Y: day van la mo phong theo thoi gian (t=Tstop), CHUA phai diem
%   xac lap chinh xac tuyet doi (xem ghi chu trong sweep_v_mu.m va
%   Blueprint_OverAssist_RL.txt muc 2.6, muc 3.8).

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
C_ = p2.C.value; E_ = p2.E.value; n_st = p2.n_st.value; e_p0 = p2.e_p0.value; t_0 = p2.t_0.value;

if bdIsLoaded(modelFileName)
    close_system(modelFileName, 0);
end
load_system(fullfile(plantDir, [modelFileName '.mdl']));
dut = subsystemDuyNhat(modelFileName);

mu_list = [0.2 0.4 0.6 0.8 1.0];       % 5 muc
v_fix_kmh = 60;
v_fix_ms  = v_fix_kmh / 3.6;
T_d_fixed = 3;      % N.m
Tstop     = 8;

% --- Do nguong T_a lon nhat con ON DINH VONG HO (dung mu=0.2 - truong
% hop mo-men can T_r YEU NHAT, tuc de mat on dinh nhat, lam can duoi an
% toan cho moi mu trong mu_list) - bisection giua 1 diem ON DINH va 1
% diem MAT ON DINH da biet tu lan chay truoc (T_a=1 on dinh, T_a=2 mat
% on dinh):
fprintf('Dang do nguong T_a on dinh (bisection, mu=0.2)...\n');
Ta_lo = 1; Ta_hi = 2;
for iter = 1:8
    Ta_mid = (Ta_lo + Ta_hi) / 2;
    if kiemTraOnDinh(dut, Ta_mid, T_d_fixed, v_fix_ms, 0.2, Tstop, harnessNameTemp())
        Ta_lo = Ta_mid;
    else
        Ta_hi = Ta_mid;
    end
end
Ta_max = 0.9 * Ta_lo;   % lui 10% de co bien an toan
fprintf('Nguong on dinh ~%.4g N.m -> dung dai T_a = [0, %.4g] N.m (10 muc)\n', Ta_lo, Ta_max);

Ta_list = linspace(0, Ta_max, 10);     % N.m - 10 muc, trong vung ON DINH

nTa = numel(Ta_list);
nMu = numel(mu_list);
Tr_grid = zeros(nTa, nMu);
ay_grid = zeros(nTa, nMu);
theta_grid = zeros(nTa, nMu);

harnessName = 'sweep_Ta_mu_harness';

fprintf('v = %g km/h, T_d = %g N.m (co dinh)\n', v_fix_kmh, T_d_fixed);
fprintf('%-8s %-6s %-12s %-12s %-12s\n', 'T_a', 'mu', 'theta(rad)', 'T_r(N.m)', 'a_y(m/s^2)');

for iTa = 1:nTa
    Ta_val = Ta_list(iTa);
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
        add_block('simulink/Sources/Step', [harnessName '/Ta_step']);
        set_param([harnessName '/Ta_step'], 'Time', '0.1', 'After', num2str(Ta_val), ...
            'Before', '0', 'Position', [50 160 80 180]);
        add_block('simulink/Sources/Constant', [harnessName '/v_const']);
        set_param([harnessName '/v_const'], 'Value', num2str(v_fix_ms), 'Position', [50 210 80 230]);
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
        add_line(harnessName, 'Ta_step/1', portRef(dutH, 'T_a'), 'autorouting', 'on');
        add_line(harnessName, 'v_const/1', portRef(dutH, 'v'), 'autorouting', 'on');
        add_line(harnessName, 'mu_const/1',portRef(dutH, 'mu'), 'autorouting', 'on');

        set_param(harnessName, 'StopTime', num2str(Tstop));
        simOut = sim(harnessName);

        theta_end = simOut.get('theta_log').Data(end);
        beta_end  = simOut.get('beta_log').Data(end);
        gamma_end = simOut.get('gamma_log').Data(end);
        ay_end    = simOut.get('a_y_log').Data(end);

        T_r_end = analytic_Tr(theta_end, beta_end, gamma_end, v_fix_ms, mu_val, ...
            m_, l_f, l_r, g_, C_alpha_f, C_r, C_, E_, n_st, e_p0, t_0);

        Tr_grid(iTa, imu) = T_r_end;
        ay_grid(iTa, imu) = ay_end;
        theta_grid(iTa, imu) = theta_end;

        fprintf('%-8g %-6.2g %-12.6g %-12.6g %-12.6g\n', Ta_val, mu_val, theta_end, T_r_end, ay_end);

        close_system(harnessName, 0);
    end
end
close_system(modelFileName, 0);

%% ----- Kiem tra: T_r phai TANG DAN theo mu (cung 1 T_a) -----
for iTa = 1:nTa
    row = Tr_grid(iTa, :);
    assert(all(diff(abs(row)) >= -1e-9), ...
        '|T_r| khong tang dan theo mu tai T_a=%g: %s', Ta_list(iTa), mat2str(row));
end
fprintf('\nKIEM TRA PASS: |T_r| tang dan theo mu tai moi T_a\n');

%% ----- Do nhay T_r theo mu (CUNG 1 cap T_d,T_a co dinh) - KHONG PHAI
%% "% over-assist" (chua co ban do tro luc/controller de so sanh voi gia
%% tri "dung ra nen co" - day chi la do chenh lech T_r GIUA 2 MUC MU, khi
%% dau vao mo-men khong doi) -----
fprintf('\n%-8s %-30s\n', 'T_a', '%% chenh T_r giua mu=0.2 va mu=1.0 (cung T_d+T_a)');
for iTa = 1:nTa
    pct = 100 * (abs(Tr_grid(iTa,end)) - abs(Tr_grid(iTa,1))) / abs(Tr_grid(iTa,end));
    fprintf('%-8g %-30.2f\n', Ta_list(iTa), pct);
end

%% ----- Ve % chenh lech T_r theo T_a -----
fig = figure('Visible', 'off');
pctVec = 100 * (abs(Tr_grid(:,end)) - abs(Tr_grid(:,1))) ./ abs(Tr_grid(:,end));
plot(Ta_list, pctVec, '-o', 'LineWidth', 1.5);
xlabel('T_a (N.m)');
ylabel('% chenh lech |T_r| giua mu=1.0 va mu=0.2 (cung T_d+T_a)');
title(sprintf(['Do nhay T_r theo mu, tai CUNG 1 muc mo-men lai tong (v=%g km/h, T_d=%g N.m, t=%gs)\n' ...
    '(KHONG PHAI %% over-assist - chua co ban do tro luc/controller de so sanh)'], ...
    v_fix_kmh, T_d_fixed, Tstop));
grid on;
outPng = fullfile(scriptDir, 'sweep_Ta_mu_pct.png');
saveas(fig, outPng);
close(fig);
fprintf('\nDa luu do thi: %s\n', outPng);

end

%% ===================== Ham tien ich =====================
function T_r = analytic_Tr(theta, beta, gamma, v, mu, m_, l_f, l_r, g_, C_alpha_f, C_r, C_, E_, n_st, e_p0, t_0)
    delta_f = theta / n_st;
    alpha_f = delta_f - beta - l_f*gamma/v;
    F_zf = m_*g_*l_r / (l_f + l_r);
    D = mu * F_zf;
    B = C_alpha_f / (C_ * D);
    F_yf = D * sin(C_ * atan(B*alpha_f - E_*(B*alpha_f - atan(B*alpha_f))));
    e_p = e_p0 - t_0 + max(0, t_0 - sign(alpha_f) * t_0 * C_alpha_f * tan(alpha_f) / (3*mu*F_zf));
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

function name = harnessNameTemp()
    name = 'stability_probe_harness';
end

function ok = kiemTraOnDinh(dut, Ta_test, Td_fixed, v_ms, mu_test, Tstop, harnessName)
% Chay 1 mo phong ngan, tra ve TRUE neu KHONG loi solver, KHONG NaN/Inf,
% va goc truot alpha_f cuoi ky khong vuot qua nguong an toan (1.3 rad ~
% 74 do - con xa singularity tan(90 do) cua PT e_p).
    if bdIsLoaded(harnessName)
        close_system(harnessName, 0);
    end
    try
        new_system(harnessName);
        open_system(harnessName);
        add_block(dut, [harnessName '/DUT']);
        dutH = [harnessName '/DUT'];

        add_block('simulink/Sources/Step', [harnessName '/Td_step']);
        set_param([harnessName '/Td_step'], 'Time', '0.1', 'After', num2str(Td_fixed), 'Before', '0');
        add_block('simulink/Sources/Step', [harnessName '/Ta_step']);
        set_param([harnessName '/Ta_step'], 'Time', '0.1', 'After', num2str(Ta_test), 'Before', '0');
        add_block('simulink/Sources/Constant', [harnessName '/v_const']);
        set_param([harnessName '/v_const'], 'Value', num2str(v_ms));
        add_block('simulink/Sources/Constant', [harnessName '/mu_const']);
        set_param([harnessName '/mu_const'], 'Value', num2str(mu_test));

        outs = {'theta', 'beta', 'gamma'};
        for i = 1:numel(outs)
            blk = [harnessName '/' outs{i} '_out'];
            add_block('simulink/Sinks/To Workspace', blk);
            set_param(blk, 'VariableName', ['probe_' outs{i} '_log']);
            add_line(harnessName, portRef(dutH, outs{i}), [outs{i} '_out/1'], 'autorouting', 'on');
        end
        add_line(harnessName, 'Td_step/1', portRef(dutH, 'T_d'), 'autorouting', 'on');
        add_line(harnessName, 'Ta_step/1', portRef(dutH, 'T_a'), 'autorouting', 'on');
        add_line(harnessName, 'v_const/1', portRef(dutH, 'v'), 'autorouting', 'on');
        add_line(harnessName, 'mu_const/1',portRef(dutH, 'mu'), 'autorouting', 'on');

        set_param(harnessName, 'StopTime', num2str(Tstop));
        simOut = sim(harnessName);

        theta_end = simOut.get('probe_theta_log').Data(end);
        beta_end  = simOut.get('probe_beta_log').Data(end);
        gamma_end = simOut.get('probe_gamma_log').Data(end);

        n_st = evalin('base', 'n_st');
        l_f  = evalin('base', 'l_f');
        delta_f = theta_end / n_st;
        alpha_f = delta_f - beta_end - l_f*gamma_end/v_ms;

        ok = isfinite(theta_end) && isfinite(beta_end) && isfinite(gamma_end) && abs(alpha_f) < 1.3;
    catch
        ok = false;
    end
    if bdIsLoaded(harnessName)
        close_system(harnessName, 0);
    end
end
