%% build_model_rl.m
% Build the complete, runnable closed-loop model for the pure RL assist controller,
% saved as Model_RL_s.mdl in the Model/ folder. Documents/RL/DieuKhien_RL.txt, section 2.1 and 2.1a.
% Sources (auto-generated "_s", must already exist): Plant/Plant_s.mdl, Ref/Reference_s.mdl.
% The RL controller subsystem is built here (it is a toolbox agent block plus
% observation/reward plumbing, no separate controller model).
%
%   Root level (runnable):
%     From Workspace  sc_theta1, sc_v, sc_mu   ([t value] matrices in base)
%       -> Model_RL (subsystem) ->
%     To Workspace    log_T_s, log_T_d_ref, log_e_T, log_T_a, log_a_y, log_reward   (TRUE values, scored)
%                     log_T_s_meas, log_a_y_meas, log_v_meas                         (what the agent sees)
%
%   Model_RL (subsystem)
%     In : theta1 (driver angle), v, mu (unmeasured, scenario input)
%     Out: T_s, T_d_ref, e_T, T_a, a_y, reward (true), T_s_meas, a_y_meas, v_meas (measured)
%     +-- Plant          In : theta1, T_a, v, mu   Out: T_s, theta2, a_y, gamma, beta, theta2_dot   (physics, noise free)
%     +-- Sensors        In : T_s, theta1, theta2_dot, v, gamma, a_y (TRUE)   Out: <signal>_meas   (add_sensors.m: noise, quantizer, hold)
%     +-- Reference      In : T_s, v, a_y (MEASURED)   Out: T_d_ref, e_T   -> feeds the agent
%     +-- Reference_true In : T_s, v, a_y (TRUE)       Out: T_d_ref, e_T   -> scoring and reward only, NOT in the observation
%     +-- RL             In : e_T, T_s, theta1, theta2_dot, v, gamma, a_y (MEASURED), e_T_true   Out: T_a, reward
%   Same sensing and scoring structure as Model_Map_6_8_s and Model_PID_s: the agent sees only measured values; the logged e_T and the
%   reward use true values (information that exists in simulation only: valid for teaching and scoring, the real car does not
%   need it). Default sensor level 'none' = ideal sensors, chain bypassed (load_sensors.m); Documents/Sim/ThucTeHoa.txt Mục 0, 1.
%
%   RL (subsystem), all sampled at rl_Ts (ECU, zero-order hold on every input):
%     obs   = [ s[k]; s[k-D]; ...; s[k-(n-1)D]; T_a[k-1]*rl_Ta_gain; I[k]*rl_I_gain ],  s = [e_T T_s theta1 theta2_dot v gamma a_y] .* rl_obs_gain,
%             n = rl_n_hist samples D = rl_hist_stride agent samples apart (one Delay block of length D per stage)
%     I     = slow observation, low-pass filter of the MEASURED e_T: I[k+1] = rl_I_decay*I[k] + rl_I_in*e_T[k] (time constant I_tau,
%             data/rl.json): gives the agent what a window of 20 ms cannot, how long the error has lasted (about the 1.3 s of T_s)
%     action = RL Agent(obs, reward, isdone)           (agent object: base variable rl_agent)
%     T_a   = sat( rl_use_agent ? action : 0 , +-T_a,max(v) )   (same limit table as every controller)
%     [reward, isdone] = Cal reward(e_T_true, T_a[k-1], T_a[k-2])   MATLAB Function: the reward formula is still
%                                                               being tuned (step 2), so it is kept as code.
%
% Run first: run('<Model>/load_rl.m') and create the agent (RL/script/rl_env.m does it), because the
% RL Agent block needs the base variable rl_agent.
% Solver: variable step, MaxStep = 0.002 s, like Model_Map_6_8_s (steep dry-friction term).

ctrlName  = 'RL';
% Variant (base variable rl_build_variant): 'abs' (default) = the agent outputs T_a, model Model_RL_s;
% 'inc' = the agent outputs dT_a and T_a[k] = sat(T_a[k-1] + dT_a), model Model_RLinc_s (Documents/RL/DieuKhien_RL.txt section 2.4d, variant C).
rlVariant = 'abs';
if evalin('base', 'exist(''rl_build_variant'', ''var'')'), rlVariant = evalin('base', 'rl_build_variant'); end
modelName = ['Model_' ctrlName ternaryName(rlVariant) '_s'];

