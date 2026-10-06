try
    run('Model/load_pi_2k.m');
    cd Model/Sim/script;
    build_closed_loop('PI_2K');
    
    seeds = 90001:90005;
    for s = seeds
        fprintf('\n>>> RUNNING TEST CASES FOR PI, NOISE HIGH, SEED %d <<<\n', s);
        run_test_cases('PI_2K', 'high', s);
    end
    
    fprintf('\n>>> RUNNING COMPARE TEST CASES: Map vs PI <<<\n');
    compare_test_cases('Map_6_8', 'PI_2K', 'high', 90001, 1);
    
    disp('ALL DONE');
    exit(0);
catch ME
    disp(ME.message);
    exit(1);
end
