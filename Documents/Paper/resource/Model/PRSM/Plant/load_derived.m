%% load_derived.m
% Compute DERIVED quantities (lumped symbols, NOT raw parameters from
% params.json) that do NOT change over time within one simulation run
% (they only depend on fixed vehicle parameters, not on v/mu/dynamic
% states). Computed ONCE here instead of every Simulink simulation step.
%
% NOT meant to be run directly - called AUTOMATICALLY by load_plant.m (at
% the end of that script), after raw parameters are already in the base
% workspace.
%
% Derived quantities:
%   F_zf = m*g*l_r/(l_f+l_r)   - static front-axle load (Eq.(4),
%                                 Documents/Cum2_Pacejka.txt, Section 2).
%                                 Used in Cluster2/TireForces (D_f) AND
%                                 Cluster2/AligningTorque (build_cum2.m).
%   F_zr = m*g*l_f/(l_f+l_r)   - static rear-axle load (Eq.(5)), used in
%                                 Cluster2/TireForces (D_r).
%   e_c  = e_p0 - t_0          - caster trail, the part of the aligning-torque arm that does not shrink with the
%                                 slip angle (Documents/Plant/plant.txt Eq.(17)); used in Cluster2/AligningTorque.

m_   = evalin('base', 'm');
g_   = evalin('base', 'g');
l_f_ = evalin('base', 'l_f');
l_r_ = evalin('base', 'l_r');

F_zf = m_ * g_ * l_r_ / (l_f_ + l_r_);
assignin('base', 'F_zf', F_zf);

F_zr = m_ * g_ * l_f_ / (l_f_ + l_r_);
assignin('base', 'F_zr', F_zr);

e_c = evalin('base', 'e_p0') - evalin('base', 't_0');   % caster trail: constant part of the aligning-torque arm
assignin('base', 'e_c', e_c);

fprintf('Computed derived quantities (load_derived.m): F_zf=%.6g N, F_zr=%.6g N\n', F_zf, F_zr);