scriptDir = fileparts(mfilename('fullpath'));   % RL/script
ctrlDir   = fileparts(scriptDir);               % RL/
modelDir  = fileparts(ctrlDir);                 % Model/
addpath(fullfile(modelDir, 'Sim', 'script'));   % add_sensors.m

src = {fullfile(modelDir, 'Plant', 'Plant_s.mdl'), fullfile(modelDir, 'Ref', 'Reference_s.mdl')};

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
modelPath = fullfile(modelDir, [modelName '.mdl']);
if exist(modelPath, 'file')
    delete(modelPath);
end
srcNames = cell(size(src));
for i = 1:numel(src)
    [~, srcNames{i}] = fileparts(src{i});
    if bdIsLoaded(srcNames{i})
        close_system(srcNames{i}, 0);
    end
    load_system(src{i});
end

new_system(modelName);
open_system(modelName);

%% ===================== Closed-loop subsystem ============================
sub = [modelName '/Model_' ctrlName];
createSubsystem(sub);
moveBlock(sub, 300, 80);
buildClosedLoop(sub, srcNames);

%% ===================== Root: scenario sources and logging ===============
ins = {'theta1', 'v', 'mu'};
for i = 1:numel(ins)
    blk = [modelName '/From Workspace ' ins{i}];
    add_block('simulink/Sources/From Workspace', blk);
    set_param(blk, 'VariableName', ['sc_' ins{i}], 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    moveBlock(blk, 60, 60 + 60*(i-1));
    add_line(modelName, ['From Workspace ' ins{i} '/1'], portRef(sub, ins{i}), 'autorouting', 'on');
end
outs = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y', 'reward', 'T_s_meas', 'a_y_meas', 'v_meas'};
for i = 1:numel(outs)
    blk = [modelName '/To Workspace ' outs{i}];
    add_block('simulink/Sinks/To Workspace', blk);
    set_param(blk, 'VariableName', ['log_' outs{i}], 'SaveFormat', 'Timeseries');
    moveBlock(blk, 600, 40 + 60*(i-1));
    add_line(modelName, portRef(sub, outs{i}), ['To Workspace ' outs{i} '/1'], 'autorouting', 'on');
end

set_param(modelName, 'StopTime', '20', 'MaxStep', '0.002', 'RelTol', '1e-6');
set_param(modelName, 'ReturnWorkspaceOutputs', 'off');
set_param(modelName, 'StopFcn', sprintf('save_run_results(''%s'', ''manual_run'')', ctrlName));

save_system(modelName, modelPath);
close_system(modelName, 0);
for i = 1:numel(srcNames)
    close_system(srcNames{i}, 0);
end
fprintf('Created: %s\n', modelPath);

%% ===================== Plant + Sensors + Reference + RL =====================
function buildClosedLoop(sub, srcNames)
    add_block(findRootSubsystem(srcNames{1}), [sub '/Plant']);
    moveBlock([sub '/Plant'], 600, 60);
    add_block(findRootSubsystem(srcNames{2}), [sub '/Reference']);
    moveBlock([sub '/Reference'], 1000, 60);
    add_block(findRootSubsystem(srcNames{2}), [sub '/Reference_true']);
    moveBlock([sub '/Reference_true'], 1000, 700);
    sensSig = {'T_s', 'theta1', 'theta2_dot', 'v', 'gamma', 'a_y'};
    sens = add_sensors(sub, sensSig, 760, 60);
    ctl = [sub '/RL'];
    createSubsystem(ctl);
    moveBlock(ctl, 300, 420);
    buildRL(ctl);

    plant = [sub '/Plant'];
    ref   = [sub '/Reference'];
    refTrue = [sub '/Reference_true'];

    addInport(sub, 'theta1', 1, 40,  60);
    addInport(sub, 'v',      2, 40, 140);
    addInport(sub, 'mu',     3, 40, 220);
    outs = {'T_s', 'T_d_ref', 'e_T', 'T_a', 'a_y', 'reward', 'T_s_meas', 'a_y_meas', 'v_meas'};
    for i = 1:numel(outs)
        addOutport(sub, outs{i}, i, 1400, 60 + 80*(i-1));
    end

    % ----- scenario inputs: TRUE values to the Plant, the Sensors and the scoring Reference -----
    g = addGoto(sub, 'theta1_true', 120, 60);  add_line(sub, 'theta1/1', [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'theta1_true', 500, 60) '/1'], portRef(plant, 'theta1'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'theta1_true', 500, 100) '/1'], portRef(sens, 'theta1'), 'autorouting', 'on');
    g = addGoto(sub, 'v_true', 120, 140);      add_line(sub, 'v/1', [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v_true', 500, 180) '/1'], portRef(plant, 'v'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v_true', 500, 220) '/1'], portRef(sens, 'v'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v_true', 900, 720) '/1'], portRef(refTrue, 'v'), 'autorouting', 'on');
    add_line(sub, 'mu/1', portRef(plant, 'mu'), 'autorouting', 'on');

    % ----- Plant outputs (true) -----
    g = addGoto(sub, 'T_s_true', 700, 60);     add_line(sub, portRef(plant, 'T_s'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s_true', 700, 100) '/1'], portRef(sens, 'T_s'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s_true', 900, 740) '/1'], portRef(refTrue, 'T_s'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s_true', 1320, 60) '/1'], 'T_s/1', 'autorouting', 'on');
    g = addGoto(sub, 'a_y_true', 700, 180);    add_line(sub, portRef(plant, 'a_y'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y_true', 700, 220) '/1'], portRef(sens, 'a_y'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y_true', 900, 760) '/1'], portRef(refTrue, 'a_y'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y_true', 1320, 380) '/1'], 'a_y/1', 'autorouting', 'on');
    g = addGoto(sub, 'theta2_dot_true', 700, 300); add_line(sub, portRef(plant, 'theta2_dot'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'theta2_dot_true', 700, 340) '/1'], portRef(sens, 'theta2_dot'), 'autorouting', 'on');
    g = addGoto(sub, 'gamma_true', 700, 380);  add_line(sub, portRef(plant, 'gamma'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'gamma_true', 700, 420) '/1'], portRef(sens, 'gamma'), 'autorouting', 'on');
    unused = {'theta2', 'beta'};             % beta is NOT measurable (Blueprint 1.2): never fed to the agent
    for i = 1:numel(unused)
        h = add_block('simulink/Sinks/Terminator', [sub '/Terminator'], 'MakeNameUnique', 'on');
        moveBlock(h, 860, 440 + 20*i);
        add_line(sub, portRef(plant, unused{i}), [get_param(h, 'Name') '/1'], 'autorouting', 'on');
    end

    % ----- Sensors outputs: MEASURED values under the plain tags (read by Reference and by the agent) -----
    for i = 1:numel(sensSig)
        g = addGoto(sub, sensSig{i}, 1000, 300 + 40*(i-1));
        add_line(sub, portRef(sens, [sensSig{i} '_meas']), [g '/1'], 'autorouting', 'on');
    end
    add_line(sub, [addFrom(sub, 'T_s', 900, 60) '/1'], portRef(ref, 'T_s'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v', 900, 100) '/1'], portRef(ref, 'v'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y', 900, 140) '/1'], portRef(ref, 'a_y'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_s', 1320, 540) '/1'], 'T_s_meas/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'a_y', 1320, 620) '/1'], 'a_y_meas/1', 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'v', 1320, 700) '/1'], 'v_meas/1', 'autorouting', 'on');

    % ----- References: measured e_T -> agent (its T_d_ref output is not used); true e_T -> scoring and reward -----
    g = addGoto(sub, 'e_T', 1200, 220);        add_line(sub, portRef(ref, 'e_T'), [g '/1'], 'autorouting', 'on');
    hT = add_block('simulink/Sinks/Terminator', [sub '/Terminator'], 'MakeNameUnique', 'on');
    moveBlock(hT, 1200, 150);                  add_line(sub, portRef(ref, 'T_d_ref'), [get_param(hT, 'Name') '/1'], 'autorouting', 'on');
    g = addGoto(sub, 'e_T_true', 1200, 700);   add_line(sub, portRef(refTrue, 'e_T'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'e_T_true', 1320, 220) '/1'], 'e_T/1', 'autorouting', 'on');
    add_line(sub, portRef(refTrue, 'T_d_ref'), 'T_d_ref/1', 'autorouting', 'on');

    % ----- agent inputs by name (measured tags and e_T_true), T_a feedback, reward -----
    ctlIns = get_param(find_system(ctl, 'SearchDepth', 1, 'BlockType', 'Inport'), 'Name');
    for i = 1:numel(ctlIns)
        add_line(sub, [addFrom(sub, ctlIns{i}, 200, 420 + 40*(i-1)) '/1'], portRef(ctl, ctlIns{i}), 'autorouting', 'on');
    end
    g = addGoto(sub, 'T_a', 500, 420);     add_line(sub, portRef(ctl, 'T_a'), [g '/1'], 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 500, 100) '/1'], portRef(plant, 'T_a'), 'autorouting', 'on');
    add_line(sub, [addFrom(sub, 'T_a', 1320, 300) '/1'], 'T_a/1', 'autorouting', 'on');
    add_line(sub, portRef(ctl, 'reward'), 'reward/1', 'autorouting', 'on');
