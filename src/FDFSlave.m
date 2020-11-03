function FDFSlave(varargin)
datefmt = 'yyyy-mm-dd HH:MM:SS,FFF';
if(~isdeployed())
    addpath(genpath(fullfile(cd)));
end
p = gcp('nocreate');
if(isempty(p))
    nr = version('-release');
    if(str2double(nr(1:4)) >= 2020 && ~isdeployed())
        p = parpool('threads');
    else
        p = parpool('local',min(32,feature('numCores')));
    end
    if(~isempty(p))
        parfevalOnAll(p, @warning, 0, 'off', 'MATLAB:rankDeficientMatrix');
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
while(true)
    try
        timestamp = datestr(now, datefmt);
        fprintf('%s - starting FDFSlave...\n',timestamp);
        startmulticoreslave(path);
    catch ME
        timestamp = datestr(now, datefmt);
        fprintf('%s - FDFSlave caused an error: %s\n',timestamp,ME.message);
    end
end

