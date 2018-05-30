function exponentialsOut = computeExponentials(bp,t,irfMaxPos,irfFFT,scatterData,amps, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, oset, tciHShiftFine,exponentialsLong,exponentialsOut)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
nTimeCh = length(t);
nVecs = size(amps,2);
if(isempty(scatterData))
    nScatter = 0;
else
    nScatter = size(scatterData,2);
end    
if(bp.incompleteDecay)
    nTimeCh = nTimeCh ./ bp.incompleteDecayFactor;
end
tOut = t(1:nTimeCh,1);
%             vpp = this.volatilePixelParams;
%             vcp = this.volatileChannelParams;
nExp = bp.nExp;
taus = 1./taus;
% if(isempty(t) || size(t,1) ~= this.tLen || size(t,2) < nVecs)
%     t = repmat(this.time(:,1),1,nVecs);
%     tSingle = single(t(:,1));
% end
if((nScatter-(bp.scatterEnable && bp.scatterIRF)) > 0)
    %shiftAndLinearOpt function will move all components by hShift -> compensate scatter shifts here
    tcis = [tcis; bsxfun(@minus,scShifts,hShift)];
    tciHShiftFine = [tciHShiftFine; scHShiftsFine];
end
%% allocate memory for temporary vatiables
%             if(isempty(exponentialsLong) || size(exponentialsLong,1) ~= size(t,1) || size(exponentialsLong,3) < nVecs || size(exponentialsLong,2) ~= nExp || size(exponentialsShort,2) ~= nExp+vpp.nScatter)
if(nargin < 17)
    exponentialsLong = ones(size(t,1),nExp+(bp.scatterEnable && bp.scatterIRF),nVecs);
end
if(nargin < 18)
    exponentialsOut = ones(nTimeCh,nExp+nScatter+1,nVecs);
end
%exponentialsOut = ones(nTimeCh,nExp,nVecs);
%exponentialsOffset = ones(nTimeCh,nExp+vpp.nScatter+1,nVecs,'single');
%             end
% if(~isempty(this.dataStorage.scatter.raw))
    scatterData = repmat(scatterData,[1,1,nVecs]);
% else
%     scVec = zeros(size(exponentialsOut,1),vpp.nScatter-bp.scatterIRF,nVecs);
% end

%% prepare scatter
%             for i = 1:vpp.nScatter
%                 scVec(:,i,:) = bsxfun(@plus,squeeze(scVec(:,i,:)),scOset(i,:));
% %                 scVec(:,i,:) = circShiftArray(bsxfun(@times, squeeze(scVec(:,i,:)),scAmps(i,:)).*this.dMaxVal,scShifts(i,:));
%             end
%                 this.myStartPos = max(this.fileInfo.StartPosition + min(scShifts(:)), this.fileInfo.StartPosition);
%                 this.myEndPos = min([this.fileInfo.EndPosition + min(scShifts(:)), this.fileInfo.EndPosition, nTimeCh]);
%% make exponentials
%stretched exponentials
for i = find(bp.stretchedExpMask)
    exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@power,bsxfun(@times, t(:,1:nVecs), taus(i,:)), betas(i,:)));
end
%'normal' exponentials
for i = find(~bp.stretchedExpMask)
    exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:)));
end
if(bp.scatterEnable && bp.scatterIRF)
    nExp = nExp+1;
    exponentialsLong(:,nExp,1:nVecs) = zeros(size(t,1),1,nVecs);
    exponentialsLong(1,nExp,1:nVecs) = 1;
end
%% reconvolute
if(bp.reconvoluteWithIRF && ~isempty(irfFFT))
    %determine reconv model length
    [~, p] = log2(size(exponentialsLong,1)-1);
    len_model_2 = pow2(p);    % smallest power of 2 > len_model
    %                 if(this.useGPU && nVecs > 1) %uses matlab gpu support
    %                     if(isempty(this.irfFFTGPU) || length(this.irfFFTGPU) ~= len_model_2)
    %                         this.irfFFTGPU = fft(gpuArray(this.getIRF()),len_model_2);
    %                     end
    %                     exponentialsLong(:,1:nExp,1:nVecs) = gather(real(ifft(bsxfun(@times, fft(exponentialsLong(:,1:nExp,1:nVecs), len_model_2, 1), this.irfFFTGPU), len_model_2, 1)));
    %                 else
