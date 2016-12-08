classdef FLIMXFitResultImport
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
    end
    
    methods
        function this = FLIMXFitResultImport(hFLIMX)
            this.FLIMXObj = hFLIMX;
            
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXFitResultImportFigure) || ~strcmp(get(this.visHandles.FLIMXFitResultImportFigure,'Tag'),'FLIMXFitResultImportFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.FLIMXFitResultImportFigure);
        end
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            %set callbacks
            
        end
    end
    
end

