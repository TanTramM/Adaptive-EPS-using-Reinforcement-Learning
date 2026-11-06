function test_mappid_grid_helpers()
%TEST_MAPPID_GRID_HELPERS Tests independent of the common grid-search implementation.
for k = 1:1000
    u = rand(1, 9);
    u([1 8]) = 0.01 + 0.99 * u([1 8]);
    if mod(k, 10) == 0, u(1) = 0; end
    if mod(k, 13) == 0, u(8) = 0; end
    x = mappid_u2x(u);
    ur = mappid_x2u(x);
    assert(max(abs(ur - u)) < 2e-12, 'mappid u/x round trip failed.');
end

tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's'));
vn = {'K','z','p_over_z','z1','p1_over_z1','Kp','Ki','Kd','Tf'};
hdr = [vn, {'seed','J','R_pct','S_Nm','TV','erel_pct','rev_pct','PM_deg','GM','HF','lagGain2Hz','simulated','c1','c2','c3','c4','seconds'}];
x1 = mappid_u2x(0.2 * ones(1, 9));
x2 = mappid_u2x(0.8 * ones(1, 9));
data = [x1,30000,4,4,1,1,2,0,40,3,1,0.8,1,-1,-1,-0.1,-1,1; ...
        x2,30000,2,2,1,1,2,0,40,3,1,0.8,1,-1,-1,-0.1,-1,1];
T = array2table(data, 'VariableNames', hdr);
writetable(T, fullfile(tmp, 'MapPID_CALIB_TEST_w1_s30000.csv'));
[uBest, xBest] = mappid_grid_best(tmp, 'TEST', 30000);
assert(max(abs(xBest - x2)) < 1e-10 && max(abs(uBest - mappid_x2u(x2))) < 1e-10);
clear cleanup;
fprintf('test_mappid_grid_helpers: PASS\n');
end
