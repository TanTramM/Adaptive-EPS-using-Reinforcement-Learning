%% build_cum3.m
% Use the Simulink API to build Cluster 3 (2-DOF vehicle body dynamics) as
% its own subsystem, saved as Bike2DOF.mdl RIGHT INSIDE the Plant/
% folder. Matches Documents/Cum3_2DOF.txt,
% Eq.(4),(5),(3):
%
%   Eq.(4) beta_dot  = (F_yf+F_yr)/(m*v) - gamma
%   Eq.(5) gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz
%   Eq.(3) a_y       = (F_yf+F_yr)/m
%
% x3=beta, x4=gamma are the states; a_y is a named OUTPUT quantity (not a
% state) used later to look up T_d,ref(v,a_y) - Blueprint section 1.3.
%
% NOTE ON F_yf+F_yr: Cum3_2DOF.txt does not give this sum its own symbol,
% but it is used in BOTH Eq.(4) (beta_dot) and Eq.(3) (a_y) - exactly the
% same situation as D/B in Cum2 (used by multiple downstream consumers).
% Following that pattern, it is factored into its own "Cal Fsum" subsystem
% so it is computed once, not duplicated.
%
% HIERARCHY (see Claude.md, "Quy tac dung model Simulink"):
%
%   Bike2DOF
%     In : F_yf, F_yr, v          Out: beta, gamma, a_y
%     |
%     +-- Cal Fsum   In : F_yf, F_yr        Out: F_sum (=F_yf+F_yr)
%     |              (hub - feeds both Cal a_y and Beta)
%     +-- Cal a_y    In : F_sum             Out: a_y
%     +-- Gamma      In : F_yf, F_yr        Out: gamma   (Eq.(5),
%     |                                     independent of beta)
%     +-- Beta       In : F_sum, v, gamma   Out: beta    (Eq.(4), needs
%                                                         gamma from
%                                                         Gamma - one-way
%                                                         coupling)
%
% F_yf, F_yr, F_sum, gamma each reach 2 destinations -> routed via
% Goto/From. v reaches only Beta (1 destination) -> wired directly.
%
% Parameters (m, l_f, l_r, Iz) are read from the base workspace - m, l_f,
% l_r are the SAME variables already loaded for Cluster 2 (not redefined
% here). Run Model/load_plant.m BEFORE building.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_plant.m')
%   >> build_cum3            % or build_cum3(true) to overwrite


function modelName = build_cum3(overwrite)
if nargin < 1, overwrite = false; end   % true: replace an existing Bike2DOF.mdl; false: save as Bike2DOF_1, Bike2DOF_2, ... instead

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelDir  = fileparts(fileparts(plantDir));     % Model/
addpath(fullfile(modelDir, 'common'));
modelName = pick_model_name(plantDir, 'Bike2DOF', overwrite);
modelPath = fullfile(plantDir, [modelName '.mdl']);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: Bike2DOF ========================
sub = [modelName '/Bike2DOF'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'F_yf', 1, 40,  60);
addInport(sub, 'F_yr', 2, 40, 130);
addInport(sub, 'v',    3, 40, 560);

addOutport(sub, 'a_y',   1, 900,  60);
addOutport(sub, 'gamma', 2, 900, 260);
addOutport(sub, 'beta',  3, 900, 480);

%% ===================== Cal Fsum - hub (F_yf+F_yr) =======================
% Top row: F_yf, F_yr feed straight in; output continues right into Cal a_y
% on the same row, and branches down to Beta via Goto/From.
fs = [sub '/Cal Fsum'];
createSubsystem(fs);
moveBlock(fs, 260, 60);
buildCalFsum(fs);

%% ===================== Cal a_y - Eq.(3), continues the top row =========
ay = [sub '/Cal a_y'];
createSubsystem(ay);
moveBlock(ay, 460, 60);
buildCalAy(ay);

%% ===================== Gamma - Eq.(5), own row (independent) ===========
ga = [sub '/Gamma'];
createSubsystem(ga);
moveBlock(ga, 260, 260);
buildGamma(ga);

%% ===================== Beta - Eq.(4), bottom row (needs gamma) =========
be = [sub '/Beta'];
createSubsystem(be);
moveBlock(be, 260, 480);
buildBeta(be);

%% ===================== Cluster-level wiring =============================
% F_yf, F_yr each feed 2 destinations (Cal Fsum and Gamma) -> Goto/From
g_fyf = addGoto(sub, 'F_yf', 140, 60);
add_line(sub, 'F_yf/1', [g_fyf '/1'], 'autorouting', 'on');
f_fyf_fs = addFrom(sub, 'F_yf', 200, 60);
add_line(sub, [f_fyf_fs '/1'], 'Cal Fsum/1', 'autorouting', 'on');
f_fyf_ga = addFrom(sub, 'F_yf', 200, 280);
add_line(sub, [f_fyf_ga '/1'], 'Gamma/1', 'autorouting', 'on');

