function p = result_dir(varargin)
%RESULT_DIR Folder for saved results, created if missing.
%   p = result_dir('Plant')                  -> <repo>/Result/PRSM/Plant
%   p = result_dir('Map', 'Cases')           -> <repo>/Result/Controllers/Map/Cases
%   p = result_dir('Compare', 'Map_vs_PI')   -> <repo>/Result/Compare/Map_vs_PI
%
%   Layout of <repo>/Result/ (mirrors Model/):
%     PRSM/Plant/, PRSM/Reference/        results of the shared environment
%     Controllers/<Ctrl>/<what>/          results of ONE controller (Design, Calib = Calib_v2 on disk, CalibV1 = Calib on disk, Cases)
%     Compare/<A>_vs_<B>/                 results that compare controllers
%   File naming (rule in Tracking/CLAUDE.md): <Subject>_<CASE>_<what>[_<event>]_<sens>.<png|csv|mat>, e.g. Map_SLIP_resp_s00000.png.
%   Change the root or the layout here only (this is the single place that knows it).

    parts = varargin;
    if any(strcmp(parts{1}, {'Plant', 'Reference'}))
        parts = [{'PRSM'}, parts];
    elseif ~strcmp(parts{1}, 'Compare')
        parts = [{'Controllers'}, parts];
    end
    % CALIB v2 (2026-10-17, QuyChuan 3.1) replaced CALIB v1: 'Calib' now means Result/Controllers/<Ctrl>/Calib_v2 so that no script can read or
    % resume (cached rows) from v1 results; the v1 results stay untouched in Calib/ and are reached with the token 'CalibV1' (reproduction only).
    if numel(parts) >= 3 && strcmp(parts{1}, 'Controllers')
        if strcmp(parts{3}, 'Calib'), parts{3} = 'Calib_v2'; elseif strcmp(parts{3}, 'CalibV1'), parts{3} = 'Calib'; end
        % DREWS v2 (2026-10-22): the token 'CasesV2' is Cases_v2 on disk; 'Cases' stays the folder of DREWS v1 and is never written by v2 runs
        if strcmp(parts{3}, 'CasesV2'), parts{3} = 'Cases_v2'; end
        % DREWS v3 (2026-10-23): the token 'CasesV3' is Cases_v3 on disk
        if strcmp(parts{3}, 'CasesV3'), parts{3} = 'Cases_v3'; end
        % SLIP v4 alone (2026-10-23): the token 'CasesSLIP4' is Cases_slip4 on disk
        if strcmp(parts{3}, 'CasesSLIP4'), parts{3} = 'Cases_slip4'; end
        % SSW (2026-10-23): the token 'CasesSSW' is Cases_ssw on disk
        if strcmp(parts{3}, 'CasesSSW'), parts{3} = 'Cases_ssw'; end
    end
    root = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'Result');   % this file is Model/common/
    p = fullfile(root, parts{:});
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
