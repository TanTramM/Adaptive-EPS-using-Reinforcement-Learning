%% build_cum2.m
% Use the Simulink API to build Cluster 2 (nonlinear Pacejka tire
% interaction) as its own subsystem, saved as Tires_s.mdl RIGHT INSIDE the
% Plant/ folder - the "_s" suffix distinguishes it from the hand-formatted
% version (Tires.mdl, same folder). Matches Documents/Cum2_Pacejka.txt,
% Eq.(1)-(11):
%
%   Section 1 - Tire slip angles:
%     delta_f = theta2/n_st
%     alpha_f = delta_f - beta - l_f*gamma/v
%     alpha_r = -beta + l_r*gamma/v
%   Section 2 - Static load + tire lateral forces:
%     F_zf = m*g*l_r/(l_f+l_r)   (precomputed once - see load_derived.m)
%     D    = mu*F_zf
%     B    = C_alpha_f/(C*D)
%     F_yf = D*sin(C*atan(u - E*(u - atan(u))))  with  u = B*alpha_f
%     F_yr = C_r*alpha_r
%   Section 3 - Road reaction (aligning) torque:
%     e_p  = e_p0 - sgn(alpha_f)*e_p0*C_alpha_f*tan(alpha_f)/(3*mu*F_zf)
%     K_tr = e_p/n_st
%     T_r  = K_tr*F_yf
%
% INPUT ANGLE: the root input is theta2 (angle on the FAR side of the
% torsion spring, J2 block) - NOT theta1 (steering-wheel angle). See
% Cum1_CEPS.txt and Blueprint section 2.2/2.3.
%
% HIERARCHY (see CLAUDE.md, "Quy tac dung model Simulink" - one subsystem
% per NAMED quantity that is reused by more than one downstream consumer;
% pure single-use algebra intermediates, like the Magic Formula's internal
% t1..t4 terms, stay as plain blocks inside their parent, not split out):
%
%   Tires
%     In : theta2, beta, gamma, v, mu     Out: F_yf, F_yr, T_r
%     |
%     +-- SlipAngles      (Section 1)
%     |     In : theta2, beta, gamma, v   Out: alpha_f, alpha_r
%     |
%     +-- TireForces      (Section 2)
%     |     In : alpha_f, alpha_r, mu     Out: F_yf, F_yr
%     |     |
%     |     +-- D          In: mu          Out: D     (F_zf read via
%     |     |                                          Constant inside -
%     |     |                                          precomputed once by
%     |     |                                          load_derived.m, NOT
%     |     |                                          a port anywhere)
%     |     +-- B          In: D           Out: B
%     |     +-- Cal F_yf   In: D, B, alpha_f            Out: F_yf
%     |     +-- Cal F_yr   In: alpha_r                  Out: F_yr
%     |
%     +-- AligningTorque  (Section 3)
%           In : alpha_f, F_yf, mu         Out: T_r     (F_zf read via
%                                                        Constant inside,
%                                                        same as D above -
%                                                        no F_zf port)
%
% Parameters are read from the base workspace - run Model/load_params.m
% BEFORE building.
%
% Usage (run from this folder, Plant/script/):
%   >> run('../../load_params.m')
%   >> build_cum2

modelName = 'Tires_s';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

scriptDir = fileparts(mfilename('fullpath'));   % Plant/script
plantDir  = fileparts(scriptDir);               % Plant/
modelPath = fullfile(plantDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);

%% ===================== Root subsystem: Tires ===========================
sub = [modelName '/Tires'];
createSubsystem(sub);
moveBlock(sub, 50, 50);

addInport(sub, 'theta2', 1,  40,  60);
addInport(sub, 'beta',   2,  40, 120);
addInport(sub, 'gamma',  3,  40, 180);
addInport(sub, 'v',      4,  40, 240);
addInport(sub, 'mu',     5,  40, 320);

