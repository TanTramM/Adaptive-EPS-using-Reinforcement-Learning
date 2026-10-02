% Diagnostic of step 1: does the untrained agent run end early? (done_eT = 10 N.m)
sc = rl_scenario();
rl_env();
for useAgent = [0 1]
    in = Simulink.SimulationInput('Model_RL_s');
    in = in.setVariable('sc_theta1', [sc.t sc.theta1]); in = in.setVariable('sc_v', [sc.t sc.v]); in = in.setVariable('sc_mu', [sc.t sc.mu]);
    in = in.setVariable('rl_use_agent', useAgent); in = in.setModelParameter('StopTime', '30');
    so = sim(in);
    Ts = so.get('log_T_s'); Ta = so.get('log_T_a'); eT = so.get('log_e_T'); rw = so.get('log_reward');
    fprintf('@@DIAG use_agent=%d: last logged time %.4f s | T_a range [%.3f, %.3f] | max|e_T| %.3f | last reward %.3f\n', ...
        useAgent, Ts.Time(end), min(Ta.Data), max(Ta.Data), max(abs(eT.Data)), rw.Data(end));
end
