function [p,S,mu] = polyfit_tTest(x,y,n)
%POLYFIT Fit polynomial to data.
%   P = POLYFIT(X,Y,N) finds the coefficients of a polynomial P(X) of
%   degree N that fits the data Y best in a least-squares sense. P is a
%   row vector of length N+1 containing the polynomial coefficients in
%   descending powers, P(1)*X^N + P(2)*X^(N-1) +...+ P(N)*X + P(N+1).
%
%   [P,S] = POLYFIT(X,Y,N) returns the polynomial coefficients P and a
%   structure S for use with POLYVAL to obtain error estimates for
%   predictions.  S contains fields for the triangular factor (R) from a QR
%   decomposition of the Vandermonde matrix of X, the degrees of freedom
%   (df), and the norm of the residuals (normr).  If the data Y are random,
%   an estimate of the covariance matrix of P is (Rinv*Rinv')*normr^2/df,
%   where Rinv is the inverse of R.
%
%   [P,S,MU] = POLYFIT(X,Y,N) finds the coefficients of a polynomial in
%   XHAT = (X-MU(1))/MU(2) where MU(1) = MEAN(X) and MU(2) = STD(X). This
%   centering and scaling transformation improves the numerical properties
%   of both the polynomial and the fitting algorithm.
%
%   Warning messages result if N is >= length(X), if X has repeated, or
%   nearly repeated, points, or if X might need centering and scaling.
%
%   Class support for inputs X,Y:
%      float: double, single
%
%   See also POLY, POLYVAL, ROOTS, LSCOV.

%   Copyright 1984-2011 The MathWorks, Inc.
%   $Revision: 5.17.4.14 $  $Date: 2011/05/17 02:32:30 $

% The regression problem is formulated in matrix format as:
%
%    y = V*p    or
%
%          3  2
%    y = [x  x  x  1] [p3
%                      p2
%                      p1
%                      p0]
%
% where the vector p contains the coefficients to be found.  For a
% 7th order polynomial, matrix V would be:
%
% V = [x.^7 x.^6 x.^5 x.^4 x.^3 x.^2 x ones(size(x))];

if ~isequal(size(x),size(y))
    error(message('MATLAB:polyfit:XYSizeMismatch'))
end

x = x(:);
y = y(:);

if nargout > 2
   mu = [mean(x); std(x)];
   x = (x - mu(1))/mu(2);
end

% Construct Vandermonde matrix.
V(:,n+1) = ones(length(x),1,class(x));
for j = n:-1:1
   V(:,j) = x.*V(:,j+1);
end

% Solve least squares problem.
[Q,R] = qr(V,0);
ws = warning('off','all'); 
p = R\(Q'*y);    % Same as p = V\y;
warning(ws);
if size(R,2) > size(R,1)
   warning(message('MATLAB:polyfit:PolyNotUnique'))
elseif warnIfLargeConditionNumber(R)
    if nargout > 2
        warning(message('MATLAB:polyfit:RepeatedPoints'));
    else
        warning(message('MATLAB:polyfit:RepeatedPointsOrRescale'));
    end
end

if nargout > 1
    r = y - V*p;
    % S is a structure containing three elements: the triangular factor from a
    % QR decomposition of the Vandermonde matrix, the degrees of freedom and
    % the norm of the residuals.
    S.R = R;
    S.df = max(0,length(y) - (n+1));
    S.normr = norm(r);
    S.tScore = (p(1)*sqrt(length(x)-2)) / sqrt(sum(r(:).^2)/sum((x(:)-mean(x(:))).^2));
    S.significant = S.tScore > icdf('t',1-0.025,length(x)-2);
    rx = x-mean(x);
    ry = y-mean(y);
    S.R2 = (sum(rx.*ry)/sqrt(sum(rx.^2)*sum(ry.^2))).^2;
    s2 = sqrt(sum(r.^2/(length(x)-2)) * (1/length(x) + rx.^2./sum(rx.^2)));
    t = icdf('t',1-(1-0.95)/2,length(x)-2);
    S.CImeanLow = p(1)-mean(s2*t);
    S.CImeanHigh = p(1)+mean(s2*t);
end

p = p.';          % Polynomial coefficients are row vectors by convention.

function flag = warnIfLargeConditionNumber(R)
if isa(R, 'double')
    flag = (condest(R) > 1e+10);
else
    flag = (condest(R) > 1e+05);
end
