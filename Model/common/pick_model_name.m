function name = pick_model_name(folder, baseName, overwrite)
%PICK_MODEL_NAME Name under which a build_*.m script saves its model, so a generated file never silently replaces an existing one.
%
%   name = pick_model_name(folder, 'Tires', false)
%     overwrite = true  : returns 'Tires'; the caller replaces <folder>/Tires.mdl (and closes it first if it is loaded)
%     overwrite = false : returns 'Tires' if <folder>/Tires.mdl does not exist yet, otherwise 'Tires_1', or 'Tires_2', ...
%                         (the first free number), so the existing file (possibly hand-edited) is left untouched
%
%   Every PRSM build script takes the same optional argument: build_cum2(true) overwrites, build_cum2() / build_cum2(false) does not.

if nargin < 3, overwrite = false; end
name = baseName;
if overwrite || ~exist(fullfile(folder, [name '.mdl']), 'file') && ~bdIsLoaded(name)
    return;
end
k = 1;
while exist(fullfile(folder, sprintf('%s_%d.mdl', baseName, k)), 'file') || bdIsLoaded(sprintf('%s_%d', baseName, k))
    k = k + 1;
end
name = sprintf('%s_%d', baseName, k);
end
