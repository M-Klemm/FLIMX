classdef FLIMXFitGUI < handle
    %=============================================================================================================
    %
    % @file     FLIMXFitGUI.m
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
    % @brief    A class to control FLIMXFit object and browse its results.
    %
    properties(GetAccess = public, SetAccess = private)
        dynVisParams = []; %options for visualization  (dynamic), sdtLoadedFlag = 0; %0 - offline mode (result loaded), 1 - online mode (sdt loaded)
        visHandles = []; %structure to save handles to uicontrols
        FLIMXObj = []; %FLIMX object
        
        currentX = 1; %current x position
        currentY = 1; %current y position
        
        lastProgressCmdLine = [];
        resScaleFlag = 1; %1 - auto mode, 0 - manual residuum scaling
        resScaleValue = 10; %percentage for manual residuum scaling
    end
    properties(GetAccess = protected, SetAccess = private)
        axesRawMgr = [];
        axesROIMgr = [];
        simToolObj = []; %handle to simulation tool
        simCompToolObj = []; %handle to simulation analysis tool
    end
    properties (Dependent = true)
        fdt = [];
        simTool = []; %handle to simulation tool
        simCompTool = []; %handle to simulation analysis tool
        
        maxX = 1;
        maxY = 1;
        axesSuppData = [];
        currentStudy = '';
        currentSubject = '';
        currentView = '';
        currentChannel = 0;
        currentDecayData = [];
        generalParams = [];
        
        showInitialization = false;
        
        about = [];
        computationParams = [];
        folderParams = [];
        initFitParams = [];
        visualizationParams = [];
        volatilePixelParams = [];
        exportParams = [];
    end
    
    methods
        function this = FLIMXFitGUI(flimX)
            %Constructs a GUI for FLIMXFit class.
            if(isempty(flimX))
                error('Handle to FLIMX object required!');
            end
            this.FLIMXObj = flimX;
            this.lastProgressCmdLine = 0;
            try
                this.dynVisParams.cm = eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
            catch
                this.dynVisParams.cm = jet(256);
            end            
            if(this.generalParams.cmInvert)
                this.dynVisParams.cm = flipud(this.dynVisParams.cm);
            end
            try
                this.dynVisParams.cmIntensity = eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
            catch
                this.dynVisParams.cmIntensity = gray(256);
            end
            if(this.generalParams.cmIntensityInvert)
                this.dynVisParams.cmIntensity = flipud(this.dynVisParams.cmIntensity);
            end
            this.dynVisParams.timeScalingAuto = 1; %1-auto, 0-manual
            this.dynVisParams.timeScalingStart = 1; %only if timeScalingAuto = 0
            this.dynVisParams.timeScalingEnd = 1024; %only if timeScalingAuto = 0
            this.dynVisParams.countsScalingAuto = 1; %1-auto, 0-manual
            this.dynVisParams.countsScalingStart = 0.1; %only if countsScalingAuto = 0
            this.dynVisParams.countsScalingEnd = 10000; %only if countsScalingAuto = 0
            
            this.FLIMXObj.FLIMFit.setProgressShortCallback(@this.updateProgressShort);
            this.FLIMXObj.FLIMFit.setProgressLongCallback(@this.updateProgressLong);            
        end %constructor
                
%         function setBusyStatus(this,flag)
%             %sets the mouse pointer to watch or arrow
%             if(flag)
%                 set(this.visHandles.FLIMXFitGUIFigure,'Pointer','watch');
%             else
%                 set(this.visHandles.FLIMXFitGUIFigure,'Pointer','arrow');
%             end
%         end
        
        function setButtonStopSpinning(this,flag)
            %switch between spinning and regular stop button
            if(flag)
                try
                    set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/> Stop</html>',fullfile(cd,'functions','visualization','spinner.gif')));
                    drawnow;
                end
            else
                set(this.visHandles.buttonStop,'String','Stop');
            end
        end
        
        function setCurrentPos(this,y,x)
            %set the current cursor position and update GUI            
            if(~this.isOpenVisWnd() || isempty(y) || isempty(x))
                return
            end
            this.currentY = max(1,min(y,this.maxY));
            this.currentX = max(1,min(x,this.maxX));
            this.updateGUI(1);
        end
                
%         function openResultFile(this)
%             %reads exported results from disc
%             [fn, fi] = loadFile({'*.mat','FLIMFit result File (*.mat)';'*.dat;*.txt','B&H Result Files (*.dat,*.txt)'},'Load result file(s)...',this.FLIMXObj.FLIMFit.folderParams.export,'on');
%             if(isempty(fn))
%                 return;
%             end
%             %toDo: fix me
% %             this.FLIMXObj.newResultFile();
% %             ch = this.FLIMXObj.curResultObj.openResult(fn,fi,true);
%             this.setupGUI();
% %             this.FLIMXObj.convResult2Synthetic();
%             if(ch > 0)
%                 this.currentChannel = ch;
%             end
%         end
        
        function setupGUI(this)
            %make parameter popup menu string
            if(~this.isOpenVisWnd())
                return
            end
            %update study controls
            studies = this.FLIMXObj.fdt.getStudyNames();
            curStudyIdx = find(strcmp(this.currentStudy,studies),1);
            if(~strcmp(this.currentStudy,this.FLIMXObj.curSubject.getStudyName()) || isempty(curStudyIdx) || curStudyIdx ~= get(this.visHandles.popupStudy,'Value')) 
                studyPos = find(strcmp(this.FLIMXObj.curSubject.getStudyName(),studies),1);
                if(isempty(studyPos))
                    if(isempty(studies))
                        set(this.visHandles.popupStudy,'String','Study','Value',1);
                    else
                        set(this.visHandles.popupStudy,'String',studies,'Value',1);                        
                    end
                else
                    set(this.visHandles.popupStudy,'String',studies,'Value',studyPos);
                end
            else
                set(this.visHandles.popupStudy,'String',studies,'Value',curStudyIdx);
            end
            views = this.FLIMXObj.fdt.getStudyViewsStr(this.currentStudy);
            oldVStr = get(this.visHandles.popupView,'String');
            if(iscell(oldVStr))
                oldVStr = oldVStr(get(this.visHandles.popupView,'Value'));
            end
            %try to find oldPStr in new pstr
            idx = find(strcmp(oldVStr,views),1);
            if(isempty(idx) || isempty(this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,views{idx})))
                idx = 1;%choose '-' view
            end
            set(this.visHandles.popupView,'String',views,'Value',idx);
            %update subject controls
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentView);
            curSubjectIdx = find(strcmp(this.currentSubject,subjects),1);
            %set(this.visHandles.popupSubject,'String',subjects,'Value',min(get(this.visHandles.popupSubject,'Value'),length(subjects)));
            if(~strcmp(this.currentSubject,this.FLIMXObj.curSubject.getDatasetName()) || isempty(curSubjectIdx) || curSubjectIdx ~= get(this.visHandles.popupSubject,'Value'))                
                subjectPos = find(strcmp(this.FLIMXObj.curSubject.getDatasetName(),subjects),1);
                if(isempty(subjectPos) && ~isMultipleCall())
                    if(isempty(subjects))
                        set(this.visHandles.popupSubject,'String','Subject','Value',1);
                        %this.FLIMXObj.newSDTFile('');
%                     else
                        % ToDo: throw warning / error!
%                         set(this.visHandles.popupSubject,'Value',1);
%                         this.FLIMXObj.setCurrentSubject(this.currentStudy,subjects{1});
%                         return
                    else
                        %old subject was renamed or removed
                        subjectPos = min(get(this.visHandles.popupSubject,'Value'),length(subjects));
                        set(this.visHandles.popupSubject,'String',subjects,'Value',subjectPos);
                    end
                else
                    set(this.visHandles.popupSubject,'String',subjects,'Value',subjectPos);
                end  
            else
                set(this.visHandles.popupSubject,'String',subjects,'Value',curSubjectIdx);
            end
            ch = this.currentChannel;
            pstr = this.FLIMXObj.curSubject.getResultNames(ch,this.showInitialization);
            if(~isempty(pstr))
                pstr = removeNonVisItems(pstr);
                pstr(2:length(pstr)+1) = sort(pstr);
            end
            pstr{1} = 'Intensity';
            %make channel popup menu string
            cStr(1) = {sprintf('%d',1)};
            for i = 2:this.FLIMXObj.curSubject.nrSpectralChannels
                cStr(i) = {sprintf('%d',i)};
            end
            set(this.visHandles.popupChannel,'String',cStr,'Value',min(this.currentChannel,length(cStr)));
            try
                this.dynVisParams.cm = eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
            catch
                this.dynVisParams.cm = jet(256);
            end
            if(this.generalParams.cmInvert)
                this.dynVisParams.cm = flipud(this.dynVisParams.cm);
            end
            try
                this.dynVisParams.cmIntensity = eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
            catch
                this.dynVisParams.cmIntensity = gray(256);
            end
            if(this.generalParams.cmIntensityInvert)
                this.dynVisParams.cm = flipud(this.dynVisParams.cmIntensity);
            end
            oldPStr = get(this.visHandles.popupROI,'String');
            if(iscell(oldPStr))
                oldPStr = oldPStr(get(this.visHandles.popupROI,'Value'));
            end
            %try to find oldPStr in new pstr
            idx = find(strcmp(oldPStr,pstr),1);
            if(isempty(idx))
                idx = min(length(pstr),get(this.visHandles.popupROI,'Value'));
            end
            set(this.visHandles.popupROI,'String',pstr,'Value',idx,'Enable','on');
            set(this.visHandles.buttonToggle,'Value',0);
            this.axesRawMgr.setColorMap(this.dynVisParams.cmIntensity);
            this.axesROIMgr.setColorMap(this.dynVisParams.cm);
            set(this.visHandles.FLIMXFitGUIFigure,'Name',sprintf('FLIMXFit: %s - Channel %d',this.FLIMXObj.curSubject.getDatasetName(),ch));
            this.lastProgressCmdLine = 0;%-1
%             this.updateProgressbar(0,'');
            if(this.showInitialization)
                this.currentX = max(1,min(this.initFitParams.gridSize,this.currentX));
                this.currentY = max(1,min(this.initFitParams.gridSize,this.currentY));
            else
                this.currentX = max(1,min(this.FLIMXObj.curSubject.getROIXSz,this.currentX));
                this.currentY = max(1,min(this.FLIMXObj.curSubject.getROIYSz,this.currentY));                
            end
            set(this.visHandles.textX,'String',num2str(this.maxX));
            set(this.visHandles.textY,'String',num2str(this.maxY));
            %time scaling edits
            if(this.FLIMXObj.curSubject.nrTimeChannels > 0)
                this.dynVisParams.timeScalingEnd = max(2,min(this.dynVisParams.timeScalingEnd,this.FLIMXObj.curSubject.nrTimeChannels));
                this.dynVisParams.timeScalingStart = max(min(this.dynVisParams.timeScalingStart,this.dynVisParams.timeScalingEnd-1),1);
            end
            set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
            set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
            %counts edits
            tmp = this.currentDecayData;            
            if(~isempty(tmp))
%                 rm = logical(this.FLIMXObj.curSubject.getReflectionMask(this.currentChannel));
%                 rm(1:this.FLIMXObj.curSubject.getStartPosition(this.currentChannel)) = false;
%                 rm(this.FLIMXObj.curSubject.getEndPosition(this.currentChannel):end) = false;
%                 if(get(this.visHandles.radioTimeScalManual,'Value'))
%                     rm(1:this.dynVisParams.timeScalingStart) = false;
%                     rm(this.dynVisParams.timeScalingEnd:end) = false;
%                 end
%                 tmp = tmp(rm);
                this.dynVisParams.countsScalingEnd = 10^ceil(log10(max(tmp(:))));
                this.dynVisParams.countsScalingStart = max(min(10^floor(log10(min(tmp(:)))),this.dynVisParams.countsScalingEnd-1),0.1);
            end
            set(this.visHandles.editCountsScalStart,'String',num2str(this.dynVisParams.countsScalingStart,'%G'));
            set(this.visHandles.editCountsScalEnd,'String',num2str(this.dynVisParams.countsScalingEnd,'%G'));
                        
            set(this.visHandles.buttonToggle,'Enable','on');
            %edit
            set(this.visHandles.editX,'Enable','on');
            set(this.visHandles.editY,'Enable','on');
            %buttons
            set(this.visHandles.buttonRight,'Enable','on');
            set(this.visHandles.buttonLeft,'Enable','on');
            set(this.visHandles.buttonUp,'Enable','on');
            set(this.visHandles.buttonDown,'Enable','on');
            set(this.visHandles.toggleShowMerge,'Enable','on');
            set(this.visHandles.buttonStop,'Enable','on');
            %popup
            set(this.visHandles.buttonToggle,'Value',0);
            
