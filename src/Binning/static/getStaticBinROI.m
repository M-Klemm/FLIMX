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
sizY = siz(1); sizX = siz(2); sizZ = siz(3);
roiX = roiCoord(1):roiCoord(2);
roiY = roiCoord(3):roiCoord(4);
roiXLen = uint16(length(roiX));
roiYLen = uint16(length(roiY));
% nPixel = roiYLen*roiXLen;
%calculate coordinates of output grid
%[pxYcoord, pxXcoord] = ind2sub([roiYLen,roiXLen],1:nPixel);
if(binFactor == 0)
    out = data(roiY,roiX,:);
else
%     tic
    dataTmp = zeros(roiYLen+2*binFactor,roiXLen+2*binFactor,sizZ,'like',data);
    dataTmp(binFactor+1:binFactor+roiYLen,binFactor+1:binFactor+roiXLen,:) = data(roiY,roiX,:);
    if(roiYLen ~= sizY || roiXLen ~= sizX)
        %ROI is smaller than data -> copy surrounding data        
        roiXStart = roiCoord(1) :-1: roiCoord(1)-binFactor;
        roiXEnd = roiCoord(2) :1: roiCoord(2)+binFactor;
        roiYStart = roiCoord(3) :-1: roiCoord(3)-binFactor;
        roiYEnd = roiCoord(4) :1: roiCoord(4)+binFactor;
        tmpStart = binFactor+1 :-1: 1;
        tmpXEnd = roiXLen+binFactor:1:roiXLen+2*binFactor;
        tmpYEnd = roiYLen+binFactor:1:roiYLen+2*binFactor;
        %ROI borders are included to have at least one hit
        idxXStart = roiXStart > 0;
        idxXEnd = roiXEnd <= sizX;
        idxYStart = roiYStart > 0;
        idxYEnd = roiYEnd <= sizY;        
        if(roiCoord(1) > 1)
            %left border
            dataTmp(min(tmpStart(idxYStart)):max(tmpYEnd(idxYEnd)),tmpStart(idxXStart),:) = data(min(roiYStart(idxYStart)):max(roiYEnd(idxYEnd)),roiXStart(idxXStart),:);
        end
        if(roiCoord(2) < sizX)
            %right border
            dataTmp(min(tmpStart(idxYStart)):max(tmpYEnd(idxYEnd)),tmpXEnd(idxXEnd),:) = data(min(roiYStart(idxYStart)):max(roiYEnd(idxYEnd)),roiXEnd(idxXEnd),:);
        end
        if(roiCoord(3) > 1)
            %bottom border
            dataTmp(tmpStart(idxYStart),min(tmpStart(idxXStart)):max(tmpXEnd(idxXEnd)),:) = data(roiYStart(idxYStart),min(roiXStart(idxXStart)):max(roiXEnd(idxXEnd)),:);
        end
        if(roiCoord(4) < sizY)
            %top border
            dataTmp(tmpYEnd(idxYEnd),min(tmpStart(idxXStart)):max(tmpXEnd(idxXEnd)),:) = data(roiYEnd(idxYEnd),min(roiXStart(idxXStart)):max(roiXEnd(idxXEnd)),:);
        end
    end
    %try to use parallel for loop
    pool = gcp('nocreate');
    if(isempty(pool))
        %no pool available -> use single core
        out = zeros(size(dataTmp),'like',data);
        for i = 1:roiYLen
            out(i+binFactor,:,:) = sum(dataTmp(i:i+2*binFactor,:,:),1,'native','omitnan');
        end
        dataTmp = out;
        out = zeros(size(dataTmp),'like',data);
        for i = 1:roiXLen
            out(:,i+binFactor,:) = sum(dataTmp(:,i:i+2*binFactor,:),2,'native','omitnan');
        end
        out = out(binFactor+1:binFactor+roiYLen,binFactor+1:binFactor+roiXLen,:);
    else
        %use the pool, use as many tiles as there are workers
        nrTiles = pool.NumWorkers;
        idxTiles = binFactor+uint16(floor(linspace(0,single(size(dataTmp,1)-2*binFactor),nrTiles+1)));
        dataSlices = cell(nrTiles,1);
        for i = 1:nrTiles
            dataSlices{i} = dataTmp(idxTiles(i)+1-binFactor:idxTiles(i+1)+binFactor,:,:);
        end
        res = cell(nrTiles,1);
        parfor j = 1:nrTiles
            myData = dataSlices{j};
            mySizY = uint16(size(myData,1)-2*binFactor);
            mySizX = uint16(size(myData,2)-2*binFactor);
            myOut = zeros(size(myData),'like',myData);
            for i = 1:mySizY
                myOut(i+binFactor,:,:) = sum(myData(i:i+2*binFactor,:,:),1,'native');
            end
            myData = myOut;
            myOut = zeros(size(myData),'like',myData);
            for i = 1:mySizX
                myOut(:,i+binFactor,:) = sum(myData(:,i:i+2*binFactor,:),2,'native');
            end
            myOut = myOut(binFactor+1:binFactor+mySizY,binFactor+1:binFactor+mySizX,:);
            res{j} = myOut;
        end
        out = cell2mat(res);
    end
end


%% half speed at quad core in matlab
% use for mex code generation
%     tic
%     out = zeros(roiYLen*roiXLen,sizZ,'like',data);
%     parfor px = 1:nPixel
%         out(px,:) = sum(reshape(data(max(roiY(pxYcoord(px))-binFactor,1):min(roiY(pxYcoord(px))+binFactor,sizY), max(roiX(pxXcoord(px))-binFactor,1):min(roiX(pxXcoord(px))+binFactor,sizX), :),[],sizZ),1,'native');
%     end
%     out = reshape(out,roiYLen,roiXLen,sizZ);
%     tocdx
%% half speed at quad core
% tic
% out = zeros(roiYLen*roiXLen,siz(3),'like',data);
% nrTiles = 4;
% idxTiles = linspace(0,single(sizY*sizX),nrTiles+1);
% pxYSlices = cell(nrTiles,1);
% pxXSlices = cell(nrTiles,1);
% for i = 1:nrTiles
%     pxYSlices{i} = pxYcoord(:,idxTiles(i)+1:idxTiles(i+1));
%     pxXSlices{i} = pxXcoord(:,idxTiles(i)+1:idxTiles(i+1));
% end
% res = cell(nrTiles,1);
% parfor i = 1:nrTiles
%     pxYc = pxYSlices{i};
%     pxXc = pxXSlices{i};
%     tmp = zeros(length(pxYc),sizZ,'like',data);
%     for px = 1:length(pxYc)
%         tmp(px,:) = sum(reshape(data(max(roiY(pxYc(px))-binFactor,1):min(roiY(pxYc(px))+binFactor,sizY), max(roiX(pxXc(px))-binFactor,1):min(roiX(pxXc(px))+binFactor,sizX), :),[],sizZ),1,'native');
%     end
%     res{i} = tmp;
% end
% for i = 1:nrTiles
%     out(idxTiles(i)+1:idxTiles(i+1),:) = res{i};
% end
% out = reshape(out,roiYLen,roiXLen,siz(3));
% toc
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


