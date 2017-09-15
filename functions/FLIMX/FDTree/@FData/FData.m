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
    properties(SetAccess = protected,GetAccess = public)
        uid = []; %unique object identifier
        id = 0; %running number        
        sType = [];
        rawImage = [];
        rawImgFilt = [];
        color_data = [];
        logColor_data = [];
        rawImgXSz = [];
        rawImgYSz = [];  
        rawImgZSz = [];
        %MSZ = false;
    end
    properties(Dependent = true, SetAccess = public,GetAccess = public) 
        dType = [];
        globalScale = [];       
        subjectName = [];
        channel = [];
        nr = [];        
        isEmptyStat = true;
        FLIMXParamMgrObj = [];
    end
    properties(SetAccess = protected,GetAccess = protected)
        myParent = [];
        %MSZMin = [];
        %MSZMax = [];
        cachedImage = [];
        maxHistClasses = 5000;
    end
    
    methods
        function this = FData(parent,id,rawImage)
            %  
            this.uid = datenum(clock);
            this.id = id;            
            this.sType = 1;         %default to linear data
            this.myParent = parent;
            this.setRawData(rawImage); 
            this.clearCachedImage();
            this.color_data = [];
            this.logColor_data = [];
        end
        
        function clearCachedImage(this)
            %reset all fields of the cached image
            ci.ROI.ROICoordinates = zeros(2,2,'int16');
            ci.ROI.ROIType = 0;
            ci.ROI.ROISubType = 0;
            ci.ROI.ROIInvertFlag = 0;
            ci.data = [];
            ci.colors = [];
            ci.info.ZMin = [];
            ci.info.ZMax = [];
            ci.info.ZLblMin = [];
            ci.info.ZLblMax = [];
            ci.info.XSz = [];            
            ci.info.YSz = [];
            ci.info.XLblStart = [];
            ci.info.XLblTick = [];
            ci.info.YLblStart = [];
            ci.info.YLblTick = [];
            ci.statistics.descriptive = [];
            ci.statistics.histogram = [];
            ci.statistics.histogramCenters = [];
            ci.statistics.histogramStrict = [];
            ci.statistics.histogramStrictCenters = [];
            this.cachedImage = ci;
        end
        
        function flag = eq(obj1,obj2)
            %compare two FData objects            
            if(obj1.uid - obj2.uid < eps('double'))
                flag = true;
            else
                flag = false;
            end
        end
           
        %% input functions
        function setRawData(this,val)
            %
            this.rawImage = single(val);
            this.color_data = [];
            this.logColor_data = [];
%             this.curImgColors = [];
            this.setRawDataXSz([]);
            this.setRawDataYSz([]);  
            this.setRawDataZSz([]);
            this.rawImgFilt = [];
            this.clearCachedImage();
            if(isempty(val))                
                return;                
            end
            [y, x] = size(val);
            this.setRawDataXSz([1 x]);
            this.setRawDataYSz([1 y]);
            %val = this.getFullImage(); %expensive but correct
            this.setRawDataZSz([FData.getNonInfMinMax(1,val) FData.getNonInfMinMax(2,val)]);            
            %this.clearCachedImage();
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
        
%         function setCIROICoordinates(this,val)
%             %set coordinates of cached ROI
%             this.cachedImage.ROI.ROICoordinates = val;
%         end
        
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
                tick = 1;
            else
                start = start(1);
            end
            this.cachedImage.info.XLblStart = start;
            this.cachedImage.info.XLblTick = tick;
        end
        
        function setupYLbl(this,start,tick)
            %set start value and tick (width) for custom y labels
            if(isempty(start) || isempty(tick))
                tick = 1;
            else
                start = start(1);
            end
            this.cachedImage.info.YLblStart = start;
            this.cachedImage.info.YLblTick = tick;
        end
        
        function setSType(this,val)
            %set sType (lin=1,log=2 perc=3)
            if(this.sType == val)
                %check if new scale type differs from old one
                return
            end
            this.sType = val;
            tmp = this.getFullImage();
            this.rawImgZSz = [FData.getNonInfMinMax(1,tmp) FData.getNonInfMinMax(2,tmp)];
