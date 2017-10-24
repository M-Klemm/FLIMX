function [expModels, ao]  = shiftAndLinearOpt(expModels,t,measData,dataNonZeroMask,hShift,tcis,tciHShiftFine,oset,linLB,linUB,fitOsetFlag,optimize4CodegenFlag)
%=============================================================================================================
%
% @file     shiftAndLinearOpt.m
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
% @brief    A function to shift models and compute amps and offset (1024 time channels)
%
nParam = length(linLB);
ao = zeros(1,size(tcis,1)+1,size(expModels,3),'like',t);
linOptFlag = false;
% linInterpFlag = false;
% fitOsetFlag = false;
if(~isempty(measData) && nParam > 0)
    data = measData(dataNonZeroMask);
    linOptFlag = true;
    tmp = ones(length(t),nParam,'like',t);
else
    data = zeros(1,1,'like',t);
    data(:) = [];
    tmp = zeros(1,1,'like',t);
    tmp(:) = [];
end
% tResFactorInterp = 100; nTSample = length(t); tmp2 = tmp; ao2 = ao;
% if(strcmp(interpMethod,'linear'))
%     linInterpFlag = true;
% end
% if(any(oset))
%     fitOsetFlag = true;
% end
% tol=0;
for j = 1:size(expModels,3)
    if(optimize4CodegenFlag)
        %% use this for codegen!
        for i = 1:size(tcis,1)
            expModels(:,i,j) = circshift(expModels(:,i,j),hShift(j) + tcis(i,j));
        end
    else
        %% use this for matlab execution
        expModels(:,:,j) = circShiftArrayNoLUT(squeeze(expModels(:,:,j)),hShift(j) + tcis(:,j));
    end    
    tciFlags = find(diff(tciHShiftFine(:,j)))+1;
    %interpolate
    if(isempty(tciFlags))
        if(abs(tciHShiftFine(1,j)) > eps)
            expModels(:,:,j) = qinterp1(t,expModels(:,:,j),t + (tciHShiftFine(1,j)).*t(2,1),optimize4CodegenFlag);
        end
    else
        if(abs(tciHShiftFine(1,j)) > eps)
            expModels(:,1:tciFlags(1)-1,j) = qinterp1(t,expModels(:,1:tciFlags(1)-1,j),t + (tciHShiftFine(1,j)).*t(2,1),optimize4CodegenFlag);
        end
        for i = 1:length(tciFlags)
            if(abs(tciHShiftFine(tciFlags(i),j)) > eps)
                expModels(:,tciFlags(i),j) = qinterp1(t,expModels(:,tciFlags(i),j),t + (tcis(tciFlags(i),j) + tciHShiftFine(tciFlags(i),j)).*t(2,1),optimize4CodegenFlag);
            end
        end
    end    
%     for i = 1:size(tcis,1)    
%         if(isempty(tciFlags))
%             aI = interp1(1:nTSample,inputSave(:,i,j),linspace(1,nTSample,(nTSample-1)*tResFactorInterp+1));
%             %aI = qinterp1(1:nTSample,expModels(:,i,j),linspace(1,nTSample,(nTSample-1)*tResFactorInterp+1),optimize4CodegenFlag);
%             s2 = round((hShift(j) + tcis(i,j) - tciHShiftFine(1,j))*tResFactorInterp);
%             aI = circshift(aI,s2);
%             inputSave(:,i,j) = single(aI(1:tResFactorInterp:(nTSample-1)*tResFactorInterp+1));            
%         else         
%         end    
%     end
    %determine amplitudes
    if(linOptFlag)        
        if(fitOsetFlag) %fit offset
            %determine amplitudes and offset
            tmp(:,1:nParam-1) = expModels(:,:,j);
            tmp(:,end) = ones(length(t),1,'like',t);
            %ao(1,:,j) = checkBounds(LinNonNeg(tmp(dataNonZeroMask,:),data(:,1)),linLB,linUB);
            ao(1,:,j) = checkBounds(tmp(dataNonZeroMask,:)\data(:,1),linLB,linUB);
        else%offset is already set
            %ao(1,1:nParam,j) = checkBounds(LinNonNeg(expModels(dataNonZeroMask,1:nParam,j),data(:,1)-oset(j)),linLB,linUB);
            ao(1,1:nParam,j) = checkBounds(expModels(dataNonZeroMask,1:nParam,j)\(data(:,1)-oset(j)),linLB,linUB);
            ao(1,end,j) = oset(j);
        end
    end
end