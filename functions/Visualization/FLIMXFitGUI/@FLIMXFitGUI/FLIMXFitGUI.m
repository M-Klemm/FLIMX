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
        mouseOverlayBoxMain = [];
        mouseOverlayBoxSupp = [];
        mouseOverlayBoxRaw = [];
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
        axesSuppDataMask = [];
        currentStudy = '';
        currentSubject = '';
        currentCondition = '';
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
            this.dynVisParams.timeScalingStartOld = 1; %only if timeScalingAuto = 0
            this.dynVisParams.timeScalingEndOld = 1024; %only if timeScalingAuto = 0
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
                    set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/> Stop</html>',FLIMX.getAnimationPath()));
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
            conditions = this.FLIMXObj.fdt.getStudyConditionsStr(this.currentStudy);
            oldVStr = get(this.visHandles.popupCondition,'String');
            if(iscell(oldVStr))
                oldVStr = oldVStr(get(this.visHandles.popupCondition,'Value'));
            end
            %try to find oldPStr in new pstr
            idx = find(strcmp(oldVStr,conditions),1);
            if(isempty(idx) || isempty(this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,conditions{idx})))
                idx = 1;%choose FDTree.defaultConditionName() condition
            end
            set(this.visHandles.popupCondition,'String',conditions,'Value',idx);
            %update subject controls
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentCondition);
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
                pstr = removeNonVisItems(pstr,this.generalParams.flimParameterView);
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
            this.axesRawMgr.setColorMap(this.dynVisParams.cmIntensity);
            this.axesRawMgr.setColorMapPercentiles(this.generalParams.cmIntensityPercentileLB,this.generalParams.cmIntensityPercentileUB);
            this.axesROIMgr.setColorMap(this.dynVisParams.cm);
            if(strcmp(pstr{idx},'Intensity'))
                this.axesROIMgr.setColorMapPercentiles(this.generalParams.cmIntensityPercentileLB,this.generalParams.cmIntensityPercentileUB);
            else
                this.axesROIMgr.setColorMapPercentiles(this.generalParams.cmPercentileLB,this.generalParams.cmPercentileUB);
            end
            this.axesRawMgr.setReverseYDirFlag(this.generalParams.reverseYDir);
            this.axesROIMgr.setReverseYDirFlag(this.generalParams.reverseYDir);
            this.mouseOverlayBoxMain.setBackgroundColor([this.visualizationParams.plotCoordinateBoxColor(:); this.visualizationParams.plotCoordinateBoxTransparency]);
            this.mouseOverlayBoxMain.setLineColor(this.visualizationParams.plotCurLinesColor);
            this.mouseOverlayBoxMain.setLineStyle(this.visualizationParams.plotCurLinesStyle);
            this.mouseOverlayBoxMain.setLineWidth(this.visualizationParams.plotCurlineswidth);
            this.mouseOverlayBoxSupp.setBackgroundColor([this.visualizationParams.plotCoordinateBoxColor(:); this.visualizationParams.plotCoordinateBoxTransparency]);
            this.mouseOverlayBoxSupp.setLineColor(this.visualizationParams.plotCurLinesColor);
            this.mouseOverlayBoxSupp.setLineStyle(this.visualizationParams.plotCurLinesStyle);
            this.mouseOverlayBoxSupp.setLineWidth(this.visualizationParams.plotCurlineswidth);
            this.mouseOverlayBoxRaw.setBackgroundColor([this.visualizationParams.plotCoordinateBoxColor(:); this.visualizationParams.plotCoordinateBoxTransparency]);
            this.mouseOverlayBoxRaw.setLineColor(this.visualizationParams.plotCurLinesColor);
            this.mouseOverlayBoxRaw.setLineStyle(this.visualizationParams.plotCurLinesStyle);
            this.mouseOverlayBoxRaw.setLineWidth(this.visualizationParams.plotCurlineswidth);
            set(this.visHandles.FLIMXFitGUIFigure,'Name',sprintf('FLIMXFit: %s - Channel %d',this.FLIMXObj.curSubject.getDatasetName(),ch));
            this.lastProgressCmdLine = 0;
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
%             tmp = this.currentDecayData;            
%             if(~isempty(tmp))
%                 this.dynVisParams.countsScalingEnd = 10^ceil(log10(max(tmp(:))));
%                 this.dynVisParams.countsScalingStart = max(min(10^floor(log10(min(tmp(:)))),this.dynVisParams.countsScalingEnd-1),0.1);
%             end
            set(this.visHandles.editCountsScalStart,'String',num2str(this.dynVisParams.countsScalingStart,'%G'));
            set(this.visHandles.editCountsScalEnd,'String',num2str(this.dynVisParams.countsScalingEnd,'%G'));
            
            %edit
            set(this.visHandles.editX,'Enable','on');
            set(this.visHandles.editY,'Enable','on');
            %buttons
            set(this.visHandles.buttonRight,'Enable','on');
            set(this.visHandles.buttonLeft,'Enable','on');
            set(this.visHandles.buttonUp,'Enable','on');
            set(this.visHandles.buttonDown,'Enable','on');
            set(this.visHandles.toggleShowInitialization,'Enable','on');
            set(this.visHandles.buttonStop,'Enable','on');            
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
            this.visCurFit(this.currentChannel,this.currentY,this.currentX,this.visHandles.axesMain);
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
                data = this.axesSuppData;
                if(~strcmp(str,'Intensity') && ~all(this.axesSuppDataMask(:)))
                    tmp = data(data ~= 0 | this.axesSuppDataMask);
                    lb = min(tmp(:));
                    ub = max(tmp(:));
                    this.axesROIMgr.setMainData(data,lb,ub);
                else
                    this.axesROIMgr.setMainData(data);
                end
            end
            roi = this.FLIMXObj.curSubject.ROICoordinates;
            if(all(roi == [1 this.FLIMXObj.curSubject.getRawXSz 1 this.FLIMXObj.curSubject.getRawYSz]'))
                %ROI is same as raw (measurement) data size 
                this.axesRawMgr.setROILineStyle('none');
            else
                this.axesRawMgr.setROILineStyle('-');
            end
            this.axesRawMgr.drawROIBox(roi);
            this.axesRawMgr.drawCP([this.currentY+roi(3)-1 this.currentX+roi(1)-1]);
            this.axesROIMgr.drawCP([this.currentY this.currentX]);
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
        
        function data = get.axesSuppData(this)
            %get data for supplemental axes
            if(~this.isOpenVisWnd())
                data = [];
                return;
            end
            pstr = char(get(this.visHandles.popupROI,'String'));
            pos = get(this.visHandles.popupROI,'Value');
            pstr = strtrim(pstr(pos,:));
            if(this.showInitialization)
                if(strcmp('Intensity',pstr))
                    data = double(sum(this.FLIMXObj.curSubject.getInitData(this.currentChannel,[]),3));
                else
                    data = double(this.FLIMXObj.curSubject.getInitFLIMItem(this.currentChannel,pstr));
                end
            else
                if(strcmp('Intensity',pstr))
                    data = double(this.FLIMXObj.curSubject.getROIDataFlat(this.currentChannel,false));
                else
                    data = double(this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,pstr));
                end
            end
        end
        
        function mask = get.axesSuppDataMask(this)
            %get mask for data of supplemental axes where data is non-zero
            if(~this.isOpenVisWnd())
                mask = [];
                return;
            end
            %we assume that each result must have a tau1 and that tau1 is never zero
            if(this.showInitialization)
                mask = double(this.FLIMXObj.curSubject.getInitFLIMItem(this.currentChannel,'Tau1'));
            else
                mask = double(this.FLIMXObj.curSubject.getPixelFLIMItem(this.currentChannel,'Tau1'));
            end
            mask = mask ~= 0;
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
        
        function out = get.currentCondition(this)
            %get current condition name from GUI
            out = FDTree.defaultConditionName();
            if(~this.isOpenVisWnd())
                return;
            end
            str = get(this.visHandles.popupCondition,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupCondition,'Value')};
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
            out = get(this.visHandles.toggleShowInitialization,'Value');
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
        
        function [apObj, xVec, oset, chi2, chi2Tail, TotalPhotons, FunctionEvaluations, time, slopeStart, iVec, paramTable] = getVisParams(this,ch,y,x,addAbsolutAmps)
            %get parameters for visualization of current fit in channel ch
            [apObj, xVec, ~, oset, chi2, chi2Tail, TotalPhotons, FunctionEvaluations, time, slopeStart, iVec] = this.FLIMXObj.curSubject.getVisParams(ch,y,x,this.showInitialization);
            if(nargout == 11)
                if(nargin < 5)
                    addAbsolutAmps = false;
                end
                if(addAbsolutAmps)
                    addParam = 1;
                else
                    addParam = 0;
                end
                tci = zeros(1,apObj.basicParams.nExp);
                tci(logical(apObj.basicParams.tciMask)) = xVec(2*apObj.basicParams.nExp+1 : 2*apObj.basicParams.nExp+sum(apObj.basicParams.tciMask))';
                %make info table and output its content
                paramTable = cell(apObj.basicParams.nExp*+1+3+2,4+addParam);
                row = 1;
                paramTable{row,1} = '';
                if(addAbsolutAmps)
                    paramTable{row,2} = 'Amp.';
                end
                if(apObj.basicParams.approximationTarget == 2 && ch == 4)
                    paramTable{row,2+addParam} = 'Amp.'; 
                else
                    paramTable{row,2+addParam} = 'Amp. (%)'; 
                end
                paramTable{row,3+addParam} = 'Tau'; paramTable{row,4+addParam} = 'tci';
                if(any(apObj.basicParams.stretchedExpMask))
                    paramTable{row,5} = 'beta';
                end
                [amps, taus, ~, betas, scAmps, scShifts, scOset, hShift, ~] = apObj.getXVecComponents(xVec,false,apObj.currentChannel);
                if(apObj.basicParams.approximationTarget == 2 && ch == 4)
                    as = 100*sum(abs(amps(1:2:apObj.basicParams.nExp)));
                else
                    as = sum(abs([amps(:); scAmps(:);]));
                end
                bCnt = 1;
                for l = 1:apObj.basicParams.nExp
                    paramTable{l+row,1} = sprintf('Exp. %d',l);
                    if(addAbsolutAmps)
                        paramTable(l+row,2) = FLIMXFitGUI.num4disp(amps(l));
                    end
                    if(apObj.basicParams.approximationTarget == 2 && ch == 4 && mod(l,2) == 0)
                        paramTable(l+row,2) = FLIMXFitGUI.num4disp(amps(l));
                    else
                        paramTable(l+row,2+addParam) = FLIMXFitGUI.num4disp(100*amps(l)/as);
                    end
                    paramTable(l+row,3+addParam) = FLIMXFitGUI.num4disp(taus(l));
                    paramTable(l+row,4+addParam) = FLIMXFitGUI.num4disp(tci(l));
                    if(apObj.basicParams.stretchedExpMask(l))
                        paramTable{l+row,5} = sprintf('%1.2f',betas(min(bCnt,length(betas))));
                        bCnt = bCnt+1;
                    end
                end
                row = apObj.basicParams.nExp+1;
                for l = 1:apObj.volatilePixelParams.nScatter
                    paramTable{l+row,1} = sprintf('Scatter %d',l);
                    paramTable{l+row,2} = sprintf('%2.1f%%',100*scAmps(l)/as);
                    paramTable{l+row,3} = sprintf('%2.3f',scOset(l));
                    paramTable{l+row,4} = sprintf('%3.1fps',scShifts(l));
                end
                row = row+apObj.volatilePixelParams.nScatter+2;
                paramTable{row,1} = 'Offset';  paramTable{row,2} = sprintf('%3.2f',oset); paramTable{row,3} = 'Shift'; paramTable{row,4} = sprintf('%3.1fps',hShift);
                row = row+1;
                paramTable{row,1} = 'Chi²';  paramTable(row,2) = FLIMXFitGUI.num4disp(chi2); paramTable{row,3} = 'Chi² (Tail)'; paramTable(row,4) = FLIMXFitGUI.num4disp(chi2Tail);
                row = row+1;
                paramTable{row,1} = 'FuncEvals';  paramTable{row,2} = sprintf('%d',FunctionEvaluations); paramTable{row,3} = 'Time'; paramTable{row,4} = sprintf('%3.2fs',time);
                row = row+1;
                paramTable{row,1} = 'Photons';  paramTable(row,2) = FLIMXFitGUI.num4disp(TotalPhotons); paramTable{row,3} = ''; paramTable{row,4} = '';
            end
        end
        
        function [xAxis, data, irf, model, exponentials, residuum, residuumHist] = visCurFit(this,ch,y,x,hAxMain,hAxRes,hAxResHis,hTableInfo)
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
                hAxMain = this.visHandles.axesMain;
            end
            exponentials = [];
            data = this.currentDecayData;
            [apObj, xVec, oset, ~, ~, ~, ~, ~, slopeStart, iVec, paramTable] = this.getVisParams(ch,y,x,false);