addOutport(sub, 'F_yf', 1, 1200, 100);
addOutport(sub, 'F_yr', 2, 1200, 180);
addOutport(sub, 'T_r',  3, 1200, 460);

%% ===================== Section 1: SlipAngles ============================
sa = [sub '/SlipAngles'];
createSubsystem(sa);
moveBlock(sa, 260, 60);
buildSlipAngles(sa);

%% ===================== Section 2: TireForces =============================
tf = [sub '/TireForces'];
createSubsystem(tf);
moveBlock(tf, 560, 60);
buildTireForces(tf);

%% ===================== Section 3: AligningTorque ==========================
at = [sub '/AligningTorque'];
createSubsystem(at);
moveBlock(at, 560, 400);
buildAligningTorque(at);

%% ===================== Cluster-level wiring ================================
% Into Section 1 (its own row, primary inputs at matching height)
add_line(sub, 'theta2/1', 'SlipAngles/1', 'autorouting', 'on');
add_line(sub, 'beta/1',   'SlipAngles/2', 'autorouting', 'on');
add_line(sub, 'gamma/1',  'SlipAngles/3', 'autorouting', 'on');
add_line(sub, 'v/1',      'SlipAngles/4', 'autorouting', 'on');

% alpha_f is used by BOTH Section 2 and Section 3 -> Goto right after
% SlipAngles, From near each consumer
g_af = addGoto(sub, 'alpha_f', 460, 90);
add_line(sub, 'SlipAngles/1', [g_af '/1'], 'autorouting', 'on');
f_af_tf = addFrom(sub, 'alpha_f', 500, 130);
add_line(sub, [f_af_tf '/1'], 'TireForces/1', 'autorouting', 'on');
f_af_at = addFrom(sub, 'alpha_f', 500, 410);
add_line(sub, [f_af_at '/1'], 'AligningTorque/1', 'autorouting', 'on');

% alpha_r is only used by Section 2 -> wire directly
add_line(sub, 'SlipAngles/2', 'TireForces/2', 'autorouting', 'on');

% mu is used by BOTH Section 2 and Section 3 -> Goto/From
g_mu = addGoto(sub, 'mu', 150, 320);
add_line(sub, 'mu/1', [g_mu '/1'], 'autorouting', 'on');
f_mu_tf = addFrom(sub, 'mu', 500, 190);
add_line(sub, [f_mu_tf '/1'], 'TireForces/3', 'autorouting', 'on');
f_mu_at = addFrom(sub, 'mu', 500, 500);
add_line(sub, [f_mu_at '/1'], 'AligningTorque/3', 'autorouting', 'on');

% F_yf goes to the cluster output AND into Section 3 -> Goto/From
g_fyf = addGoto(sub, 'F_yf', 900, 100);
add_line(sub, 'TireForces/1', [g_fyf '/1'], 'autorouting', 'on');
f_fyf_out = addFrom(sub, 'F_yf', 1100, 100);
add_line(sub, [f_fyf_out '/1'], 'F_yf/1', 'autorouting', 'on');
f_fyf_at = addFrom(sub, 'F_yf', 500, 460);
add_line(sub, [f_fyf_at '/1'], 'AligningTorque/2', 'autorouting', 'on');

% F_yr, T_r: only 1 destination each -> wire directly
add_line(sub, 'TireForces/2', 'F_yr/1', 'autorouting', 'on');
add_line(sub, 'AligningTorque/1', 'T_r/1', 'autorouting', 'on');

save_system(modelName, modelPath);
close_system(modelName, 0);

fprintf('Created: %s\n', modelPath);

