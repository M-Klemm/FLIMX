function [ao,ampsOut,osetOut] = computeAmplitudes(expModels,measData,dataNonZeroMask,oset,fitOsetFlag,linLB,linUB)
%=============================================================================================================
%
% @file     computeAmplitudes.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     June, 2018
%
% @section  LICENSE
%
% Copyright (C) 2018, Matthias Klemm. All rights reserved.
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
% @brief    A function to compute amplitude of exponential functions to fit their sum to the measurement data

nParams = size(expModels,2);
%nTimePoints = size(expModels,1);

if(size(measData,2) > 1 && size(expModels,3) == 1)
    %use the same model for all data pixels
    singleModelFlag = true;
    nVecs = size(measData,2);
elseif(size(expModels,3) == size(measData,2))
    %compute a different model for each pixel
    singleModelFlag = false;
    nVecs = size(measData,2);
elseif(size(measData,2) == 1 && size(expModels,3) > 1)
    %compute multiple models for one pixel
    singleModelFlag = false;
    nVecs = size(expModels,3);
else
    %throw error
    error('FLIMX:computeAmplitudes','Invalid model or measurement data')
end
nData = size(measData,2);
if(fitOsetFlag)
    ao = zeros(1,nParams,nVecs,'like',expModels);
else
    ao = zeros(1,nParams-1,nVecs,'like',expModels);
end
if(~isempty(measData) && nParams > 0)
    %data = measData(dataNonZeroMask);    
    %tmp = ones(nTimePoints,nParams,'like',expModels);
else
    ampsOut = double(squeeze(ao(1,1:end-1,:)));
    osetOut = double(squeeze(ao(1,end,:))');
    return
end
if(isempty(linLB))
    linLB = zeros(nParams,1,'like',expModels);
    linUB = inf(nParams,1,'like',expModels);
else
%     mMax = squeeze(max(expModels(:,1:nParams-1,:),[],1));
%     if(isvector(mMax))
%         mMax = mMax';
%     end    
%     linLB = linLB(1:nParams-1,:)./mMax;
%     linUB = linUB(1:nParams-1,:)./mMax;
end
if(fitOsetFlag)
    if(singleModelFlag)
        expModels(:,end) = ones(size(expModels,1),1,'like',expModels);
    else
        expModels(:,end,:) = ones(size(expModels,1),nVecs,'like',expModels);
    end
% else
%     ao(1,end,:) = ones(1,nVecs,'like',expModels).*oset;
end
%determine amplitudes
if(isa(expModels,'gpuArray'))
%     gpuFlag = true;
    nVecs = gpuArray(nVecs);
    nParams = gpuArray(nParams);
    nData = gpuArray(nData);
else
%     gpuFlag = false;
end
if(singleModelFlag)
    %todo: add aplitude bounds check for all data in ao (not only those in for loop
    if(fitOsetFlag)
        dA = decomposition(expModels);
        ao(1,:,:) = dA\measData;
        idx = find(any(ao(1,:,:) < 0,2));
        for j = 1:length(idx)
            tmp = LinNonNeg(expModels(dataNonZeroMask(:,idx(j)),:),(measData(dataNonZeroMask(:,idx(j)),idx(j))));
            ao(1,:,idx(j)) = checkBounds(tmp,sum(tmp(:),1).*linLB(:,1),sum(tmp(:),1).*linUB(:,1));
        end
    else
        measData = measData - oset;
        dA = decomposition(expModels(:,1:nParams-1));
        ao(1,:,:) = dA\measData;
        idx = find(any(ao(1,:,:) < 0,2));
        for j = 1:length(idx)
            tmp = LinNonNeg(expModels(dataNonZeroMask(:,idx(j)),1:nParams-1),(measData(dataNonZeroMask(:,idx(j)),idx(j))));
            ao(1,:,idx(j)) = checkBounds(tmp,sum(tmp(:),1).*linLB(1:nParams-1,1),sum(tmp(:),1).*linUB(1:nParams-1,1));
        end
    end
    
else
    for j = 1:nVecs
        %     if(singleModelFlag)
        %         idxExpModel = ones(1,1,'like',expModels);
        %         idxData = j;
        %     else
        idxExpModel = j;
        idxData = min(j,nData);
        %     end
        if(fitOsetFlag)
            %determine amplitudes and offset
            %ao(1,:,j) = checkBounds(LinNonNeg(expModels(dataNonZeroMask(:,idxData),idxExpModel),measData(dataNonZeroMask(:,idxData),idxData)),linLB,linUB);
            tmp = LinNonNeg(expModels(dataNonZeroMask(:,idxData),:,idxData),measData(dataNonZeroMask(:,idxData),idxData));
            ao(1,:,j) = checkBounds(tmp,sum(tmp(:)).*linLB(1:nParams,idxData),sum(tmp(:)).*linUB(1:nParams,idxData));
        else
            %determine amplitudes only, offset is already set
            %ao(1,1:nParams-1,j) = checkBounds(expModels(dataNonZeroMask(:,idxData),1:nParams-1,idxExpModel)\(measData(dataNonZeroMask(:,idxData),idxData)-oset(idxExpModel)),linLB(1:nParams-1,:),linUB(1:nParams-1,:));
            tmp = LinNonNeg(expModels(dataNonZeroMask(:,idxData),1:nParams-1,idxExpModel),(measData(dataNonZeroMask(:,idxData),idxData)-oset(idxExpModel)));
            ao(1,:,j) = checkBounds(tmp,sum(tmp(:)).*linLB(1:nParams-1,idxData),sum(tmp(:)).*linUB(1:nParams-1,idxData));
        end
    end
end
if(~fitOsetFlag)
    ao(1,end+1,:) = ones(1,nVecs,'like',expModels).*oset;
end
ampsOut = squeeze(ao(1,1:end-1,:)); %double(squeeze(ao(1,1:bp.nExp,:)));
if(nVecs == 1)
    ampsOut = ampsOut(:);
end
osetOut = squeeze(ao(1,end,:))';
end