%             if(sum(TotalPhotons(:)) == 0)
%                 TotalPhotons = sum(data(:));
%             end
            xAxis = this.FLIMXObj.curSubject.timeVector(1:length(data));
            if(apObj.basicParams.approximationTarget == 2 && ch == 4)
                %anisotropy
                dMin = min(data);
                yScaleStr = 'linear';
                yLbl = 'Anisotropy';                
            else
                %fluorescence lifetime
                dMin = min(oset,max(1e-2,min(data(data>0))));
                if(isempty(dMin))
                    dMin = 1e-2;
                end
                yScaleStr = 'log';
                yLbl = 'Photon-Frequency (counts)';
            end
            if(sum(xVec(:)) == 0)
                model = [];
            else
                model = apObj.getModel(ch,xVec);
                model = model(1:min(length(model),length(data)));
                model(model < dMin) = dMin;
            end
            ylabel(hAxMain,'');
            legend(hAxMain,'off');
            lStr = cell(0,0);
            cla(hAxMain);            
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
                if(~this.dynVisParams.countsScalingAuto)
                    irfPlot = irfPlot.*this.dynVisParams.countsScalingEnd;
                end
            else
                irfPlot = max(model).*irf./max(irf) + oset;
            end
                irfPlot(irfPlot < dMin) = dMin;
                lStr = this.makeModelPlot(hAxMain,irfPlot,xAxis,'IRF',this.dynVisParams,this.visualizationParams,'IRF',lStr);
            end                       
            %% display parameters on the right side
            set(hTableInfo,'Data',paramTable);
            %% display x & y
            set(this.visHandles.editX,'String',x);
            set(this.visHandles.editY,'String',y);            
            %% counts scaling
            if(~this.dynVisParams.countsScalingAuto)
                ylim(hAxMain,[this.dynVisParams.countsScalingStart this.dynVisParams.countsScalingEnd]);
                set(hAxMain,'Yscale',yScaleStr,'XTickLabelMode','auto','YTickLabelMode','auto');
            else
                set(hAxMain,'YLimMode','auto','Yscale',yScaleStr,'XTickLabelMode','auto','YTickLabelMode','auto');
            end            
            ylabel(hAxMain,yLbl);
            grid(hAxMain,'on');
            [residuum, residuumHist] = this.visRes(ch,y,x,apObj,hAxRes,hAxResHis);
            %% no parameters computed
            if(sum(xVec(:)) == 0)
                cla(this.visHandles.axesRes);
                cla(this.visHandles.axesResHis);
                if(this.visualizationParams.showLegend)
                    this.makeLegend(hAxMain,lStr)
                end
                return;
            end            
            %% we have parameters, plot exponentials
            if(this.visualizationParams.plotExp)
                [lStr, exponentials] = this.makeExponentialsPlot(hAxMain,xAxis,apObj,xVec,lStr,this.dynVisParams,this.visualizationParams);
            end
            %% optimizer initialization (guess)
            if(this.visualizationParams.plotInit)
                if(sum(iVec(:)) == 0)
                    model = [];
                else
                    %todo
