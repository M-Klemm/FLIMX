classdef FDisplay < handle
    %=============================================================================================================
    %
    % @file     FDisplay.m
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
    % @brief    A class to paint axes with FLIM data
    %
    properties(GetAccess = public, SetAccess = protected)
        myColorScaleObj = [];
        myhfdMain = {[]};
        myhfdSupp = {[]};
        myhfdInt = {[]};
        mainExportGfx = [];
        mainExportXls = [];
        mainExportColors = [];
        suppExport = [];
        colorStartClass = 0;
        colorEndClass = 0;
        colorClassWidth = 0;
        mySuppXZoomScale = [];
        zoomAnchor = [1; 1];
    end
    properties(GetAccess = protected, SetAccess = protected)
        visObj = [];
        mySide = '';        
        screenshot = false; %flag
        disp_view = [];
        current_img_min = [];
        current_img_max = [];
        current_img_lbl_min = [];
        current_img_lbl_max = [];
        h_Rectangle = [];
        h_Circle = [];
        h_ETDRSGrid = [];
        h_ETDRSGridText = [];
        h_Polygon = [];
        h_ROIArea = [];
        h_cmImage = [];
        pixelResolution = 0;
        measurementPosition = 'OS';
        
        mouseOverlayBoxMain = [];
        mouseOverlayBoxSupp = [];        
    end
    properties (Dependent = true)
        ROICoordinates = [];
        ROIType = [];
        ROISubType = [];
        ROIVicinity = [];
        crossSectionXVal = 0;
        crossSectionYVal = 0;
        crossSectionXInv = 0;
        crossSectionYInv = 0;
        mDispDim = [];
        mDispScale = [];
        mZoomFactor = 1;
        sDispMode = [];
        sDispHistMode = [];
        sDispScale = [];
        intOver = [];
        intOverBright = [];
        %handles to visObj GUI controls
        h_pd = [];
        h_m_ax = [];
        h_s_ax = [];
        h_m_p = [];
        h_m_pvar = [];
        h_m_pdim = [];
        h_m_pch = [];
        h_m_psc = [];
        h_s_p = [];
        h_s_hist = [];
        h_s_psc = [];
        h_ds_t = [];
        h_cm = [];
        h_t1 = [];
        h_t2 = [];
        h_t3 = [];
        h_t4 = [];
        h_t5 = [];
        h_io_check = [];
        h_io_edit = [];
        h_zoom_slider = [];
        h_s_colormapLowEdit = [];
        h_s_colormapHighEdit = [];
        %visualization parameters
        dynVisParams = [];
        staticVisParams = [];
    end
    
    methods
        function this = FDisplay(visObj,side)
            %Constructs a FDisplay object.
            this.visObj = visObj;
            this.mySide = side;
            this.myColorScaleObj = ColorCtrl(visObj,side,this);
            this.disp_view = [-40 30];
            this.mouseOverlayBoxMain = mouseOverlayBox(this.h_m_ax);
            this.mouseOverlayBoxSupp = mouseOverlayBox(this.h_s_ax);
            this.mouseOverlayBoxSupp.setVerticalBoxPositionMode(0);
        end %FDisplay
        
        function setDispView(this,viewVec)
            %set the 3D view, viewVec = [azimuth, elevation] 
            this.disp_view = viewVec;
            %update custom axis labels (e.g. clusters)
            this.makeMainXYLabels(); 
        end
        
        function sethfdMain(this,val)
            %sets FDisplays current FData handle(s)
            if(iscell(val))
                this.myhfdMain = val;
            else
                this.myhfdMain = {val};
            end
            this.setZoomAnchor([]);
            %todo: find the right spot for this
