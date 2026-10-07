function p = result_dir(varargin)
%RESULT_DIR Folder for saved results, created if missing.
%   p = result_dir('Plant')                  -> <repo>/Result/PRSM/Plant
%   p = result_dir('Map', 'TestCases')       -> <repo>/Result/Controllers/Map/TestCases
%   p = result_dir('Compare', 'Map_vs_PI')   -> <repo>/Result/Compare/Map_vs_PI
%
%   Layout of <repo>/Result/ (mirrors Model/):
%     PRSM/Plant/, PRSM/Reference/        results of the shared environment
%     Controllers/<Ctrl>/<what>/          results of ONE controller (Design, Sweep, TestCases, TestCases_noise ...)
%     Compare/<A>_vs_<B>/                 results that compare controllers
%   File naming: <Subject>_<what>_<condition>.<png|csv|mat>, e.g. Map_TC1_dry_calibration_time_response.png.
%   Change the root or the layout here only (this is the single place that knows it).

    parts = varargin;
    if any(strcmp(parts{1}, {'Plant', 'Reference'}))
        parts = [{'PRSM'}, parts];
    elseif ~strcmp(parts{1}, 'Compare')
        parts = [{'Controllers'}, parts];
    end
    root = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'Result');   % this file is Model/common/
    p = fullfile(root, parts{:});
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
