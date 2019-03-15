classdef FDataNormal < FData
    %=============================================================================================================
    %
    % @file     FDataNormal.m
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
    % @brief    A class to represent a "normal" fluorescence lifetime parameter.  
    %
    properties(SetAccess = protected,GetAccess = protected)
        crossSectionX = false;
        crossSectionXVal = 0;
        crossSectionXInv = false;
        crossSectionY = false;
        crossSectionYVal = 0;
        crossSectionYInv = false;
    end
    
    
    methods
        function this = FDataNormal(parent,id,rawImage)
            %constructor of FDataNormal class
            this = this@FData(parent,id,rawImage);
            this.crossSectionX = 0;
            this.crossSectionXInv = 0;
            this.crossSectionY = 0;
            this.crossSectionYInv = 0;
        end
           
        %% input functions        
        function setResultCrossSection(this,dim,csDef)
            %set the cross section for dimension dim
            if(length(csDef) ~= 3)
                return
            end
            switch upper(dim)
                case 'X'
                    this.crossSectionX = logical(csDef(1));
                    this.crossSectionXVal = max(min(csDef(2),this.rawImgXSz(2)),1);
                    this.crossSectionXInv = logical(csDef(3));
                case 'Y'
                    this.crossSectionY = logical(csDef(1));
                    this.crossSectionYVal = max(min(csDef(2),this.rawImgYSz(2)),1);
                    this.crossSectionYInv = logical(csDef(3));
            end
            end
        
        %% output functions                        
        function out = getCrossSectionX(this)
            %get enable/disable flag for crossSection of x axis
            out = this.crossSectionX;
        end
        
        function [minVal, maxVal] = getCrossSectionXBorders(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get borders for x crossSection (minVal = 0 if crossSection disabled)
            lbl = this.getCIXLbl(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            minVal = lbl(1);
            maxVal = lbl(end);
        end
        
        function out = getCrossSectionXVal(this,isRelative,isMatrixPos,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get current crossSection position of x axis
            if(isRelative && ROIType ~= 0) %val is relative to roi
                switch ROIType
                    case 1
                        %todo
                        out = 0;
                        return
                    case {2,3}
                        xMin = ROICoordinates(2,1);
                    case {4,5}
                        r = sqrt(sum((ROICoordinates(:,1)-ROICoordinates(:,2)).^2));
                        xMin = ceil(ROICoordinates(2,1)-r);
                    otherwise
                        %todo
                        xMin = 0;
                end
                out = max(0,this.crossSectionXVal - xMin +1);
            else
                out = max(1,this.crossSectionXVal);
            end
            if(~isRelative && ~isMatrixPos)
                out = this.xPos2Lbl(out);
            end
        end
        
        function out = getCrossSectionXInv(this)
            %get current inv flag for crossSection of x axis
            out = this.crossSectionXInv;
        end
        
        function out = getCrossSectionY(this)
            %get enable/disable flag for crossSection of y axis
            out = this.crossSectionY;
        end
        
        function [minVal, maxVal] = getCrossSectionYBorders(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get borders for y crossSection (minVal = 0 if crossSection disabled)
            lbl = this.getCIYLbl(ROICoordinates,ROIType,ROISubType,ROIInvertFlag);
            minVal = lbl(1);
            maxVal = lbl(end);
        end
        
        function out = getCrossSectionYVal(this,isRelative,isMatrixPos,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get current crossSection position of y axis
            if(isRelative && ROIType ~= 0) %val is relative to roi
                switch ROIType
                    case 1
                        %todo
                        out = 0;
                        return
                    case {2,3}
                        yMin = ROICoordinates(1,1);
                    case {4,5}
                        r = sqrt(sum((ROICoordinates(:,1)-ROICoordinates(:,2)).^2));
                        yMin = ceil(ROICoordinates(1,1)-r);
                    otherwise
                        %todo
                        yMin = 0;
                end
                out = max(0,this.crossSectionYVal - yMin +1);
            else
                out = max(1,this.crossSectionYVal);
            end
            if(~isRelative && ~isMatrixPos)
                out = this.yPos2Lbl(out);
            end
        end
        
        function out = getCrossSectionYInv(this)
            %set current inv flag for crossSection of y axis
            out = this.crossSectionYInv;
        end

        %% compute functions         
        function out = updateCurrentImage(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %make current image segment from this.rawImage using x,y and z limits
            %compute minimum and maximum of this segment, also for labels (linear)
            if(isempty(this.rawImage))
                out = [];                                
                return
            end
            this.clearCachedImage();
            %cut ROI
            ci = this.getImgSeg(this.getFullImage(),ROICoordinates,ROIType,ROISubType,ROIInvertFlag,this.getFileInfoStruct());
            if(this.sType == 2)
                this.cachedImage.colors = this.getImgSeg(this.logColor_data,ROICoordinates,ROIType,ROISubType,ROIInvertFlag,this.getFileInfoStruct());
            else
                this.cachedImage.colors = this.getImgSeg(this.color_data,ROICoordinates,ROIType,ROISubType,ROIInvertFlag,this.getFileInfoStruct());
            end            
            cim = FData.getNonInfMinMax(1,ci);
            %set possible "-inf" in ci to "cim"
            %ci(ci < cim) = cim;            
            %limit z
            zVec = this.getZScaling();
            if(length(zVec) == 3 && zVec(1))
                zlim_min = this.getZlimMin(cim);
                zlim_max = zVec(3);
                ci(ci < zlim_min) = NaN;%zlim_min;
                ci(ci > zlim_max) = NaN;%zlim_max;
                info.ZMin = zlim_min;
                info.ZMax = FData.getNonInfMinMax(2,ci);
                %labels
                [info.ZLblMin, info.ZLblMax] = this.makeZlbls(zlim_min,zlim_max);
            else
                info.ZMin = cim;
                info.ZMax = FData.getNonInfMinMax(2,ci);
                %labels
                [info.ZLblMin, info.ZLblMax] = this.makeZlbls(info.ZMin,info.ZMax);
            end %limit z
            [info.YSz, info.XSz] = size(ci);
            info.XLblStart = [];
            info.XLblTick = this.getDefaultXLblTick();
            info.YLblStart = [];
            info.YLblTick = this.getDefaultYLblTick();            
            %make sure current crossSections are not beyond current image
            this.crossSectionX = min(this.crossSectionX,info.XSz);
            this.crossSectionY = min(this.crossSectionY,info.YSz);
            this.cachedImage.info = info;
            this.cachedImage.data = ci;
            ROI.ROICoordinates = ROICoordinates;
            ROI.ROIType = ROIType;
            ROI.ROISubType = ROISubType;
            ROI.ROIInvertFlag = ROIInvertFlag;
            this.cachedImage.ROI = ROI;
            out = ci;
        end
 
        function out = checkClasswidth(this,currentImage)
            %check if current classwidth is within bounds
            %out = false if cw is within bounds, true otherwise
            out = false;
            ci = currentImage(~isnan(currentImage(:)));
            [cw, lim, lb, ub] = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
            if(lim)
                %min/max of centers should be multiples of the bounds
                c_min = ceil((min(ci(:))-lb)/cw)*cw+lb;
                c_min = min(c_min,lb);
                c_max = ceil((max(ci(:))-lb)/cw)*cw+lb;
                c_max = max(c_max,ub);                
            else
                c_min = round((min(ci(:)))/cw)*cw;%min(ci(:));
                c_max = round((max(ci(:)))/cw)*cw;%max(ci(:));                
            end
            %make centers vector
            centers = c_min : cw : c_max;            
            %check over under-/overflows
            if(numel(centers) <= 1)
                out = true;     %set error flag
%                 cw_old = cw;
%                 cw = (c_max-c_min)/100;
%                 warndlg(sprintf('Classwidth (%.1f) of %s %d is too big. Only one class would be computed. Please reduce classwidth to %.1f or less.',...
%                     cw_old,this.dType,this.id,cw),'Error Classwidth');
            end
            if(numel(centers) > this.maxHistClasses)
                out = true;     %set error flag
%                 cw_old = cw;
%                 nc_old = numel(centers);
%                 cw = (c_max-c_min)/5000;                
%                 warndlg(sprintf('Classwidth (%.1f) of %s %d is too small. %d classes would be computed. Please increase classwidth to %.1f or more.',...
%                     cw_old,this.dType,this.id,nc_old,cw),'Error Classwidth');
            end                      
        end
        
        function out = getDefaultXLblTick(this)
            %return tick step size for x
            out = 1;
        end
        
        function out = getDefaultYLblTick(this)
            %return tick step size for y
            out = 1;
        end
    end %methods
    methods (Access = protected)
          
    end%methods(protected)
    methods(Static)
        
    end %methods(static)
end %classdef