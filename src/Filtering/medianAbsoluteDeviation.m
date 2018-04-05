function out = medianAbsoluteDeviation(data)
%threshold taken from isoutlier
c=-1/(sqrt(2)*erfcinv(3/2));
out = c*median(abs(data-median(data)));
end