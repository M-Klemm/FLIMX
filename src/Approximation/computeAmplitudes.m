function [ao,ampsOut,osetOut] = computeAmplitudes(expModels,measData,dataNonZeroMask,oset,fitOsetFlag)
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
nTimePoints = size(expModels,1);
if(~isempty(measData) && nParams > 0)
    %data = measData(dataNonZeroMask);    
    %tmp = ones(nTimePoints,nParams,'like',expModels);
else
    return
end
if(size(measData,2) == 1 && size(expModels,3) > 1)
    %use the same model for all data pixels
    multiModelsFlag = true;
    nVecs = size(expModels,3);
else
    %use a different model for each pixel
    multiModelsFlag = false;
    nVecs = size(measData,2);
end
ao = zeros(1,nParams,nVecs,'like',expModels);    
linLB = zeros(nParams,1,'like',expModels);
linUB = inf(nParams,1,'like',expModels);
if(fitOsetFlag)
    expModels(:,end,:) = 1;
else
    ao(1,end,:) = ones(1,nVecs).*oset;
end
%determine amplitudes
for j = 1:nVecs
    if(multiModelsFlag)
        idxExpModel = j;
        idxData = 1;
    else
        idxExpModel = 1;
        idxData = j;
    end
    if(fitOsetFlag)
        %determine amplitudes and offset
%         tmp(:,1:nParams-1) = expModels(:,:,idxExpModel);
%         tmp(:,end) = ones(nTimePoints,1,'like',expModels);
        ao(1,:,j) = checkBounds(LinNonNeg(expModels(dataNonZeroMask(:,idxData),idxExpModel),measData(dataNonZeroMask(:,idxData),idxData)),linLB,linUB);
        %ao(1,:,j) = checkBounds(expModels(dataNonZeroMask(:,idxData),:)\measData(dataNonZeroMask(:,idxData),idxData),linLB,linUB);
    else 
        %determine amplitudes only, offset is already set
        %ao(1,1:nParams-1,j) = checkBounds(expModels(dataNonZeroMask(:,idxData),1:nParams-1,idxExpModel)\(measData(dataNonZeroMask(:,idxData),idxData)-oset(idxExpModel)),linLB(1:nParams-1,:),linUB(1:nParams-1,:));
        ao(1,1:nParams-1,j) = checkBounds(LinNonNeg(expModels(dataNonZeroMask(:,idxData),1:nParams-1,idxExpModel),(measData(dataNonZeroMask(:,idxData),idxData)-oset(idxExpModel))),linLB(1:nParams-1,:),linUB(1:nParams-1,:));
        %tmp = zeros(nParams,1,'like',expModels);
        %tmp(1:nParams-1,1) = checkBounds(LinNonNeg(expModels(dataNonZeroMask(:,idxData),1:nParams-1,idxExpModel),(measData(dataNonZeroMask(:,idxData),idxData)-oset(idxExpModel))),linLB(1:nParams-1,:),linUB(1:nParams-1,:));
        %tmp(end,1) = oset(idxExpModel);
        %ao(1,:,j) = tmp;
    end
end
%compute model
% if(bp.approximationTarget == 2 && bp.anisotropyR0Method == 3 && this.myChannelNr == 4)
%     %%heikal
%     z = zeros(nTimeCh,nVecs);
%     n = zeros(nTimeCh,nVecs);
%     for i = 1:2:nExp
%         z = z + bsxfun(@times,squeeze(exponentialsOffset(:,i,1:nVecs)),amps(i,:)) .* bsxfun(@times,squeeze(exponentialsOffset(:,i+1,1:nVecs)),amps(i+1,:));
%         n = n + bsxfun(@times,squeeze(exponentialsOffset(:,i,1:nVecs)),amps(i,:));
%     end
%     model = (z./n + bsxfun(@times,squeeze(exponentialsOffset(:,end,1:nVecs)),oset));% .* this.dMaxVal;
%     model(isnan(model)) = 0;
%     ampsOut = double(amps);
%     osetOut = double(oset);
%     scAmpsOut = zeros(0,nVecs);
% else
%     if(~any(vcp.cMask < 0))
%         ao(1,:,:) = [amps; scAmps; oset];
%     end
%     if(vpp.nScatter > 0)
%         scAmpsOut = double(squeeze(ao(1,bp.nExp+1:bp.nExp+vpp.nScatter,:)));
%     else
%         scAmpsOut = zeros(0,nVecs);
%     end
%     expModels(isnan(expModels)) = 0;
%     expModels(:,:,1:nVecs) = bsxfun(@times,expModels(:,:,1:nVecs),ao);
%     model = squeeze(sum(expModels(:,:,1:nVecs),2));
%     if(bp.heightMode == 2)
%         %force model to maximum of data
%         model = bsxfun(@times,model, 1./max(model,[],1)).*this.dMaxVal;
%     end
ampsOut = double(squeeze(ao(1,1:end-1,:))); %double(squeeze(ao(1,1:bp.nExp,:)));
osetOut = double(squeeze(ao(1,end,:))');
% end


end