%             if(any(this.volatilePixelParams.globalFitMask))
%                 flag = 'off';
%             else
%                 flag = 'on';
%             end
%             set(this.visHandles.menuFitAll,'Enable',flag);
            flag = 'on';
            set(this.visHandles.menuBatchSubjectAllCh,'Enable',flag);
        end %setupGUI
        
        function updateGUI(this,flag)
            %update main and cuts axes
            if(~this.isOpenVisWnd())
                return
            end
            if(~strcmp(this.currentStudy,this.FLIMXObj.curSubject.getStudyName()) || ...
                    ~strcmp(this.currentSubject,this.FLIMXObj.curSubject.getDatasetName()))
               %load new subject from tree
               
            end
            %decay plot
            if(isempty(this.FLIMXObj.curSubject.getROIData(this.currentChannel,this.currentY,this.currentX)))
                if(flag)
                    this.clearAllPlots();
                end
                return;
            end
            if(get(this.visHandles.buttonToggle,'Value'))
                this.visCurFit(this.currentChannel,this.currentY,this.currentX,this.visHandles.axesSupp);
            else
                this.visCurFit(this.currentChannel,this.currentY,this.currentX,this.visHandles.axesMain);
            end
            if(flag)
                str = get(this.visHandles.popupROI,'String');
                val = get(this.visHandles.popupROI,'Value');
                if(iscell(str))
                    str = str{val};
                end
                if(~isempty(str) && ischar(str))
                    if(strcmp(str,'Intensity'))
                        this.axesROIMgr.setColorMap(this.dynVisParams.cmIntensity);
                    else
                        this.axesROIMgr.setColorMap(this.dynVisParams.cm);
                    end
                end
                this.axesRawMgr.setMainData(this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel));
                this.axesROIMgr.setMainData(this.axesSuppData);
            end
            %s = axesWithROI(this.visHandles.axesRaw,this.visHandles.axesCbRaw,this.visHandles.textCbRawBottom,this.visHandles.textCbRawTop,this.visHandles.editCP,this.dynVisParams.cm);
%             s.setMainData(this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel));
            roi = this.FLIMXObj.curSubject.ROICoordinates;
            this.axesRawMgr.drawROIBox(roi);
            this.axesRawMgr.drawCP([this.currentY+roi(3)-1 this.currentX+roi(1)-1]);
            this.axesROIMgr.drawCP([this.currentY this.currentX]);
%             this.plotRawDataROI(this.visHandles.axesRaw,[]);
%             this.plotRawDataCP(this.visHandles.axesRaw,[]);
%             this.plotSuppDataCP(this.visHandles.axesCurSupp);
        end %updateGUI
        
        %% dependent properties
        function out = get.fdt(this)
            %shortcut to fdt
            out = this.FLIMXObj.fdt;
        end
        
        function out = get.simTool(this)
            %return simulation tool
            if(isempty(this.simToolObj))
                this.simToolObj = simFLIM(this.FLIMXObj);
            end
            out = this.simToolObj;
        end
        
        function out = get.simCompTool(this)
            %return simulation comparison tool
            if(isempty(this.simCompToolObj))
                this.simCompToolObj = simAnalysis(this.FLIMXObj,this.simTool);
            end
            out = this.simCompToolObj;
        end
        
        function value = get.maxX(this)
            %get maximum for x
            if(isempty(this.FLIMXObj.curSubject.ROICoordinates))
                value = 1;
            elseif(this.showInitialization)
                value = this.initFitParams.gridSize;
            else                
                value = abs(this.FLIMXObj.curSubject.ROICoordinates(2)-this.FLIMXObj.curSubject.ROICoordinates(1))+1;
            end
        end
        
        function value = get.maxY(this)
            %get maximum for y
            if(isempty(this.FLIMXObj.curSubject.ROICoordinates))
                value = 1;
            elseif(this.showInitialization)
                value = this.initFitParams.gridSize;
            else
                value = abs(this.FLIMXObj.curSubject.ROICoordinates(4)-this.FLIMXObj.curSubject.ROICoordinates(3))+1;
            end
        end
        
        function value = get.axesSuppData(this)
            %get data for supplemental axes
            if(~this.isOpenVisWnd())
                value = [];
                return;
            end
            pstr = char(get(this.visHandles.popupROI,'String'));
            pos = get(this.visHandles.popupROI,'Value');
            pstr = strtrim(pstr(pos,:));
            if(this.showInitialization)
                if(strcmp('Intensity',pstr))
                    value = double(sum(this.FLIMXObj.curSubject.getInitData(this.currentChannel,[]),3));
                else
                    value = double(this.FLIMXObj.curSubject.getInitFLIMItem(this.currentChannel,pstr));
                end
            else
                if(strcmp('Intensity',pstr))
                    value = double(this.FLIMXObj.curSubject.getROIDataFlat(this.currentChannel));
                else
                    value = double(this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,pstr));
                end
            end
        end
        
        function data = get.currentDecayData(this)
            %get the current photon decay histogram
            if(this.showInitialization)
                data = this.FLIMXObj.curSubject.getInitData(this.currentChannel,[]);
                data = double(squeeze(data(min(this.currentY,size(data,1)),min(this.currentX,size(data,2)),:)));
            else
                data = double(this.FLIMXObj.curSubject.getROIData(this.currentChannel,this.currentY,this.currentX));
            end
            %data = data + 50;
        end
        
        function out = get.currentStudy(this)
            %get current study name from GUI
            out = '';
            if(~this.isOpenVisWnd())
                return;
            end
            str = get(this.visHandles.popupStudy,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupStudy,'Value')};
            elseif(ischar(str))
                out = str;
            end
        end
        
        function out = get.currentView(this)
            %get current view name from GUI
            out = '-';
            if(~this.isOpenVisWnd())
                return;
            end
            str = get(this.visHandles.popupView,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupView,'Value')};
            elseif(ischar(str))
                out = str;
            end
        end
        
        function out = get.currentSubject(this)
            %get current subject name from GUI
            out = '';
            if(~this.isOpenVisWnd())
                return;
            end
            str = get(this.visHandles.popupSubject,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupSubject,'Value')};
            elseif(ischar(str))
                out = str;
            end
        end
        
        function out = get.currentChannel(this)
            %get current channel from GUI
            out = 1;
            if(~this.isOpenVisWnd())
                return;
            end
            out = get(this.visHandles.popupChannel,'Value');
            if(isempty(out))
                out = 1;
            end
        end
        
        function set.currentChannel(this,val)
            %get current channel from GUI
            if(~this.isOpenVisWnd())
                return;
            end
            if(isempty(val))
                val = 1;
            end
            if(this.isOpenVisWnd())
                set(this.visHandles.popupChannel,'Value',min(val,length(get(this.visHandles.popupChannel,'String'))));
                %set(this.visHandles.popupChannel,'Value',val);
                this.setupGUI();
                this.updateGUI(true);
            end
        end
        
        function out = get.showInitialization(this)
            %return flag to show init (true) or pixel (false)
            out = get(this.visHandles.toggleShowMerge,'Value');
        end
        
        function out = get.about(this)
            %make visParams struct
            out = this.FLIMXObj.paramMgr.getParamSection('about');
        end
                
        function out = get.generalParams(this)
            %make visParams struct
            out = this.FLIMXObj.paramMgr.getParamSection('general');
        end
        
        function params = get.computationParams(this)
            %get pre processing parameters
            params = this.FLIMXObj.paramMgr.getParamSection('computation');
        end
        
        function params = get.folderParams(this)
            %get folder parameters
            params = this.FLIMXObj.paramMgr.getParamSection('folders');
        end
        
        function params = get.initFitParams(this)
            %make fitParams struct
            params = this.FLIMXObj.curSubject.initFitParams;
        end
        
        function params = get.visualizationParams(this)
            %get visualization parameters
            params = this.FLIMXObj.paramMgr.getParamSection('fluo_decay_fit_gui');
        end
                
        function params = get.volatilePixelParams(this)
            %get volatilePixelParams
            params = this.FLIMXObj.curSubject.volatilePixelParams;
        end
        
        function out = get.exportParams(this)
            %get export paramters
            out = this.FLIMXObj.paramMgr.getParamSection('export');
        end       
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~isfield(this.visHandles,'FLIMXFitGUIFigure') || ~ishandle(this.visHandles.FLIMXFitGUIFigure) || ~strcmp(get(this.visHandles.FLIMXFitGUIFigure,'Tag'),'FLIMXFitGUIFigure'));
        end
        
        function checkVisWnd(this)
            %check if my window is open, if not: create it
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI(true);
            figure(this.visHandles.FLIMXFitGUIFigure);
        end %checkVisWnd
        
        function closeVisWnd(this)
            %try to close windows if it still exists
            try
                close(this.visHandles.FLIMXFitGUIFigure);
            end
        end %closeVisWnd
        
        function updateProgressShort(this,x,text,varargin)
            %update short progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            if(~this.isOpenVisWnd())
                return
            end
            x = max(0,min(100*x,100));
            if(~ishandle(this.visHandles.FLIMXFitGUIFigure))
                %write progress on command line
                x_test = round(x/10);
                if(x_test > this.lastProgressCmdLine)
                    fprintf('...%d%%',x_test*10);
                    this.lastProgressCmdLine = x_test;
                end
                return;
            end
            xpatch = [0 x x 0];
            set(this.visHandles.patchWaitShort,'XData',xpatch,'Parent',this.visHandles.axesWaitShort)
            yl = ylim(this.visHandles.axesWaitShort);
            set(this.visHandles.textWaitShort,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesWaitShort);
            drawnow;
        end
        
        function updateProgressLong(this,x,text,varargin)
            %update long progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            if(~this.isOpenVisWnd())
                return
            end
            if(x < 0)
                %stop button pressed
                text = get(this.visHandles.textWaitLong,'String');
                newStr = '...Stopping...';
                newLen = length(newStr);
                if(length(text) < newLen || ~strncmp(text(end-newLen+1:end),newStr,newLen))
                    text = [text newStr];
                    set(this.visHandles.textWaitLong,'String',text);
                end
            else
                x = max(0,min(100*x,100));
                if(~ishandle(this.visHandles.FLIMXFitGUIFigure))
                    %write progress on command line
                    x_test = round(x/10);
                    if(x_test > this.lastProgressCmdLine)
                        fprintf('...%d%%',x_test*10);
                        this.lastProgressCmdLine = x_test;
                    end
                    return;
                end
                xpatch = [0 x x 0];
                set(this.visHandles.patchWaitLong,'XData',xpatch,'Parent',this.visHandles.axesWaitLong)
                yl = ylim(this.visHandles.axesWaitLong);
                set(this.visHandles.textWaitLong,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesWaitLong);
            end
            drawnow;
        end
        
        function [apObj xVec oset chi2 chi2Tail TotalPhotons iterations time slopeStart iVec] = getVisParams(this,ch,y,x)
            %get parameters for visualization of current fit in channel ch
%             if(this.showInitialization)
%                 apObjs = this.FLIMXObj.getInitApproxObjs(ch);                
%                 apObj = apObjs{sub2ind([this.initFitParams.gridSize this.initFitParams.gridSize],y,x)};
%             else
%                 apObj = this.FLIMXObj.getApproxObj(ch,y,x);
%             end
            [apObj xVec hShift oset chi2 chi2Tail TotalPhotons iterations time slopeStart iVec] = this.FLIMXObj.curSubject.getVisParams(ch,y,x,this.showInitialization);
        end
        
        function [xAxis data irf model exponentials residuum residuumHist tableInfo] = visCurFit(this,ch,y,x,hAxMain,hAxRes,hAxResHis,hTableInfo)
            %plot current data, fit, parameters
            if(~this.isOpenVisWnd())
                return;
            end
            %% check handles
            if(nargin < 8 || ~ishandle(hTableInfo))
                hTableInfo = this.visHandles.tableParam;
            end
            if(nargin < 7 || ~ishandle(hAxResHis))
                hAxResHis = this.visHandles.axesResHis;
            end
            if(nargin < 6 || ~ishandle(hAxRes))
                hAxRes = this.visHandles.axesRes;
            end
            if(nargin < 5 || ~ishandle(hAxMain))
                hAxMain = this.visHandles.axesCurMain;
            end
            exponentials = [];
            residuum = [];
            residuumHist = [];
            data = this.currentDecayData;
            [apObj x_vec oset chi2 chi2Tail TotalPhotons iterations time slopeStart iVec] = this.getVisParams(ch,y,x);
            if(sum(TotalPhotons(:)) == 0)
                TotalPhotons = sum(data(:));
            end
            xAxis = this.FLIMXObj.curSubject.timeVector(1:length(data));
            if(sum(x_vec(:)) == 0)
                model = [];
            else
                model = apObj.getModel(ch,x_vec);
                model = model(1:length(data));
                model(model < 1e-1) = 1e-1;
            end
            ylabel(hAxMain,'');
            legend(hAxMain,'off');
            lStr = cell(0,0);
            cla(hAxMain);
            set(hAxMain,'YLimMode','auto','Yscale','log','XTickLabelMode','auto','YTickLabelMode','auto');
            ylabel(hAxMain,'Photon-Frequency (counts)');
            
            %% data
            if(this.visualizationParams.plotData)
                lStr = this.makeModelPlot(hAxMain,data,xAxis,'Data',this.dynVisParams,this.visualizationParams,'Measured',lStr);
            end
            
            %% model
            if(this.visualizationParams.plotExpSum)
                lStr = this.makeModelPlot(hAxMain,model,xAxis,'ExpSum',this.dynVisParams,this.visualizationParams,'Model',lStr);
            end
            
            %% IRF
            irf = apObj.getIRF(ch);
            if(this.visualizationParams.plotIRF)                
