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
    properties(GetAccess = protected, SetAccess = protected)
        visObj = [];
        mySide = '';          
        screenshot = false; %flag
        disp_view = [];
        current_img_min = [];
        current_img_max = [];
        current_img_lbl_min = [];
        current_img_lbl_max = [];
        h_CPXLine = [];
        h_CPYLine = [];
        h_Rectangle = [];
        h_Circle = [];
        h_ETDRSGrid = [];
        h_ETDRSGridText = [];
        pixelResolution = 0;
        measurementPosition = 'OS';
    end
    properties(GetAccess = public, SetAccess = protected)
        myhfdMain = {[]};
        myhfdSupp = {[]};
        myhfdInt = {[]};
        mainExportGfx = [];
        mainExportXls = [];
        suppExport = [];
    end
    properties (Dependent = true)
        ROICoordinates = [];
        ROIType = [];
        ROISubType = [];
        ROIInvertFlag = [];
        cutXVal = 0;
        cutYVal = 0;
        cutXInv = 0;
        cutYInv = 0;
        mDispDim = [];
        mDispScale = [];
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
        h_t1 = [];
        h_t2 = [];
        h_t3 = [];
        h_t4 = [];
        h_t5 = [];
        h_io_check = [];
        h_io_edit = [];
        h_CPPosTxt = [];
        h_CPValTxt = [];
        %visualization parameters
        dynVisParams = [];
        staticVisParams = [];
    end
    
    methods
        function this = FDisplay(visObj,side)
            %Constructs a FDisplay object.
            this.visObj = visObj;
            this.mySide = side;
