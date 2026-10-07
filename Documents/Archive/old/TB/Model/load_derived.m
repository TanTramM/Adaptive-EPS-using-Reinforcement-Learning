%% load_derived.m
% Compute DERIVED quantities (lumped symbols, NOT raw parameters from
% params.json) that do NOT change over time within one simulation run
% (they only depend on fixed vehicle parameters, not on v/mu/dynamic
% states). Computed ONCE here instead of every Simulink simulation step.
%
% NOT meant to be run directly - called AUTOMATICALLY by load_params.m (at
% the end of that script), after raw parameters are already in the base
% workspace.
%
% Derived quantities:
%   F_zf = m*g*l_r/(l_f+l_r)   - static front-axle load (Eq.(7),
%                                 Documents/Cum2_Pacejka.txt, Section 2).
%                                 Used in Cluster2/TireForces AND
%                                 Cluster2/AligningTorque (build_cum2.m).

m_   = evalin('base', 'm');
g_   = evalin('base', 'g');
l_f_ = evalin('base', 'l_f');
l_r_ = evalin('base', 'l_r');

F_zf = m_ * g_ * l_r_ / (l_f_ + l_r_);
assignin('base', 'F_zf', F_zf);

fprintf('Computed derived quantities (load_derived.m): F_zf=%.6g N\n', F_zf);