%                 irfPlot = mObj.compShift(irf,length(irf),mObj.dLen,mObj.mMaxPos - mObj.iMaxPos);
            if(isempty(model))
                irfPlot = max(data).*irf./max(irf);
            else
                irfPlot = max(model).*irf./max(irf) + oset;
            end
                irfPlot(irfPlot < 1e-1) = 1e-1;
                lStr = this.makeModelPlot(hAxMain,irfPlot,xAxis,'IRF',this.dynVisParams,this.visualizationParams,'IRF',lStr);
            end            
            tci = zeros(1,apObj.basicParams.nExp);
            tci(logical(apObj.basicParams.tciMask)) = x_vec(2*apObj.basicParams.nExp+1 : 2*apObj.basicParams.nExp+sum(apObj.basicParams.tciMask))';
            
            %% display parameters on the right side
            tableInfo = this.makeParamTable(hTableInfo,x_vec,tci,oset,chi2,chi2Tail,iterations,time,TotalPhotons,apObj);
            
            %% display x & y
            set(this.visHandles.editX,'String',x);
            set(this.visHandles.editY,'String',y);
            
            %% counts scaling
            if(~this.dynVisParams.countsScalingAuto)
                ylim(hAxMain,[this.dynVisParams.countsScalingStart this.dynVisParams.countsScalingEnd]);
            end
            
            %% no parameters computed
            if(sum(x_vec(:)) == 0)
                cla(this.visHandles.axesRes);
                cla(this.visHandles.axesResHis);
                if(this.visualizationParams.showLegend)
                    this.makeLegend(hAxMain,lStr)
                end
                return;
            end
            
            %% we have parameters, plot exponentials
            if(this.visualizationParams.plotExp)
                [lStr, exponentials] = this.makeExponentialsPlot(hAxMain,xAxis,apObj,x_vec,lStr,this.dynVisParams,this.visualizationParams);
            end
            %% optimizer initialization (guess)
            if(this.visualizationParams.plotInit)
                if(sum(iVec(:)) == 0)
                    model = [];
                else
                    apObj.compModel(splitXVec(iVec,apObj.volatile.cMask));
                    model = apObj.model(1:apObj.dLen);
                    model(model < 1e-1) = 1e-1;
                end
                lStr = this.makeModelPlot(hAxMain,model,xAxis,'Init',this.dynVisParams,this.visualizationParams,'Init Guess',lStr);
            end
            %% start + end position
            if(this.visualizationParams.plotStartEnd)
                [sp, ep] = apObj.getStartEndPos(ch);
                lStr = this.makeVerticalLinePlot(hAxMain,sp,xAxis,'StartEnd',this.dynVisParams,this.visualizationParams,'StartPosition',lStr);
                lStr = this.makeVerticalLinePlot(hAxMain,ep,xAxis,'StartEnd',this.dynVisParams,this.visualizationParams,'EndPosition',lStr);
            end
            %% slope position
            if(this.visualizationParams.plotSlope)
                lStr = this.makeVerticalLinePlot(hAxMain,slopeStart,xAxis,'Slope',this.dynVisParams,this.visualizationParams,'SlopeStart',lStr);                
            end
            %legend
            if(this.visualizationParams.showLegend)
                this.makeLegend(hAxMain,lStr);
            end
            
            [residuum residuumHist] = this.visRes(ch,y,x,apObj,hAxRes,hAxResHis);
        end
        
        function [e_vec rh] = visRes(this,ch,y,x,apObj,hAxRes,hAxResHis)
            %% plot error vector
            if(isempty(apObj))
                [apObj x_vec] = this.getVisParams(ch,y,x);
            else
                [~, x_vec] = this.getVisParams(ch,y,x);
            end
            if(sum(x_vec(:)) == 0)
                cla(this.visHandles.axesRes);
                set(this.visHandles.editResScal,'String','');
                axis(hAxRes,'off');
                axis(hAxResHis,'off');
                return
            end
            %% check handles
            if(nargin < 7 || ~ishandle(hAxResHis))
                hAxResHis = this.visHandles.axesResHis;
            end
            if(nargin < 6 || ~ishandle(hAxRes))
                hAxRes = this.visHandles.axesRes;
            end
            axis(hAxRes,'on');
            %% prepare            
            model = apObj.getModel(ch,x_vec);
            data = apObj.getMeasurementData(ch);
            xAxis = this.FLIMXObj.curSubject.timeVector(1:length(data));
            e_vec = zeros(length(data),1);
            %e_vec(1:apObj.getFileInfo(ch).nrTimeChannels) = ((data(1:apObj.getFileInfo(ch).nrTimeChannels))-(model(1:apObj.getFileInfo(ch).nrTimeChannels)))./(model(1:apObj.getFileInfo(ch).nrTimeChannels))*100;
            e_vec(1:apObj.getFileInfo(ch).nrTimeChannels) = ((data(1:apObj.getFileInfo(ch).nrTimeChannels))-(model(1:apObj.getFileInfo(ch).nrTimeChannels)))./sqrt(data(1:apObj.getFileInfo(ch).nrTimeChannels)); % Weighting in lsqnonlin is 1/std; in Poisson statistics: 1/sqrt(counts)
            nz_idx =  apObj.getDataNonZeroMask(ch);
            ds = find(nz_idx,1,'first');
            de = find(nz_idx,1,'last');
            [StartPosition, EndPosition] = apObj.getStartEndPos(ch);
            nz_idx(1:StartPosition) = false;
            nz_idx(EndPosition:end) = false;
            e_vec_smooth = e_vec;
            e_vec_smooth(ds:de) = fastsmooth(e_vec(ds:de),50,3,0);
            e_vec_smooth(1:ds) = e_vec_smooth(ds);
            e_vec_smooth(de:end) = e_vec_smooth(de);
            if(~this.dynVisParams.timeScalingAuto)
                e_vec = e_vec(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
                e_vec_smooth = e_vec_smooth(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
                xAxis = xAxis(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
                nz_idx = nz_idx(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
                StartPosition = StartPosition-this.dynVisParams.timeScalingStart+1;
                EndPosition = EndPosition-this.dynVisParams.timeScalingStart+1;
            end            
            cla(hAxRes);
            hold(hAxRes,'on');
            idx = measurementFile.getMaskGrps(find(nz_idx > 0));
            if(isempty(idx)) %empty data
                plot(hAxRes,xAxis,e_vec,'linewidth',2,'color',[0 0 0]);
            else
                if(idx(1,1) > 1) %plot first 'black' part
                    plot(hAxRes,xAxis(1:idx(1,1)-1),e_vec(1:idx(1,1)-1),'linewidth',2,'color',[0 0 0]);
                end
                for cnt = 1:size(idx,1) %plot 'black' and 'red' parts
                    plot(hAxRes,xAxis(idx(cnt,1):idx(cnt,2)),e_vec(idx(cnt,1):idx(cnt,2)),'linewidth',2,'color','red');
                    if(cnt > 1)
                        plot(hAxRes,xAxis(idx(cnt-1,2):idx(cnt,1)),e_vec(idx(cnt-1,2):idx(cnt,1)),'linewidth',2,'color',[0 0 0]);
                    end
                end
                plot(hAxRes,xAxis(idx(end,2):end),e_vec(idx(end,2):end),'linewidth',2,'color',[0 0 0]); %plot remaining 'black' part
            end            
            plot(hAxRes,xAxis,e_vec_smooth,'linewidth',1,'color',[1.0000 0.8125 0]);
            hold(hAxRes,'off');
            e_vec_nz = e_vec(nz_idx > 0);
            if(this.resScaleFlag)
                %auto scaling
                if(~isempty(e_vec_nz))
                    yl = round(max(abs(e_vec_nz(:))));
                else
                    yl = round(max(abs(e_vec(:))));
                end
                if(yl < eps || isinf(yl) || isnan(yl)) %==0
                    yl = 1;
                end
                set(this.visHandles.editResScal,'String',num2str(yl,'%d'));
            else
                %manual scaling
                yl = this.resScaleValue;
                set(this.visHandles.editResScal,'String',num2str(yl,'%d'));
            end
            xlim(hAxRes,[xAxis(1) xAxis(end)]);
            if(~isnan(yl))
                ylim(hAxRes,[-yl yl]);
            end
            %% lines for start and end
            if(this.visualizationParams.plotStartEnd)
                this.makeVerticalLinePlot(hAxRes,StartPosition,xAxis,'StartEnd',this.dynVisParams,this.visualizationParams,'',[]);
                this.makeVerticalLinePlot(hAxRes,EndPosition,xAxis,'StartEnd',this.dynVisParams,this.visualizationParams,'',[]);
            end
            ylabel(hAxRes,'Norm. Error');
            xlabel(hAxRes,'Time (ns)');
            grid(hAxRes,'on');
            %% residuum histogram
            nc = round(max(3,min(numel(e_vec_nz)/10,100)));
            nc = nc + rem(nc,2)+1;
            binVec = linspace(-yl,yl,nc);
            rh = hist(e_vec_nz,binVec);
            if(any(rh))
                bh = barh(hAxResHis,binVec,rh,'hist');
                xlim(hAxResHis,[0 max(rh(:))]);
                ylim(hAxResHis,[-yl yl]);
                set(bh,'FaceColor','r','LineStyle','none');
                set(hAxResHis,'XTickLabel','');
                set(hAxResHis,'YTickLabel','');
            else
                cla(hAxResHis)
                axis(hAxResHis,'off');
            end
            %% residuum statistics
        end
        
        function plotRawData(this,handle,data)
            %visualize raw data
            if(nargin == 2)
                data = this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel);
            end
            if(isempty(handle) && ~this.isOpenVisWnd())
                return;
            end
            if(isempty(handle))
                this.plotRawData(this.visHandles.axesMain);
                this.plotRawData(this.visHandles.axesRaw);
                set(this.visHandles.textCbRawTop,'String',max(data(:)));
                set(this.visHandles.textCbRawBottom,'String',min(data(:)));
                return;
            end
            cla(handle);
            if(isempty(data))
                return
            end
            lb = prctile(data(:),0.1);
            ub = prctile(data(:),99.9);
            img = image2ColorMap(data,this.dynVisParams.cmIntensity,lb,ub);
%             if(lb == ub || isnan(lb) || isnan(ub))
                image(img,'Parent',handle);
%             else
%                 imagesc(img,'Parent',handle,[lb ub]);
%             end  
            [r, c] = size(data);
            if(~isnan(r) && ~isnan(c) && size(data,1) > 1 && size(data,2) > 1)
                xlim(handle,[1 size(data,2)])
                ylim(handle,[1 size(data,1)])
            end
            set(handle,'YDir','normal');
            %lables
            xlbl = 1:1:c;
            ylbl = 1:1:r;
            xtick = get(handle,'XTick');
            idx = abs(fix(xtick)-xtick)<eps; %only integer labels
            pos = xtick(idx);
            xCell = cell(length(xtick),1);
            xCell(idx) = num2cell(xlbl(pos));
            ytick = get(handle,'YTick');
            idx = abs(fix(ytick)-ytick)<eps; %only integer labels
            pos = ytick(idx);
            yCell = cell(length(ytick),1);
            yCell(idx) = num2cell(ylbl(pos));
            set(handle,'XTickLabel',xCell,'YTickLabel',yCell);            
            
            this.visHandles.rawPlotTopLine = -1;
            this.visHandles.rawPlotBottomLine = -1;
            this.visHandles.rawPlotLeftLine = -1;
            this.visHandles.rawPlotRightLine = -1;
            this.visHandles.rawPlotCPXLine = -1;
            this.visHandles.rawPlotCPYtLine = -1;
        end
        
        function plotRawDataROI(this,handle,roi)
            %plot the current ROI in raw data plot
            if(isempty(handle) && ~this.isOpenVisWnd())
                return;
            end
            if(isempty(handle))
                this.plotRawDataROI(this.visHandles.axesMain,[]);
                this.plotRawDataROI(this.visHandles.axesRaw,[]);
                return;
            end
            if(isempty(roi) && ~isempty(this.FLIMXObj.curSubject.ROICoordinates))
                roi = this.FLIMXObj.curSubject.ROICoordinates; %x1 x2 y1 y2
            end
            if(~isempty(roi))
                %top
                if(isfield(this.visHandles,'rawPlotTopLine') && ishandle(this.visHandles.rawPlotTopLine))
                    delete(this.visHandles.rawPlotTopLine(ishandle(this.visHandles.rawPlotTopLine)));
                    this.visHandles.rawPlotTopLine = -1;
                end
                this.visHandles.rawPlotTopLine = line('XData',[roi(1) roi(2)],'YData',[roi(4) roi(4)],'Color','w','LineWidth',2,'LineStyle','-','Parent',handle);
                %bottom
                if(isfield(this.visHandles,'rawPlotBottomLine') && ishandle(this.visHandles.rawPlotBottomLine))
                    delete(this.visHandles.rawPlotBottomLine(ishandle(this.visHandles.rawPlotBottomLine)));
                    this.visHandles.rawPlotBottomLine = -1;
                end
                this.visHandles.rawPlotBottomLine = line('XData',[roi(2) roi(1)],'YData',[roi(3) roi(3)],'Color','w','LineWidth',2,'LineStyle','-','Parent',handle);
                %left
                if(isfield(this.visHandles,'rawPlotLeftLine') && ishandle(this.visHandles.rawPlotLeftLine))
                    delete(this.visHandles.rawPlotLeftLine(ishandle(this.visHandles.rawPlotLeftLine)));
                    this.visHandles.rawPlotLeftLine = -1;
                end
                this.visHandles.rawPlotLeftLine = line('XData',[roi(1) roi(1)],'YData',[roi(3) roi(4)],'Color','w','LineWidth',2,'LineStyle','-','Parent',handle);
                %right
                if(isfield(this.visHandles,'rawPlotRightLine') && ishandle(this.visHandles.rawPlotRightLine))
                    delete(this.visHandles.rawPlotRightLine(ishandle(this.visHandles.rawPlotRightLine)));
                    this.visHandles.rawPlotRightLine = -1;
                end
                this.visHandles.rawPlotRightLine = line('XData',[roi(2) roi(2)],'YData',[roi(4) roi(3)],'Color','w','LineWidth',2,'LineStyle','-','Parent',handle);
            end
        end
        
        function plotRawDataCP(this,handle,roi)
            %plot current point in raw data plot
            if(isempty(handle) && ~this.isOpenVisWnd())
                return;
            end
            if(isempty(handle))
                this.plotRawDataCP(this.visHandles.axesMain,[]);
                this.plotRawDataCP(this.visHandles.axesRaw,[]);
                return;
            end
            if(isempty(roi) && ~isempty(this.FLIMXObj.curSubject.ROICoordinates))
                roi = this.FLIMXObj.curSubject.ROICoordinates; %x1 x2 y1 y2
            end
            if(~isempty(roi))
                if(ishandle(this.visHandles.rawPlotCPXLine))
                    delete(this.visHandles.rawPlotCPXLine)
                end
                this.visHandles.rawPlotCPXLine = line('XData',[this.currentX+roi(1)-1 this.currentX+roi(1)-1],'YData',[1 size(this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel),1)],'Color','w','LineWidth',2,'LineStyle',':','Parent',handle);
                if(ishandle(this.visHandles.rawPlotCPYLine))
                    delete(this.visHandles.rawPlotCPYLine)
                end
                this.visHandles.rawPlotCPYLine = line('XData',[1 size(this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel),2)],'YData',[this.currentY+roi(3)-1 this.currentY+roi(3)-1],'Color','w','LineWidth',2,'LineStyle',':','Parent',handle);
            end
        end
        
        function plotSuppData(this,handle,data)
            %visualize raw data
            if(nargin == 2)
                data = this.axesSuppData;
            end
            if(isempty(handle) && ~this.isOpenVisWnd())
                return;
            end
            if(isempty(handle))
                this.plotSuppData(this.visHandles.axesCurMain);
                this.plotSuppData(this.visHandles.axesCurSupp);
                set(this.visHandles.textCbSuppTop,'String',max(data(:)));
                set(this.visHandles.textCbSuppBottom,'String',min(data(:)));
                return;
            end
            [r, c] = size(data);
            cla(handle);
            ylabel(handle,'');
            legend(handle,'off');
            if(isempty(data))
                return
            end
            lb = prctile(data(:),0.1);
            ub = prctile(data(:),99.9);
            img = image2ColorMap(data,this.dynVisParams.cm,lb,ub);
%             if(lb == ub || isnan(lb) || isnan(ub))
                image(img,'Parent',handle);
%             else
%                 imagesc(data,'Parent',handle,[lb ub]);
%             end
            set(handle,'YDir','normal');
            set(handle,'Yscale','linear');
            if(c > 1 && r > 1)
                axis(handle,[1 c 1 r]);
            end
            %lables            
            xlbl = 1:1:c;
            ylbl = 1:1:r;
            xtick = get(handle,'XTick');
            idx = abs(fix(xtick)-xtick)<eps & xtick > 0 & xtick < c; %only integer labels
            pos = xtick(idx);
            xCell = cell(length(xtick),1);
            xCell(idx) = num2cell(xlbl(pos));
            ytick = get(handle,'YTick');
            idx = abs(fix(ytick)-ytick)<eps & ytick > 0 & ytick < r; %only integer labels
            pos = ytick(idx);
            yCell = cell(length(ytick),1);
            yCell(idx) = num2cell(ylbl(pos));
            set(handle,'XTickLabel',xCell,'YTickLabel',yCell);
            this.visHandles.roiPlotCPXLine = -1;
            this.visHandles.roiPlotCPYLine = -1;
        end
        
        function plotSuppDataCP(this,handle)
            %plot current point in raw data plot
            if(~this.isOpenVisWnd())
                return;
            end
            if(isempty(handle))
                this.plotSuppDataCP(this.visHandles.axesCurMain);
                this.plotSuppDataCP(this.visHandles.axesCurSupp);
                return;
            end
            data = this.axesSuppData;
            if(ishandle(this.visHandles.roiPlotCPXLine))
                delete(this.visHandles.roiPlotCPXLine)
            end
            this.visHandles.roiPlotCPXLine = line('XData',[this.currentX this.currentX],'YData',[1 size(data,1)],'Color','w','LineWidth',2,'LineStyle',':','Parent',handle);
            if(ishandle(this.visHandles.roiPlotCPYLine))
                delete(this.visHandles.roiPlotCPYLine)
            end
            this.visHandles.roiPlotCPYLine = line('XData',[1 size(data,2)],'YData',[this.currentY this.currentY],'Color','w','LineWidth',2,'LineStyle',':','Parent',handle);
        end
        
        function clearAllPlots(this)
            %clean up all axes
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            cla(this.visHandles.axesMain);
            cla(this.visHandles.axesRaw);
            cla(this.visHandles.axesSupp);
            this.visHandles.rawPlotTopLine = [];
            this.visHandles.rawPlotBottomLine = [];
            this.visHandles.rawPlotLeftLine = [];
            this.visHandles.rawPlotRightLine = [];
            this.visHandles.roiPlotCPXLine = [];
            this.visHandles.roiPlotCPYLine = [];
            set(this.visHandles.textCbRawTop,'String','');
            set(this.visHandles.textCbRawBottom,'String','');
            set(this.visHandles.textCbSuppTop,'String','');
            set(this.visHandles.textCbSuppBottom,'String','');
            set(this.visHandles.tableParam,'Data','');
        end
        
        function showFitResult(this,y,x)
            %update main and cuts axes
            %decay plot
            if(nargin == 3)
                this.currentY = y;
                this.currentX = x;
            end
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
            this.plotRawDataROI(this.visHandles.axesRaw,[]);
            this.plotRawDataCP(this.visHandles.axesRaw,[]);
            this.plotSuppDataCP(this.visHandles.axesCurSupp);
        end
        
        %% GUI callbacks
        function GUI_buttonLeft_Callback(this,hObject,eventdata)
            %call of editX control
            set(this.visHandles.editX,'String',this.currentX-1);
            this.GUI_editX_Callback(this.visHandles.editX,[]);
        end
        
        function GUI_popupStudy_Callback(this,hObject,eventdata)
            %callback to change subject name
            try
                set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/></html>',fullfile(cd,'functions','visualization','spinner.gif')));
                drawnow;
            end
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,'-');
            if(~isempty(subjects) && iscell(subjects))
                cs = subjects{min(get(this.visHandles.popupSubject,'Value'),length(subjects))};
                set(this.visHandles.popupView,'Value',1);
                this.FLIMXObj.setCurrentSubject(this.currentStudy,'-',cs);
                %             else
                %                 this.FLIMXObj.newSDTFile('');
                %                 this.setupGUI();
                %                 this.updateGUI(true);
            end
            set(this.visHandles.buttonStop,'String','Stop');
        end
        
        function GUI_popupSubject_Callback(this,hObject,eventdata)
            %callback to change subject name
            try
                set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/></html>',fullfile(cd,'functions','visualization','spinner.gif')));
                drawnow;
            end
            this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentView,this.currentSubject);
            set(this.visHandles.buttonStop,'String','Stop');
        end
        
        function GUI_popupView_Callback(this,hObject,eventdata)
            %callback to change the current view
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentView);
            if(~isempty(subjects) && iscell(subjects))
                idx = find(strcmp(subjects,this.currentSubject), 1);
                if(~isempty(idx))
                    %last subject is also a member of the new view -> just update the GUI controls
                    this.setupGUI();
                else
                    %last subject is not a member of the new view -> choose a different subject
                    this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentView,subjects{min(get(this.visHandles.popupSubject,'Value'),length(subjects))});
                end
            end
        end
        
        function GUI_editX_Callback(this,hObject,eventdata)
            %callback of editX control
            this.currentX = max(min(round(abs(str2double(get(hObject,'String')))),this.maxX),1);
            set(hObject,'String',this.currentX);
            if(get(this.visHandles.checkAutoFitPixel,'Value') && ~this.FLIMXObj.curSubject.isPixelResult(this.currentChannel,this.currentY,this.currentX,this.showInitialization))
                %automatically fit current pixel when activated
                this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
            else
                this.updateGUI(0);
            end
        end
        
        function GUI_checkAutoFitPixel_Callback(this,hObject,eventdata)
            %checkbox to automatically fit current pixel when activated
            if(get(hObject,'Value'))
                this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
            end
        end
        
        function GUI_buttonSwitchSubject_Callback(this,hObject,eventdata)
            %button to switch subject up or down
            oldVal = get(this.visHandles.popupSubject,'Value');
            switch get(hObject,'Tag')
                case 'buttonSubjectDec'
                    newVal = max(1,oldVal-1);
                case 'buttonSubjectInc'
                    newVal = min(length(get(this.visHandles.popupSubject,'String')),oldVal+1);
                otherwise
                    return
            end
            if(newVal ~= oldVal)
                set(this.visHandles.popupSubject,'Value',newVal);
                this.GUI_popupSubject_Callback(this.visHandles.popupSubject,[]);
            end
        end
        
        function GUI_buttonRight_Callback(this,hObject,eventdata)
            %call of editX control
            set(this.visHandles.editX,'String',this.currentX+1);
            this.GUI_editX_Callback(this.visHandles.editX,[]);
        end
        
        function GUI_buttonDown_Callback(this,hObject,eventdata)
            %call of editY control
            set(this.visHandles.editY,'String',this.currentY-1);
            this.GUI_editY_Callback(this.visHandles.editY,[]);
        end
        
        function GUI_editY_Callback(this,hObject,eventdata)
            %callback of editY control
            this.currentY = max(min(round(abs(str2double(get(hObject,'String')))),this.maxY),1);
            set(hObject,'String',this.currentY);
            if(get(this.visHandles.checkAutoFitPixel,'Value') && ~this.FLIMXObj.curSubject.isPixelResult(this.currentChannel,this.currentY,this.currentX,this.showInitialization)) 
                %automatically fit current pixel when activated
                this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
            else
                this.updateGUI(0);
            end
        end
        
        function GUI_buttonUp_Callback(this,hObject,eventdata)
            %call of editY control
            set(this.visHandles.editY,'String',this.currentY+1);
            this.GUI_editY_Callback(this.visHandles.editY,[]);
        end
        
        function menuExportScreenshot_Callback(this,hObject,eventdata)
            %call of Screenshot button control
            formats = {'*.png','Portable Network Graphics (*.png)';...
                '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                '*.eps','Encapsulated Postscript (*.eps)';...
                '*.tiff','TaggedImage File Format (*.tiff)';...
                '*.bmp','Windows Bitmap (*.bmp)';...
                '*.emf','Windows Enhanced Metafile (*.emf)';...
                '*.pdf','Portable Document Format (*.pdf)';...
                '*.fig','MATLAB figure (*.fig)';...
                };
            [file, path, filterindex] = uiputfile(formats,'Export as','image.png');
            if ~path ; return ; end
            fn = fullfile(path,file);
            
            switch filterindex
                case 5
                    str = '-dbmp';
                case 6
                    str = '-dmeta';
                case 3
                    str = '-depsc2';
                case 2
                    str = '-djpeg';
                case 7
                    str = '-dpdf';
                case 1
                    str = '-dpng';
                case 4
                    str = '-dtiff';
            end
            if(filterindex == 8)
                hgsave(this.visHandles.FLIMXFitGUIFigure,fn);
            else
                print(this.visHandles.FLIMXFitGUIFigure,str,['-r' num2str(this.exportParams.dpi)],fn);
            end
            %saveas(this.visHandles.FLIMXFitGUIFigure,fn,str);
        end
        
        
        function GUI_buttonStop_Callback(this,hObject,eventdata)
            %call of buttonStop control
            this.FLIMXObj.FLIMFit.stopOptimization(true);
        end
        
        function GUI_buttonToggle_Callback(this,hObject,eventdata)
            %call of toggle button control
            if(get(this.visHandles.buttonToggle,'Value'))
                this.axesROIMgr.setMainAxes(this.visHandles.axesMain);
            else
                this.axesROIMgr.setMainAxes(this.visHandles.axesSupp);
            end
            this.updateGUI(0);
        end
        
        function GUI_buttonResScal_Callback(this,hObject,eventdata)
            %call of buttons for residuum scaling control
            delta = 0.1;
            factor = 1;
            if(hObject == this.visHandles.buttonResScalDec)
                factor = -1;
            end
            delta = round(this.resScaleValue * delta);
            dec = fix(log10(delta));
            delta = max(10^dec*round(delta/10^dec),1);
            this.resScaleValue = this.resScaleValue+delta*factor;
            this.visRes(this.currentChannel,this.currentY,this.currentX,[]);
        end
        
        function GUI_buttonTimeScal_Callback(this,hObject,eventdata)
            %call of button for time scaling control
            switch(hObject)
                case this.visHandles.buttonTimeScalStartInc
                    this.dynVisParams.timeScalingStart = max(min(this.dynVisParams.timeScalingStart +1,this.dynVisParams.timeScalingEnd-1),1);
                    set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalStartDec
                    this.dynVisParams.timeScalingStart = max(min(this.dynVisParams.timeScalingStart -1,this.dynVisParams.timeScalingEnd-1),1);
                    set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalEndInc
                    this.dynVisParams.timeScalingEnd = min(max(this.dynVisParams.timeScalingEnd+1,this.dynVisParams.timeScalingStart+1),this.FLIMXObj.curSubject.nrTimeChannels);
                    set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalEndDec
                    this.dynVisParams.timeScalingEnd = min(max(this.dynVisParams.timeScalingEnd-1,this.dynVisParams.timeScalingStart+1),this.FLIMXObj.curSubject.nrTimeChannels);
                    set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
            end
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_buttonCountsScal_Callback(this,hObject,eventdata)
            %call of button for Counts scaling control
            switch(hObject)
                case this.visHandles.buttonCountsScalStartInc
                    this.dynVisParams.countsScalingStart = max(min(this.dynVisParams.countsScalingStart*1.1,this.dynVisParams.countsScalingEnd*1.1),0.01);
                    set(this.visHandles.editCountsScalStart,'String',num2str(this.dynVisParams.countsScalingStart,'%G'));
                case this.visHandles.buttonCountsScalStartDec
                    this.dynVisParams.countsScalingStart = max(min(this.dynVisParams.countsScalingStart*0.9,this.dynVisParams.countsScalingEnd*0.9),0.01);
                    set(this.visHandles.editCountsScalStart,'String',num2str(this.dynVisParams.countsScalingStart,'%G'));
                case this.visHandles.buttonCountsScalEndInc
                    this.dynVisParams.countsScalingEnd = max(this.dynVisParams.countsScalingEnd+1000,this.dynVisParams.countsScalingStart+1);
                    set(this.visHandles.editCountsScalEnd,'String',num2str(this.dynVisParams.countsScalingEnd,'%G'));
                case this.visHandles.buttonCountsScalEndDec
                    this.dynVisParams.countsScalingEnd = max(this.dynVisParams.countsScalingEnd-1000,this.dynVisParams.countsScalingStart+1);
                    set(this.visHandles.editCountsScalEnd,'String',num2str(this.dynVisParams.countsScalingEnd,'%G'));
            end
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_editResScal_Callback(this,hObject,eventdata)
            %call of editResScal control
            current = max(round(abs(str2double(get(hObject,'String')))),1);
            this.resScaleValue = current;
            set(hObject,'String',num2str(current));
            this.visRes(this.currentChannel,this.currentY,this.currentX,[]);
        end
        
        function GUI_editTimeScal_Callback(this,hObject,eventdata)
            %call of editTimeScal control
            current = round(abs(str2double(get(hObject,'String')))/this.FLIMXObj.curSubject.timeChannelWidth);
            if(hObject == this.visHandles.editTimeScalStart)
                current = max(min(current,this.dynVisParams.timeScalingEnd-1),1);
                this.dynVisParams.timeScalingStart = current;
            else
                current = min(max(current,this.dynVisParams.timeScalingStart+1),this.FLIMXObj.curSubject.nrTimeChannels);
                this.dynVisParams.timeScalingEnd = current;
            end
            set(hObject,'String',num2str(current*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_editCountsScal_Callback(this,hObject,eventdata)
            %call of editCountsScal control
            current = abs(str2double(get(hObject,'String')));
            if(hObject == this.visHandles.editCountsScalStart)
                current = max(min(current,this.dynVisParams.countsScalingEnd-1),0.01);
                this.dynVisParams.countsScalingStart = current;
            else
                current = max(current,this.dynVisParams.countsScalingStart+1);
                this.dynVisParams.countsScalingEnd = current;
            end
            set(hObject,'String',num2str(current,'%G'));
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_showMerge_Callback(this,hObject,eventdata)
            %toggle between merge display and pixel display
            this.setupGUI();
            this.updateGUI(true);
%             this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_popupChannel_Callback(this,hObject,eventdata)
            %change the current channel of the GUI
            this.currentChannel = get(hObject,'Value');
        end
        
        function GUI_popupROI_Callback(this,hObject,eventdata)
            %call of popupROI control
            this.updateGUI(true);
        end
        
        function GUI_radioResScal_Callback(this,hObject,eventdata)
            %call of radioResScal control
            if(hObject == this.visHandles.radioResScalAuto)
                set(this.visHandles.radioResScalManual,'Value',~get(this.visHandles.radioResScalAuto,'Value'));
            else
                set(this.visHandles.radioResScalAuto,'Value',~get(this.visHandles.radioResScalManual,'Value'));
            end
            this.resScaleFlag = get(this.visHandles.radioResScalAuto,'Value');
            flag = 'on';
            if(this.resScaleFlag)
                flag = 'off';
            end
            set(this.visHandles.buttonResScalDec,'Enable',flag);
            set(this.visHandles.buttonResScalInc,'Enable',flag);
            set(this.visHandles.editResScal,'Enable',flag);
            this.visRes(this.currentChannel,this.currentY,this.currentX,[]);
        end
        
        function GUI_radioTimeScal_Callback(this,hObject,eventdata)
            %call of radioTimeScal control
            if(hObject == this.visHandles.radioTimeScalAuto)
                set(this.visHandles.radioTimeScalManual,'Value',~get(this.visHandles.radioTimeScalAuto,'Value'));
            else
                set(this.visHandles.radioTimeScalAuto,'Value',~get(this.visHandles.radioTimeScalManual,'Value'));
            end
            this.dynVisParams.timeScalingAuto = get(this.visHandles.radioTimeScalAuto,'Value');
            flag = 'off';
            if(~this.dynVisParams.timeScalingAuto)
                flag = 'on';
                set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
                set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.FLIMXObj.curSubject.timeChannelWidth,'%.02f'));
            end
            set(this.visHandles.buttonTimeScalStartDec,'Enable',flag);
            set(this.visHandles.buttonTimeScalStartInc,'Enable',flag);
            set(this.visHandles.buttonTimeScalEndDec,'Enable',flag);
            set(this.visHandles.buttonTimeScalEndInc,'Enable',flag);
            set(this.visHandles.editTimeScalStart,'Enable',flag);
            set(this.visHandles.editTimeScalEnd,'Enable',flag);
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_radioCountsScal_Callback(this,hObject,eventdata)
            %call of radioCountsScal control
            if(hObject == this.visHandles.radioCountsScalAuto)
                set(this.visHandles.radioCountsScalManual,'Value',~get(this.visHandles.radioCountsScalAuto,'Value'));
            else
                set(this.visHandles.radioCountsScalAuto,'Value',~get(this.visHandles.radioCountsScalManual,'Value'));
            end
            this.dynVisParams.countsScalingAuto = get(this.visHandles.radioCountsScalAuto,'Value');
            flag = 'off';
            if(~this.dynVisParams.countsScalingAuto)
                flag = 'on';
                set(this.visHandles.editCountsScalStart,'String',num2str(this.dynVisParams.countsScalingStart,'%G'));
                set(this.visHandles.editCountsScalEnd,'String',num2str(this.dynVisParams.countsScalingEnd,'%G'));
            end
            set(this.visHandles.buttonCountsScalStartDec,'Enable',flag);
            set(this.visHandles.buttonCountsScalStartInc,'Enable',flag);
            set(this.visHandles.buttonCountsScalEndDec,'Enable',flag);
            set(this.visHandles.buttonCountsScalEndInc,'Enable',flag);
            set(this.visHandles.editCountsScalStart,'Enable',flag);
            set(this.visHandles.editCountsScalEnd,'Enable',flag);
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_mouseMotion_Callback(this,hObject,eventdata)
            %executes on mouse move in window
            if(isMultipleCall)
                return
            end
            persistent inFunction
            if ~isempty(inFunction), return; end
            inFunction = 1;  %prevent callback re-entry
            %update at most 50 times per second (every 0.02 sec)
            persistent lastUpdate
            try
                tNow = datenummx(clock);  %fast
            catch
                tNow = now;  %slower
            end
            oneSec = 1/24/60/60;
            if ~isempty(lastUpdate) && tNow - lastUpdate < 0.02*oneSec
                inFunction = [];  %enable callback
                return;
            end
            lastUpdate = tNow;
            cp = get(this.visHandles.axesCurSupp,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                %outside axes
                set(this.visHandles.FLIMXFitGUIFigure,'Pointer','arrow');
                set(this.visHandles.editX,'String',num2str(this.currentX));
                set(this.visHandles.editY,'String',num2str(this.currentY));
                %update current point edit
                data = this.axesSuppData;
                if(~isempty(data))
                    set(this.visHandles.editCPSupp,'String',FLIMXFitGUI.num4disp(data(min(size(data,1),this.currentY),min(size(data,2),this.currentX))));
                end
                inFunction = [];
                return;
            end
            %pos = get(this.visHandles.axesCurSupp,'Position');            
            cp=fix(cp+0.52);
            if(cp(1) >= 1 && cp(1) <= this.maxX && cp(2) >= 1 && cp(2) <= this.maxY)
                %inside axes
                set(this.visHandles.FLIMXFitGUIFigure,'Pointer','cross');
                set(this.visHandles.editX,'String',num2str(cp(1)));
                set(this.visHandles.editY,'String',num2str(cp(2)));
                %update current point edit
                data = this.axesSuppData;
                if(~isempty(data))
                    set(this.visHandles.editCPSupp,'String',FLIMXFitGUI.num4disp(data(min(size(data,1),cp(2)),min(size(data,2),cp(1)))));
                end
            else
                set(this.visHandles.FLIMXFitGUIFigure,'Pointer','arrow');
                set(this.visHandles.editX,'String',num2str(this.currentX));
                set(this.visHandles.editY,'String',num2str(this.currentY));
            end  
            inFunction = []; %enable callback
        end
                
        function GUI_mouseButtonUp_Callback(this,hObject,eventdata)
            %executes on click in window
            cp = get(this.visHandles.axesCurSupp,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            this.currentX = max(min(round(abs(str2double(get(this.visHandles.editX,'String')))),this.maxX),1);
            this.currentY = max(min(round(abs(str2double(get(this.visHandles.editY,'String')))),this.maxY),1);
            if(get(this.visHandles.checkAutoFitPixel,'Value') && ~this.FLIMXObj.curSubject.isPixelResult(this.currentChannel,this.currentY,this.currentX,this.showInitialization))
                %automatically fit current pixel when activated
                this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
            else
                this.updateGUI(0);
            end
        end
        
        %% menu callbacks        
%         function menuImportResult_Callback(this,hObject,eventdata)
%             %call of load result menu item
%             this.openResultFile();
%         end
        
        function menuExportFiles_Callback(this,hObject,eventdata)
            %write results to disc (again)
            expDir = uigetdir(cd);
            if(isempty(expDir))
                return
            end
            %save to disc
            this.FLIMXObj.curSubject.exportMatFile([],expDir);
        end
        
        function menuExportExcel_Callback(this,hObject,eventdata)
            %
            formats = {'*.xls','Excel File (*.xls)'};
            [file, path] = uiputfile(formats,'Export as');
            if ~path ; return ; end
            fn = fullfile(path,file);
            %save fit
            [xAxis, data, irf, model, exponentials, residuum, residuumHist, tableInfo] = this.visCurFit(this.currentChannel,this.currentY,this.currentX);
            exponentials = exponentials(:,1:end-1);
            tmp = num2cell([xAxis,data,irf,model,residuum,exponentials]);
            tmp(1:length(residuumHist),end+1) = num2cell(residuumHist);
            colHead = {'t','Measured','IRF','Model','Residuum'};
            for i = 1:size(exponentials,2)
                colHead(end+1) = {sprintf('Exp. %d',i)};
            end
            %colHead(end+1) = {'Residuum'};
            colHead(end+1) = {'Residuum Histogram'};
            exportExcel(fn,tmp,colHead,'',sprintf('%s ch%d (y%d,x%d)',this.FLIMXObj.curSubject.getDatasetName(),this.currentChannel,this.currentY,this.currentX),'');
            %save table info
            tableInfo(end+2,:) = {'x',this.currentX,'y',this.currentY};
            exportExcel(fn,tableInfo,'','',sprintf('Table %s ch%d (y%d,x%d)',this.FLIMXObj.curSubject.getDatasetName(),this.currentChannel,this.currentY,this.currentX),'');
        end
        
        function menuParaSetMgr_Callback(this,hObject,eventdata)
            %callback to open parameter set manager
            this.volatileParamsetMgr.checkVisWnd();
        end
        
        function menuSimFLIM_Callback(this,hObject,eventdata)
            %open simulation tool
            this.simTool.checkVisWnd();
        end
        
        function menuSimAnalysis_Callback(this,hObject,eventdata)
            %open tool to compare simualtion parameters with fit results
            this.simCompTool.checkVisWnd();
        end
        
        function menuIRFMgr_Callback(this,hObject,eventdata)
            %open tool to manage IRFs
            this.FLIMXObj.irfMgrGUI.checkVisWnd();
        end
                        
        function menuExit_Callback(this,hObject,eventdata)
            %close window
            if(~isempty(this.simToolObj))
                this.simTool.GUI_buttonClose_Callback();
            end
            if(~isempty(this.simCompToolObj))
                this.simCompTool.GUI_buttonClose_Callback();
            end
            delete(this.visHandles.FLIMXFitGUIFigure);
            this.FLIMXObj.destroy(false);
        end
        
        function menuVersionInfo_Callback(this,hObject,eventdata)
            %
            GUI_versionInfo(this.about,this.FLIMXObj.curSubject.aboutInfo());
        end
        
        function menuCompInfo_Callback(this,hObject,eventdata)
            %
            if(this.FLIMXObj.curSubject.isPixelResult(this.currentChannel))                
                data.standalone = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'standalone');
                data.Time = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'Time');
                data.hostname = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'hostname');
                data.FunctionEvaluations = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'FunctionEvaluations');
                data.Iterations = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'Iterations');
                data.EffectiveTime = this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'EffectiveTime');
                GUI_compInfo(data);
            end
        end
        
        function menuInfoPreProcessOpt_Callback(this,hObject,eventdata)
            %
            GUI_preProcessOptions(this.FLIMXObj.curSubject.preProcessParams);
        end
        
        function  menuInfoFitOpt_Callback(this,hObject,eventdata)
            %
            [str, mask] = this.FLIMXObj.irfMgr.getIRFNames(this.FLIMXObj.curSubject.nrTimeChannels);
            GUI_fitOptions(this.FLIMXObj.curSubject.basicParams,this.initFitParams,...
                this.FLIMXObj.curSubject.pixelFitParams,...
            this.volatilePixelParams,...
            this.FLIMXObj.curSubject.getVolatileChannelParams(0),...%todo
            this.FLIMXObj.curSubject.boundsParams,...
            str,mask,{this.FLIMXObj.curSubject.basicParams.scatterStudy});
        end
        
        function menuInfoOptOpt_Callback(this,hObject,eventdata)
            %
            GUI_optOptions(this.FLIMXObj.curSubject.optimizationParams);
        end
        
        function menuInfoBndOpt_Callback(this,hObject,eventdata)
            %
            GUI_boundsOptions(this.FLIMXObj.paramMgr.getParamSection('bounds'));
        end
        
        function menuInfoCompOpt_Callback(this,hObject,eventdata)
            %
            GUI_compOptions(this.FLIMXObj.curSubject.computationParams);
        end
        
        function menuPreProcessOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_preProcessOptions(this.FLIMXObj.paramMgr.getParamSection('pre_processing'));
            if(~isempty(new))
                this.FLIMXObj.paramMgr.setParamSection('pre_processing',new.preProcessing);
                this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);%clear old results
                this.FLIMXObj.curSubject.update(); 
                this.setupGUI();
                this.updateGUI(1);
            end
        end
        
        function menuFitOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            [str, mask] = this.FLIMXObj.irfMgr.getIRFNames(this.FLIMXObj.curSubject.nrTimeChannels);
            new = GUI_fitOptions(this.FLIMXObj.paramMgr.getParamSection('basic_fit'),...
                this.FLIMXObj.paramMgr.getParamSection('init_fit'),...
                this.FLIMXObj.paramMgr.getParamSection('pixel_fit'),...
                this.volatilePixelParams,...
                this.FLIMXObj.curSubject.getVolatileChannelParams(0),...
                this.FLIMXObj.paramMgr.getParamSection('bounds'),...
                str,mask,this.FLIMXObj.fdt.getStudyNames());
            if(~isempty(new))
                if(new.isDirty(1) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('basic_fit',new.basic);
                end
                if(new.isDirty(2) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('init_fit',new.init);
                end
                if(new.isDirty(3) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('pixel_fit',new.pixel);
                end
                this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);%clear old results
                this.FLIMXObj.curSubject.update(); 
                this.setupGUI();
                this.updateGUI(1);
            end
        end
        
        function menuBndOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_boundsOptions(this.FLIMXObj.paramMgr.getParamSection('bounds'));
            if(~isempty(new))
                this.FLIMXObj.paramMgr.setParamSection('bounds',new.bounds);
                this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);%clear old results
                this.FLIMXObj.curSubject.update(); 
                this.setupGUI();
                this.updateGUI(1);
            end
        end
        
        function menuOptOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_optOptions(this.FLIMXObj.paramMgr.getParamSection('optimization'));
            if(~isempty(new))
                this.FLIMXObj.paramMgr.setParamSection('optimization',new.optParams);
                this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);%clear old results
                this.FLIMXObj.curSubject.update(); 
                this.setupGUI();
                this.updateGUI(1);
            end
        end
        
        function menuCompOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_compOptions(this.computationParams);
            if(~isempty(new))
                this.FLIMXObj.paramMgr.setParamSection('computation',new.computation);
                this.FLIMXObj.curSubject.computationParams = new;
            end
        end
        
        function menuCleanupOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_cleanupOptions(this.FLIMXObj.paramMgr.getParamSection('cleanup_fit'),this.volatilePixelParams);
            if(~isempty(new))
                this.FLIMXObj.paramMgr.setParamSection('cleanup_fit',new.cleanup_fit);
            end
        end
        
        function menuExportOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.exportParams;
            opts.defaults = this.exportParams; %todo
            new = GUI_Export_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('export',new.prefs);
            end
        end
        
        function menuVisOpt_Callback(this,hObject,eventdata)
            %
            this.FLIMXObj.paramMgr.readConfig();
            new = GUI_FLIMXFitGUIVisualizationOptions(this.visualizationParams,this.generalParams);
            if(~isempty(new))
                if(new.isDirty(1) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('fluo_decay_fit_gui',new.fluoDecay);
                    this.setupGUI();
                end
                if(new.isDirty(2) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('general',new.general);
                    this.setupGUI();
                end
                this.updateGUI(1);
            end
        end
        
        function menuROIRedefine_Callback(this,hObject,eventdata)
            % change ROI, channel or IRF
            this.FLIMXObj.importGUI.checkVisWnd();          
        end
        
        function menuClearApproxResults_Callback(this,hObject,eventdata)
            %clear approximation results 
            button = questdlg(sprintf('Clear approximation results in all channels for current subject?'),'Clear approximation results?','Clear','Abort','Abort');
            switch button
                case 'Clear'
                    this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);
                    this.FLIMXObj.curSubject.update();                    
                    data = this.FLIMXObj.curSubject.getInitData(this.currentChannel,this.initFitParams.gridPhotons);
                    if(~isempty(data) && (this.initFitParams.gridSize ~= size(data,1) || any(any(this.initFitParams.gridPhotons > sum(data,3)))))
                        this.FLIMXObj.curSubject.clearROIData();
                    end
                    this.setCurrentPos(this.currentY,this.currentX);
            end
        end
        
        function menuRunPreProcessing_Callback(this,hObject,eventdata)
            %pre process data
            this.FLIMXObj.FLIMFit.makePreProcessing(this.currentChannel);
            this.updateGUI(true);
        end
        
        function menuFitInit_Callback(this,hObject,eventdata)
            %start fitting for current channel
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            %setup visualization
            %this.checkVisWnd();
            this.setupGUI();
            this.plotRawData([]);
            this.plotRawDataROI([],[]);
            this.plotSuppData([]);
            this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,this.currentSubject);%clear old results
            this.FLIMXObj.curSubject.update(); 
            %start actual fitting process
            this.FLIMXObj.FLIMFit.startFitProcess(this.currentChannel,0,0);
            this.setupGUI();
            this.updateGUI(false);
        end
        
        function menuFitPixel_Callback(this,hObject,eventdata)
            %start fitting for current pixel
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            %start actual fitting process
            this.setButtonStopSpinning(true);
            this.FLIMXObj.FLIMFit.startFitProcess(this.currentChannel,this.currentY,this.currentX);
            this.setButtonStopSpinning(false);
            this.updateGUI(true);
        end
        
        function menuFitChannel_Callback(this,hObject,eventdata)
            %start fitting for current channel
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            %start actual fitting process
            this.setButtonStopSpinning(true);
            this.FLIMXObj.FLIMFit.startFitProcess(this.currentChannel,[],[]);
            this.FLIMXObj.FLIMVisGUI.updateGUI('');
            this.setButtonStopSpinning(false);
            this.setupGUI();
            this.updateGUI(true);
        end
        
        function menuFitAll_Callback(this,hObject,eventdata)
            %fit all channels
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            %start actual fitting process
            this.setButtonStopSpinning(true);
            this.FLIMXObj.FLIMFit.setInitFitOnly(false);
            %load all channels incase user has to specify borders, reflection mask, ...
            for ch = 1:this.FLIMXObj.curSubject.nrSpectralChannels
                this.currentChannel = ch; 
            end
            for ch = 1:this.FLIMXObj.curSubject.nrSpectralChannels
                this.currentChannel = ch;
                if(isempty(this.FLIMXObj.FLIMFit.startFitProcess(ch,[],[])))
                    %fit was aborted
                    break
                end
            end
            this.FLIMXObj.FLIMVisGUI.updateGUI('');
            this.setButtonStopSpinning(false);
            this.setupGUI();
            this.updateGUI(true);
        end
        
        function menuCleanUpFit_Callback(this,hObject,eventdata)
            %fit all channels
            cla(this.visHandles.axesRes);
            cla(this.visHandles.axesResHis);
            %start actual fitting process
            this.setButtonStopSpinning(true);
            this.FLIMXObj.FLIMFit.makeCleanUpFit(this.currentChannel,false);
            this.FLIMXObj.FLIMVisGUI.updateGUI('');
            this.setButtonStopSpinning(false);
            this.setupGUI();
            this.updateGUI(true);
        end        
        
        function menuBatchSubject_Callback(this,hObject,eventdata)
            %add current channel to batch job manager
            %if 'eventdata' is false ask user for job name
            ch = this.currentChannel;
            if(strcmp(get(hObject,'Tag'),'menuBatchSubjectAllCh'))
                allChFlag = true;
                init = sprintf('%s_%s',this.currentStudy,this.currentSubject);
            else
                allChFlag = false;
                init = sprintf('%s_%s_ch%d',this.currentStudy,this.currentSubject,ch);
            end
            jobInfo = this.FLIMXObj.batchJobMgr.getAllJobsInfo();            
            loop = 1;
            if(isempty(eventdata))
                eventdata = false;
            end
            while(true)
                if(~islogical(eventdata) || ~eventdata) %ask user
                    options.Resize='on';
                    options.WindowStyle='modal';
                    options.Interpreter='none';
                    jn=inputdlg('Enter unique batch job name (required!):','Batch Job Name',1,{init},options);
                    if(isempty(jn))
                        %user pressed cancel
                        return
                    end                    
                    %remove any '\' a might have entered
                    jn = char(jn{1,1});
                    idx = strfind(jn,filesep);
                    if(~isempty(idx))
                        jn(idx) = '';
                    end
                else %generate automatically
                    if(loop == 1)
                        jn = init;
                    else
                        jn = sprintf('%s%02.0f',init,loop);
                    end
                end
                idx = strcmp(jn,jobInfo(:,1));
                if(~any(idx))
                    break
                elseif(any(idx) && ~islogical(eventdata) || ~eventdata)
                    %ask user for new job name
                    uiwait(warndlg(sprintf('Batch job name ''%s'' is already used. Please choose a different batch job name!',jn),'Batch job name error','modal'));
                    init = jn;
                end
                loop = loop+1;
            end %while
            %put data into batch job manager
            if(any(this.volatilePixelParams.globalFitMask) || allChFlag)
                %global fit job or all channels                
                this.FLIMXObj.batchJobMgr.newJob(jn,this.FLIMXObj.paramMgr.getParamSection('batchJob'),...
                    this.FLIMXObj.curSubject,[]);
            else
                %non global fit job and only specific channel
                if(~isempty(this.FLIMXObj.curSubject.getReflectionMask(ch)))
                    this.FLIMXObj.batchJobMgr.newJob(jn,this.FLIMXObj.paramMgr.getParamSection('batchJob'),...
                        this.FLIMXObj.curSubject,ch);
                end
            end
            this.FLIMXObj.batchJobMgrGUI.updateGUI();
        end
        
        function menuBatchStudy_Callback(this,hObject,eventdata)
            %add study with current settings to batchjob manager
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentView);
            tStart = clock;
            for i = 1:length(subjects)
                this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentView,subjects{i});
                this.menuBatchSubject_Callback(this.visHandles.menuBatchSubjectAllCh,true);
                %update progressbar
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(subjects)-i)); %mean time for finished runs * iterations left
                this.updateProgressLong(i/length(subjects),sprintf('%02.1f%% - Time left: %02.0fh %02.0fm %02.0fs',i/length(subjects)*100,hours,minutes,secs));
            end
            this.updateProgressLong(0,'');
        end
                
        function menuOpenBatchJobMgr_Callback(this,hObject,eventdata)
            %show batch job manager window
            this.FLIMXObj.batchJobMgrGUI.checkVisWnd();
        end
        
        function menuOpenStudyMgr_Callback(this,hObject,eventdata)
            %show study manager window
            this.FLIMXObj.studyMgrGUI.checkVisWnd();
            this.FLIMXObj.studyMgrGUI.curStudyName = this.currentStudy;
        end
        
        function menuOpenFLIMXVis_Callback(this,hObject,eventdata)
            %show FLIMXVis window
            this.FLIMXObj.FLIMVisGUI.checkVisWnd();
        end
        
        function toggleControls(this,flag)
            %switch enable-state of control elemtens
            set(this.visHandles.buttonToggle,'Enable',flag);
            %edit
            set(this.visHandles.editX,'Enable',flag);
            set(this.visHandles.editY,'Enable',flag);
            %buttons
            set(this.visHandles.buttonRight,'Enable',flag);
            set(this.visHandles.buttonLeft,'Enable',flag);
            set(this.visHandles.buttonUp,'Enable',flag);
            set(this.visHandles.buttonDown,'Enable',flag);
            set(this.visHandles.toggleShowMerge,'Enable',flag);
            if(strcmpi(flag,'on'))
                set(this.visHandles.buttonStop,'Enable','off');
            else
                set(this.visHandles.buttonStop,'Enable','on');
            end
            %popup
            set(this.visHandles.popupROI,'Enable',flag);
            set(this.visHandles.buttonToggle,'Value',0);
            this.GUI_buttonToggle_Callback(this.visHandles.buttonToggle,[]);
        end        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            switch this.generalParams.windowSize
                case 1
                    this.visHandles = FLIMXFitGUIFigureMedium();
                case 2
                    this.visHandles = FLIMXFitGUIFigureSmall();
                case 3
                    this.visHandles = FLIMXFitGUIFigureLarge();
            end
            set(this.visHandles.FLIMXFitGUIFigure,'CloseRequestFcn',@this.menuExit_Callback);
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
            this.visHandles.patchWaitShort = patch(xpatch,ypatch,'m','EdgeColor','m','Parent',this.visHandles.axesWaitShort);%,'EraseMode','normal'
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
            %add handles for lines in raw and roi plots
            this.visHandles.rawPlotTopLine = [];
            this.visHandles.rawPlotBottomLine = [];
            this.visHandles.rawPlotLeftLine = [];
            this.visHandles.rawPlotRightLine = [];
            this.visHandles.rawPlotCPXLine = [];
            this.visHandles.rawPlotCPYLine = [];
            this.visHandles.roiPlotCPXLine = [];
            this.visHandles.roiPlotCPYLine = [];
            
            %set defaut axes
            this.visHandles.axesCurMain = this.visHandles.axesMain;
            this.visHandles.axesCurSupp = this.visHandles.axesSupp;
            axis(this.visHandles.axesMain,'off');
            axis(this.visHandles.axesRaw,'off');
            axis(this.visHandles.axesSupp,'off');
            axis(this.visHandles.axesRes,'off');
            axis(this.visHandles.axesResHis,'off');
            
            %set callbacks
            set(this.visHandles.FLIMXFitGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
            %set default toggle state
            set(this.visHandles.buttonToggle,'String',[char(172) char(174)],'Value',0,'Callback',@this.GUI_buttonToggle_Callback);
            
            %figure
            set(this.visHandles.FLIMXFitGUIFigure,'Units','Pixels');
            %edit            
            set(this.visHandles.editX,'String',num2str(this.currentX),'Callback',@this.GUI_editX_Callback);
            set(this.visHandles.editY,'String',num2str(this.currentY),'Callback',@this.GUI_editY_Callback);
            set(this.visHandles.editResScal,'Callback',@this.GUI_editResScal_Callback);
            set(this.visHandles.editTimeScalStart,'Callback',@this.GUI_editTimeScal_Callback);
            set(this.visHandles.editTimeScalEnd,'Callback',@this.GUI_editTimeScal_Callback);
            set(this.visHandles.editCountsScalStart,'Callback',@this.GUI_editCountsScal_Callback);
            set(this.visHandles.editCountsScalEnd,'Callback',@this.GUI_editCountsScal_Callback);
            
            %buttons
            set(this.visHandles.buttonSubjectDec,'FontName','Symbol','String',char(173),'Callback',@this.GUI_buttonSwitchSubject_Callback); 
            set(this.visHandles.buttonSubjectInc,'FontName','Symbol','String',char(175),'Callback',@this.GUI_buttonSwitchSubject_Callback); 
            set(this.visHandles.buttonRight,'String',char(174),'Callback',@this.GUI_buttonRight_Callback);
            set(this.visHandles.buttonLeft,'String',char(172),'Callback',@this.GUI_buttonLeft_Callback);
            set(this.visHandles.buttonUp,'String',char(173),'Callback',@this.GUI_buttonUp_Callback);
            set(this.visHandles.buttonDown,'String',char(175),'Callback',@this.GUI_buttonDown_Callback);
            set(this.visHandles.buttonFitCurrentPixel,'Callback',@this.menuFitPixel_Callback);
            set(this.visHandles.toggleShowMerge,'Callback',@this.GUI_showMerge_Callback);
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback);
            set(this.visHandles.buttonResScalDec,'String',char(172),'Callback',@this.GUI_buttonResScal_Callback);
            set(this.visHandles.buttonResScalInc,'String',char(174),'Callback',@this.GUI_buttonResScal_Callback);
            set(this.visHandles.buttonTimeScalStartDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalStartInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalEndDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalEndInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonCountsScalStartDec,'String',char(172),'Callback',@this.GUI_buttonCountsScal_Callback);
            set(this.visHandles.buttonCountsScalStartInc,'String',char(174),'Callback',@this.GUI_buttonCountsScal_Callback);
            set(this.visHandles.buttonCountsScalEndDec,'String',char(172),'Callback',@this.GUI_buttonCountsScal_Callback);
            set(this.visHandles.buttonCountsScalEndInc,'String',char(174),'Callback',@this.GUI_buttonCountsScal_Callback);
            
            %checkbox
            set(this.visHandles.checkAutoFitPixel,'Callback',@this.GUI_checkAutoFitPixel_Callback);
            
            %radio
            set(this.visHandles.radioResScalAuto,'Callback',@this.GUI_radioResScal_Callback);
            set(this.visHandles.radioResScalManual,'Callback',@this.GUI_radioResScal_Callback);
            set(this.visHandles.radioTimeScalAuto,'Callback',@this.GUI_radioTimeScal_Callback);
            set(this.visHandles.radioTimeScalManual,'Callback',@this.GUI_radioTimeScal_Callback);
            set(this.visHandles.radioCountsScalAuto,'Callback',@this.GUI_radioCountsScal_Callback);
            set(this.visHandles.radioCountsScalManual,'Callback',@this.GUI_radioCountsScal_Callback);
            
            %popup
            set(this.visHandles.popupStudy,'Callback',@this.GUI_popupStudy_Callback);
            set(this.visHandles.popupSubject,'Callback',@this.GUI_popupSubject_Callback);
            set(this.visHandles.popupView,'Callback',@this.GUI_popupView_Callback);
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback);
            set(this.visHandles.popupROI,'Callback',@this.GUI_popupROI_Callback);
            
            %menu
            set(this.visHandles.menuExit,'Callback',@this.menuExit_Callback);
            
            set(this.visHandles.menuROIRedefine,'Callback',@this.menuROIRedefine_Callback);
            
            set(this.visHandles.menuExportShot,'Callback',@this.menuExportScreenshot_Callback);
            set(this.visHandles.menuExportFiles,'Callback',@this.menuExportFiles_Callback);
            set(this.visHandles.menuExportExcel,'Callback',@this.menuExportExcel_Callback);
            
            set(this.visHandles.menuSimFLIM,'Callback',@this.menuSimFLIM_Callback);
            set(this.visHandles.menuSimAnalysis,'Callback',@this.menuSimAnalysis_Callback);
            set(this.visHandles.menuIRFMgr,'Callback',@this.menuIRFMgr_Callback);
            
            set(this.visHandles.menuVersionInfo,'Callback',@this.menuVersionInfo_Callback);
            set(this.visHandles.menuCompInfo,'Callback',@this.menuCompInfo_Callback);
            set(this.visHandles.menuInfoPreProcessOpt,'Callback',@this.menuInfoPreProcessOpt_Callback);
            set(this.visHandles.menuInfoFitOpt,'Callback',@this.menuInfoFitOpt_Callback);
            set(this.visHandles.menuInfoOptOpt,'Callback',@this.menuInfoOptOpt_Callback);
            set(this.visHandles.menuInfoBndOpt,'Callback',@this.menuInfoBndOpt_Callback);
            set(this.visHandles.menuInfoCompOpt,'Callback',@this.menuInfoCompOpt_Callback);
            %options
            set(this.visHandles.menuPreProcessOpt,'Callback',@this.menuPreProcessOpt_Callback);
            set(this.visHandles.menuFitOpt,'Callback',@this.menuFitOpt_Callback);
            set(this.visHandles.menuCleanupOpt,'Callback',@this.menuCleanupOpt_Callback);
            set(this.visHandles.menuOptOpt,'Callback',@this.menuOptOpt_Callback);
            set(this.visHandles.menuBndOpt,'Callback',@this.menuBndOpt_Callback);
            set(this.visHandles.menuCompOpt,'Callback',@this.menuCompOpt_Callback);            
            set(this.visHandles.menuExportOptions,'Callback',@this.menuExportOpt_Callback);            
            set(this.visHandles.menuVisOpt,'Callback',@this.menuVisOpt_Callback);
            %approximation
            set(this.visHandles.menuClearApproxResults,'Callback',@this.menuClearApproxResults_Callback);
            set(this.visHandles.menuRunPreProcessing,'Callback',@this.menuRunPreProcessing_Callback);
            set(this.visHandles.menuFitInit,'Callback',@this.menuFitInit_Callback);
            set(this.visHandles.menuFitPixel,'Callback',@this.menuFitPixel_Callback);
            set(this.visHandles.menuFitChannel,'Callback',@this.menuFitChannel_Callback);
            set(this.visHandles.menuFitAll,'Callback',@this.menuFitAll_Callback);
            set(this.visHandles.menuCleanUpFit,'Callback',@this.menuCleanUpFit_Callback);
            %batch manager
            set(this.visHandles.menuOpenBatchJobMgr,'Callback',@this.menuOpenBatchJobMgr_Callback);
            set(this.visHandles.menuBatchSubjectCurCh,'Callback',@this.menuBatchSubject_Callback);
            set(this.visHandles.menuBatchSubjectAllCh,'Callback',@this.menuBatchSubject_Callback);
            set(this.visHandles.menuBatchStudy,'Callback',@this.menuBatchStudy_Callback);
            %study manager
            set(this.visHandles.menuOpenStudyMgr,'Callback',@this.menuOpenStudyMgr_Callback);
            %FLIMXVis
            set(this.visHandles.menuOpenFLIMXVis,'Callback',@this.menuOpenFLIMXVis_Callback);
            
            this.axesRawMgr = axesWithROI(this.visHandles.axesRaw,this.visHandles.axesCbRaw,this.visHandles.textCbRawBottom,this.visHandles.textCbRawTop,this.visHandles.editCPRaw,this.dynVisParams.cmIntensity);
            this.axesROIMgr = axesWithROI(this.visHandles.axesSupp,this.visHandles.axesCbSupp,this.visHandles.textCbSuppBottom,this.visHandles.textCbSuppTop,this.visHandles.editCPSupp,this.dynVisParams.cm);
            
