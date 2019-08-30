function exponentialsOut = computeExponentials(nExp,incompleteDecayFactor,scatterEnable,scatterIRF,stretchedExpMask,t,irfMaxPos,irfFFT,scatterData,taus,tcis,betas,scAmps,scShifts,scHShiftsFine,scOset,hShift,tciHShiftFine,optimize4CodegenFlag,exponentialsLong,exponentialsOut)
%=============================================================================================================
%
% @file     computeExponentials.m
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
% @brief    A function to compute exponential decays from the input parameters

nTimeCh = size(t,1)*ones(1,1,'like',nExp);
nVecs = size(taus,2)*ones(1,1,'like',nExp);
if(isempty(scatterData))
    nScatter = zeros(1,1,'like',nExp);
else
    nScatter = size(scatterData,2)*ones(1,1,'like',nExp);
end    
%if(bp.incompleteDecay)
    nTimeChOut = nTimeCh / incompleteDecayFactor;
%end
%             vpp = this.volatilePixelParams;
%             vcp = this.volatileChannelParams;
%nExp = bp.nExp;
taus = 1./taus;
% if(isempty(t) || nTimeCh ~= this.tLen || size(t,2) < nVecs)
%     t = repmat(this.time(:,1),1,nVecs);
%     tSingle = single(t(:,1));
% end
if((nScatter))%-sum(scatterEnable && scatterIRF)) > 0)
    %shiftAndLinearOpt function will move all components by hShift -> compensate scatter shifts here
    scShifts = bsxfun(@minus,scShifts,hShift);
end
%% allocate memory for temporary vatiables
%             if(isempty(exponentialsLong) || size(exponentialsLong,1) ~= nTimeCh || size(exponentialsLong,3) < nVecs || size(exponentialsLong,2) ~= nExp || size(exponentialsShort,2) ~= nExp+vpp.nScatter)
if(nargin < 20)
    exponentialsLong = ones(nTimeCh,nExp*nVecs,'like',t);
end
exponentialsLong = reshape(exponentialsLong,nTimeCh,[]);
if(nargin < 21)
    exponentialsOut = ones(nTimeChOut,nExp+nScatter+1,nVecs,'like',t);
end
exponentialsOut = reshape(exponentialsOut,nTimeChOut,[]);

%calculate indices where the exponentials are
idxExponentialsLong = false(nExp,1,'like',stretchedExpMask);
idxExponentialsLong(1:nExp) = true;
idxExponentialsLong = repmat(idxExponentialsLong,nVecs,1);
idxExponentialsOut = false(nExp+nScatter+1,1,'like',stretchedExpMask);
idxExponentialsOut(1:nExp) = true;
idxScatterOut = ~idxExponentialsOut;
idxScatterOut(end) = false(1,1,'like',stretchedExpMask); %offset
idxExponentialsOut = repmat(idxExponentialsOut,nVecs,1);
idxScatterOut = repmat(idxScatterOut,nVecs,1);
%reshape the parameters
taus = reshape(taus,nVecs*nExp,1);
temporalShift = reshape((tcis + hShift),nVecs*nExp,1);
tciHShiftFine = reshape(tciHShiftFine,nVecs*nExp,1);
scShifts = reshape(scShifts,nVecs*nScatter,1);
scHShiftsFine = reshape(scHShiftsFine,nVecs*nScatter,1);
%exponentialsOut = ones(nTimeCh,nExp,nVecs);
%exponentialsOffset = ones(nTimeCh,nExp+vpp.nScatter+1,nVecs,'single');
%             end
% if(~isempty(this.dataStorage.scatter.raw))
    %scatterData = repmat(scatterData,[1,nVecs]);
% else
%     scVec = zeros(size(exponentialsOut,1),vpp.nScatter-scatterIRF,nVecs);
% end

%% prepare scatter
if(any(scOset(:)))
            for i = 1:nScatter
                scatterData(:,i,:) = bsxfun(@plus,squeeze(scatterData(:,i,:)),scOset(i,:));
%                 scVec(:,i,:) = circShiftArray(bsxfun(@times, squeeze(scVec(:,i,:)),scAmps(i,:)).*this.dMaxVal,scShifts(i,:));
            end
