function FDFSlave(varargin)
if(~isdeployed())
    addpath(genpath(fullfile(cd,'functions')));
end
if(nargin == 0)
    path = cd;
else
    path = varargin{1,1};
end
disp(path);
pause(rand(1)/2+0.25);
startmulticoreslave(path);