end

%% ===================== RL controller subsystem =====================
function buildRL(s)
    sig = {'e_T', 'T_s', 'theta1', 'theta2_dot', 'v', 'gamma', 'a_y'};
    for i = 1:numel(sig)
        addInport(s, sig{i}, i, 40, 60 + 60*(i-1));
        z = [s '/ZOH_' sig{i}];
        add_block('simulink/Discrete/Zero-Order Hold', z);
        set_param(z, 'SampleTime', 'rl_Ts');
        moveBlock(z, 140, 60 + 60*(i-1));
        add_line(s, [sig{i} '/1'], ['ZOH_' sig{i} '/1'], 'autorouting', 'on');
        if strcmp(sig{i}, 'v')                    % also used outside the observation (T_a,max(v) table)
            g = addGoto(s, sig{i}, 220, 40 + 60*(i-1));
            add_line(s, ['ZOH_' sig{i} '/1'], [g '/1'], 'autorouting', 'on');
        end
    end
    % true error: reward and early termination only (not in the observation)
    addInport(s, 'e_T_true', numel(sig) + 1, 40, 60 + 60*numel(sig));
    add_block('simulink/Discrete/Zero-Order Hold', [s '/ZOH_e_T_true']);
    set_param([s '/ZOH_e_T_true'], 'SampleTime', 'rl_Ts');
    moveBlock([s '/ZOH_e_T_true'], 140, 60 + 60*numel(sig));
    add_line(s, 'e_T_true/1', 'ZOH_e_T_true/1', 'autorouting', 'on');
    g = addGoto(s, 'e_T_true', 220, 40 + 60*numel(sig));
    add_line(s, 'ZOH_e_T_true/1', [g '/1'], 'autorouting', 'on');
    addOutport(s, 'T_a', 1, 1500, 300);
    addOutport(s, 'reward', 2, 1500, 520);

    % ---- observation: normalized signal vector, strided history, previous T_a ----
    mx = [s '/Mux_obs'];
    add_block('simulink/Signal Routing/Mux', mx);
    set_param(mx, 'Inputs', num2str(numel(sig)));
    moveBlock(mx, 320, 200);
    for i = 1:numel(sig)
        add_line(s, ['ZOH_' sig{i} '/1'], ['Mux_obs/' num2str(i)], 'autorouting', 'on');
    end
    c = addConstant(s, 'rl_obs_gain', 360, 420);
    addProduct(s, 'Prod_obs_norm', '**', 420, 200);
    add_line(s, 'Mux_obs/1', 'Prod_obs_norm/1', 'autorouting', 'on');
    add_line(s, [c '/1'], 'Prod_obs_norm/2', 'autorouting', 'on');
    % history: chain of Delay blocks of rl_hist_stride agent samples each (the Tapped Delay block accepts scalars only), so
    % the samples are D = rl_hist_stride samples apart; the number of blocks follows rl_n_hist at build time, so rebuild the
    % model after changing n_hist in data/rl.json (the stride is a variable: no rebuild needed)
    nHist = evalin('base', 'rl_n_hist');
    prev = 'Prod_obs_norm';
    for k = 1:nHist-1
        nm = sprintf('Delay_obs_%d', k);
        add_block('simulink/Discrete/Delay', [s '/' nm]);
        set_param([s '/' nm], 'DelayLength', 'rl_hist_stride', 'SampleTime', 'rl_Ts', 'InitialCondition', '0');
        moveBlock([s '/' nm], 520 + 80*k, 120);
        add_line(s, [prev '/1'], [nm '/1'], 'autorouting', 'on');
        prev = nm;
    end

    ud = [s '/Delay_Ta'];
    add_block('simulink/Discrete/Unit Delay', ud);
    set_param(ud, 'SampleTime', 'rl_Ts', 'InitialCondition', '0');
    moveBlock(ud, 1200, 420);
    g = addGoto(s, 'T_a_prev', 1280, 420);
    add_line(s, 'Delay_Ta/1', [g '/1'], 'autorouting', 'on');
    ud2 = [s '/Delay_Ta2'];
    add_block('simulink/Discrete/Unit Delay', ud2);
    set_param(ud2, 'SampleTime', 'rl_Ts', 'InitialCondition', '0');
    moveBlock(ud2, 1200, 460);
    add_line(s, 'Delay_Ta/1', 'Delay_Ta2/1', 'autorouting', 'on');
    g = addGoto(s, 'T_a_prev2', 1280, 460);
    add_line(s, 'Delay_Ta2/1', [g '/1'], 'autorouting', 'on');
    f = addFrom(s, 'T_a_prev', 520, 300);
    c = addConstant(s, 'rl_Ta_gain', 540, 360);
    addProduct(s, 'Prod_Ta_norm', '**', 620, 300);
    add_line(s, [f '/1'], 'Prod_Ta_norm/1', 'autorouting', 'on');
    add_line(s, [c '/1'], 'Prod_Ta_norm/2', 'autorouting', 'on');

    % slow observation I: first-order low-pass of the measured e_T, one Unit Delay closes the loop (no algebraic loop)
    di = [s '/Delay_I'];
    add_block('simulink/Discrete/Unit Delay', di);
    set_param(di, 'SampleTime', 'rl_Ts', 'InitialCondition', '0');
    moveBlock(di, 520, 560);
    g = addGoto(s, 'I', 600, 560);
    add_line(s, 'Delay_I/1', [g '/1'], 'autorouting', 'on');
    addProduct(s, 'Prod_I_decay', '**', 520, 620);
    add_line(s, [addFrom(s, 'I', 440, 620) '/1'], 'Prod_I_decay/1', 'autorouting', 'on');
    add_line(s, [addConstant(s, 'rl_I_decay', 440, 660) '/1'], 'Prod_I_decay/2', 'autorouting', 'on');
    addProduct(s, 'Prod_I_in', '**', 520, 700);
    add_line(s, 'ZOH_e_T/1', 'Prod_I_in/1', 'autorouting', 'on');
    add_line(s, [addConstant(s, 'rl_I_in', 440, 740) '/1'], 'Prod_I_in/2', 'autorouting', 'on');
    addSum(s, 'Sum_I', '++', 640, 660);
    add_line(s, 'Prod_I_decay/1', 'Sum_I/1', 'autorouting', 'on');
    add_line(s, 'Prod_I_in/1', 'Sum_I/2', 'autorouting', 'on');
    add_line(s, 'Sum_I/1', 'Delay_I/1', 'autorouting', 'on');
    addProduct(s, 'Prod_I_norm', '**', 700, 560);
    add_line(s, [addFrom(s, 'I', 640, 560) '/1'], 'Prod_I_norm/1', 'autorouting', 'on');
    add_line(s, [addConstant(s, 'rl_I_gain', 640, 600) '/1'], 'Prod_I_norm/2', 'autorouting', 'on');

    vc = [s '/Cat_obs'];
    add_block('simulink/Math Operations/Vector Concatenate', vc);
    set_param(vc, 'NumInputs', num2str(nHist + 2), 'Mode', 'Vector');
    moveBlock(vc, 920, 240);
    add_line(s, 'Prod_obs_norm/1', 'Cat_obs/1', 'autorouting', 'on');
    for k = 1:nHist-1
        add_line(s, sprintf('Delay_obs_%d/1', k), sprintf('Cat_obs/%d', k + 1), 'autorouting', 'on');
    end
    add_line(s, 'Prod_Ta_norm/1', sprintf('Cat_obs/%d', nHist + 1), 'autorouting', 'on');
    add_line(s, 'Prod_I_norm/1', sprintf('Cat_obs/%d', nHist + 2), 'autorouting', 'on');

    % ---- agent ----
    ag = [s '/RL Agent'];
    add_block('rllib/RL Agent', ag);
    set_param(ag, 'Agent', 'rl_agent');
    moveBlock(ag, 1000, 420);
    add_line(s, 'Cat_obs/1', 'RL Agent/1', 'autorouting', 'on');

    % ---- reward and early termination (MATLAB Function: formula still being tuned) ----
    % The reward received at sample k scores the action taken at k-1 (its effect is e_T[k]), so it uses
    % T_a[k-1] and T_a[k-2]; using T_a[k] would also create an algebraic loop through the agent block.
    rw = [s '/Cal reward'];
    add_block('simulink/User-Defined Functions/MATLAB Function', rw);
    moveBlock(rw, 1300, 500);
    setMatlabFunction(rw, sprintf(['function [reward, isdone] = cal_reward(e_T, T_a_prev, T_a_prev2, par, done_eT)\n' ...
        '%% Step reward of Documents/RL/DieuKhien_RL.txt Eq. (1) for the previous action; par = [T_ref, w1, w2]; e_T is the TRUE error.\n' ...
        'reward = -(e_T / par(1))^2 - par(2) * (T_a_prev - T_a_prev2)^2 - par(3) * T_a_prev^2;\n' ...
        'isdone = double(abs(e_T) > done_eT);\n']));
    add_line(s, [addFrom(s, 'e_T_true', 1220, 500) '/1'], 'Cal reward/1', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'T_a_prev', 1220, 530) '/1'], 'Cal reward/2', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'T_a_prev2', 1220, 560) '/1'], 'Cal reward/3', 'autorouting', 'on');
    add_line(s, [addConstant(s, 'rl_reward_par', 1220, 590) '/1'], 'Cal reward/4', 'autorouting', 'on');
    add_line(s, [addConstant(s, 'rl_done_eT', 1220, 620) '/1'], 'Cal reward/5', 'autorouting', 'on');
    g = addGoto(s, 'reward', 1420, 500); add_line(s, 'Cal reward/1', [g '/1'], 'autorouting', 'on');
    g = addGoto(s, 'isdone', 1420, 540); add_line(s, 'Cal reward/2', [g '/1'], 'autorouting', 'on');
    add_line(s, [addFrom(s, 'reward', 780, 330) '/1'], 'RL Agent/2', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'isdone', 780, 370) '/1'], 'RL Agent/3', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'reward', 1440, 520) '/1'], 'reward/1', 'autorouting', 'on');

    % ---- agent or T_a = 0 (wiring check), then the common limit +-T_a,max(v) ----
    sw = [s '/Sw_use_agent'];
    add_block('simulink/Signal Routing/Switch', sw);
    set_param(sw, 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    moveBlock(sw, 1000, 260);
    if evalin('base', 'exist(''rl_build_variant'', ''var'') && strcmp(rl_build_variant, ''inc'')')   % variant C (local functions do not see the script variable rlVariant)
        % variant C: the agent action is a CHANGE of T_a; T_a_prev is the delayed value after the clamp (Delay_Ta), so no algebraic loop
        addSum(s, 'Sum_inc', '++', 940, 200);
        add_line(s, 'RL Agent/1', 'Sum_inc/1', 'autorouting', 'on');
        add_line(s, [addFrom(s, 'T_a_prev', 880, 200) '/1'], 'Sum_inc/2', 'autorouting', 'on');
        add_line(s, 'Sum_inc/1', 'Sw_use_agent/1', 'autorouting', 'on');
    else
        add_line(s, 'RL Agent/1', 'Sw_use_agent/1', 'autorouting', 'on');
    end
    add_line(s, [addConstant(s, 'rl_use_agent', 940, 330) '/1'], 'Sw_use_agent/2', 'autorouting', 'on');
    add_line(s, [addConstant(s, '0', 940, 380) '/1'], 'Sw_use_agent/3', 'autorouting', 'on');

    lk = [s '/Lookup_Tamax'];
    add_block('simulink/Lookup Tables/1-D Lookup Table', lk);
    set_param(lk, 'Table', 'Tamax_table', 'BreakpointsForDimension1', 'Tamax_v_bp_ms', ...
        'InterpMethod', 'Linear point-slope', 'ExtrapMethod', 'Clip');
    moveBlock(lk, 1000, 160);
    add_line(s, [addFrom(s, 'v', 940, 160) '/1'], 'Lookup_Tamax/1', 'autorouting', 'on');
    mn = [s '/Min_Ta'];
    add_block('simulink/Math Operations/MinMax', mn);
    set_param(mn, 'Function', 'min', 'Inputs', '2');
    moveBlock(mn, 1120, 260);
    add_line(s, 'Sw_use_agent/1', 'Min_Ta/1', 'autorouting', 'on');
    add_line(s, 'Lookup_Tamax/1', 'Min_Ta/2', 'autorouting', 'on');
    um = [s '/Neg_Tamax'];
    add_block('simulink/Math Operations/Unary Minus', um);
    moveBlock(um, 1120, 160);
    add_line(s, 'Lookup_Tamax/1', 'Neg_Tamax/1', 'autorouting', 'on');
    mx2 = [s '/Max_Ta'];
    add_block('simulink/Math Operations/MinMax', mx2);
    set_param(mx2, 'Function', 'max', 'Inputs', '2');
    moveBlock(mx2, 1220, 260);
    add_line(s, 'Min_Ta/1', 'Max_Ta/1', 'autorouting', 'on');
    add_line(s, 'Neg_Tamax/1', 'Max_Ta/2', 'autorouting', 'on');
    g = addGoto(s, 'T_a', 1320, 260); add_line(s, 'Max_Ta/1', [g '/1'], 'autorouting', 'on');
    add_line(s, [addFrom(s, 'T_a', 1420, 300) '/1'], 'T_a/1', 'autorouting', 'on');
    add_line(s, [addFrom(s, 'T_a', 1140, 420) '/1'], 'Delay_Ta/1', 'autorouting', 'on');
end

function setMatlabFunction(blk, code)
% Write the code of a MATLAB Function block (Stateflow API).
    rt = sfroot;
    ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blk);
    ch.Script = code;
