classdef mouseOverlayBox < handle
    %=============================================================================================================
    %
    % @file     mouseOverlayBox.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     August, 2017
    %
    % @section  LICENSE
    %
    % Copyright (C) 2017, Matthias Klemm. All rights reserved.
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
    % @brief    A class to paint a custom text box near the mouse pointer on top of an axes
    %
    properties(GetAccess = public, SetAccess = protected)
    end
    properties(GetAccess = protected, SetAccess = protected)
        myAxes = [];
        myTextBox = [];
        myVerticalLine = [];
        myHorizontalLine = [];
        myEdgeColor = [0 0 0];
        myBGColor = [1 1 1 1];
        myLineStyle = '--';
        myLineColor = [0 0 0];
        myLineWidth = 2;
        myVerticalBoxPosition = 1; %0: centered at cursor line; 1: above cursor line
    end
    properties (Dependent = true)
    end
    
    methods
        function this = mouseOverlayBox(hAx)
            %Constructs a mouseOverlayBox object.
            this.setAxesHandle(hAx);
        end %mouseOverlayBox
        
        function setAxesHandle(this,hAx)
            %set handle to axes
            this.myAxes = hAx;
            this.myVerticalLine = line([NaN NaN], 10, 'Color', this.myLineColor, 'Parent', this.myAxes, 'LineStyle', this.myLineStyle, 'LineWidth', this.myLineWidth,'Visible','off');
            this.myHorizontalLine = line(1, [NaN NaN], 'Color', this.myLineColor, 'Parent', this.myAxes, 'LineStyle', this.myLineStyle, 'LineWidth', this.myLineWidth,'Visible','off');
            this.myTextBox = text(NaN, NaN, '', 'EdgeColor', this.myEdgeColor, 'BackgroundColor', this.myBGColor, 'Parent', this.myAxes,'Visible','off');
        end
        
        function setVerticalBoxPositionMode(this,mode)
            %set vertical position of text box: 0: centered at cursor line; 1: above cursor line
            if(isnumeric(mode))
                this.myVerticalBoxPosition = mode;                
            end
        end
        
        function setEdgeColor(this,color)
            %set edge color
            if(length(color) >= 3 && length(color) <= 4)
                this.myEdgeColor = color(:);
                if(ishghandle(this.myTextBox))
                    this.myTextBox.EdgeColor = color(:);
                end
            end
        end
        
        function setBackgroundColor(this,color)
            %set background color
            if(length(color) >= 3 && length(color) <= 4)
                this.myBGColor = color(:);
                if(ishghandle(this.myTextBox))
                    this.myTextBox.BackgroundColor = color(:);
                end
            end
        end
        
        function setLineStyle(this,str)
            %set style of cursor lines
            if(ischar(str))
                this.myLineStyle = str;
                if(ishghandle(this.myVerticalLine))
                    this.myVerticalLine(1).LineStyle = str;
                end
                if(ishghandle(this.myHorizontalLine))
                    this.myHorizontalLine(1).LineStyle = str;
                end
            end
        end
        
        function setLineColor(this,color)
            %set color of cursor lines
            if(length(color) >= 3 && length(color) <= 4)
                this.myLineColor = color;
                if(ishghandle(this.myVerticalLine))
                    this.myVerticalLine(1).Color = color;
                end
                if(ishghandle(this.myHorizontalLine))
                    this.myHorizontalLine(1).Color = color;
                end
            end
        end
        
        function setLineWidth(this,lw)
            %set wisth of cursor lines
            if(lw > 0)
                this.myLineWidth = lw;
                if(ishghandle(this.myVerticalLine))
                    this.myVerticalLine(1).LineWidth = lw;
                end
                if(ishghandle(this.myHorizontalLine))
                    this.myHorizontalLine(1).LineWidth = lw;
                end
            end
        end
        
        %% drawing
        function draw(this,cp,str,hLinePos,vLinePos)
            %draw overlay at current point, optional: set position of horizontal and vertical line
            if(any(isnan(cp)))
                this.clear();
                return
            end
            if(nargin < 5)
                vLinePos = cp(1);
            end
            if(nargin < 4)
                hLinePos = cp(2);
            end
            xl = this.myAxes.XLim;
            yl = this.myAxes.YLim;
            if(~ishghandle(this.myVerticalLine))
                this.myVerticalLine = line([NaN NaN], yl, 'Color', this.myLineColor, 'Parent', this.myAxes, 'LineStyle', this.myLineStyle, 'LineWidth', this.myLineWidth);
            end
            if(~ishghandle(this.myHorizontalLine))
                this.myHorizontalLine = line(xl, [NaN NaN], 'Color', this.myLineColor, 'Parent', this.myAxes, 'LineStyle', this.myLineStyle, 'LineWidth', this.myLineWidth);
            end
            if(~ishghandle(this.myTextBox))
                this.myTextBox = text(NaN, NaN, str, 'EdgeColor', this.myEdgeColor, 'BackgroundColor', this.myBGColor, 'Parent', this.myAxes);
            else
                this.myTextBox.String = str;
            end
            this.myVerticalLine(1).XData = [vLinePos vLinePos];
            this.myHorizontalLine(1).YData = [hLinePos hLinePos];
            %xWidth = xl(2)-xl(1);
            if(any(isnan(this.myTextBox.Position)))
                %draw at default location
                this.myTextBox.Position = [cp(1) cp(2)];
            end
            dy = this.myVerticalBoxPosition;
            this.myTextBox.Visible = 'on';
            this.myVerticalLine.Visible = 'on';
            this.myHorizontalLine.Visible = 'on';
            if(cp(2)+(0.8+dy)*this.myTextBox.Extent(4) > yl(2))
                %textbox will be higher than axes -> place it below the cursor line
                if(dy)
                    %text was supposed to be above cursor line
                    dy = -1;
                else
                    %text was supposed to be at cursor level
                    dy = -0.6;
                end
            end
            %0.02*xWidth + this.myTextBox.Extent(3)
            if((cp(1)+1.25*this.myTextBox.Extent(3)) < xl(2))
                %right of the cursor
                this.myTextBox.Position = [cp(1)+0.2*this.myTextBox.Extent(3) cp(2)+dy*this.myTextBox.Extent(4)];
            else
                %left of the cursor
                this.myTextBox.Position = [cp(1)-1.2*this.myTextBox.Extent(3) cp(2)+dy*this.myTextBox.Extent(4)];
            end            
            %this.displayBoxOnTop();
        end
        
        function displayBoxOnTop(this)
            %move text box to the top of the draw stack
            uistack(this.myTextBox,'top');
        end
        
        function clear(this)
            %hide box
            if(ishghandle(this.myTextBox))
                this.myTextBox.Visible = 'off';
            end
            if(ishghandle(this.myVerticalLine))
                for i = 1:length(this.myVerticalLine)
                    this.myVerticalLine(i).Visible = 'off';
                end
            end
            if(ishghandle(this.myHorizontalLine))
                for i = 1:length(this.myHorizontalLine)
                    this.myHorizontalLine(i).Visible = 'off';
                end
            end
                %this.draw([NaN; NaN],'');
        end
        
    end
end