%% ===================== Section 1: tire slip angles =======================
function buildSlipAngles(sa)
% delta_f = theta2/n_st
% alpha_f = delta_f - beta - l_f*gamma/v
% alpha_r = -beta + l_r*gamma/v
% Two independent main lines (alpha_f row, alpha_r row); gamma and v are
% each used by both rows -> Goto/From. beta feeds each row directly (1
% destination per row).
    addInport(sa, 'theta2', 1,  40,  60);
    addInport(sa, 'beta',   2,  40, 160);
    addInport(sa, 'gamma',  3,  40, 260);
    addInport(sa, 'v',      4,  40, 340);

    addOutport(sa, 'alpha_f', 1, 780, 100);
    addOutport(sa, 'alpha_r', 2, 780, 340);

    % gamma, v are each used twice (alpha_f row and alpha_r row) -> Goto/From
    g_gam = addGoto(sa, 'gamma', 120, 260);
    g_v   = addGoto(sa, 'v',     120, 340);
    add_line(sa, 'gamma/1', [g_gam '/1'], 'autorouting', 'on');
    add_line(sa, 'v/1',     [g_v   '/1'], 'autorouting', 'on');

    % --- alpha_f row (main line, y~90) ---
    hnst = addConstant(sa, 'n_st', 180, 170);   % below Div_delta
    addProduct(sa, 'Div_delta', '*/', 180,  60);   % theta2/n_st

    hlf = addConstant(sa, 'l_f', 280, 260);      % near Prod_lfg
    addProduct(sa, 'Prod_lfg', '**', 280, 180);   % l_f*gamma
    addProduct(sa, 'Div_lfg_v', '*/', 400, 180);  % /v
    addSum    (sa, 'Sum_af', '+--', 500,  90);    % delta_f - beta - (.)

    f_gam1 = addFrom(sa, 'gamma', 220, 260);
    f_v1   = addFrom(sa, 'v',     320, 280);

    add_line(sa, 'theta2/1', 'Div_delta/1', 'autorouting', 'on');
    add_line(sa, [hnst '/1'], 'Div_delta/2', 'autorouting', 'on');
    add_line(sa, [hlf '/1'],  'Prod_lfg/1', 'autorouting', 'on');
    add_line(sa, [f_gam1 '/1'], 'Prod_lfg/2', 'autorouting', 'on');
    add_line(sa, 'Prod_lfg/1', 'Div_lfg_v/1', 'autorouting', 'on');
    add_line(sa, [f_v1 '/1'],  'Div_lfg_v/2', 'autorouting', 'on');
    add_line(sa, 'Div_delta/1', 'Sum_af/1', 'autorouting', 'on');
    add_line(sa, 'beta/1',      'Sum_af/2', 'autorouting', 'on');
    add_line(sa, 'Div_lfg_v/1', 'Sum_af/3', 'autorouting', 'on');
    add_line(sa, 'Sum_af/1',    'alpha_f/1', 'autorouting', 'on');

    % --- alpha_r row (main line, y~340) ---
    hlr = addConstant(sa, 'l_r', 280, 420);      % near Prod_lrg
    addProduct(sa, 'Prod_lrg', '**', 280, 340);   % l_r*gamma
    addProduct(sa, 'Div_lrg_v', '*/', 400, 340);  % /v
    addSum    (sa, 'Sum_ar', '-+', 500, 340);     % -beta + (.)

    f_gam2 = addFrom(sa, 'gamma', 220, 420);
    f_v2   = addFrom(sa, 'v',     320, 440);

    add_line(sa, [hlr '/1'],    'Prod_lrg/1', 'autorouting', 'on');
    add_line(sa, [f_gam2 '/1'], 'Prod_lrg/2', 'autorouting', 'on');
    add_line(sa, 'Prod_lrg/1',  'Div_lrg_v/1', 'autorouting', 'on');
    add_line(sa, [f_v2 '/1'],   'Div_lrg_v/2', 'autorouting', 'on');
    add_line(sa, 'beta/1',      'Sum_ar/1', 'autorouting', 'on');
    add_line(sa, 'Div_lrg_v/1', 'Sum_ar/2', 'autorouting', 'on');
    add_line(sa, 'Sum_ar/1',    'alpha_r/1', 'autorouting', 'on');