%             if(val == 2)                
%                 %set init-values borders for log scaling                
%                 this.MSZMin = log10(this.MSZMin);
%                 this.MSZMax = log10(this.MSZMax);
%             else
%                 %set init-values for linear scaling
%                 this.MSZMin = 10^this.MSZMin;
%                 this.MSZMax = 10^this.MSZMax;
%             end                        
            this.clearCachedImage();
        end          
        
        %% output functions
        function out = get.dType(this)
            %get current data type
            out = this.myParent.getDType();
        end
        
        function out = get.globalScale(this)
            %get global scale flag
            out = this.myParent.getGlobalScale();
        end        
                
        function nr = get.channel(this)
            %
            nr = this.myParent.getMyChannelNr();
        end
        
        function nr = get.subjectName(this)
            %
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
                    stepSize = this.cachedImage.info.YLblTick;
                end                
            else %x
                ROIlb = coord(2,1);
                ROIub = coord(2,2);
                if(~isMatrixPos)
                    ROIlb = this.xPos2Lbl(ROIlb);
                    ROIub = this.xPos2Lbl(ROIub);
                    stepSize = this.cachedImage.info.XLblTick;
                end
            end
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
            %
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
        
        function out = getFullImage(this)
            %get raw image with respect to linear/log scaling
            out = this.rawImage;
            scaling = this.sType;
            %scale to log
            if(scaling == 2)
                out = log10(abs(out)); %turn negative values positive
                out(isinf(out)) = 0;
            end
            %don't filter intensity image
            if(~(strcmpi(this.dType,'intensity') || strncmp('MVGroup',this.dType,7) || strncmp('ConditionMVGroup',this.dType,16) || strncmp('GlobalMVGroup',this.dType,13)))
                if(isempty(this.rawImgFilt))
                    out = this.filter(out);
                    this.rawImgFilt = out;
                else
                    out = this.rawImgFilt;
                end
            end
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            out = this.myParent.getROICoordinates(ROIType);
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
        
        function [ROICoordinates, ROIType, ROISubType, ROIInvertFlag] = getCachedImageROIInfo(this)
            %get ROI info of cached image
            ROI = this.cachedImage.ROI;
            ROICoordinates = ROI.ROICoordinates;
            ROIType = ROI.ROIType;
            ROISubType = ROI.ROISubType;
            ROIInvertFlag = ROI.ROIInvertFlag;
        end
        
        function out = getROIImage(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get cached image
            %use whole image if we don't get ROI coordinates
            if(isempty(ROICoordinates))
                ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
            end
%             if(~isempty(ROIType) && ROIType >= 1)
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                    %we've got this image segment already
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
                end
                out = this.cachedImage.data;
%             elseif(~isempty(ROIType) && ROIType == 0)
%                 out = this.getFullImage();
%                 if(this.MSZ)
%                     cim = FData.getNonInfMinMax(1,out);
%                     %set possible "-inf" in ci to "cim"
%                     out(out < cim) = cim;
%                     zlim_min = this.getZlimMin(cim);
%                     zlim_max = this.MSZMax;
%                     out(out < zlim_min) = NaN;%zlim_min;
%                     out(out > zlim_max) = NaN;%zlim_max;
%                 end
%             else
%                 out = [];
%             end            
        end
        
        function out = getCIColor(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get current image colors
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag) || isempty(this.cachedImage.colors) && ~isempty(this.color_data))
                %update only if we have color data
                this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            end
            out = this.cachedImage.colors;
        end
        
        function out = getCImin(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get minimum of current image
            if(ROIType == 0)
                out = this.rawImgZSz(1);
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
                end
                out = this.cachedImage.info.ZMin;
            end
        end
        
        function out = getCImax(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get maximum of current image
            if(ROIType == 0)
                out = this.rawImgZSz(2);
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
                end
                out = this.cachedImage.info.ZMax;
            end
        end
        
        function out = getCIminLbl(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get label for minimum of current image
            if(ROIType == 0)
                zVec = this.getZScaling();
                if(length(zVec) == 3 && zVec(1))
                    out = this.makeZlbls(zVec(2),zVec(3));
                else
                    out = this.makeZlbls(this.rawImgZSz(1),this.rawImgZSz(2));
                end
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
                end
                out = this.cachedImage.info.ZLblMin;
            end
        end
        
        function out = getCImaxLbl(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get label for maximum of current image
            if(ROIType == 0)
                zVec = this.getZScaling();
                if(length(zVec) == 3 && zVec(1))
                    [~,out] = this.makeZlbls(zVec(2),zVec(3));
                else
                    [~,out] = this.makeZlbls(this.rawImgZSz(1),this.rawImgZSz(2));
                end
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                    this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
                end
                out = this.cachedImage.info.ZLblMax;
            end
        end
        
        function out = getRIXLbl(this)
            %get x labels for raw image
            if(~isempty(this.cachedImage.info.XLblStart) && ~isempty(this.rawImgXSz))
                out = this.xPos2Lbl(1) : this.cachedImage.info.XLblTick : this.xPos2Lbl(this.rawImgXSz(2));
            elseif(isempty(this.cachedImage.info.XLblStart) && ~isempty(this.rawImgXSz))
                out = 1:1:this.rawImgXSz(2);
            else
                out = [];
            end            
        end
        
        function out = ROIIsCached(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %check if this ROI is in my cache
            out = false;
            if(isempty(ROICoordinates))
                return
            end            
            [cROICoordinates, cROIType, cROISubType, cROIInvertFlag] = this.getCachedImageROIInfo();
            if(isempty(cROICoordinates))
                return
            end  
            if(all(size(cROICoordinates) == size(ROICoordinates)) && all(cROICoordinates(:) == ROICoordinates(:)) && cROIType == ROIType && cROISubType == ROISubType && cROIInvertFlag == ROIInvertFlag && ~isempty(this.cachedImage.data))
                out = true;
            end
        end
        
        function out = getCIXLbl(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get x labels for current image
            if(isempty(this.rawImgXSz))
                out = [];
                return
            end
            if(ROIType == 0)
                if(isempty(ROICoordinates))
                    XSz = this.rawImgXSz(2);
                else
                    XSz = ROICoordinates(2,2);
                end
                XLblStart = [];
                XLblTick = 1;
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag); 
                end
                XSz = this.cachedImage.info.XSz;
                XLblStart = this.cachedImage.info.XLblStart;
                XLblTick = this.cachedImage.info.XLblTick;
            end
            if(~isempty(ROICoordinates) && (ROIType == 0 || ROIType == 2 || ROIType == 3))
                shift = ROICoordinates(2,1)-1;
            else
                shift = 0;
            end
            if(isempty(XLblStart))
                out = 1+shift:1:XSz+shift;
            else
                out = this.xPos2Lbl(1+shift) : XLblTick : this.xPos2Lbl(XSz+shift);
            end
        end
        
        function out = xPos2Lbl(this,pos)
            %convert absolut matrix position of x axis to label
            if(isempty(this.cachedImage.info.XLblStart))
                out = pos;
            else
                out = this.cachedImage.info.XLblStart + (pos-1)*this.cachedImage.info.XLblTick;
            end
        end
        
        function out = xLbl2Pos(this,lbl)
            %convert label of x axis to absolut matrix position
            if(isempty(this.cachedImage.info.XLblStart))
                out = lbl;
            else
                out = round((lbl - this.cachedImage.info.XLblStart)/this.cachedImage.info.XLblTick+1);
            end
        end
        
        function out = getXLblTick(this)
            %get tick (step) size of x axis labels
            if(isempty(this.cachedImage.info.XLblTick))
                out = 1;
            else
                out = this.cachedImage.info.XLblTick;
            end
        end        
        
        function out = getRIYLbl(this)
            %get y labels for raw image
            if(~isempty(this.cachedImage.info.YLblStart) && ~isempty(this.rawImgYSz))
                out = this.yPos2Lbl(1) : this.cachedImage.info.YLblTick : this.yPos2Lbl(this.rawImgYSz(2));
            elseif(isempty(this.cachedImage.info.YLblStart) && ~isempty(this.rawImgYSz))
                out = 1:1:this.rawImgYSz(2);
            else
                out = [];
            end
        end
        
        function out = getCIYLbl(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get x labels for current image
            if(isempty(this.rawImgYSz))
                out = [];
                return
            end
            if(ROIType == 0)
                if(isempty(ROICoordinates))
                    YSz = this.rawImgYSz(2);
                else
                    YSz = ROICoordinates(2,2);
                end
                YLblStart = [];
                YLblTick = 1;
            else
                if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag); 
                end
                YSz = this.cachedImage.info.YSz;
                YLblStart = this.cachedImage.info.YLblStart;
                YLblTick = this.cachedImage.info.YLblTick;
            end
            if(~isempty(ROICoordinates) && (ROIType == 0 || ROIType == 2 || ROIType == 3))
                shift = ROICoordinates(1,1)-1;
            else
                shift = 0;
            end
            if(isempty(YLblStart))
                out = 1+shift:1:YSz+shift;
            else
                out = this.YPos2Lbl(1+shift) : YLblTick : this.YPos2Lbl(YSz+shift);
            end
        end
        
        function out = yPos2Lbl(this,pos)
            %convert absolut matrix position of x axis to label
            if(isempty(this.cachedImage.info.YLblStart))
                out = pos;
            else
                out = this.cachedImage.info.YLblStart + (pos-1)*this.cachedImage.info.YLblTick;
            end
        end
        
        function out = yLbl2Pos(this,lbl)
            %convert label of y axis to absolut matrix position
            if(isempty(this.cachedImage.info.YLblStart))
                out = lbl;
            else
                out = round((lbl - this.cachedImage.info.YLblStart)/this.cachedImage.info.YLblTick+1);
            end
        end
        
        function out = getYLblTick(this)
            %get tick (step) size of y axis labels
            if(isempty(this.cachedImage.info.YLblTick))
                out = 1;
            else
                out = this.cachedImage.info.YLblTick;
            end
        end
        
        function out = zPos2Lbl(this,out)
            %dummy - no functioniality
        end
        
        function out = zLbl2Pos(this,out)
            %dummy - no functioniality
        end
        
        function out = getCIxSz(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get size in x of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            end
            out = this.cachedImage.info.XSz;
        end
        
        function out = getCIySz(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get size in y of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                   this.updateCurrentImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag); 
            end
            out = this.cachedImage.info.YSz;
        end
        
        function [hist,centers] = getCIHist(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get histogram of current image
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag))
                this.clearCachedImage();
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            elseif(this.isEmptyStat)               
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            end
            hist = this.cachedImage.statistics.histogram;
            centers = this.cachedImage.statistics.histogramCenters;
        end
        
        function [hist,centers] = getCIHistStrict(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get histogram of current image using strict rules            
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag) || isempty(this.cachedImage.statistics.histogramStrict))
                [~, this.cachedImage.statistics.histogramStrict, this.cachedImage.statistics.histogramStrictCenters] = this.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIInvertFlag,true);
            end
            hist = this.cachedImage.statistics.histogramStrict;
            centers = this.cachedImage.statistics.histogramStrictCenters;
        end
                
        function out = getROIStatistics(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get statistcs of current image
            %check 
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag) || this.isEmptyStat)
                this.updateCIStats(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            end
            out = this.cachedImage.statistics.descriptive;
        end
        
        function out = getLinData(this)
            %
            this.setSType(1);
            out = this;
        end
        
        function out = getLogData(this)
            %        
            this.setSType(2);
            out = this;
        end
        
        function out = getPerData(this)
            %
            out = this.myParent.getPerData();
        end
        
        function out = getSaveMaxMemFlag(this)
            %get saveMaxMem flag from parent
            out = this.myParent.getSaveMaxMemFlag();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end      
        
        %% compute functions
        function clearRawImage(this)
            %clear raw image data
            this.rawImage = [];            
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
%             out = [];
%             if(ROIType < 1)
%                 return
%             end
            ri = this.getFullImage();
            out = zeros(9,1);
            for i = 1:9
                ci = this.getImgSeg(ri,ROICoord,ROIType,i,0,this.getFileInfoStruct()); %ROICoord,ROIType,ROISubType,ROIInvertFlag,fileInfo
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
                        out(i,1) = mean(ci(:));
                    case 'median'
                        out(i,1) = median(ci(:));    
                    case 'SD'
                        out(i,1) = std(ci(:));
                    case 'CV'
                        out(i,1) = 100*std(ci(:))./mean(ci(:));
                end
            end
        end
        
        function [stats, histogram, histCenters] = makeStatistics(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag,strictFlag)
            %make statistics for a certain ROI
%             if(~isempty(ROICoordinates))                
                ci = this.getROIImage(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
%             else
%                 ROICoordinates = [this.rawImgYSz; this.rawImgXSz];
%                 ci = this.getImgSeg(this.getFullImage(),ROICoordinates,2,0,0,this.getFileInfoStruct());
%             end
            ci = ci(~(isnan(ci(:)) | isinf(ci(:))));
            [histogram, histCenters] = this.makeHist(ci,strictFlag);
            stats = FData.computeDescriptiveStatistics(ci,histogram,histCenters);            
        end
        
        function updateCIStats(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %make statistics
            if(~this.ROIIsCached(ROICoordinates,ROIType,ROISubType,ROIInvertFlag) || this.isEmptyStat)%calculate statistics only if necessary
                [statistics.descriptive, statistics.histogram, statistics.histogramCenters] = this.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIInvertFlag,false);
                this.cachedImage.statistics = statistics;
            end
        end              
        
        function [histogram, centers] = makeHist(this,imageData,strictFlag)
            %make histogram for display puposes
            ci = imageData(~(isnan(imageData(:)) | isinf(imageData(:))));
            %ci = ci(~isinf(ci(:)));
%             %if z scaled, remove cut of values
%             if(this.MSZ)          
%                 zlim_min = this.getZlimMin(this.getNonInfMin(2,imageData));
%                 zlim_max = this.MSZMax;
%                 ci(ci == zlim_min) = [];
%                 ci(ci == zlim_max) = [];
%             end
            [cw,lim,c_min,c_max] = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
            if(lim)
                ci = ci(ci >= c_min & ci <= c_max);               
            else
                c_min = round((min(ci(:)))/cw)*cw;%min(ci(:));
                c_max = round((max(ci(:)))/cw)*cw;%max(ci(:));                
            end
            if(c_max - c_min < eps)
                %flat data -> max = min, just leave it in one class
                histogram = numel(ci);
                centers = c_min;
                return
            end
            %make centers vector
            centers = c_min : cw : c_max;            
            %check over under-/overflows
            if(~lim && numel(centers) <= 1)
                cw_old = cw;
                cw = (c_max-c_min)/100;
                %make centers vector
                centers = c_min : cw : c_max;
                %check if still to small (should not happen) 
                if(numel(centers) <= 1 || strictFlag)
                    %give up
                    histogram = numel(ci);
                    centers = c_min;
                    return
                end
                warning('FLMVisM:FData:Statistics','Classwidth (%.1f) for %s %d is too big. Only one class would be computed. Please reduce classwidth to %.1f or less. Classwidth has been reduced to that value temporarily.',cw_old,this.dType,this.id,cw);
            end
            if(~lim && numel(centers) > this.maxHistClasses && ~strictFlag)
                cw_old = cw;
                nc_old = numel(centers);
                cw = (c_max-c_min)/this.maxHistClasses;
                centers = c_min : cw : c_max;
                warning('FLMVisM:FData:Statistics','Classwidth (%.1f) for %s %d is too small. %d classes would be computed. Please increase classwidth to %.1f or more. Classwidth has been increased to that value temporarily.',cw_old,this.dType,this.id,nc_old,cw);  
            end
            histogram = hist(ci,centers);
        end  
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
    end %methods
    
    methods (Access = protected)
        function zl_min = getZlimMin(this,cim)
            %
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
            %
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
                    data = sffilt(@mean,data,[params params]);
                case 2
                    data = sffilt(@median,data,[params params]);
                case 3
                    data = smoothn(data,'robust');
                case 4
                    %dataSmooth = hmf(data,3);
                    data = sffilt(@var,data,[params params]);
                case 5
                    data = sffilt(@std,data,[params params]);    
                otherwise
                    %nothing to do (no filtering)
            end
        end
    end%methods(protected)
    
    methods(Static)
        function [data,idx] = getImgSeg(data,ROICoord,ROIType,ROISubType,ROIInvertFlag,fileInfo)
            %make current data segment respecting x / y scaling
            %data can be 2- or 3- dimensional
            idx = [];
            if(isempty(data) || isempty(ROICoord))                
                return;
            end
            [y,x,z] = size(data);
            switch ROIType
                case 1 %ETDRS grid
                    %fi = this.getFileInfoStruct();
                    if(~isempty(fileInfo))
                        res = fileInfo.pixelResolution; %
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
                    [data,idx] = FData.getCircleSegment(data,ROICoord(:,1),r,thetaRange,ROISubType,rCenter,rInner);                    
                case {2,3} %rectangle
                    if(ROICoord(2,2) > x && ROICoord(2,1) < 1)
                        temp = zeros(y,ROICoord(2,2)-ROICoord(2,1)+1,z,'like',data);
                        temp(:,-ROICoord(2,1)+(1:x),:) = data(:,1:x,:);
                        data = temp;
                        clear temp;
                    elseif(ROICoord(2,2) > x)
                        temp = zeros(y,ROICoord(2,2)-ROICoord(2,1)+1,z,'like',data);
                        temp(:,ROICoord(2,1):x,:) = data(:,ROICoord(2,1):x,:);
                        data = temp;
                        clear temp;
                    elseif(ROICoord(2,1) < 1)
                        temp = zeros(y,ROICoord(2,2)-ROICoord(2,1)+1,z,'like',data);
                        temp(:,-ROICoord(2,1)+2:end,:) = data(:,1:ROICoord(2,2),:);
                        data = temp;
                        clear temp;
                    else
                        data = data(:,ROICoord(2,1):ROICoord(2,2),:);
                    end
                    %update x (size of curImg)
                    x = ROICoord(2,2)-ROICoord(2,1)+1;
                    if(ROICoord(1,2) > y && ROICoord(1,1) < 1)
                        temp = zeros(ROICoord(1,2)-ROICoord(1,1)+1,x,z,'like',data);
                        temp(-ROICoord(1,1)+(1:y),:,:) = data(1:y,:,:);
                        data = temp;
                        clear temp;
                    elseif(ROICoord(1,2) > y)
                        temp = zeros(ROICoord(1,2)-ROICoord(1,1)+1,x,z,'like',data);
                        temp(ROICoord(1,1):y,:,:) = data(ROICoord(1,1):y,:,:);
                        data = temp;
                        clear temp;
                    elseif(ROICoord(1,1) < 1)
                        temp = zeros(ROICoord(1,2)-ROICoord(1,1)+1,x,z,'like',data);
                        temp(-ROICoord(1,1)+2:end,:,:) = data(1:ROICoord(1,2),:,:);
                        data = temp;
                        clear temp;
                    else
                        data = data(ROICoord(1,1):ROICoord(1,2),:,:);
                    end
                case {4,5} %circle
                    r = sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                    thetaRange = [-pi, 0; 0, pi];
                    data = FData.getCircleSegment(data,ROICoord(:,1),r,thetaRange,0,[],[]);
                case {6,7} %polygon
                    %check whether there are at least three vertices of the polygon yet
                    [~,vertices]=size(ROICoord);
                    if(vertices > 2)
                        %create mask out of polygon
                        mask = poly2mask(ROICoord(2,:),ROICoord(1,:),y,x);
                        %apply mask to data, delete all rows and columns which
                        %are unneeded(outside of the Polygon)
                        data(~mask)=NaN;
                        data(~any(~isnan(data),2),:)=[];
                        data(: ,~any(~isnan(data),1))=[];
                    end
                otherwise
                    
            end
        end
        
        function [out,idx] = getCircleSegment(data,coord,r,thetaRange,ROISubType,rCenter,rInner)
            %get sircle or a segment of a circle from data at position coord
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
            Ym(:) = Ym(:) + coord(1,1);
            Xm(:) = Xm(:) + coord(2,1);
            %coordinates must be between 1 and size of the data matrix
            mask = mask & Ym <= y & Ym > 0 & Xm <= x & Xm > 0;
            %there might new unused pixels -> cut them off
            cols = any(mask,1);
            rows = any(mask,2);
            Ym = Ym(rows,cols);
            Xm = Xm(rows,cols);
            mask = mask(rows,cols);
            %create output matrix, unused / empty pixels are NaN
            out = nan(size(mask),'like',data);
            % idx = sub2ind([dataYSz,dataXSz],tmpYcoord(mask),tmpXcoord(mask));
            idx = Ym(mask)+y.*(Xm(mask)-1);
            out(mask) = data(idx);
        end
        
        function out = getNonInfMinMax(param,data)
            %get minimum (param = 1) or maximum (param = 2) of data, in case of "inf" get next smallest value
            out = [];
            data = data(~isinf(data));
            switch param
                case 1                    
                    out = min(data(:));
                case 2
                    out = max(data(:));
            end
            if(isempty(out))
                %all data is was zero
                out = 0;
            end
        end
        
        function stats = computeDescriptiveStatistics(imageData,imageHistogram,imageHistogramCenters)
            %compute descriptive statistics using imageData and imageHistogram and return it in a cell array; gete description from getDescriptiveStatisticsDescription()
            [~, pos] = max(imageHistogram);
            stats = zeros(10,1);
            if(isempty(imageHistogramCenters))
                stats(1) = NaN;
            else
                stats(1) = imageHistogramCenters(min(pos,length(imageHistogramCenters)));
            end
            stats(2) = median(imageData);
            stats(3) = mean(imageData);
            stats(4) = var(imageData);
            stats(5) = std(imageData);
            stats(6) = 100*stats(5)./stats(3);
            stats(7) = skewness(imageData);
            stats(8) = kurtosis(imageData);
            px = numel(imageData);
            t = icdf('t',1-(1-0.95)/2,px-1); %confidence level 95%
            stats(9) = stats(3) - t*stats(5)/sqrt(px);
            stats(10) = stats(3) + t*stats(5)/sqrt(px);
            stats(11) = sum(imageData(:));
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