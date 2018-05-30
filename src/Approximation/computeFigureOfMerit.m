function chiVec = computeFigureOfMerit(model,measData,dataNonZeroMask,nApproxParams,bp,figureOfMerit,chiWeightingMode,fomModifier)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

%compute the figure of merit (goodness of fit)
if(nargin < 8)
    fomModifier = bp.figureOfMeritModifier;
end
if(nargin < 7)
    chiWeightingMode = bp.chiWeightingMode;
end
if(nargin < 6)
    figureOfMerit = bp.figureOfMerit;
end
nrModels = size(model,2);
nrDataVectors = size(measData,2);
if(nrModels > 1 && nrDataVectors == 1)
    %use the same model for all data pixels
    multiModelsFlag = true;
else
    %use a different model for each pixel
    multiModelsFlag = false;
end
%% get errors & least squares
errLsq = bsxfun(@minus,model,measData).^2;
errLsq(isnan(errLsq)) = 0;

%% compute error measure
%             if(bp.useGPU)
%                 e_lsq = e_lsq - repmat(this.dataRez,1,nrM);
%                 idx = 1:size(model,1);
%                 idx(this.dataStorage.measurement.nonZeroMask) = 0;
%                 idx(1:this.myStartPos-1) = 0;
%                 idx(this.myEndPos:end) = 0;
%                 idx = repmat(logical(idx),1,nrM);
%                 e_lsq(idx) = 0;
%                 chiVec = sum(e_lsq,1) .* repmat(this.chi_weights,1,nrM) ./ (sum(this.dataStorage.measurement.nonZeroMask,1)-nApproxParams);  %(numel(this.dataStorage.measurement.nonZeroMask)-nApproxParams);
%                 chi = sum(chiVec(:));
%                 chiD = chiVec(1);
%             else
if(figureOfMerit == 2)
    %least squares
    chiVec = sum(errLsq);
    chiVec(chiVec <= eps(chiVec)) = inf;
%     chi = sum(chiVec(:));
%     chiD = chiVec(1);
    return
end
%                 elseif(figureOfMerit == 3) %maximum likelihood
%                     tmp = bsxfun(@minus,model,measData);
%                     nz = repmat(this.dataStorage.measurement.nonZeroMask,1,nrM);
%                     tmp(~nz) = 0;
%                     t1 = sum(tmp,1)*2;
%                     tmp = log(bsxfun(@times,model,this.getMeasurementDataRez())).*model;
%                     tmp(~nz) = 0;
%                     t2 = sum(tmp,1)*2;
%                     chiVec = t1 + t2;
switch chiWeightingMode
    case 2 %person
        modelNonZeroMask = model > 0 & repmat(dataNonZeroMask,1,nrModels);
%         modelNonZeroMask(1:this.fileInfo.StartPosition-1,:) = false;
%         modelNonZeroMask(this.fileInfo.EndPosition+1:end,:) = false;
%         if(isempty(this.fileInfo.reflectionMask))
%             reflectionMask = true(size(dataNonZeroMask));
%         else
%             reflectionMask = this.fileInfo.reflectionMask;
%         end
%         modelNonZeroMask = modelNonZeroMask & repmat(reflectionMask,1,nrM);
        errLsq(modelNonZeroMask) = errLsq(modelNonZeroMask) .* (1./model(modelNonZeroMask));
        errLsq(~modelNonZeroMask) = 0;
    case 3
        errLsq = bsxfun(@times,errLsq,chiWeightData);
    case 4
        dMaxVal = max(measData(:));
        errLsq = bsxfun(@times,errLsq,chiWeightData.*1./(dMaxVal*min(chiWeightData))); %normalize weight vector to data maximum
    otherwise %neyman
        errLsq = bsxfun(@times,errLsq,1./measData);
end
%use only residuum of non-zero values in measurement data
if(multiModelsFlag)
    errLsq(~dataNonZeroMask,:) = 0;
else
    errLsq(~dataNonZeroMask) = 0;
end
switch fomModifier
    case 1 %regular chi²
        chiVec = sum(errLsq,1) ./ (sum(dataNonZeroMask,1)-nApproxParams); 
    case 2 %boost chi2 around the 'peak'
        idx = false(size(errLsq));
        idx(1:min(bp.ErrorMP2+bp.ErrorMP3+1,this.myEndPos),:) = true;
        idx = circShiftArray(idx,repmat(max(this.dMaxPos-bp.ErrorMP2-1,0),1,nrModels));
        roi = errLsq(idx);
        %boost error only if model is too high
        roi(roi > 0) = (roi(roi > 0).*bp.ErrorMP1).^2;%boost
        errLsq(idx) = roi;
        chiVec = sum(errLsq,1) ./ (sum(dataNonZeroMask,1)-nApproxParams);  %(numel(this.dataStorage.measurement.nonZeroMask)-nApproxParams);
        
end
%chiVec = abs(1-chiVec); %the ideal value of chi² is 1
chiVec(chiVec == 0) = inf;
% chi = sum(chiVec(:));
% chiD = chiVec(1);

end

