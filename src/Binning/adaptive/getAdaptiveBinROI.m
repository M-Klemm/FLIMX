function [roiFlat, binLevels, roiFull, mask] = getAdaptiveBinROI(raw,roiX,roiY,targetPhotons,maxBinFactor,optimize4Codegen)
%=============================================================================================================
%
% @file     getAdaptiveBinROI.m
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
% @brief    A function to implement adataptive binning for a certain ROI
%
flat = int32(sum(raw,3));
[yR,xR,zR] = size(raw);
raw = reshape(raw,[yR*xR,zR]);
%rawClass = class(raw);
[dataYSz,dataXSz] = size(flat);
dataYSz = int32(dataYSz);
dataXSz = int32(dataXSz);
roiX = int32(roiX);
roiY = int32(roiY);
roiXLen = length(roiX);
roiYLen = length(roiY);
roiFlat = zeros(roiYLen,roiXLen,'int32');
binLevels = zeros(roiYLen,roiXLen,'int32');
if(nargout >= 3)
    roiFull = zeros(roiYLen,roiXLen,zR,'uint32');
    roiFull = reshape(roiFull,roiYLen*roiXLen,1,zR);
end
if(targetPhotons < 1)
    mask = [];
    return
end
nPixel = roiYLen*roiXLen;
%calculate coordinates of output grid
[pxYcoord, pxXcoord] = ind2sub([roiYLen,roiXLen],1:nPixel);
[binXcoord, binYcoord, binRho, binRhoU, allMasks] = makeBinMask(maxBinFactor);
idxCoarse = find(ismember(binRhoU,single(1:maxBinFactor)'));
maxBinFactor = double(maxBinFactor);
maskIdx = cell(nPixel,1);
mask = false(roiYLen,roiXLen,dataYSz,dataXSz);
tSz = size(allMasks,1);
allMasks = reshape(allMasks,tSz*tSz,size(allMasks,3));
%ticBytes(gcp)
parfor px = 1:nPixel
    %% coarse search
    %maxBinLevelReached = false;
    val = int32(0);
    idx = int32(0);
    tile = zeros(tSz,tSz,'like',flat);
    cp = [roiY(pxYcoord(px)),roiX(pxXcoord(px))];
    %copy image data to tile
    %calculate indices around the current pixel
    rowsTop = cp(1)+1:cp(1)+maxBinFactor;
    rowsTop(rowsTop > dataYSz) = [];
    rowsBottom = cp(1):-1:cp(1)-maxBinFactor;
    rowsBottom(rowsBottom < 1) = [];
    colRight = cp(2)+1:cp(2)+maxBinFactor;
    colRight(colRight > dataXSz) = [];
    colLeft = cp(2):-1:cp(2)-maxBinFactor;
    colLeft(colLeft < 1) = [];
    %copy current pixel neighbors
    if(~isempty(rowsTop))
        tile(maxBinFactor+2:maxBinFactor+length(rowsTop)+1,maxBinFactor+2:maxBinFactor+length(colRight)+1) = flat(rowsTop,colRight);
    end
    tile(maxBinFactor+2:maxBinFactor+length(rowsTop)+1,maxBinFactor+1:-1:maxBinFactor-length(colLeft)+2) = flat(rowsTop,colLeft);
    if(~isempty(rowsBottom))
        tile(maxBinFactor+1:-1:maxBinFactor-length(rowsBottom)+2,maxBinFactor+2:maxBinFactor+length(colRight)+1) = flat(rowsBottom,colRight);
    end
    tile(maxBinFactor+1:-1:maxBinFactor-length(rowsBottom)+2,maxBinFactor+1:-1:maxBinFactor-length(colLeft)+2) = flat(rowsBottom,colLeft);
    %multiply the tile with all masks
    tile = reshape(tile,tSz*tSz,1);
    for binFactor = 1:maxBinFactor
        val = sum(tile(allMasks(:,idxCoarse(binFactor))),'native');
        if(val >= targetPhotons)
            %binFactor = binFactor+1;
            break
        end
    end    
    %slower version of coarse search
    %     binFactor = 0;
    %     binLevel = int32(0);
    %     val = int32(0);
    %     idx = int32(0);
    %     while(~maxBinLevelReached && val < targetPhotons && binFactor < maxBinFactor)
    %         binFactor = binFactor+1;
    %         binLevel = int32(find(binFactor == binRhoU,1,'first'));
    %         if(~isempty(binLevel))
    %             [idx,maxBinLevelReached] = getAdaptiveBinningIndex(roiY(pxYcoord(px)),roiX(pxXcoord(px)),binLevel(1),dataYSz,dataXSz,binXcoord, binYcoord, binRho, binRhoU);
    %             val = sum(flat(idx),'native');
    %         end
    %     end
    %% fine search
    binLevelStart = int32(0);
    binLevelEnd = int32(0);
    if(binFactor > 0)
        binLevelStart = int32(find(binFactor-1 == binRhoU,1,'first'));
        binLevelEnd = int32(find(binFactor == binRhoU,1,'first'));
        if(isempty(binLevelStart))
            binLevelStart = int32(0);
        end
        if(isempty(binLevelEnd))
            binLevelStart = int32(length(binRhoU));
        end
    end    
    for binLevel = binLevelStart:binLevelEnd
        val = sum(tile(allMasks(:,binLevel)),'native');
        if(val >= targetPhotons)
            idx = moveMaskToPixelPosition(reshape(allMasks(:,binLevel),tSz,tSz),roiY(pxYcoord(px)),roiX(pxXcoord(px)),dataYSz,dataXSz,binXcoord,binYcoord);
            break
        end
    end
    %slower version of fine search 
    %     if(binFactor > 0)
    %         binLevel = int32(find(binFactor == binRhoU,1,'first'));
    %         if(isempty(binLevel))
    %             binLevel = int32(0);
    %         end
    %         binLevel = binLevel(1);
    %     end
    %     val = int32(0);
    %     while(~maxBinLevelReached && val < targetPhotons)
    %         binLevel = binLevel+1;
    %         [idx,maxBinLevelReached] = getAdaptiveBinningIndex(roiY(pxYcoord(px)),roiX(pxXcoord(px)),binLevel,dataYSz,dataXSz,binXcoord, binYcoord, binRho, binRhoU);
    %         val = sum(flat(idx),'native');
    %     end
    %% save results and combine time data
    roiFlat(px) = val;%pxYcoord(px),pxXcoord(px)
    binLevels(px) = binLevel(1);
    if(~any(idx))
        %algorithm failed
        continue
    end    
%     if(optimize4Codegen)
%         %% use this for codegen!
%         [iY,iX] = ind2sub([yR,xR],idx);
%         tmp = zeros(length(idx),zR,rawClass);
%         for i = 1:length(idx)
%             tmp(i,:) = raw(iY(i),iX(i),:);
%         end
%         %roiFull(pxYcoord(px),pxXcoord(px),:) = sum(tmp,1,'native');
%         roiFull(px,1,:) = sum(tmp,1,'native');
%     else
        %% use this for matlab execution!
        %roiFull(px,1,:) = sum(raw(bsxfun(@plus, idx, int32(yR) * int32(xR) * ((1:int32(zR))-1))),1,'native'); %slow
        roiFull(px,1,:) = sum(raw(idx, :),1,'native');
%     end
%     if(~isempty(maskTmp))
        %save the mask of the binning area
        maskIdx{px,1} = idx;
%     end
end
%tocBytes(gcp)
if(nargout == 4)   
   for px = 1:nPixel
       maskTmp = mask(pxYcoord(px),pxXcoord(px),:,:);
       maskTmp(maskIdx{px}) = true;
       mask(pxYcoord(px),pxXcoord(px),:,:) = maskTmp;
   end   
else
    mask = [];
end
roiFull = reshape(roiFull,roiYLen,roiXLen,zR);
end
