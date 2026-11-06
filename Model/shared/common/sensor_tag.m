function s = sensor_tag(runSeed)
%SENSOR_TAG Sensor-mode token used in result file names (naming rule of Tracking/CLAUDE.md).
%   sensor_tag([])     -> 'ideal'   (no seed = ideal sensors)
%   sensor_tag(99999)  -> 's99999'  (noisy sensors, run seed 99999; always 5 digits)
    if isempty(runSeed)
        s = 'ideal';
    else
        s = sprintf('s%05d', runSeed);
    end
end
