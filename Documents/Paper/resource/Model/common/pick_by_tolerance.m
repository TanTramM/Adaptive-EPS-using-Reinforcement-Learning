function idx = pick_by_tolerance(R, S, admissible, tol)
%PICK_BY_TOLERANCE Finalists of the shared selection rule of every controller (Tracking/CLAUDE.md, "Quy tac chon tham so").
%
%   idx = pick_by_tolerance(R, S, admissible, tol)
%   R, S         response (RMS e_T) and smoothness (high-passed RMS of T_a) of every candidate, both to be minimized
%   admissible   logical vector: candidates that pass the hard gates
%   tol          tie tolerance (default 0.05 = 5 %)
%   idx          indices (into R, S) of the admissible candidates with R <= (1 + tol) * (smallest admissible R), sorted by INCREASING S.
%                The chosen point is idx(1); a further gate evaluated afterwards (no bang-bang) takes the first of the list that passes.
%   Meaning: response (following T_d,ref) is the first priority; among the points whose response is practically as good as the best of the
%   same controller, take the smoothest.
if nargin < 4, tol = 0.05; end
R = R(:); S = S(:); admissible = logical(admissible(:));
ia = find(admissible);
assert(~isempty(ia), 'pick_by_tolerance: no admissible candidate');
rmin = min(R(ia));
keep = ia(R(ia) <= (1 + tol) * rmin);
[~, o] = sort(S(keep));
idx = keep(o);
end
