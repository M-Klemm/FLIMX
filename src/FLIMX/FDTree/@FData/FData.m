classdef FData < handle
    %=============================================================================================================
    %
    % @file     FData.m
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
    % @brief    A class to represent a base class of a fluorescence lifetime parameter
    %
    properties(SetAccess = protected, GetAccess = public)
        %uid = []; %unique object identifier
        id = 0; %running number
        sType = [];
        rawImage = [];
        rawImgFilt = [];
        rawImgIsLogical = false;
        color_data = [];
        logColor_data = [];
        rawImgXSz = [];
        rawImgYSz = [];
        rawImgZSz = [];
        supplementalData = [];
    end
    properties(Dependent = true, SetAccess = protected, GetAccess = public)
        name;
    end
    properties(Dependent = true, SetAccess = public, GetAccess = public)
        dType
        isSubjectDefaultSize
        subjectName
        channel
        isEmptyStat
        FLIMXParamMgrObj
    end
    properties(SetAccess = protected, GetAccess = protected)
        myParent = [];
        cachedImage = [];
        maxHistClasses = 5000;
        rawXLblStart = [];
        rawXLblTick = 1;
        rawYLblStart = [];
        rawYLblTick = 1;
    end

    methods
        function this = FData(parent,nr,rawImage)
            %constructor of the FData class
            %this.uid = datenum(clock);
            this.id = nr;
            this.sType = 1; %default to linear data scaling
            this.myParent = parent;
            this.setRawData(rawImage);
%             this.clearCachedImage();
%             this.color_data = [];
%             this.logColor_data = [];
        end

        function out = getMemorySize(this)
            %determine memory size of the FData
            props = properties(this);
            props{11} = 'cachedImage';
            props{12} = 'maxHistClasses';
            props(13:end) = [];
            out = 0;
            for i=1:length(props)
                tmp = this.(props{i});
                s = whos('tmp');
                out = out + s.bytes;
            end
            %fprintf(1, 'FData size %d bytes\n', out);
        end

        function clearCachedImage(this)
            %reset all fields of the cached image
            ci.ROI.ROICoordinates = zeros(2,2,'int16');
            ci.ROI.ROIType = 0;
            ci.ROI.ROISubType = 0;
            ci.ROI.ROIVicinity = 0;
            ci.data = [];
            ci.colors = [];
            ci.info.ZMin = [];
            ci.info.ZMax = [];
            ci.info.ZLblMin = [];
            ci.info.ZLblMax = [];
            ci.info.XSz = [];
            ci.info.YSz = [];
%             ci.info.XLblStart = [];
%             ci.info.XLblTick = [];
%             ci.info.YLblStart = [];
%             ci.info.YLblTick = [];
            ci.statistics.descriptive = [];
            ci.statistics.histogram = [];
            ci.statistics.histogramCenters = [];
            ci.statistics.histogramStrict = [];
            ci.statistics.histogramStrictCenters = [];
            this.cachedImage = ci;
        end

