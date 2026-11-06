function cfg = mapopt_cfg(suffix)
%MAPOPT_CFG Search thresholds of a MapOpt run (DieuKhien_MapOpt.txt Part M, 2026-10-17).
%   cfg = mapopt_cfg('')    run 1: linear PM > 0 and GM >= 1 while searching (the final point must still have PM >= 30, GM >= 2: select_mapopt)
%   cfg = mapopt_cfg('b')   run 2: PM >= 30 deg and GM >= 2 already while searching (same limits as the final gate, so the valid region is explored)
%   Everything else (box, chains, selection rule) is the same in both runs.
if nargin < 1 || isempty(suffix)
    cfg = struct('PMmin', 0, 'GMmin', 1);
else
    cfg = struct('PMmin', 30, 'GMmin', 2);
end
end