%             this.setUIHandles();
            this.disp_view = [-40 30];
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
        end
        
        function sethfdSupp(this,val)
            %sets FDisplays current FData handle(s)
            if(iscell(val))
                this.myhfdSupp = val;
            else
                this.myhfdSupp = {val};
            end
        end        
        
        function out = getDispView(this)
            %get current display view
            out = this.disp_view;
        end
        
        function cp = getMyCP(this)
            %get the current point of my main axes            
            hfd = this.gethfd();
            if(isempty(hfd{1}) || length(hfd) > 1 || this.mDispDim > 2)                
                cp = [];
                return
            end 
            hfd = hfd{1};
            cp = get(this.h_m_ax,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                %we are outside axes - nothing to do
                cp = [];
                return;
            end
            cp=fix(cp+0.52);
            if(this.mDispDim == 1)
                xMax = hfd.rawImgXSz(2);
                yMax = hfd.rawImgYSz(2);
            else
                rc = this.ROICoordinates;
                rt = this.ROIType;
                rs = this.ROISubType;
                ri = this.ROIInvertFlag;
                xMax = hfd.getCIxSz(rc,rt,rs,ri);
                yMax = hfd.getCIySz(rc,rt,rs,ri);
            end
            if(cp(1) >= 1 && cp(1) <= xMax && cp(2) >= 1 && cp(2) <= yMax)
            else
                cp = [];
            end            
        end
        
        function drawCP(this,cp)
            %draw current point into 2D plots
            if isMultipleCall();  return;  end
            hfd = this.gethfd();
            dim = this.mDispDim;
            if(isempty(hfd{1}) || length(hfd) > 1 || dim > 2)
                return
            end  
            hfd = hfd{1};
            cp=fix(cp+0.52);            
            if(dim == 1)
                ci = hfd.getFullImage();
            else
                rc = this.ROICoordinates;
                rt = this.ROIType;
                rs = this.ROISubType;
                ri = this.ROIInvertFlag;
                ci = hfd.getROIImage(rc,rt,rs,ri);
            end
            if(isempty(cp))
                if(ishghandle(this.h_CPYLine))
                    delete(this.h_CPYLine);
                end
                if(ishghandle(this.h_CPXLine))
                    delete(this.h_CPXLine);
                end
                set(this.h_CPPosTxt,'String','|');
                set(this.h_CPValTxt,'String','');
                return
            end
            %delete(this.h_CPLines(idx))
            if(isempty(ci))
                set(this.h_CPPosTxt,'String','  |  ');
                set(this.h_CPValTxt,'String','');
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
                set(this.h_CPPosTxt,'String',sprintf('%d | %d',xLbl(cp(1)),yLbl(cp(2))));
                set(this.h_CPValTxt,'String',FLIMXFitGUI.num4disp(ci(cp(2),cp(1))));
                if(ishghandle(this.h_CPXLine))
                    set(this.h_CPXLine,'XData',[cp(1) cp(1)],'YData',[1 y]);
                else
                    this.h_CPXLine = line('XData',[cp(1) cp(1)],'YData',[1 y],'Color','w','LineWidth',2,'LineStyle',':','Parent',this.h_m_ax);
                end
                if(ishghandle(this.h_CPYLine))
                    set(this.h_CPYLine,'XData',[1 x],'YData',[cp(2) cp(2)]);
                else
                    this.h_CPYLine =  line('XData',[1 x],'YData',[cp(2) cp(2)],'Color','w','LineWidth',2,'LineStyle',':','Parent',this.h_m_ax);
                end
            end                      
        end
        
        function drawROI(this,ROIType,op,cp,drawTextFlag)
            %draw ROI on 2D main plot; cp: current point; op: old point
            switch ROIType
                case 1
                    this.drawETDRSGrid(cp,drawTextFlag);
                case {2,3}
                    if(isempty(op))
                        return
                    end
                    this.drawRectangle(cp,op-cp,drawTextFlag);
                case {4,5}
                    if(isempty(op))
                        return
                    end
                    radius = sqrt(sum((op-cp).^2));
                    this.drawCircle(op,radius,drawTextFlag);
                case {6,7}
                    
                otherwise
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
            end                    
        end
        
        function drawRectangle(this,cp,widths,drawTextFlag)
            %draw rectangle into 2D plot
            if(isempty(widths))
                return
            end
            gc = this.staticVisParams.ROIColor;
            lw = 2;
            idx = widths < 0;
            cp(idx) = cp(idx) + widths(idx);
            widths = abs(widths);
            isHG = ishghandle(this.h_Rectangle);
            if(~isempty(isHG) && isHG)
                set(this.h_Rectangle,'Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw);
            else
                try
                    delete(this.h_Rectangle);
                end
                if(this.staticVisParams.ROI_fill_enable)
                    fc = [gc this.staticVisParams.ETDRS_subfield_bg_color(end)];
                    this.h_Rectangle = rectangle('Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc,'FaceColor',fc);
                else
                    this.h_Rectangle = rectangle('Position',[cp(2),cp(1),widths(2),widths(1)],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc);
                end
            end
            %             if(MSX)
            %                 line('XData',[MSXMin MSXMin],'YData',[MSYMin MSYMax],'Color',sVisParam.ROIColor,'LineWidth',2,'LineStyle','-','Parent',hAx);
            %
            %                 line('XData',[MSXMax MSXMax],'YData',[MSYMin MSYMax],'Color',sVisParam.ROIColor,'LineWidth',2,'LineStyle','-','Parent',hAx);
            %             end
            %             if(MSY)
            %                 line('XData',[MSXMin MSXMax],'YData',[MSYMin MSYMin],'Color',sVisParam.ROIColor,'LineWidth',2,'LineStyle','-','Parent',hAx);
            %                 line('XData',[MSXMin MSXMax],'YData',[MSYMax MSYMax],'Color',sVisParam.ROIColor,'LineWidth',2,'LineStyle','-','Parent',hAx);
            %             end
        end
        
        function drawCircle(this,cp,radius,drawTextFlag)
            %draw rectangle into 2D plot
            if(isempty(radius))
                return
            end
            gc = this.staticVisParams.ROIColor;
            lw = 2;
            isHG = ishghandle(this.h_Rectangle);
            if(~isempty(isHG) && isHG)
                set(this.h_Circle,'Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'LineWidth',lw);
            else
                try
                    delete(this.h_Circle);
                end
                if(this.staticVisParams.ROI_fill_enable)
                    fc = [gc this.staticVisParams.ETDRS_subfield_bg_color(end)];
                    this.h_Circle = rectangle('Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc,'FaceColor',fc);
                else
                    this.h_Circle = rectangle('Position',[cp(2)-radius,cp(1)-radius,2*radius,2*radius],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc);
                end
            end
        end
        
        function drawETDRSGrid(this,cp,drawTextFlag)
            %draw ETDRS grid into 2D plot
            if isMultipleCall();  return;  end            
            idxG = ishghandle(this.h_ETDRSGrid); 
            idxT = ishghandle(this.h_ETDRSGridText); 
            if(isempty(cp)) 
                delete(this.h_ETDRSGrid(idxG));
                delete(this.h_ETDRSGridText(idxT));
                return
            end
            res = this.pixelResolution;
            switch this.measurementPosition
                case 'OS'
                    pos = 1;                    
                otherwise
                    pos = 1;
            end
            gc = this.staticVisParams.ROIColor;%[1 1 1];
            if(this.staticVisParams.ROI_fill_enable)
                trans = this.staticVisParams.ETDRS_subfield_bg_color(end);
            else
                trans = 0;
            end
            if(res > 0)
                %radius ring1 = 500 µm
                d1 = 1000/res;
                d2 = 3000/res;
                d3 = 6000/res;                
                lw = 2;
                fs = this.staticVisParams.fontsize;
                if(~isempty(idxG) && all(idxG(:)))
                    %circles
                    set(this.h_ETDRSGrid(1),'Position',[cp(2)-d1/2,cp(1)-d1/2,d1,d1],'LineWidth',lw);
                    set(this.h_ETDRSGrid(2),'Position',[cp(2)-d2/2,cp(1)-d2/2,d2,d2],'LineWidth',lw);
                    set(this.h_ETDRSGrid(3),'Position',[cp(2)-d3/2,cp(1)-d3/2,d3,d3],'LineWidth',lw);
                    %lines
                    set(this.h_ETDRSGrid(4),'XData',[cp(2)+cos(pi/4)*d1/2  cp(2)+cos(pi/4)*d3/2],'YData',[cp(1)+sin(pi/4)*d1/2 cp(1)+sin(pi/4)*d3/2],'LineWidth',lw);
                    set(this.h_ETDRSGrid(5),'XData',[cp(2)+cos(3*pi/4)*d1/2  cp(2)+cos(3*pi/4)*d3/2],'YData',[cp(1)+sin(3*pi/4)*d1/2 cp(1)+sin(3*pi/4)*d3/2],'LineWidth',lw);
                    set(this.h_ETDRSGrid(6),'XData',[cp(2)+cos(-pi/4)*d1/2  cp(2)+cos(-pi/4)*d3/2],'YData',[cp(1)+sin(-pi/4)*d1/2 cp(1)+sin(-pi/4)*d3/2],'LineWidth',lw);
                    set(this.h_ETDRSGrid(7),'XData',[cp(2)+cos(-3*pi/4)*d1/2  cp(2)+cos(-3*pi/4)*d3/2],'YData',[cp(1)+sin(-3*pi/4)*d1/2 cp(1)+sin(-3*pi/4)*d3/2],'LineWidth',lw);
                else
                    try
                        delete(this.h_ETDRSGrid(idxG));
                    end
                    h = zeros(7,1);
                    
                    h(1) = rectangle('Position',[cp(2)-d1/2,cp(1)-d1/2,d1,d1],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc);
                    h(2) = rectangle('Position',[cp(2)-d2/2,cp(1)-d2/2,d2,d2],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc);
                    if(this.staticVisParams.ROI_fill_enable)
                        fc = [gc this.staticVisParams.ETDRS_subfield_bg_color(end)];
                        h(3) = rectangle('Position',[cp(2)-d3/2,cp(1)-d3/2,d3,d3],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc,'FaceColor',fc);
                    else
                        h(3) = rectangle('Position',[cp(2)-d3/2,cp(1)-d3/2,d3,d3],'Curvature',[1 1],'LineWidth',lw,'Parent',this.h_m_ax,'EdgeColor',gc);
                    end
                    %lines
                    h(4) = line('XData',[cp(2)+cos(pi/4)*d1/2  cp(2)+cos(pi/4)*d3/2],'YData',[cp(1)+sin(pi/4)*d1/2 cp(1)+sin(pi/4)*d3/2],'LineWidth',lw,'Parent',this.h_m_ax,'Color',gc);
                    h(5) = line('XData',[cp(2)+cos(3*pi/4)*d1/2  cp(2)+cos(3*pi/4)*d3/2],'YData',[cp(1)+sin(3*pi/4)*d1/2 cp(1)+sin(3*pi/4)*d3/2],'LineWidth',lw,'Parent',this.h_m_ax,'Color',gc);
                    h(6) = line('XData',[cp(2)+cos(-pi/4)*d1/2  cp(2)+cos(-pi/4)*d3/2],'YData',[cp(1)+sin(-pi/4)*d1/2 cp(1)+sin(-pi/4)*d3/2],'LineWidth',lw,'Parent',this.h_m_ax,'Color',gc);
                    h(7) = line('XData',[cp(2)+cos(-3*pi/4)*d1/2  cp(2)+cos(-3*pi/4)*d3/2],'YData',[cp(1)+sin(-3*pi/4)*d1/2 cp(1)+sin(-3*pi/4)*d3/2],'LineWidth',lw,'Parent',this.h_m_ax,'Color',gc);
                    this.h_ETDRSGrid = h;
                end
                %text in subfields
                if(~drawTextFlag)
                    delete(this.h_ETDRSGridText(idxT));
                    return
                end
                [hfd, ~] = this.gethfd();
                if(isempty(hfd{1}))
                    return
                end
                hfd = hfd{1};
                txt = repmat({''},9,1);
                bgc = [0 0 0 0];
                if(~strcmp(this.staticVisParams.ETDRS_subfield_values,'none'))
                    if(strcmp(this.staticVisParams.ETDRS_subfield_values,'field name'))
                        txt = {'C','IN','IS','II','IT','OS','ON','OI','OT'};
                    else
                        tmp = hfd.getROISubfieldStatistics(2,this.staticVisParams.ETDRS_subfield_values);                        
                        txt = arrayfun(@FLIMXFitGUI.num4disp,tmp,'UniformOutput',false);%FLIMXFitGUI.num4disp(tmp(i));
                    end
                    if(this.staticVisParams.ETDRS_subfield_bg_enable)
                        bgc = this.staticVisParams.ETDRS_subfield_bg_color;%[0.3 0.3 0.3 0.33];
                    end
                end
                if(~isempty(idxT) && all(idxT(:)))
                    set(this.h_ETDRSGridText(1),'Position',[cp(2),cp(1)],'String',txt{1});
                    set(this.h_ETDRSGridText(2),'Position',[cp(2),cp(1)+d1/2+(d2-d1)/4,cp(1)],'String',txt{2});
                    set(this.h_ETDRSGridText(3),'Position',[cp(2)-pos*(d1/2+(d2-d1)/4),cp(1)],'String',txt{3});
                    set(this.h_ETDRSGridText(4),'Position',[cp(2),cp(1)-d1/2-(d2-d1)/4,cp(1)],'String',txt{4});
                    set(this.h_ETDRSGridText(5),'Position',[cp(2)+pos*(d1/2+(d2-d1)/4),cp(1)],'String',txt{5});                    
                    set(this.h_ETDRSGridText(6),'Position',[cp(2),cp(1)+d2/2+(d3-d2)/4,cp(1)],'String',txt{6});
                    set(this.h_ETDRSGridText(9),'Position',[cp(2)-pos*(d2/2+(d3-d2)/4),cp(1)],'String',txt{7});
                    set(this.h_ETDRSGridText(7),'Position',[cp(2),cp(1)-d2/2-(d3-d2)/4,cp(1)],'String',txt{8});
                    set(this.h_ETDRSGridText(8),'Position',[cp(2)+pos*(d2/2+(d3-d2)/4),cp(1)],'String',txt{9});                    
                else
                    delete(this.h_ETDRSGridText(idxT));
                    h = zeros(9,1);
                    h(1) = text(cp(2),cp(1),txt{1},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(2) = text(cp(2),cp(1)+d1/2+(d2-d1)/4,txt{2},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(3) = text(cp(2)-pos*(d1/2+(d2-d1)/4),cp(1),txt{3},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(4) = text(cp(2),cp(1)-d1/2-(d2-d1)/4,txt{4},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(5) = text(cp(2)+pos*(d1/2+(d2-d1)/4),cp(1),txt{5},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(6) = text(cp(2),cp(1)+d2/2+(d3-d2)/4,txt{6},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(7) = text(cp(2)-pos*(d2/2+(d3-d2)/4),cp(1),txt{7},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(8) = text(cp(2),cp(1)-d2/2-(d3-d2)/4,txt{8},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    h(9) = text(cp(2)+pos*(d2/2+(d3-d2)/4),cp(1),txt{9},'Color',gc,'BackgroundColor',bgc,'Fontsize',fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','Parent',this.h_m_ax);
                    this.h_ETDRSGridText = h;
                end
            end
        end
                
        function [hfd, hfdInt, hfdSupp] = gethfd(this)
            %
            hfd = this.myhfdMain;           
            hfdInt = this.myhfdInt;
            hfdSupp = this.myhfdSupp;
            if(~isempty(hfd{1}) && ~isempty(hfdInt) && ~isempty(hfdSupp{1}))            
                return
            end
            %get handle to intensity image
            hfdInt = this.visObj.fdt.getFDataObj(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),this.visObj.getChannel(this.mySide),'Intensity',0,1);
            %hfd = {[]};
            %no old FData handle, read GUI settings and get new one
            scale = get(this.h_m_psc,'Value');
            %get 'variation mode': 1:uini 2: multi 3: cluster
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
                    hfd{1} = this.visObj.fdt.getStudyObjMerged(this.visObj.getStudy(this.mySide),this.visObj.getView(this.mySide),this.visObj.getChannel(this.mySide),clusterID,dTypeNr(1),scale);
                case 4 %global clusters
                    clusterID = sprintf('Global%s',dType{1});
                    hfd{1} = this.visObj.fdt.getGlobalClusterObj(this.visObj.getChannel(this.mySide),clusterID,scale);
            end            
            %save new hfd(s)            
            this.myhfdMain = hfd;
            this.myhfdInt = hfdInt;
            if(this.sDispMode == 2)
                %histogram
                switch get(this.h_s_hist,'Value')
                    case 1 %single histogram
                        this.myhfdSupp = hfd;
                    case 2 %study view histogram
                        if(~(dTypeNr == 0))
                            this.myhfdSupp{1} = this.visObj.fdt.getStudyObjMerged(this.visObj.getStudy(this.mySide),...
                                this.visObj.getView(this.mySide),this.visObj.getChannel(this.mySide),dType{1},dTypeNr,1);
                        else
                            this.myhfdSupp = {[]};
                        end
                    case 3 %global histogram
                        if(~isnan(dTypeNr))
                            this.myhfdSupp{1} = this.visObj.fdt.getGlobalObjMerged(this.visObj.getChannel(this.mySide),dType{1},dTypeNr);
                        else
                            this.myhfdSupp = hfd;
                        end
                end
            else
                %cuts                    
                this.myhfdSupp = hfd;
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
            %update main and cuts axes
            %tic;                                    
            this.UpdateMinMaxLbl();
            this.makeMainPlot();
            this.makeMainXYLabels();
            this.makeSuppPlot();
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
            ri = this.ROIInvertFlag;
            this.current_img_min = hfd{1}.getCImin(rc,rt,rs,ri);
            if(isnan(this.current_img_min))
                this.current_img_min = 0;
            end
            this.current_img_max = hfd{1}.getCImax(rc,rt,rs,ri);
            if(isnan(this.current_img_max))
                this.current_img_max = this.current_img_min+eps(this.current_img_min);
            end  
            this.current_img_lbl_min = hfd{1}.getCIminLbl(rc,rt,rs,ri);
            if(isnan(this.current_img_lbl_min))
                this.current_img_lbl_min = 0;
            end            
            this.current_img_lbl_max = max(hfd{1}.getCImaxLbl(rc,rt,rs,ri),this.current_img_lbl_min+1);
            if(length(hfd) > 1)
                for i = 2:length(hfd)
                    this.current_img_min = min(this.current_img_min,hfd{i}.getCImin(rc,rt,rs,ri));
                    this.current_img_max = max(this.current_img_max,hfd{i}.getCImax(rc,rt,rs,ri));
                    this.current_img_lbl_min = min(this.current_img_lbl_min,hfd{i}.getCIminLbl(rc,rt,rs,ri));
                    this.current_img_lbl_max = max(this.current_img_lbl_max,hfd{i}.getCImaxLbl(rc,rt,rs,ri));
                end
            end
        end
        
        function makeMainPlot(this)
            %make current main plot
            [hfd, hfdInt] = this.gethfd();
            hAx = this.h_m_ax;
            if(isempty(hfd{1}))
                cla(hAx);
                axis(hAx,'off');
                return
            end
            dispDim = this.mDispDim;
            sVisParam = this.staticVisParams;
            if(~this.screenshot)
                set(hAx,'Fontsize',sVisParam.fontsize);
            end
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
            ri = this.ROIInvertFlag;
            for i = 1:nrFD
                %get image data to display
                if(dispDim == 1)
                    %TOP view
                    current_img = hfd{i}.getFullImage();
                else
                    %ROI in 2D / 3D
                    current_img = hfd{i}.getROIImage(rc,rt,rs,ri);
                end
                if(isempty(current_img))
                    return
                end
                %z scaling
                if(hfd{i}.MSZ)
                    [~, MSZMin, MSZMax ] = hfd{i}.getMSZ();
                    zMin(i) = MSZMin;
                    if(isinf(zMin))
                        zMin(i) = hfd{i}.getCImin();
                    end
                    zMax(i) = MSZMax;
                    if(dispDim == 1)
                        %do z scaling here
                        current_img(current_img < zMin(i)) = zMin(i);
                        current_img(current_img > zMax(i)) = zMax(i);
                    end
                else
                    if(dispDim == 1)
                        zMax(i) = max(current_img(:));
                        zMin(i) = min(current_img(:));                        
                    else
                        zMax(i) = hfd{i}.getCImax(rc,rt,rs,ri);
                        zMin(i) = hfd{i}.getCImin(rc,rt,rs,ri);
                    end
                end    
                if((zMax - zMin) < 0.1)
                    zMax = zMax + 0.1;
                end
                %color mapping                
                if(dispDim == 1 || isempty(hfd{i}.getCIColor(rc,rt,rs,ri)))
                    colors = current_img - zMin(i);
                    if(strcmp(hfd{i}.dType,'Intensity'))
                        cm = this.dynVisParams.cmIntensity;
                    else
                        cm = this.dynVisParams.cm;
                    end
                    colors = colors/(zMax(i)-zMin(i))*(size(cm,1)-1)+1; %mapping for colorbar
                    colors(isnan(colors)) = 1;
                    if(strncmp(hfd{i}.dType,'MVGroup',7)  || strncmp(hfd{i}.dType,'ConditionMVGroup',16))
                        cm = repmat([0:1/(size(cm,1)-1):1]',1,3);
                        color = this.visObj.fdt.getViewColor(this.visObj.getStudy(this.mySide),this.visObj.getView(this.mySide));
                        cm = [cm(:,1).*color(1) cm(:,2).*color(2) cm(:,3).*color(3)];
                        colors = cm(round(reshape(colors,[],1)),:);
                        alphaData = ceil(sum(colors,2));
                        colors = reshape(colors,[size(current_img) 3]);
                        alphaData = reshape(alphaData,size(current_img));
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
                    end                    
                else
                    %we have precomputed colors
                    colors = hfd{i}.getCIColor(rc,rt,rs,ri);
                    alphaData = ceil(sum(colors,3));
                end
                %intensity overlay
                if(this.intOver)
                    %merge with intensity image
                    if(dispDim == 1)
                        colors = this.makeIntOverlay(colors,hfdInt.getFullImage());
                    else
                        colors = this.makeIntOverlay(colors,hfdInt.getROIImage(rc,rt,rs,ri));
                    end
                end
                %save image for possible export
                if(nrFD == 1)
                    this.mainExportXls = current_img;
                end
                switch dispDim                      
                    case {1,2} %2D plot
                        %plot the image
                        image(colors,'Parent',hAx);
                        caxis(hAx,[zMin(end) zMax(end)]);
                        set(hAx,'YDir','normal','XLim',[1 size(current_img,2)],'YLim',[1 size(current_img,1)]);
                        %draw cuts
                        tmp = hfd{i}.getCutXVal(dispDim-1,true,rc,rt,rs,ri);
                        if(hfd{i}.getCutX() && tmp ~= 0)
                            line('XData',[tmp tmp],'YData',[1 size(current_img,1)],'LineWidth',1,'Linestyle','--','Color',sVisParam.cutXColor,'Parent',hAx);
                        end
                        tmp = hfd{i}.getCutYVal(dispDim-1,true,rc,rt,rs,ri);
                        if(hfd{i}.getCutY() && tmp ~= 0)
                            line('XData',[1 size(current_img,2)], 'YData',[tmp tmp],'LineWidth',1,'Linestyle','--','Color',sVisParam.cutYColor,'Parent',hAx);
                        end
                        %draw ROI if TOP view
                        if(dispDim == 1)
                            %check roi
%                             h = hfd{i};
                            ROIType = this.ROIType;
                            if(ROIType >= 1)
                                ROICoord = this.ROICoordinates;
                                this.drawROI(ROIType,ROICoord(:,1),ROICoord(:,2),false);
                            end
                        end
                        if(~this.screenshot)
                            setAllowAxesRotate(this.visObj.visHandles.hrotate3d,hAx,false);
                        end
                        %save for export
                        %this.mainExportGfx = current_img;
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
                        %% cuts
                        cutsWidth = 2;
                        if(sVisParam.padd) %padd with zeros (-inf)
                            if(hfd{i}.getCutX() && hfd{i}.getCutXVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCutXInv())
                                    current_img(:,hfd{i}.getCutXVal(true,true,rc,rt,rs,ri)+1:end) = -inf;
                                else
                                    current_img(:,1:hfd{i}.getCutXVal(true,true,rc,rt,rs,ri)-1) = -inf;
                                end
                                if(sVisParam.color_cuts)
                                    tmp = hfd{i}.getCutXVal(true,true,rc,rt,rs,ri);
                                    colors(:,tmp:tmp+cutsWidth-1,:) = reshape(repmat(sVisParam.cutXColor,size(colors,1),cutsWidth),[size(colors,1) cutsWidth 3]);
                                end
                            end
                            if(hfd{1}.getCutY() && hfd{1}.getCutYVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{1}.getCutYInv())
                                    current_img(hfd{1}.getCutYVal(true,true,rc,rt,rs,ri)+1:end,:) = -inf;
                                else
                                    current_img(1:hfd{1}.getCutYVal(true,true,rc,rt,rs,ri)-1,:) = -inf;%m.sVisParam.zlim_min;
                                end
                                if(sVisParam.color_cuts)
                                    tmp = hfd{1}.getCutYVal(true,true,rc,rt,rs,ri);
                                    colors(tmp:tmp+cutsWidth-1,:,:) = reshape(repmat(sVisParam.cutYColor,size(colors,2),cutsWidth),[cutsWidth size(colors,2) 3]);
                                end
                            end
                        elseif(~sVisParam.padd)%no padding
                            if(hfd{i}.getCutX() && hfd{i}.getCutXVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCutXInv())
                                    current_img = current_img(:,1:hfd{i}.getCutXVal(true,true,rc,rt,rs,ri));
                                    alphaData = alphaData(:,1:hfd{i}.getCutXVal(true,true,rc,rt,rs,ri));
                                    colors = colors(:,1:hfd{i}.getCutXVal(true,true,rc,rt,rs,ri),:);
                                    if(sVisParam.color_cuts)
                                        colors(:,end-cutsWidth+1:end,:) = reshape(repmat(sVisParam.cutXColor,size(colors,1),cutsWidth),[size(colors,1) cutsWidth 3]);
                                    end
                                else
                                    current_img = current_img(:,hfd{i}.getCutXVal(true,true,rc,rt,rs,ri):end);
                                    alphaData = alphaData(:,hfd{i}.getCutXVal(true,true,rc,rt,rs,ri):end);
                                    colors = colors(:,hfd{i}.getCutXVal(true,true,rc,rt,rs,ri):end,:);
                                    if(sVisParam.color_cuts)
                                        colors(:,1:cutsWidth,:) = reshape(repmat(sVisParam.cutXColor,size(colors,1),cutsWidth),[size(colors,1) cutsWidth 3]);
                                    end
                                end                                
                            end
                            if(hfd{i}.getCutY() && hfd{i}.getCutYVal(true,true,rc,rt,rs,ri) ~= 0)
                                if(hfd{i}.getCutYInv())
                                    current_img = current_img(1:hfd{i}.getCutYVal(true,true,rc,rt,rs,ri),:);
                                    alphaData = alphaData(1:hfd{i}.getCutYVal(true,true,rc,rt,rs,ri),:);
                                    colors = colors(1:hfd{i}.getCutYVal(true,true,rc,rt,rs,ri),:,:);
                                    if(sVisParam.color_cuts)
                                        colors(end-cutsWidth+1:end,:,:) = reshape(repmat(sVisParam.cutYColor,size(colors,2),cutsWidth),[cutsWidth size(colors,2) 3]);
                                    end
                                else
                                    current_img = current_img(hfd{i}.getCutYVal(true,true,rc,rt,rs,ri):end,:);
                                    alphaData = alphaData(hfd{i}.getCutYVal(true,true,rc,rt,rs,ri):end,:);
                                    colors = colors(hfd{i}.getCutYVal(true,true,rc,rt,rs,ri):end,:,:);
                                    if(sVisParam.color_cuts)
                                        colors(1:cutsWidth,:,:) = reshape(repmat(sVisParam.cutYColor,size(colors,2),cutsWidth),[cutsWidth size(colors,2) 3]);
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
                        caxis(hAx,[min(current_img(:)) max(current_img(:))]);
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
                        if(~this.screenshot)
                            setAllowAxesRotate(this.visObj.visHandles.hrotate3d,hAx,true);
                        end
                        if(nrFD > 1)
                            hold(hAx,'on');
                        end
                end
                clear current_img
            end
            shading(hAx,sVisParam.shading);
            if(nrFD > 1)
                hold(hAx,'off');
            end
        end %makeMainPlot
          
        function makeMainXYLabels(this)
            %axis labes
            hfd = this.gethfd();
            if(isempty(hfd{1}))
                cla(this.h_m_ax);
                axis(this.h_m_ax,'off');
                return
            end
            if(~this.screenshot)
                set(this.h_m_ax,'Fontsize',this.staticVisParams.fontsize);
            end
            if(this.mDispDim == 1) %2Do
                xlbl = hfd{1}.getRIXLbl();
                ylbl = hfd{1}.getRIYLbl();
            else %2D, 3D
                rc = this.ROICoordinates;
                rt = this.ROIType;
                rs = this.ROISubType;
                ri = this.ROIInvertFlag;
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
          
        function makeSuppPlot(this)
            %make current supplemental plot                        
            hfd = this.myhfdSupp;
            if(isempty(hfd{1}))
                cla(this.h_s_ax);
                axis(this.h_s_ax,'off');                
                set(this.h_s_p,'Value',1);  
                set(this.h_s_hist,'Visible','off'); 
                return
            end            
            nrFD = length(hfd);            
            this.suppExport = []; 
            if(~this.screenshot)
                set(this.h_s_ax,'Fontsize',this.staticVisParams.fontsize);
            end
            rc = this.ROICoordinates;
            rt = this.ROIType;
            rs = this.ROISubType;
            ri = this.ROIInvertFlag;
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
                                    this.visObj.getStudy(this.mySide),this.visObj.getView(this.mySide),...
                                    this.visObj.getChannel(this.mySide),dType{1},dTypeNr(1));
                            case 3 %global histogram
                                list = get(this.h_m_p,'String');
                                typeSel = get(this.h_m_p,'Value');
                                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(char(list(typeSel,:)));                               
                                [centers, histo] = this.visObj.fdt.getGlobalHistogram(...
                                    this.visObj.getChannel(this.mySide),dType{1},dTypeNr(1));
                        end
                        if(isempty(centers))
                            cla(this.h_s_ax);
                            axis(this.h_s_ax,'off');
                            return
                        end
                        this.suppExport = [centers' histo'];
                        bar(this.h_s_ax,histo,'hist');
                        if(this.staticVisParams.grid)
                            grid(this.h_s_ax,'on');
                        else
                            grid(this.h_s_ax,'off');
                        end
                        if(length(histo) > 1)
                            xlim(this.h_s_ax,size(histo));
                        end
                        xtick = get(this.h_s_ax,'XTick');
                        if(xtick(1) == 0)
                            xtick = xtick+1;
                        end
                        set(this.h_s_ax,'color',this.staticVisParams.supp_plot_bg_color,...
                            'XTickLabel',num2str(centers(xtick)','%.1f'));
                        if(~this.screenshot)
                            setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_s_ax,false);
                        end
                    else %nothing to do
                        cla(this.h_s_ax);
                        axis(this.h_s_ax,'off');
                    end
                    
                case {3, 4} %3:horizontal cut, 4: vertical cut
                    if( (this.sDispMode == 4 && hfd{1}.getCutX() && hfd{1}.getCutXVal(true,true,rc,rt,rs,ri) ~= 0 ) ||...
                            (this.sDispMode == 3 && hfd{1}.getCutY() && hfd{1}.getCutYVal(true,true,rc,rt,rs,ri) ~= 0 ))
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
                                if(hfd{i}.MSZ)
                                    [~, MSZMin, MSZMax ] = hfd{i}.getMSZ();
                                    if(MSZMin ~= -inf)
                                        zMin(i) = MSZMin;
                                    end
                                    zMax(i) = MSZMax;
                                end
                            else
                                %get data from object with the appropriate data format
                                switch this.sDispScale
                                    case 2
                                        hfdT = hfd{i}.getLogData();
                                    case 3
                                        hfdT = hfd{i}.getPerData();
                                    otherwise %linear data
                                        hfdT = hfd{i}.getLinData();
                                end
                                current_img = hfdT.getROIImage(rc,rt,rs,ri);
                                zMin(i) = hfdT.getCImin();
                                zMax(i) = hfdT.getCImax();
                                %z scaling
                                if(hfdT.MSZ)
                                    [~, MSZMin, MSZMax ] = hfdT.getMSZ();
                                    if(MSZMin ~= -inf)
                                        zMin(i) = MSZMin;
                                    end
                                    zMax(i) = MSZMax;
                                end
                            end
                            
                            if(this.staticVisParams.offset_m3d && nrFD > 1)
                                %get offset
                                pos = get(this.h_s_ax,'Position');
                                max_amp = pos(4)/nrFD;
                            end
                            %cuts
                            if(this.sDispMode == 3) %horizontal cut
                                current_img = current_img(min(hfd{1}.getCutYVal(true,true,rc,rt,rs,ri),size(current_img,1)),:);
                                this.suppExport(i,:) = current_img;
                            else %vertical cut
                                current_img = current_img(:,min(hfd{1}.getCutXVal(true,true,rc,rt,rs,ri),size(current_img,2)));
                                this.suppExport(i,:) = current_img;
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
                            if(~this.screenshot)
                                setAllowAxesRotate(this.visObj.visHandles.hrotate3d,this.h_s_ax,false);
                            end
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
                        if(this.sDispMode == 3 && hfd{1}.getCutX() && hfd{1}.getCutXVal(true,true,rc,rt,rs,ri) ~= 0 && this.staticVisParams.show_cut)
                            %horizontal cut
                            line('XData',[hfd{1}.getCutXVal(true,true,rc,rt,rs,ri) hfd{1}.getCutXVal(true,true,rc,rt,rs,ri)],...
                                'YData',ylim, ...
                                'LineWidth',1,'Linestyle','--','Color',this.staticVisParams.cutXColor,'Parent',this.h_s_ax);
                        end
                        if(this.sDispMode == 4 && hfd{1}.getCutY() && hfd{1}.getCutYVal(true,true,rc,rt,rs,ri) ~= 0 && this.staticVisParams.show_cut)
                            %vertical cut
                            line('XData',[hfd{1}.getCutYVal(true,true,rc,rt,rs,ri) hfd{1}.getCutYVal(true,true,rc,rt,rs,ri)],...
                                'YData',ylim, ...
                                'LineWidth',1,'Linestyle','--','Color',this.staticVisParams.cutYColor,'Parent',this.h_s_ax);
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
        end %makeSuppPlot
        
        function makeDSTable(this)
            %fill descripte statistics table
            [~, ~, hfd] = this.gethfd();    %update hfd(s)           
            if(isempty(hfd{1}) || length(hfd) > 1)
                set(this.h_ds_t,'Data',cell(0,0));
            else
                data(:,1) = hfd{1}.getDescriptiveStatisticsDescriptionShort();
                tmp = hfd{1}.getROIStatistics(this.ROICoordinates,this.ROIType,this.ROISubType,this.ROIInvertFlag);
                data(:,2) = arrayfun(@FLIMXFitGUI.num4disp,tmp,'UniformOutput',false);%{num2str(tmp(i),'%.3G')};
                %remove not needed parameters
                %data([4,8,9],:) = [];              
                set(this.h_ds_t,'Data',data);
            end
        end
        
        function updateColorBarLbls(this)
            %update the labels of the colorbar
            tickLbls = this.makeColorBarLbls(5);
            for i=1:5
                set(this.(sprintf('h_t%s',num2str(i))),'String',tickLbls{i});%,'Fontsize',this.staticVisParams.fontsize);
                
            end
        end
        
        function out = makeColorBarLbls(this,nTicks)
            %make nTicks labels for the color bar
            nTicks = max(2,nTicks); %at least 2 labels
            out = cell(nTicks,1);
            if(this.mDispDim == 1)
                hfd = this.gethfd();
                if(isempty(hfd{1}))
                    return
                end
                if(isempty(hfd{1}.rawImgZSz))
                    img_min = 0;
                    img_max = 0;
                else
                    if(hfd{1}.MSZ)
                        [~, img_min, img_max ] = hfd{1}.getMSZ();
                    else
                        img_min = hfd{1}.rawImgZSz(1);
                        img_max = hfd{1}.rawImgZSz(2);
                    end
                end
            else
                img_min = this.current_img_lbl_min;
                img_max = this.current_img_lbl_max;
            end
            if(isempty(img_min))
                return
            end            
            if(isempty(img_max))
                return
            end
            %range = img_max - img_min;            
            vec = linspace(img_min,img_max,nTicks);
            out(:,1) = arrayfun(@FLIMXFitGUI.num4disp,vec,'UniformOutput',false);
        end
        
        function colorImg = makeIntOverlay(this,colorImg,intImg)
            %
            intImg = double(intImg);
            if(size(intImg,1) == size(colorImg,1) && size(intImg,2) == size(colorImg,2))
                brightness = this.intOverBright;
                %contrast = 1;
                intImg = histeq(intImg./max(intImg(:)));
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
        
        function out = get.ROIInvertFlag(this)
            %
            out = this.visObj.getROIInvertFlag(this.mySide);
        end
        
        function out = get.cutXVal(this)
            %
            if(this.visObj.fdt.getCutX(this.myDS))
                out = this.visObj.fdt.getCutXVal(this.myDS,true);
            else
                out = 0;
            end
        end
        
        function out = get.cutYVal(this)
            %
            if(this.visObj.fdt.getCutY(this.myDS))
                out = this.visObj.fdt.getCutYVal(this.myDS,true);
            else
                out = 0;
            end
        end
        
        function out = get.cutXInv(this)
            %
            out = this.visObj.fdt.getCutXInv(this.myDS);
        end
        
        function out = get.cutYInv(this)
            %
            out = this.visObj.fdt.getCutYInv(this.myDS);
        end
        
        function out = get.mDispDim(this)
            %
            out = get(this.h_m_pdim,'Value');
        end
        
        function out = get.mDispScale(this)
            %
            out = get(this.h_m_psc,'Value');
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
            out = this.visObj.visHandles.(sprintf('dataset_%s_pop',this.mySide));
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
            out = this.visObj.visHandles.(sprintf('main_axes_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pvar(this)
            %
            out = this.visObj.visHandles.(sprintf('main_axes_var_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pdim(this)
            %
            out = this.visObj.visHandles.(sprintf('main_axes_pdim_%s_pop',this.mySide));
        end
        
        function out = get.h_m_pch(this)
            %
            out = this.visObj.visHandles.(sprintf('main_axes_chan_%s_pop',this.mySide));
        end
        
        function out = get.h_m_psc(this)
            %
            out = this.visObj.visHandles.(sprintf('main_axes_scale_%s_pop',this.mySide));
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
        
        function out = get.h_CPPosTxt(this)
            %
            out = this.visObj.visHandles.(sprintf('cp_%s_pos_text',this.mySide));
        end
        
        function out = get.h_CPValTxt(this)
            %
            out = this.visObj.visHandles.(sprintf('cp_%s_val_text',this.mySide));
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
        function setUIHandles(this)
            %builds the uicontrol handles for the FDisplay object
%             s = this.mySide;
            %axes
%             this.h_m_ax = this.visObj.visHandles.(sprintf('main_%s_axes',s));
%             this.h_s_ax = this.visObj.visHandles.(sprintf('supp_%s_axes',s));
            %controls
%             this.h_pd = this.visObj.visHandles.(sprintf('dataset_%s_pop',s));
            %main axes
%             this.h_m_p = this.visObj.visHandles.(sprintf('main_axes_%s_pop',s));
%             this.h_m_pvar = this.visObj.visHandles.(sprintf('main_axes_var_%s_pop',s));
%             this.h_m_pdim = this.visObj.visHandles.(sprintf('main_axes_pdim_%s_pop',s));
%             this.h_m_pch = this.visObj.visHandles.(sprintf('main_axes_chan_%s_pop',s));
%             this.h_m_psc = this.visObj.visHandles.(sprintf('main_axes_scale_%s_pop',s));
            %supp axes
%             this.h_s_p = this.visObj.visHandles.(sprintf('supp_axes_%s_pop',s));
%             this.h_s_hist = this.visObj.visHandles.(sprintf('supp_axes_hist_%s_pop',s));
%             this.h_s_psc = this.visObj.visHandles.(sprintf('supp_axes_scale_%s_pop',s));
            %descripte statistics table
%             this.h_ds_t = this.visObj.visHandles.(sprintf('descStats_%s_table',s));
            %intensity overlay
%             this.h_io_check = this.visObj.visHandles.(sprintf('IO_%s_check',s));
%             this.h_io_edit = this.visObj.visHandles.(sprintf('IO_%s_edit',s));
            
            %colorbar text
%             this.h_t1 = this.visObj.visHandles.(sprintf('cm_1_%s_text',s));
%             this.h_t2 = this.visObj.visHandles.(sprintf('cm_2_%s_text',s));
%             this.h_t3 = this.visObj.visHandles.(sprintf('cm_3_%s_text',s));
%             this.h_t4 = this.visObj.visHandles.(sprintf('cm_4_%s_text',s));
%             this.h_t5 = this.visObj.visHandles.(sprintf('cm_5_%s_text',s));
            
            %current point text
%             this.h_CPPosTxt = this.visObj.visHandles.(sprintf('cp_%s_pos_text',s));
%             this.h_CPValTxt = this.visObj.visHandles.(sprintf('cp_%s_val_text',s));
        end
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
            ticklbl = cell(1,length(tick));
            for i = 1:length(tick)
                ticklbl{1,i}=FLIMXFitGUI.num4disp(tick(i));
            end
            
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
                ticklbl(end+1) = {FLIMXFitGUI.num4disp(tick(3)+i*10^(log_max-1))};
                i=i+5;
            end
            idx = tick >= color_min & tick <= color_max;
            tick = tick(idx);
            ticklbl = ticklbl(idx);
            if((tick(1) - color_min) > eps)%old 0.001%drecksverschissener mistverwichster hack weil if((tick(1) > color_min) nicht richtig funktioniert
                tick = [color_min tick];
                ticklbl(2:end+1) = ticklbl;
                ticklbl(1) = {FLIMXFitGUI.num4disp(color_min)};
            else
                
            end
            if((color_max - tick(end)) > eps)
                tick(end+1) = color_max;
                ticklbl(end+1) = {FLIMXFitGUI.num4disp(color_max)};
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
                %ticklbl(1) = {FLIMXFitGUI.num4disp(tick(1))};
                ticklbl(10) = {FLIMXFitGUI.num4disp(tick(end))};
            else
                for i=log_min:log_max
                    tick = [tick tick_0.*10^i];
                    ticklbl(length(ticklbl)+9)={FLIMXFitGUI.num4disp(10^i)};
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
                ticklbl(1) = {FLIMXFitGUI.num4disp(lin_min)};
            else
                ticklbl(1) = {FLIMXFitGUI.num4disp(tick(1))};
            end
            if((lin_max - tick(end)) > max(eps,(lin_max-lin_min)*0.001))
                tick(end+1) = lin_max;
                ticklbl(end+1) = {FLIMXFitGUI.num4disp(lin_max)};
            else
                ticklbl(end) = {FLIMXFitGUI.num4disp(tick(end))};
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
    end
    
end %classdef