%         function flag = eq(obj1,obj2)
%             %compare two FData objects
%             if(obj1.uid - obj2.uid < eps('double'))
%                 flag = true;
%             else
%                 flag = false;
%             end
%         end

        %% input functions
        function setRawData(this,val)
            %set the raw data, clears cached data
            if(islogical(val))
                this.rawImgIsLogical = true;
            else
                this.rawImgIsLogical = false;
            end
            this.rawImage = single(val);
            this.supplementalData = [];
            this.color_data = [];
            this.logColor_data = [];
            % this.curImgColors = [];
            this.setRawDataXSz([]);
            this.setRawDataYSz([]);
            this.setRawDataZSz([]);
            this.rawImgFilt = [];
            this.clearCachedImage();
            this.rawXLblStart = [];
            this.rawXLblTick = 1;
            this.rawYLblStart = [];
            this.rawYLblTick = 1;
            if(isempty(val))
                return;
            end
            [y, x] = size(val);
            this.setRawDataXSz([1 x]);
            this.setRawDataYSz([1 y]);
            %val = this.getFullImage(); %expensive but correct
            this.setRawDataZSz([FData.getNonInfMinMax(1,val) FData.getNonInfMinMax(2,val)]);
        end
        
        function setSupplementalData(this,val)
            %set supplemental data, e.g. info supporting the raw data
            this.supplementalData = val;
        end

        function setColor_data(this,val,valLog)
            %
            this.color_data = val;
            this.logColor_data = valLog;
            this.clearCachedImage();
        end

        function setRawDataXSz(this,val)
            %set rawImgXSz property
            this.rawImgXSz = val;
        end

        function setRawDataYSz(this,val)
            %set rawImgYSz property
            this.rawImgYSz = val;
        end

        function setRawDataZSz(this,val)
            %set rawImgZSz property
            this.rawImgZSz = val;
        end

        function setCIROIType(this,val)
            %set type of cached ROI
            this.cachedImage.ROI.ROIType = val;
        end

        function setCIROISubType(this,val)
            %set type of roi (number corresponding to type)
            this.cachedImage.ROI.ROISubType = val;
        end

        function setupXLbl(this,start,tick)
            %set start value and tick (width) for custom x labels
            if(isempty(start) || isempty(tick))
                tick = this.getDefaultXLblTick();
            else
                start = start(1);
            end
            this.rawXLblStart = start;
            this.rawXLblTick = tick;
        end

        function setupYLbl(this,start,tick)
            %set start value and tick (width) for custom y labels
            if(isempty(start) || isempty(tick))
                tick = 1;
            else
                start = start(1);
            end
            this.rawYLblStart = start;
            this.rawYLblTick = tick;
        end

        function setSType(this,val)
            %set sType (lin=1,log=2)
            if(this.sType == val)
                %check if new scale type differs from old one
                return
            end
            this.sType = val;
            tmp = this.getFullImage();
            this.rawImgZSz = [FData.getNonInfMinMax(1,tmp) FData.getNonInfMinMax(2,tmp)];
            this.clearCachedImage();
        end

        %% output functions
        function out = get.name(this)
            %return my ID as string
            out = num2str(this.id);
        end

        function out = get.dType(this)
            %get current data type
            out = this.myParent.getDType();
        end

        function out = get.isSubjectDefaultSize(this)
            %return true, if FLIM item has the subect defalt size
            out = this.myParent.isSubjectDefaultSize;
        end

        function nr = get.channel(this)
            %get my channel number
            nr = this.myParent.getMyChannelNr();
        end

        function nr = get.subjectName(this)
            %get my subject name
            nr = this.myParent.getMySubjectName();
        end

        function [ROIlb, ROIub, stepSize] = getROIParameters(this,ROIType,dim,isMatrixPos)
            %get lower bound, upper bound and stepsize in x or y dimension for ROIType
            coord = this.getROICoordinates(ROIType);
            if(isempty(coord))
                coord = [this.rawImgYSz; this.rawImgXSz];
            end
            stepSize = 1;
            if(strcmp(dim,'y'))
                ROIlb = coord(1,1);
                ROIub = coord(1,2);
                if(~isMatrixPos)
                    ROIlb = this.yPos2Lbl(ROIlb);
                    ROIub = this.yPos2Lbl(ROIub);
                    stepSize = this.rawYLblTick;
                end
            else %x
                ROIlb = coord(2,1);
                ROIub = coord(2,2);
                if(~isMatrixPos)
                    ROIlb = this.xPos2Lbl(ROIlb);
                    ROIub = this.xPos2Lbl(ROIub);
                    stepSize = this.rawXLblTick;
                end
            end
        end

        function out = isArithmeticImage(this)
            %return true, if dType is an arithmetic image
            out = this.myParent.isArithmeticImage();
        end

        function out = getZScaling(this)
            %get z scaling parameters
            out = this.myParent.getZScaling(this.id);
        end

        function out = getColorScaling(this)
            %get color scaling parameters
            out = this.myParent.getColorScaling(this.id);
        end

        function out = get.isEmptyStat(this)
            %returns true, if descripte statistics of the cached data are empty (not yet computed)
            out = isempty(this.cachedImage.statistics.descriptive);
        end

        function out = getSType(this)
            %get current/demanded scale type
            out = this.sType;
        end

        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end

        function out = getFileInfoStruct(this)
            %get fileinfo struct
            out = this.myParent.getFileInfoStruct();
        end

        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.myParent.getVicinityInfo();
        end

        function out = getFullImage(this)
            %get raw image with respect to linear/log scaling
            out = this.rawImage;
            if(isempty(out))
                return
            end
            imask = this.myParent.getIgnoredPixelsMask();
            scaling = this.sType;
            %scale to log
            if(scaling == 2)
                out = log10(abs(out)); %turn negative values positive
                out(isinf(out)) = 0;
            end
            out(imask) = NaN;
            %don't filter intensity image
            if(~this.isArithmeticImage() && ~(strcmpi(this.dType,'intensity') || strncmp('MVGroup',this.dType,7) || strncmp('ConditionMVGroup',this.dType,16) || strncmp('GlobalMVGroup',this.dType,13)))
                if(isempty(this.rawImgFilt))
                    out = this.filter(out);
                    out(imask) = NaN;
                    this.rawImgFilt = out;
                else
                    out = this.rawImgFilt;
                end
            end
        end
        
        function out = getSupplementalData(this)
            %return support data, if available
            out = this.supplementalData;
        end            
        
        function out = getROIGroup(this,grpName)
            %get the ROI group names and members
            out = this.myParent.getROIGroup(grpName);
        end

        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            if(~isempty(ROIType) && strncmp(this.dType,'MVGroup_',8) && ROIType == 2003)
                %quantilRect
                %force auto ROI coordinates
                rp = this.FLIMXParamMgrObj.getParamSection('region_of_interest');
                tmp = this.getFullImage();
                xH = cumsum(sum(tmp,1));
                yH = cumsum(sum(tmp,2));
                out(2,1) = find(xH >= xH(end)*rp.rectangle3Quantil(1)/100,1,'first');
                out(2,2) = find(xH >= xH(end)*rp.rectangle3Quantil(2)/100,1,'first');
                out(1,1) = find(yH >= yH(end)*rp.rectangle3Quantil(1)/100,1,'first');
                out(1,2) = find(yH >= yH(end)*rp.rectangle3Quantil(2)/100,1,'first');
            else
                out = this.myParent.getROICoordinates(ROIType);
            end
        end

        function out = getROIType(this)
            %get type of ROI
            out = this.myParent.getROIType();
        end

        function out = getROISubType(this)
            %get type of grid roi (number corresponding to type)
            out = this.myParent.getROISubType();
        end

        function out = getCIROICoordinates(this)
            %get coordinates of cached ROI
            out = this.cachedImage.ROI.ROICoordinates;
        end

        function out = getCIROIType(this)
            %get type of cached ROI
            out = this.cachedImage.ROI.ROIType;
        end

        function out = getCIROISubType(this)
            %get type of grid roi (number corresponding to type)
            out = this.cachedImage.ROI.ROISubType;
        end

        function [ROICoordinates, ROIType, ROISubType, ROIVicinity] = getCachedImageROIInfo(this)
            %get ROI info of cached image
            ROI = this.cachedImage.ROI;
            ROICoordinates = ROI.ROICoordinates;
            ROIType = ROI.ROIType;
            ROISubType = ROI.ROISubType;
            ROIVicinity = ROI.ROIVicinity;
        end

        function [ci,idx] = getROIImage(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get cached image            
            %use whole image if we don't get ROI coordinates
            if(isempty(ROICoordinates))
                ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
            end
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                %we've got this image segment already
                [ci,idx] = this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            else
                ci = this.cachedImage.data;
                idx = this.cachedImage.indicesInRawImage;
            end
        end

        function out = getCIColor(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get current image colors
            if(isempty(ROICoordinates))
                ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
            end
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity) || isempty(this.cachedImage.colors) && ~isempty(this.color_data))
                %update only if we have color data
                this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            end
            out = this.cachedImage.colors;
        end

        function out = getCImin(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get minimum of current image
            if(ROIType == 0)
                out = this.rawImgZSz(1);
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                out = this.cachedImage.info.ZMin;
            end
        end

        function out = getCImax(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get maximum of current image
            if(ROIType == 0)
                out = this.rawImgZSz(2);
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                out = this.cachedImage.info.ZMax;
            end
        end

        function out = getCIminLbl(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get label for minimum of current image
            if(ROIType == 0)
                zVec = this.getZScaling();
                if(length(zVec) == 3 && zVec(1))
                    out = this.makeZlbls(zVec(2),zVec(3));
                else
                    out = this.makeZlbls(this.rawImgZSz(1),this.rawImgZSz(2));
                end
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                out = this.cachedImage.info.ZLblMin;
            end
        end

        function out = getCImaxLbl(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get label for maximum of current image
            if(ROIType == 0)
                zVec = this.getZScaling();
                if(length(zVec) == 3 && zVec(1))
                    [~,out] = this.makeZlbls(zVec(2),zVec(3));
                else
                    [~,out] = this.makeZlbls(this.rawImgZSz(1),this.rawImgZSz(2));
                end
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                out = this.cachedImage.info.ZLblMax;
            end
        end

        function out = getRIXLbl(this)
            %get x labels for raw image
            if(~isempty(this.rawXLblStart) && ~isempty(this.rawImgXSz))
                out = this.xPos2Lbl(1) : this.rawXLblTick : this.xPos2Lbl(this.rawImgXSz(2));
            elseif(isempty(this.rawXLblStart) && ~isempty(this.rawImgXSz))
                step = this.getDefaultXLblTick();
                out = 1*step:step:this.rawImgXSz(2)*step;
            else
                out = [];
            end
        end

        function out = ROIIsCached(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %check if this ROI is in my cache
            out = false;
            if(isempty(ROICoordinates))
                return
            end
            [cROICoordinates, cROIType, cROISubType, cROIVicinity] = this.getCachedImageROIInfo();
            if(isempty(cROICoordinates))
                return
            end
            if(all(size(cROICoordinates) == size(ROICoordinates)) && all(cROICoordinates(:) == ROICoordinates(:)) && cROIType == ROIType && cROISubType == ROISubType && cROIVicinity == ROIVicinity && ~isempty(this.cachedImage.data))
                out = true;
            end
        end

        function out = getCIXLbl(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get x labels for current image
            if(isempty(this.rawImgXSz))
                out = [];
                return
            end
            if(isempty(ROICoordinates))
                ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
            end
            if(ROIType == 0 && ~(strncmp(this.dType,'MVGroup',7) || strncmp(this.dType,'ConditionMVGroup',16) || strncmp(this.dType,'GlobalMVGroup',13)))
                XSz = ROICoordinates(1,2);
                XLblStart = [];
                XLblTick = this.getDefaultXLblTick();
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                XSz = this.cachedImage.info.XSz;
                XLblStart = this.rawXLblStart;
                XLblTick = this.rawXLblTick;
            end
            if(~isempty(ROICoordinates) && (ROIType == 0 || ROIType > 2000 && ROIType < 3000))
                shift = ROICoordinates(2,1)-1;
            else
                shift = 0;
            end
            if(isempty(XLblStart))
                out = (1+shift)*XLblTick : XLblTick : (XSz+shift)*XLblTick;
            else
                out = this.xPos2Lbl(1+shift) : XLblTick : this.xPos2Lbl(XSz+shift);
            end
        end

        function out = xPos2Lbl(this,pos)
            %convert absolut matrix position of x axis to label
            if(isempty(this.rawXLblStart))
                out = pos;
            else
                out = this.rawXLblStart + (pos-1)*this.rawXLblTick;
            end
        end

        function out = xLbl2Pos(this,lbl)
            %convert label of x axis to absolut matrix position
            if(isempty(this.rawXLblStart))
                out = lbl;
            else
                out = round((lbl - this.rawXLblStart)/this.rawXLblTick+1);
            end
        end

        function out = getXLblTick(this)
            %get tick (step) size of x axis labels
            if(isempty(this.rawXLblTick))
                out = this.getDefaultXLblTick();
            else
                out = this.rawXLblTick;
            end
        end

        function out = getRIYLbl(this)
            %get y labels for raw image
            if(~isempty(this.rawYLblStart) && ~isempty(this.rawImgYSz))
                out = this.yPos2Lbl(1) : this.rawYLblTick : this.yPos2Lbl(this.rawImgYSz(2));
            elseif(isempty(this.rawYLblStart) && ~isempty(this.rawImgYSz))
                step = this.getDefaultYLblTick();
                out = 1*step:step:this.rawImgYSz(2)*step;
            else
                out = [];
            end
        end

        function out = getCIYLbl(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get x labels for current image
            if(isempty(this.rawImgYSz))
                out = [];
                return
            end
            if(isempty(ROICoordinates))
                ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
            end
            if(ROIType == 0 && ~(strncmp(this.dType,'MVGroup',7) || strncmp(this.dType,'ConditionMVGroup',16) || strncmp(this.dType,'GlobalMVGroup',13)))
                YSz = ROICoordinates(2,2);
                YLblStart = [];
                YLblTick = this.getDefaultYLblTick();
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end
                YSz = this.cachedImage.info.YSz;
                YLblStart = this.rawYLblStart;
                YLblTick = this.rawYLblTick;
            end
            if(~isempty(ROICoordinates) && (ROIType == 0 || ROIType > 2000 && ROIType < 3000))
                shift = ROICoordinates(1,1)-1;
            else
                shift = 0;
            end
            if(isempty(YLblStart))
                out = (1+shift)*YLblTick : YLblTick : (YSz+shift)*YLblTick;
            else
                out = this.yPos2Lbl(1+shift) : YLblTick : this.yPos2Lbl(YSz+shift);
            end
        end

        function out = yPos2Lbl(this,pos)
            %convert absolut matrix position of x axis to label
            if(isempty(this.rawYLblStart))
                out = pos;
            else
                out = this.rawYLblStart + (pos-1)*this.rawYLblTick;
            end
        end

        function out = yLbl2Pos(this,lbl)
            %convert label of y axis to absolut matrix position
            if(isempty(this.rawYLblStart))
                out = lbl;
            else
                out = round((lbl - this.rawYLblStart)/this.rawYLblTick+1);
            end
        end

        function out = getYLblTick(this)
            %get tick (step) size of y axis labels
            if(isempty(this.rawYLblTick))
                out = this.getDefaultYLblTick();
            else
                out = this.rawYLblTick;
            end
        end

        function out = zPos2Lbl(this,out)
            %dummy - no functioniality
        end

        function out = zLbl2Pos(this,out)
            %dummy - no functioniality
        end

        function out = getCIxSz(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get size in x of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            end
            out = this.cachedImage.info.XSz;
        end

        function out = getCIySz(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get size in y of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            end
            out = this.cachedImage.info.YSz;
        end

        function [hist,centers] = getCIHist(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get histogram of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity))
                this.clearCachedImage();
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            elseif(this.isEmptyStat)
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            end
            hist = this.cachedImage.statistics.histogram;
            centers = this.cachedImage.statistics.histogramCenters;
        end

        function [hist,centers] = getCIHistStrict(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get histogram of current image using strict rules
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity) || ~isfield(this.cachedImage.statistics,'histogramStrict') || isempty(this.cachedImage.statistics.histogramStrict))
                [~, this.cachedImage.statistics.histogramStrict, this.cachedImage.statistics.histogramStrictCenters] = this.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
            end
            hist = this.cachedImage.statistics.histogramStrict;
            centers = this.cachedImage.statistics.histogramStrictCenters;
        end

        function out = getROIStatistics(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %get statistcs of current image
            %check
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity) || this.isEmptyStat)
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            end
            out = this.cachedImage.statistics.descriptive;
        end

        function out = getLinData(this)
            %set the data scaling to linear
            this.setSType(1);
            out = this;
        end

        function out = getLogData(this)
            %set the data scaling to log10
            this.setSType(2);
            out = this;
        end

        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end

        %% compute functions
        function clearRawImage(this)
            %clear raw image data (and the supplemental data) 
            this.rawImage = [];
            this.supplementalData = [];
        end

        function clearFilteredImage(this)
            %clear filtered raw image data
            this.rawImgFilt = [];
            %now cached data is invalid
            this.clearCachedImage();
        end

        function out = getROISubfieldStatistics(this,ROICoord,ROIType,statsType)
            %get statType (mean, SD) for all subfields of the ETDRS grid
            %with the following order:
            %             1 %central
            %             2 %inner superior
            %             3 %inner nasal
            %             4 %inner inferior
            %             5 %inner temporal
            %             6 %outer superior
            %             7 %outer nasal
            %             8 %outer inferior
            %             9 %outer temporal
            ri = this.getFullImage();
            out = zeros(9,1);
            for i = 1:9
                ci = this.getImgSeg(ri,ROICoord,ROIType,i,0,this.getFileInfoStruct(),this.getVicinityInfo(),strncmp(this.dType,'MVGroup_',8));
                ci = ci(~(isnan(ci(:)) | isinf(ci(:))));
                cim = FData.getNonInfMinMax(1,ci);
                %set possible "-inf" in curImg to "cim"
                ci(ci < cim) = cim;
                zVec = this.getZScaling();
                if(length(zVec) == 3 && zVec(1))
                    zlim_min = this.getZlimMin(ci);
                    zlim_max = zVec(3);
                    ci(ci < zlim_min) = zlim_min;
                    ci(ci > zlim_max) = zlim_max;
                end
                switch strtrim(statsType)
                    case 'mean'
                        out(i,1) = mean(ci(:),'omitnan');
                    case 'median'
                        out(i,1) = median(ci(:),'omitnan');
                    case 'SD'
                        out(i,1) = std(ci(:),'omitnan');
                    case 'CV'
                        out(i,1) = 100*std(ci(:),'omitnan')./mean(ci(:),'omitnan');
                end
            end
        end
        
%         function [stats, histogram, histCenters] = makeROIGroupStatistics(this,ROIType,ROISubType,ROIVicinity,strictFlag)
%             %make statistics for a group of ROIs
%             allGrps = this.getROIGroup([]);
%             if(isempty(allGrps) || size(allGrps,2) ~= 2 || isempty(allGrps{1,1}) || abs(ROIType) > size(allGrps,1))
%                 stats = [];
%                 histogram = [];
%                 histCenters = [];
%                 return
%             end
%             gROIs = allGrps{abs(ROIType),2};
%             idx = [];
%             outsideFlag = false;
%             if(ROIVicinity == 2)
%                 %areas outside ROI are requested
%                 outsideFlag = true;
%                 ROIVicinity = 1;
%             end
%             for i = 1:length(gROIs)
%                 [~,tmp] = this.getROIImage(this.getROICoordinates(gROIs(i)),gROIs(i),ROISubType,ROIVicinity);
%                 idx = [idx; tmp(:)];
%             end
%             %idx are the indices of the ROI pixels in the raw image
%             idx = unique(idx); %remove redundant pixels from overlapping ROIs
%             raw = this.getFullImage();
%             if(outsideFlag)
%                 %areas outside ROI are requested but we got the indices of inside the ROIs (on purpose)               
%                 raw(idx) = NaN;
%                 ci = raw;
%             else
%                 ci = raw(idx);
%             end
%             ci = ci(~(isnan(ci(:)) | isinf(ci(:))));
%             [histogram, histCenters] = this.makeHistogram(ci,strictFlag);
%             stats = FData.computeDescriptiveStatistics(ci,histogram,histCenters);
%         end

        function [stats, histogram, histCenters] = makeStatistics(this,ROICoordinates,ROIType,ROISubType,ROIVicinity,strictFlag)
            %make statistics for a certain ROI
            ci = this.getROIImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
            ci = ci(~(isnan(ci(:)) | isinf(ci(:))));
            [histogram, histCenters] = this.makeHistogram(ci,strictFlag);
            stats = FData.computeDescriptiveStatistics(ci,histogram,histCenters);
        end

        function updateCIStats(this,ROICoordinates,ROIType,ROISubType,ROIVicinity)
            %make statistics
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIVicinity) || this.isEmptyStat)%calculate statistics only if necessary
                [statistics.descriptive, statistics.histogram, statistics.histogramCenters] = this.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,false);
                statistics.histogramStrict = [];
                statistics.histogramStrictCenters = [];
                if(isempty(statistics.histogramCenters) || sum(statistics.histogram(:)) == 0)
                    statistics.descriptive = [];
                    statistics.histogram = [];
                    
                    this.cachedImage.statistics = statistics;
                    return
                end
                this.cachedImage.statistics = statistics;
                this.cachedImage.ROI.ROICoordinates = ROICoordinates;
                this.cachedImage.ROI.ROIType = ROIType;
                this.cachedImage.ROI.ROISubType = ROISubType;
                this.cachedImage.ROI.ROIVicinity = ROIVicinity;
            end
        end

        function [histogram, centers] = makeHistogram(this,imageData,strictFlag)
            %make histogram for display puposes
            ci = imageData(~(isnan(imageData(:)) | isinf(imageData(:))));
            if(isempty(ci))
                histogram = [];
                centers = [];
                return
            end
            [classWidth,limitFlag,classMin,classMax] = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
            [histogram, centers] = FData.computeHistogram(imageData,classWidth,limitFlag,classMin,classMax,this.maxHistClasses,this.dType,this.id,strictFlag);            
        end

        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
    end %methods

    methods (Access = protected)
        function zl_min = getZlimMin(this,cim)
            %get data minimum which is not -inf with respect to scaling
            zVec = this.getZScaling();
            if(length(zVec) ~= 3 || (length(zVec) == 3 && ~zVec(1)))
                zl_min = cim;
                return
            end
            if(this.sType == 2)
                %log10 scaling
                if(zVec(2) == -inf)
                    %cim is already in log10
                    zl_min = cim;
                else
                    zl_min = zVec(2);
                end
            else
                %linear
                zl_min = zVec(2);
            end
        end

        function [lblMin, lblMax] = makeZlbls(this,dMin,dMax)
            %compute min and max labels for z axis with respect to scaling
            if(this.sType == 2)
                %log10-scaling
                lblMin = 10^dMin;
                lblMax = 10^dMax;
            else
                %linear scaling
                lblMin = dMin;
                lblMax = dMax;
            end
            if(abs(lblMin - lblMax) < eps)
                lblMax = lblMin *1.1;
            end
        end

        function data = filter(this,data)
            %smooth (filter) raw data if neccessary
            [alg, params] = this.getDataSmoothFilter();
            switch alg
                case 1
                    data = sffilt(@meanOmitNaN,data,[params params],NaN);
                case 2
                    data = sffilt(@medianOmitNaN,data,[params params],NaN);
                case 3
                    data = smoothn(data,'robust');
                case 4
                    %dataSmooth = hmf(data,3);
                    data = sffilt(@varOmitNaN,data,[params params],NaN);
                case 5
                    data = sffilt(@stdOmitNaN,data,[params params],NaN);
                otherwise
                    %nothing to do (no filtering)
            end
        end
    end%methods(protected)

    methods(Static)
        function [data,idx] = getImgSeg(data,ROICoord,ROIType,ROISubType,ROIVicinity,fileInfo,vicinityInfo,reducedOutsideFlag)
            %make current data segment respecting x / y scaling
            %data can be 2- or 3- dimensional
            %also returns indices of data in full image
            if(nargin < 7)
                reducedOutsideFlag = false;
            end
            idx = [];
            if(isempty(data) || isempty(ROICoord) || ~any(ROICoord(:)))
                data = [];
                return;
            end
            if(~isempty(vicinityInfo))
                vicDist = vicinityInfo.vicinityDistance;
                vicDiameter = vicinityInfo.vicinityDiameter;
            else
                vicDist = 1;
                vicDiameter = 3;
                %todo: warning/error message
            end
            [y,x,z] = size(data);
            if(ROIType  == 0)
                idx = (1:uint32(numel(data)))';
            elseif(ROIType > 1000 && ROIType < 2000)
                %ETDRS grid
                if(~isempty(fileInfo))
                    res = fileInfo.pixelResolution;
                    side = fileInfo.position;
                else
                    res = 58.66666666666;
                    side = 'OS';
                    %todo: warning/error message
                end
                rCenter = (1000/res/2);
                rInner = (3000/res/2);
                rOuter = (6000/res/2);
                switch ROISubType
                    case 1 %central
                        thetaRange = [0, pi; -pi, pi];
                        r = rCenter;
                    case 2 %inner superior
                        thetaRange = [pi/4, pi/2; pi/2, 3*pi/4];
                        r = rInner;
                    case 3 %inner nasal
                        if(strcmp(side,'OS'))
                            thetaRange = [3*pi/4, pi; -pi, -3*pi/4];
                        else
                            thetaRange = [-pi/4, 0; 0, pi/4];
                        end
                        r = rInner;
                    case 4 %inner inferior
                        thetaRange = [-3*pi/4, -pi/2; -pi/2, -pi/4];
                        r = rInner;
                    case 5 %inner temporal
                        if(strcmp(side,'OS'))
                            thetaRange = [-pi/4, 0; 0, pi/4];
                        else
                            thetaRange = [3*pi/4, pi; -pi, -3*pi/4];
                        end
                        r = rInner;
                    case 6 %outer superior
                        thetaRange = [pi/4, pi/2; pi/2, 3*pi/4];
                        r = rOuter;
                    case 7 %outer nasal
                        if(strcmp(side,'OS'))
                            thetaRange = [3*pi/4, pi; -pi, -3*pi/4];
                        else
                            thetaRange = [-pi/4, 0; 0, pi/4];
                        end
                        r = rOuter;
                    case 8 %outer inferior
                        thetaRange = [-3*pi/4, -pi/2; -pi/2, -pi/4];
                        r = rOuter;
                    case 9 %outer temporal
                        if(strcmp(side,'OS'))
                            thetaRange = [-pi/4, 0; 0, pi/4];
                        else
                            thetaRange = [3*pi/4, pi; -pi, -3*pi/4];
                        end
                        r = rOuter;
                    case 10 %inner ring
                        thetaRange = [-pi, 0; 0, pi];
                        r = rInner;
                    case 11 %outer ring
                        thetaRange = [-pi, 0; 0, pi];
                        r = rOuter;
                    case 12 %full circle
                        thetaRange = [-pi, 0; 0, pi];
                        r = rOuter;
                    case 13 %center + inner ring
                        thetaRange = [-pi, 0; 0, pi];
                        r = rInner;
                    case 14 %center + outer ring
                        thetaRange = [-pi, 0; 0, pi];
                        r = rOuter;
                    case 15 %inner + outer ring
                        thetaRange = [-pi, 0; 0, pi];
                        r = rOuter;
                end
                [tmpData,idx] = FData.getCircleSegment(data,ROICoord(:,1),r,thetaRange,ROISubType,rCenter,rInner,1,0,0);
                if(ROIVicinity == 1)
                    data = tmpData;
                elseif(ROIVicinity == 2)
                    mask = true(y,x);
                    mask(idx) = false;
                    data(idx) = NaN;
                    idx = find(mask);
                elseif(ROIVicinity == 3)
                    mask = false(y,x);
                    mask(idx) = true;
                    outerMask = FData.computeVicinityMask(mask,vicDist,vicDiameter);
                    data(~outerMask) = NaN;
                    idx = find(outerMask);
                end
                data = FData.removeNaNBoundingBox(data);
            elseif(ROIType > 2000 && ROIType < 3000)
                %rectangle
                rc = zeros(2,4);
                rc(:,1) = ROICoord(:,1);
                rc(:,2) = [ROICoord(1,2);ROICoord(2,1);];
                rc(:,3) = ROICoord(:,2);
                rc(:,4) = [ROICoord(1,1);ROICoord(2,2);];
                rc(2,1:2) = rc(2,1:2)-0.5; %workaround for specific poly2mask behavior
                rc(1,[1,4]) = rc(1,[1,4])-0.5; %workaround for specific poly2mask behavior
                mask = poly2mask(rc(2,:),rc(1,:),y,x);
                if(ROIVicinity == 1)
                    data(~mask) = NaN;
                    idx = find(mask);
                elseif(ROIVicinity == 2)
                    if(reducedOutsideFlag)
                        mask(1:min(y,max(1,ROICoord(1,1)-1)),1:min(x,max(1,ROICoord(2,1)-1))) = true;
                        mask(min(y,max(1,ROICoord(1,2)+1)):end,1:min(x,max(1,ROICoord(2,1)-1))) = true;
                        mask(1:min(y,max(1,ROICoord(1,1)-1)),min(x,max(1,ROICoord(2,2)+1)):end) = true;
                        mask(min(y,max(1,ROICoord(1,2)+1)):end,min(x,max(1,ROICoord(2,2)+1)):end) = true;
                    end
                    data(mask) = NaN;
                    idx = find(~mask);
                elseif(ROIVicinity == 3)
                    outerMask = FData.computeVicinityMask(mask,vicDist,vicDiameter);
                    data(~outerMask) = NaN;
                    idx = find(outerMask);                    
                end
                data = FData.removeNaNBoundingBox(data);
            elseif(ROIType > 3000 && ROIType < 4000)
                %circle
                r = sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                thetaRange = [-pi, 0; 0, pi];
                [data,idx] = FData.getCircleSegment(data,ROICoord(:,1),r,thetaRange,0,[],[],ROIVicinity,vicDist,vicDiameter);
            elseif(ROIType > 4000 && ROIType < 5000)
                %polygon
                %check whether there are at least three vertices of the polygon yet
                [~,vertices] = size(ROICoord);
                if(vertices > 2)
                    %create mask out of polygon
                    mask0 = false(y,x);
                    %clip pixels outside the image
                    ROICoord(1,ROICoord(1,:) > y) = y;
                    ROICoord(1,ROICoord(1,:) < 1) = 1;
                    ROICoord(2,ROICoord(2,:) > x) = x;
                    ROICoord(2,ROICoord(2,:) < 1) = 1;
                    mask0(sub2ind([y,x],ROICoord(1,:),ROICoord(2,:))) = true;
                    [minY, posY] = min(ROICoord(1,:));
                    [minX, posX] = min(ROICoord(2,:));
                    ROICoord(1,posY) = minY-0.5; %workaround for specific poly2mask behavior
                    ROICoord(2,posX) = minX-0.5; %workaround for specific poly2mask behavior
                    mask = poly2mask(ROICoord(2,:),ROICoord(1,:),y,x);
                    %make sure ROI coordinates are part of mask (buggy poly2mask behavior)
                    mask = mask | mask0;
                    %apply mask to data, delete all rows and columns which
                    %are unneeded(outside of the Polygon)
                    if(ROIVicinity == 1)
                        data(~mask) = NaN;
                        idx = find(~isnan(data));
                        data(~any(~isnan(data),2),:) = [];
                        data(: ,~any(~isnan(data),1)) = [];                        
                    elseif(ROIVicinity == 2)
                        data(mask) = NaN;
                        idx = find(~mask);
                    elseif(ROIVicinity == 3)
                        outerMask = FData.computeVicinityMask(mask,vicDist,vicDiameter);
                        data(~outerMask) = NaN;
                        idx = find(outerMask);                        
                    end
                    data = FData.removeNaNBoundingBox(data);
                end
            end
            idx = uint32(idx);
        end

        function [out,idx] = getCircleSegment(data,coord,r,thetaRange,ROISubType,rCenter,rInner,ROIVicinity,vicDist,vicDiameter)
            %get sircle or a segment of a circle from data at position coord
            if(ROIVicinity == 3)
                [out,idx] = FData.getCircleSegment(data,coord,r++vicDist+vicDiameter,thetaRange,11,0,r+vicDist,1,0,0);
                return
            end
            [y,x,z] = size(data);
            px = -ceil(r):ceil(r);
            [xCord,yCord] = meshgrid(px, px);
            [theta,rho] = cart2pol(xCord,yCord);
            mask = rho <= r & (theta <= thetaRange(1,2) & theta >= thetaRange(1,1) | theta <= thetaRange(2,2) & theta >= thetaRange(2,1));
            if(ROISubType > 5 && ROISubType ~= 10 && ROISubType < 12)
                mask(rho < rInner) = false;
            elseif((ROISubType > 1 && ROISubType < 6) || ROISubType == 10 || ROISubType == 15)
                mask(rho < rCenter) = false;
            elseif(ROISubType == 14)
                mask(rho > rCenter & rho < rInner) = false;
            end
            %cut off unused pixels
            cols = any(mask,1);
            rows = any(mask,2);
            Ym = int32(yCord(rows,cols));
            Xm = int32(xCord(rows,cols));
            mask = mask(rows,cols);
            %move mask to coordinates of pixel position
            Ym(:) = Ym(:) + int32(coord(1,1));
            Xm(:) = Xm(:) + int32(coord(2,1));
            %coordinates must be between 1 and size of the data matrix
            mask = mask & Ym <= y & Ym > 0 & Xm <= x & Xm > 0;
            %there might new unused pixels -> cut them off
            cols = any(mask,1);
            rows = any(mask,2);
            Ym = Ym(rows,cols);
            Xm = Xm(rows,cols);
            mask = mask(rows,cols);
            %create output matrix, unused / empty pixels are NaN
            if(ROIVicinity == 1)
                out = nan(size(mask),'like',data);
                %idx = sub2ind([dataYSz,dataXSz],tmpYcoord(mask),tmpXcoord(mask));
                idx = Ym(mask)+y.*(Xm(mask)-1);
                out(mask) = data(idx);
            elseif(ROIVicinity == 2)
                idx = Ym(mask)+y.*(Xm(mask)-1);
                out = data;
                out(idx) = NaN;
                idx = find(~isnan(out));
                idx = idx(:);
            end
        end

        function outerMask = computeVicinityMask(mask,vicDist,vicDiameter)
            %compute a vicinity mask from an ROI mask
            %             outerMask = mask;
            %             kernel = true(3,3);
            %             for i = 1:vicDist+vicDiameter
            %                 outerMask = imdilate(outerMask,kernel);
            %             end
            %             innerMask = mask;
            %             for i = 1:vicDist
            %                 innerMask = imdilate(innerMask,true(2*vicDist+1));
            %             end
            outerMask = imdilate(mask,true(2*(vicDist+vicDiameter)+1));
            innerMask = imdilate(mask,true(2*vicDist+1));
            outerMask(innerMask) = false;
        end

        function data = removeNaNBoundingBox(data)
            %return only valid data, remove surrounding NaNs
            if(isempty(data))
                return
            end
            try %workaround for rare error of unknown reason
                idx = any(~isnan(data),2);
                data = data(find(idx,1,'first'):find(idx,1,'last'),:);
                idx = any(~isnan(data),1);
                data = data(:,find(idx,1,'first'):find(idx,1,'last'));
            catch ME
                data = [];
            end
        end

        function out = getNonInfMinMax(param,data)
            %get minimum (param = 1) or maximum (param = 2) of data, in case of "inf" get next smallest value
            out = [];
            data = data(~isinf(data));
            switch param
                case 1
                    out = min(data(:),[],'omitnan');
                case 2
                    out = max(data(:),[],'omitnan');
            end
            if(isempty(out))
                %all data is zero
                out = 0;
            end
        end
        
        function [histogram, centers] = computeHistogram(imageData,classWidth,limitFlag,classMin,classMax,maxHistClasses,dType,id,strictFlag)
            %make histogram for display puposes
            ci = imageData(~(isnan(imageData(:)) | isinf(imageData(:))));
            if(isempty(ci))
                histogram = [];
                centers = [];
                return
            end
            %[classWidth,limitFlag,classMin,classMax] = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
            if(limitFlag)
                ci = ci(ci >= classMin & ci <= classMax);
            else
                classMin = round((min(ci(:)))/classWidth)*classWidth;
                classMax = round((max(ci(:)))/classWidth)*classWidth;
            end
            if(classMax - classMin < eps)
                %flat data -> max = min, just leave it in one class
                histogram = numel(ci);
                centers = classMin;
                return
            end
            %make centers vector
            centers = classMin : classWidth : classMax;
            %check over under-/overflows
            if(~limitFlag && numel(centers) <= 1)
                cw_old = classWidth;
                classWidth = (classMax-classMin)/100;
                %make centers vector
                centers = classMin : classWidth : classMax;
                %check if still too small (should not happen)
                if(strictFlag || numel(centers) <= 1)
                    %give up
                    histogram = numel(ci);
                    centers = classMin;
                    return
                end
                warning('FLIMX:FData:computeHistogram','Classwidth (%.1f) for %s %d is too big. Only one class would be computed. Please reduce classwidth to %.1f or less. Classwidth has been reduced to that value temporarily.',cw_old,dType,id,classWidth);
            end
            if(~limitFlag && ~strictFlag && numel(centers) > maxHistClasses)
                cw_old = classWidth;
                nc_old = numel(centers);
                classWidth = (classMax-classMin)/maxHistClasses;
                centers = classMin : classWidth : classMax;
                warning('FLIMX:FData:computeHistogram','Classwidth (%.1f) for %s %d is too small. %d classes would be computed. Please increase classwidth to %.1f or more. Classwidth has been increased to that value temporarily.',cw_old,dType,id,nc_old,classWidth);
            end
            histogram = hist(ci,centers);
        end

        function stats = computeDescriptiveStatistics(imageData,imageHistogram,imageHistogramCenters)
            %compute descriptive statistics using imageData and imageHistogram and return it in a cell array; get description from getDescriptiveStatisticsDescription()
            [~, pos] = max(imageHistogram);
            stats = zeros(10,1);
            if(isempty(imageHistogramCenters))
                stats(1) = NaN;
            else
                stats(1) = imageHistogramCenters(min(pos,length(imageHistogramCenters)));
            end
            stats(2) = median(imageData,'omitnan');
            stats(3) = mean(imageData,'omitnan');
            stats(4) = var(imageData,'omitnan');
            stats(5) = std(imageData,'omitnan');
            stats(6) = 100*stats(5)./stats(3);
            stats(7) = skewness(imageData);
            stats(8) = kurtosis(imageData);
            px = numel(imageData);
            t = icdf('t',1-(1-0.95)/2,px-1); %confidence level 95%
            stats(9) = stats(3) - t*stats(5)/sqrt(px);
            stats(10) = stats(3) + t*stats(5)/sqrt(px);
            stats(11) = sum(imageData(:),'omitnan');
            stats(12) = numel(imageData);
        end

        function out = getDescriptiveStatisticsDescription()
            %get statistcs descriptions of current image
            out = [{'Mode'}; {'Median'}; {'Mean'}; {'Variance'}; {'Standard Deviation'}; {'Coefficient of Variation'}; {'Skewness'}; {'Kurtosis'}; {'Confidence Interval (lower)'}; {'Confidence Interval (upper)'}; {'Total'}; {'Pixel'}];
        end

        function out = getDescriptiveStatisticsDescriptionShort()
            %get statistcs descriptions of current image
            out = [{'Mode'}; {'Median'}; {'Mean'}; {'Var.'}; {'SD'}; {'CV'}; {'Skew.'}; {'Kurt.'}; {'CI low'}; {'CI high'}; {'Total'}; {'Pixel'}];
        end
    end %methods(static)
end %classdef