end
%                 this.myStartPos = max(this.fileInfo.StartPosition + min(scShifts(:)), this.fileInfo.StartPosition);
%                 this.myEndPos = min([this.fileInfo.EndPosition + min(scShifts(:)), this.fileInfo.EndPosition, nTimeCh]);
%% make exponentials
if(any(stretchedExpMask))
    idxSExp = repmat(stretchedExpMask(:),nVecs,1);
    betas = reshape(betas,[],1);
    exponentialsLong(:,idxExponentialsLong & idxSExp) = exp(-bsxfun(@power,bsxfun(@times,t(:,1:sum(idxExponentialsLong & idxSExp)),taus(idxExponentialsLong & idxSExp)'),betas(idxSExp)'));
    exponentialsLong(:,idxExponentialsLong & ~idxSExp) = exp(bsxfun(@times,-t(:,1:sum(idxExponentialsLong & ~idxSExp)),taus(idxExponentialsLong & ~idxSExp)'));
%     for i = 1:length(stretchedExpMask)
%         if(stretchedExpMask(i))
%             %stretched exponentials
%             exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@power,bsxfun(@times, t(:,1:nVecs), taus(i,:)), betas(i,:)));
%         else
%             %'normal' exponentials
%             exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:)));
%         end
%     end
else
    exponentialsLong(:,idxExponentialsLong) = exp(bsxfun(@times,-t(:,1:nExp*nVecs),taus'));
end
% for i = find(~stretchedExpMask)
%     exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:)));
% end
% if(scatterEnable && scatterIRF)
%     %irf as scatter data
%     nExp = nExp+1;
%     exponentialsLong(:,nExp,1:nVecs) = zeros(nTimeCh,1,nVecs);
%     exponentialsLong(1,nExp,1:nVecs) = 1;
% end
%% reconvolute
if(~isempty(irfFFT))
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
    exponentialsLong(:,idxExponentialsLong) = real(ifft(bsxfun(@times,fft(exponentialsLong(:,idxExponentialsLong), len_model_2, 1),irfFFT), len_model_2, 1));
    %                 end
%     if(bp.approximationTarget == 2 && this.myChannelNr <= 2) %only in anisotropy mode
%         %correct for shift caused by reconvolution
%         dtci = zeros(size(tcis));
%         [~,dtci(:,:)] = max(exponentialsOut(:,:,1:nVecs),[],1);
%         tcis = tcis - bsxfun(@minus,dtci,dtci(1,:));
%     end
else
    exponentialsLong = circShiftArrayNoLUT(exponentialsLong,irfMaxPos);
%     for j = 1:nExp*nVecs
%         exponentialsLong(:,j) = circShift(exponentialsLong(:,j),irfMaxPos);
%     end
end
%% incomplete decay
if(incompleteDecayFactor == 4)
    exponentialsLong(1:nTimeChOut,:) = exponentialsLong(1:nTimeChOut,idxExponentialsLong) + exponentialsLong(nTimeChOut+1:2*nTimeChOut,idxExponentialsLong) + exponentialsLong(2*nTimeChOut+1:3*nTimeChOut,idxExponentialsLong) + exponentialsLong(3*nTimeChOut+1:end,idxExponentialsLong);
elseif(incompleteDecayFactor == 2)
    exponentialsLong(1:nTimeChOut,:) = exponentialsLong(1:nTimeChOut,idxExponentialsLong) + exponentialsLong(nTimeChOut+1:2*nTimeChOut,idxExponentialsLong);
else
    %no incomplete decay
    exponentialsLong(1:nTimeChOut,:) = exponentialsLong(1:nTimeChOut,idxExponentialsLong);
end

%% shift exponentials
% for j = 1:nExp*nVecs
%     %temporal shift with full time channels
%     exponentialsLong(1:nTimeChOut,j) = circshift(exponentialsLong(1:nTimeChOut,j),temporalShift(j));
% end
exponentialsLong(1:nTimeChOut,:) = circShiftArrayNoLUT(exponentialsLong(1:nTimeChOut,:),temporalShift);
%shift with higher time resolution (interpolate)
exponentialsLong(1:nTimeChOut,:) = vectorInterp(exponentialsLong(1:nTimeChOut,:),tciHShiftFine);

%% assemble output
exponentialsOut(:,idxExponentialsOut) = exponentialsLong(1:nTimeChOut,idxExponentialsLong);
%% add shifted scatter
%if((nScatter-sum(scatterEnable && scatterIRF)) > 0)
if(nScatter == 1)
    exponentialsOut(:,idxScatterOut) = circShiftArrayNoLUT(squeeze(scatterData),scShifts);
    %shift with higher time resolution (interpolate)
    exponentialsOut(:,idxScatterOut) = vectorInterp(exponentialsOut(:,idxScatterOut),scHShiftsFine);
elseif(nScatter >= 2)
    for j = 1:nVecs
        for k = 1:nScatter
            exponentialsOut(:,j*(nExp+k+1)-1) = circshift(scatterData(:,k,j),scShifts((j-1)*nScatter+k));
            %shift with higher time resolution (interpolate)
            exponentialsOut(:,j*(nExp+k+1)-1) = vectorInterp(exponentialsOut(:,j*(nExp+k+1)-1),scHShiftsFine((j-1)*nScatter+k));
        end
    end
end
%% remove not a numbers
exponentialsOut(isnan(exponentialsOut)) = 0;
%% reshape
exponentialsOut = reshape(exponentialsOut,nTimeChOut,[],nVecs);
%add offset
exponentialsOut(:,end,:) = ones([nTimeChOut,nVecs],'like',t);%.*oset;
end

