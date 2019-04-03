classdef axesWithROI < handle
    %=============================================================================================================
    %
    % @file     axesWithROI.m
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
    % @brief    A class to paint a 2D axes with an ROI and a point
    %
    properties(GetAccess = protected, SetAccess = protected)
        myMainAxes = [];
        myCBAxes = [];
        myCBLblLow = -1;
        myCBLblHigh = -1;
        myCPLbl = -1;
        
        myData = [];
        myCM = [];
        
        myCMPercentileLB = 0;
        myCMPercentileUB = 1;
        myROIRectangle = -1;
        
        ROILineColor = 'w';
        ROILineWidth = 2;
        ROILineStyle = '-';
        
        CPXLine = -1; %current point x line
        CPYLine = -1; %current point y line    
        
        shortNumbers = true;
        reverseYDir = false;
    end
    properties (Dependent = true)
    end
    
    methods
        function this = axesWithROI(hMainAx,hCBAx,hCBLblLow,hCBLblHigh,hCPLbl,cm)
            %Constructs an axesWithROI object
            this.myMainAxes = hMainAx;
            this.myCBAxes = hCBAx;
            this.myCBLblLow = hCBLblLow;
            this.myCBLblHigh = hCBLblHigh;
            this.myCPLbl = hCPLbl;
            this.setColorMap(cm);
        end
        
        function clear(this)
            %clear all data
            if(ishandle(this.myMainAxes))
                cla(this.myMainAxes);
            end
            if(ishandle(this.myCBAxes))
                cla(this.myCBAxes);
            end
            %delete old ROI and current point lines
            if(ishandle(this.myROIRectangle))
                delete(this.myROIRectangle);
                this.myROIRectangle = -1;
            end
            if(ishandle(this.CPXLine))
                delete(this.CPXLine);
                this.CPXLine = -1;
            end
            if(ishandle(this.CPYLine))
                delete(this.CPYLine);
                this.CPYLine = -1;
            end            
            %update colorbar labels
            if(ishandle(this.myCBLblLow))                  
                this.myCBLblLow.String = '';
            end
            if(ishandle(this.myCBLblHigh))
                this.myCBLblHigh.String = '';
            end
            if(ishandle(this.myCPLbl))
                this.myCPLbl.String = '';
            end
            this.myData = [];
            this.myCMPercentileLB = 0;
            this.myCMPercentileUB = 1;            
        end
        
        function setShortNumberFlag(this,flag)
            %toggle display of numbers
            this.shortNumbers = logical(flag);
        end
        
        function setReverseYDirFlag(this,flag)
            %toggle display direction of y axis
            this.reverseYDir = logical(flag);
        end
        
        function setMainAxes(this,hAx)
            %set handle to main axes
            this.myMainAxes = hAx;
            reset(hAx);
            this.drawMain();
        end
        
        function setMainData(this,data,lb,ub)
            %set the data for the main plot
            this.myData = data;
            if(nargin == 4 && ~isempty(lb) && ~isempty(ub))
                this.drawMain(lb,ub);
            else
                this.drawMain();
            end
        end
        
        function setColorMap(this,data)
            %set a new colormap
            if(size(data,2) == 3)
                this.myCM = data;
                this.drawColorBar();
            end
        end
        
        function setColorMapPercentiles(this,lb,ub)
            %set default percentiles for color mapping, lower bound (lb) and upper bound (ub) must be between 0 and 100
            if(~isnan(lb) && ~isnan(ub) && lb < ub && ub-lb >= 1 && lb >= 0 && ub <= 100)
                this.myCMPercentileLB = lb;
                this.myCMPercentileUB = ub;
            end
        end
        
        function setROILineColor(this,val)
            %set color of ROI lines
            if(ischar(val) && any(strncmp(val,{'y','m','c','r','g','b','w','k'},1)) || isnumeric(val) && length(val) == 3)
                this.ROILineColor = val;
            end
        end
        
        function setROILineWidth(this,val)
            %set width of ROI lines
            if(isnumeric(val) && length(val) == 1)
                this.ROILineWidth = val;
            end
        end
        
        function setROILineStyle(this,val)
            %set style of ROI lines
            if(ischar(val) && any(strncmp(val,{'-','--',':','_.','none'},1)))
                this.ROILineStyle = val;
            end
        end
        %% output methods
        function out = getMyData(this)
            %return the data used to draw the axes
            out = this.myData;
        end
        
        %% drawing methods
        function drawMain(this,lb,ub)
            %draw main axes, delete ROI box and current point
            if(ishandle(this.myMainAxes))
                cla(this.myMainAxes);
            else
                return
            end
            if(isempty(this.myData))
                return
            end
            if(nargin ~= 3)
                lb = prctile(this.myData(:),this.myCMPercentileLB);
                ub = prctile(this.myData(:),this.myCMPercentileUB);
