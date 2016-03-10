function items = removeNonVisItems(items,mode)
%=============================================================================================================
%
% @file     removeNonVisItems.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     July, 2015
%
% @section  LICENSE
%
% Copyright (C) 2015, Matthias Klemm. All rights reserved.
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
% @brief    A function to remove items which are not suited for visualization
%
items = items(~strcmpi(items,'ROI_merge_result'));
items = items(~strcmpi(items,'x_vec'));
items = items(~strcmpi(items,'hostname'));
items = items(~strcmpi(items,'Message'));
items = items(~strcmpi(items,'cVec'));
items = items(~strcmpi(items,'cMask'));
items = items(~strcmpi(items,'reflectionMask'));
items = items(~strcmpi(items,'EffectiveTime'));
items = items(~strcmpi(items,'Intensity'));
items = items(~strcmpi(items,'iVec'));
%select specific items
if(mode == 1) %simple
    keep = {'Tau','AmplitudePercent','Offset','TauMean','Q','hShift','chi2','AnisotropyQuick'};    
elseif(mode == 2) %expert
    keep = {'Tau','AmplitudePercent','Offset','TauMean','Q','shift','hShift','chi2','RAUC','RAUCIS','Amplitude','MaximumPosition','MaximumPhotons','chi2Tail','AnisotropyQuick','tc'};    
else %all
    return
end
new = [];
cLen = cellfun(@length,items);
for i = 1:length(keep)
    idxLen = cLen == length(keep{i}) | cLen == length(keep{i})+1;
    idxStrCmp = strncmp(keep{i},items(idxLen),length(keep{i}));
    if(any(idxStrCmp))
        idxLen = find(idxLen);
        new = [new; idxLen(idxStrCmp)];
    end
end
items = items(new);
