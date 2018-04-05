function C = fastIntersect(A,B)
%only works on positive integers
%source: http://www.mathworks.de/matlabcentral/answers/53796
if ~isempty(A)&&~isempty(B)
 P = zeros(1, max(max(A),max(B)) ) ;
 P(A) = 1;
 C = B(logical(P(B)));
else
  C = [];
end