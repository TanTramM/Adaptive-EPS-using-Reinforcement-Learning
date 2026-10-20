function Cal = calibrate_map_cached()
%CALIBRATE_MAP_CACHED Returns the stored Map calibration, caching it in memory.
%   The calibration is part of data/map.json after the Map preparation
%   stage.  Loading it here keeps independent grid-search MATLAB sessions
%   read-only: otherwise every fresh session calls calibrate_map() and the
%   concurrent direct writes to map.json can expose a partial JSON document
%   to another worker.
persistent C
if isempty(C)
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fileparts(fileparts(fileparts(scriptDir)));
    mp = fullfile(modelDir, 'data', 'map.json');
    J = [];
    % A pre-existing legacy process can still be finishing one write when a
    % resumed worker starts.  Retry the read briefly; new sessions below do
    % not write this shared file.
    for attempt = 1:10
        try
            J = jsondecode(fileread(mp));
            break;
        catch ME
            if attempt == 10
                rethrow(ME);
            end
            pause(0.25);
        end
    end
    if isstruct(J) && isfield(J, 'calibration') && isfield(J.calibration, 'points')
        C = fromStoredCalibration(J.calibration, modelDir);
    else
        % Retain the standalone bootstrap path when map.json has not yet
        % been prepared.  It is intentionally not used by the S1 workers.
        C = calibrate_map();
    end
end
Cal = C;
end

function Cal = fromStoredCalibration(S, modelDir)
pts = S.points;
n = numel(pts);
assert(n > 0, 'data/map.json calibration has no points');
Cal = struct('v_kmh', zeros(n, 1), 'ay_g', {cell(n, 1)}, ...
    'Ts', {cell(n, 1)}, 'Tr', {cell(n, 1)}, 'Ta', {cell(n, 1)}, ...
    'slope', {cell(n, 1)}, 'ay_lim_g', zeros(n, 1), ...
    'Ta_max', zeros(n, 1), 'F', NaN);
ref = jsondecode(fileread(fullfile(modelDir, 'data', 'ref.json')));
Cal.F = ref.Ta_max.F_Nm;
for i = 1:n
    Cal.v_kmh(i) = pts(i).v_kmh;
    Cal.ay_g{i} = pts(i).ay_g(:)';
    Cal.Ts{i} = pts(i).Ts_Nm(:)';
    Cal.Ta{i} = pts(i).Ta_Nm(:)';
    assert(numel(Cal.ay_g{i}) == numel(Cal.Ts{i}) && ...
        numel(Cal.Ts{i}) == numel(Cal.Ta{i}), ...
        'data/map.json calibration point %d has inconsistent vector sizes', i);
    Cal.Tr{i} = Cal.Ts{i} + Cal.Ta{i};
    Cal.slope{i} = [NaN, diff(Cal.Ta{i}) ./ diff(Cal.Ts{i})];
    Cal.ay_lim_g(i) = max(Cal.ay_g{i});
    Cal.Ta_max(i) = interp1(ref.Ta_max.v_kmh(:), ref.Ta_max.Ta_max_Nm(:), Cal.v_kmh(i), 'linear');
end
end