end

%% ===================== Section 2: tire lateral forces =====================
function buildTireForces(tf)
    addInport(tf, 'alpha_f', 1,  40,  60);
    addInport(tf, 'alpha_r', 2,  40, 360);
    addInport(tf, 'mu',      3,  40, 140);

    addOutport(tf, 'F_yf', 1, 1180, 100);
    addOutport(tf, 'F_yr', 2, 1180, 360);

    % --- D: In mu -> Out D (top row) ---
    dSub = [tf '/D'];
    createSubsystem(dSub);
    moveBlock(dSub, 220, 100);
    buildD(dSub);
    add_line(tf, 'mu/1', 'D/1', 'autorouting', 'on');

    % --- B: In D -> Out B (continues the same row) ---
    bSub = [tf '/B'];
    createSubsystem(bSub);
    moveBlock(bSub, 420, 100);
    buildB(bSub);

    g_D = addGoto(tf, 'D', 380, 100);
    add_line(tf, 'D/1', [g_D '/1'], 'autorouting', 'on');
    f_D_b = addFrom(tf, 'D', 400, 100);
    add_line(tf, [f_D_b '/1'], 'B/1', 'autorouting', 'on');

    % --- Cal F_yf: In D, B, alpha_f -> Out F_yf (row continues right) ---
    fyfSub = [tf '/Cal F_yf'];
    createSubsystem(fyfSub);
    moveBlock(fyfSub, 640, 60);
    buildCalFyf(fyfSub);

    f_D_fyf = addFrom(tf, 'D', 600, 200);   % D is consumed late inside
    add_line(tf, [f_D_fyf '/1'], 'Cal F_yf/1', 'autorouting', 'on');
    g_B = addGoto(tf, 'B', 580, 100);
    add_line(tf, 'B/1', [g_B '/1'], 'autorouting', 'on');
    f_B_fyf = addFrom(tf, 'B', 600, 60);
    add_line(tf, [f_B_fyf '/1'], 'Cal F_yf/2', 'autorouting', 'on');
    add_line(tf, 'alpha_f/1', 'Cal F_yf/3', 'autorouting', 'on');
    add_line(tf, 'Cal F_yf/1', 'F_yf/1', 'autorouting', 'on');

    % --- Cal F_yr: In alpha_r -> Out F_yr (own row, independent) ---
    fyrSub = [tf '/Cal F_yr'];
    createSubsystem(fyrSub);
    moveBlock(fyrSub, 640, 360);
    buildCalFyr(fyrSub);
    add_line(tf, 'alpha_r/1', 'Cal F_yr/1', 'autorouting', 'on');
    add_line(tf, 'Cal F_yr/1', 'F_yr/1', 'autorouting', 'on');
end

function buildD(dSub)
% D = mu*F_zf. F_zf is precomputed once (load_derived.m) - read here via a
% plain Constant, NOT passed in as a port from anywhere.
    addInport(dSub, 'mu', 1, 40, 60);
    addOutport(dSub, 'D', 1, 300, 60);

    hFzf = addConstant(dSub, 'F_zf', 160, 140);   % right below Prod_D
    addProduct(dSub, 'Prod_D', '**', 200, 60);

    add_line(dSub, 'mu/1',     'Prod_D/1', 'autorouting', 'on');
    add_line(dSub, [hFzf '/1'], 'Prod_D/2', 'autorouting', 'on');
    add_line(dSub, 'Prod_D/1', 'D/1', 'autorouting', 'on');
end

