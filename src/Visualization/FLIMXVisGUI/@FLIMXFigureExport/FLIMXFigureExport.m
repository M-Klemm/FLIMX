classdef FLIMXFigureExport < FDisplay
    %=============================================================================================================
    %
    % @file     FLIMXFigureExport.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  2.0
    % @date     December, 2020
    %
    % @section  LICENSE
    %
    % Copyright (C) 2020, Matthias Klemm. All rights reserved.
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
    % @brief    A class to export a figure from FDisplay object
    %
    properties(GetAccess = protected, SetAccess = protected)
        myDynVisParams = [];
        myStaticVisParams = [];
        myHMainAxes = [];
        myHSuppAxes = [];
        myHColorBar = [];
        myHTextOverlay = [];
    end
    methods
        
        function this = FLIMXFigureExport(FDisplayObj)
            %
            this = this@FDisplay(FDisplayObj.visObj,FDisplayObj.mySide);
            this.gethfd();
            %set inital values
            this.myDynVisParams = FDisplayObj.dynVisParams;
            this.myDynVisParams.mainAxesUnits = FDisplayObj.h_m_ax.Units;
            this.myDynVisParams.mainAxesPosition = FDisplayObj.h_m_ax.Position;
            if(this.visObj.exportParams.plotColorbar)
                switch lower(this.visObj.exportParams.colorbarLocation)
                    case 'westoutside'
                        this.myDynVisParams.mainAxesPosition(1,1) = 200;
                        this.myDynVisParams.mainAxesPosition(1,2) = 50;
                    case 'southoutside'
                        this.myDynVisParams.mainAxesPosition(1,1) = 100;
                        this.myDynVisParams.mainAxesPosition(1,2) = 150;
                    otherwise
                        this.myDynVisParams.mainAxesPosition(1,1) = 100;
                        this.myDynVisParams.mainAxesPosition(1,2) = 50;
                end
            else
                this.myDynVisParams.mainAxesPosition(1,1) = 100;
                this.myDynVisParams.mainAxesPosition(1,2) = 50;
            end
            this.myStaticVisParams = FDisplayObj.staticVisParams;
            this.disp_view = FDisplayObj.disp_view;
        end
        
        function out = getHandleMainAxes(this)
            %get handle to main axes
            out = this.myHMainAxes;
        end
        
        function out = getHandleSuppAxes(this)
            %get handle to support axes
            out = this.myHSuppAxes;
        end
                
        function hAx = makeExportPlot(this,hFig,type)
            %make a plot for a screenshot
            this.screenshot = true;
            hFig.Units = this.myDynVisParams.mainAxesUnits;
            hFig.Position(4) = max(450,hFig.Position(4));
            if(this.visObj.exportParams.plotColorbar && strcmp(type,'main'))
                switch lower(this.visObj.exportParams.colorbarLocation)
                    case 'eastoutside'
                        hFig.Position(3) = (hFig.Position(4)+75);
                        axSz = hFig.Position(4)-20;
                        offsetX = 10;
                        offsetY = 10;
                    case 'westoutside'
                        hFig.Position(3) = hFig.Position(4)+75;
                        axSz = hFig.Position(4)-20;
                        offsetX = 75;
                        offsetY = 10;
                        %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 250 75];
                    case 'northoutside'
                        hFig.Position(3) = hFig.Position(4)+175;
                        axSz = hFig.Position(4)-20;
                        offsetX = 10;
                        offsetY = 10;
                    case 'southoutside'
                        hFig.Position(3) = hFig.Position(4)+175;
                        axSz = hFig.Position(4)-20;
                        offsetX = 10;
                        offsetY = 175;
                        %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 175];
                    otherwise
                        hFig.Position(3) = hFig.Position(4);
                        axSz = hFig.Position(4)-20;
                        offsetX = 10;
                        offsetY = 10;
                        %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
                end
            else
                %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
            end
            %hFig.Position(4) = max(715,hFig.Position(4));
            if(isempty(this.myHMainAxes) || ~this.myHMainAxes.isvalid)
                %axSz = min(0.95*(hFig.Position(3)-70-175),0.95*(hFig.Position(4)-50));
                %             if(this.visObj.exportParams.plotColorbar)
                %                 switch lower(this.visObj.exportParams.colorbarLocation)
                %                     case {'eastoutside','westoutside'}
                %                         hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 250 75];
                %                     case {'northoutside' ,'southoutside'}
                %                         hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 175];
                %                     otherwise
                %                         hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
                %                 end
                %             else
                %                 hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
                %             end
                %figure(hFig);
                %hAx = axes('Units','pixels','Position',[10,10,axSz,axSz]); %[70,50,axSz,axSz]
                hAx = axes('Units','pixels','Position',[offsetX,offsetY,axSz,axSz],'Parent',hFig);
                %hAx = axes('Units',this.myDynVisParams.mainAxesUnits,'Position',this.myDynVisParams.mainAxesPosition);
                axis(hAx,'off');
                hAx.FontSize = this.visObj.exportParams.labelFontSize;
            else
                cla(this.myHMainAxes);
                hAx = [];
            end
            switch type
                case 'main'
                    if(isempty(hAx))
                        hAx = this.myHMainAxes;
                    else
                        this.myHMainAxes = hAx;
                    end
                    this.UpdateMinMaxLbl();
                    this.makeMainPlot();
                    this.makeZoom();
                    %this.makeMainXYLabels(); 
                    colormap(hAx,this.dynVisParams.cm);
                    %[y x] = size(this.mainExportGfx);
                    %daspect(hAx,[1 1 max(this.mainExportGfx(:))/max(x,y)]);
                    if(this.visObj.exportParams.plotColorbar)% && this.mDispDim ~= 3
                        %todo: make own colorbar because Matlabs colorbar destroys the aspect ratio
                        if(isempty(this.myHColorBar) || ~this.myHColorBar.isvalid)
                            this.myHColorBar = colorbar(hAx,'location',this.visObj.exportParams.colorbarLocation,'Fontsize',this.visObj.exportParams.labelFontSize);
                        end
                        [dType, dTypeNr] = this.visObj.getFLIMItem(this.mySide);
                        if(strcmp(dType,'Intensity'))
                            colormap(hAx,gray(256));
                        else
                            colormap(hAx,this.dynVisParams.cm);
                        end
                        cbLabels = this.makeColorBarLbls(3);
                        %set(this.myHColorBar,'Fontsize',this.visObj.exportParams.labelFontSize);
                        %                         if(this.mDispDim == 2)
                        %special handling of colorbar for 2D plot
                        %clim = get(hAx,'CLim');
                        %cbLabels = linspace(clim(1),clim(2),length(this.dynVisParams.cm));                        
                        if(dTypeNr)
                            dType = sprintf('%s %d',dType{1},dTypeNr);
                        else
                            dType = dType{1};
                        end
                        %idx = [1 1+round(length(this.dynVisParams.cm)/2) 1+length(this.dynVisParams.cm)];
                        idx = [this.myHColorBar.Limits(1) this.myHColorBar.Limits(1)+(this.myHColorBar.Limits(2)-this.myHColorBar.Limits(1))/2 this.myHColorBar.Limits(2)];
                        if(contains(lower(this.visObj.exportParams.colorbarLocation),'north') || contains(lower(this.visObj.exportParams.colorbarLocation),'south'))
                            %idx = [1 get(this.myHColorBar,'XTick')];
                            set(this.myHColorBar,'XTick',idx,'XTickLabel',cbLabels);
                            xlabel(this.myHColorBar,dType);
                        else
                            %idx = [1 get(this.myHColorBar,'YTick')];
                            set(this.myHColorBar,'YTick',idx,'YTickLabel',cbLabels);
                            ylabel(this.myHColorBar,dType);
                        end
                        %set(hAx,'Units',this.myDynVisParams.mainAxesUnits,'Position',this.myDynVisParams.mainAxesPosition);                        
                    end                    
                    
                case 'supp'
                    if(isempty(hAx))
                        hAx = this.myHSuppAxes;
                    else
                        this.myHSuppAxes = hAx;
                    end
                    this.makeSuppPlot();                   
            end
            if(this.visObj.exportParams.autoAspectRatio)
                daspect(hAx,'auto');
            else %same as data
                daspect(hAx,[1 1 1]);
            end
            if(this.visObj.exportParams.plotBox)
                hAx.Box = 'on';
                hAx.XAxis.Visible = 'on';
                hAx.YAxis.Visible = 'on';
            else
                hAx.Box = 'off';
                hAx.XAxis.Visible = 'off';
                hAx.YAxis.Visible = 'off';
            end
            drawnow;
            this.screenshot = false;
        end
        
        function addTextOverlay(this,str)
            %add a text overlay to the main axes
            if(isempty(this.myHMainAxes) || ~this.myHMainAxes.isvalid)
                return
            end
            if(isempty(this.myHTextOverlay) || ~this.myHTextOverlay.isvalid)
                this.myHTextOverlay = text(this.myHMainAxes,10,20,str, 'Interpreter', 'none'); %change to chosen corner
            else
                this.myHTextOverlay.String = str;
            end
%                     t.Color = settings.overlayFontColor;
                    this.myHTextOverlay.FontSize = this.visObj.exportParams.labelFontSize;
%                     t.FontName = settings.overlayFontName;
        end
        
    end
end