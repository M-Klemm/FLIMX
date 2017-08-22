classdef studyMgr < handle
    %=============================================================================================================
    %
    % @file     studyMgr.m
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
    % @brief    A class to represent the study manager GUI, used to organize studies
    %
    properties
        
    end
    properties(GetAccess = public, SetAccess = private)
        myDir = []; %study manager working directory
        visHandles = []; %structure to handles in GUI
        myClipboard = []; %Clipboard to copy/insert Subjects between studies
        lastAddedSubject = ''; %name last added subject
        stop = false;
        FLIMXObj = []; %handle to FLIMVis
        lastStudyPath = '';
        lastImportPath = '';
        selectedSubjects = [];
        selectedInfoField = [];
    end
    properties (Dependent = true)
        fdt = [];
        visObj = [];
        curStudyNr = [];
        curStudyName = [];
        allStudiesStr = [];
    end
    
    methods
        function this = studyMgr(flimX,myDir)
            %constructor for studyMgr
            this.myDir = myDir;
            if(~isdir(myDir))
                [status, message, ~] = mkdir(myDir);
                if(~status)
                    error('FLIMX:studyMgr','Could not create study manager working directory %s.\n%s',myDir,message);
                end
            end
            this.FLIMXObj = flimX;
            this.lastStudyPath = flimX.getWorkingDir();
            this.lastImportPath = flimX.getWorkingDir();
            this.myClipboard = cell(0,0);
        end
        
        %% computations and other methods
        function createVisWnd(this)
            %make a new window for study management
            this.visHandles = studyMgrFigure();
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
            set(this.visHandles.studyMgrFigure,'CloseRequestFcn',@this.menuExit_Callback);
            set(this.visHandles.menuExit,'Callback',@this.menuExit_Callback);
            %menus & buttons
            %study
            set(this.visHandles.menuNewStudy,'Callback',@this.menuNewStudy_Callback);
            set(this.visHandles.buttonNewStudy,'Callback',@this.menuNewStudy_Callback);
            set(this.visHandles.menuSaveStudy,'Callback',@this.menuSaveStudy_Callback);
            set(this.visHandles.buttonSaveStudy,'Callback',@this.menuSaveStudy_Callback);
            set(this.visHandles.menuDeleteStudy,'Callback',@this.menuDeleteStudy_Callback);
            set(this.visHandles.buttonDeleteStudy,'Callback',@this.menuDeleteStudy_Callback);
            set(this.visHandles.menuDuplicateStudy,'Callback',@this.menuDuplicateStudy_Callback);
            set(this.visHandles.buttonDuplicateStudy,'Callback',@this.menuDuplicateStudy_Callback);
            set(this.visHandles.menuExportStudy,'Callback',@this.menuExportStudy_Callback);
            set(this.visHandles.menuImportStudy,'Callback',@this.menuImportStudy_Callback);
            set(this.visHandles.menuRenameStudy,'Callback',@this.menuRenameStudy_Callback);
            set(this.visHandles.buttonRenameStudy,'Callback',@this.menuRenameStudy_Callback);
            set(this.visHandles.menuChangeStudyFileInfo,'Callback',@this.menuChangeStudyFileInfo_Callback);
            %subjects
            set(this.visHandles.menuNewSubject,'Callback',@this.menuNewSubject_Callback);
            set(this.visHandles.menuDeleteSubject,'Callback',@this.menuDeleteSubject_Callback);
            set(this.visHandles.menuImportSubjectsExcel,'Callback',@this.menuImportExcel_Callback);
            set(this.visHandles.menuExportSubjectsExcel,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuCopySubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.menuCutSubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.menuPasteSubject,'Callback',@this.menuPasteSubject_Callback);
            set(this.visHandles.menuDuplicateSubject,'Callback',@this.menuDuplicateSubject_Callback);
            set(this.visHandles.menuRenameSubject,'Callback',@this.menuRenameSubject_Callback);
            set(this.visHandles.menuChangeSubjectFileInfo,'Callback',@this.menuChangeSubjectFileInfo_Callback);
            set(this.visHandles.menuDeleteSubjectResult,'Callback',@this.menuDeleteSubjectResult_Callback);
            set(this.visHandles.menuCopyROI2Study,'Callback',@this.menuCopyROI2Study_Callback);
            set(this.visHandles.buttonNewSubject,'Callback',@this.menuNewSubject_Callback);
            set(this.visHandles.buttonDeleteSubject,'Callback',@this.menuDeleteSubject_Callback);
            set(this.visHandles.buttonCopySubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.buttonCutSubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.buttonPasteSubject,'Callback',@this.menuPasteSubject_Callback);
            set(this.visHandles.buttonDuplicateSubject,'Callback',@this.menuDuplicateSubject_Callback);
            set(this.visHandles.buttonRenameSubject,'Callback',@this.menuRenameSubject_Callback);
            set(this.visHandles.buttonChangeSubjectFileInfo,'Callback',@this.menuChangeSubjectFileInfo_Callback);
            set(this.visHandles.buttonDeleteSubjectResult,'Callback',@this.menuDeleteSubjectResult_Callback);
            set(this.visHandles.buttonCopyROI2Study,'Callback',@this.menuCopyROI2Study_Callback);
            %subject info column management
            set(this.visHandles.menuNewColumn,'Callback',@this.contextNewColumn_Callback);
            set(this.visHandles.buttonNewColumn,'Callback',@this.contextNewColumn_Callback);
            set(this.visHandles.menuEditColumn,'Callback',@this.contextEditColumn_Callback);
            set(this.visHandles.buttonEditColumn,'Callback',@this.contextEditColumn_Callback);
            set(this.visHandles.menuDeleteColumn,'Callback',@this.contextDelColumn_Callback);
            set(this.visHandles.buttonDeleteColumn,'Callback',@this.contextDelColumn_Callback);
            set(this.visHandles.menuMoveColLeft,'Callback',@this.contextMoveColL_Callback);
            set(this.visHandles.buttonMoveColLeft,'Callback',@this.contextMoveColL_Callback);
            set(this.visHandles.menuMoveColRight,'Callback',@this.contextMoveColR_Callback);
            set(this.visHandles.buttonMoveColRight,'Callback',@this.contextMoveColR_Callback);
            set(this.visHandles.menuMoveColBegin,'Callback',@this.contextMoveColBegin_Callback);
            set(this.visHandles.buttonMoveColBegin,'Callback',@this.contextMoveColBegin_Callback);
            set(this.visHandles.menuMoveColEnd,'Callback',@this.contextMoveColEnd_Callback);
            set(this.visHandles.buttonMoveColEnd,'Callback',@this.contextMoveColEnd_Callback);
            %contect menus subjects
            set(this.visHandles.contextNewSubject,'Callback',@this.menuNewSubject_Callback);
            set(this.visHandles.contextDeleteSubject,'Callback',@this.menuDeleteSubject_Callback);
            set(this.visHandles.contextCopySubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.contextCutSubject,'Callback',@this.menuCopySubject_Callback);
            set(this.visHandles.contextPasteSubject,'Callback',@this.menuPasteSubject_Callback);
            set(this.visHandles.contextDuplicateSubject,'Callback',@this.menuDuplicateSubject_Callback);
            set(this.visHandles.contextRenameSubject,'Callback',@this.menuRenameSubject_Callback);
            set(this.visHandles.contextChangeSubjectFileInfo,'Callback',@this.menuChangeSubjectFileInfo_Callback);
            set(this.visHandles.contextDeleteSubjectResult,'Callback',@this.menuDeleteSubjectResult_Callback);
            set(this.visHandles.contextCopyROI2Study,'Callback',@this.menuCopyROI2Study_Callback);
            %other
            set(this.visHandles.menuImportResultSel,'Callback',@this.menuImportResultSelSub_Callback);
            set(this.visHandles.menuImportResultAll,'Callback',@this.menuImportResultAll_Callback);
            set(this.visHandles.menuImportMeasurementSingle,'Callback',@this.menuImportMeasurementSingle_Callback);
            set(this.visHandles.menuImportMeasurementFolder,'Callback',@this.menuImportMeasurementFolder_Callback);
            set(this.visHandles.buttonOK,'Callback',@this.GUI_buttonOK_Callback);
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback);
            %context menus subject info
            set(this.visHandles.contextNewColumn,'Callback',@this.contextNewColumn_Callback);
            set(this.visHandles.contextEditColumn,'Callback',@this.contextEditColumn_Callback);
            set(this.visHandles.contextMoveColL,'Callback',@this.contextMoveColL_Callback);
            set(this.visHandles.contextMoveColR,'Callback',@this.contextMoveColR_Callback);
            set(this.visHandles.contextMoveColBegin,'Callback',@this.contextMoveColBegin_Callback);
            set(this.visHandles.contextMoveColEnd,'Callback',@this.contextMoveColEnd_Callback);
            set(this.visHandles.contextDelColumn,'Callback',@this.contextDelColumn_Callback);
            %popups
            set(this.visHandles.popupStudySelection,'Callback',@this.GUI_studySelPop_Callback);
            set(this.visHandles.popupSubjectSelection,'Callback',@this.GUI_subjectSelPop_Callback);
            set(this.visHandles.popupColumnSelection,'Callback',@this.GUI_columnSelPop_Callback);
            %tables
            set(this.visHandles.tableFileData,'CellSelectionCallback',@this.GUI_tableFileDataSel_Callback);
            set(this.visHandles.tableStudyData,'CellEditCallback',@this.GUI_tableStudyDataEdit_Callback);
            set(this.visHandles.tableStudyData,'CellSelectionCallback',@this.GUI_tableStudyDataSel_Callback);
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.studyMgrFigure) || ~strcmp(get(this.visHandles.studyMgrFigure,'Tag'),'studyMgrFigure'));
        end
        
        function checkVisWnd(this)
            %
            if(~this.isOpenVisWnd())
                %no study manager window - open one
                this.createVisWnd();
            end
            this.updateGUI();
            figure(this.visHandles.studyMgrFigure);
        end
        
        function updateGUI(this)
            %update GUI controls
            if(~this.isOpenVisWnd())
                return
            end
            sStr = this.allStudiesStr;
            if(isempty(sStr))
                set(this.visHandles.popupStudySelection,'String','no studies found');
            else
                set(this.visHandles.popupStudySelection,'String',sStr,'Value',min(length(sStr),get(this.visHandles.popupStudySelection,'Value')));
            end
            infoHeaders = this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders');
            if(~isempty(this.selectedInfoField))
                curColumn = get(this.visHandles.popupColumnSelection,'String'); %current column name and index
                if(iscell(curColumn))
                    curColumn = curColumn{min(length(curColumn),this.selectedInfoField(2))};
                end
                curColumnIdx = find(strcmp(curColumn,infoHeaders),1);
            else
                curColumnIdx = [];
            end
            set(this.visHandles.tableStudyData,'ColumnName',infoHeaders);
            if(~isempty(infoHeaders))
                if(isempty(curColumnIdx))
                    set(this.visHandles.popupColumnSelection,'Value',min(get(this.visHandles.popupColumnSelection,'Value'),length(infoHeaders)),'String',infoHeaders);
                else
                    set(this.visHandles.popupColumnSelection,'String',infoHeaders,'Value',curColumnIdx);
                    this.selectedInfoField(2) = curColumnIdx;
                end
            else
                set(this.visHandles.popupColumnSelection,'String','-');
                set(this.visHandles.popupColumnSelection,'Value',1);
            end            
            subjectInfo = this.fdt.getDataFromStudyInfo(this.curStudyName,'subjectInfo');
            subjectFilesData = this.fdt.getSubjectFilesData(this.curStudyName);
            set(this.visHandles.tableStudyData,'Data',subjectInfo,'ColumnEditable',true(1,size(subjectInfo,2))); 
            if(~isempty(subjectFilesData))
                set(this.visHandles.tableStudyData,'RowName',subjectFilesData(:,1));
            end
            set(this.visHandles.tableFileData,'ColumnName',this.fdt.getDataFromStudyInfo(this.curStudyName,'filesHeaders'),'Data',subjectFilesData);
            sStr = this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName());
            if(isempty(sStr))
                set(this.visHandles.popupSubjectSelection,'String','no subjects found');
            else
                set(this.visHandles.popupSubjectSelection,'String',sStr,'Value',min(length(sStr),get(this.visHandles.popupSubjectSelection,'Value')));
                if(isempty(this.selectedSubjects))
                    GUI_subjectSelPop_Callback(this,this.visHandles.popupSubjectSelection,[])
                end
            end
        end
        
        function addStudy(this,sName)
            %insert new study in FDTree and to study manager
            this.fdt.addStudy(sName);
            if(~this.isOpenVisWnd())
                return
            end
            studies = this.fdt.getStudyNames();
            nr = find(strcmp(sName,studies),1);
            if(~isempty(nr))
                set(this.visHandles.popupStudySelection,'String',studies,'Value',nr);
            end
            this.visObj.setupGUI();
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.FLIMXObj.FLIMFitGUI.updateGUI(true);
            this.updateGUI();
        end
        
        function renameStudy(this,oldStudyName)
            %rename a study
            if(strcmp(oldStudyName,'Default'))
                %do not rename Default study
                errordlg('Renaming study "Default" is not possible!','Error renaming study');
                return
            end
            
            sn = this.newStudyName();   %input dialog for study name
            if(isempty(sn))
                return
            end
            %change name
            this.fdt.setStudyName(oldStudyName,sn);
            %change directory
            oldfn = fullfile(this.myDir,oldStudyName);
            fn = fullfile(this.myDir,sn);
            movefile(oldfn,fn);
            this.fdt.saveStudy(sn);
        end
        
        function out = newStudyName(this)
            %input dialog for study name
            %rename Study
            out = [];
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            while(true)
                sn=inputdlg('Enter new study name:','Study Name',1,{this.curStudyName},options);
                if(isempty(sn))
                    return
                end
                %remove any '\' a might have entered
                sn = char(sn{1,1});
                sn = studyMgr.checkFolderName(sn);
                if(isempty(sn))
                    continue
                end
                %check if study name is available
                if(any(strcmp(sn,this.fdt.getStudyNames())))
                    choice = questdlg(sprintf('The Study "%s" is already existent! Please choose another name.',sn),...
                        'Error creating Study','Choose new Name','Cancel','Choose new Name');                    
                    % Handle response
                    switch choice
                        case 'Cancel'
                            return
                    end
                    continue;
                else
                    %we have a unique name
                    break;
                end
            end
            out = sn;
        end
        
        function out = getChNo(this,subName)
            % input dialog for channel number
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            id = this.fdt.getSubjectNr(this.curStudyName,subName);
            subjectFiles = this.fdt.getDataFromStudyInfo(this.curStudyName,'subjectFiles');
            if(isempty(max([subjectFiles{id,:}])))
                ch = 1;
            else
                ch = max([subjectFiles{id,:}])+1;
            end            
            while(true)
                sn=inputdlg('Enter a new channel number:','Adding new channel',1,{sprintf('%d',ch)},options);
                if(isempty(sn))
                    out = [];
                    return
                end                
                sn = str2double(sn);                
                if(isempty(sn))
                    choice = questdlg(sprintf('This is not a valid channel identification! Please choose another name.'),...
                        'Error adding channel','Choose new name','Cancel','Choose new name');
                    switch choice
                        case 'Cancel'
                            return
                    end
                    continue;
                end                
                check = intersect(sn,[subjectFiles{id,:}]);
                if(~isempty(check))
                    choice = questdlg(sprintf('This channel identification is already assigned! Please choose another channel.'),...
                        'Error adding channel','Choose new channel','Cancel','Choose new channel');
                    switch choice
                        case 'Cancel'
                            return
                    end
                    continue;
                else
                    %we have a unique name
                    break;
                end
            end %
            out = sn;
        end
        
        function add2Clipboard(this,val)
            %add something to Clipboard
            %First Element: Mode 1: Copy / Mode 2: Cut
            this.myClipboard(end+1) = {val};
        end
        
        function clearClipboard(this)
            %delete all contents of Clipboard
            this.myClipboard = cell(0,0);
        end
        
        function insertSubjects(this,destination)
            %insert subject in destination study
            %used by the operations copy/move and the study duplication
            
            %check and insert column headers with conditions
            this.fdt.insertColumnHeaders(destination,this.myClipboard{2});            
            queue = [];
            nSubjects = length(this.myClipboard)-2;
            tStart = clock;
            for i=3:(length(this.myClipboard))
                %copy Subject Data for StudyMgr
                subName = this.fdt.getSubjectName(this.myClipboard{2},this.myClipboard{i});
                %check subject
                this.fdt.copySubject(this.myClipboard{2},subName,destination,subName);                
                %update progress bar
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/(i-2)*(nSubjects-(i-2))); %mean cputime for finished runs * cycles left
                this.plotProgressbar((i-2)/nSubjects,[],...
                    sprintf('Progress: %02.1f%% - Time left: %dh %dmin %.0fsec', 100*(i-2)/nSubjects,hours,minutes,secs));
                %workaround for deleting subjects in cut-mode
                queue{end+1} = subName;
                if(this.stop)
                    this.stop = false;
                    break;
                end
            end
            
            %Clipboard-Mode: Cut?
            if this.myClipboard{1} == 2
                for i = 1:size(queue,2)
                    %delete only subjects which were copied successfully
                    %using workaround
                    subName = queue{i};
                    %clear subject from source study
                    this.fdt.removeSubject(this.myClipboard{2},subName);
                end
                this.fdt.checkStudyFiles(this.myClipboard{2});
                this.fdt.saveStudy(this.myClipboard{2});
            end
            this.fdt.checkConditionRef(destination,[]);
            this.plotProgressbar(0,'','');
        end
        
        function importResults4Subjects(this,subjects)
            %import result channel(s) for subject(s)
            for i = 1:length(subjects)
                %get channel list
                chList = cell(0,0);
                subjectFiles = this.fdt.getDataFromStudyInfo(this.curStudyName,'resultFileChs');
                for j = 1:size(subjectFiles,2)
                    if(~isempty(subjectFiles{subjects(i),j}))
                        chList(end+1,1)=subjectFiles(subjects(i),j);
                    end
                end
                subName = this.fdt.getSubjectName(this.curStudyName,subjects(i));
                opt.parent = 'studyMgr';
                opt.subName = subName;
                opt.studyName = this.curStudyName;
                opt.chList = chList;
                opt.mode = 1;
                opt.ch = [];
                opt.fdt = this.fdt;
                subject = this.fdt.getSubject4Approx(this.curStudyName,subjects(i));
                fi = [];
                if(~isempty(subject) && ~isempty(subject.nonEmptyResultChannelList))
                    fi = subject.getFileInfoStruct(subject.nonEmptyResultChannelList(1));
                end
                if(isempty(subject) || isempty(fi))
                    fi = measurementFile.getDefaultFileInfo();
                end
                opt.position = fi.position;
                opt.pixelResolution = fi.pixelResolution;
                if(~this.visObj.importResult([],opt))
                    %user pressed cancel or something went wrong
                    return
                end
                this.fdt.checkSubjectFiles(this.curStudyName,'');
                this.updateGUI();
            end
        end
        
        %% GUI & menu callbacks
        function menuExit_Callback(this,hObject,eventdata)
            %executes on figure close
            %close StudyManager
            studies = this.fdt.getStudyNames();
            askUser = true;            
            for i = 1:length(studies)
                if(~isempty(studies{i}) && any(this.fdt.checkStudyDirtyFlag(studies{i})))
                    if(askUser)
                        choice = questdlg(sprintf('Save changes to study ''%s''?',studies{i}),'Save study?','Yes','All','No','Yes');
                        switch choice
                            case 'Yes'
                                this.fdt.saveStudy(studies{i});
                            case 'All'
                                askUser = false;
                                this.fdt.saveStudy(studies{i});
                            case 'No'
                                %load unmodified study and check files
                                this.fdt.loadStudy(studies{i});
                        end
                    else
                        %always save changes
                        this.fdt.saveStudy(studies{i});
                    end
                    this.fdt.checkStudyFiles(studies{i});
                end
            end
            if(~isempty(this.visHandles) && ishandle(this.visHandles.studyMgrFigure))
                delete(this.visHandles.studyMgrFigure);
            end
        end
        
        function menuSaveStudy_Callback(this,hObject,eventdata)
            %
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> Save</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.fdt.saveStudy(this.curStudyName);
            set(hObject,'String','Save');
        end
        
        function menuDeleteStudy_Callback(this,hObject,eventdata)
            %delete current study
            if(strcmp(this.curStudyName,'Default'))
                errordlg('Study ''Default'' can not be deleted!','Error deleting Study');
                return
            end            
            choice = questdlg(sprintf('Do really want to delete study ''%s'' PERMANENTLY?',this.curStudyName),'Delete Study','Yes','No','No');
            switch choice
                case 'No'
                    return
            end
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> Delete</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.fdt.removeStudy(this.curStudyName);
            this.updateGUI();
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.FLIMXObj.FLIMFitGUI.updateGUI(true);
            set(hObject,'String','Delete');
            figure(this.visHandles.studyMgrFigure);
        end
        
        function menuDuplicateStudy_Callback(this,hObject,eventdata)
            %duplicate current study
            newStudyName = this.newStudyName();
            if(isempty(newStudyName))
                %user pressed cancel
                return
            end
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> Duplicate</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            %duplicate study using the copySubject method and Clipboard
            this.clearClipboard;
            this.add2Clipboard(1);
            this.add2Clipboard(this.curStudyName);
            for i=1:this.fdt.getNrSubjects(this.curStudyName,FDTree.defaultConditionName())
                this.add2Clipboard(i)
            end            
            this.addStudy(newStudyName);
            this.insertSubjects(newStudyName);            
            this.fdt.saveStudy(newStudyName);
            this.clearClipboard;
            set(hObject,'String','Duplicate');
            this.updateGUI();
        end
        
        function menuNewStudy_Callback(this,hObject,eventdata)
            %create new study in study manager
            sn = this.newStudyName();
            if(~isempty(sn))
                %add study to FDTree
                this.addStudy(sn);
            end
        end
        
        function menuExportStudy_Callback(this,hObject,eventdata)
            %get all studies in FDtree
            studiesFLIM = this.fdt.getStudyNames();
            studiesFile = cell(0,0);            
            %open export dialog to export studies
            list = GUI_studyExportImport(studiesFLIM,studiesFile);            
            if(~isempty(list))
                %file dialog -> select export file name
                [file,path] = uiputfile('*.flimxstudy','Destination for exported studies...');
                if(~file)
                    return;
                end
                fn = fullfile(path,file);                
                %studies to export:
                this.fdt.exportStudies(list,fn);
            end
        end
        
        function menuImportStudy_Callback(this,hObject,eventdata)
            %opens import dialog to import studies
            [file,path] = uigetfile('*.flimxstudy','Import Studies...',...
                'MultiSelect', 'on');
            if(~iscell(file) && ~ischar(file) && file == 0)
                %user pressed cancel
                return;
            end
            if(ischar(file))
                file = {file};
            end
            %find number of studies
            studyNames = cell(length(file),1);
            userNames = cell(length(file),1);
            for i = 1:length(file)
                idx = strfind(file{i},'~FLIMX~');
                userNames{i} = file{i}(1:idx-1);
                studyNames{i} = file{i}(idx+7:end-length('.flimxstudy'));
                %check for multiple parts of a study
                hit = regexp(studyNames{i},'#\d\d\d');
                if(~isempty(hit))
                    studyNames{i} = studyNames{i}(1:hit-1);
                end
            end
            [studyNames,idx] = unique(studyNames);
            userNames = userNames(idx);
            %get all studies in FDTree
            studiesFLIMX = this.fdt.getStudyNames();
            tStart = clock;
            for i = 1:length(studyNames)
                %check study names
                newStudyNames = studyNames;
                if(any(strncmp(studiesFLIMX,newStudyNames{i},length(newStudyNames{i}))))
                    choice = questdlg(sprintf('Study ''%s'' already exists in FLIMX. Choose a new name for the imported study or skip this study.',newStudyNames{i}),...
                        'Study already exists','Choose new name','Skip study','Choose new name');
                    switch choice
                        case 'Choose new name'
                            % rename study in export file
                            newName = this.newStudyName();
                            if(isempty(newName))
                                %user pressed cancel
                                return
                            end
                            newStudyNames{i} = newName;
                            % update name in export file
                        case 'Skip study'
                            continue
                    end
                end
                %update progress bar
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(studyNames)-i)); %mean cputime for finished runs * cycles left
                this.plotProgressbar(i/(length(studyNames)),[],sprintf('Progress: %02.1f%% - Time left: %dh %dmin %.0fsec - Importing study ''%s''',100*i/length(studyNames),hours,minutes,secs,newStudyNames{i}));
                %check for additional files on disk
                fn = rdir(fullfile(path,sprintf('%s~FLIMX~%s*.flimxstudy',userNames{i},studyNames{i})));
                if(~isempty(fn))
                    %import
                    this.fdt.importStudy(newStudyNames{i},{fn.name});
                end                
            end           
            this.plotProgressbar(0,'','');
            this.updateGUI();
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.FLIMXObj.FLIMFitGUI.updateGUI(true);
        end
        
        function menuRenameStudy_Callback(this,hObject,eventdata)
            %rename study
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> Rename</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            oldSub = '';
            subs = this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName());
            if(strcmp(this.FLIMXObj.curSubject.myParent.name,this.curStudyName) && any(strcmp(this.FLIMXObj.curSubject.name,subs)))
                %a subject of the study we want to rename is currently loaded in FLIMX
                %toDo: load dummy subject?! load other study?!
                oldSub = this.FLIMXObj.curSubject.name;
                this.FLIMXObj.setCurrentSubject(this.curStudyName,FDTree.defaultConditionName(),'');                
            end
            this.renameStudy(this.curStudyName);
            this.updateGUI();
            this.visObj.setupGUI();
            if(~isempty(oldSub))
                this.FLIMXObj.setCurrentSubject(this.curStudyName,FDTree.defaultConditionName(),oldSub);
            else                
                this.FLIMXObj.FLIMFitGUI.setupGUI();
                this.FLIMXObj.FLIMFitGUI.updateGUI(true);
            end
            set(hObject,'String','Rename');
        end
        
        function menuImportMeasurementSingle_Callback(this,hObject,eventdata)
            %import measurement file
            if(isempty(this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName())) || isempty(this.selectedSubjects))
                %no subjects in current study
                return
            end
            for i = 1:length(this.selectedSubjects)
                subName = this.fdt.getSubjectName(this.curStudyName,this.selectedSubjects(i));
                this.FLIMXObj.importGUI.openFileByGUI(this.curStudyName,subName);
            end
