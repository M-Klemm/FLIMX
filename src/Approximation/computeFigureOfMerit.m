function chiVec = computeFigureOfMerit(model,measData,dataNonZeroMask,nApproxParams,bp,figureOfMerit,chiWeightingMode,fomModifier,chiWeightingData)
%=============================================================================================================
%
% @file     computeFigureOfMerit.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.1
% @date     June, 2020
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
% @brief    A function to compute the figure of merit (chi²) of the model function and the measurement data

%compute the figure of merit (goodness of fit)
if(nargin < 9)
    if((nargin < 7 && bp.chiWeightingMode >= 3) || chiWeightingMode >= 3)
        chiWeightingData = measData;
        chiWeightingData = chiWeightingData ./ max(chiWeightingData,[],1);
    end
end
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
errLsq = (model - measData).^2;
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
        modelNonZeroMask = model > 0 & dataNonZeroMask;
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
    case {3,4} %weight by initial model
         dMaxVal = max(measData,[],1);
         errLsq = errLsq .* 1./(dMaxVal.*chiWeightingData);
%     case 4 %weight by avg. measured data
%         dMaxVal = max(measData,[],1);
%         errLsq = bsxfun(@times,errLsq,chiWeightingData.*1./(dMaxVal.*min(chiWeightingData,[],2))); %normalize weight vector to data maximum
    otherwise %neyman
        errLsq = errLsq .* 1./measData;
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
        idx(1:min(bp.ErrorMP2+bp.ErrorMP3+1,size(errLsq,1)),:) = true;
        [~, maxPos] = max(measData,[],1);
        idx = circShiftArrayNoLUT(idx,max(maxPos-bp.ErrorMP2-1,0));
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