function buildB(bSub)
% B = C_alpha_f/(C*D)
    addInport(bSub, 'D', 1, 40, 60);
    addOutport(bSub, 'B', 1, 400, 60);

    hC   = addConstant(bSub, 'C',         160, 140);   % near Prod_CD
    hCaf = addConstant(bSub, 'C_alpha_f', 280, 140);   % near Div_B

    addProduct(bSub, 'Prod_CD', '**', 200, 60);
    addProduct(bSub, 'Div_B',   '*/', 320, 60);

    add_line(bSub, 'D/1',       'Prod_CD/1', 'autorouting', 'on');
    add_line(bSub, [hC '/1'],   'Prod_CD/2', 'autorouting', 'on');
    add_line(bSub, [hCaf '/1'], 'Div_B/1', 'autorouting', 'on');
    add_line(bSub, 'Prod_CD/1', 'Div_B/2', 'autorouting', 'on');
    add_line(bSub, 'Div_B/1',   'B/1', 'autorouting', 'on');
end

function buildCalFyf(fyfSub)
% u = B*alpha_f
% F_yf = D*sin(C*atan(u - E*(u - atan(u))))
% Main line, one straight row: Prod_u -> Trig_atan_u -> Sum_t1 -> Prod_t2
% -> Sum_t3 -> Trig_atan_t3 -> Prod_t4 -> Trig_sin_t4 -> Prod_Fyf. B and
% alpha_f drive the start of the chain (true left edge); D is only needed
% at the very end (Prod_Fyf) - placed near there instead of the left
% column (layout exception).
    addInport(fyfSub, 'D',       1, 700, 160);   % used late -> near Prod_Fyf
    addInport(fyfSub, 'B',       2,  40,  60);
    addInport(fyfSub, 'alpha_f', 3,  40, 160);

    addOutport(fyfSub, 'F_yf', 1, 1020, 60);

    addProduct(fyfSub, 'Prod_u',       '**',  180,  60);
    addTrigFcn(fyfSub, 'Trig_atan_u',  'atan', 280,  60);
    addSum    (fyfSub, 'Sum_t1',       '+-',   380,  80);
    addProduct(fyfSub, 'Prod_t2',      '**',   460, 100);
    addSum    (fyfSub, 'Sum_t3',       '+-',   540,  80);
    addTrigFcn(fyfSub, 'Trig_atan_t3', 'atan', 620,  80);
    addProduct(fyfSub, 'Prod_t4',      '**',   700,  60);
    addTrigFcn(fyfSub, 'Trig_sin_t4',  'sin',  800,  60);
    addProduct(fyfSub, 'Prod_Fyf',     '**',   900,  60);

    hE = addConstant(fyfSub, 'E', 460, 180);   % right below Prod_t2
    hC = addConstant(fyfSub, 'C', 700, 160);   % right below Prod_t4

    add_line(fyfSub, 'B/1',       'Prod_u/1', 'autorouting', 'on');
    add_line(fyfSub, 'alpha_f/1', 'Prod_u/2', 'autorouting', 'on');
    add_line(fyfSub, 'Prod_u/1',  'Trig_atan_u/1', 'autorouting', 'on');

    % u is used twice more (Sum_t1 and Sum_t3) -> Goto/From
    g_u = addGoto(fyfSub, 'u', 240, 60);
    add_line(fyfSub, 'Prod_u/1', [g_u '/1'], 'autorouting', 'on');
    f_u1 = addFrom(fyfSub, 'u', 340, 100);
    f_u2 = addFrom(fyfSub, 'u', 500, 120);
    add_line(fyfSub, [f_u1 '/1'], 'Sum_t1/1', 'autorouting', 'on');
    add_line(fyfSub, 'Trig_atan_u/1', 'Sum_t1/2', 'autorouting', 'on');
    add_line(fyfSub, [hE '/1'],   'Prod_t2/1', 'autorouting', 'on');
    add_line(fyfSub, 'Sum_t1/1',  'Prod_t2/2', 'autorouting', 'on');
    add_line(fyfSub, [f_u2 '/1'], 'Sum_t3/1', 'autorouting', 'on');
    add_line(fyfSub, 'Prod_t2/1', 'Sum_t3/2', 'autorouting', 'on');
    add_line(fyfSub, 'Sum_t3/1',  'Trig_atan_t3/1', 'autorouting', 'on');
    add_line(fyfSub, [hC '/1'],   'Prod_t4/1', 'autorouting', 'on');
    add_line(fyfSub, 'Trig_atan_t3/1', 'Prod_t4/2', 'autorouting', 'on');
    add_line(fyfSub, 'Prod_t4/1', 'Trig_sin_t4/1', 'autorouting', 'on');
    add_line(fyfSub, 'D/1',       'Prod_Fyf/1', 'autorouting', 'on');
    add_line(fyfSub, 'Trig_sin_t4/1', 'Prod_Fyf/2', 'autorouting', 'on');
    add_line(fyfSub, 'Prod_Fyf/1', 'F_yf/1', 'autorouting', 'on');
