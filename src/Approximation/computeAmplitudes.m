function [ao,ampsOut,osetOut] = computeAmplitudes(expModels,measData,dataNonZeroMask,oset,fitOsetFlag)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here
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
        %ao(1,:,j) = checkBounds(tmp(dataNonZeroMask(:,idxData),:)\measData(dataNonZeroMask(:,idxData),idxData),linLB,linUB);
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

