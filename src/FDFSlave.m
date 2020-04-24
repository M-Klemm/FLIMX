function FDFSlave(varargin)
if(~isdeployed())
    addpath(genpath(fullfile(cd)));
    p = gcp('nocreate');
    if(isempty(p))
        nr = version('-release');
        if(str2double(nr(1:4)) >= 2020)
            parpool('threads');
        else
            parpool('local',feature('numCores'));
        end
    end
end
if(nargin == 0)
    path = cd;
else
    path = varargin{1,1};
end
warning('off','MATLAB:rankDeficientMatrix');
disp(path);
pause(rand(1)/2+0.25);
startmulticoreslave(path);

