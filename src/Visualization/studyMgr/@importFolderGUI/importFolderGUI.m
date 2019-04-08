classdef importFolderGUI < handle
    %=============================================================================================================
    %
    % @file     importFolderGUI.m
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
    % @brief    A class to represent a GUI to import a folder of SDT files
    %
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        currentFiles = [];
        currentPath = '';
        measurementObj = [];
    end
    
    properties (Dependent = true)
        currentStudy = '';
    end
    
    methods
        function this = importFolderGUI(flimX)
            %constructor
            if(isempty(flimX))
                error('Handle to FLIMX object required!');
            end
            this.FLIMXObj = flimX;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.importFolderFigure) || ~strcmp(get(this.visHandles.importFolderFigure,'Tag'),'importFolderFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            figure(this.visHandles.importFolderFigure);
        end
        
        function closeCallback(this)
            %executed when figure should be closed
            if(this.isOpenVisWnd())
                delete(this.visHandles.importFolderFigure);
            end
        end
        
        function setupGUI(this)
            %setup GUI controls
            %study selection
            set(this.visHandles.popupStudySel,'String',this.FLIMXObj.fdt.getStudyNames());
            if(get(this.visHandles.radioExistingStudy,'Value'))
                set(this.visHandles.popupStudySel,'Visible','on');
                set(this.visHandles.editStudyName,'Visible','off');
            else
                set(this.visHandles.popupStudySel,'Visible','off');
                set(this.visHandles.editStudyName,'Visible','on');
                str = get(this.visHandles.popupStudySel,'String');
                if(~isempty(str) && iscell(str))
                    set(this.visHandles.editStudyName,'String',str{get(this.visHandles.popupStudySel,'Value')});
                end
            end
            %table            
            set(this.visHandles.tableSubjects,'Data',this.buildTableData(false));
        end
        
        function out = buildTableData(this,askUserFlag)
            %build content of the table, based on current values or from scratch
            out = get(this.visHandles.tableSubjects,'Data');
            if(isempty(out))
                out = cell(length(this.currentFiles),4);                
                for i = 1:length(this.currentFiles)                    
                    out{i,1} = this.currentFiles(i,1).name;
                    idx = strfind(out{i,1},filesep);
                    if(get(this.visHandles.popupSubjectNameGuess,'Value') == 1 && length(idx) > 1)
                        %proposal for subject name from folder
                        out{i,2} = out{i,1}(idx(end-1)+1:idx(end)-1);
                    elseif(get(this.visHandles.popupSubjectNameGuess,'Value') == 2 || length(idx) <= 1)
                        %proposal for subject name from file
                        [~, out{i,2}, ~] = fileparts(out{i,1});
                    else
                        %proposal for subject name from folder + file
                        folderN = out{i,1}(idx(end-1)+1:idx(end)-1);
                        [~,fileN,~] = fileparts(out{i,1});
                        out{i,2} = [folderN '_' fileN];
                    end
                end
            end
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName());
            for i = 1:size(out,1)
                %check if we have this name in the list already
                if(i > 1 && any(strcmp(out{i,2},out(1:i-1,2))))
                    out{i,2} = importFolderGUI.getNewSubjectName(out{i,2},out(1:i-1,2));
                end
                %set flags
                if(any(strcmp(out{i,2},subjects)))
                    out{i,3} = true;
                    out{i,4} = false;
                else
                    out{i,3} = false;
                    if(isempty(out{i,4}))
                        out{i,4} = true;
                    end
                end
            end
        end
        
        function openFolderByGUI(this)
            %open a new folder using a GUI
            path = uigetdir_workaround(this.FLIMXObj.importGUI.lastImportPath,'Select Folder to import measurement data');
            if(isempty(path) || all(~path(:)))
                return
            end
            this.checkVisWnd();
            this.openFolderByStr(path);
        end
        
        function openFolderByStr(this,path)
            %open path
            if(isempty(path) || ~ischar(path))
                return
            end
            set(this.visHandles.tableSubjects,'Data',[]);
            set(this.visHandles.editFolder,'String',path);
            this.currentFiles = rdir(sprintf('%s%s**%s*.sdt',path,filesep,filesep));
            %save path
            this.FLIMXObj.importGUI.lastImportPath = path;
            this.setupGUI();
        end
        
        %GUI callbacks
        function GUI_checkAllNone_Callback(this,hObject, eventdata)
            %select all or none of the subjects
            data = get(this.visHandles.tableSubjects,'Data');
            data(:,4) = num2cell(logical(ones(size(data,1),1).*get(hObject,'Value')));
            set(this.visHandles.tableSubjects,'Data',data);
        end
        
        function GUI_popupStudySel_Callback(this,hObject, eventdata)
            %user changed existing study
            this.setupGUI();
        end
        
        function GUI_popupSubjectNameGuess_Callback(this,hObject, eventdata)
            %user changed subject name proposal source
            set(this.visHandles.tableSubjects,'Data',[]);
            this.setupGUI();
        end
        
        function GUI_radioStudy_Callback(this,hObject, eventdata)
            %user changed study source
            this.setupGUI();
        end
        
        function GUI_editStudyName_Callback(this,hObject, eventdata)
            %user enters name for a new study
            newOrg = get(hObject,'String');
            i = 1;
            new = newOrg;
            while(any(strcmp(new,this.FLIMXObj.fdt.getStudyNames())))
                new = sprintf('%s%d',newOrg,i);
                i=i+1;
            end
            set(hObject,'String',new);
        end
        
        function GUI_editFolder_Callback(this,hObject, eventdata)
            %user entered new folder name
            this.openFolderByStr(get(this.visHandles.editFolder,'String',path));
        end
        
        function GUI_buttonBrowse_Callback(this,hObject, eventdata)
            %user clicked browse button
            this.openFolderByGUI();
        end
        
        function GUI_buttonOK_Callback(this,hObject, eventdata)
            %import selected files and close window
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> OK</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.plotProgressbar(0.001,[],'Preparing Import of Files...');
            mask = get(this.visHandles.tableSubjects,'Data');
            if(~isempty(mask))
                mask = mask([mask{:,4}],:);
                nSubjects = size(mask,1);
                tStart = clock;
                pMgr = this.FLIMXObj.paramMgr;
                oldPPP = pMgr.preProcessParams;
                newPPP = oldPPP;
                newPPP.roiAdaptiveBinEnable = 0;
                newPPP.roiBinning = 0;
                pMgr.setParamSection('pre_processing',newPPP,false);
                for i = 1:nSubjects
                    if(mask{i,4})                        
                        this.measurementObj = measurementReadRawData(pMgr);
                        this.measurementObj.setSourceFile(mask{i,1}); 
                        %read raw data
                        for ch = 1:this.measurementObj.nrSpectralChannels
                            this.measurementObj.getRawData(ch);
                        end
                        %get full roi
                        ROIVec = [1 this.measurementObj.getRawXSz() 1 this.measurementObj.getRawYSz()];
                        %ROIVec = importWizard.getAutoROI(this.measurementObj.getRawDataFlat(ch),this.measurementObj.roiStaticBinningFactor);
                        %if(ROIVec(1) > 5 || ROIVec(3) > 5 || ROIVec(2) < this.measurementObj.rawXSz-5 || ROIVec(4) < this.measurementObj.rawYSz-5)
                        this.measurementObj.setROICoord(ROIVec);
                        x = this.measurementObj.rawXSz;
                        if(x < 256)
                            x = 150;
                        end
                        this.measurementObj.pixelResolution = 1000*8.8/x;
                        %guess position of the eye
                        this.measurementObj.guessEyePosition();
                        subject = this.FLIMXObj.fdt.getSubject4Approx(this.currentStudy,mask{i,2},true);
                        subject.importMeasurementObj(this.measurementObj);
                    end
                    [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(nSubjects-i)); %mean cputime for finished runs * cycles left
                    this.plotProgressbar(i/nSubjects,[],...
                        sprintf('Progress: %d/%d (%02.1f%%) - Time left: %dh %dmin %.0fsec', i,nSubjects,100*i/nSubjects,hours,minutes,secs));
                end
                if(any([mask{:,4}]))
                    if(this.FLIMXObj.FLIMVisGUI.isOpenVisWnd())
                        this.FLIMXObj.FLIMVisGUI.checkVisWnd();
                    end
                    if(this.FLIMXObj.FLIMFitGUI.isOpenVisWnd())
                        this.FLIMXObj.FLIMFitGUI.checkVisWnd();
                    end
                    this.FLIMXObj.studyMgrGUI.checkVisWnd();
                end
            end
            pMgr.setParamSection('pre_processing',oldPPP,false);
            set(hObject,'String','OK');
            this.plotProgressbar(0,'','');
            this.closeCallback();
        end
        
        function GUI_tableSubjects_Callback(this,hObject, eventdata)
            %edit of subject name or change of import selection
            if(isempty(eventdata) || eventdata.Indices(1,2) ~= 2)% || eventdata.Indices(1,1) == 1)
                return
            end
            data = get(hObject,'Data');
            newName = importFolderGUI.getNewSubjectName(eventdata.NewData,data(setdiff(1:size(data,1),eventdata.Indices(1,1)),2));            
            %we got a unique name for the current list
            if(any(strcmp(newName,this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName()))))
                data{eventdata.Indices(1,1),3} = true;
                data{eventdata.Indices(1,1),4} = false;
            else
                data{eventdata.Indices(1,1),3} = false;
                data{eventdata.Indices(1,1),4} = true;
            end
            data{eventdata.Indices(1,1),2} = newName;
            set(hObject,'Data',data);
        end
        
        function plotProgressbar(this,x,varargin)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));
            if(~ishandle(this.visHandles.importFolderFigure))
                return;
            end
            xpatch = [0 x x 0];
            set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            if(nargin > 2)
                % update waitbar
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textProgress,'Position',[1,yl(2)/2,0],'String',varargin{2},'Parent',this.visHandles.axesProgress);
            end
            drawnow;
        end
        
        function GUI_buttonCancel_Callback(this,hObject, eventdata)
            %abort import
            this.closeCallback();
        end
        
        
        %dependent properties
        function out = get.currentStudy(this)
            %get name of current study
            out = '';
            if(~this.isOpenVisWnd())
                return
            end
            if(get(this.visHandles.radioExistingStudy,'Value'))
                str = get(this.visHandles.popupStudySel,'String');
                if(~isempty(str) && iscell(str))
                    out = str{get(this.visHandles.popupStudySel,'Value')};
                elseif(ischar(str))
                    out = str;
                end
            else
                out = get(this.visHandles.editStudyName,'String');
            end
        end
        
        function set.currentStudy(this,val)
            %set name of current study to new value
            if(~this.isOpenVisWnd() || ~ischar(val))
                return
            end
            idx = find(strcmp(get(this.visHandles.popupStudySel,'String'),val));
            if(~isempty(idx))
                %new study exists already in fdt
                set(this.visHandles.radioExistingStudy,'Value',1);
                set(this.visHandles.radioNewStudy,'Value',0);
                set(this.visHandles.popupStudySel,'Value',idx);
                GUI_popupStudySel_Callback(this,this.visHandles.popupStudySel, []);
            else
                %new study is now known yet
                set(this.visHandles.radioExistingStudy,'Value',1);
                set(this.visHandles.radioNewStudy,'Value',0);
                set(this.visHandles.editStudyName,'String',val);
                GUI_editStudyName_Callback(this,this.visHandles.editStudyName, []);
            end                
        end
    end %methods
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = importFolderFigure();
            set(this.visHandles.axesProgress,'XLim',[0 100],...
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
            %axes(this.visHandles.axesWait);
            this.visHandles.patchProgress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textProgress = text(1,0,'','Parent',this.visHandles.axesProgress);
            set(this.visHandles.importFolderFigure,'CloseRequestFcn',@this.GUI_buttonCancel_Callback);
            %set callbacks
            %checkboxes
            set(this.visHandles.checkAllNone,'Callback',@this.GUI_checkAllNone_Callback);
            %buttons
            set(this.visHandles.buttonBrowse,'Callback',@this.GUI_buttonBrowse_Callback);
            set(this.visHandles.buttonOK,'Callback',@this.GUI_buttonOK_Callback);
            set(this.visHandles.buttonCancel,'Callback',@this.GUI_buttonCancel_Callback);
            %popups
            set(this.visHandles.popupStudySel,'Callback',@this.GUI_popupStudySel_Callback);
            set(this.visHandles.popupSubjectNameGuess,'Callback',@this.GUI_popupSubjectNameGuess_Callback);
            %radio buttons
            set(this.visHandles.radioExistingStudy,'Callback',@this.GUI_radioStudy_Callback);
            set(this.visHandles.radioNewStudy,'Callback',@this.GUI_radioStudy_Callback);
            %edit fields
            set(this.visHandles.editFolder,'Callback',@this.GUI_editFolder_Callback);
            set(this.visHandles.editStudyName,'Callback',@this.GUI_editStudyName_Callback);
            %table
            set(this.visHandles.tableSubjects,'CellEditCallback',@this.GUI_tableSubjects_Callback);
            %set initial study
            studies = this.FLIMXObj.fdt.getStudyNames();
            curStudy = this.FLIMXObj.FLIMFitGUI.currentStudy;
            idx = find(strcmp(curStudy,studies));
            if(~isempty(studies))
                set(this.visHandles.editStudyName,'String',curStudy);
            end
            if(~isempty(idx))
                set(this.visHandles.popupStudySel,'String',studies,'Value',idx);
            end
            figure(this.visHandles.importFolderFigure);
        end
    end %methods(Access = protected)
    
    methods(Static)
        
        function subName = getNewSubjectName(subName,otherNames)
            %generate automated subject name, must not be in otherNames already
            subName = studyMgr.checkFolderName(subName);
            if(any(strcmp(subName,otherNames)))
                if(length(subName) >= 3 && strcmp(subName(end-2),'_') && all(isstrprop(subName(end-1:end), 'digit')))
                    
                else
                    subName = [subName '_01'];
                end
                iStart = str2double(subName(end-1:end));
                for i = iStart+1:99
                    if(any(strcmp(subName,otherNames)))
                        subName(end-1:end) = sprintf('%02.0f',i);
                    else
                        return;
                    end
                end
                subName = [subName '_01'];
            end
        end
        
    end %methods(Static)
end