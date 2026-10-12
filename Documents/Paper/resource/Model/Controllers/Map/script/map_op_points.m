function ops = map_op_points()
%MAP_OP_POINTS Operating points (a_y [g], mu) at which the linearized Plant is checked:
%   nearly straight and strong cornering on the dry road, and the same on a slippery road.
ops = [0.001 0.8; 0.3 0.8; 0.001 0.2; 0.15 0.2];
end

