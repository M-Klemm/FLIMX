function [idx,maxBinLevelReached] = getAdaptiveBinningIndex(pixelYPos,pixelXPos,binLevel,dataYSz,dataXSz,binXcoord, binYcoord, binRho, binRhoU)
%=============================================================================================================
    %
    % @file     getAdaptiveBinningIndex.m
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
    % @brief    A function to calculate the index of the adaptive binning
    %
% persistent maxBin binXcoord binYcoord binRho binRhoU
% if(isempty(maxBin))
%     maxBin = int8(maxBinFactor);
% end
% if(isempty(binXcoord) || maxBin ~= maxBinFactor)
%     [binXcoord, binYcoord, binRho, binRhoU] = makeBinMask(maxBinFactor);
% end
binLevel = binLevel(1);
if(binLevel >= length(binRhoU))
    binLevel = int32(length(binRhoU));
    maxBinLevelReached = true;
else
    maxBinLevelReached = false;
end
mask = binRho <= binRhoU(binLevel);
rows = any(mask,1);
cols = any(mask,2);
Ym = int32(binYcoord(rows,cols));
Xm = int32(binXcoord(rows,cols));
mask = mask(rows,cols);
%move mask to coordinates of pixel position
Ym(:) = Ym(:) + pixelYPos;
Xm(:) = Xm(:) + pixelXPos;
%coordinates must be between 1 and size of the data matrix
mask = mask & Ym <= dataYSz & Ym > 0 & Xm <= dataXSz & Xm > 0;
%             idx = sub2ind([dataYSz,dataXSz],tmpYcoord(mask),tmpXcoord(mask));
idx = Ym(mask)+dataYSz.*(Xm(mask)-1);
end