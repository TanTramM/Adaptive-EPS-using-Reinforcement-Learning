function Cal = calibrate_map_cached()
%CALIBRATE_MAP_CACHED Returns calibrate_map output, caching in persistent memory for speed.
persistent C
if isempty(C)
    C = calibrate_map();
end
Cal = C;
end