%     if(isempty(this.irfFFT) || length(this.irfFFT) ~= len_model_2)
%         this.irfFFT = fft(this.getIRF(), len_model_2);
%     end
    exponentialsLong(:,1:nExp,1:nVecs) = real(ifft(bsxfun(@times, fft(exponentialsLong(:,1:nExp,1:nVecs), len_model_2, 1), irfFFT), len_model_2, 1));
    %                 end
%     if(bp.approximationTarget == 2 && this.myChannelNr <= 2) %only in anisotropy mode
%         %correct for shift caused by reconvolution
%         dtci = zeros(size(tcis));
%         [~,dtci(:,:)] = max(exponentialsOut(:,:,1:nVecs),[],1);
%         tcis = tcis - bsxfun(@minus,dtci,dtci(1,:));
%     end
else
    for i = 1:size(exponentialsLong,2)
        exponentialsLong(:,i,1:nVecs) = circShiftArrayNoLUT(squeeze(exponentialsLong(:,i,1:nVecs)),repmat(irfMaxPos,nVecs,1));
    end
end
%% incomplete decay
if(bp.incompleteDecay)
    if(bp.incompleteDecayFactor == 4)
        exponentialsOut(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs) + exponentialsLong(nTimeCh+1:2*nTimeCh,:,1:nVecs) + exponentialsLong(2*nTimeCh+1:3*nTimeCh,:,1:nVecs) + exponentialsLong(3*nTimeCh+1:end,:,1:nVecs);
    elseif(bp.incompleteDecayFactor == 2)
        exponentialsOut(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs) + exponentialsLong(nTimeCh+1:2*nTimeCh,:,1:nVecs);
    end
else
    exponentialsOut(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs);
end
%% add scatter
if((nScatter-(bp.scatterEnable && bp.scatterIRF)) > 0)
    exponentialsOut(:,nExp+1:nExp+nScatter,1:nVecs) = scatterData(:,:,1:nVecs);
end
%% shift exponentials
optimize4CodegenFlag = false;
nTci = size(tcis,1);
for j = 1:nVecs
    %temporal shift with full time channels
    if(optimize4CodegenFlag)
        %% use this for codegen!
        for i = 1:nTci
            exponentialsOut(:,i,j) = circshift(exponentialsOut(:,i,j),hShift(j) + tcis(i,j));
        end
    else
        %% use this for matlab execution
        exponentialsOut(:,1:nTci,j) = circShiftArrayNoLUT(squeeze(exponentialsOut(:,1:nTci,j)),hShift(j) + tcis(:,j));
    end    
    tciFlags = find(diff(tciHShiftFine(:,j)))+1;
    %temporal shift with sub-time-channel resolution
    %interpolate
    if(isempty(tciFlags))
        if(abs(tciHShiftFine(1,j)) > eps)
            exponentialsOut(:,1:nTci,j) = qinterp1(tOut,exponentialsOut(:,1:nTci,j),tOut + (tciHShiftFine(1,j)).*tOut(2,1),optimize4CodegenFlag);
        end
    else
        if(abs(tciHShiftFine(1,j)) > eps)
            exponentialsOut(:,1:tciFlags(1)-1,j) = qinterp1(tOut,exponentialsOut(:,1:tciFlags(1)-1,j),tOut + (tciHShiftFine(1,j)).*tOut(2,1),optimize4CodegenFlag);
        end
        for i = 1:length(tciFlags)
            if(abs(tciHShiftFine(tciFlags(i),j)) > eps)
                exponentialsOut(:,tciFlags(i),j) = qinterp1(tOut,exponentialsOut(:,tciFlags(i),j),tOut + tciHShiftFine(tciFlags(i),j).*tOut(2,1),optimize4CodegenFlag);
            end
        end
    end
end
exponentialsOut(isnan(exponentialsOut)) = 0;
end

