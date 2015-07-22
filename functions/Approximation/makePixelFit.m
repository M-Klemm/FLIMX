function result = makePixelFit(apObjs,optimizationParams,aboutInfo)
%=============================================================================================================
%
% @file     makePixelFit.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     July, 2015
%
% @section  LICENSE
%
% Copyright (C) 2015, Matthias Klemm. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that
% the following conditions are met:
%     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%       following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%       the following disclaimer in the documentation and/or other materials provided with the distribution.
%     * Neither the name of FLIMX authors nor the names of its contributors may be used
%       to endorse or promote products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
%
% @brief    A function to fit a single pixel or a vector of pixels
%
%check if core version is compatible
myAboutInfo = FLIMX.getVersionInfo();
nrPixels = length(apObjs);
result = [];
if(nrPixels < 1 || ~iscell(apObjs))
    return
end
if(isdeployed())
    %check GPU support
    warning('off','parallel:gpu:DeviceCapability');
    GPUList = [];
    if(apObjs{1}.computationParams.useGPU && isGpuAvailable())
        for i = 1:gpuDeviceCount
            info = gpuDevice(i);
            if(info.DeviceSupported)
                GPUList = [GPUList i];
            end
        end
    end
    for i = 1:nrPixels
        apObjs{i}.volatilePixelParams.compatibleGPUs = GPUList;
    end 
%     if(isempty(ini))
%         ini = paramMgr.ini2struct(fullfile('config','config.ini'));
%     end
    if(apObjs{1}.computationParams.useMatlabDistComp > 0)
        %check if matlabpool is open
        if(isempty(gcp('nocreate')))
            parpool('local');
        end
    end
% else
%     if(isempty(ini))
%         ini = paramMgr.ini2struct(fullfile(cd,'config','config.ini'));
%     end
end
for i = 1:nrPixels
    apObjs{i}.checkGPU;
    apObjs{i}.checkMexFiles();
end
if(aboutInfo.core_revision ~= myAboutInfo.core_revision)
    warning('FluoDecayFit:mcOpt:coreVersionMismatch', 'Revision of this core (%01.2f) does not match the core revision of calling client (%01.2f)! Skipping computation...',...
        myAboutInfo.core_revision,aboutInfo.core_revision);
    if(myAboutInfo.core_revision < aboutInfo.core_revision)
        verb = 'newer';
    else
        verb = 'too old';
    end
    result = sprintf('Parameter approximation skipped due to version mismatch. This core: %01.2f - calling client: (%01.2f). Your core version is %s!',...
        myAboutInfo.core_revision/100,aboutInfo.core_revision/100,verb);
    return
end
%compatible core
if(nrPixels > 1 && apObjs{1}.computationParams.useMatlabDistComp > 0 && apObjs{1}.basicParams.optimizerInitStrategy ~= 3)
    %run pixels in parallel
    parfor i = 1:nrPixels
        tmp(i,:) = runOpt(apObjs(i),optimizationParams);
        %fprintf('iter %d finished\n',i);
    end
else
    %no parallelization
    for i = 1:nrPixels
        tmp(i,:) = runOpt(apObjs(i),optimizationParams);
    end
end
if(isempty(tmp))    
    return
end
%rebuild results structure
for i = 1:nrPixels
    for ch = 1:length(apObjs{1}.nonEmptyChannelList)
        fn = fieldnames(tmp(i,ch));
        fn = fn(~strcmpi(fn,'ROI_merge_result'));
        %fn = fn(~strcmpi(fn,'Message'));
        for j = 1:length(fn)
            result(ch).(fn{j})(i,:) = tmp(i,ch).(fn{j});
        end
    end
end