classdef measurementFile < handle
    %=============================================================================================================
    %
    % @file     measurementFile.m
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
    % @brief    A class to represent the measurementFile class
    %
    properties(GetAccess = public, SetAccess = protected)
        paramMgrObj = []; %handle to parameter manager
        progressCb = cell(0,0); %callback function handles for progress bars
        sourceFile = '';    %name of the source file (not path!)
        ROICoord = [];
        rawXSz = 0;
        rawYSz = 0;
        fileInfo = []; %struct with timing related parameters
        ROIDataType = 'uint16';
        fileStub = 'measurement_';
        fileExt = '.mat';
        
        fileInfoLoaded = false;
        rawFluoData = cell(0,0);
        rawFluoDataMask = cell(0,0); %masked raw data (if we have a mask)
        rawFluoDataFlat = cell(0,0);
        rawMaskData = cell(0,0);
        roiFluoData = cell(0,0);
        roiFluoDataFlat = cell(0,0);
        roiSupport = cell(0,0);
        roiBinLevels = cell(0,0);
        roiMerged = cell(0,0);
        initData = cell(0,0);
        useMexFlags = [];
        useGPUFlags = [];
        dirtyFlags = false(1,4); %rawData, fluoFileInfo, auxInfo, ROIInfo
    end
    
    properties (Dependent = true)
        useGPU4StaticBin = [];
        useGPU4AdaptiveBin = [];
        useMex4StaticBin = [];
        useMex4AdaptiveBin = [];
        nonEmptyChannelList = [];
        loadedChannelList = [];
        FLIMXAboutInfo = [];
        tacRange = 0;
        nrTimeChannels = 0;
        timeChannelWidth = 0;
        nrSpectralChannels = 1;
        timeVector = [];
        roiStaticBinningFactor = 0;
        roiAdaptiveBinEnable = false;
        roiAdaptiveBinThreshold = 0;
        roiAdaptiveBinMax = 0;
        ROICoordinates = [];
        ROIWidths = [];
        position = '';
        pixelResolution = [];
    end
    
    methods
        function this = measurementFile(hPM)
            %constructor
            this.setParamMgrHandle(hPM);
            this.setFileInfoStruct(measurementFile.getDefaultFileInfo());
            this.fileInfoLoaded = false;
        end
        
        %% converter
        function out = fluoSyntheticFile(this)
            out = fluoSyntheticFile(this.paramMgrObj);
            %copy all properties
            out.progressCb = this.progressCb;
            out.sourceFile = this.sourceFile;
            out.ROICoord = this.ROICoord;
            out.rawXSz = this.rawXSz;
            out.rawYSz = this.rawYSz;
            out.fileInfo = this.fileInfo;
            
            out.rawFluoData = this.rawFluoData;
            out.roiFluoData = this.roiFluoData;
            out.rawFluoDataFlat = this.rawFluoDataFlat;
            out.roiFluoDataFlat = this.roiFluoDataFlat;
            out.roiMerged = this.roiMerged;
        end
        %% input methods
        function setProgressCallback(this,cb)
            %set callback function for short progress bar
            this.progressCb(end+1) = {cb};
        end
        
        function setSourceFile(this,fn)
            %set file name
            this.sourceFile = fn;
            this.setDirtyFlags([],3,true);
        end
        
        function setROICoord(this,coord)
            %set coordinates for roi coord(x_low, x_high, y_low, y_high)
            if(length(coord) == 4 && isempty(this.ROICoord) || (~isempty(this.ROICoord) && any(coord(:) - this.ROICoord(:))))
                this.clearROIData();
                this.ROICoord = coord(:);
                this.setDirtyFlags([],4,true);
            end
        end
        
        function setParamMgrHandle(this,hPM)
            %set handle to parameter manager
            this.paramMgrObj = hPM;
        end
        
        function setReflectionMask(this,channel,val)
            %set reflection mask for channel
            this.fileInfo.reflectionMask(channel) = {val};
            this.setDirtyFlags(channel,2,true);
        end
        
        function setStartPosition(this,channel,val)
            %set start position for channel
            this.fileInfo.StartPosition(channel) = {val};
            this.setDirtyFlags(channel,2,true);
        end
        
        function setEndPosition(this,channel,val)
            %set end position for channel
            this.fileInfo.EndPosition(channel) = {val};
            this.setDirtyFlags(channel,2,true);
        end
        
        function setROIDataType(this,val)
            %set data type of roi data
            if(~strcmp(this.ROIDataType,val))
                this.ROIDataType = val;
                this.clearROIData();
                this.setDirtyFlags([],4,true);
            end
        end
        
        function set.position(this,val)
            %set position
            this.setPosition(val);
        end
        
        function set.pixelResolution(this,val)
            %set pixel resolution
            this.setPixelResolution(val);
        end
        
        %% output methods
        function out = getDirtyFlags(this,ch,flagPos)
            %return dirty falgs for a channel
            out = false;
            if(ch <= size(this.dirtyFlags,1) && all(flagPos > 0) && all(flagPos <= 4))
                out = this.dirtyFlags(ch,flagPos);
            end
        end
        
        function raw = getRawData(this,channel,useMaskFlag)
            %get raw data for channel
            if(nargin < 3)
                useMaskFlag = true;
            end
            raw = [];
            bp = this.paramMgrObj.basicParams;
            if(channel <= this.nrSpectralChannels && length(this.rawFluoData) >= channel)
                raw = this.rawFluoData{channel};
                %if there is a mask, use it
                if(useMaskFlag)
                    if(length(this.rawFluoDataMask) < channel || isempty(this.rawFluoDataMask{channel}))
                        mask = this.getRawMaskData(channel);
                        if(~isempty(mask))
                            if(ndims(mask) == 3)
                                mask = sum(mask,3);
                            end
                            th = max(mask(:))*0.10;
                            mask(mask < th) = 0;
                            mask(mask >= th) = 1;
                            %mask = imdilate(mask,true(3));
                            mask = logical(mask);
                            [yR,xR,zR] = size(raw);
                            raw = reshape(raw,[yR*xR,zR]);
                            mask = reshape(mask,[yR*xR,1]);
                            raw(mask,:) = 0;
                            this.rawFluoDataMask{channel} = reshape(raw,yR,xR,zR);
                        end
                    else
                        raw = this.rawFluoDataMask{channel};
                    end
                end                
            elseif(channel > 2 && bp.approximationTarget == 2 && ~isMultipleCall())
                %get anisotropy data from channel 1 and 2 (ch1 is parallel; ch2 is perpendicular)
                if(this.nrSpectralChannels >= 2)
                    pP = double(this.getRawData(1,useMaskFlag)); %parallel %getROIData(1,y,x))
                    pS = double(this.getRawData(2,useMaskFlag)); %senkrecht
                    pS = circshift(pS,bp.anisotropyChannelShift);
                    %pP(isnan(pP)) = 0;
                    %pS(isnan(pS)) = 0;
                    if(channel == 3)
                        raw = pP+pS;
                    elseif(channel == 4)
                        raw = (pP-bp.anisotropyGFactor*pS)./(pP+bp.anisotropyGFactor*bp.anisotropyPerpendicularFactor*pS);
                        raw(isnan(raw)) = 0;
                    end
                    this.rawFluoData{channel} = raw;
                end
