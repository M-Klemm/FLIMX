function [simCurve, model] = calcSimDecay(model,oset,nrPhotons)
%=============================================================================================================
%
% @file     calcSimDecay.m
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
% @brief    A function to compute synthetic FLIM data based model curve and offset for a certain number of photons

%oset is average value for offset photons in all time channels -> calculate total nr of offset photons
nrTimeChannels = size(model,2);
osetPhotons = round(oset * nrTimeChannels);
%photons for exponentials are the remaining photons
expPhotons = max(0,round(nrPhotons - osetPhotons));
mmax = max(model,[],2);
%generate the random photon distributions for exponentials
simCurve = sampleMExpDecay(model,expPhotons);
%generate the random photon distributions for offset
simOset = sampleMExpDecay(ones(size(simCurve)),osetPhotons);
if(nargout == 2)
    %scale model function to data
    smax = max(simCurve,[],3);
    model = bsxfun(@times,model,smax./mmax);
    model = model + oset;
end
simCurve = simCurve + simOset;