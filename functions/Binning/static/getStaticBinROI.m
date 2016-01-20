function out = getStaticBinROI(data,roiCoord,binFactor)
%=============================================================================================================
%
% @file     getStaticBinROI.m
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
% @brief    A function to use a square window of size 2 x binFactor + 1 in the area of
%           roiCoord(x1,x2,y1,y2) on data (x,y,z) summing up the content of the window in the third dimension (z)
%
%example:  dataBinned = getStaticBinROI(data,[32,192,32,192],2);
%
siz = uint16(size(data));
roiX = roiCoord(1):roiCoord(2);
roiY = roiCoord(3):roiCoord(4);
roiXLen = int32(length(roiX));
roiYLen = int32(length(roiY));
nPixel = roiYLen*roiXLen;
%calculate coordinates of output grid
[pxYcoord, pxXcoord] = ind2sub([roiYLen,roiXLen],1:nPixel);
if(binFactor == 0)
    out = uint16(data(roiY,roiX,:));
else
    out = zeros(roiYLen*roiXLen,1,siz(3),'like',data);
    parfor px = 1:nPixel
        out(px,1,:) = sum(reshape(data(max(roiY(pxYcoord(px))-binFactor,1):min(roiY(pxYcoord(px))+binFactor,siz(1)), max(roiX(pxXcoord(px))-binFactor,1):min(roiX(pxXcoord(px))+binFactor,siz(2)), :),[],siz(3)),1,'native');
    end
    out = reshape(out,roiYLen,roiXLen,siz(3));
end
%% GPU version a
% if(binFactor == 0)
%     out = uint16(data(roiY,roiX,:));
% else
%     out = zeros(roiYLen,roiXLen,siz(3),'like',data);
%     for i = 1:siz(3)
%         out(:,:,i) = sffilt(@sum,data(roiCoord(3):roiCoord(4),roiCoord(1):roiCoord(2),i),[2*binFactor+1 2*binFactor+1],uint16(0),1);
%     end
% end
%% GPU version b
% if(binFactor == 0)
%     out = uint16(data(roiY,roiX,:));
% else
%     out = zeros(roiYLen*roiXLen,1,siz(3),'like',data);
%     for px = 1:nPixel
%         out(px,1,:) = sum(reshape(data(max(roiY(pxYcoord(px))-binFactor,1):min(roiY(pxYcoord(px))+binFactor,siz(1)), max(roiX(pxXcoord(px))-binFactor,1):min(roiX(pxXcoord(px))+binFactor,siz(2)), :),[],siz(3)),1,'native');
%     end
%     out = reshape(out,roiYLen,roiXLen,siz(3));
% end


