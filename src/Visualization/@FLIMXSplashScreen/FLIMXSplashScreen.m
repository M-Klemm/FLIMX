classdef FLIMXSplashScreen < handle
    %=============================================================================================================
    %
    % @file     FLIMXSplashScreen.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     August, 2016
    %
    % @section  LICENSE
    %
    % Copyright (C) 2016, Matthias Klemm. All rights reserved.
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
    % @brief    A class to show a splash screen while FLIMX starts up for the first time.
    %
    properties(GetAccess = public, SetAccess = private)
        visHandles = []; %structure to save handles to uicontrols
    end
    
    methods
        function this = FLIMXSplashScreen()
            %Constructs a GUI for FLIMXSplashScreen class.
            this.createVisWnd();                       
        end %constructor
        
        function delete(this)
            %destructor
            try
                delete(this.visHandles.FLIMXSplashFigure);
            end
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~isfield(this.visHandles,'FLIMXSplashFigure') || ~ishandle(this.visHandles.FLIMXSplashFigure) || ~strcmp(get(this.visHandles.FLIMXSplashFigure,'Tag'),'FLIMXSplashFigure'));
        end
        
        function updateShortProgress(this,x,text)
            %update short progress bar, progress x: 0..1
            if(~this.isOpenVisWnd())
                return
            end
            x = max(0,min(100*x,100));
            if(~ishandle(this.visHandles.FLIMXSplashFigure))
                return;
            end
            xpatch = [0 x x 0];
            set(this.visHandles.patchWaitShort,'XData',xpatch,'Parent',this.visHandles.axesWaitShort);
            yl = ylim(this.visHandles.axesWaitShort);
            set(this.visHandles.textWaitShort,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesWaitShort);
            drawnow;
        end
        
        function updateLongProgress(this,x,text)
            %update long progress bar, progress x: 0..1
            if(~this.isOpenVisWnd())
                return
            end
            x = max(0,min(100*x,100));
            if(~ishandle(this.visHandles.FLIMXSplashFigure))
                return;
            end
            xpatch = [0 x x 0];
            set(this.visHandles.patchWaitLong,'XData',xpatch,'Parent',this.visHandles.axesWaitLong);
            yl = ylim(this.visHandles.axesWaitLong);
            set(this.visHandles.textWaitLong,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesWaitLong);
            drawnow;
        end
        
    end
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = FLIMXSplashFigure();
            set(this.visHandles.axesWaitShort,'XLim',[0 100],...
                'YLim',[0 1],...
                'Box','on', ...
                'FontSize', get(0,'FactoryAxesFontSize'),...
                'XTickMode','manual',...
                'YTickMode','manual',...
                'XTick',[],...
                'YTick',[],...
                'XTickLabelMode','manual',...
                'XTickLabel',[],...
                'YTickLabelMode','manual',...
                'YTickLabel',[]);
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            this.visHandles.patchWaitShort = patch(xpatch,ypatch,'g','EdgeColor',[0 174 76]/256,'Parent',this.visHandles.axesWaitShort);%,'EraseMode','normal'
            set(this.visHandles.patchWaitShort,'FaceColor',[0 174 76]/256);
            this.visHandles.textWaitShort = text(1,0,'','Parent',this.visHandles.axesWaitShort);
            set(this.visHandles.axesWaitLong,'XLim',[0 100],...
                'YLim',[0 1],...
                'Box','on', ...
                'FontSize', get(0,'FactoryAxesFontSize'),...
                'XTickMode','manual',...
                'YTickMode','manual',...
                'XTick',[],...
                'YTick',[],...
                'XTickLabelMode','manual',...
                'XTickLabel',[],...
                'YTickLabelMode','manual',...
                'YTickLabel',[]);
            this.visHandles.patchWaitLong = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesWaitLong);%,'EraseMode','normal'
            this.visHandles.textWaitLong = text(1,0,'','Parent',this.visHandles.axesWaitLong); 
            vi = FLIMX.getVersionInfo();
            set(this.visHandles.textVersion,'String',sprintf('Version: %d.%d.%d',vi.client_revision_major,vi.client_revision_minor,vi.client_revision_fix));
            set(this.visHandles.textSplash,'String','This may take a few moments...');
        end                
    end %methods protected
end