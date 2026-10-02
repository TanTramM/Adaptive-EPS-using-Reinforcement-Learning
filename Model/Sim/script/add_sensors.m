function sensorsPath = add_sensors(sys, signals, x, y)
%ADD_SENSORS Create the Sensors subsystem of a closed-loop model: measured signal = digitized, held, noisy true signal.
%
%   sensorsPath = add_sensors(sys, {'T_s', 'a_y', 'v'}, x, y)
%
%   Sensors (subsystem) inside sys:
%     In : <signal> (TRUE value, from the Plant or the scenario), one Inport per name in signals
%     Out: <signal>_meas (what the controller and the controller's Reference block see)
%   Per signal the chain is
%       true -> Sum_<s>_meas (+ Random Number) -> Quant_<s> (Quantizer) -> ZOH_<s> (zero-order hold) -> Switch_<s> -> <s>_meas
%   and Switch_<s> passes the true value straight through when sensors_on = 0 (ideal sensor), so with level 'none' the model
%   behaves exactly as without Sensors.
%   Random Number: Gaussian, mean 0, Variance noise_var_<s>, Seed noise_seed_<s>, sample time sens_Tupd_<s>.
%   Quantizer: interval sens_delta_<s> (resolution of the sensor). ZOH: sample time sens_Tupd_<s> (update period of the signal as
%   the ECU sees it: 1 ms for sensors wired to the EPS ECU, 10 ms for ESC signals over CAN). Noise is added BEFORE quantization
%   (analog noise), the hold comes last (CAN frame / ADC register keeps the last value until the next update).
%   All parameters are base-workspace variables (load_sensors.m defines them; run_test_cases.m overrides them per run).
%   Only signals that a sensor measures go through here: beta, mu and T_r have no sensor, T_a is the controller's own command.
%   Documents/Sim/ThucTeHoa.txt Mục 0 and 1.

sensorsPath = [sys '/Sensors'];
createSubsystem(sensorsPath);
moveBlock(sensorsPath, x, y);
for i = 1:numel(signals)
    s = signals{i};
    row = 160 * (i - 1);
    addInport(sensorsPath, s, i, 40, 60 + row);
    addOutport(sensorsPath, [s '_meas'], i, 1060, 60 + row);

    rn = [sensorsPath '/Random Number'];
    h = add_block('simulink/Sources/Random Number', rn, 'MakeNameUnique', 'on');
    set_param(h, 'Mean', '0', 'Variance', ['noise_var_' s], 'Seed', ['noise_seed_' s], 'SampleTime', ['sens_Tupd_' s]);
    moveBlock(h, 160, 110 + row);
    rnName = get_param(h, 'Name');

    addSum(sensorsPath, ['Sum_' s '_meas'], '++', 320, 60 + row);
    qn = ['Quant_' s];
    add_block('simulink/Discontinuities/Quantizer', [sensorsPath '/' qn]);
    set_param([sensorsPath '/' qn], 'QuantizationInterval', ['sens_delta_' s]);
    moveBlock([sensorsPath '/' qn], 460, 60 + row);
    zn = ['ZOH_' s];
    add_block('simulink/Discrete/Zero-Order Hold', [sensorsPath '/' zn]);
    set_param([sensorsPath '/' zn], 'SampleTime', ['sens_Tupd_' s]);
    moveBlock([sensorsPath '/' zn], 620, 60 + row);
    sw = ['Switch_' s];
    add_block('simulink/Signal Routing/Switch', [sensorsPath '/' sw]);
    set_param([sensorsPath '/' sw], 'Criteria', 'u2 ~= 0');
    moveBlock([sensorsPath '/' sw], 880, 60 + row);
    hc = add_block('simulink/Sources/Constant', [sensorsPath '/Constant'], 'MakeNameUnique', 'on');
    set_param(hc, 'Value', 'sensors_on');
    moveBlock(hc, 760, 120 + row);
    cName = get_param(hc, 'Name');

    add_line(sensorsPath, [s '/1'], ['Sum_' s '_meas/1'], 'autorouting', 'on');
    add_line(sensorsPath, [rnName '/1'], ['Sum_' s '_meas/2'], 'autorouting', 'on');
    add_line(sensorsPath, ['Sum_' s '_meas/1'], [qn '/1'], 'autorouting', 'on');
    add_line(sensorsPath, [qn '/1'], [zn '/1'], 'autorouting', 'on');
    add_line(sensorsPath, [zn '/1'], [sw '/1'], 'autorouting', 'on');
    add_line(sensorsPath, [cName '/1'], [sw '/2'], 'autorouting', 'on');
    add_line(sensorsPath, [s '/1'], [sw '/3'], 'autorouting', 'on');
    add_line(sensorsPath, [sw '/1'], [s '_meas/1'], 'autorouting', 'on');
end
end

%% ===================== Shared utility functions ========================
function moveBlock(blk, x, y)
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

function addSum(sys, name, inputsStr, x, y)
    full = [sys '/' name];
    add_block('simulink/Math Operations/Add', full);
    set_param(full, 'Inputs', inputsStr);
    moveBlock(full, x, y);
end
