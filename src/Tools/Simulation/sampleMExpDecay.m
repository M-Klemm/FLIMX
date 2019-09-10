function out = sampleMExpDecay(photonHist,nrPhotons)
%=============================================================================================================
%
% @file     sampleMExpDecay.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     September, 2019
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
% @brief    A function to compute synthetic FLIM data based photon histograms for a certain number of photons

%make synthetic multi exponential decay
[nModels, nBins] = size(photonHist);
out = zeros(size(photonHist));
if(length(nrPhotons) == 1)
    nrPhotons = repmat(nrPhotons,[nModels,1]);
end
if(all(nrPhotons == 0) || length(nrPhotons) ~= nModels)
    return
end
parfor model = 1:nModels
    dfIdx = 1;
    temp = zeros(nBins,1);
    df = cumsum(photonHist(model,:)); %compute commulative distribution function
    rn = sort(rand(round(nrPhotons(model)),1).*df(end),1); %make random numbers
    for i = 1:size(rn,1)
        if(rn(i) < df(dfIdx))
            %random number fits into current class of distribution function
            temp(dfIdx) = temp(dfIdx)+1;
        else
            while(rn(i) >= df(dfIdx) && dfIdx < length(df))
                %current random number is bigger than current class of distribution function -> move to next class
                dfIdx = dfIdx+1;
            end
            %random number fits into current class of distribution function
            temp(dfIdx) = temp(dfIdx)+1;
        end
    end
    out(model,:) = temp;
end