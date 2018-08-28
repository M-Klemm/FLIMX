classdef FLIMXFitResultImport < handle
    %=============================================================================================================
    %
    % @file     FLIMXFitResultImport.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     September, 2017
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
    % @brief    A class for importingapproximation results from 3rd party software such as B&H SPCImage
    %
    
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];
        currentPath = '';
    end
    
    properties(GetAccess = protected, SetAccess = protected)
        visHandles = [];
        allFiles = cell(0,0);
        myFileTypes = {'.bmp', '.tif', '.tiff', '.png'};
        myFileGroups = {};
        myFileGroupsCounts = [];
        myResultStruct = [];
        myJTableHandle = [];
        myChannelNrs = [];
        myCurrentSubject = [];
        maxCh = 16;
        currentRow = 1;
        axesMgr = [];
        mouseOverlay = [];
        xRef = [];
        yRef = [];
    end
    
    properties (Dependent = true)
        cm = [];
        isOpenVisWnd = false;
        cmIntensity = [];
        currentStudyName = '';
        currentSubjectName = '';
        currentChannel = 1;
        currentSubject = [];
        currentItem = '';
        currentFileInfo = [];
        currentFileGroup = '';
        currentFileFilter = 1;
        numberOfAllImports = 0;
    end
    
    methods
        %% constructor
        function this = FLIMXFitResultImport(hFLIMX)
            this.FLIMXObj = hFLIMX;
            this.currentPath = cd;
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd)
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            %this.updateGUI();
            figure(this.visHandles.FLIMXFitResultImportFigure);
        end
        
        function closeVisWnd(this)
            %try to close windows if it still exists
            try
                close(this.visHandles.FLIMXFitResultImportFigure);
            end
            %delete old info
            this.allFiles = cell(0,0);
            this.myFileGroups = {};
            this.myFileGroupsCounts = [];
            this.myResultStruct = [];
            this.myJTableHandle = [];
            this.myChannelNrs = [];
            this.myCurrentSubject = []; %check if dirty?
            this.currentRow = 1;
        end %closeVisWnd
        
        function setSubject(this,study,subject)
            %set study and subject, does not update plots!
            if(isempty(study))
                study = this.FLIMXObj.studyMgrGUI.curStudyName;
                if(isempty(study))
                    study = 'Default';
                end
            end
            studies = this.FLIMXObj.fdt.getStudyNames();
            idx = find(strcmp(study,studies));
            if(~isempty(studies))
                set(this.visHandles.editStudyName,'String',study);
            end
            if(~isempty(idx))
                set(this.visHandles.popupStudySel,'String',studies,'Value',idx);
            end
            %set subject name
            if(isempty(subject))
                subNr = this.FLIMXObj.studyMgrGUI.selectedSubjects(1);
                subject = this.FLIMXObj.fdt.getSubjectName(study,subNr);
            end
            %try to find subject in study
            if(any(strcmp(subject,this.FLIMXObj.fdt.getSubjectsNames(study,FDTree.defaultConditionName()))))
                %this is not a new file
                set(this.visHandles.radioExistingSubject,'Value',1);
                subjects = this.FLIMXObj.fdt.getSubjectsNames(study,FDTree.defaultConditionName());
                idx = find(strcmp(subject,subjects));
                if(~isempty(idx))
                    set(this.visHandles.popupSubjectSel,'String',subjects,'Value',idx);
                end
            else
                %new subject?!
                %should switch to edit field and put subject name there
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
            %subject selection
            str = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudyName,FDTree.defaultConditionName());
            if(isempty(str))
                set(this.visHandles.radioExistingSubject,'Value',0,'Enable','off');
                set(this.visHandles.radioNewSubject,'Value',1);
                set(this.visHandles.popupSubjectSel,'String','-none-','Value',1,'Enable','off');
            else
                set(this.visHandles.popupSubjectSel,'String',str,'Value',min(length(str),get(this.visHandles.popupSubjectSel,'Value')));
                set(this.visHandles.radioExistingSubject,'Enable','on','Value',1);
                set(this.visHandles.radioNewSubject,'Value',0,'Enable','off');
            end
            if(get(this.visHandles.radioExistingSubject,'Value'))
                set(this.visHandles.popupSubjectSel,'Visible','on');
                set(this.visHandles.editSubjectName,'Visible','off');
                %set subject popup to current subject
                idx = find(strcmp(str,this.currentSubjectName));
                if(~isempty(idx))
                    set(this.visHandles.popupSubjectSel,'Value',idx);
                else
                    %we could not find the subject - this should not happen
                    %warn user?
                    set(this.visHandles.popupSubjectSel,'Value',1);
                end
            else
                set(this.visHandles.popupSubjectSel,'Visible','off');
                set(this.visHandles.editSubjectName,'Visible','on');
            end
