function [models, expAmpsOut, scAmpsOut, osetOut, exponentialsShort] = computeModels(nExp,incompleteDecayFactor,scatterEnable,scatterIRF,stretchedExpMask,t,irfMaxPos,irfFFT,scatterData,expAmps,taus,tcis,betas,scAmps,scShifts,scHShiftsFine,scOset,hShift,tciHShiftFine,oset,fitAmpsFlag,fitOsetFlag,measurementData,dataNonZeroMask,linLB,linUB,optimize4CodegenFlag,exponentialsLong,exponentialsShort)
%=============================================================================================================
%
% @file     computeModels.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     May, 2019
%
% @section  LICENSE
%
% Copyright (C) 2019, Matthias Klemm. All rights reserved.
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
% @brief    A function to compute exponential decays models from the input parameters

%
scAmpsOut = [];
nVecs = size(taus,2);
if(isempty(scatterData))
    nScatter = 0;
else
    nScatter = size(scatterData,2);
end
if(nargin < 26)
    nTimeCh = uint16(size(t,1));
    exponentialsLong = ones(nTimeCh,nExp*nVecs,'like',t);
end
if(nargin < 27)
    nTimeCh = uint16(size(t,1));
    nTimeChNoID = nTimeCh / incompleteDecayFactor;
    exponentialsShort = ones(nTimeChNoID,nExp+nScatter+1,nVecs,'like',t);
end
% for i = 1:1000
exponentialsShort = computeExponentials(nExp, incompleteDecayFactor, scatterEnable, scatterIRF,...
    stretchedExpMask, t(:,1:nExp*nVecs), irfMaxPos, irfFFT, scatterData, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, tciHShiftFine,...
    optimize4CodegenFlag,exponentialsLong,exponentialsShort);
% end
if(isa(exponentialsShort,'gpuArray'))
    exponentialsShort = gather(exponentialsShort);
    oset = gather(oset);
end
if(~fitAmpsFlag && ~fitOsetFlag)
    %do not fit amps or offset
    ao = zeros(1,size(expAmps,1)+size(scAmps,1)+size(oset,1),size(expAmps,2),'like',expAmps);
    ao(1,:,:) = [expAmps; scAmps; oset];
    expAmpsOut = double(squeeze(ao(1,1:nExp,:)));
    osetOut = double(squeeze(ao(1,end,:)));
else
    [ao,expAmpsOut,osetOut] = computeAmplitudes(exponentialsShort,measurementData,dataNonZeroMask,oset,fitOsetFlag,linLB,linUB);
    if(nScatter > 0)
        scAmpsOut = expAmpsOut(nExp+1:end,:);
        expAmpsOut(nExp+1:end,:) = [];
    end
end
%exponentialsShort = exponentialsShort(1:nTimeChNoID,1:nExp+nScatter+1,1:nVecs);
exponentialsShort = bsxfun(@times,exponentialsShort,ao);
models = squeeze(sum(exponentialsShort,2,'native'));
