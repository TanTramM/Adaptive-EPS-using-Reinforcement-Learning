%% build_plant.m
% Ghep 3 khoi da co (SteeringColumn.mdl, Tires.mdl, Bike2DOF.mdl - ban da
% TU FORMAT TAY, nam ngay trong thu muc Plant/) thanh 1 model Plant_s.mdl
% khep vong, luu NGAY TRONG Plant/ - hau to "_s" de phan biet voi Plant.mdl
% da tu format tay (neu co). Dung Simulink API (add_block copy + add_line),
% KHONG sua truc tiep 3 file nguon.
%
% Cac cong duoc noi theo TEN (khong theo so thu tu cong), tu dong do bang
% find_system - de kich ban nay hoat dong dung bat ke 3 file nguon sap xep
% thu tu cong the nao, chi can dung TEN cong (T_d, T_a, T_r, theta, beta,
% gamma, v, mu, F_yf, F_yr, a_y).
%
% So do noi day (khop Documents/HeThongPlant_TongHop.txt):
%   T_d, T_a (Inport ngoai)          -> SteeringColumn (T_d, T_a)
%   SteeringColumn.theta             -> Tires.theta
%   SteeringColumn.theta, theta_dot  -> Outport (x1, x2)
%   v, mu (Inport ngoai)             -> Tires (v, mu) ; v -> Bike2DOF.v
%   Tires.F_yf, F_yr                 -> Bike2DOF (F_yf, F_yr)
%   Tires.T_r                        -> SteeringColumn.T_r
%   Bike2DOF.beta, gamma             -> Tires (beta, gamma) ; -> Outport (x3, x4)
%   Bike2DOF.a_y                     -> Outport (dau ra phu, khong phai trang thai)
%
% Cach dung (chay tu thu muc nay, Plant/script/):
%   >> build_plant
%   (model Plant_s.mdl duoc tao trong thu muc Plant/)

modelName = 'Plant_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelPath = fullfile(plantDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

srcFiles = struct('steer', 'SteeringColumn', 'tires', 'Tires', 'bike', 'Bike2DOF');
fn = fieldnames(srcFiles);
for i = 1:numel(fn)
    nm = srcFiles.(fn{i});
    if bdIsLoaded(nm)
        close_system(nm, 0);
    end
    load_system(fullfile(plantDir, [nm '.mdl']));
end

new_system(modelName);
open_system(modelName);

%% ----- Subsystem goc "Plant" -----
sub = [modelName '/Plant'];
add_block('simulink/Ports & Subsystems/Subsystem', sub);
delete_line(sub, 'In1/1', 'Out1/1');
delete_block([sub '/In1']);
delete_block([sub '/Out1']);
dichKhoi(sub, 50, 50);

%% ----- Copy 3 subsystem nguon (tu dong tim, khong gia dinh ten) -----
steerSrc = subsystemDuyNhat(srcFiles.steer);
tiresSrc = subsystemDuyNhat(srcFiles.tires);
bikeSrc  = subsystemDuyNhat(srcFiles.bike);

add_block(steerSrc, [sub '/SteeringColumn']);
dichKhoi([sub '/SteeringColumn'], 250, 40);
add_block(tiresSrc, [sub '/Tires']);
dichKhoi([sub '/Tires'], 500, 40);
add_block(bikeSrc, [sub '/Bike2DOF']);
dichKhoi([sub '/Bike2DOF'], 750, 200);

steer = [sub '/SteeringColumn'];
tires = [sub '/Tires'];
bike  = [sub '/Bike2DOF'];

%% ----- Inport/Outport cap he thong -----
in_Td = addIn(sub, 'T_d', 1, 40, 40);
in_Ta = addIn(sub, 'T_a', 2, 40, 100);
in_v  = addIn(sub, 'v',   3, 40, 400);
in_mu = addIn(sub, 'mu',  4, 40, 460);

out_theta     = addOut(sub, 'theta',     1, 1100, 40);
out_thetadot  = addOut(sub, 'theta_dot', 2, 1100, 100);
out_beta      = addOut(sub, 'beta',      3, 1100, 260);
out_gamma     = addOut(sub, 'gamma',     4, 1100, 320);
out_ay        = addOut(sub, 'a_y',       5, 1100, 380);

%% ----- Noi day theo TEN cong (tu dong do port number) -----
add_line(sub, [in_Td '/1'], portRef(steer, 'T_d'), 'autorouting', 'on');
add_line(sub, [in_Ta '/1'], portRef(steer, 'T_a'), 'autorouting', 'on');

add_line(sub, portRef(steer, 'theta'), portRef(tires, 'theta'), 'autorouting', 'on');
add_line(sub, portRef(steer, 'theta'), [out_theta '/1'], 'autorouting', 'on');
add_line(sub, portRef(steer, 'theta_dot'), [out_thetadot '/1'], 'autorouting', 'on');

add_line(sub, [in_v '/1'],  portRef(tires, 'v'), 'autorouting', 'on');
add_line(sub, [in_mu '/1'], portRef(tires, 'mu'), 'autorouting', 'on');
add_line(sub, [in_v '/1'],  portRef(bike, 'v'), 'autorouting', 'on');

add_line(sub, portRef(tires, 'F_yf'), portRef(bike, 'F_yf'), 'autorouting', 'on');
add_line(sub, portRef(tires, 'F_yr'), portRef(bike, 'F_yr'), 'autorouting', 'on');
add_line(sub, portRef(tires, 'T_r'),  portRef(steer, 'T_r'), 'autorouting', 'on');

add_line(sub, portRef(bike, 'beta'),  portRef(tires, 'beta'), 'autorouting', 'on');
add_line(sub, portRef(bike, 'gamma'), portRef(tires, 'gamma'), 'autorouting', 'on');
add_line(sub, portRef(bike, 'beta'),  [out_beta '/1'], 'autorouting', 'on');
add_line(sub, portRef(bike, 'gamma'), [out_gamma '/1'], 'autorouting', 'on');
add_line(sub, portRef(bike, 'a_y'),   [out_ay '/1'], 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);
for i = 1:numel(fn)
    close_system(srcFiles.(fn{i}), 0);
end

fprintf('Da tao: %s\n', modelPath);

%% ===================== Ham tien ich =====================
function dichKhoi(blockPath, x, y)
    pos = get_param(blockPath, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blockPath, 'Position', [x, y, x + w, y + h]);
end

function h = addIn(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sources/In1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
    h = name;
end

function h = addOut(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sinks/Out1', full);
    set_param(full, 'Port', num2str(port));
    dichKhoi(full, x, y);
    h = name;
end

function subPath = subsystemDuyNhat(modelFileName)
% Tra ve duong dan subsystem CAP GOC DUY NHAT trong 1 model .mdl da load.
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s phai co dung 1 subsystem cap goc, tim thay %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% Tim cong (Inport hoac Outport) ten portName ben trong subsystem subPath,
% tra ve chuoi "<TenKhoiTrongHeThongCha>/<SoCong>" de dung truc tiep trong
% add_line. subPath o day la duong dan block CHA (vd sub/SteeringColumn),
% blockNameInParent la ten cua no trong he thong cha (phan sau dau '/'
% cuoi cung).
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
