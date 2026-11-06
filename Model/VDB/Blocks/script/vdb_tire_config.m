function info = vdb_tire_config(blk, P, axle, v0, overrides)
%VDB_TIRE_CONFIG Common configuration of one VDB tire block (Combined Slip Wheel 2DOF) used by every Plant_VDB test (night plan N1, items R9/R10).
%   info = vdb_tire_config(blk, P, axle, v0 [, overrides])
%   blk  : path of the block 'vehdynlibtire/Combined Slip Wheel 2DOF' already added to a model
%   P    : struct with fields Fzf, Fzr (axle loads, N), Ca (axle cornering stiffness, N/rad), C, E (Magic Formula shape factors of the Plant)
%   axle : 'front' or 'rear'  (a half axle is modelled: Fz = axle load / 2, stiffness = Ca / 2; forces are doubled by the caller)
%   v0   : rolling speed in m/s, used for the initial wheel speed omegao
%   overrides : optional struct of mask coefficients applied last (used only for the deliberate-error negative controls of the checks)
%   The preset tire types do not take new coefficient values (found by simulation in night N1); with tireType = External file the coefficient fields
%   of the mask are editable, so the preset values are loaded first and every coefficient is then overwritten through the mask.
%   The tire is made to be the same Magic Formula as the Plant PT(9)-(10), so that a difference seen by a test is a difference of the block:
%     Plant: Fy = mu*Fz*sin(C*atan(B*a - E*(B*a - atan(B*a)))), B = Ca/(C*mu*Fz).
%     VDB side: PCY1 = C, PDY1 = 1, PEY1 = E, FNOMIN = Fz, PKY2 = 1, PKY4 = 2, PKY1 = -Ca/FNOMIN (the VDB slope is
%     PKY1*FNOMIN*sin(PKY4*atan(Fz/(PKY2*FNOMIN))), equal to PKY1*FNOMIN at Fz = FNOMIN; the sign is negative because the VDB slip angle has
%     the opposite sign of the Plant alpha_f, see R8). mu is applied only through the scale factor LMUY (third entry of ScaleFctrs).
%     Every shift, load, camber, pressure and relaxation coefficient is set to zero: nothing depends on anything but alpha, Fz and mu.
%   Returns a struct with the values that were set (Fz, Ca and the list of coefficients that were zeroed).
    switch axle
        case 'front', Fz = P.Fzf / 2;
        case 'rear',  Fz = P.Fzr / 2;
        otherwise, error('axle must be front or rear');
    end
    if nargin < 5, overrides = struct(); end
    Ca = P.Ca / 2;
    set_param(blk, 'tireType', 'External file');                       % default parameter set vdynPassCar.mat = the 205/60R15 preset; every value below is overwritten
    set_param(blk, 'vertType', 'None');                               % vertical load comes from the input Fext, not from the tire spring
    set_param(blk, 'plySteer', 'off'); set_param(blk, 'turnslip', 'off');
    Re = str2double(get_param(blk, 'UNLOADED_RADIUS'));
    set_param(blk, 'omegao', num2str(v0 / (0.97 * Re), 12));           % wheel starts at the rolling speed, no start-up slip transient

    setp(blk, 'FNOMIN', Fz);
    setp(blk, 'PCY1', P.C);  setp(blk, 'PDY1', 1);  setp(blk, 'PEY1', P.E);
    setp(blk, 'PKY1', -Ca / Fz);  setp(blk, 'PKY2', 1);  setp(blk, 'PKY4', 2);
    zeroed = {'PDY2', 'PDY3', 'PEY2', 'PEY3', 'PEY4', 'PEY5', 'PKY3', 'PKY5', 'PKY6', 'PKY7', 'PHY1', 'PHY2', 'PVY1', 'PVY2', 'PVY3', 'PVY4', ...
              'PPY1', 'PPY2', 'PPY3', 'PPY4', 'PPY5', 'RBY1', 'RBY2', 'RBY3', 'RBY4', 'RHY1', 'RHY2', 'RVY1', 'RVY2', 'RVY3', 'RVY4', 'RVY5', 'RVY6', ...
              'QSY1', 'QSY2', 'QSY3', 'QSY4', 'QSY5', 'QSY6', 'QSY7', 'QSY8'};   % QSY* = rolling resistance moment (plan N1: rolling resistance off)
    for i = 1:numel(zeroed), setp(blk, zeroed{i}, 0); end
    setp(blk, 'RCY1', 1); setp(blk, 'REY1', 0); setp(blk, 'REY2', 0);   % combined-slip weight is 1 at zero longitudinal slip
    f = fieldnames(overrides);
    for i = 1:numel(f), setp(blk, f{i}, overrides.(f{i})); end
    info = struct('Fz', Fz, 'Ca', Ca, 'zeroed', {zeroed});
end

function setp(blk, name, val)
    set_param(blk, name, num2str(val, 12));
end
