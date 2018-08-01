function data = circShiftArrayNoLUT(data,sVec)
%=============================================================================================================
%
% @file     circShiftArrayNoLUT.m
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
% @brief    A function to circularly shift the values data each column in array data independently by each element in sVec (no lookup table used)
%
[r, c, e] = size(data);
if(r == 0 || c == 0 || isempty(sVec))
    return
end
r = int32(r);
c = int32(c);
e = int32(e);
% if(any([r c] > size(idxTable)))
%     %update if necessary
%     idxTable = repmat((0:int32(r)-1)',1,c);
% end
sVec = int32(sVec(:));
if(c ~= length(sVec))
    error('length of sVec=%d is not equal to number of columns in "data" array (size "data" =%dx%d)',length(sVec),r,c);
end
% if(c == 1)
%     idx = mod((0:r-1)'-sVec, r)+1;
% else
if(isa(data,'gpuArray'))
    tmp = repmat(gpuArray(0:int32(r)-1)',1,c);
    idx = bsxfun(@plus,mod(bsxfun(@minus,tmp,sVec'), r)+1,(0:c-1)*r);
else
    idx = bsxfun(@plus,mod(bsxfun(@minus,repmat((0:int32(r)-1)',1,c),sVec'), r)+1,(0:c-1)*r);
end
% end
if(e > 1)
    idx2 = repmat(idx,[1,1,e]);
    vec = zeros(1,1,e-1,'int32');
    vec(1,1,:) = (1:1:e-1)*r*c;
    idx2(:,:,2:e) = bsxfun(@plus,idx2(:,:,2:e),vec);
    data = data(idx2);
else
    data = data(idx);
end
