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
%             if(this.visObj.exportParams.plotColorbar && strcmp(type,'main'))
%                 switch lower(this.visObj.exportParams.colorbarLocation)
%                     case 'eastoutside'
%                         hFig.Position(3) = (hFig.Position(4)+75);
%                         axSz = hFig.Position(4)-20;
%                         offsetX = 50;
%                         offsetY = 10;
%                     case 'westoutside'
%                         hFig.Position(3) = hFig.Position(4)+75;
%                         axSz = hFig.Position(4)-20;
%                         offsetX = 75;
%                         offsetY = 10;
%                         %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 250 75];
%                     case 'northoutside'
%                         hFig.Position(3) = hFig.Position(4)+175;
%                         axSz = hFig.Position(4)-20;
%                         offsetX = 50;
%                         offsetY = 10;
%                     case 'southoutside'
%                         hFig.Position(3) = hFig.Position(4)+175;
%                         axSz = hFig.Position(4)-175;
%                         offsetX = 50;
%                         offsetY = 175;
%                         %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 175];
%                     otherwise
                        hFig.Position(3) = hFig.Position(4);
                        axSz = hFig.Position(4)-200;
                        offsetX = 100;
                        offsetY = 100;
                        %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
%                 end
%             else
                %hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
%             end
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
                    hfd = this.gethfd();
                    hfd = hfd{1};
                    if(isempty(hfd))
                        return
                    end
                    if(hfd.rawImgIsLogical)
                        colormap(hAx,gray(2));
                        cbLabels = this.makeColorBarLbls(2);
                    elseif(strcmp(hfd.dType,'Intensity'))
                        colormap(hAx,this.dynVisParams.cmIntensity);
                        cbLabels = this.makeColorBarLbls(3);
                    elseif(strncmp(hfd.dType,'MVGroup',7))
                        if(length(hfd.rawImgZSz) < 2)
                            %MVGroup computation failed
                            colormap(hAx,FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,1,this.visObj.visParams.MVGroupBrightnessScaling));
                        else
                            colormap(hAx,FDisplay.makeMVGroupColorMap(this.visObj.fdt.getConditionColor(this.visObj.getStudy(this.mySide),this.visObj.getCondition(this.mySide)),256,hfd.rawImgZSz(2),this.visObj.visParams.MVGroupBrightnessScaling));
                        end
                        cbLabels = this.makeColorBarLbls(3);
                    else
                        colormap(hAx,this.dynVisParams.cm);
                        cbLabels = this.makeColorBarLbls(3);
                    end
                    %[y x] = size(this.mainExportGfx);
                    %daspect(hAx,[1 1 max(this.mainExportGfx(:))/max(x,y)]);
                    if(this.visObj.exportParams.plotColorbar)
                        %todo: make own colorbar because Matlabs colorbar destroys the aspect ratio
                        if(isempty(this.myHColorBar) || ~this.myHColorBar.isvalid)
                            this.myHColorBar = colorbar(hAx,'location',this.visObj.exportParams.colorbarLocation,'Fontsize',this.visObj.exportParams.labelFontSize);
                        end
                        [dType, dTypeNr] = this.visObj.getFLIMItem(this.mySide);
                        if(dTypeNr)
                            dType = sprintf('%s %d',dType{1},dTypeNr);
                        else
                            dType = dType{1};
                        end
                        if(hfd.rawImgIsLogical)
                            ticks = [0 1];
                        else
                            ticks = [this.myHColorBar.Limits(1) this.myHColorBar.Limits(1)+(this.myHColorBar.Limits(2)-this.myHColorBar.Limits(1))/2 this.myHColorBar.Limits(2)];
                        end
%                         if(contains(lower(this.visObj.exportParams.colorbarLocation),'north') || contains(lower(this.visObj.exportParams.colorbarLocation),'south'))
                            %idx = [1 get(this.myHColorBar,'XTick')];
                            set(this.myHColorBar,'Ticks',ticks,'TickLabels',cbLabels);
                            this.myHColorBar.Label.String = dType;
                            this.myHColorBar.Label.Interpreter = 'none';
                            %xlabel(this.myHColorBar,dType);
%                         else
%                             %idx = [1 get(this.myHColorBar,'YTick')];
%                             set(this.myHColorBar,'Ticks',ticks,'Label',cbLabels); %YTickLabel
%                             ylabel(this.myHColorBar,dType);
%                         end
                        %set(hAx,'Units',this.myDynVisParams.mainAxesUnits,'Position',this.myDynVisParams.mainAxesPosition);                        
                    end
                    if(this.mDispDim == 3)
                        if(~isempty(this.disp_view))
                            view(hAx,this.disp_view);
                        end
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
            hAx.FontSize = this.visObj.exportParams.labelFontSize;
            drawnow;
            this.screenshot = false;
        end
        
        function addTextOverlay(this,str)
            %add a text overlay to the main axes
            if(isempty(this.myHMainAxes) || ~this.myHMainAxes.isvalid)
                return
            end
            xPos = 10;
            yPos = 20;
            if(isempty(this.myHTextOverlay) || ~this.myHTextOverlay.isvalid)
                this.myHTextOverlay = text(this.myHMainAxes,xPos,yPos,str, 'Units', 'pixels', 'Interpreter', 'none'); %change to chosen corner
            else
                this.myHTextOverlay.String = str;
            end
            this.myHTextOverlay.Units = 'data';
            xPos = floor(this.myHTextOverlay.Position(1));
            yPos = floor(this.myHTextOverlay.Position(2));
            imgFlat = sum(this.mainExportColors,3)/3;
            txtArea = imgFlat(xPos:floor(xPos+this.myHTextOverlay.Extent(3)),floor((yPos:yPos+this.myHTextOverlay.Extent(4))-this.myHTextOverlay.Extent(4)/2));
            %rectangle('Position',[xPos,yPos-this.myHTextOverlay.Extent(4)/2,this.myHTextOverlay.Extent(3),this.myHTextOverlay.Extent(4)],'EdgeColor','r');
            if(mean(txtArea(:)) < 0.5)
                this.myHTextOverlay.Color = [0.8 0.8 0.8];
            else
                this.myHTextOverlay.Color = [0.2 0.2 0.2];
            end
            % t.Color = settings.overlayFontColor;
            this.myHTextOverlay.FontSize = this.visObj.exportParams.labelFontSize;
            % t.FontName = settings.overlayFontName;
        end
        
    end
end