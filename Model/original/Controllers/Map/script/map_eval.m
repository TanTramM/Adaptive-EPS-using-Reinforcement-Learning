function y = map_eval(M, Ts)
%MAP_EVAL Evaluates assist from map_table: sgn(T_s) * M(|T_s|).
%   Linear interpolation, saturated beyond the last breakpoint, zero in dead zone |T_s| <= M.Ts0.
a = abs(Ts);
y = interp1(M.Ts, M.Ta, min(a, M.Ts(end)), 'linear', 0) .* sign(Ts);
y(a <= M.Ts(1)) = 0;
end

