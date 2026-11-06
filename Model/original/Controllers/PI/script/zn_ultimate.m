function [Kcu, Pu] = zn_ultimate()
%ZN_ULTIMATE Ultimate gain and period of the loop under proportional-only control (Ziegler-Nichols continuous cycling,
%   Seborg et al., Process Dynamics and Control, Section 12.5.1 and Table 12.7), measured on the linear plant of pi_plant_lin.m.
%
%   [Kcu, Pu] = zn_ultimate()
%   Loop: 1 ms zero-order hold, one sample of computation delay, motor lag; both tire surfaces (dry k_r and saturated k_r = 0).
%   Kcu is the smallest ultimate gain of the two surfaces, Pu the largest ultimate period (the conservative choice for the
%   constraints Ti >= Pu/1.2 (PI) and Ti >= Pu/2 (PID) of QuyChuan v5).

Ts = 0.001;
[G1c, G0c] = pi_plant_lin();
z = tf('z', Ts);
Kcu = Inf; Pu = 0;
for Gc = {G1c, G0c}
    L = (1 / z) * c2d(Gc{1}, Ts, 'zoh');
    s = allmargin(L);
    gm = s.GainMargin; wf = s.GMFrequency;
    ok = isfinite(gm) & gm > 0 & wf > 0 & wf < pi / Ts * 0.9;      % ignore the Nyquist crossing at 500 Hz
    [g1, j] = min(gm(ok));
    w1 = wf(ok); w1 = w1(j);
    Kcu = min(Kcu, g1);
    Pu = max(Pu, 2 * pi / w1);
end
end