%             this.setupGUI();
%             this.updateGUI(true);
        end
        
%         function makeColorbars(this)
%             %draw colorbars
%             cm = this.dynVisParams.cm;
%             temp(:,1,:) = cm;
%             image(temp,'Parent',this.visHandles.axesCbRaw);
%             ytick = (0:0.25:1).*size(this.dynVisParams.cm,1);
%             ytick(1) = 1;
%             set(this.visHandles.axesCbRaw,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
%             ylim(this.visHandles.axesCbRaw,[1 size(this.dynVisParams.cm,1)]);
%             image(temp,'Parent',this.visHandles.axesCbSupp);
%             set(this.visHandles.axesCbSupp,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
%             ylim(this.visHandles.axesCbSupp,[1 size(this.dynVisParams.cm,1)]);
%         end
        
    end %methods protected
    
    methods(Static)
        function out = num4disp(data)
            %convert numeric value to string
            if(ischar(data))
                return
            end
            da = abs(data);
            if(isinteger(data) || abs(data - fix(data)) < eps(data) || da >= 100)
                out = num2str(data,'%.0f');
            elseif(da < 100 && da >= 10)
                out = num2str(data,'%2.1f');
            else
                out = num2str(data,'%1.2f');
            end
        end
        
        function lStr = makeModelPlot(hAx,model,xAxis,paramName,dynVisParams,staticVisParams,legendName,lStr)
            %plot data and model function to hAx
            if(isempty(model))
                return
            end
            if(~dynVisParams.timeScalingAuto)
                model = model(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
                xAxis = xAxis(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
            end
            if(~isempty(get(hAx,'Children')))
                set(hAx,'NextPlot','add');
            end            
            try
                semilogy(hAx,xAxis,model,...
                    'Linewidth',staticVisParams.(sprintf('plot%sLinewidth',paramName)),...
                    'Linestyle',staticVisParams.(sprintf('plot%sLinestyle',paramName)),...
                    'Color',staticVisParams.(sprintf('plot%sColor',paramName)),...
                    'Marker',staticVisParams.(sprintf('plot%sMarkerstyle',paramName)),...
                    'Markersize',staticVisParams.(sprintf('plot%sMarkersize',paramName)));
                if(numel(xAxis > 1))
                    xlim(hAx,[xAxis(1) xAxis(end)]);
                end
            catch ME
                warning('FLIMXFitGUI:makeVerticalLinePlot',ME.message);
                return
            end
            if(~isempty(legendName))
                lStr(end+1) = {legendName};
            end
        end
                
        function [lStr exponentials] = makeExponentialsPlot(hAx,xAxis,apObj,x_vec,lStr,dynVisParams,staticVisParams,exponentials)
            %plot exponentials and scatter data to hAx
            %[amps taus tcis scAmps scShifts scOset vShift hShift oset] = sliceXVec(x_vec,fitParams);
            if(nargin < 8)
                %compute exponentials
                hmOld = apObj.basicParams.heightMode;
                apObj.basicParams.heightMode = 1;
%                 m_single = multiExpModel(data,[],[],irf,fileInfo,basicFitParams,pixelFitParams,computationParams,volatileParams,-inf,inf);%this.FLIMXObj.FLIMFit.data.scatter.cut
                exponentials = apObj.getExponentials(apObj.currentChannel,x_vec);
                apObj.basicParams.heightMode = hmOld;
                exponentials = squeeze(exponentials);
                if(size(exponentials,2) ~= apObj.basicParams.nExp+1+apObj.volatilePixelParams.nScatter)
                    return
                end
            end
            oset = exponentials(:,end);
            %plot exponentials
            if(~dynVisParams.timeScalingAuto)
                xAxis = xAxis(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
            end
            if(~isempty(get(hAx,'Children')))
                set(hAx,'NextPlot','add');
            end
            for i = 1 : size(exponentials,2)-1
                model_vec = squeeze(exponentials(:,i)) + oset;
                model_vec(model_vec < 1e-1) = 1e-1;
                if(~dynVisParams.timeScalingAuto)
                    model_vec = model_vec(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
                end
                semilogy(hAx,xAxis,model_vec,'Linestyle',staticVisParams.plotExpLinestyle,'Linewidth',staticVisParams.plotExpLinewidth,...
                    'Color',staticVisParams.(sprintf('plotExp%dColor',i-5*(ceil(i/5)-1))),'Marker',staticVisParams.plotExpMarkerstyle,'Markersize',staticVisParams.plotExpMarkersize);
                if(i <= apObj.basicParams.nExp)
                    lStr(end+1) = {sprintf('Exp. %d',i)};
                else
                    lStr(end+1) = {sprintf('Scatter. %d',i-apObj.basicParams.nExp)};
                end
            end
            %             %plot scatter vector(s)
            %             for i = 1 : fitParams.nScatter
            %                 my_scAmps = scAmps;
            %                 idx = 1 : fitParams.nScatter;
            %                 idx(i) = [];
            %                 my_scAmps(idx) = 0;
            %                 my_xVec = mergeXVec(zeros(size(amps)),taus,tcis,my_scAmps,scShifts,scOset,vShift,hShift,oset,fitParams);
            %                 m_single.compModel(splitXVec(my_xVec,fitParams.cMask));
            %                 model_vec = m_single.model(1:m_single.dLen);
            %                 model_vec(model_vec < 1e-1) = 1e-1;
            %                 if(~this.dynVisParams.timeScalingAuto)
            %                     model_vec = model_vec(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
            %                 end
            %                 semilogy(hAx,xAxis,model_vec,'Linewidth',1,'color',map(i+3+fitParams.nExp,:));
            %                 lStr(end+1) = {sprintf('Scatter %d',i)};
            %             end
        end
        
        function tstr = makeParamTable(hTable,xVec,tci,osetS,chi2,chi2Tail,FunctionEvaluations,time,nrPhotons,apObj)
            %make info table and output its content
            tstr = cell(apObj.basicParams.nExp*+1+3+2,4);
            row = 1;
            tstr{row,1} = '';  tstr{row,2} = 'Amp.'; tstr{row,3} = 'Tau'; tstr{row,4} = 'tci';
            if(any(apObj.basicParams.stretchedExpMask))
                tstr{row,5} = 'beta';
            end
            [amps, taus, ~, betas, scAmps, scShifts, scOset, hShift, ~] = apObj.getXVecComponents(xVec,false,apObj.currentChannel);
            as = sum([amps(:); scAmps(:);]);
            bCnt = 1;
            for l = 1:apObj.basicParams.nExp
                tstr{l+row,1} = sprintf('Exp. %d',l);
                tstr{l+row,2} = sprintf('%2.1f%%',100*amps(l)/as);
                tstr{l+row,3} = sprintf('%3.0fps',taus(l));
                tstr{l+row,4} = sprintf('%3.1fps',tci(l));
                if(apObj.basicParams.stretchedExpMask(l))
                    tstr{l+row,5} = sprintf('%1.2f',betas(min(bCnt,length(betas))));
                    bCnt = bCnt+1;
                end
            end
            row = apObj.basicParams.nExp+1;
%             if(apObj.volatilePixelParams.nScatter > 0)
%                 row = row+1;
%                 tstr{row,1} = '';  tstr{row,2} = 'Amp.'; tstr{row,3} = 'Shift'; tstr{row,4} = 'Offset';
%             end
            for l = 1:apObj.volatilePixelParams.nScatter
                tstr{l+row,1} = sprintf('Scatter %d',l);
                tstr{l+row,2} = sprintf('%2.1f%%',100*scAmps(l)/as);
                tstr{l+row,3} = sprintf('%2.3f',scOset(l));
                tstr{l+row,4} = sprintf('%3.1fps',scShifts(l));
                
            end
            row = row+apObj.volatilePixelParams.nScatter+2;
            tstr{row,1} = 'Offset';  tstr{row,2} = sprintf('%3.1f',osetS); tstr{row,3} = 'Shift'; tstr{row,4} = sprintf('%3.1fps',hShift);
            row = row+1;
            tstr{row,1} = 'Chi²';  tstr{row,2} = sprintf('%3.2f',chi2); tstr{row,3} = 'Chi² (Tail)'; tstr{row,4} = sprintf('%3.2f',chi2Tail);
            row = row+1;
            tstr{row,1} = 'FuncEvals';  tstr{row,2} = sprintf('%d',FunctionEvaluations); tstr{row,3} = 'Time'; tstr{row,4} = sprintf('%3.1fs',time);
            row = row+1;
            tstr{row,1} = 'Photons';  tstr{row,2} = sprintf('%d',nrPhotons); tstr{row,3} = ''; tstr{row,4} = '';
            set(hTable,'Data',tstr);
        end
        
        function lStr = makeVerticalLinePlot(hAx,position,xAxis,paramName,dynVisParams,staticVisParams,legendName,lStr)
            %plot lines at start + end positions
            if(~isempty(get(hAx,'Children')))
                set(hAx,'NextPlot','add');
            end
%             if(~dynVisParams.timeScalingAuto)
%                 irf = irf(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
%                 xAxis = xAxis(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
%             end            
            if(position > 0  && position <= length(xAxis))
                try
                    line('XData',[xAxis(position) xAxis(position)],'YData',ylim(hAx),...
                    'LInewidth',staticVisParams.(sprintf('plot%sLinewidth',paramName)),...
                    'Linestyle',staticVisParams.(sprintf('plot%sLinestyle',paramName)),...
                    'Color',staticVisParams.(sprintf('plot%sColor',paramName)),'Parent',hAx);
                catch ME
                    warning('FLIMXFitGUI:makeverticalLinePlot',ME.message);
                    return
                end
            end
            if(~isempty(legendName))
                lStr(end+1) = {legendName};
            end
        end
        
        function makeLegend(hAx,lStr)
            legend(hAx,lStr);
        end
    end %methods(Static)
    
end %classdef