end

function buildCalFyr(fyrSub)
% F_yr = C_r*alpha_r
    addInport(fyrSub, 'alpha_r', 1, 40, 60);
    addOutport(fyrSub, 'F_yr', 1, 300, 60);

    hCr = addConstant(fyrSub, 'C_r', 160, 140);   % right below Prod_Fyr
    addProduct(fyrSub, 'Prod_Fyr', '**', 200, 60);

    add_line(fyrSub, 'alpha_r/1', 'Prod_Fyr/1', 'autorouting', 'on');
    add_line(fyrSub, [hCr '/1'],  'Prod_Fyr/2', 'autorouting', 'on');
    add_line(fyrSub, 'Prod_Fyr/1', 'F_yr/1', 'autorouting', 'on');
end

%% ===================== Section 3: road reaction torque ====================
function buildAligningTorque(at)
% e_p  = e_p0 - sgn(alpha_f)*e_p0*C_alpha_f*tan(alpha_f)/(3*mu*F_zf)
% K_tr = e_p/n_st ; T_r = K_tr*F_yf
% e_p, K_tr are pure single-use algebra intermediates (never reused outside
% this formula) - stay as plain blocks, same treatment as t1..t4 inside
% Cal F_yf, no separate subsystem. F_zf: read via Constant (same pattern
% as D above), not a port. F_yf is only needed at the very end (Prod_Tr) -
% placed near there, not at the left column (layout exception).
    addInport(at, 'alpha_f', 1,  40,  60);
    addInport(at, 'mu',      2,  40, 300);
    addInport(at, 'F_yf',    3, 700, 200);   % used late -> near Prod_Tr

    addOutport(at, 'T_r', 1, 940, 100);

    % alpha_f is used twice (sgn and tan) -> Goto/From
    g_af = addGoto(at, 'alpha_f', 120, 60);
    add_line(at, 'alpha_f/1', [g_af '/1'], 'autorouting', 'on');
    f_af1 = addFrom(at, 'alpha_f', 180,  60);
    f_af2 = addFrom(at, 'alpha_f', 180, 140);

    addSignBlock(at, 'Sign_af',        260,  60);
    addTrigFcn  (at, 'Trig_tan_af', 'tan', 260, 140);
    add_line(at, [f_af1 '/1'], 'Sign_af/1', 'autorouting', 'on');
    add_line(at, [f_af2 '/1'], 'Trig_tan_af/1', 'autorouting', 'on');

    hep0a = addConstant(at, 'e_p0',      340, 220);   % near Prod_ep0C
    hCaf  = addConstant(at, 'C_alpha_f', 420, 220);   % near Prod_ep0C
    addProduct(at, 'Prod_ep0C', '**', 380, 180);      % e_p0*C_alpha_f

    addProduct(at, 'Prod_numer', '***', 460, 100);    % sgn*(e_p0*C_af)*tan

    hFzf = addConstant(at, 'F_zf', 260, 340);   % near Prod_3Fzf
    h3   = addConstant(at, '3',    260, 400);   % literal 3, near Prod_3Fzf
    addProduct(at, 'Prod_3Fzf', '**', 320, 320);      % 3*F_zf
    addProduct(at, 'Prod_denom', '**', 400, 280);     % mu*(3*F_zf)

    addProduct(at, 'Div_frac', '*/', 560, 100);       % numer/denom
    hep0b = addConstant(at, 'e_p0', 560, 180);        % near Sum_ep
    addSum(at, 'Sum_ep', '+-', 640, 100);             % e_p0 - frac

    hnst = addConstant(at, 'n_st', 640, 180);   % near Div_Ktr
    addProduct(at, 'Div_Ktr', '*/', 720, 100);        % e_p/n_st

    addProduct(at, 'Prod_Tr', '**', 820, 100);        % K_tr*F_yf

    add_line(at, [hep0a '/1'], 'Prod_ep0C/1', 'autorouting', 'on');
    add_line(at, [hCaf '/1'],  'Prod_ep0C/2', 'autorouting', 'on');

    add_line(at, 'Sign_af/1',     'Prod_numer/1', 'autorouting', 'on');
    add_line(at, 'Prod_ep0C/1',   'Prod_numer/2', 'autorouting', 'on');
    add_line(at, 'Trig_tan_af/1', 'Prod_numer/3', 'autorouting', 'on');

    add_line(at, [hFzf '/1'], 'Prod_3Fzf/1', 'autorouting', 'on');
    add_line(at, [h3 '/1'],   'Prod_3Fzf/2', 'autorouting', 'on');
    add_line(at, 'mu/1',        'Prod_denom/1', 'autorouting', 'on');
    add_line(at, 'Prod_3Fzf/1', 'Prod_denom/2', 'autorouting', 'on');

    add_line(at, 'Prod_numer/1', 'Div_frac/1', 'autorouting', 'on');
    add_line(at, 'Prod_denom/1', 'Div_frac/2', 'autorouting', 'on');

    add_line(at, [hep0b '/1'], 'Sum_ep/1', 'autorouting', 'on');
    add_line(at, 'Div_frac/1', 'Sum_ep/2', 'autorouting', 'on');

    add_line(at, 'Sum_ep/1',  'Div_Ktr/1', 'autorouting', 'on');
    add_line(at, [hnst '/1'], 'Div_Ktr/2', 'autorouting', 'on');

    add_line(at, 'Div_Ktr/1', 'Prod_Tr/1', 'autorouting', 'on');
    add_line(at, 'F_yf/1',    'Prod_Tr/2', 'autorouting', 'on');
    add_line(at, 'Prod_Tr/1', 'T_r/1', 'autorouting', 'on');
end

%% ===================== Shared utility functions ============================
function moveBlock(blk, x, y)
% Move a block to (x,y), KEEPING its default size.
    pos = get_param(blk, 'Position');
    w = pos(3) - pos(1);
    h = pos(4) - pos(2);
    set_param(blk, 'Position', [x, y, x + w, y + h]);
end

function createSubsystem(path)
    add_block('simulink/Ports & Subsystems/Subsystem', path);
    delete_line(path, 'In1/1', 'Out1/1');
    delete_block([path '/In1']);
    delete_block([path '/Out1']);
end

function addInport(sys, name, port, x, y)
% Ports keep MEANINGFUL names - they ARE the physical variable name.
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
% STRAIGHT to a base-workspace variable name. Note: '3' is a literal, not a
% base-workspace variable, but the same helper works (Value is just a
% string Simulink evaluates).
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
    h = add_block('simulink/Signal Routing/From', [sys '/From'], ...
        'MakeNameUnique', 'on');
    set_param(h, 'GotoTag', tag);
    moveBlock(h, x, y);
    nm = get_param(h, 'Name');
end

function addProduct(sys, name, inputsStr, x, y)
% Computation blocks DO get meaningful names: Prod_<result>, Div_<result>.
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