%             figure(this.visHandles.studyMgrFigure);
        end
        
        function menuImportMeasurementFolder_Callback(this,hObject,eventdata)
            %import all sdt files in a folder and its subfolders
            obj = importFolderGUI(this.FLIMXObj);
            obj.openFolderByGUI();
            obj.currentStudy = this.curStudyName;
        end
        
        function menuImportResultSelSub_Callback(this,hObject,eventdata)
            %import ASCII results for selected subject(s)
            if(isempty(this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName())))
                %no subjects in current study
                return
            end            
            this.importResults4Subjects(this.selectedSubjects);
            figure(this.visHandles.studyMgrFigure);
        end
        
        function menuImportResultAll_Callback(this,hObject,eventdata)
            %import ASCII results for all subjects
            if(isempty(this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName())))
                %no subjects in current study
                return
            end            
            subjects = this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName());
            for i=1:length(subjects)
                subidx(i) = this.fdt.getSubjectNr(this.curStudyName,subjects{i});
            end            
            choice = questdlg(sprintf('The FLIMFitresults for each subject of the study will now be imported.\n\nPlease select either ASCII files beginning with the first channel or FLIMFit result files.'),'Importing study subjects','OK','Cancel','OK');
            switch choice
                case 'Cancel'
                    return
            end            
            this.importResults4Subjects(subidx);
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextNewColumn_Callback(this,hObject,eventdata)
            %Create new conditional column
            infoHeaders = this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders');
            infoHeaders(end+1,1) = {FDTree.defaultConditionName()};
            %init GUI with arbitrary start values
            opt.list = infoHeaders;
            opt.cond = false;
            opt.ops = {'-no op-','AND','OR','!AND','!OR','XOR','<','>','<=','>=','==','!='};
            opt.name = [];
            opt.colA = 1;
            opt.colB = 2;
            opt.relA = 5;
            opt.valA = 1;
            opt.relB = 5;
            opt.valB = 1;
            opt.logOp = 1;
            %start GUI
            opt = GUI_conditionalCol(opt);
            if(~isempty(opt))
                %insert new column
                if(~opt.cond)
                    this.fdt.addColumn(this.curStudyName,opt.name);
                else
                    this.fdt.addCondColumn(this.curStudyName,opt);
                    if(strcmp(this.FLIMXObj.curSubject.myParent.name,this.curStudyName))
                        this.FLIMXObj.FLIMFitGUI.setupGUI();
                    end
                end
                this.updateGUI();
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextEditColumn_Callback(this,hObject,eventdata)
            %edit existing condition column
            %init GUI with corresponding values
            if(isempty(this.selectedInfoField))
                return
            end
            %check if conditional column and enable context menu
            ref = this.fdt.getColReference(this.curStudyName,this.selectedInfoField(2));
            infoHeaders = this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders');
            opt.list = infoHeaders;
            opt.ops = {'-no op-','AND','OR','!AND','!OR','XOR','<','>','<=','>=','==','!='};
            opt.name = infoHeaders{this.selectedInfoField(2)};
            if(isempty(ref))
                opt.cond = false;
                opt.colA = 1;
                opt.colB = 2;
                opt.relA = 1;
                opt.valA = 10;
                opt.relB = 1;
                opt.valB = 10;
                opt.logOp = 1;
            else
                opt.cond = true;
                opt.colA = this.fdt.infoHeaderName2idx(this.curStudyName,ref.colA);
                opt.colB = this.fdt.infoHeaderName2idx(this.curStudyName,ref.colB);
                [~, loc] = ismember(ref.relA,opt.ops);
                opt.relA = loc-6;
                opt.valA = ref.valA;
                [~, loc] = ismember(ref.relB,opt.ops);
                opt.relB = loc-6;
                opt.valB = ref.valB;
                [~, loc] = ismember(ref.logOp,opt.ops);
                opt.logOp = loc;
            end
            
            %start GUI
            opt = GUI_conditionalCol(opt);
            if(~isempty(opt))
                %modify conditional column
                this.fdt.setSubjectInfoHeaders(this.curStudyName,opt.name,this.selectedInfoField(2));
                if(opt.cond)
                    %set or update condition
                    this.fdt.setCondColumn(this.curStudyName,opt.name,opt);
                else
                    if(~isempty(ref))
                        %delete old condition and reset table values
                        this.fdt.setCondColumn(this.curStudyName,opt.name,[]);
                    end
                end
                this.updateGUI();
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextMoveColL_Callback(this,hObject,eventdata)
            %move selected column by swapping with its left neighbor
            this.fdt.swapColumn(this.curStudyName,this.selectedInfoField(2),-1);
            this.updateGUI();
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextMoveColR_Callback(this,hObject,eventdata)
            %move selected column by swapping with its right neighbor
            this.fdt.swapColumn(this.curStudyName,this.selectedInfoField(2),1);
            this.updateGUI();
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextMoveColBegin_Callback(this,hObject,eventdata)
            %move selected column to beginning
            col = this.selectedInfoField(2);
            while(col > 1)
                this.fdt.swapColumn(this.curStudyName,col,-1);
                col = col-1;
            end
            this.updateGUI();
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextMoveColEnd_Callback(this,hObject,eventdata)
            %move selected column to end
            headers = this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders');
            col = this.selectedInfoField(2);
            while(col < length(headers))
                this.fdt.swapColumn(this.curStudyName,col,1);
                col = col+1;
            end
            this.updateGUI();
            figure(this.visHandles.studyMgrFigure);
        end
        
        function contextDelColumn_Callback(this,hObject,eventdata)
            %delete selected column
            col=this.selectedInfoField(2);
            infoHeaders = this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders');
            if(col > size(infoHeaders,1))
                %if index is greater than column number (i.e. table is empty or
                %user deleted a column at the end without selecting new cell)
                col = size(infoHeaders,1);
            end
            if(col>0);
                choice = questdlg(sprintf('Do you really want to delete Column "%s" ?',...
                    infoHeaders{col,1}),'Delete Column','Yes','Cancel','Yes');
                %Handle response
                switch choice
                    case 'Cancel'
                        return
                end
            end
            %User want to delete column or column is empty:
            this.fdt.removeColumn(this.curStudyName,infoHeaders{col,1})
            this.updateGUI();
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            figure(this.visHandles.studyMgrFigure);
        end
        
        
        function GUI_tableStudyDataSel_Callback(this,hObject,eventdata)
            %gets current position in table StudyData
            %necessary for newColumn
            if(~isempty(eventdata.Indices))
                this.selectedInfoField = eventdata.Indices;
                set(this.visHandles.popupColumnSelection,'Value',eventdata.Indices(2));
            end
        end
        
        function GUI_tableFileDataSel_Callback(this,hObject,eventdata)
            %select a subject
            if(~isempty(eventdata.Indices))
                this.selectedSubjects = unique(min(eventdata.Indices(:,1),this.fdt.getNrSubjects(this.curStudyName,FDTree.defaultConditionName())));
                if(~isempty(this.selectedSubjects))
                    set(this.visHandles.popupSubjectSelection,'Value',min(length(get(this.visHandles.popupSubjectSelection,'String')),this.selectedSubjects(1)));
                end
            end
        end
        
        function GUI_tableStudyDataEdit_Callback(this,hObject,eventdata)
            %change content of cellarray in StudyData table
            %get new subject info
            new = eventdata.NewData;
            if(all(isstrprop(new,'digit')))
                new = str2double(new);
            end
            this.fdt.setSubjectInfo(this.curStudyName,eventdata.Indices(1),eventdata.Indices(2),new);
            this.updateGUI();
        end
        
        function GUI_studySelPop_Callback(this,hObject,eventdata)
            %select a study
            if(~isempty(this.fdt.getDataFromStudyInfo(this.curStudyName,'infoHeaders')))
                %select first column
                this.selectedInfoField = [1 1];
            end
            this.selectedSubjects = [];
            this.updateGUI();
        end
        
        function GUI_subjectSelPop_Callback(this,hObject,eventdata)
            %select a subject
            if(isMultipleCall())
                return
            end
            ed.Indices(1) = get(hObject,'Value');
            ed.Indices(2) = 1;
            try
                sp = findjobj(this.visHandles.tableFileData);
                components = sp.getComponents;
                viewport = components(1);
                curComp = viewport.getComponents;
                jtable=curComp(1);
                %             jtable.setRowSelectionAllowed(0);
                %             jtable.setColumnSelectionAllowed(0);
                jtable.changeSelection(ed.Indices(1)-1,0, false, false);
            catch
                GUI_tableFileDataSel_Callback(this,this.visHandles.tableFileData,ed);
            end
        end        
        
        function GUI_columnSelPop_Callback(this,hObject,eventdata)
            % set current column for editing and moving purposes
            this.selectedInfoField = [1 get(hObject,'Value')];
        end
        
        function menuNewSubject_Callback(this,hObject,eventdata)
            %add a new subject to current study manually
            subName = this.getUniqueSubjectName(this.curStudyName,this.lastAddedSubject);
            if(~isempty(subName))
                this.fdt.addSubject(this.curStudyName,subName);
                this.lastAddedSubject = subName;
                this.updateGUI();
            end
        end
        
        function menuDeleteSubject_Callback(this,hObject,eventdata)
            %delete subject from current study
            subjects = sort(this.selectedSubjects,'descend');
            if(isempty(subjects))
                return
            end
            askUser = true;
            for i = 1:length(subjects)
                subName = this.fdt.getSubjectName(this.curStudyName,subjects(i));
                if(~isempty(subName))
                    if(askUser)
                        choice = questdlg(sprintf('Delete subject ''%s'' from study ''%s''?',subName,this.curStudyName),...
                            'Delete Subject','Yes','All','No','No');
                        if(isempty(choice))                            
                            break %abort
                        end
                        % Handle response
                        switch choice
                            case 'No'
                                continue
                            case 'All'
                                askUser = false;
                        end
                    end
                    this.fdt.removeSubject(this.curStudyName,subName);
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
            subs = this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName());
            if(strcmp(this.FLIMXObj.curSubject.myParent.name,this.curStudyName) && strcmp(this.FLIMXObj.curSubject.name,subName))
                if(~isempty(subs))
                    this.FLIMXObj.setCurrentSubject(this.curStudyName,FDTree.defaultConditionName(),subs{1});
                else
                    %toDo: load dummy subject?! load other study?!
                    this.FLIMXObj.setCurrentSubject(this.curStudyName,FDTree.defaultConditionName(),'');
                end
            else
                this.FLIMXObj.FLIMFitGUI.setupGUI();
                this.FLIMXObj.FLIMFitGUI.updateGUI(true);
            end
            this.checkVisWnd();
        end
        
        function menuCopySubject_Callback(this,hObject,eventdata)
            %"Copy" or "Cut" Subject to Clipboard
            %not the Subject will be saved in the clipbord but a "link" to
            %the corresponding Study and the selected Subject
            this.clearClipboard;
            %First element in Clipboard characterize mode
            if(strcmp(get(hObject,'Tag'),'menuCutSubject')...
                    || strcmp(get(hObject,'Tag'),'contextCutSubject'))
                this.add2Clipboard(2);  %Clipboard-Mode: Cut
            else
                this.add2Clipboard(1);  %Clipboard-Mode: Copy
            end
            
            %Second element: Study Number
            this.add2Clipboard(this.curStudyName);
            %Other elements: Subject Numbers
            subjects = sort(this.selectedSubjects,'ascend');
            for i = 1:length(subjects)
                this.add2Clipboard(subjects(i));
            end
        end
        
        function menuPasteSubject_Callback(this,hObject,eventdata)
            %Insert Subject from Clipboard in current Study
            if(isempty(this.myClipboard))
                return
            end
            
            if(this.fdt.checkStudyDirtyFlag(this.curStudyName))
                %warning dialog
                choice = questdlg(sprintf('All changes in study ''%s'' will be saved. Do you want to continue?',this.curStudyName),...
                    'Inserting Subjects','Yes','Abort','Abort');
                switch choice
                    case 'Yes'
                        %
                    case 'Abort'
                        return
                end %end switch
            end %end if
            
            %Subject in Clipboard is from current Study
            if(this.curStudyNr == this.myClipboard{2})
                errordlg('You can not copy a Subject to itself! Please select another Study!',...
                    'Error inserting Subject');
                return
            end
            
            %insert subjects
            this.insertSubjects(this.curStudyName);
            this.fdt.saveStudy(this.curStudyName);
            this.updateGUI();
        end
        
        function menuDuplicateSubject_Callback(this,hObject,eventdata)
            %duplicate subject
            if(this.fdt.checkStudyDirtyFlag(this.curStudyName))
                %warning dialog
                choice = questdlg(sprintf('All changes in study ''%s'' will be saved. Do you want to continue?',this.curStudyName),...
                    'Inserting Subjects','Yes','Abort','Abort');
                switch choice
                    case 'Yes'
                        %
                    case 'Abort'
                        return
                end %end switch
            end %end if
            subNrs = this.selectedSubjects;
            subNames = cell(length(subNrs),1);
            for i=1:length(subNrs)
                subNames{i} = this.fdt.getSubjectName(this.curStudyName,subNrs(i));
            end
            %rename selected subjects
            for i=1:length(subNrs)
                oldSubName = subNames{i};
                newSubName = this.getUniqueSubjectName(this.curStudyName,oldSubName);
                if(isempty(newSubName))
                    break
                end
                %duplicate subject
                this.fdt.copySubject(this.curStudyName,oldSubName,this.curStudyName,newSubName);
            end
            this.updateGUI();
            this.visObj.setupGUI();
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.FLIMXObj.FLIMFitGUI.updateGUI(true);
        end
        
        function menuRenameSubject_Callback(this,hObject,eventdata)
            %rename subject
            if(this.fdt.checkStudyDirtyFlag(this.curStudyName))
                %warning dialog
                choice = questdlg(sprintf('All changes in study ''%s'' will be saved. Do you want to continue?',this.curStudyName),...
                    'Inserting Subjects','Yes','Abort','Abort');
                switch choice
                    case 'Yes'
                        %
                    case 'Abort'
                        return
                end %end switch
            end %end if
            subNrs = this.selectedSubjects;
            %rename selected subjects
            for i=1:length(subNrs)
                oldSubName = this.fdt.getSubjectName(this.curStudyName,subNrs(i));
                subName = this.getUniqueSubjectName(this.curStudyName,oldSubName);
                if(~isempty(subName))
                    %rename subject
                    this.fdt.setSubjectName(this.curStudyName,oldSubName,subName);
                end
            end
            this.visObj.setupGUI();
            this.FLIMXObj.FLIMFitGUI.setupGUI();
            this.FLIMXObj.FLIMFitGUI.updateGUI(true);
            this.checkVisWnd();
        end
        
        function menuChangeStudyFileInfo_Callback(this,hObject,eventdata)
            %change file info (only resolution) for each subject in a study
            
        end
        
        function menuChangeSubjectFileInfo_Callback(this,hObject,eventdata)
            %change subject file info (position, resolution)
            subNrs = this.selectedSubjects;
            for i=1:length(subNrs)
                subject = this.fdt.getSubject4Approx(this.curStudyName,subNrs(i));
                if(isempty(subject))
                    continue
                end
                fi = subject.getFileInfoStruct([]);
                if(isempty(fi))
                    continue
                end
                [pos, res] = GUI_subjectFileInfo(fi.position,fi.pixelResolution);
                if(~isempty(pos) && (~strcmp(pos,fi.position) || abs(res-fi.pixelResolution) > eps))
                    this.plotProgressbar(0.25,[],'25% - Updating File Info');
                    %update subject
                    subject.updatePixelResolution(res,[]);
                    subject.updatePosition(pos,[]);
                    %                     subject.saveMatFile2Disk([]);
                    %                     this.FLIMXObj.fdt.clearSubjectCI(this.curStudyName,subNrs(i));
                    
                    this.plotProgressbar(0.50,[],'50% - Updating File Info');
                    chList = subject.nonEmptyResultChannelList;
                    for chIdx = 1:length(chList)
                        subject.updateSubjectChannel(chList(chIdx),'');
                        this.plotProgressbar(0.50+0.5*chIdx/length(chList),[],sprintf('%2.0f%% - Updating File Info',(0.50+0.5*chIdx/length(chList))*100));
                    end
                end
                this.plotProgressbar(0,[],'');
            end
            this.updateGUI();
            this.visObj.updateGUI('');
        end
        
        function newName = getUniqueSubjectName(this,study,oldSubjetName)
            %have the user enter a new name for subject which is not already in the study
            newName = '';
            if(~any(strcmp(study,this.fdt.getStudyNames())))
                %we don't have that study
                return
            end
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            while(true)
                newName = inputdlg('Enter a unique subject name:',...
                    'New Subject',1,{oldSubjetName},options);
                if(isempty(newName))
                    return
                end
                newName = char(newName{1,1});
                newName = studyMgr.checkFolderName(newName);
                if(isempty(newName))
                    continue
                end
                if(~isempty(this.fdt.getSubjectNr(study,newName)))
                    choice = questdlg(sprintf('The description "%s" is already a name for a subject in study ''%s''!',...
                        newName,study),'Subject Name Error','Choose new Name','Cancel','Choose new Name');
                    % Handle response
                    switch choice
                        case 'Cancel'
                            newName = '';
                            return
                    end
                    continue;
                else
                    %we have a unique name
                    break;
                end
            end
        end
        
        function menuDeleteSubjectResult_Callback(this,hObject,eventdata)
            %delete the results of current subject(s)
            subNrs = this.selectedSubjects;
            askUser = true;
            for i=1:length(subNrs)
                subName = this.fdt.getSubjectName(this.curStudyName,subNrs(i));
                if(askUser)
                    choice = questdlg(sprintf('Delete the approximation results for subject "%s"?',subName),'Delete Subject Results','Yes','All','No','No');
                    % Handle response
                    if(isempty(choice))
                        break %abort
                    end
                    switch choice
                        case 'All'
                            askUser = false;
                        case 'No'
                            continue
                    end
                end
                this.fdt.removeSubjectResult(this.curStudyName,subNrs(i));
                if(rem(i,10)<eps)
                    this.plotProgressbar(i/length(subNrs),[],sprintf('%2.0f%% - Deleting Subject Results',(i/length(subNrs))*100));
                end