g_fyr = addGoto(sub, 'F_yr', 140, 130);
add_line(sub, 'F_yr/1', [g_fyr '/1'], 'autorouting', 'on');
f_fyr_fs = addFrom(sub, 'F_yr', 200, 100);
add_line(sub, [f_fyr_fs '/1'], 'Cal Fsum/2', 'autorouting', 'on');
f_fyr_ga = addFrom(sub, 'F_yr', 200, 340);
add_line(sub, [f_fyr_ga '/1'], 'Gamma/2', 'autorouting', 'on');

% F_sum (Cal Fsum output) -> Cal a_y directly (adjacent, same row) AND
% down to Beta via Goto/From
add_line(sub, 'Cal Fsum/1', 'Cal a_y/1', 'autorouting', 'on');
g_fsum = addGoto(sub, 'F_sum', 420, 60);
add_line(sub, 'Cal Fsum/1', [g_fsum '/1'], 'autorouting', 'on');
f_fsum_be = addFrom(sub, 'F_sum', 200, 500);
add_line(sub, [f_fsum_be '/1'], 'Beta/1', 'autorouting', 'on');

% a_y: only the cluster output -> wire directly
add_line(sub, 'Cal a_y/1', 'a_y/1', 'autorouting', 'on');

% gamma (Gamma output) -> Goto ; From into Beta and the cluster output
g_gamma = addGoto(sub, 'gamma', 420, 260);
add_line(sub, 'Gamma/1', [g_gamma '/1'], 'autorouting', 'on');
f_gamma_be  = addFrom(sub, 'gamma', 200, 580);
add_line(sub, [f_gamma_be '/1'], 'Beta/3', 'autorouting', 'on');
f_gamma_out = addFrom(sub, 'gamma', 700, 260);
add_line(sub, [f_gamma_out '/1'], 'gamma/1', 'autorouting', 'on');

% v: only Beta needs it -> wire directly
add_line(sub, 'v/1', 'Beta/2', 'autorouting', 'on');