%             this.mouseOverlayBoxMain.setBackgroundColor([this.staticVisParams.plotCoordinateBoxColor(:); this.visualizationParams.plotCoordinateBoxTransparency]); 
            this.mouseOverlayBoxMain.setLineColor([1 1 1]);
            this.mouseOverlayBoxMain.setLineStyle(':');
            this.mouseOverlayBoxMain.setLineWidth(2);
            this.mouseOverlayBoxSupp.setLineColor([0.2 0.2 0.2]);
            this.mouseOverlayBoxSupp.setLineStyle(':');
            this.mouseOverlayBoxSupp.setLineWidth(2);
        end
        
        function sethfdSupp(this,val)
            %sets FDisplays current FData handle(s)
            if(iscell(val))
                this.myhfdSupp = val;
            else
                this.myhfdSupp = {val};
            end
            this.mySuppXZoomScale = [];
        end
        
        function zoomSuppXScale(this,target)
            %set x scaling for supp axes            
            if(~(this.sDispMode == 2 && this.sDispHistMode == 1))
                return
            end            
            hfd = this.myhfdSupp;
            if(isempty(hfd{1}))
                return
            end
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            [~, histCenters] = hfd{1}.getCIHist(rc,rt,rs,ri);
            if(~ischar(target) && isnumeric(target) && length(target) == 2)
                %we've got zoom borders
                lb = target(1);
                ub = target(2);
            else
                %zoom in or out                
                %             cs = this.myColorScaleObj.getCurCSInfo();
                %             if(length(histCenters) > 1)
                %                 classWidth = histCenters(2)-histCenters(1);
                %                 colorStartClass = round((cs(2)-histCenters(1))./classWidth)+1;
                %                 colorEndClass = round((cs(3)-histCenters(1))./classWidth)+1;
                %                 %colorEndClass = round((max(histCenters(end),cs(3))-histCenters(1))./classWidth)+1;
                %             else
                %                 colorStartClass = 1;
                %                 colorEndClass = 1;
                %             end
                curXlim = xlim(this.h_s_ax);
                curHistRange = curXlim(2) - curXlim(1) +1;
                curColorRange = (this.colorEndClass-this.colorStartClass)/2;
                curColorCenter = this.colorStartClass + curColorRange;
                if(strcmpi(target,'in'))
                    range = curHistRange*0.5;
                else
                    range = curHistRange*2;
                end
                lb = round(max(-histCenters(1)./this.colorClassWidth+1,floor(curColorCenter-range/2))); %make sure we don't have negative classes
                ub = round(curColorCenter+range/2); %min(length(histCenters),max(curEndClass,round(curColorCenter+range/2)));            
            end
            histCenters = (lb-1:ub).*this.colorClassWidth + histCenters(1); 
            xlim(this.h_s_ax,[lb ub]);
            this.mySuppXZoomScale = [lb ub];
            xtick = get(this.h_s_ax,'XTick');
            newLabelTicks = xtick-lb+1;
            newLabelTicks(newLabelTicks <= 0 | newLabelTicks > length(histCenters)) = [];
            set(this.h_s_ax,'XTickLabel',FLIMXFitGUI.num4disp(histCenters(newLabelTicks)'));
        end
        
        function out = getDispView(this)
            %get current display view
            out = this.disp_view;
        end
        
        function cp = getMyCP(this,axesFlag)
            %get the current point of my main (axesFlag = 1) axes or supplemental axes (axesFlag = 2)
            switch axesFlag
                case 1
                    hAx = this.h_m_ax;
                case 2
                    hAx = this.h_s_ax;
                otherwise
                    cp = [];
                    return;
            end
            cp = get(hAx,'CurrentPoint');
            cp = round(cp(logical([1 1 0; 0 0 0])));
            if(any(cp(:) <= 0))
                %we are outside axes - nothing to do
                cp = [];
                return;
            end
            if(cp(1) < hAx.XLim(1) || cp(1) > hAx.XLim(2) || cp(2) < hAx.YLim(1) || cp(2) > hAx.YLim(2))
                cp = [];
            end
        end
        
        function drawCPMain(this,cp)
            %draw current point into 2D plots of main axes
            %if isMultipleCall();  return;  end
            hfd = this.gethfd();
            dim = this.mDispDim;
            if(isempty(hfd{1}) || length(hfd) > 1 || dim > 2)
                this.mouseOverlayBoxMain.clear();
                return
            end
            hfd = hfd{1};
            cp = round(cp);
            if(dim == 1)
                ci = hfd.getFullImage();
            else
                rc = this.ROICoordinates;
                rt = this.ROIType;
                rs = this.ROISubType;
                ri = this.ROIVicinity;
                ci = hfd.getROIImage(rc,rt,rs,ri);
            end
            if(isempty(cp) || isempty(ci))
                this.mouseOverlayBoxMain.clear();
            else
                [y, x] = size(ci);
                cp(1) = min(cp(1),x);
                cp(2) = min(cp(2),y);
                if(dim == 1)
                    xLbl = hfd.getRIXLbl();
                    yLbl = hfd.getRIYLbl();
                else
                    xLbl = hfd.getCIXLbl(rc,rt,rs,ri);
                    yLbl = hfd.getCIYLbl(rc,rt,rs,ri);
                end
                this.mouseOverlayBoxMain.draw(cp,[{sprintf('x:%d y:%d',xLbl(cp(1)),yLbl(cp(2)))},FLIMXFitGUI.num4disp(ci(cp(2),cp(1)))]);
                this.mouseOverlayBoxMain.displayBoxOnTop();
            end
        end
        
        function drawCPSupp(this,cp)
            %draw current point into support axes
            sdm = this.sDispMode;
            if(isempty(this.suppExport) || isempty(cp) || size(this.suppExport,1) < cp(1) || sdm == 1)
                this.mouseOverlayBoxSupp.clear();
                return
            end
            if(sdm == 2 && size(this.suppExport,2) == 2)
                %histogram
                str = FLIMXFitGUI.num4disp(this.suppExport(cp(1),:));
                this.mouseOverlayBoxSupp.draw(cp,sprintf('%s: %s',str{1},str{2}),this.suppExport(cp(1),2));
            else
                %cross-section 
                str = FLIMXFitGUI.num4disp(this.suppExport(cp(1),1));
                this.mouseOverlayBoxSupp.draw(cp,sprintf('%d: %s',cp(1),str{1}),this.suppExport(cp(1),1));
            end
        end
        
        function drawROI(this,ROIType,op,cp,drawTextFlag)
            %draw ROI on 2D main plot; cp: current point; op: old point
            if(isempty(op) && isempty(cp))
                %delete old ROIs
                ROIType = 0;
            end
            if(~any([op(:); cp(:)]))
                %empty ROI
                return
            end
            op = double(op);
            cp = double(cp);
            [~, ROIMinor] = ROICtrl.decodeROIType(ROIType);
            if(ROIType > 0 && length(this.h_ROIArea) >= ROIType)
                try
                    delete(this.h_ROIArea(ROIType));
                end
                this.h_ROIArea(ROIType) = [];
            end
            if(this.staticVisParams.ROI_fill_enable && (this.ROIVicinity ~= 1 || ROIType > 1000 && ROIType < 2000 && this.ROIVicinity == 1))
                %draw ETDRS grid segments or inverted / vicinity ROI areas
                gc = this.staticVisParams.ROIColor;
                fileInfo.pixelResolution = this.pixelResolution;
                fileInfo.position = this.measurementPosition;
                mask = zeros(size(this.mainExportXls),'single');
                [~,idx] = FData.getImgSeg(zeros(size(this.mainExportXls)),[op cp],ROIType,this.ROISubType,this.ROIVicinity,fileInfo,this.visObj.fdt.getVicinityInfo());
                if(~isempty(idx))
                    mask(idx) = 1;
                    mask = repmat(mask,1,1,4);
                    mask(:,:,1) = mask(:,:,1) .* gc(1);
                    mask(:,:,2) = mask(:,:,2) .* gc(2);
                    mask(:,:,3) = mask(:,:,3) .* gc(3);
                    mask(:,:,4) = mask(:,:,4) .* this.staticVisParams.ETDRS_subfield_bg_color(end);
                    hold(this.h_m_ax,'on');
                    this.h_ROIArea(ROIType) = image(this.h_m_ax,mask(:,:,1:3),'AlphaData',mask(:,:,4));
                    hold(this.h_m_ax,'off');
                end
            end
            %draw ROI lines
            if(ROIType > 1000 && ROIType < 2000)
                this.drawETDRSGrid(cp,drawTextFlag,ROIMinor);
            elseif(ROIType > 2000 && ROIType < 3000)
                if(isempty(op))
                    return
                end
                this.drawRectangle(cp,op-cp,drawTextFlag,ROIMinor);
            elseif(ROIType > 3000 && ROIType < 4000)
                if(isempty(op))
                    return
                end
                radius = sqrt(sum((op-cp).^2));
                this.drawCircle(op,radius,drawTextFlag,ROIMinor);
            elseif(ROIType > 4000 && ROIType < 5000)
                this.drawPolygon([op,cp],drawTextFlag,ROIMinor);
            else
                try
                    delete(this.h_Rectangle);
                    this.h_Rectangle = [];
                end
                try
                    delete(this.h_Circle);
                    this.h_Circle = [];
                end
                try
                    delete(this.h_ETDRSGrid);
                    this.h_ETDRSGrid = [];
                end
                try
                    delete(this.h_ETDRSGridText);
                    this.h_ETDRSGridText = [];
                end
                try
                    delete(this.h_Polygon);
                    this.h_Polygon = [];
                end
            end
        end
        
        function drawRectangle(this,cp,widths,drawTextFlag,ROINumber)
            %draw rectangle into 2D plot
            if(isempty(widths) || ~any(widths(:)))
                return
            end
            gc = this.staticVisParams.ROIColor;
            lw = this.staticVisParams.ROILinewidth;
            ls = this.staticVisParams.ROILinestyle;
            idx = widths < 0;
            cp(idx) = cp(idx) + widths(idx);
            widths = abs(widths);
            if(length(this.h_Rectangle) >= ROINumber)
                isHG = ishghandle(this.h_Rectangle(ROINumber)) & this.h_Rectangle(ROINumber) > 0;
            else
                isHG = false;
            end
            if(~isempty(isHG) && isHG)
                set(this.h_Rectangle(ROINumber),'Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw,'LineStyle',ls);
            else
%                 try
%                     delete(this.h_Rectangle(ROINumber));
%                 end
                if(this.staticVisParams.ROI_fill_enable && this.ROIVicinity == 1)
                    fc = [gc this.staticVisParams.ETDRS_subfield_bg_color(end)];
                    this.h_Rectangle(ROINumber) = rectangle('Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc,'FaceColor',fc);
                else
                    this.h_Rectangle(ROINumber) = rectangle('Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc);
                end
            end
        end
        
        function drawCircle(this,cp,radius,drawTextFlag,ROINumber)
            %draw rectangle into 2D plot
            if(isempty(radius) || ~any(radius(:)))
                return
            end
            gc = this.staticVisParams.ROIColor;
            lw = this.staticVisParams.ROILinewidth;
            ls = this.staticVisParams.ROILinestyle;
            if(length(this.h_Circle) >= ROINumber)
                isHG = ishghandle(this.h_Circle(ROINumber)) & this.h_Circle(ROINumber) > 0;
            else
                isHG = false;
            end            
            if(~isempty(isHG) && isHG)
                set(this.h_Circle(ROINumber),'Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'LineWidth',lw,'LineStyle',ls);
            else
%                 try
%                     delete(this.h_Circle(ROINumber));
%                 end
                if(this.staticVisParams.ROI_fill_enable  && this.ROIVicinity == 1)
                    fc = [gc this.staticVisParams.ETDRS_subfield_bg_color(end)];
                    this.h_Circle(ROINumber) = rectangle('Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'Curvature',[1 1],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc,'FaceColor',fc);
                else
                    this.h_Circle(ROINumber) = rectangle('Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'Curvature',[1 1],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc);
                end
            end
        end
        
        function drawPolygon(this,points,drawTextFlag,ROINumber)
            %draw polygon into 2D plot
            gc = this.staticVisParams.ROIColor;
            lw = this.staticVisParams.ROILinewidth;
            ls = this.staticVisParams.ROILinestyle;
            if(length(this.h_Polygon) >= ROINumber)
                isHG = ishghandle(this.h_Polygon(ROINumber)) & this.h_Polygon(ROINumber) > 0;
            else
                isHG = false;
            end            
            if(~isempty(isHG) && isHG)
                set(this.h_Polygon(ROINumber),'Faces',1:size(points,2),'Vertices',flipud(points)','LineWidth',lw,'LineStyle',ls);
            else
%                 try
%                     delete(this.h_Polygon(ROINumber));
%                 end
                if(this.staticVisParams.ROI_fill_enable && this.ROIVicinity == 1)
                    this.h_Polygon(ROINumber) = patch('Faces',1:size(points,2),'Vertices',flipud(points)','LineWidth',lw,'LineStyle',ls,'EdgeColor',gc,'FaceColor',gc,'FaceAlpha',this.staticVisParams.ETDRS_subfield_bg_color(end),'Parent',this.h_m_ax);
                else
                    this.h_Polygon(ROINumber) = patch('Faces',1:size(points,2),'Vertices',flipud(points)','LineWidth',lw,'LineStyle',ls,'EdgeColor',gc,'FaceAlpha',0,'Parent',this.h_m_ax);
                end
            end
        end
        
        function drawETDRSGrid(this,cp,drawTextFlag,ROINumber)
            %draw ETDRS grid into 2D plot
            if isMultipleCall();  return;  end
            if(size(this.h_ETDRSGrid,2) >= ROINumber)
                idxG = ishghandle(this.h_ETDRSGrid(:,ROINumber)) & this.h_ETDRSGrid > 0;
            else
                idxG = [];
            end
            if(size(this.h_ETDRSGridText,2) >= ROINumber)
                idxT = ishghandle(this.h_ETDRSGridText(:,ROINumber)) & this.h_ETDRSGridText > 0;
            else
                idxT = [];
            end
            if(isempty(cp) || ~any(cp(:)))
                delete(this.h_ETDRSGrid(idxG,ROINumber));
                delete(this.h_ETDRSGridText(idxT,ROINumber));
                return
            end
            res = this.pixelResolution;
            gc = this.staticVisParams.ROIColor;
            if(res > 0)
                %radius ring1 = 500 µm
                d1 = 1000/res;
                d2 = 3000/res;
                d3 = 6000/res;
                lw = this.staticVisParams.ROILinewidth;
                ls = this.staticVisParams.ROILinestyle;
                fs = this.staticVisParams.fontsize;
                if(~isempty(idxG) && all(idxG(:)) && size(this.h_ETDRSGrid,2) >= ROINumber)% && ~this.staticVisParams.ROI_fill_enable)
                    %circles
                    set(this.h_ETDRSGrid(1,ROINumber),'Position',[cp(2)-d1/2,cp(1)-d1/2,d1,d1],'LineWidth',lw,'LineStyle',ls);
                    set(this.h_ETDRSGrid(2,ROINumber),'Position',[cp(2)-d2/2,cp(1)-d2/2,d2,d2],'LineWidth',lw,'LineStyle',ls);
                    set(this.h_ETDRSGrid(3,ROINumber),'Position',[cp(2)-d3/2,cp(1)-d3/2,d3,d3],'LineWidth',lw,'LineStyle',ls);
                    %lines
                    set(this.h_ETDRSGrid(4,ROINumber),'XData',[cp(2)+cos(pi/4)*d1/2  cp(2)+cos(pi/4)*d3/2],'YData',[cp(1)+sin(pi/4)*d1/2 cp(1)+sin(pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls);
                    set(this.h_ETDRSGrid(5,ROINumber),'XData',[cp(2)+cos(3*pi/4)*d1/2  cp(2)+cos(3*pi/4)*d3/2],'YData',[cp(1)+sin(3*pi/4)*d1/2 cp(1)+sin(3*pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls);
                    set(this.h_ETDRSGrid(6,ROINumber),'XData',[cp(2)+cos(-pi/4)*d1/2  cp(2)+cos(-pi/4)*d3/2],'YData',[cp(1)+sin(-pi/4)*d1/2 cp(1)+sin(-pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls);
                    set(this.h_ETDRSGrid(7,ROINumber),'XData',[cp(2)+cos(-3*pi/4)*d1/2  cp(2)+cos(-3*pi/4)*d3/2],'YData',[cp(1)+sin(-3*pi/4)*d1/2 cp(1)+sin(-3*pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls);
                else
%                     try
%                         delete(this.h_ETDRSGrid(idxG,ROINumber));
%                     end
                    h = zeros(7,1);
                    h(1) = rectangle('Position',[cp(2)-d1/2,cp(1)-d1/2,d1,d1],'Curvature',[1 1],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc);
                    h(2) = rectangle('Position',[cp(2)-d2/2,cp(1)-d2/2,d2,d2],'Curvature',[1 1],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc);
                    h(3) = rectangle('Position',[cp(2)-d3/2,cp(1)-d3/2,d3,d3],'Curvature',[1 1],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'EdgeColor',gc);
                    %lines
                    h(4) = line('XData',[cp(2)+cos(pi/4)*d1/2  cp(2)+cos(pi/4)*d3/2],'YData',[cp(1)+sin(pi/4)*d1/2 cp(1)+sin(pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'Color',gc);
                    h(5) = line('XData',[cp(2)+cos(3*pi/4)*d1/2  cp(2)+cos(3*pi/4)*d3/2],'YData',[cp(1)+sin(3*pi/4)*d1/2 cp(1)+sin(3*pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'Color',gc);
                    h(6) = line('XData',[cp(2)+cos(-pi/4)*d1/2  cp(2)+cos(-pi/4)*d3/2],'YData',[cp(1)+sin(-pi/4)*d1/2 cp(1)+sin(-pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'Color',gc);
                    h(7) = line('XData',[cp(2)+cos(-3*pi/4)*d1/2  cp(2)+cos(-3*pi/4)*d3/2],'YData',[cp(1)+sin(-3*pi/4)*d1/2 cp(1)+sin(-3*pi/4)*d3/2],'LineWidth',lw,'LineStyle',ls,'Parent',this.h_m_ax,'Color',gc);
                    this.h_ETDRSGrid(:,ROINumber) = h;
                end
                %text in subfields
                if(~drawTextFlag)
                    delete(this.h_ETDRSGridText(idxT,ROINumber));
                    return
                end
                hfd = this.gethfd();
                if(isempty(hfd{1}))
                    return
                end
                hfd = hfd{1};
                txt = repmat({''},9,1);
                bgc = [0 0 0 0];
                if(~strcmp(this.staticVisParams.ETDRS_subfield_values,'none'))
                    if(strcmp(this.staticVisParams.ETDRS_subfield_values,'field name'))
                        txt = {'C','IS','IN','II','IT','OS','ON','OI','OT'}';
                    else
                        tmp = hfd.getROISubfieldStatistics(cp,1,this.staticVisParams.ETDRS_subfield_values);
                        txt = FLIMXFitGUI.num4disp(tmp);
                    end
                    if(this.staticVisParams.ETDRS_subfield_bg_enable)
                        bgc = this.staticVisParams.ETDRS_subfield_bg_color;%[0.3 0.3 0.3 0.33];
                    end
                end
                if(strcmp(this.measurementPosition,'OD'))
                    txt = txt([1,2,5,4,3,6,9,8,7],1); %re-order nasal and temporal fields
                end
                if(~isempty(idxT) && all(idxT(:)) && size(this.h_ETDRSGrid,2) >= ROINumber)
                    set(this.h_ETDRSGridText(1,ROINumber),'Position',[cp(2),cp(1)],'String',txt{1});
                    set(this.h_ETDRSGridText(2,ROINumber),'Position',[cp(2),cp(1)+d1/2+(d2-d1)/4,cp(1)],'String',txt{2});
                    set(this.h_ETDRSGridText(3,ROINumber),'Position',[cp(2)-(d1/2+(d2-d1)/4),cp(1)],'String',txt{3});
                    set(this.h_ETDRSGridText(4,ROINumber),'Position',[cp(2),cp(1)-d1/2-(d2-d1)/4,cp(1)],'String',txt{4});
                    set(this.h_ETDRSGridText(5,ROINumber),'Position',[cp(2)+(d1/2+(d2-d1)/4),cp(1)],'String',txt{5});
                    set(this.h_ETDRSGridText(6,ROINumber),'Position',[cp(2),cp(1)+d2/2+(d3-d2)/4,cp(1)],'String',txt{6});
                    set(this.h_ETDRSGridText(9,ROINumber),'Position',[cp(2)-(d2/2+(d3-d2)/4),cp(1)],'String',txt{7});
                    set(this.h_ETDRSGridText(7,ROINumber),'Position',[cp(2),cp(1)-d2/2-(d3-d2)/4,cp(1)],'String',txt{8});
                    set(this.h_ETDRSGridText(8,ROINumber),'Position',[cp(2)+(d2/2+(d3-d2)/4),cp(1)],'String',txt{9});
                else
%                     delete(this.h_ETDRSGridText(idxT,ROINumber));
                    h = zeros(9,1);
                    h(1) = text(cp(2),cp(1),txt{1},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(2) = text(cp(2),cp(1)+d1/2+(d2-d1)/4,txt{2},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(3) = text(cp(2)-(d1/2+(d2-d1)/4),cp(1),txt{3},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(4) = text(cp(2),cp(1)-d1/2-(d2-d1)/4,txt{4},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(5) = text(cp(2)+(d1/2+(d2-d1)/4),cp(1),txt{5},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(6) = text(cp(2),cp(1)+d2/2+(d3-d2)/4,txt{6},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(7) = text(cp(2)-(d2/2+(d3-d2)/4),cp(1),txt{7},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(8) = text(cp(2),cp(1)-d2/2-(d3-d2)/4,txt{8},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(9) = text(cp(2)+(d2/2+(d3-d2)/4),cp(1),txt{9},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    this.h_ETDRSGridText(:,ROINumber) = h;
                end
            end
        end
        function hfdInt = getIntHfd(this)
            %get handle to intensity image
            hfdInt = this.visObj.fdt.getFDataObj(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),this.visObj.getChannel(this.mySide),'Intensity',0,1);
        end
        function [hfd, hfdSupp] = gethfd(this)
            %get handle(s) to current FData object(s)
%             hfd = this.myhfdMain;           
%             hfdInt = this.myhfdInt;
%             hfdSupp = this.myhfdSupp;
%             if(~isempty(hfd{1}) && ~isempty(hfdInt) && ~isempty(hfdSupp{1}))            
%                 return
%             end            
            %no old FData handle, read GUI settings and get new one
            scale = get(this.h_m_psc,'Value');
            %get 'variation mode': 1:uni 2: multi 3: cluster
            varMode = get(this.h_m_pvar,'Value');            
            [dType, dTypeNr] = this.visObj.getFLIMItem(this.mySide);
            hfd = cell(length(dTypeNr),1);
            switch varMode
                case {1,2} %univariate or multivariate mode
                    for i = 1:length(dTypeNr)
                        hfd{i} = this.visObj.fdt.getFDataObj(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),this.visObj.getChannel(this.mySide),dType{i},dTypeNr(i),scale);
                    end
                case 3  %view clusters
                    %get merged view cluster object
                    clusterID = sprintf('Condition%s',dType{1});
                    hfd{1} = this.visObj.fdt.getStudyObjMerged(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide),this.visObj.getChannel(this.mySide),clusterID,dTypeNr(1),scale,this.ROIType,this.ROISubType,this.ROIVicinity);
                case 4 %global clusters
                    clusterID = sprintf('Global%s',dType{1});
                    hfd{1} = this.visObj.fdt.getGlobalMVGroupObj(this.visObj.getChannel(this.mySide),clusterID,scale);
            end            
            %save new hfd(s)            
%             this.myhfdMain = hfd;
%             this.myhfdInt = hfdInt;
            if(this.sDispMode == 2)
                %histogram
                switch get(this.h_s_hist,'Value')
                    case 1 %single histogram
                        this.sethfdSupp(hfd);
                        hfdSupp = hfd;
                    case 2 %study view histogram
                        if(~(dTypeNr == 0))
                            this.sethfdSupp(this.visObj.fdt.getStudyObjMerged(this.visObj.getStudy(this.mySide),...
                                this.visObj.getCondition(this.mySide),this.visObj.getChannel(this.mySide),dType{1},dTypeNr,1,this.ROIType,this.ROISubType,this.ROIVicinity));
                            hfdSupp = {this.visObj.fdt.getStudyObjMerged(this.visObj.getStudy(this.mySide),...
                                this.visObj.getCondition(this.mySide),this.visObj.getChannel(this.mySide),dType{1},dTypeNr,1,this.ROIType,this.ROISubType,this.ROIVicinity)};
                        else
                            this.sethfdSupp({[]});
                            hfdSupp = [];
                        end
%                     case 3 %global histogram
%                         if(~isnan(dTypeNr))
%                             this.sethfdSupp(this.visObj.fdt.getGlobalObjMerged(this.visObj.getChannel(this.mySide),dType{1},dTypeNr,this.ROIType,this.ROISubType,this.ROIVicinity));
%                         else
%                             this.sethfdSupp(hfd);
%                         end
                end
            else
                %crossSections                    
                this.sethfdSupp(hfd);
                hfdSupp = hfd;
            end
            if(~isempty(hfd{1}))
                fi = hfd{1}.getFileInfoStruct();
                if(~isempty(fi))
                    this.pixelResolution = fi.pixelResolution;
                    this.measurementPosition = fi.position;
                end
            end
        end        
        
        function updatePlots(this)
            %update main and crossSections axes
            if(isMultipleCall())
                return
            end
            %tic;                                    
            this.UpdateMinMaxLbl();
            this.myColorScaleObj.updateGUI([]);
            this.clearROIs();
            this.makeMainPlot();            
            this.makeSuppPlot();
            this.makeZoom(); 
            %this.makeMainXYLabels();
            this.makeDSTable();
            this.updateColorBarLbls();
            %toc
        end %updateGUI
        
        function UpdateMinMaxLbl(this)
            %get min & max for current image and its labels
            hfd = this.gethfd();
            if(isempty(hfd{1}) || this.mDispDim == 1)
                return
            end
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            this.current_img_min = single(hfd{1}.getCImin(rc,rt,rs,ri));
            if(isnan(this.current_img_min))
                this.current_img_min = 0;
            end
            this.current_img_max = single(hfd{1}.getCImax(rc,rt,rs,ri));
            if(isnan(this.current_img_max))
                this.current_img_max = this.current_img_min+eps(this.current_img_min);
            end  
            this.current_img_lbl_min = single(hfd{1}.getCIminLbl(rc,rt,rs,ri));
            if(isnan(this.current_img_lbl_min))
                this.current_img_lbl_min = 0;
            end            
            this.current_img_lbl_max = max(single(hfd{1}.getCImaxLbl(rc,rt,rs,ri)),this.current_img_lbl_min+1);
            if(length(hfd) > 1)
                for i = 2:length(hfd)
                    this.current_img_min = min(this.current_img_min,single(hfd{i}.getCImin(rc,rt,rs,ri)));
                    this.current_img_max = max(this.current_img_max,single(hfd{i}.getCImax(rc,rt,rs,ri)));
                    this.current_img_lbl_min = min(this.current_img_lbl_min,single(hfd{i}.getCIminLbl(rc,rt,rs,ri)));
                    this.current_img_lbl_max = max(this.current_img_lbl_max,single(hfd{i}.getCImaxLbl(rc,rt,rs,ri)));
                end
            end
        end
        
        function clearROIs(this)
            %delete ROI handles
            isHG = ishghandle(this.h_ROIArea) & this.h_ROIArea > 0;
            delete(this.h_ROIArea(isHG));
            this.h_ROIArea = [];
            isHG = ishghandle(this.h_ETDRSGrid) & this.h_ETDRSGrid > 0;
            delete(this.h_ETDRSGrid(isHG));
            this.h_ETDRSGrid = [];
            isHG = ishghandle(this.h_ETDRSGridText) & this.h_ETDRSGridText > 0;            
            delete(this.h_ETDRSGridText(isHG));
            this.h_ETDRSGridText = [];
            isHG = ishghandle(this.h_Rectangle) & this.h_Rectangle > 0;
            delete(this.h_Rectangle(isHG));
            this.h_Rectangle = [];
            isHG = ishghandle(this.h_Circle) & this.h_Circle > 0;
            delete(this.h_Circle(isHG));
            this.h_Circle = [];
            isHG = ishghandle(this.h_Polygon) & this.h_Polygon > 0;
            delete(this.h_Polygon(isHG));
            this.h_Polygon = [];
        end
        
        function makeMainPlot(this)
            %make current main plot
            hfd = this.gethfd();
            hAx = this.h_m_ax;
            cla(hAx);
            axis(hAx,'off');
            if(isempty(hfd{1}))
                return
            end
            dispDim = this.mDispDim;
            sVisParam = this.staticVisParams;
%             if(~this.screenshot)
%                 set(hAx,'Fontsize',sVisParam.fontsize);
%             end
            nrFD = length(hfd);            
            ztick = [];
            zticklbl = {};
            offset = 0;
            max_amp = 0;
%             zMin = zeros(1,nrFD);
%             zMax = ones(1,nrFD);
            this.mainExportXls = [];
            this.mainExportGfx = []; 
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            for i = 1:nrFD
                %get image data to display
                if(dispDim == 1)
                    %TOP view
                    current_img = hfd{i}.getFullImage();
                else
                    %ROI in 2D / 3D
%                     if(rt < 0)
%                         %ROI group
%                         current_img = hfd{i}.getROIImage(rc,0,rs,ri);
%                         allGrps = this.visObj.fdt.getResultROIGroup(this.visObj.getStudy(this.mySide),[]);
%                         if(abs(rt) <= size(allGrps,1))
%                             grt = allGrps{abs(rt),2}; %list of roi types in this group
%                             idx = [];
%                             for j = 1:length(grt)
%                                 %draw all rois of the group
%                                 ROICoord = hfd{i}.getROICoordinates(grt(j));
%                                 [~,idxTmp] = hfd{i}.getROIImage(ROICoord,grt(j),rs,ri);
%                                 idx = unique([idxTmp;idx]);
%                             end
%                             ci = NaN(size(current_img));
%                             ci(idx) = current_img(idx);
%                             current_img = FData.removeNaNBoundingBox(ci);
%                         end
%                     else
                        current_img = hfd{i}.getROIImage(rc,rt,rs,ri);
%                     end
                end
                if(isempty(current_img) || all(isnan(current_img(:))) || all(isinf(current_img(:))))
                    return
                end
                if(hfd{i}.rawImgIsLogical)
                    %logical data, e.g. a mask
                    current_img(isnan(current_img)) = 0;
                    current_img = logical(current_img);
                    zMin = 0;
                    zMax = 1;
                    colors = single(repmat(current_img,[1 1 3]));
                    alphaData = ones(size(colors,1),1);
                else
                    %z scaling
                    zData = hfd{i}.getZScaling();
                    if(~isempty(zData) && zData(1))
                        zMin(i) = zData(2);
                        if(isinf(zMin))
                            zMin(i) = hfd{i}.getCImin();
                        end
                        zMax(i) = zData(3);
                        if(dispDim == 1)
                            %do z scaling here
                            current_img(current_img < zMin(i)) = NaN;%zMin(i);
                            current_img(current_img > zMax(i)) = NaN;%zMax(i);
                        end
                    else
                        if(dispDim == 1)
                            zMax(i) = FData.getNonInfMinMax(2,current_img);
                            zMin(i) = FData.getNonInfMinMax(1,current_img);
                        else
                            zMax(i) = single(hfd{i}.getCImax(rc,rt,rs,ri));
                            zMin(i) = single(hfd{i}.getCImin(rc,rt,rs,ri));
                        end
                    end
                    if((zMax - zMin) < 0.1)
                        zMax = zMax + 0.1;
                    end
                    %color mapping
                    if(isempty(hfd{i}.getCIColor(rc,rt,rs,ri))) %dispDim == 1 || 
                        %cTmp = hfd{i}.getColorScaling();
                        cTmp = single(this.myColorScaleObj.getCurCSInfo());
                        if(isempty(cTmp) || length(cTmp) ~= 3 || nrFD > 1)
                            %auto color scaling
                            cMin = zMin(i);
                            cMax = zMax(i);
                        else
                            cMin = cTmp(2);
                            cMax = cTmp(3);
                        end
                        
                        if(strcmp(hfd{i}.dType,'Intensity'))
                            cm = this.dynVisParams.cmIntensity;
                        else
                            cm = this.dynVisParams.cm;
                        end
                        if(strcmp(this.dynVisParams.cmType,'SpectrumFixed') && ~strcmp(hfd{i}.dType,'Intensity'))
                            colors = current_img-379; %map pixel values directly to the color map starting at 380 nm
                        else
                            colors = current_img - cMin;
                            colors(isinf(colors)) = NaN;
                            colors = colors/(cMax-cMin)*(size(cm,1)-1)+1; %mapping for colorbar
                        end                        
                        colors(isnan(colors)) = 1;
                        colors = max(colors,1);
                        colors = min(colors,size(cm,1));
                        if(strncmp(hfd{i}.dType,'MVGroup',7)  || strncmp(hfd{i}.dType,'ConditionMVGroup',16))
                            cm = FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,max(current_img(:)));
%                             originalrgb = this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)); %replace by whatever rgb colour you want
%                             originalhsv = rgb2hsv(originalrgb);  %get the HSV values of your original colour. We really only care about the hue
%                             ciL10 = 1+double(log10(max(current_img(:))));
%                             logCM = log10(linspace(1,10^ciL10,256))'/ciL10;
%                             maphsv = rgb2hsv(repmat(logCM,1,3)); %rgb2hsv(gray(256));  convert to hsv
%                             maphsv(:, 1) = originalhsv(1);  %replace gray hue by original hue
%                             maphsv(:, 2) = originalhsv(2); %replace saturation. Anything but 0 will work
%                             cm = hsv2rgb(maphsv);
                            cMin = zMin(i);
                            cMax = zMax(i);
                            colors = current_img - cMin;
                            colors(isinf(colors)) = NaN;
                            colors = colors/(cMax-cMin)*(size(cm,1)-1)+1;
                            colors(isnan(colors)) = 1;
                            colors = max(colors,1);
                            colors = min(colors,size(cm,1));
                            %get colors from map
                            colors = cm(round(reshape(colors,[],1)),:);
                            alphaData = ones(size(colors,1),1);
                            colors = reshape(colors,[size(current_img) 3]);
                            alphaData = reshape(alphaData,size(current_img));
                            %set NaN to black
                            colors(repmat(isnan(current_img),[1 1 3])) = 0;
                            colors(repmat(isinf(current_img),[1 1 3])) = 0;
%                             cm = repmat([0:1/(size(cm,1)-1):1]',1,3);
%                             conditionColor = this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide));
%                             cm = [cm(:,1).*conditionColor(1) cm(:,2).*conditionColor(2) cm(:,3).*conditionColor(3)];
%                             colors = cm(round(reshape(colors,[],1)),:);
%                             alphaData = ceil(sum(colors,2));
%                             colors = reshape(colors,[size(current_img) 3]);
%                             alphaData = reshape(alphaData,size(current_img));
                        elseif(strncmp(hfd{i}.dType,'GlobalMVGroup',13))
                            %get colors for global merged clusters
                            colors = hfd{i}.getCIColor([],0,1,0);
                            alphaData = ceil(sum(colors,3));
                        else
                            %get colors from map
                            colors = cm(round(reshape(colors,[],1)),:);
                            alphaData = ones(size(colors,1),1);
                            colors = reshape(colors,[size(current_img) 3]);
                            alphaData = reshape(alphaData,size(current_img));
                            %set NaN to black
                            colors(repmat(isnan(current_img),[1 1 3])) = 0;
                            colors(repmat(isinf(current_img),[1 1 3])) = 0;
                        end
                    else
                        %we have precomputed colors
                        colors = hfd{i}.getCIColor(rc,rt,rs,ri);
                        alphaData = ceil(sum(colors,3));
                    end
                end
                %intensity overlay
                if(this.intOver)
                    %merge with intensity image
                    hfdInt = this.getIntHfd();
                    if(dispDim == 1)                        
                        colors = this.makeIntOverlay(colors,hfdInt.getFullImage());
                    else
                        colors = this.makeIntOverlay(colors,hfdInt.getROIImage(rc,rt,rs,ri));
                    end
                end
                %save image for possible export
                if(nrFD == 1)
                    this.mainExportXls = current_img;
                    this.mainExportColors = colors;
                end
                if(this.visObj.generalParams.reverseYDir)
                    ydir = 'reverse';
                else
                    ydir = 'normal';
                end
                set(hAx,'YDir',ydir);
                switch dispDim                      
                    case {1,2} %2D plot
                        %plot the image
                        image(colors,'Parent',hAx);
                        zMin(isnan(zMin)) = 0;
                        zMax(isnan(zMax)) = zMin(isnan(zMax))+1;
                        caxis(hAx,[zMin(end) zMax(end)]);
                        set(hAx,'YDir',ydir,'XLim',[1 max(size(current_img,2),1.1)],'YLim',[1 max(size(current_img,1),1.1)]);
                        %draw crossSections
%                         %MVGroup hack
%                         if(strcmp(this.mySide,'r') && strcmp(this.visObj.getStudy('l'),this.visObj.getStudy('r')) && strcmp(this.visObj.getSubject('l'),this.visObj.getSubject('r')) && int8(this.visObj.getChannel('l')) == int8(this.visObj.getChannel('r')))
%                             %study, subject and channel are identical for both sides of FLIMXVisGUI
%                             mvg_hfd = this.visObj.objHandles.ldo.myhfdMain{1};
%                             sd = mvg_hfd.getSupplementalData();
%                             if(~isempty(sd))
%                                 gc = [1 0 0];
%                                 rcL = double(this.visObj.getROICoordinates('l'));
%                                 rtL = this.visObj.getROIType('l');
%                                 rsL = this.visObj.getROISubType('l');
%                                 riL = this.visObj.getROIVicinity('l');
%                                 fileInfo.pixelResolution = this.pixelResolution;
%                                 fileInfo.position = this.measurementPosition;
%                                 %mvg_img = mvg_hfd.getFullImage();
%                                 %get mvgroup roi and determine which pixels are not zero / NaN
%                                 [mvg_roi,roi_idx] = FData.getImgSeg(mvg_hfd.getFullImage(),rcL,rtL,rsL,riL,fileInfo,this.visObj.fdt.getVicinityInfo());
%                                 mvg_roi = mvg_roi(~isnan(mvg_roi));
%                                 if(~isempty(roi_idx) && length(mvg_roi) == length(roi_idx))
%                                     roi_idx(~mvg_roi) = [];
%                                     [row,col] = ind2sub([mvg_hfd.rawImgYSz(2),mvg_hfd.rawImgXSz(2)],roi_idx);
%                                     mvg_overlay = zeros([hfd{i}.rawImgYSz(2),hfd{i}.rawImgXSz(2)]);
%                                     for mi = 1:length(roi_idx)
%                                         idx = sd(:,1) == col(mi) & sd(:,2) == row(mi);
%                                         if(~isempty(idx))
%                                             %should not happen to be empty
%                                             mvg_overlay(idx) = 1;
%                                         end
%                                         %                                 mvg_hfd.yLbl2Pos(row);
%                                         %                                 mvg_hfd.xLbl2Pos(col);
%                                         %sd(sub2ind([hfd{i}.rawImgYSz(2),hfd{i}.rawImgXSz(2)],row(mi),col(mi)),:)
%                                     end
%                                     mvg_overlay = repmat(mvg_overlay,1,1,4);
%                                     mvg_overlay(:,:,1) = mvg_overlay(:,:,1) .* gc(1);
%                                     mvg_overlay(:,:,2) = mvg_overlay(:,:,2) .* gc(2);
%                                     mvg_overlay(:,:,3) = mvg_overlay(:,:,3) .* gc(3);
%                                     mvg_overlay(:,:,4) = mvg_overlay(:,:,4) .* this.staticVisParams.ETDRS_subfield_bg_color(end);
%                                     hold(hAx,'on');
%                                     hOL = image(hAx,mvg_overlay(:,:,1:3),'AlphaData',mvg_overlay(:,:,4));
%                                     hold(hAx,'off');
%                                 end
%                             end
                            %get ROI info from the left side
%                             rcL = double(this.visObj.getROICoordinates('l'));
%                             rtL = this.visObj.getROIType('l');
%                             rsL = this.visObj.getROISubType('l');
%                             riL = this.visObj.getROIVicinity('l');%                             
%                             %mvg_img = this.visObj.objHandles.ldo.myhfdMain{1}.getROIImage(rcL,rtL,rsL,riL);
%                             gc = [1 0 0];
%                             fileInfo.pixelResolution = this.pixelResolution;
%                             fileInfo.position = this.measurementPosition;                            
%                             mvg_hfd = this.visObj.objHandles.ldo.myhfdMain{1};
%                             mvg_targets = this.visObj.fdt.getStudyMVGroupTargets(this.visObj.getStudy('l'),mvg_hfd.dType);
%                             [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(mvg_targets.x{1});
%                             mvg_tx = this.visObj.fdt.getFDataObj(this.visObj.getStudy('l'),this.visObj.getSubject('l'),this.visObj.getChannel('l'),dType{1},dTypeNr(1),1);
%                             [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(mvg_targets.y{1});
%                             mvg_ty = this.visObj.fdt.getFDataObj(this.visObj.getStudy('l'),this.visObj.getSubject('l'),this.visObj.getChannel('l'),dType{1},dTypeNr(1),1);
%                             tx = uint16(round(mvg_tx.getFullImage()));
%                             ty = uint16(round(mvg_ty.getFullImage()));
%                             %get mvgroup roi and determine which pixels are not zero / NaN
%                             [mvg_img,roi_idx] = FData.getImgSeg(mvg_hfd.getFullImage(),rcL,rtL,rsL,riL,fileInfo,this.visObj.fdt.getVicinityInfo());
%                             mvg_mask = mvg_img(:) > 0;
%                             mvg_idx = roi_idx(mvg_mask);
%                             for mi = 1:length(mvg_idx)
%                                 %determine the mvgroup parameters for these hits
%                                 [row,col] = ind2sub([mvg_hfd.rawImgYSz(2),mvg_hfd.rawImgXSz(2)],mvg_idx(mi));
%                                 mvg_hfd.yPos2Lbl(row);
%                                 mvg_hfd.xPos2Lbl(col);
%                                 %
%                                 ix = tx == uint16(mvg_hfd.xPos2Lbl(col));
%                                 iy = ty == uint16(mvg_hfd.yPos2Lbl(row));
%                             end
                            
                            
%                             mask = zeros(size(this.mainExportXls),'single');
%                             if(~isempty(idx))
%                                 mask(idx) = 1;
%                                 mask = repmat(mask,1,1,4);
%                                 mask(:,:,1) = mask(:,:,1) .* gc(1);
%                                 mask(:,:,2) = mask(:,:,2) .* gc(2);
%                                 mask(:,:,3) = mask(:,:,3) .* gc(3);
%                                 mask(:,:,4) = mask(:,:,4) .* this.staticVisParams.ETDRS_subfield_bg_color(end);
%                                 hold(this.h_m_ax,'on');
%                                 this.h_ROIArea(ROIType) = image(this.h_m_ax,mask(:,:,1:3),'AlphaData',mask(:,:,4));
%                                 hold(this.h_m_ax,'off');
%                             end
                            
%                         end
                        
                        tmp = hfd{i}.getCrossSectionXVal(dispDim-1,true,rc,rt,rs,ri);
                        if(hfd{i}.getCrossSectionX() && tmp ~= 0)
                            line('XData',[tmp tmp],'YData',[1 size(current_img,1)],'LineWidth',1,'Linestyle','--','Color',sVisParam.crossSectionXColor,'Parent',hAx);
                        end
                        tmp = hfd{i}.getCrossSectionYVal(dispDim-1,true,rc,rt,rs,ri);
                        if(hfd{i}.getCrossSectionY() && tmp ~= 0)
                            line('XData',[1 size(current_img,2)], 'YData',[tmp tmp],'LineWidth',1,'Linestyle','--','Color',sVisParam.crossSectionYColor,'Parent',hAx);
                        end
                        %draw ROI if TOP view
                        if(dispDim == 1)
                            %check roi
                            if(rt > 1000)
                                if(sVisParam.ROIDrawAllOfType)
                                    allROI = hfd{i}.getROICoordinates([]);
                                    if(~isempty(allROI))
                                        idx = find(ROICtrl.decodeROIType(rt) == ROICtrl.decodeROIType(allROI(:,1,1)));                                        
                                        for j = 1:length(idx)
                                            ROICoord = hfd{i}.getROICoordinates(allROI(idx(j),1,1));
                                            if(~isempty(ROICoord))
                                                this.drawROI(allROI(idx(j),1,1),ROICoord(:,1),ROICoord(:,2:end),true);
                                            end
                                        end
                                    end
                                else
                                    ROICoord = this.ROICoordinates;
                                    if(~isempty(ROICoord))
                                        this.drawROI(rt,ROICoord(:,1),ROICoord(:,2:end),true);
                                    end
                                end
                            elseif(rt < 0)
                                %roi group
                                rt = abs(rt);
                                allGrps = this.visObj.fdt.getResultROIGroup(this.visObj.getStudy(this.mySide),[]);
                                if(rt <= size(allGrps,1))
                                    grt = allGrps{rt,2}; %list of roi types in this group
                                    for j = 1:length(grt)
                                        %draw all rois of the group
                                        ROICoord = hfd{i}.getROICoordinates(grt(j));
                                        %ROI in group may have been deleted (-> ROICoord is empty)
                                        if(~isempty(ROICoord))                                            
                                            this.drawROI(grt(j),ROICoord(:,1),ROICoord(:,2:end),true);
                                        end
                                    end
                                end
                            end
                        end
                        %make labels
%                         if(strncmp(hfd{i}.dType,'MVGroup',7) || strncmp(hfd{i}.dType,'ConditionMVGroup',16) || strncmp(hfd{i}.dType,'GlobalMVGroup',13))
%                             xLbl = hfd{i}.getCIXLbl(rc,rt,rs,ri);
%                             yLbl = hfd{i}.getCIYLbl(rc,rt,rs,ri);
%                             hAx.XTickLabel = xLbl(hAx.XTick);
%                             hAx.YTickLabel = yLbl(hAx.YTick);
%                         end
                        %save for export
                    case 3 %3D plot
                        if(sVisParam.offset_m3d && nrFD > 1)
                            %add offset to each 3d plot
                            if(hfd{i}.sType == 2)
                                %log10
                                if(sVisParam.offset_sc)
                                    %distribute plots equaly among axes
                                    pos = get(hAx,'Position');
                                    max_amp = pos(4)/nrFD;
                                    if(i > 1)
                                        offset = offset + max_amp;
                                    end
                                    %respect z scaling
                                    current_img = (current_img-zMin(i)) / (zMax(i)-zMin(i)) * max_amp + offset;
                                else
                                    %distribute plots based on their max-values
                                    if(i > 1)
                                        offset = offset + 10^zMax(i-1) - 10^zMin(i-1);
                                    end
                                    %add (linear) offset to linear data and log10 transform
                                    current_img =  log10(10^hfd{i}.getROIImage(rc,rt,rs,ri) + offset);
                                end                                
                            else
                                %linear
                                current_img = (current_img-zMin(i));
                                if(sVisParam.offset_sc)
                                    %distribute plots equaly among axes
                                    pos = get(hAx,'Position');
                                    max_amp = pos(4)/nrFD;
                                    if(i > 1)
                                        offset = offset + max_amp;
                                    end
                                    %respect z scaling
                                    current_img = current_img / (zMax(i)-zMin(i)) * max_amp;
                                else
                                    %distribute plots based on their max-values
                                    if(i > 1)
                                        offset = offset + zMax(i-1) - zMin(i-1);
                                    end
                                end
                                current_img = current_img + offset; %add offset
                            end
                        end                        
                        %% crossSections
                        crossSectionssWidth = 2;
                        if(sVisParam.padd) %padd with zeros (-inf)
                            if(hfd{i}.getCrossSectionX() && hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCrossSectionXInv())
                                    current_img(:,hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri)+1:end) = -inf;
                                else
                                    current_img(:,1:hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri)-1) = -inf;
                                end
                                if(sVisParam.color_crossSections)
                                    tmp = hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri);
                                    colors(:,tmp:tmp+crossSectionssWidth-1,:) = permute(repmat(repmat(sVisParam.crossSectionXColor,size(colors,2),1),[1 1 crossSectionssWidth]),[1 3 2]);
                                end
                            end
                            if(hfd{1}.getCrossSectionY() && hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{1}.getCrossSectionYInv())
                                    current_img(hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri)+1:end,:) = -inf;
                                else
                                    current_img(1:hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri)-1,:) = -inf;%m.sVisParam.zlim_min;
                                end
                                if(sVisParam.color_crossSections)
                                    tmp = hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri);
                                    colors(tmp:tmp+crossSectionssWidth-1,:,:) = permute(repmat(repmat(sVisParam.crossSectionYColor,size(colors,2),1),[1 1 crossSectionssWidth]),[3 1 2]);
                                end
                            end
                        elseif(~sVisParam.padd)%no padding
                            if(hfd{i}.getCrossSectionX() && hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCrossSectionXInv())
                                    current_img = current_img(:,1:hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri));
                                    alphaData = alphaData(:,1:hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri));
                                    colors = colors(:,1:hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri),:);
                                    if(sVisParam.color_crossSections)
                                        colors(:,end-crossSectionssWidth+1:end,:) = reshape(repmat(sVisParam.crossSectionXColor,size(colors,1),crossSectionssWidth),[size(colors,1) crossSectionssWidth 3]);
                                    end
                                else
                                    current_img = current_img(:,hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri):end);
                                    alphaData = alphaData(:,hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri):end);
                                    colors = colors(:,hfd{i}.getCrossSectionXVal(true,true,rc,rt,rs,ri):end,:);
                                    if(sVisParam.color_crossSections)
                                        colors(:,1:crossSectionssWidth,:) = reshape(repmat(sVisParam.crossSectionXColor,size(colors,1),crossSectionssWidth),[size(colors,1) crossSectionssWidth 3]);
                                    end
                                end                                
                            end
                            if(hfd{i}.getCrossSectionY() && hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCrossSectionYInv())
                                    current_img = current_img(1:hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri),:);
                                    alphaData = alphaData(1:hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri),:);
                                    colors = colors(1:hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri),:,:);
                                    if(sVisParam.color_crossSections)
                                        colors(end-crossSectionssWidth+1:end,:,:) = reshape(repmat(sVisParam.crossSectionYColor,size(colors,2),crossSectionssWidth),[crossSectionssWidth size(colors,2) 3]);
                                    end
                                else
                                    current_img = current_img(hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri):end,:);
                                    alphaData = alphaData(hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri):end,:);
                                    colors = colors(hfd{i}.getCrossSectionYVal(true,true,rc,rt,rs,ri):end,:,:);
                                    if(sVisParam.color_crossSections)
                                        colors(1:crossSectionssWidth,:,:) = reshape(repmat(sVisParam.crossSectionYColor,size(colors,2),crossSectionssWidth),[crossSectionssWidth size(colors,2) 3]);
                                    end
                                end                                
                            end
                        end
                        %change cluster background color
                        if((strncmp(hfd{i}.dType,'MVGroup',7) || strncmp(hfd{i}.dType,'ConditionMVGroup',16) ||strncmp(hfd{i}.dType,'GlobalMVGroup',13)) && (sum(sVisParam.cluster_grp_bg_color) ~= 0))
                            c = reshape(colors,[],3);
                            idx = c(:,1) == 0 & c(:,2) == 0 & c(:,3) == 0;
                            c_neu = repmat(sVisParam.cluster_grp_bg_color,sum(idx),1);
                            c(idx,:) = c_neu;
                            colors = reshape(c,[size(current_img) 3]);
                        end
                        %finally plot
                        surf(hAx,current_img,colors,'LineStyle','none','EdgeColor','none','FaceLighting','phong','AlphaDataMapping','none','AlphaData',alphaData);%,'FaceAlpha','flat'
                        alim(hAx,[0 1]);
                        cMM = [min(current_img(~isnan(current_img(:)) & ~isinf(current_img(:)))) max(current_img(~isnan(current_img(:)) & ~isinf(current_img(:))))];
                        if(abs(cMM(1) - cMM(2)) < eps)
                            %ensure a minimum dinstance
                            cMM(2) = cMM(1)+1;
                        end
                        caxis(hAx,cMM);
                        set(hAx,'YDir',ydir);
                        %set view
                        if(~isempty(this.disp_view))
                            view(hAx,this.disp_view);
                        end                        
                        %make labels
                        if(hfd{i}.sType == 2)
                            %log10
                            if(sVisParam.offset_m3d && nrFD > 1)
                                %add offset to each 3d plot
                                [tick_i,ticklbl_i] = FDisplay.makeLogScaling([10^zMin(i) 10^zMax(i)]);
                                if(sVisParam.offset_sc)
                                    %distribute plots equaly among axes
                                    [ztick,zticklbl] = FDisplay.mergeTicksLbls(ztick, zticklbl,(tick_i-min(tick_i))/ (max(tick_i)-min(tick_i))* max_amp + offset, ticklbl_i);
                                    if(any(isinf(ztick)))
                                        ztick(1) = (ztick(end)-ztick(2))/(numel(ztick)-1);
                                    end
                                else
                                    %distribute plots based on their max-values
                                    [ztick,zticklbl] = FDisplay.mergeTicksLbls(ztick, zticklbl,log10(10.^tick_i + offset), ticklbl_i);
                                end
                            else
                                [ztick,zticklbl] = FDisplay.makeLogScaling([this.current_img_lbl_min this.current_img_lbl_max]);
                            end
                            set(hAx,'color',sVisParam.supp_plot_bg_color,'Box','off','XLim',[1 size(current_img,2)],'YLim',[1 size(current_img,1)],'ZLim',[ztick(1) ztick(end)],'ZTick',ztick,'ZTickLabel',zticklbl);
                        else
                            %linear
                            if(sVisParam.offset_m3d && nrFD > 1)
                                %add offset to each 3d plot
                                [tick_i,ticklbl_i] = FDisplay.makeLinScaling([zMin(i) zMax(i)]);
                                if(sVisParam.offset_sc)
                                    %distribute plots equaly among axes
                                    [ztick,zticklbl] = FDisplay.mergeTicksLbls(ztick, zticklbl,(tick_i-zMin(i))/(zMax(i)-zMin(i))* max_amp + offset, ticklbl_i);
                                else
                                    %distribute plots based on their max-values
                                    [ztick,zticklbl] = FDisplay.mergeTicksLbls(ztick, zticklbl,tick_i + offset, ticklbl_i);
                                end
                                set(hAx,'color',sVisParam.supp_plot_bg_color,'Box','off','XLim',[1 size(current_img,2)],'YLim',[1 size(current_img,1)],'ZLim',[ztick(1) ztick(end)],'ZTick',ztick,'ZTickLabel',zticklbl);
                            else
                                set(hAx,'color',sVisParam.supp_plot_bg_color,'Box','off','XLim',[1 size(current_img,2)],'YLim',[1 size(current_img,1)],'ZLim',[this.current_img_lbl_min this.current_img_lbl_max]);
                            end                            
                        end
                        if(sVisParam.alpha ~= 1)
                            alpha(sVisParam.alpha);
                        end
                        if(sVisParam.grid)
                            grid(hAx,'on');
                        else
                            grid(hAx,'off');
                        end
                        if(nrFD > 1)
                            hold(hAx,'on');
                        end
                        shading(hAx,sVisParam.shading);
                end
                clear current_img
            end
            if(nrFD > 1)
                hold(hAx,'off');
            end
            if(~this.screenshot)
                if(dispDim == 3)
                    setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_m_ax,true);
                else
                    setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_m_ax,false);
                end
            end           
        end %makeMainPlot
        
        function setZoomAnchor(this,anchor)
            %set center for zoom
            hfd = this.gethfd();
            if(isempty(hfd{1}))
                return
            end
            hfd = hfd{1};
            rc = this.ROICoordinates;
            rt = max(0,this.ROIType); %ignore ROI groups
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            if(this.mDispDim == 1 && ~isempty(hfd.rawImgXSz) && ~isempty(hfd.rawImgYSz))
                xFullRange = hfd.rawImgXSz(end);
                yFullRange = hfd.rawImgYSz(end);
            else
                xFullRange = hfd.getCIxSz(rc,rt,rs,ri);
                yFullRange = hfd.getCIySz(rc,rt,rs,ri);
            end
            if(isempty(anchor) || length(anchor) ~= 2)                
                %set anchor to the center of the image
                this.zoomAnchor = [max(1,floor(xFullRange./2));max(1,floor(yFullRange./2))];
            else
%                 xNewRange = xFullRange./this.mZoomFactor;
%                 xNewHalfRange = floor(xNewRange./2);
%                 yNewRange = yFullRange./this.mZoomFactor;
%                 yNewHalfRange = floor(yNewRange./2);
%                 this.zoomAnchor(1) = max(xNewHalfRange+1,min(xFullRange-xNewHalfRange,this.zoomAnchor(1)));
%                 this.zoomAnchor(2) = max(yNewHalfRange+1,min(yFullRange-yNewHalfRange,this.zoomAnchor(2)));
                this.zoomAnchor = anchor(:);                
            end
        end
        
        function makeZoom(this)
            %apply zoom to main and supplemental plots; does NOT set labels correctly!
            hfd = this.gethfd();
            if(isempty(hfd{1}) || isempty(hfd{1}.rawImgXSz) || isempty(hfd{1}.rawImgYSz))
                return
            end
            hfd = hfd{1};
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            if(this.mDispDim == 1)
                xFullRange = hfd.rawImgXSz(end);
                yFullRange = hfd.rawImgYSz(end);
            else
%                 if(rt < 0)
%                     if(rt < 0)
%                         %ROI group
%                         current_img = hfd{i}.getROIImage(rc,0,rs,ri);
%                         allGrps = this.visObj.fdt.getResultROIGroup(this.visObj.getStudy(this.mySide),[]);
%                         if(abs(rt) <= size(allGrps,1))
%                             grt = allGrps{abs(rt),2}; %list of roi types in this group
%                             idx = [];
%                             for j = 1:length(grt)
%                                 %draw all rois of the group
%                                 ROICoord = hfd{i}.getROICoordinates(grt(j));
%                                 [~,idxTmp] = hfd{i}.getROIImage(ROICoord,grt(j),rs,ri);
%                                 idx = unique([idxTmp;idx]);
%                             end
%                             ci = NaN(size(current_img));
%                             ci(idx) = current_img(idx);
%                             current_img = FData.removeNaNBoundingBox(ci);
%                         end
                    
%                 else
                    xFullRange = hfd.getCIxSz(rc,rt,rs,ri);
                    yFullRange = hfd.getCIySz(rc,rt,rs,ri);
%                 end
            end
            if(isempty(xFullRange) || isempty(yFullRange) || xFullRange <= 1 || yFullRange <= 1)
                return
            end
            zoom = this.mZoomFactor;
            %main plot
            hAxMain = this.h_m_ax;
            if((zoom-1) < eps)
                hAxMain.XLim = [1 xFullRange];
                hAxMain.YLim = [1 yFullRange];
            else
                xNewRange = xFullRange./zoom;
                xNewHalfRange = floor(xNewRange./2);
                yNewRange = yFullRange./zoom;
                yNewHalfRange = floor(yNewRange./2);
                this.zoomAnchor(1) = max(xNewHalfRange+1,min(xFullRange-xNewHalfRange,this.zoomAnchor(1)));
                this.zoomAnchor(2) = max(yNewHalfRange+1,min(yFullRange-yNewHalfRange,this.zoomAnchor(2)));
                hAxMain.XLim = [max(1,this.zoomAnchor(1) - xNewHalfRange) min(xFullRange,this.zoomAnchor(1) + xNewHalfRange)];
                hAxMain.YLim = [max(1,this.zoomAnchor(2) - yNewHalfRange) min(yFullRange,this.zoomAnchor(2) + yNewHalfRange)];
            end
            this.makeMainXYLabels();
            %supplemental plot
            if(this.sDispMode == 4 && hfd.getCrossSectionX() && hfd.getCrossSectionXVal(true,true,rc,rt,rs,ri) ~= 0 )
                this.h_s_ax.XLim = hAxMain.YLim;
                xlbl = hfd.getCIYLbl(rc,rt,rs,ri);
            elseif(this.sDispMode == 3 && hfd.getCrossSectionY() && hfd.getCrossSectionYVal(true,true,rc,rt,rs,ri) ~= 0 )
                this.h_s_ax.XLim = hAxMain.XLim;
                xlbl = hfd.getCIXLbl(rc,rt,rs,ri);
            else
                return
            end
            xtick = get(this.h_s_ax,'XTick');
            idx = abs(fix(xtick)-xtick)<eps;
            pos = xtick(idx);
            xCell = cell(length(xtick),1);
            xCell(idx) = num2cell(xlbl(pos));
            this.h_s_ax.XTickLabel = xCell;
        end
          
        function makeMainXYLabels(this)
            %axis labes
            hfd = this.gethfd();
            if(isempty(hfd{1}))
                cla(this.h_m_ax);
                axis(this.h_m_ax,'off');
                return
            end
%             if(~this.screenshot)
%                 set(this.h_m_ax,'FontUnits','pixels','Fontsize',this.staticVisParams.fontsize);
%             end
            if(this.mDispDim == 1) %2Do
                xlbl = hfd{1}.getRIXLbl();
                ylbl = hfd{1}.getRIYLbl();
            else %2D, 3D
                rc = this.ROICoordinates;
                rt = this.ROIType;
                rs = this.ROISubType;
                ri = this.ROIVicinity;
                xlbl = hfd{1}.getCIXLbl(rc,rt,rs,ri);
                ylbl = hfd{1}.getCIYLbl(rc,rt,rs,ri);
            end
            if(isempty(xlbl) || isempty(ylbl))
                cla(this.h_m_ax);
                axis(this.h_m_ax,'off');
                return
            end
            xtick = get(this.h_m_ax,'XTick');
            xtick = min(xtick,length(xlbl));
            idx = abs(fix(xtick)-xtick)<eps; %only integer labels
            pos = xtick(idx);
            idx = find(idx);
            idx(~pos) = [];
            pos(~pos) = [];
            xCell = cell(length(xtick),1);
            xCell(idx) = num2cell(xlbl(pos));
            ytick = get(this.h_m_ax,'YTick');
            ytick = min(ytick,length(ylbl));
            idx = abs(fix(ytick)-ytick)<eps; %only integer labels
            pos = ytick(idx);
            idx(~pos) = [];
            pos(~pos) = [];
            yCell = cell(length(ytick),1);
            yCell(idx) = num2cell(ylbl(pos));
            set(this.h_m_ax,'XTickLabel',xCell,'YTickLabel',yCell);
        end
        
        function drawColorbarOnSuppPlot(this)
            %draw colobar behind histogram on supplemental axes
            hfd = this.myhfdSupp;
            if(isempty(hfd{1}))
                return
            end
            hfd = hfd{1};
            cTmp = single(this.myColorScaleObj.getCurCSInfo());
            if(isempty(cTmp) || length(cTmp) ~= 3)
                %should not happen
                error('no auto-scaled color found!');
            end
            %fit color scaling to histogram classes            
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            [~, centers] = hfd.getCIHist(rc,rt,rs,ri);            
            if(length(centers) > 1)
                classWidth = centers(2)-centers(1);
                cStartClass = round((cTmp(2)-centers(1))./classWidth)+1;
                cEndClass = round((cTmp(3)-centers(1))./classWidth)+1;                
                %endClass = round((max(centers(end),cTmp(3))-centers(1))./classWidth)+1;
                %centers = (0:endClass).*classWidth;
            else
                cStartClass = 1;
                cEndClass = 1;
                classWidth = 0;
            end
            this.colorStartClass = cStartClass;
            this.colorEndClass = cEndClass;
            this.colorClassWidth = classWidth;            
            %add colorbar either in full axes or at specified location, put it behind the bar
            xtemp = [cStartClass cEndClass];
            ytemp = this.h_s_ax.YLim;
            dp = this.getDynVisParams();
            %temp = zeros(1,length(dp.cm), 3);
            if(hfd.rawImgIsLogical)
                temp(1,:,:) = gray(2);
            elseif(strcmp(hfd.dType,'Intensity'))
                temp(1,:,:) = dp.cmIntensity;
            elseif(strncmp(hfd.dType,'MVGroup',7))
                if(length(hfd.rawImgZSz) < 2)
                    %MVGroup computation failed
                    temp(1,:,:) = FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,1);
                else
                    temp(1,:,:) = FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,hfd.rawImgZSz(2));
                end
%             elseif(strncmp(hfd.dType,'ConditionMVGroup',16))
%             elseif(strncmp(hfd.dType,'GlobalMVGroup',13))
            else
                temp(1,:,:) = dp.cm;
            end
%             if(strcmp(hfd{1}.dType,'Intensity'))
%                 temp = zeros(1,length(this.dynVisParams.cmIntensity), 3);
%                 temp(1,:,:) = this.dynVisParams.cmIntensity;
%             else
%                 temp = zeros(1,length(this.dynVisParams.cm), 3);
%                 temp(1,:,:) = this.dynVisParams.cm;
%             end
            if(~isempty(this.h_cmImage) && ishghandle(this.h_cmImage) && this.h_cmImage > 0)
                try
                    delete(this.h_cmImage);
                    this.h_cmImage = [];
                end
            end
            if(abs(cStartClass - cEndClass) > eps)
                %draw colormap only if we have at least one class
                this.h_cmImage = image('XData',xtemp,'YData',ytemp,'CData',temp,'Parent',this.h_s_ax);
                this.h_s_ax.YLim = ytemp;
                uistack(this.h_cmImage,'bottom');
            end
        end
          
        function makeSuppPlot(this)
            %make current supplemental plot
            hfd = this.myhfdSupp;
            if(isempty(hfd{1}))
                cla(this.h_s_ax);
                axis(this.h_s_ax,'off');
                set(this.h_s_hist,'Visible','off');
                return
            end
            nrFD = length(hfd);
            this.suppExport = [];
            %             if(~this.screenshot)
            %                 set(this.h_s_ax,'Fontsize',this.staticVisParams.fontsize);
            %             end
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIVicinity;
            switch this.sDispMode
                case 1 %nothing to do
                    cla(this.h_s_ax);
                    axis(this.h_s_ax,'off');
                case 2 %histogram
                    if(length(hfd) == 1) %only for univariate data
                        switch this.sDispHistMode
                            case 1 %histogram of current subject
                                [histo, centers] = hfd{1}.getCIHist(rc,rt,rs,ri);
                                %centers = hfd{1}.getCIHistCenters();
                            case 2 %histogram of current study view
                                list = get(this.h_m_p,'String');
                                typeSel = get(this.h_m_p,'Value');
                                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(char(list(typeSel,:)));
                                [centers, histo] = this.visObj.fdt.getStudyHistogram(...
                                    this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide),...
                                    this.visObj.getChannel(this.mySide),dType{1},dTypeNr(1),this.ROIType,this.ROISubType,this.ROIVicinity);
%                             case 3 %global histogram
%                                 list = get(this.h_m_p,'String');
%                                 typeSel = get(this.h_m_p,'Value');
%                                 [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(char(list(typeSel,:)));
%                                 [centers, histo] = this.visObj.fdt.getGlobalHistogram(...
%                                     this.visObj.getChannel(this.mySide),dType{1},dTypeNr(1));
                        end
                        if(isempty(centers))
                            cla(this.h_s_ax);
                            axis(this.h_s_ax,'off');
                            return
                        end
                        this.suppExport = [centers' histo'];
                        h = bar(this.h_s_ax,histo,'hist','Parent',this.h_s_ax);
                        h.FaceColor = [0 0 0];
                        h.EdgeColor = [0 0 0];
                        if(this.staticVisParams.grid)
                            grid(this.h_s_ax,'on');
                        else
                            grid(this.h_s_ax,'off');
                        end
                        if(length(histo) > 1)
                            xlim(this.h_s_ax,size(histo));
                        end
                        if(~this.myColorScaleObj.check && ~isempty(this.mySuppXZoomScale))
                            lb = this.mySuppXZoomScale(1);
                            ub = this.mySuppXZoomScale(2);                            
                            xlim(this.h_s_ax,[lb ub]);
                        else
                            lb = this.h_s_ax.XLim(1); 
                            ub = this.h_s_ax.XLim(2);
                        end
                        xtick = get(this.h_s_ax,'XTick');
                        if(xtick(1) == 0)
                            xtick = xtick+1;
                        end
                        if(length(centers) > 1)% && xtick(end) > length(centers))
                            classWidth = centers(2) - centers(1);
                            centers = (lb-1:ub).*classWidth + centers(1);
                            set(this.h_s_ax,'color',this.staticVisParams.supp_plot_bg_color,'XTickLabel',FLIMXFitGUI.num4disp(centers(xtick-lb+1)'));
                        else
                            set(this.h_s_ax,'color',this.staticVisParams.supp_plot_bg_color,'XTickLabel',centers(1));
                        end                        
                        this.drawColorbarOnSuppPlot();
                    else %nothing to do
                        cla(this.h_s_ax);
                        axis(this.h_s_ax,'off');
                    end
                case {3, 4} %3:horizontal crossSection, 4: vertical crossSection
                    if( (this.sDispMode == 4 && hfd{1}.getCrossSectionX() && hfd{1}.getCrossSectionXVal(true,true,rc,rt,rs,ri) ~= 0 ) ||...
                            (this.sDispMode == 3 && hfd{1}.getCrossSectionY() && hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri) ~= 0 ))
                        offset = 0;
                        max_amp = 0;
                        ytick = [];
                        yticklbl = [];
                        for i= 1:nrFD
                            %get data from object with the appropriate data format
                            if(hfd{i}.sType == this.sDispScale)
                                current_img = hfd{i}.getROIImage(rc,rt,rs,ri);
                                zMin(i) = hfd{i}.getCImin(rc,rt,rs,ri);
                                zMax(i) = hfd{i}.getCImax(rc,rt,rs,ri);
                                %z scaling
                                zData = hfd{i}.getZScaling();
                                if(~isempty(zData) && zData(1))
                                    zMin(i) = zData(2);
                                    zMax(i) = zData(3);
                                end
                            else
                                %get data from object with the appropriate data format
                                switch this.sDispScale
                                    case 2
                                        hfdT = hfd{i}.getLogData();
                                    otherwise %linear data
                                        hfdT = hfd{i}.getLinData();
                                end
                                current_img = hfdT.getROIImage(rc,rt,rs,ri);
                                zMin(i) = hfdT.getCImin();
                                zMax(i) = hfdT.getCImax();
                                %z scaling
                                zData = hfdT.getZScaling();
                                if(~isempty(zData) && zData(1))
                                    zMin(i) = zData(2);
                                    zMax(i) = zData(3);
                                end
                            end
                            if(this.staticVisParams.offset_m3d && nrFD > 1)
                                %get offset
                                pos = get(this.h_s_ax,'Position');
                                max_amp = pos(4)/nrFD;
                            end
                            %crossSections
                            if(this.sDispMode == 3) %horizontal crossSection
                                current_img = current_img(min(hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri),size(current_img,1)),:);
                                this.suppExport(:,i) = current_img;
                            else %vertical crossSection
                                current_img = current_img(:,min(hfd{1}.getCrossSectionXVal(true,true,rc,rt,rs,ri),size(current_img,2)));
                                this.suppExport(:,i) = current_img;
                            end
                            if(nrFD > 1)
                                if(this.sDispScale == 2 && this.staticVisParams.offset_m3d)
                                    %log10
                                    if(this.staticVisParams.offset_sc)
                                        %distribute plots equaly among axes
                                        current_img = (current_img-zMin(i)) / (zMax(i)-zMin(i)) * max_amp + offset;
                                    end
                                    current_img(isinf(current_img)) = 0;
                                elseif(this.sDispScale ~= 2 && this.staticVisParams.offset_m3d)
                                    %linear, percent
                                    if(this.staticVisParams.offset_sc)
                                        %distribute plots equaly among axes
                                        current_img = (current_img-zMin(i)) / (zMax(i)-zMin(i)) * max_amp;
                                    end
                                    current_img = current_img + offset;
                                end
                            end
                            plot(this.h_s_ax,current_img,'Color',this.staticVisParams.supp_plot_color,'LineWidth',this.staticVisParams.supp_plot_linewidth);
                            if(nrFD > 1)
                                hold(this.h_s_ax,'on');
                            end
                            %y-limits & scaling
                            if(this.sDispScale == 2)
                                %log10 scaling
                                if(this.staticVisParams.offset_m3d && nrFD > 1)
                                    %add offset to each 3d plot
                                    [tick_i, ticklbl_i] = FDisplay.makeLogScaling([10^zMin(i) 10^zMax(i)]);
                                    if(this.staticVisParams.offset_sc)
                                        %distribute plots equaly among axes
                                        [ytick, yticklbl] = FDisplay.mergeTicksLbls(ytick, yticklbl, ...
                                            (tick_i-min(tick_i))/ (max(tick_i)-min(tick_i))* max_amp + offset, ticklbl_i);
                                    else
                                        %distribute plots based on their max-values
                                        [ytick, yticklbl] = FDisplay.mergeTicksLbls(ytick, yticklbl, ...
                                            log10(10.^tick_i + offset), ticklbl_i);
                                    end
                                else
                                    %no offset
                                    [ytick, yticklbl] = FDisplay.makeLogScaling([10^min(zMin(:)) 10^max(zMax(:))]);
                                end
                                set(this.h_s_ax,'YTick',ytick,'YTickLabel',yticklbl);
                                ylim(this.h_s_ax,[ytick(1) ytick(end)]);
                            else
                                %linear, percent
                                if(this.staticVisParams.offset_m3d && nrFD > 1)
                                    %add offset to each 3d plot
                                    [tick_i, ticklbl_i] = FDisplay.makeLinScaling([zMin(i) zMax(i)]);
                                    if(this.staticVisParams.offset_sc)
                                        %distribute plots equaly among axes
                                        [ytick, yticklbl] = FDisplay.mergeTicksLbls(ytick, yticklbl, ...
                                            (tick_i-zMin(i))/ (zMax(i)-zMin(i))* max_amp + offset, ticklbl_i);
                                    else
                                        %distribute plots based on their max-values
                                        [ytick, yticklbl] = FDisplay.mergeTicksLbls(ytick, yticklbl, ...
                                            tick_i + offset, ticklbl_i);
                                    end
                                    set(this.h_s_ax,'YTick',ytick,'YTickLabel',yticklbl);
                                else
                                    %no offset
                                    %                                     [ytick, yticklbl] = FDisplay.makeLinScaling([min(zMin(:)) max(zMax(:))]);
                                    ytick = get(this.h_s_ax,'YTick');
                                end
                                ylim(this.h_s_ax,[ytick(1) ytick(end)]);
                            end
                            %xlim
                            xlim(this.h_s_ax,[1 length(current_img)]);
                            %x labels
                            if(this.sDispMode == 3)
                                xlbl = hfd{i}.getCIXLbl(rc,rt,rs,ri);
                            else
                                xlbl = hfd{i}.getCIYLbl(rc,rt,rs,ri);
                            end
                            xtick = get(this.h_s_ax,'XTick');
                            idx = abs(fix(xtick)-xtick)<eps;
                            pos = xtick(idx);
                            xCell = cell(length(xtick),1);
                            xCell(idx) = num2cell(xlbl(pos));
                            set(this.h_s_ax,'XTickLabel',xCell);
                            %grid
                            if(this.staticVisParams.grid)
                                grid(this.h_s_ax,'on');
                            else
                                grid(this.h_s_ax,'off');
                            end
                            set(this.h_s_ax,'color',this.staticVisParams.supp_plot_bg_color);
                            %get offset for next iteration
                            if(this.staticVisParams.offset_sc)
                                %distribute plots equaly among axes
                                offset = offset + max_amp;
                            else
                                %distribute plots based on their max-values
                                if(this.sDispScale == 2)
                                    %log10 scaling
                                    offset = offset + 10^zMax(i);
                                else
                                    %linear, percent
                                    offset = offset + zMax(i);
                                end
                            end
                        end
                        if(this.sDispMode == 3 && hfd{1}.getCrossSectionX() && hfd{1}.getCrossSectionXVal(true,true,rc,rt,rs,ri) ~= 0 && this.staticVisParams.show_crossSection)
                            %horizontal crossSection
                            line('XData',[hfd{1}.getCrossSectionXVal(true,true,rc,rt,rs,ri) hfd{1}.getCrossSectionXVal(true,true,rc,rt,rs,ri)],...
                                'YData',ylim, ...
                                'LineWidth',1,'Linestyle','--','Color',this.staticVisParams.crossSectionXColor,'Parent',this.h_s_ax);
                        end
                        if(this.sDispMode == 4 && hfd{1}.getCrossSectionY() && hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri) ~= 0 && this.staticVisParams.show_crossSection)
                            %vertical crossSection
                            line('XData',[hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri) hfd{1}.getCrossSectionYVal(true,true,rc,rt,rs,ri)],...
                                'YData',ylim, ...
                                'LineWidth',1,'Linestyle','--','Color',this.staticVisParams.crossSectionYColor,'Parent',this.h_s_ax);
                        end
                    else
                        %nothing to do
                        cla(this.h_s_ax);
                        axis(this.h_s_ax,'off');
                    end
                otherwise%nothing to do
                    cla(this.h_s_ax);
                    axis(this.h_s_ax,'off');
            end
            if(nrFD > 1)
                hold(this.h_s_ax,'off');
            end
            if(~this.screenshot)
                this.h_s_ax.FontSize = this.staticVisParams.fontsize;
                this.h_s_ax.FontUnits = 'pixels';
                if(strcmp(this.mySide,'l'))
                    this.h_s_ax.YAxisLocation = 'right';
                end
                setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_s_ax,false);
            end
        end %makeSuppPlot
        
        function makeDSTable(this)
            %fill descriptive statistics table
            [~, hfd] = this.gethfd();    %update hfd(s)
            if(this.ROIType >= 0 && (isempty(hfd{1}) || length(hfd) > 1 || ~any(this.ROICoordinates(:))))
                %ROI is empty and not a ROI group
                this.h_ds_t.Data = cell(0,0);
            else
                data(:,1) = hfd{1}.getDescriptiveStatisticsDescriptionShort();
                stats = hfd{1}.getROIStatistics(this.ROICoordinates,this.ROIType,this.ROISubType,this.ROIVicinity);
                if(isempty(stats))
                    data(:,2) = cell(size(data,1),1);
                else
                    data(:,2) = FLIMXFitGUI.num4disp(stats);
                end
                this.h_ds_t.Data = data;
            end
        end
        
        function updateColorbar(this)
            %update the colorbar to the current color map
            hfd = this.gethfd();
            hfd = hfd{1};
            if(isempty(hfd))
                cla(this.h_cm);
                return
            end
            dp = this.getDynVisParams();
            if(hfd.rawImgIsLogical)
                temp(:,1,:) = gray(2);
                ytick = 1:2;
            elseif(strcmp(hfd.dType,'Intensity'))
                temp(:,1,:) = dp.cmIntensity;
                ytick = (0:0.25:1).*size(temp,1);
            elseif(strncmp(hfd.dType,'MVGroup',7))
                if(length(hfd.rawImgZSz) < 2)
                    %MVGroup computation failed
                    temp(:,1,:) = FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,1);
                else
                    temp(:,1,:) = FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,hfd.rawImgZSz(2));
                end
%             elseif(strncmp(hfd.dType,'ConditionMVGroup',16))
%             elseif(strncmp(hfd.dType,'GlobalMVGroup',13))
            else
                temp(:,1,:) = dp.cm;
                ytick = (0:0.25:1).*size(temp,1);
            end
            image(temp,'Parent',this.h_cm);            
            ytick(1) = 1;
            set(this.h_cm,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.h_cm,[1 size(temp,1)]);
            if(isfield(this.visObj.visHandles,'hrotate3d'))
                setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_cm,false);
            end
        end
        
        function updateColorBarLbls(this)
            %update the labels of the colorbar
            hfd = this.gethfd();
            hfd = hfd{1};
            if(isempty(hfd))
                tickLbls = cell(5,1);
            else
                if(hfd.rawImgIsLogical)
                    tickLbls = cell(5,1);
                    tickLbls{1} = '0';
                    tickLbls{5} = '1';
                else
                    tickLbls = this.makeColorBarLbls(5);
                end
            end            
            for i=1:5
                set(this.(sprintf('h_t%s',num2str(i))),'String',tickLbls{i},'FontUnits','pixels','Fontsize',this.staticVisParams.fontsize);
            end
        end
        
        function out = makeColorBarLbls(this,nTicks)
            %make nTicks labels for the color bar
            nTicks = max(2,nTicks); %at least 2 labels
            out = cell(nTicks,1);
%             if(this.mDispDim == 1)
%                 hfd = this.gethfd();
%                 if(isempty(hfd{1}))
%                     return
%                 end
%                 if(isempty(hfd{1}.rawImgZSz))
%                     img_min = 0;
%                     img_max = 0;
%                 else
%                     zData = hfd{1}.getZScaling();
%                     if(~isempty(zData) && zData(1))                        
%                         img_min = zData(2);
%                         img_max = zData(3);
%                     else
%                         img_min = hfd{1}.rawImgZSz(1);
%                         img_max = hfd{1}.rawImgZSz(2);
%                     end
%                 end
%             else
%                 img_min = this.current_img_lbl_min;
%                 img_max = this.current_img_lbl_max;
%             end
%             if(isempty(img_min))
%                 return
%             end            
%             if(isempty(img_max))
%                 return
%             end
            
            %range = img_max - img_mini;
            hfd = this.gethfd();
            if(isempty(hfd{1}))
                return
            end
            hfd = hfd{1};
            if(strcmp(this.dynVisParams.cmType,'SpectrumFixed') && ~strcmp(hfd.dType,'Intensity'))
                cs = [1 380 780];
            elseif(strncmp(hfd.dType,'MVGroup',7))
                if(isempty(hfd.rawImgZSz))
                    cs = [1 0 1];
                else
                    cs = [1 hfd.rawImgZSz];
                end
            else
                cs = this.myColorScaleObj.getCurCSInfo();
            end
            vec = linspace(double(cs(2)),double(cs(3)),nTicks);
            %out(:,1) = arrayfun(@FLIMXFitGUI.num4disp,vec,'UniformOutput',false);
            out(:,1) = FLIMXFitGUI.num4disp(vec);
        end
        
        function colorImg = makeIntOverlay(this,colorImg,intImg)
            %make intensity overlay on color image
            intImg = double(intImg);
            if(size(intImg,1) == size(colorImg,1) && size(intImg,2) == size(colorImg,2))
                brightness = this.intOverBright;
                %contrast = 1;
                intImg = intImg - min(intImg(:));
                %intImg = histeq(intImg./max(intImg(:)));
                intImg = intImg/max(intImg(:));  %*(size(this.dynVisParams.cm,1)-1)+1; %mapping for colorbar
                intImg(isnan(intImg)) = 0;
                %adapt brightness and contrast of intensity image
                %from GIMP (wikipedia): 
                % if (brightness < 0.0)  value = value * ( 1.0 + brightness);
                %   else value = value + ((1.0 - value) * brightness);
                % value = (value - 0.5) * (tan ((contrast + 1) * PI/4) ) + 0.5;
                if(brightness < 0)
                    intImg = intImg .* (brightness+1);
                else
                    intImg = intImg + (1-intImg) .* brightness;
                end
%                 intImg = (intImg - 0.5) .* contrast + 0.5;
                intImg = repmat(intImg,[1 1 3]);
                if(size(colorImg,3) == 1)
                    %just to be save
                    colorImg = repmat(colorImg,[1 1 3]);
                end
                %invert intImg
                intImg = abs(intImg-1);
                colorImg = colorImg-intImg;
                colorImg(colorImg < 0) = 0;
                %
                colorImg = colorImg-min(colorImg(:));
                colorImg = colorImg/max(colorImg(:));
            end
        end
        
        %% dependent properties
        
        function out = get.ROICoordinates(this)
            %
            out = double(this.visObj.getROICoordinates(this.mySide));
        end
        
        function out = get.ROIType(this)
            %
            out = this.visObj.getROIType(this.mySide);
        end  
        
        function out = get.ROISubType(this)
            %
            out = this.visObj.getROISubType(this.mySide);
        end
        
        function out = get.ROIVicinity(this)
            %
            out = this.visObj.getROIVicinity(this.mySide);
        end
        
        function out = get.crossSectionXVal(this)
            %
            if(this.visObj.fdt.getCrossSectionX(this.myDS))
                out = this.visObj.fdt.getCrossSectionXVal(this.myDS,true);
            else
                out = 0;
            end
        end
        
        function out = get.crossSectionYVal(this)
            %
            if(this.visObj.fdt.getCrossSectionY(this.myDS))
                out = this.visObj.fdt.getCrossSectionYVal(this.myDS,true);
            else
                out = 0;
            end
        end
        
        function out = get.crossSectionXInv(this)
            %
            out = this.visObj.fdt.getCrossSectionXInv(this.myDS);
        end
        
        function out = get.crossSectionYInv(this)
            %
            out = this.visObj.fdt.getCrossSectionYInv(this.myDS);
        end
        
        function out = get.mDispDim(this)
            %
            out = get(this.h_m_pdim,'Value');
        end
        
        function out = get.mDispScale(this)
            %
            out = get(this.h_m_psc,'Value');
        end
        
        function out = get.mZoomFactor(this)
            %
            out = get(this.h_zoom_slider,'Value');
        end
        
        function out = get.sDispMode(this)
            %
            out = get(this.h_s_p,'Value');
        end
        
        function out = get.sDispHistMode(this)
            %
            out = get(this.h_s_hist,'Value');
        end
        
        function out = get.sDispScale(this)
            %
            out = get(this.h_s_psc,'Value');
        end
        
        function out = get.intOver(this)
            %
            out = get(this.h_io_check,'Value');
        end
        
        function out = get.intOverBright(this)
            %
            out = str2double(get(this.h_io_edit,'String'));
        end
        
        function out = get.h_pd(this)
            %
            out = this.visObj.visHandles.(sprintf('subject_%s_pop',this.mySide));
        end
        
        function out = get.h_m_ax(this)
            %
            out = this.getHandleMainAxes();
        end
        
        function out = get.h_s_ax(this)
            %
            out = this.getHandleSuppAxes();
        end
        
        function out = get.h_m_p(this)
            %
            out = this.visObj.visHandles.(sprintf('flim_param_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pvar(this)
            %
            out = this.visObj.visHandles.(sprintf('var_mode_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pdim(this)
            %
            out = this.visObj.visHandles.(sprintf('dimension_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pch(this)
            %
            out = this.visObj.visHandles.(sprintf('channel_%s_pop',this.mySide));
        end
        
        function out = get.h_m_psc(this)
            %
            out = this.visObj.visHandles.(sprintf('scale_%s_pop',this.mySide));
        end
        
        function out = get.h_s_p(this)
            %
            out = this.visObj.visHandles.(sprintf('supp_axes_%s_pop',this.mySide));
        end
        
        function out = get.h_s_hist(this)
            %
            out = this.visObj.visHandles.(sprintf('supp_axes_hist_%s_pop',this.mySide));
        end
        
        function out = get.h_s_psc(this)
            %
            out = this.visObj.visHandles.(sprintf('supp_axes_scale_%s_pop',this.mySide));
        end
        
        function out = get.h_ds_t(this)
            %
            out = this.visObj.visHandles.(sprintf('descStats_%s_table',this.mySide));
        end
        
        function out = get.h_cm(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_%s_axes',this.mySide));
        end
        
        function out = get.h_t1(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_1_%s_text',this.mySide));
        end
        
        function out = get.h_t2(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_2_%s_text',this.mySide));
        end
        
        function out = get.h_t3(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_3_%s_text',this.mySide));
        end
        
        function out = get.h_t4(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_4_%s_text',this.mySide));
        end
        
        function out = get.h_t5(this)
            %
            out = this.visObj.visHandles.(sprintf('cm_5_%s_text',this.mySide));
        end        
        
        function out = get.h_io_check(this)
            %
            out = this.visObj.visHandles.(sprintf('IO_%s_check',this.mySide));
        end
        
        function out = get.h_io_edit(this)
            %
            out = this.visObj.visHandles.(sprintf('IO_%s_edit',this.mySide));
        end
                
        function out = get.h_zoom_slider(this)
            %
            out = this.visObj.visHandles.(sprintf('zoom_%s_slider',this.mySide));
        end
        
        function out = get.h_s_colormapLowEdit(this)
            %
            out = this.visObj.visHandles.(sprintf('colormap_low_%s_edit',this.mySide));
        end
        
        function out = get.h_s_colormapHighEdit(this)
            %
            out = this.visObj.visHandles.(sprintf('colormap_high_%s_edit',this.mySide));
        end        
        
        %visualization parameters
        function out = get.dynVisParams(this)
            %
            out = this.getDynVisParams();
        end
        
        function set.dynVisParams(this,val)
            %
            this.setDynVisParams(val);
        end
        
        function out = get.staticVisParams(this)
            %
            out = this.getStaticVisParams();
        end
        
        %dependent properties helper methods
        function out = getDynVisParams(this)
            %
            out = this.visObj.dynParams;
        end
        
        function setDynVisParams(this,val)
            %
            this.visObj.dynParams = val;
        end
        
        function out = getStaticVisParams(this)
            %
            out = this.visObj.visParams;
        end
        
        function out = getHandleMainAxes(this)
            %get handle to main axes
            out = this.visObj.visHandles.(sprintf('main_%s_axes',this.mySide));
        end
        
        function out = getHandleSuppAxes(this)
            %get handle to support axes
            out = this.visObj.visHandles.(sprintf('supp_%s_axes',this.mySide));
        end        
    end %methods
    
    methods(Access = protected)
        %internal methods
    end %methods protected
    
    methods(Static)
        function [tick, ticklbl, color_min, color_max] = makeLinScaling(img)
            %make ticks and tick labels for a linear axis scaling
            %max(img) is the last tick / tick label
            color_min = min(img(:));
            color_max = max(img(:));
            log_max = floor(log10(color_max-color_min));
            %tick = [0 0.2 0.4 0.6 0.8 1];
            tick = [0 0.5 1];
            tick = tick*10^log_max;
            %ticklbl = cell(1,length(tick));
            ticklbl = FLIMXFitGUI.num4disp(tick);
            
            %add additional ticks up to actual maximum
            tail = color_max-10^(log_max);
            % for i=5:5:ceil(tail / 10^(log_max-1))
            %     tick = [tick tick(3)+i*10^(log_max-1)];
            %     ticklbl(end+1) = {FLIMXFitGUI.num4disp(tick(3)+i*10^(log_max-1))};
            % end
            i = 5;
            i_stop = ceil(tail / 10^(log_max-1));
            while(i-5 < i_stop)
                tick = [tick tick(3)+i*10^(log_max-1)];
                ticklbl(end+1) = FLIMXFitGUI.num4disp(tick(3)+i*10^(log_max-1));
                i=i+5;
            end
            idx = tick >= color_min & tick <= color_max;
            tick = tick(idx);
            ticklbl = ticklbl(idx);
            if((tick(1) - color_min) > eps)%old 0.001%drecksverschissener mistverwichster hack weil if((tick(1) > color_min) nicht richtig funktioniert
                tick = [color_min tick];
                ticklbl(2:end+1) = ticklbl;
                ticklbl(1) = FLIMXFitGUI.num4disp(color_min);
            else
                
            end
            if((color_max - tick(end)) > eps)
                tick(end+1) = color_max;
                ticklbl(end+1) = FLIMXFitGUI.num4disp(color_max);
            else
                
            end
            %tick = tick - min(tick);
        end
        
        function [tick, ticklbl, color_min, color_max] = makeLogScaling(img)
            %make ticks and tick labels for a log10 axis scaling
            %max(img) is the last tick / tick label
            lin_min = min(img(:));
            lin_max = max(img(:));
            if(lin_min == 0)
                img = sort(reshape(img,[],1));
                for i = 2:length(img)
                    if(img(i) ~= 0)
                        lin_min = img(i);
                        break;
                    end
                end
            end
            color_min = log10(lin_min);
            color_max = log10(lin_max);
            log_max = floor(color_max);
            log_min = round(color_min);
            tick_0 = [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1];
            tick = [];
            ticklbl = {};
            
            if(log_min == log_max)
                %min & max are on the same log10, e.g. 200
                tick = floor(lin_min/10^log_min)*10^log_min+[0.1 tick_0].*10^log_min;
                %ticklbl(1) = FLIMXFitGUI.num4disp(tick(1));
                ticklbl(10) = FLIMXFitGUI.num4disp(tick(end));
            else
                for i=log_min:log_max
                    tick = [tick tick_0.*10^i];
                    ticklbl(length(ticklbl)+9)=FLIMXFitGUI.num4disp(10^i);
                end
                %add additional ticks up to actual maximum
                for i=2:ceil(lin_max / 10^log_max)
                    tick = [tick i*10^log_max];
                    ticklbl(end+1) = {''};
                end
            end
            idx = tick >= lin_min & tick <= lin_max;
            tick = tick(idx);
            ticklbl = ticklbl(idx);
            if((tick(1) - lin_min) > max(eps,(lin_max-lin_min)*0.001))%drecksverschissener mistverwichster hack weil if((tick(1) > color_min) nicht richtig funktioniert
                tick = [lin_min tick];
                ticklbl(2:end+1) = ticklbl;
                ticklbl(1) = FLIMXFitGUI.num4disp(lin_min);
            else
                ticklbl(1) = FLIMXFitGUI.num4disp(tick(1));
            end
            if((lin_max - tick(end)) > max(eps,(lin_max-lin_min)*0.001))
                tick(end+1) = lin_max;
                ticklbl(end+1) = FLIMXFitGUI.num4disp(lin_max);
            else
                ticklbl(end) = FLIMXFitGUI.num4disp(tick(end));
            end
            % tick = tick - min(tick);
            %transform ticks
            tick = log10(tick);
        end
        
        function [ticks, lbls] = mergeTicksLbls(ticks1, lbls1, ticks2, lbls2)
            %function to merge two axes ticks and related labels
            %ticks1 MUST be the lower one, ticks2 the upper!
            if(isempty(ticks1))
                ticks = ticks2;
                lbls = lbls2;
                return;
            elseif(isempty(ticks2))
                ticks = ticks1;
                lbls = lbls1;
                return;
            end
            
            % if(ticks1(end) == ticks2(1))
            ticks = [ticks1(1:end-1) ticks2];
            lbls = [lbls1(1:end-1) lbls2];
            % else
            %     ticks = zeros(1,length(ticks1)+length(ticks2));
            %     lbls = lbls1(1:end);
            % end
        end
        
        function out = makeMVGroupColorMap(colorRGB,cmSize,dataMax)
            %make a color map from a single RGB color, using a logarithmic scaling of the brightness
            originalrgb = colorRGB; %replace by whatever rgb colour you want
            originalhsv = rgb2hsv(originalrgb);  %get the HSV values of your original colour. We really only care about the hue
            ciL10 = 1+double(log10(dataMax));
            logCM = log10(linspace(1,10^ciL10,cmSize))'/ciL10;
            maphsv = rgb2hsv(repmat(logCM,1,3)); %rgb2hsv(gray(256));  convert to hsv
            maphsv(:, 1) = originalhsv(1);  %replace gray hue by original hue
            maphsv(:, 2) = originalhsv(2); %replace saturation. Anything but 0 will work
            out = hsv2rgb(maphsv);
        end
    end
    
end %classdef