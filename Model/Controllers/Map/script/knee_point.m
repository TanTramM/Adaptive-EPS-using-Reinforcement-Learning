function [front, kneeIdx] = knee_point(R, S)
%KNEE_POINT Pareto front of (R, S), both to be minimized, and its knee.
%
%   [front, kneeIdx] = knee_point(R, S)
%   front    indices (into R, S) of the non-dominated points, sorted by increasing R
%   kneeIdx  index (into R, S) of the knee: normalize R and S to [0,1] on the front, draw the line between its two ends and take the point
%            farthest BELOW the line (largest distance toward the origin). A front with fewer than 3 points returns the point with the
%            smallest normalized R+S.
R = R(:); S = S(:);
n = numel(R);
dom = false(n, 1);
for i = 1:n
    dom(i) = any(R <= R(i) & S <= S(i) & (R < R(i) | S < S(i)));
end
front = find(~dom);
[~, o] = sort(R(front)); front = front(o);
if numel(front) < 3
    rn = (R(front) - min(R(front))) ./ max(range(R(front)), eps);
    sn = (S(front) - min(S(front))) ./ max(range(S(front)), eps);
    [~, j] = min(rn + sn); kneeIdx = front(j); return;
end
rn = (R(front) - min(R(front))) / range(R(front));
sn = (S(front) - min(S(front))) / range(S(front));
% line from the first (smallest R, largest S) to the last point (largest R, smallest S); distance below it
p1 = [rn(1) sn(1)]; p2 = [rn(end) sn(end)]; dvec = p2 - p1; nrm = norm(dvec);
dist = ((rn - p1(1)) * dvec(2) - (sn - p1(2)) * dvec(1)) / nrm;     % positive below the line (toward the origin)
[~, j] = max(dist);
kneeIdx = front(j);
end