% beta: only the cluster output -> wire directly
add_line(sub, 'Beta/1', 'beta/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

end

%% ===================== Hub: F_sum = F_yf + F_yr ==========================
function buildCalFsum(fs)
    addInport(fs, 'F_yf', 1, 40, 60);
    addInport(fs, 'F_yr', 2, 40, 140);

    addOutport(fs, 'F_sum', 1, 260, 90);

    addSum(fs, 'Sum_Fsum', '++', 160, 90);

    add_line(fs, 'F_yf/1', 'Sum_Fsum/1', 'autorouting', 'on');
    add_line(fs, 'F_yr/1', 'Sum_Fsum/2', 'autorouting', 'on');
    add_line(fs, 'Sum_Fsum/1', 'F_sum/1', 'autorouting', 'on');
end

%% ===================== Eq.(3): lateral acceleration output ==============
function buildCalAy(ay)
% a_y = F_sum/m
    addInport(ay, 'F_sum', 1, 40, 60);
    addOutport(ay, 'a_y', 1, 260, 60);

    hm = addConstant(ay, 'm', 160, 140);   % right below Div_ay
    addProduct(ay, 'Div_ay', '*/', 200, 60);

    add_line(ay, 'F_sum/1', 'Div_ay/1', 'autorouting', 'on');
    add_line(ay, [hm '/1'], 'Div_ay/2', 'autorouting', 'on');
    add_line(ay, 'Div_ay/1', 'a_y/1', 'autorouting', 'on');
end

%% ===================== Eq.(5): Yaw rate (independent of beta) ===========
function buildGamma(ga)
% gamma_dot = (l_f*F_yf - l_r*F_yr)/Iz ; gamma = integral(gamma_dot)
% Main line: Sum_moment -> Div_gammadot -> Int_gamma -> gamma. l_f*F_yf and
% l_r*F_yr are the two terms feeding Sum_moment, positioned symmetrically
% above/below it (their own constants right next to each).
    addInport(ga, 'F_yf', 1, 40,  60);
    addInport(ga, 'F_yr', 2, 40, 220);

    addOutport(ga, 'gamma', 1, 620, 100);

    hlf = addConstant(ga, 'l_f', 160, 140);   % near Prod_lfFyf
    addProduct(ga, 'Prod_lfFyf', '**', 200,  60);   % l_f*F_yf

    hlr = addConstant(ga, 'l_r', 160, 300);   % near Prod_lrFyr
    addProduct(ga, 'Prod_lrFyr', '**', 200, 220);   % l_r*F_yr

    addSum(ga, 'Sum_moment', '+-', 300, 100);       % l_f*F_yf - l_r*F_yr

    hIz = addConstant(ga, 'Iz', 380, 180);   % below Div_gammadot
    addProduct(ga, 'Div_gammadot', '*/', 420, 100);

    addIntegrator(ga, 'Int_gamma', 500, 100);

    add_line(ga, [hlf '/1'], 'Prod_lfFyf/1', 'autorouting', 'on');
    add_line(ga, 'F_yf/1',   'Prod_lfFyf/2', 'autorouting', 'on');
    add_line(ga, [hlr '/1'], 'Prod_lrFyr/1', 'autorouting', 'on');
    add_line(ga, 'F_yr/1',   'Prod_lrFyr/2', 'autorouting', 'on');

    add_line(ga, 'Prod_lfFyf/1', 'Sum_moment/1', 'autorouting', 'on');
    add_line(ga, 'Prod_lrFyr/1', 'Sum_moment/2', 'autorouting', 'on');

    add_line(ga, 'Sum_moment/1', 'Div_gammadot/1', 'autorouting', 'on');
    add_line(ga, [hIz '/1'],     'Div_gammadot/2', 'autorouting', 'on');
    add_line(ga, 'Div_gammadot/1', 'Int_gamma/1', 'autorouting', 'on');
    add_line(ga, 'Int_gamma/1', 'gamma/1', 'autorouting', 'on');
end

%% ===================== Eq.(4): side-slip angle (needs gamma) ============
function buildBeta(be)
% beta_dot = F_sum/(m*v) - gamma ; beta = integral(beta_dot)
% Main line: Div_Fsum_mv -> Sum_betadot -> Int_beta -> beta. m*v is a
% secondary product feeding the denominator, positioned below the main
% line right next to Div_Fsum_mv.
    addInport(be, 'F_sum', 1, 40,  60);
    addInport(be, 'v',     2, 40, 200);
    addInport(be, 'gamma', 3, 40, 320);

    addOutport(be, 'beta', 1, 620, 100);

    hm = addConstant(be, 'm', 160, 240);   % near Prod_mv
    addProduct(be, 'Prod_mv', '**', 200, 220);   % m*v

    addProduct(be, 'Div_Fsum_mv', '*/', 280,  60);   % F_sum/(m*v)
    addSum    (be, 'Sum_betadot', '+-', 420,  90);   % (.) - gamma

    addIntegrator(be, 'Int_beta', 500, 90);

    add_line(be, [hm '/1'], 'Prod_mv/1', 'autorouting', 'on');
    add_line(be, 'v/1',     'Prod_mv/2', 'autorouting', 'on');

    add_line(be, 'F_sum/1',    'Div_Fsum_mv/1', 'autorouting', 'on');
    add_line(be, 'Prod_mv/1',  'Div_Fsum_mv/2', 'autorouting', 'on');
    add_line(be, 'Div_Fsum_mv/1', 'Sum_betadot/1', 'autorouting', 'on');
    add_line(be, 'gamma/1',       'Sum_betadot/2', 'autorouting', 'on');
    add_line(be, 'Sum_betadot/1', 'Int_beta/1', 'autorouting', 'on');
    add_line(be, 'Int_beta/1', 'beta/1', 'autorouting', 'on');
end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
% Move a block to (x,y), KEEPING its default size.
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function createSubsystem(path)
% Create an empty Subsystem (removes the default In1->Out1 pair).
    add_block('simulink/Ports & Subsystems/Subsystem', path);
    delete_line(path, 'In1/1', 'Out1/1');
    delete_block([path '/In1']);
    delete_block([path '/Out1']);
end

function addInport(sys, name, port, x, y)
% Ports keep MEANINGFUL names - they ARE the physical variable name and are
% looked up by name in test_*.m.
    full = [sys '/' name];
    add_block('simulink/Sources/In1', full);
    set_param(full, 'Port', num2str(port));
    moveBlock(full, x, y);
end

function addOutport(sys, name, port, x, y)
    full = [sys '/' name];
    add_block('simulink/Sinks/Out1', full);
    set_param(full, 'Port', num2str(port));
    moveBlock(full, x, y);
end

function nm = addConstant(sys, baseWorkspaceVar, x, y)
% Constant block, DEFAULT name (Constant, Constant1, ...); Value points
% STRAIGHT to a base-workspace variable name (or a literal such as '3').
    h = add_block('simulink/Sources/Constant', [sys '/Constant'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'Value', baseWorkspaceVar);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addGoto(sys, tag, x, y)
% Goto block, DEFAULT name; LOCAL scope only. tag is the plain variable
% name, no suffix.
    h = add_block('simulink/Signal Routing/Goto', [sys '/Goto'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag, 'TagVisibility', 'local');
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function nm = addFrom(sys, tag, x, y)
% From block, DEFAULT name.
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, inputsStr, x, y)
% Prod_<result or operands>, Div_<result> (Inputs='*/').
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addTrigFcn(sys, name, op, x, y)
% Trig_<function>_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Trigonometric Function', full);
    set_param(full, 'Operator', op);
    moveBlock(full, x, y);
end

function addSignBlock(sys, name, x, y)
% Sign_<argument>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Sign', full);
    moveBlock(full, x, y);
end

function addIntegrator(sys, name, x, y)
% Int_<state variable>
    full = [sys '/' name];
    add_block('simulink/Continuous/Integrator', full);
    moveBlock(full, x, y);
end