%             this.visHandles.popupFileGroup.String = this.myFileGroups;
%             if(~isempty(this.myFileGroupsCounts))
%                 [~,lg] = max(this.myFileGroupsCounts);
%                 this.visHandles.popupFileGroup.Value = lg;
%             end
            if(length(this.myFileGroups) == 1)
                this.visHandles.textFileGroup.Enable = 'Off';
                this.visHandles.popupFileGroup.Enable = 'Off';
            else
                this.visHandles.textFileGroup.Enable = 'On';
                this.visHandles.popupFileGroup.Enable = 'On';
            end
            set(this.visHandles.popupChannel,'String',num2cell(this.myChannelNrs),'Value',max(1,min(this.maxCh,get(this.visHandles.popupChannel,'Value'))));
            set(this.visHandles.editPath,'String',this.currentPath,'Enable','on');
            fi = this.currentFileInfo;
            if(strcmp(fi.position,'OD'))
                this.visHandles.popupPosition.Value = 1;
            else
                this.visHandles.popupPosition.Value = 2;
            end
            this.visHandles.editResolution.String = fi.pixelResolution;
            if(fi.rawXSz > 0)
                this.visHandles.editImageSize.String = sprintf('%dx%d',fi.rawXSz,fi.rawYSz);
            else
                this.visHandles.editImageSize.String = 'no measurement file';
            end
            if(~isempty(this.allFiles))
                data = this.getTableData4Channel(this.currentChannel);
                data(:,6) = num2cell(this.checkImageSizes(this.currentChannel) & [data{:,6}]');
                this.setTableData4Channel(this.currentChannel,data);
            end
        end
        
        function updateGUI(this)
            %update GUI controls
            if(isMultipleCall())
                return
            end
            % selected channel in uitable
            data = this.getTableData4Channel(this.currentChannel);
            set(this.visHandles.tableFiles,'Data',data(:,1:6));
            if(isempty(this.currentRow))
                %clear table selection
                ed.Indices(1) = 0;
            else
                ed.Indices(1) = this.currentRow(1);
            end            
            ed.Indices(2) = 1;
            if(~isempty(this.myJTableHandle))
                this.myJTableHandle.changeSelection(ed.Indices(1)-1,0, false, false);
            else
                try
                    sp = findjobj(this.visHandles.tableFiles); %,'persist'
                    components = sp.getComponents;
                    viewport = components(1);
                    curComp = viewport.getComponents;
                    jtable = curComp(1);
                    % jtable.setRowSelectionAllowed(0);
                    % jtable.setColumnSelectionAllowed(0);
                    jtable.changeSelection(ed.Indices(1)-1,0, false, false);
                end
            end
            this.drawCurrentImage();
            this.updateImportCounter();
        end
        
        function updateImportCounter(this)
            %update the counter for the imported items            
            data = this.getTableData4Channel(this.currentChannel);
            if(~isempty(data) || size(data,1) >= this.currentRow || size(data,2) < 8)
                nCh = sum([data{:,6}]);
                nAll = this.numberOfAllImports;
            else
                nCh = 0;
                nAll = 0;
            end
            set(this.visHandles.editNumberImports,'String',sprintf('%d/%d in current channel',nCh, nAll));
        end
        
        function drawCurrentImage(this)
            % show selected image
            data = this.getTableData4Channel(this.currentChannel);
            if(~isempty(data) || size(data,1) >= this.currentRow || size(data,2) < 8)
                img = this.myResultStruct(this.currentChannel).results.pixel.(this.currentItem);
                %resize if neccessary
                if(~isempty(this.yRef) && ~isempty(this.xRef) && any([this.yRef,this.xRef] ~= size(img)))
                    img = imresize(img,[this.yRef,this.xRef]);
                end
                %do binning if neccessary
                img = FLIMXFitResultImport.binImage(img,data{this.currentRow,3});
                %flip up/down
                if(data{this.currentRow,4})
                    img = flipud(img);
                end
                if(islogical(img))
                    this.axesMgr.setMainData(img,0,1);
                else
                    this.axesMgr.setMainData(img);
                end
            else
                cla(this.visHandles.axesPreview);
            end
        end
        
        function out = getTableData4Channel(this,ch)
            %get data from our struct as a cell array
            if(isempty(this.allFiles))
                out = cell(0,7);
            else
                out = this.allFiles{ch};
            end
        end
        
        function setTableData4Channel(this,ch,data)
            %set cell data in our struct
            if(size(data,2) == 7)
                this.allFiles(ch) = {data};
            end
        end
        
        %% dependent properties
        function out = get.currentSubject(this)
            %get current selected subject
            if(~this.isOpenVisWnd)
                return
            end
            if(isempty(this.myCurrentSubject))
                this.myCurrentSubject = this.FLIMXObj.fdt.getSubject4Approx(this.currentStudyName,this.currentSubjectName);
            end
            out = this.myCurrentSubject;
        end
        
        function out = get.currentChannel(this)
            %get current selected channel
            if(~this.isOpenVisWnd)
                return
            end
            nr = max(1,this.visHandles.popupChannel.Value);
            str = this.visHandles.popupChannel.String;
            if(iscell(str))
                nr = min(nr,length(str));
            end
            if(iscell(str) && ~isempty(str))
                out = str2double(str{nr});
            elseif(ischar(str))
                %nothing to do
                out = str2double(str);
            else
                out = [];
            end
        end
        
        function out = get.currentItem(this)
            %get current selected item in table
            if(~this.isOpenVisWnd)
                return
            end
            data = this.visHandles.tableFiles.Data;
            if(~isempty(data))
                out = data{max(1,min(size(data,1),this.currentRow)),1};
            end
        end
        
        function out = get.cm(this)
            %get current color map
            out = this.FLIMXObj.FLIMVisGUI.dynParams.cm;
        end
        
        function out = get.isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXFitResultImportFigure) || ~strcmp(get(this.visHandles.FLIMXFitResultImportFigure,'Tag'),'FLIMXFitResultImportFigure'));
        end
        
        function out = get.cmIntensity(this)
            %get current intensity color map
            out = this.FLIMXObj.FLIMVisGUI.dynParams.cmIntensity;
        end
        
        function out = get.currentStudyName(this)
            %get name of current study
            out = '';
            if(this.isOpenVisWnd)
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
            else
                %we don't have a GUI yet, use FLIMXFitGUI
                out = this.FLIMXObj.FLIMFitGUI.currentStudyName;
            end
        end
        
        function out = get.currentSubjectName(this)
            %get name of current subject
            out = '';
            if(~this.isOpenVisWnd)
                return
            end
            if(get(this.visHandles.radioExistingSubject,'Value'))
                str = get(this.visHandles.popupSubjectSel,'String');
                if(~isempty(str) && iscell(str))
                    out = str{get(this.visHandles.popupSubjectSel,'Value')};
                elseif(ischar(str))
                    out = str;
                end
            else
                out = get(this.visHandles.editSubjectName,'String');
            end
        end
        
        function out = get.currentFileInfo(this)
            %get current file info struct; if we have a measurement, take it from there, otherwise use default
            measurementChs = this.FLIMXObj.fdt.getSubjectFilesStatus(this.currentStudyName,this.currentSubjectName);
            if(~isempty(measurementChs))
                subject = this.currentSubject;
                if(isempty(subject))
                    %should not happen
                    out = measurementFile.getDefaultFileInfo();
                else
                    out = subject.getFileInfoStruct(measurementChs(1));
                end
            else
                out = measurementFile.getDefaultFileInfo();
            end
        end
        
        function out = get.currentFileGroup(this)
            %get currently selected file group
            if(isempty(this.myFileGroups))
                [this.myFileGroups, this.myFileGroupsCounts] = result4Import.detectFileGroups(this.currentPath,this.myFileTypes);
            end
            str = this.myFileGroups;
            nr = min(this.visHandles.popupFileGroup.Value,size(str,1));
            if(~isempty(str) && iscell(str))
                out = str{nr};
            elseif(ischar(str))
                %nothing to do
                out = str;
            else
                out = '';
            end
        end
        
        function out = get.currentFileFilter(this)
            %get currently selected file filter
            out = this.visHandles.popupFilter.Value;
        end
        
        function out = get.numberOfAllImports(this)
            %return the total number of imported items
            out = 0;
            for chId = 1:length(this.myChannelNrs)
                data = this.getTableData4Channel(this.myChannelNrs(chId));
                if(~isempty(data) && size(data,2) >= 6)
                    out = out + sum([data{:,6}]);
                end
            end
        end
        
        function set.currentChannel(this,val)
            if(~this.isOpenVisWnd)% || ~ischar(val))
                return
            end
            idx = find(val == this.myChannelNrs,1);
            if(isempty(val))
                idx = 1;
            end
            set(this.visHandles.popupChannel,'Value',idx);
            this.currentRow = 1;
            this.updateGUI();
        end
        
        %% Ask User
        function openFolderByGUI(this,studyName,subjectName)
            %open a new folder using a GUI
            this.checkVisWnd(); %make sure GUI is open
            path = uigetdir(this.currentPath,sprintf('Select folder to import results for ''%s'' in study ''%s''',subjectName,studyName));
            if(isempty(path) || isequal(path,0))
                this.closeVisWnd();
                return
            end
            this.setSubject(studyName,subjectName);
            this.openFolderByStr(path);
        end
        
        function openFolderByStr(this,path)
            %open a new folder
            %clear old data
            this.allFiles = cell(0,0);
            this.myFileGroups = cell(0,0);
            this.myFileGroupsCounts = [];
            this.currentRow = 1;
            this.myChannelNrs = [];
            this.myCurrentSubject = [];
            this.maxCh = 16;
            this.myResultStruct = [];
            this.xRef = [];
            this.yRef = [];
            %save path
            this.currentPath = path;
            %read info from disk
            [this.myFileGroups, this.myFileGroupsCounts] = result4Import.detectFileGroups(this.currentPath,this.myFileTypes);
            %setup fileGroup popup
            this.visHandles.popupFileGroup.String = this.myFileGroups;
            if(~isempty(this.myFileGroupsCounts))
                [~,lg] = max(this.myFileGroupsCounts);
                this.visHandles.popupFileGroup.Value = lg;
            end
            this.switchFileGroup(this.currentFileGroup);
        end
        
        function switchFileGroup(this,fileGroup)
            %load data of a certain filegroup
            this.visHandles.buttonImport.Enable = 'Off';
            drawnow
            this.currentRow = 1;
            %this.currentChannel = 1;
            rs = result4Import.ASCIIFilesInGroup2ResultStruct(this.currentPath,this.myFileTypes,fileGroup,this.currentSubjectName,@this.plotProgressbar);
            rsChNrs = length(rs);
            [~, existingChs] = this.FLIMXObj.fdt.getSubjectFilesStatus(this.currentStudyName,this.currentSubjectName);
            choice = '';
            chs = intersect(existingChs,1:rsChNrs);
            if(any(chs))
                %some or all channels exist already in current subject
                choice = questdlg(sprintf('Channels ''%s'' already have results in subject ''%s''!',num2str(chs),this.currentSubjectName),...
                    'FLIMX Result Import: Existing Result Channel(s)','Keep existing results and add new items','Delete all existing results and import new channel(s)','Abort','Keep existing results and add new items');
            end
            switch choice
                case 'Abort'
                    %skip
                    this.visHandles.buttonImport.Enable = 'On';
                    this.closeVisWnd();
                    return
                case 'Keep existing results and add new items'                    
                case 'Delete all existing results and import new channel(s)'
                    %clear old result data and add new channel(s)
                    this.FLIMXObj.fdt.removeSubjectResult(this.currentStudyName,this.currentSubjectName);
                    %this.FLIMXObj.fdt.clearSubjectFiles(this.currentStudyName,this.currentSubjectName);
                otherwise                    
            end            
            %check if there are too many channels            
            maxChNr = this.FLIMXObj.irfMgr.getSpectralChNrs([],'',[]);
            if(rsChNrs > maxChNr)
                removeChs = maxChNr+1 : rsChNrs;
                %remove the channels
                rs = rs(1:maxChNr);
                %display it to to user
                warndlg(sprintf('Detected the following channel numbers: %s\nMaximum number of known IRF channels is %d.\nChannel(s) %s have been removed from this import. To import those channels add the corresponding IRF channels using the IRF manager.',num2str(rsChNrs),maxChNr,num2str(removeChs)),'FLIMX Result Import: Too Many Channels');
            end
            this.myResultStruct = rs;
            if(rsChNrs > 0 && ~isempty(this.myResultStruct) && isfield(this.myResultStruct,'channel'))
                this.myChannelNrs = [this.myResultStruct.channel];
                this.maxCh = max(this.myChannelNrs(:));
            else
                set(this.visHandles.editPath,'String',this.currentPath);
                warndlg('No result files found!','FLIMX Result Import: No Files Found');
                this.visHandles.buttonImport.Enable = 'On';
                return
            end
            for chId = 1:length(this.myChannelNrs)
                fn = fieldnames(rs(this.myChannelNrs(chId)).results.pixel);
                af = cell(length(fn),7);
                for i = 1:length(fn)
                    [sy, sx, sz] = size(rs(this.myChannelNrs(chId)).results.pixel.(fn{i}));
                    af(i,1) = {fn{i}};
                    af(i,2) = {sprintf('%dx%d',sx,sy)}; %size
                    af(i,3) = {0}; %binning
                    af(i,4) = {false}; %flip up/down flag
                    af(i,5) = {false}; %exist flag
                    af(i,6) = {true}; %import flag
                    af(i,7) = {[sy, sx, sz]};
                end
                this.allFiles(this.myChannelNrs(chId)) = {af};
                if(chId == 1)
                    [this.xRef,this.yRef] = this.getRefImageSize();
                end
                existing = this.checkExistingFLIMItems(this.myChannelNrs(chId));
                sizeFit = this.checkImageSizes(this.myChannelNrs(chId));
                af(:,5) = num2cell(existing);
                af(:,6) = num2cell(~existing & sizeFit);
                this.allFiles(this.myChannelNrs(chId)) = {af};
            end
            this.visHandles.buttonImport.Enable = 'On';
            this.setupGUI();
            this.updateGUI();
        end
        
        function out = checkImageSizes(this,ch)
            %check if to be imported results fit to the measurement resolution or to amplitude 1
            out = true;
            if(isempty(this.allFiles) || isempty(this.xRef) || isempty(this.yRef))
                return
            end
            af = this.allFiles{ch};
            sz = vertcat(af{:,7});
            out = sz(:,2) == this.xRef & sz(:,1) == this.yRef;
        end
        
        function out = checkExistingFLIMItems(this,ch)
            %check if subject already has results
            af = this.allFiles{ch};
            out = false(size(af,1),1);
            subject = this.currentSubject;
            if(isempty(subject))
                return
            end
            if(subject.isPixelResult(ch,[],[],false))
                existingFLIMItems = subject.getResultNames(ch,false);
                for i = 1:length(out)
                    out(i) = any(strcmp(af{i,1},existingFLIMItems));
                end
            end
        end
        
        function [xRef,yRef] = getRefImageSize(this)
            %return the size of the subject's intensity image or of amplitude 1
            xRef = []; yRef = [];
            fi = this.currentFileInfo;            
            if(fi.rawXSz == 0)
                %look in valid channel for reference
                afRef = this.allFiles{this.myChannelNrs(1)};
                idx = find(strcmp(afRef(:,1),'Amplitude1'), 1);
                if(isempty(idx))
                    %no reference, nothing to do
                    return
                end
                sz = vertcat(afRef{:,7});
                xRef = sz(idx,2);
                yRef = sz(idx,1);
            else
                xRef = fi.rawXSz;
                yRef = fi.rawYSz;
            end            
        end
            
        function flag = checkSubjectID(this, Ch)
            %check if channel ch of subject is already in tree
            [~, resultChs] = this.FLIMXObj.fdt.getSubjectFilesStatus(this.FLIMXObj.curSubject.myParent.name,this.FLIMXObj.curSubject.name);
            
            flag = any(resultChs == Ch);
        end
        
        function matchingImportsInitialize(this, channel)
            %make sure corresponding amplitudes and taus are checked / unchecked for import
            data = this.getTableData4Channel(channel);
            names = data(:,1);
            %todo: make for n Taus/Amps
            pos_t1 = strcmp(names,'Tau1');
            pos_a1 = strcmp(names,'Amplitude1');
            pos_t2 = strcmp(names,'Tau2');
            pos_a2 = strcmp(names,'Amplitude2');
            pos_t3 = strcmp(names,'Tau3');
            pos_a3 = strcmp(names,'Amplitude3');
            if(~any(pos_a1) && any(pos_t1))
                tmp = [data{:,5}];
                tmp(pos_t1) = false;
                data(:,5) = num2cell(tmp);
            end
            if(~any(pos_t1) && any(pos_a1))
                tmp = [data{:,5}];
                tmp(pos_a1) = false;
                data(:,5) = num2cell(tmp);
            end
            if(~any(pos_a2) && any(pos_t2))
                tmp = [data{:,5}];
                tmp(pos_t2) = false;
                data(:,5) = num2cell(tmp);
            end
            if(~any(pos_t2) && any(pos_a2))
                tmp = [data{:,5}];
                tmp(pos_a2) = false;
                data(:,5) = num2cell(tmp);
            end
            if(~any(pos_a3) && any(pos_t3))
                tmp = [data{:,5}];
                tmp(pos_t3) = false;
                data(:,5) = num2cell(tmp);
            end
            if(~any(pos_t3) && any(pos_a3))
                tmp = [data{:,5}];
                tmp(pos_a3) = false;
                data(:,5) = num2cell(tmp);
            end
            this.setTableData4Channel(channel,data);
        end
        
        function plotProgressbar(this,x,text)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));
            %             if(~ishandle(this.visHandles.studyMgrFigure))
            %                 return;
            %             end
            xpatch = [0 x x 0];
            set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            if(nargin>0)
                % update waitbar
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textProgress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesProgress);
            end
            drawnow;
        end
        
    end
    
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            % make a window for visualization of current fit
            this.visHandles = FLIMXFitResultImportFigure();
            figure(this.visHandles.FLIMXFitResultImportFigure);
            %set callbacks
            % popup
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback,'TooltipString','Select channel');
            set(this.visHandles.popupFileGroup,'Callback',@this.GUI_popupFileGroup_Callback,'TooltipString','Select file stub. You will loose your current choice of FLIM items!');
            set(this.visHandles.popupFilter,'Enable','off','Callback',@this.GUI_popupFilter_Callback,'TooltipString','Select file stub. You will loose your current choice of FLIM items!');
            set(this.visHandles.popupStudySel,'Callback',@this.GUI_popupStudySel_Callback);
            set(this.visHandles.popupSubjectSel,'Callback',@this.GUI_popupSubjectSel_Callback);
            % table
            set(this.visHandles.tableFiles,'CellSelectionCallback',@this.GUI_tableFiles_CellSelectionCallback);
            set(this.visHandles.tableFiles,'CellEditCallback',@this.GUI_tableFiles_CellEditCallback);
            % axes
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
            this.visHandles.patchProgress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textProgress = text(1,0,'','Parent',this.visHandles.axesProgress);
            % radiobutton
            set(this.visHandles.radioExistingStudy,'Callback',@this.GUI_radioStudy_Callback);
            set(this.visHandles.radioNewStudy,'Callback',@this.GUI_radioStudy_Callback,'enable','off');
            set(this.visHandles.radioExistingSubject,'Callback',@this.GUI_radioSubject_Callback);
            set(this.visHandles.radioNewSubject,'Callback',@this.GUI_radioSubject_Callback,'enable','off');
            % push button
            set(this.visHandles.buttonBrowse,'Callback',@this.GUI_buttonBrowse_Callback,'TooltipString','Browse PC for the folder, which contains the import files');
            set(this.visHandles.buttonImport,'Callback',@this.GUI_buttonImport_Callback,'TooltipString','If you are ready, click here to import all selected files from all channels for the selected file stub');
            set(this.visHandles.buttonCancel,'Callback',@this.GUI_buttonCancel_Callback,'TooltipString','Click here for cancel importing result files');
            % checkbox
            set(this.visHandles.checkSelectAll,'Callback',@this.GUI_checkSelectAll_Callback,'TooltipString','Select all files for import in the current channel');
            set(this.visHandles.checkSelectNone,'Callback',@this.GUI_checkSelectNone_Callback,'TooltipString','Deselect all files for import in the current channel');            
            % edit fields
            set(this.visHandles.editPath,'Callback',@this.GUI_editPath_Callback,'TooltipString','Current import folder');
            % mouse
            set(this.visHandles.FLIMXFitResultImportFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            this.axesMgr = axesWithROI(this.visHandles.axesPreview,this.visHandles.axesCb,this.visHandles.textCbBottom,this.visHandles.textCbTop,[],this.cm);
            this.axesMgr.setColorMapPercentiles(this.FLIMXObj.paramMgr.generalParams.cmPercentileLB,this.FLIMXObj.paramMgr.generalParams.cmPercentileUB);
            this.axesMgr.setReverseYDirFlag(this.FLIMXObj.paramMgr.generalParams.reverseYDir);
            this.mouseOverlay = mouseOverlayBox(this.visHandles.axesPreview);
            % find jave table handle
            try
                sp = findjobj(this.visHandles.tableFiles); %,'persist'
                components = sp.getComponents;
                viewport = components(1);
                curComp = viewport.getComponents;
                this.myJTableHandle = curComp(1);
            end
            this.setupGUI();
        end
        
        %% GUI Callbacks
        % Tables
        function GUI_tableFiles_CellSelectionCallback(this,hObject, eventdata)
            if (isempty(eventdata.Indices))
                return
            else
                row = eventdata.Indices(1);
            end
            this.currentRow = row;
            this.drawCurrentImage();
        end
        
        function GUI_tableFiles_CellEditCallback(this,hObject, eventdata)
            % which file is selected
            if (isempty(eventdata.Indices))
                row = 1;
            else
                row = eventdata.Indices(1);
            end
            this.currentRow = row;
            % update GUI
            dataNew = eventdata.Source.Data;
            dataOld = this.getTableData4Channel(this.currentChannel);
            di = find(~[dataOld{:,5}] & [dataOld{:,6}] - [dataNew{:,6}],1);
            if(~isempty(di))
                %check if change is an amplitude or a tau
                newVal = dataNew{di,6};
                str = dataOld{di,1};
                if(sum(isstrprop(str,'alpha')) == 9 && strncmp(str,'Amplitude',9))
                    otherParam = 'Tau';
                elseif(sum(isstrprop(str,'alpha')) == 3 && strncmp(str,'Tau',3))
                    otherParam = 'Amplitude';
                else
                    otherParam = '';
                end
                if(~isempty(otherParam))
                    %find amplitude/tau number
                    nrThis = str2double(str(isstrprop(str,'digit')));
                    if(~isempty(nrThis) && nrThis == 1 && ~newVal)
                        %prohibit deselection of amp1/tau1
                        dataNew{di,6} = true;
                    elseif(~isempty(nrThis) && nrThis > 1)
                        %find corresponding otherParam
                        ids = find(strncmp(dataOld(:,1),otherParam,length(otherParam)));
                        hit = false;
                        for i = 1:length(ids)
                            str = dataOld{ids(i),1};
                            %check that there is the correnct number of letter
                            if(sum(isstrprop(str,'alpha')) ~= length(otherParam))
                                continue
                            end
                            nrT = str2double(str(isstrprop(str,'digit')));
                            if(nrThis == nrT)
                                dataNew{ids(i),6} = newVal;
                                hit = true;
                                break
                            end
                        end
                        if(~hit && newVal)
                            %user selected an amp/tau but its corresponding tau/amp is missing -> revert that click
                            dataNew{di,6} = false;
                        end
                    end
                end
                %check if an item was enabled for import, which size doesn't match the reference
                if(newVal)
                    resList = find(~this.checkImageSizes(this.currentChannel));
                    if(any(resList == di))
                        uiwait(warndlg(sprintf('Image size of ''%s'' is different from the reference (x:%d y:%d).\n\nThe image will be rescaled to match the reference!',dataOld{di},this.xRef,this.yRef),...
                            'FLIMX Result Import: Size Mismatch'));
                    end
                end
            else
                dataNew(:,6) = dataOld(:,6);
            end
            dataOld(:,1:6) = dataNew;
            this.setTableData4Channel(this.currentChannel,dataOld);
            % select/deselect matching files
            if(isequal(5,eventdata.Indices(2)))
                this.matchingImportsInitialize(this.currentChannel);
            end
            this.drawCurrentImage();
            this.updateImportCounter();
        end
        
        % edit
        function GUI_editPath_Callback(this,hObject,eventdata)
            %enter path manually
            path = get(this.visHandles.editPath,'String');
            if(isempty(path))
                this.openFolderByGUI(this.currentStudyName,this.currentSubjectName);
            else
                this.openFolderByStr(path);
            end
        end
                
        % Popup
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            this.currentRow = min(this.currentRow,size(this.allFiles{this.currentChannel},1));
            this.updateGUI();
        end
        
        function GUI_popupFileGroup_Callback(this,hObject, eventdata)
            %change current file group
            this.currentRow = 1;
            this.currentChannel = 1;
            this.switchFileGroup(this.currentFileGroup);
%             this.setupGUI();
%             this.updateGUI();
        end
        
        function GUI_popupFilter_Callback(this,hObject, eventdata)
            %change file selection filter
            
        end
        
        function GUI_popupStudySel_Callback(this,hObject, eventdata)
            %change study
            this.setupGUI();
        end
        
        function GUI_popupSubjectSel_Callback(this,hObject, eventdata)
            %change subject
            this.setupGUI();
        end
        
        % Pushbutton
        function GUI_buttonBrowse_Callback(this,hObject, eventdata)
            %browse for a new folder
            this.openFolderByGUI(this.currentStudyName,this.currentSubjectName);
        end
        
        function GUI_buttonCancel_Callback(this,hObject, eventdata)
            this.closeVisWnd();
        end
        
        function GUI_buttonImport_Callback(this,hObject, eventdata)
            %import selected results to subject
            %check if something is selected
            if(this.numberOfAllImports == 0)
                choice = questdlg('No items are selected for import. Select items or close the FLIMX Result Import Wizard?','FLIMX Result Import: Nothing selected','Select Items','Close','Select Items');
                switch choice
                    case 'Select Items'
                        return
                    case 'Close'
                        this.closeVisWnd();
                        return
                end
            end
            %confirm that user wants to import
            choice = questdlg(sprintf('Do you want to import all selected items into subject\n\n''%s''\n\nin study\n\n''%s''?', this.currentSubjectName,this.currentStudyName),'FLIMX Result Import: Confirmation','Yes','No','No');
            switch choice
                case 'No'
                    this.closeVisWnd();
                    return
            end
            %% do actual import
            is = this.FLIMXObj.fdt.getSubject4Import(this.currentStudyName,this.currentSubjectName);
            %update position and scaling if needed
            pos = this.visHandles.popupPosition.String{this.visHandles.popupPosition.Value};
            res = str2double(this.visHandles.editResolution.String);
            if(~strcmp(is.myMeasurement.position,pos))
                is.myMeasurement.position = pos;
            end
            if(is.myMeasurement.pixelResolution - res > eps)
                is.myMeasurement.pixelResolution = res;
            end
            %import channels
            for chId = 1:length(this.myChannelNrs)
                rs = this.myResultStruct(this.myChannelNrs(chId));
                data = this.getTableData4Channel(this.myChannelNrs(chId));
                idx = [data{:,6}];
                names = data(idx,1);
                fn = fieldnames(rs.results.pixel);
                names = setdiff(fn,names);
                rs.results.pixel = rmfield(rs.results.pixel,names);
                fn = fieldnames(rs.results.pixel);
                if(~isempty(fieldnames(rs.results.pixel)))
                    binIds = find([data{idx,3}]);
                    flipIds = find([data{idx,4}]);
                    for i = 1:length(fn)
                        %resize
                        if(~isempty(this.yRef) && ~isempty(this.xRef) && any([this.yRef,this.xRef] ~= size(rs.results.pixel.(fn{i}))))
                            rs.results.pixel.(fn{i}) = imresize(rs.results.pixel.(fn{i}),[this.yRef,this.xRef]);
                        end
                        %do binning
                        if(any(binIds == i))
                            rs.results.pixel.(fn{i}) = FLIMXFitResultImport.binImage(rs.results.pixel.(fn{i}),data{i,3});
                        end
                        %flip up/down
                        if(any(flipIds == i))
                            rs.results.pixel.(fn{i}) = flipud(rs.results.pixel.(fn{i}));
                        end
                    end
                    if(any([data{:,5}])) 
                        %we have existing results
                        is.addFLIMItems(this.myChannelNrs(chId),rs.results.pixel);
                    else
                        %the subject does not have any results
                        is.importResultStruct(rs,this.myChannelNrs(chId),pos,res);
                    end
                end
            end
%             this.FLIMXObj.studyMgrGUI.updateGUI();
            this.closeVisWnd();            
        end
        
        % checkbox
        function GUI_checkSelectAll_Callback(this,hObject, eventdata)
            % switch checkbox and select all/deselect all
            data = this.getTableData4Channel(this.currentChannel);
            set(hObject,'Value',1)
            data(:,6) = num2cell(true(size(data,1),1));
            this.setTableData4Channel(this.currentChannel,data);
            this.updateGUI();
        end
        
        function GUI_checkSelectNone_Callback(this,hObject, eventdata)
            % switch checkbox and select all/deselect all
            data = this.getTableData4Channel(this.currentChannel);
            set(hObject,'Value',0)
            data(:,6) = num2cell(false(size(data,1),1));
            this.setTableData4Channel(this.currentChannel,data);
            this.updateGUI();
        end
                
        %radio button
        function GUI_radioStudy_Callback(this,hObject, eventdata)
            %user changed study source
            this.setupGUI();
        end
        
        function GUI_radioSubject_Callback(this,hObject, eventdata)
            %user changed subject name source
            this.setupGUI();
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %mouse callbacks
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function GUI_mouseMotion_Callback(this, hObject, eventdata)
            %executes on mouse move in window
            cp = get(this.visHandles.axesPreview,'CurrentPoint');
            cp = round(cp(logical([1 1 0; 0 0 0])));
            ci = this.axesMgr.getMyData();
            if(cp(1) < this.visHandles.axesPreview.XLim(1) || cp(1) > this.visHandles.axesPreview.XLim(2) || cp(2) < this.visHandles.axesPreview.YLim(1) || cp(2) > this.visHandles.axesPreview.YLim(2) || isempty(ci))
                %we are outside axes - nothing to do
                this.mouseOverlay.clear();
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','arrow');
            else
                %inside axes
                set(this.visHandles.FLIMXFitResultImportFigure,'Pointer','cross');
                this.mouseOverlay.draw(cp,[{sprintf('x:%d y:%d',cp(1),cp(2))},FLIMXFitGUI.num4disp(ci(cp(2),cp(1)))]);
            end
        end
    end
    
    methods(Static)
        
        function img = binImage(img,binFactor)
            %perform binning on image using bin factor
            binFactor = round(binFactor);
            if(binFactor < 1)
                return
            end
            img = imdilate(img,true(2*binFactor+1));
        end
    end
end

