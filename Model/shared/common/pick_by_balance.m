function idx = pick_by_balance(R, S, admissible, a)
%PICK_BY_BALANCE Finalists of the balanced selection rule (QuyChuan v5, 2026-10-11): minimize J = R^a * S among the admissible candidates.
%
%   idx = pick_by_balance(R, S, admissible, a)
%   R, S         response (RMS e_T) and smoothness (high-passed RMS of T_a) of every candidate, both to be minimized
%   admissible   logical vector: candidates that pass the hard gates (and the book-sourced constraints of the controller)
%   a            exponent of R (default 1)
%   idx          indices (into R, S) of the admissible candidates sorted by INCREASING J = R^a * S.
%                The chosen point is idx(1); a further gate evaluated afterwards (no bang-bang, margin) takes the first of the list that passes.
%   Meaning (a = 1): moving along the Pareto front, one more percent of noise S must buy at least one percent of tracking R; the rule
%   is dimensionless (independent of the units of R and S) and has no tolerance parameter. Sensitivity: report a = 0.5, 1, 2.
if nargin < 4 || isempty(a), a = 1; end
R = R(:); S = S(:); admissible = logical(admissible(:));
ia = find(admissible);
assert(~isempty(ia), 'pick_by_balance: no admissible candidate');
J = R(ia) .^ a .* S(ia);
[~, o] = sort(J);
idx = ia(o);
end
