classdef FScreenshot < FDisplay
    %=============================================================================================================
    %
    % @file     FScreenshot.m
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
    % @brief    A class to export a screenshot from FDisplay object
    %
    properties(GetAccess = protected, SetAccess = protected)
        myDynVisParams = [];
        myStaticVisParams = [];
        myHMainAxes = [];
        myHSuppAxes = [];
    end
    methods
        
        function this = FScreenshot(FDisplayObj)
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
                
        function hAx = makeScreenshotPlot(this,hFig,type)
            %make a plot for a screenshot
            this.screenshot = true;
            hFig.Units = this.myDynVisParams.mainAxesUnits;
            if(this.visObj.exportParams.plotColorbar)
                switch lower(this.visObj.exportParams.colorbarLocation)
                    case {'eastoutside','westoutside'}
                        hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 250 75];
                    case {'northoutside' ,'southoutside'}             
                        hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 175];
                    otherwise
                        hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
                end
            else
                hFig.Position = this.myDynVisParams.mainAxesPosition + [0 0 150 75];
            end
            figure(hFig);            
            hAx = axes('Units',this.myDynVisParams.mainAxesUnits,'Position',this.myDynVisParams.mainAxesPosition);
            axis(hAx,'off');
            set(hAx,'FontSize',this.visObj.exportParams.labelFontSize);
            switch type
                case 'main'
%                     hOld = this.h_m_ax;
                    this.myHMainAxes = hAx;
                    this.UpdateMinMaxLbl();
                    this.makeMainPlot();
                    this.makeZoom();
                    %this.makeMainXYLabels(); 
                    colormap(hAx,this.dynVisParams.cm);
%                     this.h_m_ax = hOld;
                    %[y x] = size(this.mainExportGfx);
                    %daspect(hAx,[1 1 max(this.mainExportGfx(:))/max(x,y)]);
                    if(this.visObj.exportParams.plotColorbar)% && this.mDispDim ~= 3
                        cb = colorbar(hAx,'location',this.visObj.exportParams.colorbarLocation,'Fontsize',this.visObj.exportParams.labelFontSize);
                        [dType, dTypeNr] = this.visObj.getFLIMItem(this.mySide);
                        if(strcmp(dType,'Intensity'))
                            colormap(hAx,gray(256));
                        else
                            colormap(hAx,this.dynVisParams.cm);
                        end
                        cbLabels = this.makeColorBarLbls(3);
                        %set(cb,'Fontsize',this.visObj.exportParams.labelFontSize);
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
                        idx = [cb.Limits(1) cb.Limits(1)+(cb.Limits(2)-cb.Limits(1))/2 cb.Limits(2)];
                        if(~isempty(strfind(lower(this.visObj.exportParams.colorbarLocation),'north')) || ~isempty(strfind(lower(this.visObj.exportParams.colorbarLocation),'south')))
                            %idx = [1 get(cb,'XTick')];
                            set(cb,'XTick',idx,'XTickLabel',cbLabels);
                            xlabel(cb,dType);
                        else
                            %idx = [1 get(cb,'YTick')];
                            set(cb,'YTick',idx,'YTickLabel',cbLabels);
                            ylabel(cb,dType);
                        end
                        set(hAx,'Units',this.myDynVisParams.mainAxesUnits,'Position',this.myDynVisParams.mainAxesPosition);                        
                    end                    
                    
                case 'supp'
%                     hOld = this.h_s_ax;
                    this.myHSuppAxes = hAx;
                    this.makeSuppPlot();
%                     this.h_s_ax = hOld;                    
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
        
    end
end