%                 cBLb = min(this.myData(:));
%                 cBUb = max(this.myData(:));
%             else
%                 cBLb = lb;
%                 cBUb = ub;
            end
            img = image2ColorMap(single(this.myData),this.myCM,single(lb),single(ub));
            image(img,'Parent',this.myMainAxes);
            [r, c] = size(this.myData);
            if(~isnan(r) && ~isnan(c) && size(this.myData,1) > 1 && size(this.myData,2) > 1)
                xlim(this.myMainAxes,[1 size(this.myData,2)])
                ylim(this.myMainAxes,[1 size(this.myData,1)])
            end
            if(this.reverseYDir)                
                set(this.myMainAxes,'YDir','reverse');
            else
                set(this.myMainAxes,'YDir','normal');
            end
            %lables
            xlbl = 1:1:c;
            ylbl = 1:1:r;
            xtick = get(this.myMainAxes,'XTick');
            idx = abs(fix(xtick)-xtick)<eps; %only integer labels
            pos = xtick(idx);
            xCell = cell(length(xtick),1);
            xCell(idx) = num2cell(xlbl(pos));
            ytick = get(this.myMainAxes,'YTick');
            idx = abs(fix(ytick)-ytick)<eps; %only integer labels
            pos = ytick(idx);
            yCell = cell(length(ytick),1);
            yCell(idx) = num2cell(ylbl(pos));
            set(this.myMainAxes,'XTickLabel',xCell,'YTickLabel',yCell);            
            %delete old ROI and current point lines
            if(ishandle(this.myROIRectangle))
                delete(this.myROIRectangle);
                this.myROIRectangle = -1;
            end
            if(ishandle(this.CPXLine))
                delete(this.CPXLine);
                this.CPXLine = -1;
            end
            if(ishandle(this.CPYLine))
                delete(this.CPYLine);
                this.CPYLine = -1;
            end            
            %update colorbar labels
            if(ishandle(this.myCBLblLow))                
                if(this.shortNumbers)
                    lb = FLIMXFitGUI.num4disp(lb);
                end                    
                set(this.myCBLblLow,'String',lb);
            end
            if(ishandle(this.myCBLblHigh))
                if(this.shortNumbers)
                    ub = FLIMXFitGUI.num4disp(ub);
                end  
                set(this.myCBLblHigh,'String',ub);
            end
        end
        
        function drawROIBox(this,coord)
            %draw an ROI box on top of the main axes at coord = [y, x]
            if(~isempty(coord) && coord(2)-coord(1) > 0 && coord(4)-coord(3) > 0)
                if(ishandle(this.myROIRectangle))
                    set(this.myROIRectangle,'Position',[coord(1),coord(3),coord(2)-coord(1),coord(4)-coord(3)],'LineWidth',this.ROILineWidth,'LineStyle',this.ROILineStyle);
                else
                    this.myROIRectangle = rectangle('Position',[coord(1),coord(3),coord(2)-coord(1),coord(4)-coord(3)],'LineWidth',this.ROILineWidth,'LineStyle',this.ROILineStyle,'Parent',this.myMainAxes,'EdgeColor',this.ROILineColor);%,'FaceColor',fc
                end
            end
        end
        
        function drawCP(this,coord)
            %draw a vertical and a horizontal line to the point at coord = [y, x]
            sz = size(this.myData);
            if(~isempty(coord) && all(coord > 0) && all(coord <= sz))
                if(ishandle(this.CPXLine))
                    %delete(this.CPXLine)
                    this.CPXLine.XData = [coord(2) coord(2)];
                    this.CPXLine.YData = [1 size(this.myData,1)];
                else
                    this.CPXLine = line('XData',[coord(2) coord(2)],'YData',[1 size(this.myData,1)],'Color','w','LineWidth',2,'LineStyle',':','Parent',this.myMainAxes);
                end                
                if(ishandle(this.CPYLine))
                    %delete(this.CPYLine)
                    this.CPYLine.XData = [1 size(this.myData,2)];
                    this.CPYLine.YData = [coord(1) coord(1)];
                else
                    this.CPYLine = line('XData',[1 size(this.myData,2)],'YData',[coord(1) coord(1)],'Color','w','LineWidth',2,'LineStyle',':','Parent',this.myMainAxes);
                end                
            end
            %update text field
            if(ishandle(this.myCPLbl))
                set(this.myCPLbl,'String',FLIMXFitGUI.num4disp(this.myData(coord(1),coord(2))));
            end
        end
        
        function drawColorBar(this)
            %draw a colorbar
            if(ishandle(this.myCBAxes))
                temp(:,1,:) = this.myCM;
                image(temp,'Parent',this.myCBAxes);
                ytick = (0:0.25:1).*size(this.myCM,1);
                ytick(1) = 1;
                set(this.myCBAxes,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
                ylim(this.myCBAxes,[1 size(this.myCM,1)]);
            end
        end
        
        
        
    end %methods
end
    