end

function subPath = findRootSubsystem(modelFileName)
% Return the ONE root-level subsystem of an already-loaded .mdl.
    subs = find_system(modelFileName, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    assert(numel(subs) == 1, 'Model %s must have exactly 1 root subsystem, found %d', ...
        modelFileName, numel(subs));
    subPath = subs{1};
end

function ref = portRef(subPath, portName)
% "<BlockNameInParent>/<PortNumber>" of the Inport/Outport named portName
% inside subPath - wiring by NAME.
    parts = strsplit(subPath, '/');
    blockNameInParent = parts{end};
    for bt = {'Inport', 'Outport'}
        ports = find_system(subPath, 'SearchDepth', 1, 'BlockType', bt{1});
        for k = 1:numel(ports)
            if strcmp(get_param(ports{k}, 'Name'), portName)
                ref = sprintf('%s/%s', blockNameInParent, get_param(ports{k}, 'Port'));
                return;
            end
        end
    end
    error('Port named "%s" not found in %s', portName, subPath);
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

function addSum(sys, name, inputsStr, x, y)
% Sum_<result>
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function addProduct(sys, name, inputsStr, x, y)
% Prod_<result or operands>, Div_<result> (Inputs='*/').
    full = [sys '/' name];
    add_block('simulink/Math Operations/Product', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end

function s = ternaryName(variant)
    if strcmp(variant, 'inc'), s = 'inc'; else, s = ''; end
end