%                 %check if deleted result is currently loaded in fitGUI
%                 if(strcmp(this.FLIMXObj.curFluoFile.studyName,this.curStudyName) && strcmp(this.FLIMXObj.curFluoFile.datasetName,subName))
%                     this.FLIMXObj.curResultObj.allocResults();
%                 end
            end
            this.plotProgressbar(0,[],'');
            this.updateGUI();
            this.visObj.setupGUI();
        end
        
        function menuCopyROI2Study_Callback(this,hObject,eventdata)
            %copy ROI coordinates of subject(s) from current study to target study
            if(~this.isOpenVisWnd())
                return
            end
            studies = get(this.visHandles.popupStudySelection,'String');
            orgStudyID = get(this.visHandles.popupStudySelection,'Value');
            destStudyID = GUI_studyDestinationSel(studies,orgStudyID);
            if(isempty(destStudyID) || destStudyID > length(studies) || orgStudyID == destStudyID)
                return
            end
            subNrs = this.selectedSubjects;
            nSubjects = length(subNrs);
            tStart = clock;
            for i=1:nSubjects
                subjectID = this.fdt.getSubjectName(studies{orgStudyID},subNrs(i));
                this.fdt.copySubjectROI(studies{orgStudyID},studies{destStudyID},subjectID)
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/(i)*(nSubjects-(i))); %mean cputime for finished runs * cycles left
                this.plotProgressbar((i)/nSubjects,[],...
                    sprintf('Progress: %02.1f%% - Time left: %dh %dmin %.0fsec', 100*(i)/nSubjects,hours,minutes,secs));
            end
            this.plotProgressbar(0,'','');
            this.visObj.setupGUI();
            this.visObj.updateGUI('');
        end
        
        function menuImportExcel_Callback(this,hObject,eventdata)
            %import subject info from excel file
            mode = 1;
            if(~isempty(this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName())))
                choice = questdlg(sprintf('Either delete all current subject information for all subjects in study ''%s'' or update existing subject information and add new subjects?',this.curStudyName),'Importing Subject Information from Excel Data','Update and Add New','Delete Old Info','Abort','Update and Add New');
                switch choice
                    case 'Update and Add New'
                        mode = 2;
                    case 'Delete Old Info'
                        mode = 1;
                    otherwise %'Abort'
                        return
                end
            end
            [file, path, filterindex] = uigetfile( ...
                {  '*.xls','Excel-files (*.xls)'}, ...
                'Import Subject Data from Excel File...', ...
                'MultiSelect', 'off',this.lastStudyPath);
            if ~path ; return ; end
            fn = fullfile(path,file);
            this.lastStudyPath = path;
            this.fdt.importXLS(this.curStudyName,fn,mode);
            this.updateGUI;
            figure(this.visHandles.studyMgrFigure);
        end
        
        function menuExportExcel_Callback(this,hObject,eventdata)
            %save Subjects and corresponding study data to Excel file
            if(isempty(this.fdt.getSubjectsNames(this.curStudyName,FDTree.defaultConditionName())))
                return
            end
            
            [file,path] = uiputfile('*.xls','Export Subject Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);
            
            this.fdt.exportXLS(this.curStudyName,fn);
        end
        
        function GUI_buttonOK_Callback(this,hObject,eventdata)
            this.menuExit_Callback();
        end
        
        function GUI_buttonStop_Callback(this,hObject,eventdata)
            this.stop = true;
        end
        
        function plotProgressbar(this,x,varargin)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));
            if(~ishandle(this.visHandles.studyMgrFigure))
                return;
            end
            xpatch = [0 x x 0];
            set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            if nargin>0,
                % update waitbar
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textProgress,'Position',[1,yl(2)/2,0],'String',varargin{2},'Parent',this.visHandles.axesProgress);
            end
            drawnow;
        end
        
        %% dependent properties
        function out = get.fdt(this)
            %shortcut to fdt
            out = this.FLIMXObj.fdt;
        end
        
        function out = get.visObj(this)
            %shortcut to FLIMVis
            out = this.FLIMXObj.FLIMVisGUI;
        end
        
        function nr = get.curStudyNr(this)
            %get current study nr
            if(this.isOpenVisWnd())
                nr = get(this.visHandles.popupStudySelection,'Value');
            end
        end
        
        function name = get.curStudyName(this)
            %get name of current study
            if(this.isOpenVisWnd())
                studies = get(this.visHandles.popupStudySelection,'String');
                name = studies{this.curStudyNr};
                if(isempty(name))
                    name = '';
                end            
            else
                name = '';
            end
        end
        
        function set.curStudyName(this,val)
            %set name of current study
            if(this.isOpenVisWnd())
                studies = get(this.visHandles.popupStudySelection,'String');
                idx = find(strcmp(val,studies),1);
                if(~isempty(idx))
                    set(this.visHandles.popupStudySelection,'Value',idx);
                end
                this.GUI_studySelPop_Callback(this.visHandles.popupStudySelection,[]);
            end
        end
                
        function str = get.allStudiesStr(this)
            %return a cell aray of all studies
            str = this.fdt.getStudyNames();
        end
        
    end %methods
    
     methods(Static)
         function name = checkFolderName(name)
             %check folder / file name for valid characters
             name = regexprep(name,'[/*:?"<>|]','');
             name = regexprep(name,'\','');
             name = strtrim(name); %remove leading and trailing whitespace
             name = regexprep(name,'[.]*$', ''); %remove trailing dots
         end         
     end %methods(Static)
end %classdef