%                 if(isempty(y) && isempty(x))
%                     flat = out;
%                     flat(isnan(flat)) = 0;
%                     this.roiFluoDataFlat{channel} = sum(flat,3,'native');
%                 end
            end
        end
        
        function raw = getRawMaskData(this,channel)
            %get raw data mask for channel
            raw = [];
            if(channel <= this.nrSpectralChannels && length(this.rawMaskData) >= channel)
                raw = this.rawMaskData{channel};
            end
        end
        
        function out = get.useMex4StaticBin(this)
            %
            if(isempty(this.useMexFlags))
                this.useMexFlags(1) = this.testStaticBinMex();
            end
            out = this.useMexFlags(1);
        end
        
        function out = get.useMex4AdaptiveBin(this)
            %
            if(isempty(this.useMexFlags) || length(this.useMexFlags) < 2)
                this.useMexFlags(2) = this.testAdaptiveBinMex();
            end
            out = this.useMexFlags(2);
        end
        
        function out = get.useGPU4StaticBin(this)
            %
            if(isempty(this.useGPUFlags))
                this.useGPUFlags(1) = this.testStaticBinGPU();
            end
            out = this.useGPUFlags(1);
        end
        
        function out = get.useGPU4AdaptiveBin(this)
            %
            if(isempty(this.useGPUFlags) || length(this.useGPUFlags) < 2)
                this.useGPUFlags(2) = this.testAdaptiveBinGPU();
            end
            out = this.useGPUFlags(2);
        end
        
        function out = get.roiStaticBinningFactor(this)
            %
            if(isempty(this.paramMgrObj))
                out = 0;
            else
                param = this.paramMgrObj.getParamSection('pre_processing');
                out = param.roiBinning;
            end
        end
        
        function out = get.roiAdaptiveBinEnable(this)
            %
            if(isempty(this.paramMgrObj))
                out = false;
            else
                param = this.paramMgrObj.getParamSection('pre_processing');
                out = param.roiAdaptiveBinEnable;
            end
        end
        
        function out = get.roiAdaptiveBinThreshold(this)
            %
            if(isempty(this.paramMgrObj))
                out = 0;
            else
                param = this.paramMgrObj.getParamSection('pre_processing');
                out = param.roiAdaptiveBinThreshold;
            end
        end
        
        function out = get.roiAdaptiveBinMax(this)
            %
            if(isempty(this.paramMgrObj))
                out = 0;
            else
                param = this.paramMgrObj.getParamSection('pre_processing');
                out = param.roiAdaptiveBinMax;
            end
        end
        
        function out = get.ROICoordinates(this)
            %returns the coordinates of the ROI, [xLow, xHigh, yLow, yHigh]
            out = this.ROICoord;
            if(isempty(out))
                out = [1 max(1,this.getRawXSz) 1 max(1,this.getRawYSz)]';
            end
        end
        
        function out = get.nonEmptyChannelList(this)
            %return a list of channel numbers "with data"
            out = this.getNonEmptyChannelList();
        end
        
        function out = getNonEmptyChannelList(this)
            %return list of channel with measurement data
            out = find(~cellfun('isempty',this.rawFluoData));
        end
        
        function out = get.loadedChannelList(this)
            %return a list of channel numbers "with data"
            out = this.getLoadedChannelList();
        end
        
        function out = getLoadedChannelList(this)
            %return a list of channels in memory
            out = this.getNonEmptyChannelList();
        end
        
        function out = getROIXSz(this)
            %return ROI width of x axis
            coord = this.ROICoordinates;
            out = 0;
            if(~isempty(coord))
                out = coord(2) - coord(1) +1;
            end
        end
        
        function out = getROIYSz(this)
            %return ROI width of y axis
            coord = this.ROICoordinates;
            out = 0;
            if(~isempty(coord))
                out = coord(4) - coord(3) +1;
            end
        end
        
        function out = getRawXSz(this)
            %return raw width of x axis
            out = this.rawXSz;
        end
        
        function out = getRawYSz(this)
            %return raw width of x axis
            out = this.rawYSz;
        end
        
        function out = getSourceFile(this)
            %get file name
            out = this.sourceFile;
        end
        
        function [tacRange, nrTimeChans, timeChanWidth, nrSpecChans] = getFileInfo(this)
            %get tacRange nrTimeChans timeChanWidth and nrSpecChans
            tacRange = this.tacRange;
            nrTimeChans = this.nrTimeChannels;
            timeChanWidth = this.timeChannelWidth;
            nrSpecChans = this.nrSpectralChannels;
        end
        
        function fileInfo = getFileInfoStruct(this,channel)
            %get fluo file info
            if(isempty(channel))
                %export info of all channels
                fileInfo = this.fileInfo;
                fileInfo.channel = 1:this.nrSpectralChannels;
            elseif(channel > this.nrSpectralChannels)
                fileInfo = [];
                return
            else
                fileInfo.tacRange = this.fileInfo.tacRange;
                fileInfo.nrTimeChannels = this.fileInfo.nrTimeChannels;
                fileInfo.timeChannelWidth = this.timeChannelWidth;
                fileInfo.nrSpectralChannels = this.nrSpectralChannels;
                fileInfo.reflectionMask = this.getReflectionMask(channel);
                fileInfo.StartPosition = this.getStartPosition(channel);
                fileInfo.EndPosition = this.getEndPosition(channel);
                fileInfo.channel = channel;
            end
            fileInfo.rawXSz = this.rawXSz;
            fileInfo.rawYSz = this.rawYSz;
            fileInfo.position = this.fileInfo.position;
            fileInfo.pixelResolution = this.fileInfo.pixelResolution;
        end
        
        function out = getROIInfo(this,ch)
            %get info about ROI
            out.ROICoordinates = this.ROICoordinates;
            out.ROIDataType = this.ROIDataType;
            out.ROIAdaptiveBinEnable = this.roiAdaptiveBinEnable;
            if(out.ROIAdaptiveBinEnable)
                out.ROIAdaptiveBinThreshold = this.roiAdaptiveBinThreshold;
                out.ROISupport.roiFluoDataFlat = this.getROIDataFlat(ch,false);
                out.ROISupport.roiAdaptiveBinLevels = this.getROIAdaptiveBinLevels(ch);
            else
                out.ROIAdaptiveBinThreshold = [];
                out.ROISupport = [];
            end
        end
        
        function params = get.FLIMXAboutInfo(this)
            %get about info
            params = this.paramMgrObj.getParamSection('about');
        end
        
        function out = get.position(this)
            %get tac range
            out = this.fileInfo.position;
        end
        
        function out = get.pixelResolution(this)
            %get tac range
            out = this.fileInfo.pixelResolution;
        end
        
        function out = get.tacRange(this)
            %get tac range
            out = this.fileInfo.tacRange;
        end
        
        function out = get.nrTimeChannels(this)
            %get nr of time channels
            out = this.fileInfo.nrTimeChannels;
        end
        
        function out = get.timeChannelWidth(this)
            %get time channel width
            out = this.fileInfo.tacRange / this.fileInfo.nrTimeChannels * 1000;
        end
        
        function out = get.nrSpectralChannels(this)
            %get number of spectral channels
            out = this.getNrSpectralChannels();
        end
        
        function out = get.timeVector(this)
            %get a vector of time points for each "time" class
            %             out = linspace(0,(this.fileInfo.nrTimeChannels-1)*this.getTimeChannelWidth,this.fileInfo.nrTimeChannels)';
            out = linspace(0,this.fileInfo.tacRange,this.fileInfo.nrTimeChannels)';
        end
        
        function out = getReflectionMask(this,channel)
            %get reflection mask of channel
            if(isempty(this.fileInfo.reflectionMask) || length(this.fileInfo.reflectionMask) < channel || isempty(this.fileInfo.reflectionMask{channel}))
                this.getSEPosRM(channel);
            end
            out = this.fileInfo.reflectionMask{channel};
        end
        
        function out = getStartPosition(this,channel)
            %get start position of channel
            out = this.fileInfo.StartPosition{channel};
        end
        
        function out = getEndPosition(this,channel)
            %get end position of channel
            out = this.fileInfo.EndPosition{channel};
        end
        
        function out = getRawDataFlat(this,channel)
            %get intensity image of (raw) measurement data
            if(length(this.rawFluoDataFlat) < channel || isempty(this.rawFluoDataFlat{channel}))
                if(this.paramMgrObj.basicParams.approximationTarget == 2 && ~isMultipleCall() && channel > 2)
                    out = this.getRawDataFlat(1) + this.getRawDataFlat(2);
                else
                    out = this.getRawData(channel);
                    if(~isempty(out))
                        out = sum(out,3);
                        this.rawFluoDataFlat(channel,1) = {out};
                    end
                end
            else
                out = this.rawFluoDataFlat{channel};
            end
        end
        
        function [out, binFactors] = getROIDataFlat(this,channel,noBinFlag)
            %get intensity of roi for channel, return ROI without binning if noBinFlag is true
            bp = this.paramMgrObj.basicParams;
            raw = this.getRawData(channel);
            if(isempty(raw) && bp.approximationTarget == 1)
                out = [];
                return
            end
            [yR, xR, zR] = size(raw);
            roi = this.ROICoordinates;
            if(length(roi) ~= 4)
                roi = ones(4,1);
                roi(2) = xR;
                roi(4) = yR;
            end
            if(noBinFlag && ~isempty(raw))
                out = int32(sum(raw(roi(3):roi(4),roi(1):roi(2),:),3));
                return
            end
            if(length(this.roiFluoDataFlat) < channel || isempty(this.roiFluoDataFlat{channel}))
                if(this.roiAdaptiveBinEnable || (bp.approximationTarget == 2 && channel > 2))
                    this.getROIData(channel,[],[]);
                    %                     flat = sum(raw,3);
                    %                     [dataYSz,dataXSz] = size(flat);
                    %                     roiX = roi(1):roi(2);
                    %                     roiY = roi(3):roi(4);
                    %                     binFactors = zeros(length(roiY),length(roiX));
                    %                     out = zeros(length(roiY),length(roiX));
                    %                     nPixel = length(roiY)*length(roiX);
                    %                     %calculate coordinates of init grid
                    %                     [pxYcoord, pxXcoord] = ind2sub([length(roiY),length(roiX)],1:nPixel);
                    %                     for px = 1:nPixel
                    %                         binLevel = 0;
                    %                         maxBinLevelReached = false;
                    %                         %now we add up so many pixels until we reach the target
                    %                         while(~all(out(pxYcoord(px),pxXcoord(px))) && ~maxBinLevelReached)
                    %                             binLevel = binLevel+1;
                    %                             [idx,maxBinLevelReached] = measurementFile.getAdaptiveBinningInd(roiY(pxYcoord(px)),roiX(pxXcoord(px)),binLevel,dataYSz,dataXSz,maxBinFactor);
                    %                             val = flat(idx);
                    %                             val = sum(val(:));
                    %                             if(val >= target)
                    %                                 %binFactors(pxYcoord(px),pxXcoord(px)) = binLevel;
                    %                                 out(pxYcoord(px),pxXcoord(px)) = val;
                    %                             end
                    %                         end
                    %                         %if we did get enough photons use max binning for this pixel
                    %                         binFactors(pxYcoord(px),pxXcoord(px)) = binLevel;
                    %                         out(pxYcoord(px),pxXcoord(px)) = val;
                    %                     end
                    out = this.roiFluoDataFlat{channel};
                    %this.roiBinLevels{channel} = binFactors;
                else
                    bin = this.roiStaticBinningFactor;
                    if(isempty(raw))
                        out = [];
                    elseif(bin == 0)
                        out = int32(sum(raw(roi(3):roi(4),roi(1):roi(2),:),3));
                    else
                        out = sffilt(@sum,sum(raw(roi(3):roi(4),roi(1):roi(2),:),3),[2*bin+1 2*bin+1]);
                    end
                    this.roiFluoDataFlat(channel) = {out};
                end
            else
                out = this.roiFluoDataFlat{channel};
                if(length(this.roiBinLevels) >= channel)
                    binFactors = this.roiBinLevels{channel};
                else
                    binFactors = [];
                end
            end
        end
        
        function out = getROIAdaptiveBinLevels(this,channel)
            %get binning levels determined by adaptive binning in channel
            out = [];
            if(~this.roiAdaptiveBinEnable)
                return
            end
            if(length(this.roiBinLevels) < channel || isempty(this.roiBinLevels{channel}))
                this.makeROIData(channel);
            end
            if(~(length(this.roiBinLevels) < channel || isempty(this.roiBinLevels{channel})))
                out = this.roiBinLevels{channel};
            end
        end
        
        function out = getROIData(this,channel,y,x)
            %get roi data for channel
            out = [];
            bp = this.paramMgrObj.basicParams;
            raw = this.getRawData(channel);
            if(isempty(raw) && bp.approximationTarget == 1)
                return
            end
            [yR, xR, zR] = size(raw);
            roi = this.ROICoordinates;
            if(length(roi) ~= 4)
                roi = ones(4,1);
                roi(2) = xR;
                roi(4) = yR;
            end
            if(yR <= 1 && xR <= 1)
                %raw data has only a single pixel -> nothing to do
                out = raw;
                if(~isempty(y) && ~isempty(x) && ~isempty(out))
                    out = squeeze(out(1,1,:));
                end
            else
                %we've got spatial resolution
                if(~isempty(y) && ~isempty(x) && (length(this.roiFluoData) < channel || isempty(this.roiFluoData{channel})) && (~this.roiAdaptiveBinEnable || ~(length(this.roiBinLevels) < channel || isempty(this.roiBinLevels{channel}))))
                    %single pixel is requested => we do binning for pixel (y,x) on the fly
                    if(~this.roiAdaptiveBinEnable)
                        %static binning
                        bin = this.roiStaticBinningFactor;
                        if(bp.approximationTarget == 2 && channel == 4)
                            out = sum(reshape(raw(max(roi(3)+y-bin-1,1):min(roi(3)+y+bin-1,yR), max(roi(1)+x-bin-1,1):min(roi(1)+x+bin-1,xR), :),[],zR),1)';
                        else
                            out = eval([this.ROIDataType '(sum(reshape(raw(max(roi(3)+y-bin-1,1):min(roi(3)+y+bin-1,yR), max(roi(1)+x-bin-1,1):min(roi(1)+x+bin-1,xR), :),[],zR),1))'])';
                        end
                    else
                        %adaptive binning
                        bl = this.getROIAdaptiveBinLevels(channel);
                        if(y <= size(bl,1) && x <= size(bl,2))
                            [binXcoord, binYcoord, binRho, binRhoU] = makeBinMask(100);
                            idx = getAdaptiveBinningIndex(roi(3)+y-1,roi(1)+x-1,bl(y,x),yR,xR,binXcoord, binYcoord, binRho, binRhoU);
                            %out = sum(raw(bsxfun(@plus, idx, int32(yR) * int32(xR) * ((1:int32(zR))-1))),1,'native')';
                            raw = reshape(raw,[yR*xR,zR]);
                            out = sum(raw(idx, :),1,'native')';
                        end
                    end
                else
                    %whole ROI is requested
                    if(length(this.roiFluoData) < channel || isempty(this.roiFluoData{channel}))
                        %try to load this channel, cut and bin raw data
                        ROIComputedFlag = false;
                        bl = this.getROIAdaptiveBinLevels(channel); %returns [] in case of static binning
                        if(isempty(bl))
                            %we don't have pre-computed adaptive binning levels or static binning is requested => compute the whole ROI
                            out = this.makeROIData(channel);
                            ROIComputedFlag = true;
                        else
                            %we have pre-computed adaptive binning levels, reconstruct the actual binning per pixel
                            if(isempty(this.roiFluoData{channel}))
                                this.updateProgress(0.5,sprintf('rebuilding ROI channel %d',channel));
                                out = getAdaptiveBinRebuild(raw,roi,bl);
