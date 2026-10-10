function [R, S, S_cmd, TV, maxTa, maxEt, satFrac, revFrac, nonfinite, erelWin, RWin, refWin, cntWin] = gates_fcn(T_s, T_d_ref, T_a, T_a_cmd, T_a_lim, winId) %#codegen
%GATES_FCN Running calibration scores of the closed loop (QuyChuan.txt part 4 and 5). Source of the MATLAB Function block in Gates.mdl.
%
%   Called once per sample (fixed step Ts = 1 ms, the grid of the test cases) with the TRUE signals; every output is the score of the
%   run SO FAR, so the value at the last sample is the score of the whole case. The block only reads signals (no output goes back to the
%   loop): it is a measuring instrument for calibration, not part of the real controller model.
%
%   Inputs  T_s, T_d_ref   true column torque and its set value  [N.m]
%           T_a            applied assist torque (after the motor lag)  [N.m]
%           T_a_cmd        controller command (before the Actuator limit)  [N.m]
%           T_a_lim        command after the assist limit T_a,max(v)  [N.m]
%           winId          scoring window of the sample: 0 = none, 1..NW = window number (steady / sine / small ... of the case)
%   Outputs R         RMS of e_T = T_s - T_d_ref pooled over all samples with winId > 0        [N.m]   (the case score R of QuyChuan 4.1 is the
%                     mean of four group errors 100 RMS(e_T) / mean|T_d_ref|; it is formed OUTSIDE the block from RWin, refWin, cntWin
%                     because the block does not know which window belongs to which group)
%           S, S_cmd  RMS of T_a, T_a_cmd high-passed at 5 Hz over the samples from 2 s       [N.m]   4.2, 4.3
%           TV        total variation of T_a per second from 2 s                              [N.m/s] 4.3
%           maxTa     largest |T_a| from 2 s                                                  [N.m]   4.5(d), 4.7
%           maxEt     largest |e_T| over the whole run                                        [N.m]
%           satFrac   fraction of samples from 2 s where the command is clamped (|T_a_cmd| > |T_a_lim|)  [-]  5.4 (bang-bang: compare a
%                     noisy run with an ideal run, outside this block)
%           revFrac   fraction of samples from 2 s with |T_s| >= 0.5 N.m and T_a against T_s  [-]  4.6, 5.5
%           nonfinite 1 if any input was NaN or Inf at any sample, else 0                      5.1
%           erelWin   per window: 100 |mean e_T| / mean |T_d_ref|  [%]   (4.4; the case decides which windows are steady)
%           RWin      per window: RMS e_T  [N.m]
%           refWin    per window: mean |T_d_ref|  [N.m]
%           cntWin    per window: number of samples  [-]
%   Only the quantities that need no knowledge of the case are computed here; the pass/fail thresholds are applied outside (check script).

NW = 32;            % number of windows the block can score
Ts = 0.001;         % sample time [s]
tSkip = 2;          % first seconds not scored [s]
fHp = 5;            % high-pass corner [Hz]
tolSat = 1e-9;      % margin by which the command must exceed the limit to count as clamped (rounding of interpolated signals) [N.m]
tolRev = 0.5;       % |T_s| above which a T_a against T_s counts as reverse assist [N.m]

persistent k lpTa lpCmd prevTa nSc sumS2 sumSc2 sumDTa maxA maxE nSat nRev nonf sumE sumAbsRef sumE2 cnt
if isempty(k)
    k = 0; lpTa = 0; lpCmd = 0; prevTa = 0; nSc = 0; sumS2 = 0; sumSc2 = 0; sumDTa = 0; maxA = 0; maxE = 0;
    nSat = 0; nRev = 0; nonf = 0;
    sumE = zeros(NW, 1); sumAbsRef = zeros(NW, 1); sumE2 = zeros(NW, 1); cnt = zeros(NW, 1);
end

e_T = T_s - T_d_ref;
if ~(isfinite(T_s) && isfinite(T_d_ref) && isfinite(T_a) && isfinite(T_a_cmd) && isfinite(T_a_lim))
    nonf = 1;
else
    a = Ts / (1 / (2 * pi * fHp) + Ts);              % first-order low-pass weight, as in tk_run.m
    lpTa  = (1 - a) * lpTa  + a * T_a;               % same as filter(a, [1 -(1-a)], x) started at 0
    lpCmd = (1 - a) * lpCmd + a * T_a_cmd;
    maxE = max(maxE, abs(e_T));

    w = round(winId);
    if w >= 1 && w <= NW
        sumE(w) = sumE(w) + e_T;
        sumAbsRef(w) = sumAbsRef(w) + abs(T_d_ref);
        sumE2(w) = sumE2(w) + e_T^2;
        cnt(w) = cnt(w) + 1;
    end

    if k * Ts >= tSkip
        hp = T_a - lpTa; hpc = T_a_cmd - lpCmd;
        sumS2 = sumS2 + hp^2; sumSc2 = sumSc2 + hpc^2;
        if nSc > 0, sumDTa = sumDTa + abs(T_a - prevTa); end
        maxA = max(maxA, abs(T_a));
        if abs(T_a_cmd) > abs(T_a_lim) + tolSat, nSat = nSat + 1; end
        if abs(T_s) >= tolRev && T_a * T_s < 0, nRev = nRev + 1; end
        nSc = nSc + 1;
    end
    prevTa = T_a;
end
k = k + 1;

nWin = sum(cnt);
R = 0; if nWin > 0, R = sqrt(sum(sumE2) / nWin); end
S = 0; S_cmd = 0; TV = 0; satFrac = 0; revFrac = 0;
if nSc > 0
    S = sqrt(sumS2 / nSc); S_cmd = sqrt(sumSc2 / nSc);
    satFrac = nSat / nSc; revFrac = nRev / nSc;
end
if nSc > 1, TV = sumDTa / ((nSc - 1) * Ts); end
maxTa = maxA; maxEt = maxE; nonfinite = nonf;
erelWin = zeros(NW, 1); RWin = zeros(NW, 1); refWin = zeros(NW, 1); cntWin = cnt;
for i = 1:NW
    if cnt(i) > 0
        refWin(i) = sumAbsRef(i) / cnt(i);
        erelWin(i) = 100 * abs(sumE(i) / cnt(i)) / max(sumAbsRef(i) / cnt(i), eps);
        RWin(i) = sqrt(sumE2(i) / cnt(i));
    end
end
end