%                     apObj.compModel(splitXVec(iVec,apObj.volatile.cMask));
%                     model = apObj.model(1:apObj.dLen);
%                     model(model < 1e-1) = 1e-1;
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
        end
        
        function [e_vec, rh] = visRes(this,ch,y,x,apObj,hAxRes,hAxResHis)
            %% plot error vector
            e_vec = [];
            rh = [];
            if(isempty(apObj))
                [apObj, x_vec] = this.getVisParams(ch,y,x);
            else
                [~, x_vec] = this.getVisParams(ch,y,x);
            end
            %% check handles
            if(nargin < 7 || ~ishandle(hAxResHis))
                hAxResHis = this.visHandles.axesResHis;
            end
            if(nargin < 6 || ~ishandle(hAxRes))
                hAxRes = this.visHandles.axesRes;
            end
            %% prepare #1 
            axis(hAxRes,'on');
            axis(hAxResHis,'on');
            cla(hAxRes);
            cla(hAxResHis);
            ylabel(hAxRes,'Norm. Error');
            xlabel(hAxRes,'Time (ns)');
            grid(hAxRes,'on');
            data = apObj.getMeasurementData(ch);
            xAxis = this.FLIMXObj.curSubject.timeVector(1:length(data));
            if(sum(x_vec(:)) == 0)
                cla(this.visHandles.axesRes);
                set(this.visHandles.editResScal,'String','');
                set(hAxResHis,'XTickLabel','');
                set(hAxResHis,'YTickLabel','');
                if(~this.dynVisParams.timeScalingAuto)
                    xAxis = xAxis(this.dynVisParams.timeScalingStart:this.dynVisParams.timeScalingEnd);
                end
                xlim(hAxRes,[xAxis(1) xAxis(end)]);
                %axis(hAxRes,'on');                
                return
            end                      
            %% prepare #2           
            model = apObj.getModel(ch,x_vec);            
            e_vec = zeros(length(data),1);
            data(isnan(data)) = 0;
            if(apObj.basicParams.approximationTarget == 2 && ch == 4)
                e_vec(1:apObj.getFileInfo(ch).nrTimeChannels) = ((data(1:apObj.getFileInfo(ch).nrTimeChannels))-(model(1:apObj.getFileInfo(ch).nrTimeChannels)))./(model(1:apObj.getFileInfo(ch).nrTimeChannels))*100;
            else
                e_vec(1:apObj.getFileInfo(ch).nrTimeChannels) = ((data(1:apObj.getFileInfo(ch).nrTimeChannels))-(model(1:apObj.getFileInfo(ch).nrTimeChannels)))./sqrt(abs(data(1:apObj.getFileInfo(ch).nrTimeChannels))); % Weighting in lsqnonlin is 1/std; in Poisson statistics: 1/sqrt(counts)
            end
            nz_idx =  apObj.getDataNonZeroMask(ch);
            ds = find(nz_idx,1,'first');
            de = find(nz_idx,1,'last');
            [StartPosition, EndPosition] = apObj.getStartEndPos(ch);
            nz_idx(1:StartPosition) = false;
            nz_idx(EndPosition:end) = false;
            e_vec(isinf(e_vec)) = 0;
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
                %axis(hAxResHis,'off');
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
%             lb = prctile(data(:),0.1);
%             ub = prctile(data(:),99.9);
            img = image2ColorMap(data,this.dynVisParams.cmIntensity);
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
                this.plotSuppData(this.visHandles.axesMain);
                this.plotSuppData(this.visHandles.axesSupp);
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
%             lb = prctile(data(:),0.1);
%             ub = prctile(data(:),99.9);
            img = image2ColorMap(data,this.dynVisParams.cm);
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
                this.plotSuppDataCP(this.visHandles.axesMain);
                this.plotSuppDataCP(this.visHandles.axesSupp);
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
            this.plotSuppDataCP(this.visHandles.axesSupp);
        end
        
        %% GUI callbacks
        function GUI_buttonLeft_Callback(this,hObject,eventdata)
            %call of editX control
            set(this.visHandles.editX,'String',this.currentX-1);
            this.GUI_editX_Callback(this.visHandles.editX,[]);
        end
        
        function GUI_popupStudy_Callback(this,hObject,eventdata)
            %callback to change study name
            try
                set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName());
            if(~isempty(subjects) && iscell(subjects))
                cs = subjects{min(get(this.visHandles.popupSubject,'Value'),length(subjects))};
                set(this.visHandles.popupCondition,'Value',1);
                this.FLIMXObj.setCurrentSubject(this.currentStudy,FDTree.defaultConditionName(),cs);
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
                set(this.visHandles.buttonStop,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentCondition,this.currentSubject);
            set(this.visHandles.buttonStop,'String','Stop');
        end
        
        function GUI_popupCondition_Callback(this,hObject,eventdata)
            %callback to change the current condition
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentCondition);
            if(~isempty(subjects) && iscell(subjects))
                idx = find(strcmp(subjects,this.currentSubject), 1);
                if(~isempty(idx))
                    %last subject is also a member of the new condition -> just update the GUI controls
                    this.setupGUI();
                else
                    %last subject is not a member of the new condition -> choose a different subject
                    this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentCondition,subjects{min(get(this.visHandles.popupSubject,'Value'),length(subjects))});
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
            current = str2double(get(hObject,'String'));
            if(hObject == this.visHandles.editCountsScalStart)
                current = min(current,this.dynVisParams.countsScalingEnd-0.01);
                this.dynVisParams.countsScalingStart = current;
            else
                current = max(current,this.dynVisParams.countsScalingStart+0.01);
                this.dynVisParams.countsScalingEnd = current;
            end
            set(hObject,'String',num2str(current,'%G'));
            this.visCurFit(this.currentChannel,this.currentY,this.currentX);
        end
        
        function GUI_showInitialization_Callback(this,hObject,eventdata)
            %toggle between merge display and pixel display
            this.setupGUI();
            this.updateGUI(true);
        end
        
        function GUI_popupChannel_Callback(this,hObject,eventdata)
            %change the current channel of the GUI
            this.currentChannel = get(hObject,'Value');
        end
        
        function GUI_popupROI_Callback(this,hObject,eventdata)
            %call of popupROI control
            this.setupGUI();
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
            %             if(isMultipleCall)
            %                 return
            %             end
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
            %% main axes
            cpMain = get(this.visHandles.axesMain,'CurrentPoint');
            cpMain = cpMain(logical([1 1 0; 0 0 0]));
            xl = this.visHandles.axesMain.XLim;
            yl = this.visHandles.axesMain.YLim;
            if(cpMain(1) >= xl(1) && cpMain(1) <= xl(2) && cpMain(2) >= yl(1) && cpMain(2) <= yl(2) && ~isempty(this.currentDecayData) && this.visualizationParams.plotCurLinesAndText)
                %inside main axes
                set(this.visHandles.FLIMXFitGUIFigure,'Pointer','cross');
                yVal = this.currentDecayData;
                %xPos = mouse coordinates transformed to dimension of YData
                tVec = abs(this.FLIMXObj.curSubject.timeVector - cpMain(1));
                [~,xPos] = min(tVec(:));
                if(abs(xPos - this.dynVisParams.timeScalingStart) >= 10 && xPos > this.dynVisParams.timeScalingStart)
                    %at least 10 time channels difference
                    this.visHandles.editTimeScalEnd.String = num2str(xPos .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                end
                %cursorline for axesres
                if(~ishghandle(this.visHandles.cursorLineResiduum))
                    this.visHandles.cursorLineResiduum = line([NaN NaN], ylim(this.visHandles.axesRes),'Color' , this.visualizationParams.plotCurLinesColor, 'Parent', this.visHandles.axesRes, 'LineStyle' , this.visualizationParams.plotCurLinesStyle, 'LineWidth' , this.visualizationParams.plotCurlineswidth);
                end
                this.visHandles.cursorLineResiduum.XData = [cpMain(1) cpMain(1)];
                if(xPos > 0 && xPos <= length(yVal) && ~isempty(this.currentDecayData))
                    this.mouseOverlayBoxMain.draw(cpMain,{sprintf('Time: %04.2fns',xPos.*this.FLIMXObj.curSubject.timeChannelWidth/1000), sprintf('Counts: %d',yVal(xPos))},yVal(xPos));
                end
                %draw zoom area when mouse button down
                if(ishghandle(this.visHandles.scaleZoomRectangle))
                    this.visHandles.scaleZoomRectangle.Position(3) = max(cpMain(1)-this.visHandles.scaleZoomRectangle.Position(1),10*this.FLIMXObj.curSubject.timeVector(2));
                    this.mouseOverlayBoxMain.displayBoxOnTop();
                end
                %clear other mouse overs
                this.mouseOverlayBoxSupp.clear();
                this.mouseOverlayBoxRaw.clear();
            else
                cpMain = [];
                this.mouseOverlayBoxMain.clear();
                if(ishghandle(this.visHandles.cursorLineResiduum))
                    this.visHandles.cursorLineResiduum.XData = [NaN NaN];
                end
                %% support axes
                cpSupp = get(this.visHandles.axesSupp,'CurrentPoint');
                cpSupp = round(cpSupp(logical([1 1 0; 0 0 0])));
                xl = this.visHandles.axesSupp.XLim;
                yl = this.visHandles.axesSupp.YLim;
                if(cpSupp(1) >= xl(1) && cpSupp(1) <= xl(2) && cpSupp(2) >= yl(1) && cpSupp(2) <= yl(2))
                    %inside support axes
                    set(this.visHandles.FLIMXFitGUIFigure,'Pointer','cross');
                    data = this.axesSuppData;
                    if(~isempty(data))
                        str = FLIMXFitGUI.num4disp(data(min(size(data,1),cpSupp(2)),min(size(data,2),cpSupp(1))));
                        this.mouseOverlayBoxSupp.draw(cpSupp,[sprintf('x:%d y:%d',cpSupp(1),cpSupp(2));str]);
                        this.mouseOverlayBoxSupp.displayBoxOnTop();
                    end
                    %clear other mouse overs
                    this.mouseOverlayBoxMain.clear();
                    this.mouseOverlayBoxRaw.clear();
                else
                    cpSupp = [];
                    this.mouseOverlayBoxSupp.clear();
                    %% raw intensity axes
                    cpRaw = get(this.visHandles.axesRaw,'CurrentPoint');
                    cpRaw = round(cpRaw(logical([1 1 0; 0 0 0])));
                    xl = this.visHandles.axesRaw.XLim;
                    yl = this.visHandles.axesRaw.YLim;
                    if(cpRaw(1) >= xl(1) && cpRaw(1) <= xl(2) && cpRaw(2) >= yl(1) && cpRaw(2) <= yl(2))
                        %inside raw intensity axes
                        set(this.visHandles.FLIMXFitGUIFigure,'Pointer','cross');
                        data = this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel);
                        if(~isempty(data))
                            str = FLIMXFitGUI.num4disp(data(min(size(data,1),cpRaw(2)),min(size(data,2),cpRaw(1))));
                            this.mouseOverlayBoxRaw.draw(cpRaw,[sprintf('x:%d y:%d',cpRaw(1),cpRaw(2));str]);
                            this.mouseOverlayBoxRaw.displayBoxOnTop();
                        end
                        %clear other mouse overs
                        this.mouseOverlayBoxMain.clear();
                        this.mouseOverlayBoxSupp.clear();
                    else
                        cpRaw = [];
                        this.mouseOverlayBoxRaw.clear();
                    end
                end
            end
            if(isempty(cpMain) && isempty(cpSupp) && isempty(cpRaw))
                set(this.visHandles.FLIMXFitGUIFigure,'Pointer','arrow');
            end
            inFunction = []; %enable callback
        end
        
        function GUI_mouseButtonUp_Callback(this,hObject,eventdata)
            %executes on clickrelease in window            
            cpMain = get(this.visHandles.axesMain,'CurrentPoint');
            cpMain = cpMain(logical([1 1 0; 0 0 0]));
            xl = xlim(this.visHandles.axesMain);
            yl = ylim(this.visHandles.axesMain);
            if(cpMain(1) < xl(1) || cpMain(1) > xl(2) || cpMain(2) < yl(1) || cpMain(2) > yl(2))
                cpMain = [];
            end
            %% main axes
            if(~isempty(cpMain))
                %xPos = mouse coordinates transformed to dimension of YData
                tVec = abs(this.FLIMXObj.curSubject.timeVector - cpMain(1));
                [~,xPos] = min(tVec(:));
                switch get(hObject,'SelectionType')
                    case 'normal'                        
                        if(cpMain(1) >= xl(1) && cpMain(1) <= xl(2) && cpMain(2) >= yl(1) && cpMain(2) <= yl(2))
                            if(abs(xPos - this.dynVisParams.timeScalingStart) >= 10)
                                %at least 10 time channels difference
                                if(xPos < this.dynVisParams.timeScalingStart)
                                    this.dynVisParams.timeScalingEnd = this.dynVisParams.timeScalingStart;
                                    this.dynVisParams.timeScalingStart = uint32(xPos);
                                else
                                    this.dynVisParams.timeScalingEnd = uint32(xPos);
                                end
                                this.visHandles.editTimeScalStart.String = num2str(this.dynVisParams.timeScalingStart .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                                this.visHandles.editTimeScalEnd.String = num2str(this.dynVisParams.timeScalingEnd .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                                this.dynVisParams.timeScalingStartOld = this.dynVisParams.timeScalingStart;
                                this.dynVisParams.timeScalingEndOld = this.dynVisParams.timeScalingEnd;
                                set(this.visHandles.radioTimeScalManual,'Value', 1);
                                set(this.visHandles.radioTimeScalAuto,'Value', 0);
                                this.GUI_radioTimeScal_Callback(this, this.visHandles.radioTimeScalManual);
                            else
                                %abort zoom in main axes
                                if(ishghandle(this.visHandles.scaleZoomRectangle))
                                    delete(this.visHandles.scaleZoomRectangle);
                                end
                                this.dynVisParams.timeScalingStart = this.dynVisParams.timeScalingStartOld;
                                this.dynVisParams.timeScalingEnd = this.dynVisParams.timeScalingEndOld;
                                this.visHandles.editTimeScalStart.String = num2str(this.dynVisParams.timeScalingStartOld .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                                this.visHandles.editTimeScalEnd.String = num2str(this.dynVisParams.timeScalingEndOld .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                            end
                        end
                    case 'alt'
                        %reset zoom in main axes on right click
                        set(this.visHandles.radioTimeScalManual,'Value', 0);
                        set(this.visHandles.radioTimeScalAuto,'Value', 1);
                        this.GUI_radioTimeScal_Callback(this, this.visHandles.radioTimeScalAuto);
                        yVal = this.currentDecayData;
                        if(xPos > 0 && xPos <= length(yVal) && ~isempty(this.currentDecayData))
                            this.mouseOverlayBoxMain.draw(cpMain,{sprintf('Time: %04.2fns',xPos.*this.FLIMXObj.curSubject.timeChannelWidth/1000), sprintf('Counts: %d',yVal(xPos))},yVal(xPos));
                        end
                end
            else
                %no hit on main axes, try supp axes
                cpSupp = get(this.visHandles.axesSupp,'CurrentPoint');
                cpSupp = round(cpSupp(logical([1 1 0; 0 0 0])));
                xl = xlim(this.visHandles.axesSupp);
                yl = ylim(this.visHandles.axesSupp);
                if(cpSupp(1) < xl(1) || cpSupp(1) > xl(2) || cpSupp(2) < yl(1) || cpSupp(2) > yl(2))
                    cpSupp = [];
                end
                if(~isempty(cpSupp))
                    switch get(hObject,'SelectionType')
                        case 'normal'
                            set(this.visHandles.editX,'String',num2str(cpSupp(1)));
                            set(this.visHandles.editY,'String',num2str(cpSupp(2)));
%                             data = this.axesSuppData;
%                             if(~isempty(data))
%                                 str = FLIMXFitGUI.num4disp(data(min(size(data,1),cpSupp(2)),min(size(data,2),cpSupp(1))));
%                                 this.mouseOverlayBoxSupp.draw(cpSupp,[sprintf('x:%d y:%d',cpSupp(1),cpSupp(2));str]);
%                             end
                            this.currentX = max(min(round(abs(str2double(get(this.visHandles.editX,'String')))),this.maxX),1);
                            this.currentY = max(min(round(abs(str2double(get(this.visHandles.editY,'String')))),this.maxY),1);
                            if(get(this.visHandles.checkAutoFitPixel,'Value') && ~this.FLIMXObj.curSubject.isPixelResult(this.currentChannel,this.currentY,this.currentX,this.showInitialization))
                                %automatically fit current pixel when activated
                                this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
                            else
                                this.updateGUI(0);
                            end
                    end
                else
                    %no hit on supp axes, try raw axes
                    cpRaw = get(this.visHandles.axesRaw,'CurrentPoint');
                    cpRaw = round(cpRaw(logical([1 1 0; 0 0 0])));
                    xl = xlim(this.visHandles.axesRaw);
                    yl = ylim(this.visHandles.axesRaw);
                    if(cpRaw(1) < xl(1) || cpRaw(1) > xl(2) || cpRaw(2) < yl(1) || cpRaw(2) > yl(2))
                        cpRaw = [];
                    end
                    if(~isempty(cpRaw))
                        switch get(hObject,'SelectionType')
                            case 'normal'
                                roi = this.FLIMXObj.curSubject.ROICoordinates;
                                cpRaw(1) = cpRaw(1)-roi(1)+1;
                                cpRaw(2) = cpRaw(2)-roi(3)+1;
                                if(cpRaw(1) >= 1 && cpRaw(1) <= this.maxX && cpRaw(2) >= 1 && cpRaw(2) <= this.maxY)
                                    set(this.visHandles.editX,'String',num2str(cpRaw(1)));
                                    set(this.visHandles.editY,'String',num2str(cpRaw(2)));
%                                     data = this.FLIMXObj.curSubject.getRawDataFlat(this.currentChannel);
%                                     if(~isempty(data))
%                                         str = FLIMXFitGUI.num4disp(data(min(size(data,1),cpRaw(2)),min(size(data,2),cpRaw(1))));
%                                         this.mouseOverlayBoxRaw.draw(cpRaw,[sprintf('x:%d y:%d',cpRaw(1),cpRaw(2));str]);
%                                     end
                                    this.currentX = max(min(round(abs(str2double(get(this.visHandles.editX,'String')))),this.maxX),1);
                                    this.currentY = max(min(round(abs(str2double(get(this.visHandles.editY,'String')))),this.maxY),1);
                                    if(get(this.visHandles.checkAutoFitPixel,'Value') && ~this.FLIMXObj.curSubject.isPixelResult(this.currentChannel,this.currentY,this.currentX,this.showInitialization))
                                        %automatically fit current pixel when activated
                                        this.menuFitPixel_Callback(this.visHandles.menuFitPixel,[]);
                                    else
                                        this.updateGUI(0);
                                    end
                                end
                        end
                    else
                        %mouse button was released outside of all axes
                        switch get(hObject,'SelectionType')
                            case 'normal'
                                %abort zoom in main axes
                                if(ishghandle(this.visHandles.scaleZoomRectangle))
                                    delete(this.visHandles.scaleZoomRectangle);
                                end
                                this.dynVisParams.timeScalingStart = this.dynVisParams.timeScalingStartOld;
                                this.dynVisParams.timeScalingEnd = this.dynVisParams.timeScalingEndOld;
                                this.visHandles.editTimeScalStart.String = num2str(this.dynVisParams.timeScalingStartOld .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                                this.visHandles.editTimeScalEnd.String = num2str(this.dynVisParams.timeScalingEndOld .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                        end
                    end
                end
            end
        end
        
        function GUI_mouseButtonDown_Callback(this,hObject,eventdata)
            %executes on clicking down in window            
            switch get(hObject,'SelectionType')
                case 'normal'
                    cp = get(this.visHandles.axesMain,'CurrentPoint');
                    cp = cp(logical([1 1 0; 0 0 0]));
                    if(any(cp(:) < 0))
                        %outside main axes
                        return;
                    end
                    xl = xlim(this.visHandles.axesMain);
                    yl = ylim(this.visHandles.axesMain);
                    if(cp(1) >= xl(1) && cp(1) <= xl(2) && cp(2) >= yl(1) && cp(2) <= yl(2))
                        if(ishghandle(this.visHandles.scaleZoomRectangle))
                            delete(this.visHandles.scaleZoomRectangle)
                        end
                        this.visHandles.scaleZoomRectangle = rectangle('Position',[cp(1),yl(1),10*this.FLIMXObj.curSubject.timeVector(2),yl(2)-yl(1)],'EdgeColor',[0 0.75 0 this.visualizationParams.plotCoordinateBoxTransparency],'FaceColor',[0 0.75 0 this.visualizationParams.plotCoordinateBoxTransparency],'Parent',this.visHandles.axesMain);
                        %xPos = mouse coordinates transformed to dimension of YData
                        tVec = abs(this.FLIMXObj.curSubject.timeVector - cp(1));
                        [~,xPos] = min(tVec(:));
                        this.dynVisParams.timeScalingStart = uint32(xPos);
                        this.visHandles.editTimeScalStart.String = num2str(xPos .* this.FLIMXObj.curSubject.timeChannelWidth,'%.02f');
                    end
            end
        end

        
        %% menu callbacks
        function menuExportFiles_Callback(this,hObject,eventdata)
            %write results to disc (again)
            expDir = uigetdir(this.FLIMXObj.getWorkingDir());
            if(isempty(expDir) || ~expDir)
                return
            end
            %save to disc
            this.FLIMXObj.curSubject.exportMatFile([],expDir);
        end
        
        function menuExportExcel_Callback(this,hObject,eventdata)
            %export data of current graphs and info table to excel file
            formats = {'*.xls','Excel File (*.xls)'};
            [file, path] = uiputfile(formats,'Export as');
            if ~path ; return ; end
            fn = fullfile(path,file);
            %save fit
            [xAxis, data, irf, model, exponentials, residuum, residuumHist] = this.visCurFit(this.currentChannel,this.currentY,this.currentX);
            exponentials = exponentials(:,1:end-1);
            if(isempty(model))
                tmp = num2cell([xAxis,data,irf]);
                colHead = {'t','Measured','IRF'};
            else
                tmp = num2cell([xAxis,data,irf,model,residuum,exponentials]);
                tmp(1:length(residuumHist),end+1) = num2cell(residuumHist);
                colHead = {'t','Measured','IRF','Model','Residuum'};
                for i = 1:size(exponentials,2)
                    colHead(end+1) = {sprintf('Exp. %d',i)};
                end
                colHead(end+1) = {'Residuum Histogram'};
            end
            exportExcel(fn,tmp,colHead,'',sprintf('Data %s ch%d (y%d,x%d)',this.FLIMXObj.curSubject.getDatasetName(),this.currentChannel,this.currentY,this.currentX),'');
            %save table info
            [apObj, ~, ~, ~, ~, ~, ~, ~, ~, ~, tableInfo] = this.getVisParams(this.currentChannel,this.currentY,this.currentX,true);
            tableInfo(end+2,1:4) = {'x',this.currentX,'y',this.currentY};
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
            this.FLIMXObj.irfMgrGUI.currentTimePoints = this.FLIMXObj.curSubject.getFileInfoStruct(this.currentChannel).nrTimeChannels;
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
        
        function menuUserGuide_Callback(this,hObject,eventdata)
            %
            FLIMX.openFLIMXUserGuide();
        end
        
        function menuWebsite_Callback(this,hObject,eventdata)
            %
            FLIMX.openFLIMXWebSite();
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
            str,mask,{this.FLIMXObj.curSubject.basicParams.scatterStudy},this.currentChannel);
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
                str,mask,this.FLIMXObj.fdt.getStudyNames(),...
                this.currentChannel);
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
                    if(this.generalParams.flimParameterView ~= new.general.flimParameterView)
                        this.FLIMXObj.fdt.unloadAllChannels();                        
                    end
                    this.FLIMXObj.paramMgr.setParamSection('general',new.general);
                    this.axesRawMgr.setReverseYDirFlag(new.general.reverseYDir);
                    this.axesROIMgr.setReverseYDirFlag(new.general.reverseYDir);
                    this.FLIMXObj.FLIMVisGUI.setupGUI();
                    this.FLIMXObj.FLIMVisGUI.updateGUI([]);
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
            this.FLIMXObj.FLIMFit.startFitProcess([],[],[]);            
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
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,this.currentCondition);
            tStart = clock;
            for i = 1:length(subjects)
                this.FLIMXObj.setCurrentSubject(this.currentStudy,this.currentCondition,subjects{i});
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
            axis(this.visHandles.axesMain,'off');
            axis(this.visHandles.axesRaw,'off');
            axis(this.visHandles.axesSupp,'off');
            axis(this.visHandles.axesRes,'off');
            axis(this.visHandles.axesResHis,'off');
                        
            %set handles for zoom in main axes and current mouse position in residdum
            this.visHandles.cursorLineResiduum = []; %cursorline in axesres
            this.visHandles.scaleZoomRectangle = []; %rectangle when mouse button down for zoom
            
            %set callbacks
            set(this.visHandles.FLIMXFitGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback, 'WindowButtonDownFcn', @this.GUI_mouseButtonDown_Callback);
            
            %figure
            set(this.visHandles.FLIMXFitGUIFigure,'Units','pixels');
            %edit            
            set(this.visHandles.editX,'String',num2str(this.currentX),'Callback',@this.GUI_editX_Callback,'TooltipString','Enter horizontal position of current pixel');
            set(this.visHandles.editY,'String',num2str(this.currentY),'Callback',@this.GUI_editY_Callback,'TooltipString','Enter vertical position of current pixel');
            set(this.visHandles.editResScal,'Callback',@this.GUI_editResScal_Callback,'TooltipString','Enter limit for residuum scaling');
            set(this.visHandles.editTimeScalStart,'Callback',@this.GUI_editTimeScal_Callback,'TooltipString','Enter lower limit (in ps) for custom time scaling');
            set(this.visHandles.editTimeScalEnd,'Callback',@this.GUI_editTimeScal_Callback,'TooltipString','Enter upper limit (in ps) for custom time scaling');
            set(this.visHandles.editCountsScalStart,'Callback',@this.GUI_editCountsScal_Callback,'TooltipString','Enter lower limit for custom intensity / anisotropy scaling');
            set(this.visHandles.editCountsScalEnd,'Callback',@this.GUI_editCountsScal_Callback,'TooltipString','Enter upper limit for custom intensity / anisotropy scaling');
            
            %buttons
            set(this.visHandles.buttonSubjectDec,'FontName','Symbol','String',char(173),'Callback',@this.GUI_buttonSwitchSubject_Callback,'TooltipString','Go to previous subject'); 
            set(this.visHandles.buttonSubjectInc,'FontName','Symbol','String',char(175),'Callback',@this.GUI_buttonSwitchSubject_Callback,'TooltipString','Go to next subject'); 
            set(this.visHandles.buttonRight,'String',char(174),'Callback',@this.GUI_buttonRight_Callback,'TooltipString','Go to pixel to the right');
            set(this.visHandles.buttonLeft,'String',char(172),'Callback',@this.GUI_buttonLeft_Callback,'TooltipString','Go to pixel to the left');
            set(this.visHandles.buttonUp,'String',char(173),'Callback',@this.GUI_buttonUp_Callback,'TooltipString','Go to pixel above');
            set(this.visHandles.buttonDown,'String',char(175),'Callback',@this.GUI_buttonDown_Callback,'TooltipString','Go to pixel below');
            set(this.visHandles.buttonFitCurrentPixel,'Callback',@this.menuFitPixel_Callback,'TooltipString','Approximate current pixel');
            set(this.visHandles.toggleShowInitialization,'Callback',@this.GUI_showInitialization_Callback,'TooltipString','Show initialization of fluorescence lifetime approimation');
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback,'TooltipString','Stop current computation');
            set(this.visHandles.buttonResScalDec,'String',char(172),'Callback',@this.GUI_buttonResScal_Callback,'TooltipString','Decrease residuum scaling limit');
            set(this.visHandles.buttonResScalInc,'String',char(174),'Callback',@this.GUI_buttonResScal_Callback,'TooltipString','Increase residuum scaling limit');
            set(this.visHandles.buttonTimeScalStartDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback,'TooltipString','Decrease lower limit of custom time scaling');
            set(this.visHandles.buttonTimeScalStartInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback,'TooltipString','Increase lower limit of custom time scaling');
            set(this.visHandles.buttonTimeScalEndDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback,'TooltipString','Decrease upper limit of custom time scaling');
            set(this.visHandles.buttonTimeScalEndInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback,'TooltipString','Increase upper limit of custom time scaling');
            set(this.visHandles.buttonCountsScalStartDec,'String',char(172),'Callback',@this.GUI_buttonCountsScal_Callback,'TooltipString','Decrease lower limit of custom intensity / anisotropy scaling');
            set(this.visHandles.buttonCountsScalStartInc,'String',char(174),'Callback',@this.GUI_buttonCountsScal_Callback,'TooltipString','Increase lower limit of custom intensity / anisotropy scaling');
            set(this.visHandles.buttonCountsScalEndDec,'String',char(172),'Callback',@this.GUI_buttonCountsScal_Callback,'TooltipString','Decrease upper limit of custom intensity / anisotropy scaling');
            set(this.visHandles.buttonCountsScalEndInc,'String',char(174),'Callback',@this.GUI_buttonCountsScal_Callback,'TooltipString','Increase upper limit of custom intensity / anisotropy scaling');
            
            %checkbox
            set(this.visHandles.checkAutoFitPixel,'Callback',@this.GUI_checkAutoFitPixel_Callback,'TooltipString','Automatically approximate current pixel on mouse click (may be slow!)');
            
            %radio
            set(this.visHandles.radioResScalAuto,'Callback',@this.GUI_radioResScal_Callback,'TooltipString','Automatic residuum scaling');
            set(this.visHandles.radioResScalManual,'Callback',@this.GUI_radioResScal_Callback,'TooltipString','Manual residuum scaling');
            set(this.visHandles.radioTimeScalAuto,'Callback',@this.GUI_radioTimeScal_Callback,'TooltipString','Automatic time scaling');
            set(this.visHandles.radioTimeScalManual,'Callback',@this.GUI_radioTimeScal_Callback,'TooltipString','Manual time scaling');
            set(this.visHandles.radioCountsScalAuto,'Callback',@this.GUI_radioCountsScal_Callback,'TooltipString','Automatic intensity / anisotropy scaling');
            set(this.visHandles.radioCountsScalManual,'Callback',@this.GUI_radioCountsScal_Callback,'TooltipString','Manual intensity / anisotropy scaling');
            
            %popup
            set(this.visHandles.popupStudy,'Callback',@this.GUI_popupStudy_Callback,'TooltipString','Select a study');
            set(this.visHandles.popupSubject,'Callback',@this.GUI_popupSubject_Callback,'TooltipString','Select a subject');
            set(this.visHandles.popupCondition,'Callback',@this.GUI_popupCondition_Callback,'TooltipString','Select a condition');
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select a channel');
            set(this.visHandles.popupROI,'Callback',@this.GUI_popupROI_Callback,'TooltipString','Select FLIM parameter to display');
            
            %menu            
            set(this.visHandles.menuROIRedefine,'Callback',@this.menuROIRedefine_Callback);
            
            set(this.visHandles.menuExportShot,'Callback',@this.menuExportScreenshot_Callback);
            set(this.visHandles.menuExportFiles,'Callback',@this.menuExportFiles_Callback);
            set(this.visHandles.menuExportExcel,'Callback',@this.menuExportExcel_Callback);
            
            set(this.visHandles.menuSimFLIM,'Callback',@this.menuSimFLIM_Callback);
            set(this.visHandles.menuSimAnalysis,'Callback',@this.menuSimAnalysis_Callback);
            set(this.visHandles.menuIRFMgr,'Callback',@this.menuIRFMgr_Callback);
            
            set(this.visHandles.menuVersionInfo,'Callback',@this.menuVersionInfo_Callback);
            set(this.visHandles.menuUserGuide,'Callback',@this.menuUserGuide_Callback);
            set(this.visHandles.menuWebsite,'Callback',@this.menuWebsite_Callback);
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
            %batch job manager
            set(this.visHandles.menuOpenBatchJobMgr,'Callback',@this.menuOpenBatchJobMgr_Callback);
            set(this.visHandles.menuBatchSubjectCurCh,'Callback',@this.menuBatchSubject_Callback);
            set(this.visHandles.menuBatchSubjectAllCh,'Callback',@this.menuBatchSubject_Callback);
            set(this.visHandles.menuBatchStudy,'Callback',@this.menuBatchStudy_Callback);
            %study manager
            set(this.visHandles.menuOpenStudyMgr,'Callback',@this.menuOpenStudyMgr_Callback);
            %FLIMXVis
            set(this.visHandles.menuOpenFLIMXVis,'Callback',@this.menuOpenFLIMXVis_Callback);
            
            this.axesRawMgr = axesWithROI(this.visHandles.axesRaw,this.visHandles.axesCbRaw,this.visHandles.textCbRawBottom,this.visHandles.textCbRawTop,this.visHandles.editCPRaw,this.dynVisParams.cmIntensity);
            this.axesRawMgr.setROILineColor('r');
            this.axesROIMgr = axesWithROI(this.visHandles.axesSupp,this.visHandles.axesCbSupp,this.visHandles.textCbSuppBottom,this.visHandles.textCbSuppTop,this.visHandles.editCPSupp,this.dynVisParams.cm);
            this.mouseOverlayBoxMain = mouseOverlayBox(this.visHandles.axesMain);
            this.mouseOverlayBoxMain.setVerticalBoxPositionMode(0);
            this.mouseOverlayBoxSupp = mouseOverlayBox(this.visHandles.axesSupp);
            this.mouseOverlayBoxRaw = mouseOverlayBox(this.visHandles.axesRaw);
            
%             this.setupGUI();
%             this.updateGUI(true);
        end                
    end %methods protected
    
    methods(Static)
        function out = num4disp(data)
            %convert numeric value(s) to string(s), returns a cell array with size of data
            if(ischar(data))
                return
            end
            [x,y,z] = size(data);
            data = reshape(data,[],1);
            da = abs(data);
            idxInt = isinteger(data);
            idx100 = idxInt | abs(data - fix(data)) < eps('single') | da >= 100;
            idx10 = ~idx100 & da < 100 & da >= 10;
            idx1 = ~(idx100 | idx10);
            out = cell(size(data));
            out(idx100) = cellstr(num2str(data(idx100),'%.0f'));
            out(idx10) = cellstr(num2str(data(idx10),'%2.1f'));
            out(idx1) = cellstr(num2str(data(idx1),'%1.2f'));
            out = strtrim(out);
            out = reshape(out,x,y,z);
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
                plot(hAx,xAxis,model,...
                    'Linewidth',staticVisParams.(sprintf('plot%sLinewidth',paramName)),...
                    'Linestyle',staticVisParams.(sprintf('plot%sLinestyle',paramName)),...
                    'Color',staticVisParams.(sprintf('plot%sColor',paramName)),...
                    'Marker',staticVisParams.(sprintf('plot%sMarkerstyle',paramName)),...
                    'Markersize',staticVisParams.(sprintf('plot%sMarkersize',paramName)));
                if(numel(xAxis > 1))
                    xlim(hAx,[xAxis(1) xAxis(end)]);
                end
            catch ME
                warning('FLIMXFitGUI:makeVerticalLinePlot','%s',ME.message);
                return
            end
            if(~isempty(legendName))
                lStr(end+1) = {legendName};
            end
        end
                
        function [lStr, exponentials] = makeExponentialsPlot(hAx,xAxis,apObj,x_vec,lStr,dynVisParams,staticVisParams,exponentials,dMin)
            %plot exponentials and scatter data to hAx
            %[amps taus tcis scAmps scShifts scOset vShift hShift oset] = sliceXVec(x_vec,fitParams);
            if(nargin < 9)
                dMin = 1e-2;
            end
            if(nargin < 8)
                %compute exponentials
                hmOld = apObj.basicParams.heightMode;
                apObj.basicParams.heightMode = 1;
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
                model_vec(model_vec < dMin) = dMin;
                if(~dynVisParams.timeScalingAuto)
                    model_vec = model_vec(dynVisParams.timeScalingStart:dynVisParams.timeScalingEnd);
                end
                plot(hAx,xAxis,model_vec,'Linestyle',staticVisParams.plotExpLinestyle,'Linewidth',staticVisParams.plotExpLinewidth,...
                    'Color',staticVisParams.(sprintf('plotExp%dColor',i-5*(ceil(i/5)-1))),'Marker',staticVisParams.plotExpMarkerstyle,'Markersize',staticVisParams.plotExpMarkersize);
                if(i <= apObj.basicParams.nExp)
                    lStr(end+1) = {sprintf('Exp. %d',i)};
                else
                    lStr(end+1) = {sprintf('Scatter. %d',i-apObj.basicParams.nExp)};
                end
            end
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
            legend(hAx,lStr,'AutoUpdate','off');
        end
    end %methods(Static)
    
end %classdef