%                                 tic;out2 = getAdaptiveBinRebuild_mex(raw,roi,bl);toc
%                                 tic;out = gather(getAdaptiveBinRebuild(gpuArray(raw),roi,bl));toc
                                this.updateProgress(1,sprintf('ROI rebuild channel %d 100% done',channel));
                            end                            
                        end
                        this.roiFluoData{channel} = out;
                        this.roiFluoDataFlat{channel} = sum(uint32(out),3,'native');
                        this.updateProgress(0,'');
                        if(isempty(out) && bp.approximationTarget ~= 2)
                            return
                        end
                        this.setDirtyFlags(channel,4,true);
                        if(this.roiAdaptiveBinEnable && ROIComputedFlag)
                            %save adaptive binning levels in measuremen %file
                            this.saveMatFile2Disk(channel);
                        end
                    else
                        %we've got the pre-computed ROI
                        out = this.roiFluoData{channel};
                    end
                    if(~isempty(y) && ~isempty(x))
                        out = squeeze(out(y,x,:));
                    end
                end
            end
%             if(bp.approximationTarget == 2 && ~isMultipleCall() && channel > 2)
%                 %get anisotropy data from channel 1 and 2 (ch1 is parallel; ch2 is perpendicular)
%                 if(this.nrSpectralChannels >= 2)
%                     pP = double(this.getROIData(1,y,x)); %parallel
%                     pS = double(this.getROIData(2,y,x)); %senkrecht
%                     pS = circshift(pS,bp.anisotropyChannelShift);
%                     %pP(isnan(pP)) = 0;
%                     %pS(isnan(pS)) = 0;
%                     if(channel == 3)
%                         out = pP+pS;
%                     elseif(channel == 4)
%                         out = (pP-bp.anisotropyGFactor*pS)./(pP+bp.anisotropyGFactor*bp.anisotropyPerpendicularFactor*pS);
%                     end
%                 end
%                 if(isempty(y) && isempty(x))
%                     flat = out;
%                     flat(isnan(flat)) = 0;
%                     this.roiFluoDataFlat{channel} = sum(flat,3,'native');
%                 end
%             end
            out(isnan(out)) = 0;
        end
        
        function out = getROIMerged(this,channel)
            %get the ROI merged to a single decay
            if(length(this.roiMerged) < channel || isempty(this.roiMerged{channel}))
                %merge raw ROI to single decay
                raw = this.getRawData(channel);
                if(isvector(raw))
                    this.roiMerged(channel) = {raw};
                elseif(~isempty(raw) && ndims(raw) == 3)
                    this.roiMerged(channel) = {sum(reshape(raw(this.ROICoordinates(3):this.ROICoordinates(4),this.ROICoordinates(1):this.ROICoordinates(2),:),[],size(raw,3)),1)'};
                end
            end
            if(length(this.roiMerged) < channel || isempty(this.roiMerged{channel}))
                %still no data available
                out = [];
            else
                out = this.roiMerged{channel};
            end
        end
        
        function [out,bl] = getInitData(this,ch,targetPhotons)
            %returns data for initialization fit of the corners of the ROI, each corner has >= target photons
            if(length(this.initData) < ch || isempty(this.initData{ch}))
                out = [];
            else
                out = this.initData{ch};
                bl = zeros(size(out,1),size(out,2));
            end
            %get grid size
            if(isempty(this.paramMgrObj))
                gridSz = 2;
            else
                param = this.paramMgrObj.getParamSection('init_fit');
                gridSz = param.gridSize;
            end
            if(isempty(out) || size(out,1) ~= gridSz)
                this.updateProgress(0.5,sprintf('Init data preparation channel %d',ch));
                [roiX,roiY] = compGridCoordinates(this.ROICoordinates,gridSz);
                if(this.paramMgrObj.basicParams.approximationTarget == 2 && ch > 2)
                    %special anisotropy data
                    bp = this.paramMgrObj.basicParams;
                    %get anisotropy data from channel 1 and 2 (ch1 is parallel; ch2 is perpendicular)
                    if(this.nrSpectralChannels >= 2 && length(this.rawFluoData) >= 2)
                        [pP,bl] = this.getInitData(1,targetPhotons); %parallel
                        raw = this.getRawData(2); %senkrecht
                        [yR,xR,zR] = size(raw);
                        if(gridSz == 1 && param.gridPhotons == 0)
                            [pS,~] = this.getInitData(2,0);
                        else
                            pS = zeros(size(bl,1),size(bl,2),zR,'like',pP);
                            if(yR <= 1 && xR <= 1)
                                if(~isa(raw,class(pP)))
                                    eval(sprintf('pS = %s(raw);',class(pP)));
                                else
                                    pS = raw;
                                end
                            else
                                [binXcoord, binYcoord, binRho, binRhoU] = makeBinMask(100);
                                raw = reshape(raw,[yR*xR,zR]);
                                parfor i = 1:size(bl,1)
                                    tmp = pS(i,:,:);
                                    for j = 1:size(bl,2)
                                        idx = getAdaptiveBinningIndex(roiY(i),roiX(j),bl(i,j),yR,xR,binXcoord, binYcoord, binRho, binRhoU);
                                        %tmp(1,j,:) = circshift(sum(raw(bsxfun(@plus, idx, int32(yR) * int32(xR) * ((1:int32(zR))-1))),1,'native')',bp.anisotropyChannelShift);
                                        tmp(1,j,:) = circshift(sum(raw(idx, :),1,'native')',bp.anisotropyChannelShift);
                                    end
                                    pS(i,:,:) = tmp;
                                end
                            end
                        end
                        %pP(isnan(pP)) = 0;
                        %pS(isnan(pS)) = 0;
                        if(ch == 3)
                            out = pP+pS;
                        else
                            pP = double(pP);
                            pS = double(pS);
                            out = (pP-bp.anisotropyGFactor*pS)./(pP+bp.anisotropyGFactor*bp.anisotropyPerpendicularFactor*pS);
                        end
                    end
                else
                    %fluorescence lifetime data
                    %merge raw ROI to single decay
                    raw = this.getRawData(ch);                    
                    out = zeros(gridSz,gridSz,this.nrTimeChannels);                    
                    if(isempty(raw))
                        return
                    end
                    if(isempty(targetPhotons))
                        if(isempty(this.paramMgrObj))
                            targetPhotons = int32(100000);
                        else
                            param = this.paramMgrObj.getParamSection('init_fit');
                            targetPhotons = int32(param.gridPhotons);
                        end
                    end
                    if(gridSz <= 1 && targetPhotons == 0)
                        out(1,1,:) = this.getROIMerged(ch);
                        bl = 0;
                    else
                        %get target nr of photons                        
                        [~,bl,out] = getAdaptiveBinROI(raw,roiX,roiY,targetPhotons,int32(50),false);
                    end
                end
                this.updateProgress(1,sprintf('ROI preparation channel %d 100%% done',ch));
                this.initData{ch} = out;
                this.updateProgress(0,'');
            end
        end
        
        function out = getNeigborData(this,channels,y,x,nrNbs)
            %get neighbors from ROI data
            out = [];
            if(nrNbs == 0)
                return
            end
            for ch = 1:length(channels)
                out(:,:,ch) = measurementFile.get3DNbs(this.getROIData(channels(ch),[],[]),y,x,nrNbs/8);
            end
        end
        
        function goOn = getSEPosRM(this,channel)
            %get start-pos, end-pos and reflection mask
            goOn = true;            
            pParam = this.paramMgrObj.getParamSection('pre_processing');
            %1: auto, 0: manual, -1: fix
            if(pParam.autoStartPos == 1)
                %run auto function
                m = this.getROIMerged(channel);
                if(isempty(m))
                    this.fileInfo.StartPosition(channel) = {1};
                else
                    this.fileInfo.StartPosition(channel) = {fluoPixelModel.getStartPos(m)};
                end
            elseif(pParam.autoStartPos == -1)
                %fixed predifined value
                this.fileInfo.StartPosition(channel) = {pParam.fixStartPos};
            end
            if(pParam.autoEndPos == 1)
                %run auto function
                m = this.getROIMerged(channel);
                if(isempty(m))
                    this.fileInfo.EndPosition(channel) = {1};
                else
                    this.fileInfo.EndPosition(channel) = {fluoPixelModel.getEndPos(m)};
                end
            elseif(pParam.autoEndPos == -1)
                %fixed predifined value
                this.fileInfo.EndPosition(channel) = {pParam.fixEndPos};
            end
            if(pParam.autoReflRem == 1)
                %auto reflection removal
                m = this.getROIMerged(channel);
                if(isempty(m))
                    this.fileInfo.reflectionMask(channel) = {ones(this.fileInfo.nrTimeChannels,1)};
                else
                    this.fileInfo.reflectionMask(channel) = {measurementFile.compReflectionMask(m,pParam.ReflRemWinSz,pParam.ReflRemGrpSz)};
                end
            else %-1 disabled
                this.fileInfo.reflectionMask(channel) = {ones(this.fileInfo.nrTimeChannels,1)};
            end
            %user wants to choose
            if((pParam.autoStartPos == 0 || pParam.autoEndPos == 0 || pParam.autoReflRem == 0) && ~isempty(this.getROIMerged(channel)))                
                %call startpos gui
                [this.fileInfo.StartPosition{channel}, this.fileInfo.EndPosition{channel}, this.fileInfo.reflectionMask{channel}] = GUI_startEndPosWizard(this.getROIMerged(channel),...
                    pParam.autoStartPos,pParam.autoEndPos,this.timeChannelWidth,...
                    pParam.ReflRemWinSz,pParam.ReflRemGrpSz,...
                    pParam.fixStartPos,pParam.fixEndPos);
            end
            if(isempty(this.fileInfo.StartPosition) || isempty(this.fileInfo.StartPosition{channel}) || isempty(this.fileInfo.EndPosition)...
                    || isempty(this.fileInfo.EndPosition{channel}) || (this.fileInfo.StartPosition{channel} == 0 && this.fileInfo.EndPosition{channel} == 0))
                %cancel was pressed or merged roi is empty
                goOn = false;
                this.fileInfo.StartPosition{channel} = 1;
                this.fileInfo.EndPosition{channel} = this.fileInfo.nrTimeChannels;
                this.fileInfo.reflectionMask{channel} = ones(this.fileInfo.nrTimeChannels,1);
            end
        end
        
        function [rawData, fluoFileInfo, auxInfo, ROIInfo] = makeExportVars(this,ch)
            %save measurement data in separate structure
            fluoFileInfo = []; auxInfo = []; ROIInfo = [];
            rawData = this.getRawData(ch);
            if(isempty(rawData))
                return
            end
            auxInfo.revision = this.FLIMXAboutInfo.measurement_revision;
            %out.channel = ch;
            [~, name, ext] = fileparts(this.getSourceFile());
            auxInfo.sourceFile = [name ext];
            fluoFileInfo = this.getFileInfoStruct(ch);
            ROIInfo = this.getROIInfo();
        end
        
        function saveMatFile2Disk(this,ch)
            %save result channel to disk
            %fn = this.getMeasurementFileName(ch,'');
            this.exportMatFile(ch,'');
        end
        
        function exportMatFile(this,ch,folder)
            %save measurement data to disk
            %              [rawData, fluoFileInfo, auxInfo, ROIInfo] = this.makeExportVars(ch);
            %              if(isempty(rawData))
            %                  return
            %              end
            fn = this.getMeasurementFileName(ch,folder);
            [pathstr, ~, ~]= fileparts(fn);
            if(~isdir(pathstr))
                [status, message, ~] = mkdir(pathstr);
                if(~status)
                    error('FLIMX:measurementFile:exportMatFile','Could not create path for measurement file export: %s\n%s',pathstr,message);
                end
            end
            %saveVars = {'rawData', 'fluoFileInfo', 'auxInfo', 'ROIInfo'};
            df = this.getDirtyFlags(ch,1:4);
            if(all(df) || ~exist(fn,'file'))
                rawData = this.getRawData(ch,false);
                rawMaskData = this.getRawMaskData(ch);
                fluoFileInfo = this.getFileInfoStruct(ch);
                auxInfo.revision = this.FLIMXAboutInfo.measurement_revision;
                %out.channel = ch;
                [~, name, ext] = fileparts(this.getSourceFile());
                auxInfo.sourceFile = [name ext];
                ROIInfo = this.getROIInfo(ch);
                save(fn,'rawData','rawMaskData','fluoFileInfo','auxInfo','ROIInfo','-v7.3');
            else
                if(df(1,1))
                    %rawData
                    rawData = this.getRawData(ch,false);
                    rawMaskData = this.getRawMaskData(ch);
                    if(~isempty(rawData))
                        save(fn,'rawData','rawMaskData','-append');
                    end
                end
                if(df(1,2))
                    %fluoFileInfo
                    fluoFileInfo = this.getFileInfoStruct(ch);
                    if(this.paramMgrObj.basicParams.approximationTarget == 2)
                        %revert artificial change of spectral channels
                        fluoFileInfo.nrSpectralChannels = 2;
                    end
                    save(fn,'fluoFileInfo','-append');
                end
                if(df(1,3))
                    %auxInfo
                    auxInfo.revision = this.FLIMXAboutInfo.measurement_revision;
                    %out.channel = ch;
                    [~, name, ext] = fileparts(this.getSourceFile());
                    auxInfo.sourceFile = [name ext];
                    save(fn,'auxInfo','-append');
                end
                if(df(1,4))
                    %ROIInfo
                    ROIInfo = this.getROIInfo(ch);
                    save(fn,'ROIInfo','-append');
                end
            end
            this.setDirtyFlags(ch,1:4,false);
            %              saveVars = saveVars(this.dirtyFlags);
            %              if(~isempty(saveVars))
            % %                  file = matfile(fn,'Writable',true);
            % %                  file.ROIInfo = ROIInfo;
            %                  save(fn,saveVars{:},'-append');
            %              end
        end
        
        function out = getMyFolder(this)
            %returns working folder
            %supposed to be overloaded by childs
            out = cd;
        end
        
        %% computation methods
        function guessEyePosition(this)
            %guess position (left: OS or right: OD) of the eye
            [eyePos, confidence] = eyePosition(this.getRawDataFlat(1));
            %try other channel(s)
            for ch = 2:this.nrSpectralChannels
                if(confidence >= 0.05)
                    break
                end
                [eyePosN, confidenceN] = eyePosition(this.getRawDataFlat(ch));
                if(confidenceN > confidence)
                    eyePos = eyePosN;
                    confidence = confidenceN;
                end
            end
            if(~isnan(confidence))
                %save the position only if the algorithm didn't fail
                this.position = eyePos;
            end
        end
        
        function out = makeROIData(this,channel)
            %bin raw data using binFactor and save in object
            out = [];
            if(isMultipleCall())
                return
            end
            if(length(this.roiFluoData) < channel || isempty(this.roiFluoData{channel}))
                %try to load this channel
                raw = this.getRawData(channel);
                if(isempty(raw))
                    return
                end
                [y, x, z] = size(raw);
                roi = this.ROICoordinates(:);
                if(length(roi) ~= 4)
                    roi = ones(4,1);
                    roi(2) = x;
                    roi(4) = y;
                end
                %bin raw data
                computationParams = this.paramMgrObj.getParamSection('computation');
                generalParams = this.paramMgrObj.getParamSection('general');
                bp = this.paramMgrObj.basicParams;
                if(bp.approximationTarget == 2 && channel > 2)
                    binFactor = 0;
                else
                    binFactor = this.roiStaticBinningFactor;
                end
                if(binFactor > 0)
                    this.updateProgress(0.5,sprintf('ROI preparation channel %d',channel));
                end
                %                  pool = gcp('nocreate');
                %                  if(~isempty(pool))
                %                      ps = 4*pool.NumWorkers;
                %                  else
                %                      ps = 0;
                %                  end
                if(computationParams.useMatlabDistComp == 0 || binFactor < 1 || generalParams.saveMaxMem || this.roiAdaptiveBinEnable && ~isa(raw,'uint16'))
                    %force to run binning on matlab code
                    if(this.roiAdaptiveBinEnable)
                        [roiX,roiY] = compGridCoordinates(roi,0);
                        [~,binLevels,out] = getAdaptiveBinROI(uint32(raw),roiX,roiY,int32(this.roiAdaptiveBinThreshold),int32(this.roiAdaptiveBinMax),false);
                        this.roiBinLevels{channel} = binLevels;
                        this.setDirtyFlags(channel,4,true);
                    else
                        out = getStaticBinROI(raw,uint16(roi),uint16(binFactor));
                    end
                    this.updateProgress(1,sprintf('ROI preparation channel %d 100%% done',channel));
                else
                    %use mex files and/or parfor
                    if(this.roiAdaptiveBinEnable)
                        target = int32(this.roiAdaptiveBinThreshold);
                        maxBin = int32(this.roiAdaptiveBinMax);
                        [roiX,roiY] = compGridCoordinates(roi,0);
%                         if(this.useMex4AdaptiveBin && this.nrTimeChannels <= 1024)
%                             [~,binLevels,out] = getAdaptiveBinROI_mex(raw,roiX,roiY,target,maxBin,true);                            
%                         else
                            [~,binLevels,out] = getAdaptiveBinROI(raw,roiX,roiY,target,maxBin,false);
%                         end
                        this.roiBinLevels{channel} = binLevels;
                        this.setDirtyFlags(channel,4,true);
                    else
                        %static binning
                        if(computationParams.useGPU && this.useGPU4StaticBin && binFactor > 2)
                            out = gather(getStaticBinROI(gpuArray(raw),roi,binFactor));
                        elseif(this.useMex4StaticBin && isa(raw,'uint16') && binFactor > 4)
                            out = getStaticBinROI_mex(raw,uint16(roi),uint16(binFactor));
                        else
                            out = getStaticBinROI(raw,uint16(roi),uint16(binFactor));
                        end
                    end
                end
                %save ROI data in object
                if(~isempty(out))
                    this.roiFluoData(channel) = {out};
                    this.roiFluoDataFlat{channel} = sum(uint32(out),3,'native');
                end
                this.saveMatFile2Disk(channel);
                this.updateProgress(0,'');
            end
        end
        
        function clearRawData(this,ch)
            %clear raw data to save memory, clear all channels if ch is empty
            if(isempty(ch))
                this.rawFluoData = cell(0,0);
                this.rawMaskData = cell(0,0);
            elseif(isscalar(ch) && any(ch == this.nonEmptyChannelList))
                this.rawFluoData{ch} = [];
                this.rawMaskData{ch} = [];
            end
        end
        
        function clearROIData(this)
            %clear everything except for the measurement data
            this.roiFluoData = cell(this.nrSpectralChannels,1);
            this.rawFluoDataMask = cell(this.nrSpectralChannels,1);
            this.roiFluoDataFlat = cell(this.nrSpectralChannels,1);
            this.roiMerged = cell(this.nrSpectralChannels,1);
            this.roiSupport = cell(this.nrSpectralChannels,1);
            this.initData = cell(this.nrSpectralChannels,1);
            this.fileInfo.reflectionMask = cell(this.nrSpectralChannels,1);
            this.fileInfo.StartPosition = num2cell(ones(this.nrSpectralChannels,1));
            this.fileInfo.EndPosition = num2cell(this.fileInfo.nrTimeChannels.*ones(this.nrSpectralChannels,1));
        end
        
        function clearInitData(this)
            %clear data needed for initialization fit
            this.initData = cell(this.nrSpectralChannels,1);
        end
        
        function updateProgress(this,prog,text)
            %either update progress bar of visObj or plot to command line
            for i = length(this.progressCb):-1:1
                try
                    this.progressCb{i}(prog,text);
                catch
                    this.progressCb{i} = [];
                end
            end
        end
        
    end %methods
    
    methods (Access = protected)
        function setPosition(this,val)
            %set position
            for i = 1:length(this.nonEmptyChannelList)
                %load fileinfo of all channels
                this.getFileInfoStruct(this.nonEmptyChannelList(i));
            end
            this.fileInfo.position = val;
            this.setDirtyFlags([],2,true);
        end
        
        function setPixelResolution(this,val)
            %set pixel resolution
            for i = 1:length(this.nonEmptyChannelList)
                %load fileinfo of all channels
                this.getFileInfoStruct(this.nonEmptyChannelList(i));
            end
            this.fileInfo.pixelResolution = val;
            this.setDirtyFlags([],2,true);
        end
        
        function setDirtyFlags(this,ch,flagPos,val)
            %set one or multiple dirty flags to a new value
            if(isempty(ch))
                ch = 1:this.nrSpectralChannels;
            end
            if(ch(end) > size(this.dirtyFlags,1))
                newChs = size(this.dirtyFlags,1):ch(end);
                this.dirtyFlags(newChs,1:4) = repmat(this.dirtyFlags(1,:),length(newChs),1);
            end
            this.dirtyFlags(ch,flagPos) = logical(val);
        end
        
        function setNrTimeChannels(this,val)
            %set nr of time channels
            this.fileInfo.nrTimeChannels = val;
            this.fileInfo.reflectionMask = mat2cell(ones(this.fileInfo.nrTimeChannels,this.fileInfo.nrSpectralChannels),val,ones(this.fileInfo.nrSpectralChannels,1))';
            this.setDirtyFlags([],2,true);
        end
        
        function setFileInfoStruct(this,fileInfo)
            %set info (for batch job)
            if(isempty(fileInfo))
                return
            end
            old = this.fileInfo;
            this.fileInfo.tacRange = fileInfo.tacRange;
            this.fileInfo.nrTimeChannels = fileInfo.nrTimeChannels;
            this.fileInfo.nrSpectralChannels = fileInfo.nrSpectralChannels;
            if(~this.fileInfoLoaded || old.tacRange ~= fileInfo.tacRange || old.nrTimeChannels ~= fileInfo.nrTimeChannels || old.nrSpectralChannels ~= fileInfo.nrSpectralChannels)
                this.clearROIData();
            end
            if(~isfield(fileInfo,'reflectionMask'))
                fileInfo.reflectionMask = mat2cell(ones(fileInfo.nrTimeChannels,fileInfo.nrSpectralChannels),val,ones(fileInfo.nrSpectralChannels,1))';
            end
            this.setSEPosRM(fileInfo.channel,fileInfo.StartPosition,fileInfo.EndPosition,fileInfo.reflectionMask);
            this.rawXSz = fileInfo.rawXSz;
            this.rawYSz = fileInfo.rawYSz;
            this.fileInfo.position = fileInfo.position;
            this.fileInfo.pixelResolution = fileInfo.pixelResolution;
            this.fileInfoLoaded = true;
            this.setDirtyFlags([],2,true);
        end
        
        function setSEPosRM(this,channel,startP,endP,RM)
            %set start position, end position and reflection mask
            if(isempty(channel) || length(channel) > 1)
                %we are importing more than 1 channel at a time, no further checks done here at the moment...
                this.fileInfo.reflectionMask = RM;
                this.fileInfo.StartPosition = startP;
                this.fileInfo.EndPosition = endP;
            elseif(channel <= this.nrSpectralChannels)
                this.fileInfo.reflectionMask{channel} = RM;
                this.fileInfo.StartPosition{channel} = startP;
                this.fileInfo.EndPosition{channel} = endP;
            end
            this.setDirtyFlags([],2,true);
        end
        
        function setRawData(this,channel,data)
            %set raw data for channel
            if(channel <= this.nrSpectralChannels && ndims(data) == 3)
                this.rawFluoData(channel,1) = {data};
                this.rawFluoDataFlat(channel,1) = cell(1,1);
                this.rawMaskData(channel,1) = cell(1,1);
                [this.rawYSz,this.rawXSz, ~] = size(data);
                this.roiFluoData(channel,1) = cell(1,1);
                this.roiMerged(channel,1) = cell(1,1);
            end
            this.setDirtyFlags(channel,1,true);
        end
        
        function setRawMaskData(this,channel,data)
            %set raw mask data for channel
            if(channel <= this.nrSpectralChannels && this.rawYSz == size(data,1) && this.rawXSz == size(data,2))
                this.rawMaskData(channel,1) = {data};
                this.rawFluoDataFlat(channel,1) = cell(1,1);
                this.roiFluoData(channel,1) = cell(1,1);
                this.roiMerged(channel,1) = cell(1,1);
            end
            this.setDirtyFlags(channel,1,true);
        end
        
        function out = getMeasurementFileName(this,ch,folder)
            %returns path and filename for channel ch
            if(isempty(folder))
                out = fullfile(this.getMyFolder(),sprintf('%sch%02d%s',this.fileStub,ch,this.fileExt));
            else
                out = fullfile(folder,sprintf('%sch%02d%s',this.fileStub,ch,this.fileExt));
            end
        end
        
        function out = getNrSpectralChannels(this)
            %return number of spectral channels, in case of anisotropy: 4
            out = this.fileInfo.nrSpectralChannels;
            if(this.paramMgrObj.basicParams.approximationTarget == 2)
                out=4;
            end
        end
    end %methods (Access = protected)
    
    methods(Static)
        function out = sWnd3D(xl,xu,yl,yu,d,raw,pres,hwb)
            % xl - lower bound x
            % xu - upper bound x
            % yl - lower bound y
            % yu - upper bound y
            % d - half window length +1
            % raw - input data matrix
            %
            %example:  [cut cut_flat] = sWnd3D(32,192,32,192,2,raw);
            [y,x,z] = size(raw);
            xl = max(1,min(abs(xl),x));
            xu = max(1,min(x,xu));
            yl = max(1,min(abs(yl),y));
            yu = max(1,min(y,yu));
            out = zeros(yu-yl+1,xu-xl+1,z,pres);
            
            % %precompute indices
            % idx = zeros(xu-xl+1,yu-yl+1,4);
            % for i = xl:xu
            %    for j = yl:yu
            %        idx(i-xl+1,j-yl+1,:) = [max(i-d,1) min(i+d,y) max(j-d,1) min(j+d,x)];
            %    end
            % end
            
            if(d == 0)
                out = uint16(raw(yl:yu,xl:xu,:));
            else
                %hwb = waitbar(0,'ROI preparation');
                if(~isempty(hwb))
                    t_start = clock;
                end
                for i = yl:yu
                    for j = xl:xu
                        %slower: out(ic,jc,:) = sum(sum(raw(i-d:i+d, j-d:j+d, :),1),2);
                        ic = i-yl+1;
                        jc = j-xl+1;
                        out(ic,jc,:) = eval([pres '(sum(reshape(raw(max(i-d,1):min(i+d,y), max(j-d,1):min(j+d,x), :),[],z),1))']);
                    end
                    if(~isempty(hwb))
                        prog = ic/(yu-yl+1);
                        [~, minutes, secs] = secs2hms(etime(clock,t_start)/ic*(yu-yl+1-ic)); %mean cputime for finished runs * cycles left
                        waitbar(prog, hwb,sprintf('ROI preparation: %03.1f%% done - Time left: %02.0fmin %02.0fsec',prog*100,minutes,secs));
                    end
                end
                %close(hwb);
                % even slower
                %                 t_start = clock;
                %                 out = sffilt(@sum,raw(yl:yu,xl:xu,:),[2*d+1 2*d+1]);
                %                 etime(clock,t_start)
            end
            %             out_flat = sum(out,3);
        end
        
        function fi = getDefaultFileInfo()
            %return a file info struct with some default values
            fi.tacRange = 12.5084; %just some default value; in ns (1 / laser repetition rate)
            fi.nrTimeChannels = 1024;
            fi.timeChannelWidth = fi.tacRange/fi.nrTimeChannels;
            fi.nrSpectralChannels = 1;
            fi.channel = 1;
            fi.StartPosition = 1;
            fi.EndPosition = fi.nrTimeChannels;
            fi.reflectionMask = true(fi.nrTimeChannels,1);
            fi.mergeMaxPos = zeros(fi.nrSpectralChannels,1);
            %fi.ROICoordinates = [];
            %fi.ROIDataType = 'uint16';
            fi.rawXSz = 0;
            fi.rawYSz = 0;
            fi.pixelResolution = 34.375; %just some default value: 58.666 (old) | 34.375 (new) µm / pixel
            fi.position = 'OS'; %OD "oculus dexter" = "right eye"; OS "oculus sinister" = "left eye"
        end
        
        function out = getDefaultROIInfo()
            %return a ROI info struct with some default values
            out.ROICoordinates = [];
            out.ROIDataType = 'uint16';
            out.ROIAdaptiveBinEnable = false;
            out.ROIAdaptiveBinThreshold = [];
            out.ROISupport = [];
        end
        
        function out = testStaticBinMex()
            %returns true is a mex file can be used for static binning
            out = false;
            try
                getStaticBinROI_mex(zeros(1,1,1024,'uint16'),uint16([1;1;1;1]),uint16(1));
                out = true;
            catch ME
            end
        end
        
        function out = testAdaptiveBinMex()
            %returns true is a mex file can be used for adaptive binning
            out = false;
            try
                getAdaptiveBinROI_mex(zeros(1,1,1024,'uint16'),int32(1),int32(1),int32(0),int32(0),true);
                out = true;
            catch ME
            end
        end
        
        function out = testStaticBinGPU()
            %returns true is a GPU could be used for static binning
            persistent GPUFlag
            if(isempty(GPUFlag))
                GPUFlag = false;
                n = gpuDeviceCount;
                if(n < 1)
                    return
                end
                GPUList = zeros(n,1);
                GPUSpeed = zeros(n,1);
                for i = 1:n
                    info = gpuDevice(i);
                    if(info.DeviceSupported)
                        GPUList(i) = i;
                        GPUSpeed(i) = info.MultiprocessorCount .* info.ClockRateKHz;
                    end
                end
                idx = GPUList > 0;
                %GPUList = GPUList(idx);
                GPUSpeed = GPUSpeed(idx);
                [~,idx] = max(GPUSpeed);
                %select fastest device
                gpuDevice(idx);
                try
                    gather(getStaticBinROI(gpuArray(zeros(1,1,1024,'uint16')),uint16([1;1;1;1]),uint16(1)));
                    GPUFlag = true;
                catch ME
                end
            end
            out = GPUFlag;
        end
        
        function [out, idx] = compReflectionMask(in,aWSz,minGWSz)
            %detectes reflection in fluorescence decay data using 1st order gradient
            out = true(size(in));
            if(isempty(in))
                return
            end
            idx = [];
            %in_a = sWnd1DAvg(in,aWSz);
            in_a = fastsmooth(in,aWSz,3,0);
            [~, m_pos] = max(in_a(:));
            in_g = fastGrad(in_a);
            in_g(1:m_pos) = -inf;
            in_pos = find(in_g > 0);
            if(length(in_pos) < minGWSz)
                return
            end
            idx = measurementFile.getMaskGrps(in_pos);
            idx_diff = idx(:,2) - idx(:,1);
            idx = idx(idx_diff >= minGWSz,:);
            if(isempty(idx))
                return
            end
            idx(:,2) = idx(:,2) + round(4*idx_diff(idx_diff >= minGWSz)); %remove 4 times the slope of the reflection (in total)
            oLen = length(out);
            idx(idx(:,2) > oLen,2) = oLen;
            for i = 1:size(idx,1)
                out(idx(i,1):idx(i,2)) = false;
            end
        end
        
        function idx = getMaskGrps(mask)
            %get indices of true valued groups in index-mask (find of a logical mask)
            if(numel(mask) == 0)
                idx = [];
                return
            end
            cnt = 1;
            idx(1,1) = mask(1);
            idx(1,2) = mask(1);
            for i=2:length(mask)
                if(mask(i) ~= mask(i-1)+1)
                    idx(cnt,2) = mask(i-1);
                    cnt = cnt+1;
                    idx(cnt,1) = mask(i);
                end
                if(i == length(mask))
                    idx(cnt,2) = mask(i);
                end
            end
        end
        
        function nbs = get3DNbs(mat,yPos,xPos,d)
            %find the 4 or 8 neighbors (nbCnt) of yPos/xPos in window d keeping the 3rd dimension
            [y, x, z, nrChannels] = size(mat);
            nbs = zeros(z,(2*d+1)^2-1,nrChannels,class(mat));%(2*d+1)^2-1
            if(d == 0)
                return
            end
            idx_center = sub2ind([y x z],yPos,xPos);
            idx_rows = max(yPos-ceil(d),1):min(yPos+ceil(d),y);
            idx_cols = max(xPos-ceil(d),1):min(xPos+ceil(d),x);
            %fuse row and column subscripts
            if(d == 0.5)
                %4 neighbors (for d = 1)
                idx_nbs = zeros(length(idx_rows)+length(idx_cols),2);
                %first add vertical neighbors
                idx_nbs(1:length(idx_rows),1) = idx_rows;
                idx_nbs(1:length(idx_rows),2) = repmat(xPos,length(idx_rows),1);
                %second add horizontal neighbors
                idx_nbs(1+length(idx_rows):end,1) = repmat(yPos,length(idx_cols),1);
                idx_nbs(1+length(idx_rows):end,2) = idx_cols;
            else
                %8 neighbors (for d = 1)
                idx_nbs = zeros(length(idx_rows)*length(idx_cols),2);
                for l = 1:length(idx_cols)
                    idx_nbs((l-1)*length(idx_rows)+1:l*length(idx_rows),1) = idx_rows;
                    idx_nbs((l-1)*length(idx_rows)+1:l*length(idx_rows),2) = idx_cols(l);
                end
            end
            %convert
            idx_nbs = sub2ind([y x z],idx_nbs(:,1),idx_nbs(:,2));
            %data vector is also in nbs, find it and remove it!
            idx_nbs(idx_nbs == idx_center) = [];
            [idx_rows, idx_cols] = ind2sub([y x z],idx_nbs);
            for l = 1:length(idx_nbs)
                nbs(:,l) = reshape(mat(idx_rows(l), idx_cols(l), :,:),[],z)';
            end
            %nbs(:,sum(nbs,1) == 0) = [];
        end
    end %methods(Static)
end

