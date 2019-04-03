classdef FDTStudy < FDTreeNode
    %=============================================================================================================
    %
    % @file     FDTStudy.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  2.0
    % @date     January, 2019
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
    % @brief    A class to represent a study (contains subjectDataSets)
    %
    properties(SetAccess = protected,GetAccess = public)
        myDir = '';             %study's working directory
        revision = [];          %revision of the study code/dataformat
        myStudyInfoSet = [];    %subject info in study
        myConditionStatistics = [];  %merged objects to save statistics
        IRFInfo = [];           %struct to save information on the used IRF
        isDirty = false;        %flag is true if something of the study was changed
        isLoaded = false;       %flag is true if study was loaded from disk
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
    end
    
    methods
        function this = FDTStudy(parent,sDir,name)
            % Constructor for FDTStudy
            this = this@FDTreeNode(parent,name);
            this.revision = 31;
            this.myDir = sDir;
            this.myStudyInfoSet = studyIS(this);
            this.myConditionStatistics = LinkedList();
        end
        
        function  pingLRUCacheTable(this,obj)
            %ping LRU table for object obj
            if(~isempty(this.myParent))
                this.myParent.pingLRUCacheTable(obj);
            end
        end
        
%         function out = getSize(this)
%             %determine memory size of the study
%             out = 0;
%             for i = 1:this.nrChildren
%                 subject = this.getSubject(i);
%                 if(~isempty(subject))
%                     out = out + subject.getSize();
%                 end
%             end
%             %todo: add studyInfoSet and ConditionStatistics
%             %fprintf(1, 'Study size %d bytes\n', out);
%         end
        
        function load(this)
            %load study data from disk
            if(isMultipleCall())
                return
            end
            try
                import = load(fullfile(this.myDir,'studyData.mat'));
            catch
                %file not found
                return
            end
            import = import.export;            
            if(import.revision < this.revision)
                %version problem
                import = this.updateStudyVer(import);
            end            
            dirty = this.isDirty; %loadStudyIS may reset dirty flag from revision update
            this.name = import.name;
            this.myStudyInfoSet.loadStudyIS(import);            
            %this.checkSubjectFiles('');
            this.setDirty(dirty || this.isDirty);
            if(this.isDirty)
                %study version updated
                this.save();
            end            
            %create subjects (but load them on demand)
            subjects = this.myStudyInfoSet.getAllSubjectNames();
            for i=1:length(subjects)
                %add subject to mySubjects
                %channels = this.myStudyInfoSet.getFileChs(i);
                %add empty subject
                this.addSubject(subjects{i});                
            end
            this.isLoaded = true;
        end
                
        function updateShortProgress(this,prog,text)
            %update the progress bar of a short operation
            this.myParent.updateShortProgress(prog,text);
        end
        
        function updateLongProgress(this,prog,text)
            %update the progress bar of a long operation consisting of short ops
            this.myParent.updateLongProgress(prog,text);
        end
        
        function updateStudyMgrProgress(this,prog,text)
            %update the progress bar of study manager
            this.myParent.updateStudyMgrProgress(prog,text);
        end
        
        %% input functions
        function addObj(this,subjectID,chan,dType,gScale,data)
            %add an object to FDTree and generate id (running number) automatically
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                subject = this.addSubject(subjectID);
            end
            if(~isempty(chan))
                subject.addObj(chan,dType,gScale,data);
                this.clearObjMerged(chan,dType);
            end
        end
        
        function addObjID(this,nr,subjectID,chan,dType,gScale,data)
            %add an object to FDTree with specific id (running number)
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                subject = this.addSubject(subjectID);
            end
            if(~isempty(chan))
                subject.addObjID(nr,chan,dType,gScale,data);
                this.clearObjMerged(chan,dType,nr);
            end
        end
        
        function subject = addSubject(this,subjectName)
            %add subject(name = subjectID) to study data and make its directory
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectName);
            if(isempty(subject))
                %make dir if not present
                sDir = fullfile(this.myDir,subjectName);
                if(~isfolder(sDir))
                    [status, message, ~] = mkdir(sDir);
                    if(~status)
                        error('FLIMX:FDTree:addSubject','Could not create subject folder: %s\n%s',sDir,message);
                    end
                end
                subject = FDTSubject(this,sDir,subjectName);
                this.addChildByName(subject,subjectName);
                this.myStudyInfoSet.addSubject(subjectName);                
            end
        end
        
        function setSubjectName(this,subjectID,newName)
            %set subject name
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                %set name in tree
                subject.setSubjectName(newName);
                %set name in study info set
                idx = this.getChild(subjectID);
                this.myStudyInfoSet.setSubjectName(newName,idx);
                %rename folder (if one exists)
                oldpath = fullfile(this.myDir,subjectID);
                newpath = fullfile(this.myDir,newName);
                if(exist(oldpath,'dir') ~= 0)
                    movefile(oldpath,newpath);
                end
                this.renameChild(subjectID,newName);
                this.myStudyInfoSet.sortSubjects();
                %save because study info on disk was changed
                this.save();
            end
        end
        
        function setMVGroupTargets(this,MVGroupID,targets)
            %set multivariate targets for MVGroup
            %this.MVTargets = sort(val);
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setMVGroupTargets(MVGroupID,targets);
        end
        
        function setMVGroupName(this,MVGroupID,val)
            %set MVGroup name
            if(~this.isLoaded)
                this.load();
            end
            %set name of local MVGroup objects
            subStr = this.getSubjectsNames(FDTree.defaultConditionName());
            for i=1:length(subStr)
                subject = this.getChild(subStr{i});
                if(~isempty(subject))
                    subject.setdType(MVGroupID,val);
                end
            end
            %set name of condition MVGroup objects
            conditionStr = this.myStudyInfoSet.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
            conditionMVGroupID = sprintf('Condition%s',MVGroupID);
            for i=1:length(conditionStr)
                condition = this.getConditionObj(conditionStr{i});
                if(~isempty(condition))
                    condition.setdType(conditionMVGroupID,sprintf('Condition%s',val));
                end
            end
            %set name in study info set
            this.myStudyInfoSet.setMVGroupName(MVGroupID,val);
            this.setDirty(true);
        end
        
        function clearSubjectCI(this,subjectID)
            %clear current images (result ROI) of a subject
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                subject.clearAllCIs('');
%                 for ch = 1:2
%                     subject.loadChannel(ch,true);
%                 end
            end
        end
        
        function clearAllCIs(this,dType)
            %clear current images of datatype dType in all subject
            clearAllCIs@FDTreeNode(this,dType);
            %clear current images of datatype dType in all merged subjects
            for i = 1:this.myConditionStatistics.queueLen
                this.myConditionStatistics.getDataByPos(i).clearAllCIs(dType);
            end
        end
        
        function clearAllFIs(this,dType)
            %clear filtered raw images of datatype dType in all subject
            clearAllFIs@FDTreeNode(this,dType);
            %clear filtered raw images of datatype dType in all merged subjects
            for i = 1:this.myConditionStatistics.queueLen
                this.myConditionStatistics.getDataByPos(i).clearAllFIs(dType);
            end
        end
        
        function clearAllRIs(this,dType)
            %clear raw images of datatype dType in all subjects
            clearAllRIs@FDTreeNode(this,dType);
            if(strncmp(dType,'MVGroup',7))
                %clear corresponding condition MVGroup object
                conditionMVGroupID = sprintf('Condition%s',dType);
                for j=1:this.myConditionStatistics.queueLen
                    this.myConditionStatistics.getDataByPos(j).clearAllRIs(conditionMVGroupID);
                end
            end
%             for i = 1:this.nrChildren
%                 this.mySubjects.getDataByPos(i).clearAllRIs(dType);
%                 if(strncmp(dType,'MVGroup',7))
%                     %clear corresponding condition MVGroup object
%                     conditionMVGroupID = sprintf('Condition%s',dType);
%                     for j=1:this.myConditionStatistics.queueLen
%                         this.myConditionStatistics.getDataByPos(j).clearAllRIs(conditionMVGroupID);
%                     end
%                 end
%             end
        end
        
        function clearArithmeticRIs(this)
            %clear raw images of arithmetic images
            aiNames = this.getArithmeticImageDefinition();
            for j = 1:length(aiNames)
                if(~isempty(aiNames{j}))
                    this.clearAllRIs(aiNames{j});
                end
            end
        end
        
        function setName(this,name)
            %set new name for study
            this.name = name;
            this.setDirty(true);
        end
        
        function setStudyDir(this,sDir)
            %set the working directory for this study object
            this.myDir = sDir;
        end
        
        function setResultROICoordinates(this,subjectID,dType,dTypeNr,ROIType,ROICoord)
            %set the ROI vector at subject subjectID
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                return
            end
            this.myStudyInfoSet.setResultROICoordinates(subjectID,ROIType,ROICoord);
            this.clearArithmeticRIs(); %todo: check if an AI uses an ROI
            this.clearObjMerged();
            this.clearMVGroups(subjectID,dType,dTypeNr);
        end
        
        function deleteResultROICoordinates(this,dType,dTypeNr,ROIType)
            %delete the ROI coordinates for ROIType
            if(~this.isLoaded)
                this.load();
            end
%             subject = this.getChild(subjectID);
%             if(isempty(subject))
%                 return
%             end
            this.myStudyInfoSet.deleteResultROICoordinates(ROIType);
            this.clearArithmeticRIs(); %todo: check if an AI uses an ROI
            this.clearObjMerged();
%             this.clearMVGroups(subjectID,dType,dTypeNr);
        end
        
        function setResultZScaling(this,subjectID,ch,dType,dTypeNr,zValues)
            %set the z scaling at subject subjectID
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                return
            end
            this.myStudyInfoSet.setResultZScaling(subjectID,ch,dType,dTypeNr,zValues);
            this.clearObjMerged();
            this.clearMVGroups(subjectID,dType,dTypeNr);
        end
        
        function setResultColorScaling(this,subjectID,ch,dType,dTypeNr,colorBorders)
            %set the color scaling at subject subjectID
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                return
            end
            this.myStudyInfoSet.setResultColorScaling(subjectID,ch,dType,dTypeNr,colorBorders);
        end
        
        function setResultCrossSection(this,subjectID,dim,csDef)
            %set the cross section for subject subName and dimension dim
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setResultCrossSection(subjectID,dim,csDef);
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                subject.setResultCrossSection(dim,csDef);
            end
        end
                
        function setAllFLIMItems(this,subjectID,ch,items)
            %
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setAllFLIMItems(subjectID,ch,items);
        end
        
        function subjectObj = insertSubject(this,subName,subjectInfo)
            %create a new subject and store its subject info
            subjectObj = this.addSubject(subName);
            this.myStudyInfoSet.insertSubject(subName,subjectInfo);
        end
        
        function addColumn(this,name)
            %add new column to study info
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.addColumn(name);
        end
        
        function addConditionalColumn(this,val)
            %add new conditional column to study info with definition val
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.addConditionalColumn(val);
        end
        
        function setConditionalColumnDefinition(this,colName,opt)
            %set definition for conditional column
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setConditionalColumnDefinition(colName,opt);
        end
        
        function setSubjectInfoColumnName(this,newColumnName,idx)
            %give column at idx a new name
            if(~this.isLoaded)
                this.load();
            end
            %check if idx is a conditional column
            conditions = this.myStudyInfoSet.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
            allColumnNames = this.myStudyInfoSet.getDataFromStudyInfo('subjectInfoAllColumnNames');
            colName = allColumnNames{idx};
            if(ismember(colName,conditions))
                condition = this.getConditionObj(colName);
                if(~isempty(condition))
                    %we have this condition in FDtree, change name of condition
                    condition.setSubjectName(newColumnName);
                end
            end
            %set column name in study info data
            this.myStudyInfoSet.setSubjectInfoColumnName(newColumnName,idx);
        end
        
        function setSubjectInfo(this,irow,icol,newData)
            %set data in subject info at specific row and column
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setSubjectInfo(irow,icol,newData);
        end
        
        function setSubjectInfoConditionalColumnDefinition(this,def,idx)
            %set definition def of a conditional column with the index idx
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setSubjectInfoConditionalColumnDefinition(def,idx);
        end
        
        function importStudyInfo(this,file,mode)
            %import study info (subject info table) from excel file, mode 1: delete all old, mode 2: update old & add new
            if(~this.isLoaded)
                this.load();
            end
            %check file
            [typ, desc] = xlsfinfo(file);
            if(isempty(typ))
                %no excel file
                errordlg('This is not an Excel file!','No Excel file','modal')
                return;
            end
            idx = find(strcmp('Subjectinfo',desc),1);
            if(isempty(idx))
                %no appropriate spreadsheet
                errordlg('Spreadsheet ''Subjectinfo'' not found!','No appropriate spreadsheet','modal');
                return;
            else
                [~, ~, raw] = xlsread(file,'Subjectinfo');
            end
            %get subject and header names
            xlsSubs = raw(2:end,1);
            %make sure we have only strings as subjects
            idx = cellfun(@ischar,xlsSubs);
            xlsSubs = xlsSubs(idx);
            newSubs = setdiff(xlsSubs,this.getSubjectsNames(FDTree.defaultConditionName()));            
            %add new subjects
            for i=1:length(newSubs)
                this.addSubject(newSubs{i});
            end            
            this.myStudyInfoSet.importStudyInfo(raw,mode);
        end
        
%         function importResultStruct(this,subjectID,result,itemsTarget)
%             %import a new subject
%             subject = this.getSubject(subjectID);
%             if(isempty(subject))
%                 subject = this.addSubject(subjectID);
%             end            
%             chan = result.channel;
%             sfile = sprintf('result_ch%02d.mat',chan);
%             try
%                 save(fullfile(this.myDir,subjectID,sfile),'result');
%             catch ME
%                 %file saving failed
%                 %todo: better error handling / messaging
%                 return
%             end
%             this.myStudyInfoSet.setAllFLIMItems(subjectID,chan,removeNonVisItems(fieldnames(result.results.pixel)));
%             this.myStudyInfoSet.setSelFLIMItems(subjectID,chan,itemsTarget);
%             this.myStudyInfoSet.setResultOnHDD(subjectID,chan);
%             this.checkIRFInfo(chan);
%             %add empty channel
%             this.addObj(subjectID,chan,[],[],[]);
% %             subject.loadChannelResult(chan);
%         end
        
        function importSubject(this,importSubject)
            %import a new subject object (and possibly study)
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(importSubject.name);
            if(isempty(subject))
                subject = this.addSubject(importSubject.name);
            end
            %remove all old files
            this.clearSubjectFiles(importSubject.name);
            %save mat files for measurements and results
            importSubject.exportMatFile([],fullfile(this.myDir,importSubject.name));
            %this.checkSubjectFiles(importSubject.name);
            chs = importSubject.getNonEmptyChannelList('');
            if(~isempty(chs))
                for ch = chs
                    subject.removeResultChannelFromMemory(ch);
                    this.addObj(importSubject.name,ch,[],[],[]);
                end
%                 subject.loadChannel(chs(1),false);
            end
        end
        
        function unloadAllChannels(this)
            %remove all channels in all subjects from memory
            subStr = this.getSubjectsNames(FDTree.defaultConditionName());
            for i=1:length(subStr)
                subject = this.getChild(subStr{i});
                chs = subject.getNrChannels();
                if(~isempty(chs))
                    for ch = 1:chs
                        if(subject.channelResultIsLoaded(ch))
                            subject.removeResultChannelFromMemory(ch);
                            this.addObj(subject.name,ch,[],[],[]);
                        end
                    end
                end
            end
        end        
        
%         function importResultObj(this,resultObj,subjectName)
%             %import a result of a new subject (and possibly study)
%             subject = this.getSubject(subjectID);
%             if(isempty(subject))
%                 subject = this.addSubject(subjectID);
%             end
%             subject.importResultStruct(subjectName,resultObj.makeExportStruct(1),[]);
%                 %this.removeObjMerged();
%             
%         end
%         
%         function importMeasurementObj(this,fluoFileObj)
%             %import a measurement of a new subject (and possibly study)
%             subjectID = fluoFileObj.getDatasetName();
%             subject = this.getSubject(subjectID);
%             if(isempty(subject))
%                 subject = this.addSubject(subjectID);
%             end
%             
%             fluoFileObj.save2Disk([],fullfile(this.myDir,subjectID));
%             this.checkSubjectFiles(subjectID);
% %             sfile = sprintf('measurement_ch%02d.mat',chan);
% %             try
% %                 save(fullfile(sDir,sfile),'import');
% %             catch ME
% %                 %file saving failed
% %                 %todo: better error handling / messaging
% %                 return
% %             end 
% %             this.myStudyInfoSet.setResultOnHDD(subjectID,chan);
% %             this.checkIRFInfo(chan);
%             chs = fluoFileObj.getNonEmptyChannelList();
%             if(~isempty(chs))
%                 for ch = chs
%                     subject.removeResultChannelFromMemory(ch);
%                 end
%                 subject.loadChannelMeasurement(chs(1));
%             end
%         end
        
        function setArithmeticImageDefinition(this,aiName,aiParam)
            %set name and definition of arithmetic image for a study
            this.clearArithmeticRIs();
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setArithmeticImageDefinition(aiName,aiParam);
        end
        
        function setConditionColor(this,cName,val)
            %set condition color
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.setConditionColor(cName,val);
        end
        
        %% removing functions
        function removeArithmeticImageDefinition(this,aiName)
            %remove arithmetic image for a study
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.removeArithmeticImageDefinition(aiName);
            %remove the arithmetic image from each subject
            %do NOT load subjects from disk
            for i = 1:this.nrChildren
                if(this.getChildAtPos(i).channelResultIsLoaded(1))
                    this.removeObj(i,1,aiName,0);
                end
            end
        end
        
        function removeObj(this,subjectID,chan,dType,id)
            %remove object from subject
            if(~this.isLoaded)
                this.load();
            end
            [subject, subjectPos] = this.getChild(subjectID);
            if(~isempty(subject))
                subject.removeObj(chan,dType,id);
                this.clearObjMerged(chan,dType,id);
                if(subject.getNrChannels == 0)
                    %no channels in subject anymore -> remove whole subject
                    this.deleteChildByPos(subjectPos);
                end
            end
        end
        
        function removeResultChannelFromMemory(this,subjectID,ch)
            %remove channel of a subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                subject.removeResultChannelFromMemory(ch);
                %if(subject.getNrChannels == 0)
                %no channels in subject anymore -> remove whole subject
                %this.mySubjects.removePos(subjectPos);
                %end
                this.clearObjMerged(ch);
            end
        end
        
        function deleteChannel(this,subjectID,ch,type)
            %delete channel of a subject from memory and disk
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                subject.deleteChannel(ch,type);
                %if(subject.getNrChannels == 0)
                %no channels in subject anymore -> remove whole subject
                %this.mySubjects.removePos(subjectPos);
                %end
                if(strcmp(type,'result'))
                    subject.removeResultChannelFromMemory([]);
                    this.myStudyInfoSet.removeSubjectResult(subjectID);
                    this.clearObjMerged(ch);
                end
            end
        end
        
%         function removeSubjectResult(this,subjectID)
%             %remove all results of a subject
%             if(~this.isLoaded)
%                 this.load();
%             end
%             subject = this.getChild(subjectID);
%             if(~isempty(subject))
%                 subject.removeResultChannelFromMemory([]);
%                 this.myStudyInfoSet.removeSubjectResult(subjectID);
%                 %find result files
%                 subDir = fullfile(this.myDir,subject.name);
%                 files = rdir(sprintf('%s%sresult_ch*.mat',subDir,filesep));
%                 for i = 1:length(files)
%                     try
%                         delete(files(i).name);
%                     catch ME
%                         %todo
%                     end
%                 end
%             end
%         end
        
        function removeSubject(this,subjectID)
            %remove a subject
            if(~this.isLoaded)
                this.load();
            end
            [subject, subjectPos] = this.getChild(subjectID);
            if(~isempty(subject))
                this.deleteChildByPos(subjectPos);
                this.myStudyInfoSet.removeSubject(subjectID);                
                this.clearObjMerged();
            end
        end
        
        function removeMVGroup(this,MVGroupID)
            %remove MVGroup and corresponding objects            
            if(~this.isLoaded)
                this.load();
            end
            %delete local MVGroup objects
            subStr = this.getSubjectsNames(FDTree.defaultConditionName());
            for i=1:length(subStr)
                subject = this.getChild(subStr{i});
                if(~isempty(subject))
                    [~, chNrs] = this.getChStr(subStr{i});
                    for j=1:length(chNrs)
                        subject.removeObj(chNrs(j),MVGroupID,0);
                    end
                end
            end
            %delete condition MVGroup objects
            conditionStr = this.myStudyInfoSet.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
            conditionMVGroupID = sprintf('Condition%s',MVGroupID);
            for i=1:length(conditionStr)
                condition = this.getConditionObj(conditionStr{i});
                if(~isempty(condition))
                    [~, chNrs] = condition.getChStr();
                    for j=1:length(chNrs)
                        condition.removeObj(chNrs(j),conditionMVGroupID,0);
                    end
                end
            end
            %delete MVGroup parameter in study info set
            this.myStudyInfoSet.removeMVGroup(MVGroupID);
            this.setDirty(true);
        end
        
        function clearObjMerged(this,chan,dType,id)
            %clear merged FData objects, force to rebuild statistics
            for i = 1:this.myConditionStatistics.queueLen
                switch nargin
                    case 4
                        %clear specific object
                        hfd = this.myConditionStatistics.getDataByPos(i).getFDataObj(chan,dType,id,1);
                        if(~isempty(hfd))
                            hfd.clearCachedImage();
                        end
                    case 3
                        %clear all objects of dType
                        this.myConditionStatistics.getDataByPos(i).clearAllCIs(dType);
                    otherwise
                        %clear all objects
                        this.myConditionStatistics.getDataByPos(i).clearAllCIs([]);
                end
            end
        end
        
        function clearMVGroups(this,subjectID,dType,dTypeNr)
            %clear local and condition MVGroups
            MVGroupStr = this.getMVGroupNames(1);
            subject = this.getChild(subjectID);
            if(isempty(subject))
                return
            end
            if(strncmp('MVGroup',dType,7))
                %ROI of MVGroup was changed
                for i = 1:this.myConditionStatistics.queueLen
                    subStr = this.getSubjectsNames(this.myConditionStatistics.getDataByPos(i).name);
                    if(ismember(subjectID,subStr))
                        %condition contains subject
                        this.myConditionStatistics.getDataByPos(i).clearAllRIs(sprintf('Condition%s',dType));
                    end
                end
%                 this.myParent.clearGlobalObjMerged(sprintf('Global%s',dType));
            elseif(strncmp('ConditionMVGroup',dType,16))
                for i = 1:this.myConditionStatistics.queueLen
                    this.myConditionStatistics.getDataByPos(i).clearAllRIs(dType);
                end
%                 this.myParent.clearGlobalObjMerged(sprintf('Global%s',dType(5:end)));
%             elseif(strncmp('GlobalMVGroup',dType,13))
%                 this.myParent.clearGlobalObjMerged(dType);
            else
                %normal dType
                curGS = subject.getGlobalScale(dType);
                for i = 1:length(MVGroupStr)
                    cMVs = this.getMVGroupTargets(MVGroupStr{i});
                    cDType = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                    cGS = subject.getGlobalScale(cDType{1});
                    tmp = sprintf('%s %d',dType,dTypeNr);
                    if(ismember(tmp,cMVs.x) || ismember(tmp,cMVs.y) || curGS && cGS)
                        %clear local MVGroups
                        subject.clearAllRIs(MVGroupStr{i})
                        %clear condition MVGroups
                        for j = 1:this.myConditionStatistics.queueLen
                            subStr = this.getSubjectsNames(this.myConditionStatistics.getDataByPos(j).name);
                            if(ismember(subjectID,subStr))
                                %condition contains subject
                                this.myConditionStatistics.getDataByPos(j).clearAllRIs(sprintf('Condition%s',MVGroupStr{i}));
                            end
                        end
%                         this.myParent.clearGlobalObjMerged(sprintf('Global%s',MVGroupStr{i}));
                    end
                end
            end
        end
        
        function removeColumn(this,colName)
            %reomve column in study data and condition if required
            if(~this.isLoaded)
                this.load();
            end
            cond = this.myStudyInfoSet.getColumnDependencies(colName);
            if(~isempty(cond))
                %we have a reference column
                choice = questdlg(sprintf('"%s" is a reference column. All corresponding conditions will be deleted! Do you want to continue?',...
                    colName),'Delete Reference Column','OK','Cancel','OK');
                switch choice
                    case 'Cancel'
                        return
                end
                %delete all corresponding conditions
                for i=1:length(cond)
                    this.removeColumn(cond{i});
                end
            end
            %remove it from merged objects
            this.myConditionStatistics.removeID(colName);
            this.myStudyInfoSet.removeColumn(colName);
        end
        
        %% output functions
        function save(this)
            %save current study data to disk
            export = this.myStudyInfoSet.makeExportStruct([]);
            export.name = this.name;
            export.revision = this.revision;
            save(fullfile(this.myDir,'studyData.mat'),'export');
            %remove unnecessary files
            this.checkStudyFiles();
            %this.checkSubjectFiles([]);
            this.isDirty = false;
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end
        
        function out = getFDataObj(this,subjectID,chan,dType,id,sType)
            %get FData object
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                out = [];
                return
            end
            %check if is arithmetic image
            %to do: move this to FDTSubject class?
            [aiNames, aiParams] = this.myStudyInfoSet.getArithmeticImageDefinition();
            idx = strcmp(dType,aiNames);
            if(sum(idx) == 1) %found 1 arithmetic image
                %try to get image data
                out = subject.getFDataObj(chan,dType,id,sType);
                if(isempty(out) || isempty(out.getFullImage()))
                    %(re)build arithmetic image
                    subject.makeArithmeticImage(aiNames{idx},aiParams{idx});
                else %we have what we want
                    return
                end
            end
            out = subject.getFDataObj(chan,dType,id,sType);
        end
        
        function out = isArithmeticImage(this,dType)
            %return true, if dType is an arithmetic image
            aiNames = this.myStudyInfoSet.getArithmeticImageDefinition();
            idx = strcmp(dType,aiNames);
            out = sum(idx) == 1;
        end
        
        function out = getSubject4Approx(this,subjectID)
            %get subject object which includes measurements and results
            if(~this.isLoaded)
                this.load();
            end
            if(~ischar(subjectID))
                subjectID = this.myStudyInfoSet.idx2SubName(subjectID);
            end
            out = this.getChild(subjectID);
            if(isempty(out))
                out = this.addSubject(subjectID);
            end
        end
        
        function out = getSubject4Import(this,subjectID)
            %get subject object to import measurements or results
            if(~this.isLoaded)
                this.load();
            end
            if(~ischar(subjectID))
                subjectID = this.myStudyInfoSet.idx2SubName(subjectID);
            end
            out = subject4Import(this,subjectID);
        end
        
%         function [ROIType, ROISubType, ROICustomCoordinates] = getResultROIInfo(this,subjectID)
%             %get all info on result ROI definition of subject
%             ROIType = this.getResultROIType(subjectID);
%             ROISubType = this.getResultROISubType(subjectID);
%             %ROISubTypeAnchor = this.getResultROISubTypeAnchor(subjectID);
%             ROICustomCoordinates = this.getResultROI(subjectID,[]);
%         end
        
        function [resultObj, isBH, chNrs] = getResultObj(this,subjectID,chan)
            %get fluoDecayFitResult object, chan = [] loads all channels
            if(~this.isLoaded)
                this.load();
            end
            %get all FLIM data for subject subjectID
            resultObj = []; isBH = false;
            chNrs = cell2mat(this.myStudyInfoSet.getResultFileChs(subjectID));
            if(isempty(chan) && ~isempty(chNrs))
                chan = chNrs;
            elseif(~any(chNrs == chan) || (isempty(chan) && isempty(chNrs)))
                %channel not found
                return
            end
            if(~ischar(subjectID))
                subjectID = this.myStudyInfoSet.idx2SubName(subjectID);
            end
            resultObj = fluoSubject(this,subjectID);
            chNrs = resultObj.getNonEmptyChannelList('result');
%             chLoad = resultObj.openResult(fullfile(this.myDir,subjectID,sprintf('result_ch%02d.mat',chan(1))),1,length(chan) > 1);
%             if(isempty(chLoad) || chLoad < 1)
%                 %             try
%                 %                 import = load(fullfile(this.myDir,subjectID,sprintf('result_ch%02d.mat',chan)));
%                 %                 data = import.result;
%                 %                 if(strcmp(data.resultType,'ASCII'))
%                 %                     %this is a B&H result
%                 %                     isBH = true;
%                 %                 end
%                 %             catch ME
%                 %                 uiwait(warndlg(sprintf(...
%                 %                     'Channel %d of subject ''%s'' could not be loaded!\nFile is corrupt!\n\n%S',...
%                 %                     chan,subjectID,ME.message),'Error loading channel!','modal'));
%                 chNrs(ch) = [];
%                 %resultObj = [];
%                 %break
%             end
            if(~isempty(resultObj) && strcmp(resultObj.resultType,'ASCII'))
                isBH = true;
            end
            if(isempty(chNrs))
                resultObj = [];
            end
        end
        
%         function mObj = getMeasurementObj(this,varargin)
%             %get fluoFile object containing measurement data, chan = [] loads all channels
%             mObj = [];
%             if(length(varargin) == 2)
%                 subjectID = varargin{1};
%                 chan = varargin{2};
%             elseif(length(varargin) == 3)
%                 study = this.myParent.getStudy(varargin{1});
%                 if(~isempty(study))
%                     mObj = study.getMeasurementObj(varargin{2:3});
%                 end
%                 return
%             else
%                 return
%             end            
%             if(~ischar(subjectID))
%                 subjectID = this.myStudyInfoSet.idx2SubName(subjectID);
%             end
%             chNrs = cell2mat(this.myStudyInfoSet.getMeasurementFileChs(subjectID));
%             if(isempty(chNrs))
%                 %no data in subject or subject not in study
%                 return
%             elseif(isempty(chan))
%                 chan = chNrs;
%             elseif(~any(chNrs == chan))
%                 %channel not found
%                 return                
%             end            
%             mObj = measurementInFDTree(this.FLIMXParamMgrObj,fullfile(this.myDir,subjectID));
% %             mObj.setStudyName(this.name);            
% %             for ch = chan
% %                 goOn = mObj.loadFromDisk(fullfile(this.myDir,subjectID,sprintf('measurement_ch%02d.mat',ch)));
% %                 if(~goOn)
% %                     mObj = [];
% %                     break;
% %                 end
% %             end
% %             if(isempty(chNrs) || ~strcmp(mObj.getDatasetName(),subjectID))
% %                 mObj.setDatasetName(subjectID);
% %             end
%         end
        
        function out = getStudyObjs(this,cName,chan,dType,id,sType)
            %get all fData objects of datatype dType and with id from a study
            if(~this.isLoaded)
                this.load();
            end
            out = cell(0,0);
            tStart = clock;
            persistent lastUpdate                
            if(strcmp(cName,FDTree.defaultConditionName()))
                %get all objects
                for i=1:this.nrChildren
                    %try to get data
                    fData = this.getFDataObj(i,chan,dType,id,sType);
                    if(~isempty(fData))
                        %we found an object
                        out(end+1) = {fData};
                    end
                    if(isempty(lastUpdate) || etime(clock, lastUpdate) > 1)
                        [~, minutes, secs] = secs2hms(etime(clock,tStart)/i*(this.nrChildren-i));
                        this.updateLongProgress(i/this.nrChildren,sprintf('%02.1f%% - %02.0fmin %02.0fsec',i/this.nrChildren*100,minutes,secs));
                        lastUpdate = clock;
                    end
                    if(this.getCancelFlag())
                        break
                    end
                end
            else
                %get only objects of the selected condition cName
                subjectNames = this.getSubjectsNames(cName);
                for i=1:length(subjectNames)
                    %try to get data
                    fData = this.getFDataObj(subjectNames{i},chan,dType,id,sType);
                    if(~isempty(fData))
                        %we found an object
                        out(end+1) = {fData};
                    end
                    if(isempty(lastUpdate) || etime(clock, lastUpdate) > 1) %i == 1 || mod(i,5) == 0 || i == this.nrChildren)
                        [~, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(subjectNames)-i));
                        this.updateLongProgress(i/length(subjectNames),sprintf('%02.1f%% - %02.0fmin %02.0fsec',i/length(subjectNames)*100,minutes,secs));
                        lastUpdate = clock;
                    end
                    if(this.getCancelFlag())
                        break
                    end
                end
            end
            this.updateLongProgress(0,'');
        end
        
        function out = getFDataMergedObj(this,cName,chan,dType,id,sType,ROIType,ROISubType,ROIVicinity)
            %get merged subject object for histogram and statistics
            if(~this.isLoaded)
                this.load();
            end
            condition = this.getConditionObj(cName);
            if(isempty(condition) || isempty(condition.getFDataObj(chan,dType,id,sType)))
                %distinguish between merged statistics and condition MVGroups
                if(strncmp(dType,'ConditionMVGroup',16))
                    %add condition object
                    condition = FDTSubject(this,[],cName);
                    this.myConditionStatistics.insertEnd(condition,cName);
                    %make condition MVGroup
                    MVGroupID = dType(10:end);
                    [cimg, lblx, lbly, cw] = this.makeConditionMVGroupObj(cName,chan,MVGroupID);
                    %add condition MVGroup
                    condition.addObjID(0,chan,dType,0,cimg);
                    out = condition.getFDataObj(chan,dType,id,sType);
                    out.setupXLbl(lblx,cw);
                    out.setupYLbl(lbly,cw);
                    return
                else
                    %make merged subjects
                    this.makeObjMerged(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity);
                    condition = this.getConditionObj(cName);
                    if(isempty(condition))
                        %still empty, something went wrong
                        out = [];
                        return
                    end
                end
            end
            %try to get data
            out = condition.getFDataObj(chan,dType,id,sType);
            if(~strncmp(dType,'ConditionMVGroup',16))
                if(isempty(out) || out.isEmptyStat)
                    %rebuild merged subjects
                    this.makeObjMerged(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity);
                    out = condition.getFDataObj(chan,dType,id,sType);
                end
            end
        end
                
        function out = getConditionName(this,cNr)
            %get name of condition out of study data
            if(~this.isLoaded)
                this.load();
            end
            if(cNr == 1)
                %all subjects
                out = FDTree.defaultConditionName();
                return
            end
            subjectInfoHeaders = this.getDataFromStudyInfo('subjectInfoAllColumnNames');
            if(cNr > length(subjectInfoHeaders))
                out = [];
                return
            end
            out = subjectInfoHeaders{cNr};
        end        
        
        function out = getSubjectName(this,subjectID)
            %get subject name
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                out = [];
                return
            end
            out = subject.name;
        end
        
        function [condition, conditionPos] = getConditionObj(this,cName)
            %check if cName is in myConditionStatistics and return the condition object
            if(~this.isLoaded)
                this.load();
            end
            condition = [];
            conditionPos = [];
            if(ischar(cName))
                [condition, conditionPos] = this.myConditionStatistics.getDataByID(cName);
            elseif(isnumeric(cName) && cName <= this.myConditionStatistics.queueLen)
                conditionPos = cName;
                condition = this.myConditionStatistics.getDataByPos(conditionPos);
            end
        end
        
        function nr = getSubjectNr(this,subjectID)
            %get subject number
            if(~this.isLoaded)
                this.load();
            end
            nr = this.myStudyInfoSet.subName2idx(subjectID);
        end
        
        function [measurementChs, resultChs, position, resolution] = getSubjectFilesStatus(this,subjectID)
            %returns which channels are available for a subject in a study            
            subject = this.getChild(subjectID);
            if(~isempty(subject))
                %measurements
                measurementChs = subject.nonEmptyMeasurementChannelList;
                %results
                resultChs = subject.nonEmptyResultChannelList;  
                position = subject.position;
                resolution = subject.pixelResolution;
            end            
%             measurements = cell2mat(this.myStudyInfoSet.getMeasurementFileChs(subjectID));
%             results = cell2mat(this.myStudyInfoSet.getResultFileChs(subjectID));            
        end
        
        function out = getMVGroupTargets(this,MVGroupID)
            %get MVGroup targets from study info
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getMVGroupTargets(MVGroupID);
        end
        
        function nr = getNrSubjects(this,cName)
            %get number of subjects in study with condition cName
            if(~this.isLoaded)
                this.load();
            end
            if(strcmp(cName,FDTree.defaultConditionName()))
                %no condition
                nr = this.nrChildren;
            else
                %get number according to conditional column
                idx = this.myStudyInfoSet.subjectInfoColumnName2idx(cName);
                subjectInfo = this.myStudyInfoSet.getSubjectInfo([]);
                col = cell2mat(subjectInfo(:,idx));
                nr = sum(col);
            end
        end
        
        function dStr = getSubjectsNames(this,cName)
            %get a string of all subjects in the study
            if(~this.isLoaded)
                this.load();
            end
            dStr = this.getNamesOfAllChildren();%cell(0,0);
%             for i=1:this.nrChildren
%                 dStr(i,1) = {this.mySubjects.getDataByPos(i).getSubjectName};
%             end
            if(strcmp(cName,FDTree.defaultConditionName()))
                %no condition selected, show all subjects
%                 %make sure no suject name is empty
%                 idx = cellfun('isempty',dStr);
%                 dStr = dStr(~idx);
                return
            end
            %show only subjects which fullfil the conditional column
            idx = this.myStudyInfoSet.subjectInfoColumnName2idx(cName);
            subjectInfo = this.myStudyInfoSet.getSubjectInfo([]);
            col = cell2mat(subjectInfo(:,idx));
            dStr = dStr(col);
%             %make sure no suject name is empty
%             idx = cellfun('isempty',dStr);
%             dStr = dStr(~idx);
        end
        
        function [str, chNrs] = getChStr(this,subjectID)
            %get a string and numbers of all loaded channels in subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                str = [];
                chNrs = [];
                return
            end
            [str, chNrs] = subject.getChStr();
%             [measurements, results] = this.getSubjectFilesStatus(subjectID);
%             chNrs = union(measurements,results);
%             str = cell(length(chNrs),1);
%             for i = 1:length(chNrs)
%                 str(i,1) = {sprintf('Ch %d',chNrs(i))};
%             end
%             str = sprintfc('Ch %d',chNrs(:));
            %[str, nrs] = subject.getChStr();
        end
        
        function str = getChObjStr(this,subjectID,ch)
            %get a string of all objects in channel ch in subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                str = [];
                return
            end
%             if(~subject.channelResultIsLoaded(ch))
%                 subject.loadChannel(ch,false);
%             end
            %get existing FLIMitems in channel + arithmetic images (which may have not been computed yet)
            str = this.getArithmeticImageDefinition();
            if(isempty(str{1}))
                str = subject.getChObjStr(ch);
            else
                str = unique([subject.getChObjStr(ch);str]);
            end
        end
                
%         function str = getMVGroupNames(this,subjectID,ch)
%             %get a string of all MVGroup objects in channel ch in subject
%             if(~this.isLoaded)
%                 this.load();
%             end
%             subject = this.getChild(subjectID);
%             if(isempty(subject))
%                 str = [];
%                 return
%             end
% %             if(~subject.subjectIsLoaded(ch))
% %                 subject.loadChannel(ch,false);
% %             end
%             %get existing FLIMitems in channel + arithmetic images (which may have not been computed yet)
%             str = subject.getMVGroupNames(ch);
%         end
        
        function out = getHeight(this,subjectID)
            %get image height in subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                out = 0;
                return
            end
            out = subject.getHeight();
        end
        
        function out = getWidth(this,subjectID)
            %get image width in subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                out = 0;
                return
            end
            out = subject.getWidth();
        end
        
        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.myParent.getVicinityInfo();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end
                
        function data = getStudyPayload(this,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,dataProc)
            %get merged payload from all subjects of channel chan, datatype dType and 'running number' within a study for a certain ROI
            if(~this.isLoaded)
                this.load();
            end
            hg = this.getStudyObjs(cName,chan,dType,id,1);
            if(isempty(hg))
                return
            end
            data = [];
            for i = 1:length(hg)
                %tmp = hg{i}.getFullImage();
                ROICoordinates = this.getResultROICoordinates(hg{1}.subjectName,ROIType);
                tmp = hg{i}.getImgSeg(hg{i}.getFullImage(),ROICoordinates,ROIType,ROISubType,ROIVicinity,hg{1}.getFileInfoStruct(),this.getVicinityInfo());
                switch dataProc
                    case 'mean'
                        tmp = mean(tmp(~isnan(tmp) & ~isinf(tmp)));
                    case 'median'
                        tmp = median(tmp(~isnan(tmp) & ~isinf(tmp)));
                end
                data = [data; tmp(:)];        
            end
        end
        
        function [centers, histMerge, histTable, colDescription] = getStudyHistogram(this,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity)
            %combine all histograms of channel chan, datatype dType and 'running number' within a study
            if(~this.isLoaded)
                this.load();
            end
            hg = this.getFDataMergedObj(cName,chan,dType,id,1,ROIType,ROISubType,ROIVicinity);
            if(~isempty(hg))
                if(nargout > 2)
%                     centers = hg.getCIHistCentersStrict();
%                     histMerge = hg.getCIHist();
%                     [~, histMerge, centers]= hg.makeStatistics(ROIType,ROISubType,true);
                    hg = this.getStudyObjs(cName,chan,dType,id,1);
                    if(isempty(hg))
                        return
                    end
                    ROICoordinates = this.getResultROICoordinates(hg{1}.subjectName,ROIType);
                    [~, histMerge, centers]= hg{1}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
                    histTable = zeros(length(hg),length(centers));
                    colDescription = cell(length(hg),1);
                    for i = 1:length(hg)
                        %just make sure that histograms correspond to subject names
                        %c = hg{i}.getCIHistCentersStrict();
                        colDescription(i) = {hg{i}.subjectName};
                        ROICoordinates = this.getResultROICoordinates(colDescription{i},ROIType);
                        [~, histTemp, cTemp]= hg{i}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
                        start = find(centers == cTemp(1));
                        if(isempty(start))
                            start = find(cTemp == centers(1));                            
                            if(isempty(start))
                                cw = getHistParams(this.getStatsParams(),chan,dType,id);
                                if(min(cTemp(:)) > max(centers(:)))
                                    centers = centers(1):cw:cTemp(end);
                                    start = find(centers == cTemp(1));
                                    histTemp2 = zeros(length(hg),length(centers));
                                    histTemp2(:,1:size(histTable,2)) = histTable;
                                    histTemp2(i,start:start+length(histTemp)-1) = histTemp;
                                else
                                    centers = cTemp(1):cw:centers(end);
                                    histTemp2 = zeros(length(hg),length(centers));
                                    histTemp2(:,end-size(histTable,2)+1:end) = histTable;
                                    histTemp2(i,1:length(histTemp)) = histTemp;
                                end                                
                                histTable = histTemp2; 
                            else
                                cTemp(start:start+length(centers)-1) = centers;
                                centers = cTemp;
                                histTemp2 = zeros(length(hg),length(centers));
                                histTemp2(:,start:start+size(histTable,2)-1) = histTable;
                                histTemp2(i,1:length(histTemp)) = histTemp;
                                histTable = histTemp2;                                
                            end                            
                        else
                            histTable(i,start:start+length(cTemp)-1) = histTemp;
                            centers(start:start+length(cTemp)-1) = cTemp;                            
                        end                        
                    end
                else
                    %2 output arguments -> non-strict version
                    [histMerge, centers] = hg.getCIHist(ROIType,ROISubType,ROIVicinity);
                    histTable = [];
                    colDescription = cell(0,0);
                end
            else
                centers = []; histTable = []; histMerge = []; colDescription = cell(0,0);
            end
        end
        
        function [stats, statsDesc, subjectDesc] = getStudyStatistics(this,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,strictFlag)
            %get statistics for all subjects in study studyID, condition cName and channel chan of datatype dType with 'running number' id
            if(~this.isLoaded)
                this.load();
            end
            stats = []; statsDesc = []; subjectDesc = [];
            hg = this.getStudyObjs(cName,chan,dType,id,1);
            if(isempty(hg))
                return
            end
            nSubs = length(hg);
            statsDesc = FData.getDescriptiveStatisticsDescription();
            stats = zeros(nSubs,length(statsDesc));
            subjectDesc = cell(nSubs,1);
            for i = 1:nSubs
                subjectDesc(i) = {hg{i}.subjectName};
                ROICoordinates = this.getResultROICoordinates(subjectDesc{i},ROIType);
                if(strictFlag)
                    if(~any(ROICoordinates))
                        stats(i,:) = NaN;
                    else
                        stats(i,:) = hg{i}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
                    end
                else
                    stats(i,:) = hg{i}.getROIStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                end                
            end
        end
        
        function items = getAllFLIMItems(this,subjectID,ch)
            %
            if(~this.isLoaded)
                this.load();
            end
            items = this.myStudyInfoSet.getAllFLIMItems(subjectID,ch);
        end
                        
%         function out = getResultFileChs(this,j)
%             %
%             out = this.myStudyInfoSet.getResultFileChs(j);
%         end
        
        function out = getMVGroupNames(this,mode)
            %get list of MVGroups in study
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getMVGroupNames(mode);
        end
        
        function out = getConditionalColumnDefinition(this,idx)
            %return definition of a conditional column with index idx
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getConditionalColumnDefinition(idx);
        end
                
        function out = getSubjectInfo(this,subName)
            %return the data of all columns in subject info
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getSubjectInfo(subName);
        end
        
        function out = getSubjectInfoConditionalColumnDefinitions(this)
            %return definitions of all conditional columns in subject info
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getSubjectInfoConditionalColumnDefinitions();
        end
        
        function out = getResultROICoordinates(this,subName,ROIType)
            %return ROI coordinates for ROIType in a subject
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getResultROICoordinates(subName,ROIType);
        end
        
        function out = getResultZScaling(this,subName,ch,dType,dTypeNr)
            %
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getResultZScaling(subName,dType,ch,dTypeNr);
        end
        
        function out = getResultColorScaling(this,subName,ch,dType,dTypeNr)
            %
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getResultColorScaling(subName,dType,ch,dTypeNr);
        end
                
        function out = getResultCrossSection(this,subName)
            %return cross section defintion for subject
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getResultCrossSection(subName);
        end
        
        function data = makeInfoSetExportStruct(this,subName)
            %
            if(~this.isLoaded)
                this.load();
            end
            data = this.myStudyInfoSet.makeExportStruct(subName);
        end
        
%         function out = getSubjectFilesHeaders(this)
%             %
%             out = this.myStudyInfoSet.getSubjectFilesHeaders();
%         end
        
        function idx = subjectInfoColumnName2idx(this,columnName)
            %get the index of a subject info column or check if index is valid
            if(~this.isLoaded)
                this.load();
            end
            idx = this.myStudyInfoSet.subjectInfoColumnName2idx(columnName);
        end
        
        function data = getSubjectFilesData(this)
            %return a cell with subject names, their measurement and result channels
            %data = this.myStudyInfoSet.getSubjectFilesData();
            if(~this.isLoaded)
                this.load();
            end            
            data = cell(this.nrChildren,5);
            lastUpdate = clock;
            tStart = clock;
            this.updateStudyMgrProgress(0.01,'Scan subjects: 0%');
            for i = 1:this.nrChildren
                subject = this.getChildAtPos(i);
                if(~isempty(subject))
                    data{i,1} = subject.name;
                    [msChannels, rsChannels, pos, res] = this.getSubjectFilesStatus(i);
                    %measurements
                    %msChannels = subject.nonEmptyMeasurementChannelList;
                    if(isempty(msChannels))
                        data{i,2} = 'none';
                    else
                        str = num2str(msChannels(1));
                        for j = 2:length(msChannels)
                            str = sprintf('%s, %d',str,msChannels(j));
                        end
                        data{i,2} = str;
                    end
                    %results
                    %rsChannels = subject.nonEmptyResultChannelList;
                    if(isempty(rsChannels))
                        data{i,3} = 'none';
                    else
                        str = num2str(rsChannels(1));
                        for j = 2:length(rsChannels)
                            str = sprintf('%s, %d',str,rsChannels(j));
                        end
                        data{i,3} = str;
                    end
                    data{i,4} = pos;
                    data{i,5} = res;
                end
                if(etime(clock, lastUpdate) > 0.5)
                    [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(this.nrChildren-i)); %mean cputime for finished runs * cycles left
                    this.updateStudyMgrProgress(i/this.nrChildren,sprintf('Scan subjects: %0.1f%% - Time left: %dmin %.0fsec',100*i/this.nrChildren,minutes+hours*60,secs));
                    lastUpdate = clock;
                end
            end
            this.updateStudyMgrProgress(0,'');            
        end
        
        function out = getDataFromStudyInfo(this,descriptor,subName,colName)
            %get data from study info defined by descriptor
            if(~this.isLoaded)
                this.load();
            end
            switch nargin
                case 2
                    out = this.myStudyInfoSet.getDataFromStudyInfo(descriptor);
                case 3
                    out = this.myStudyInfoSet.getDataFromStudyInfo(descriptor,subName);
                case 4
                    out = this.myStudyInfoSet.getDataFromStudyInfo(descriptor,subName,colName);
                otherwise
                    out = [];
            end
        end
        
        function exportStudyInfo(this,file)
            %export study info (subject info table) to excel file
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.exportStudyInfo(file);
        end
        
        function out = getAllIRFInfo(this)
            %
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getAllIRFInfo();
        end
        
        function out = getIRFMgr(this)
            %get IRF manager
            out = this.myParent.getIRFMgr();
        end
        
        function out = getIRF(this,id,channel,timeChannels,tacRange)
            %get IRF from fitObj
            mgr = this.getIRFMgr();
            if(~isempty(mgr))
                out = mgr.getIRF(timeChannels,id,tacRange,channel);
            else
                out = [];
            end
        end
        
%         function out = getIRFStr(this,timeChannels)
%             %get names of all IRFs from fitObj
%             out = this.myParent.getIRFStr(timeChannels);
%         end
        
        function [aiStr, aiParam] = getArithmeticImageDefinition(this)
            %get names and definitions of arithmetic images for a study
            if(~this.isLoaded)
                this.load();
            end
            [aiStr, aiParam] = this.myStudyInfoSet.getArithmeticImageDefinition();
        end
        
        function out = getConditionColor(this,cName)
            %get color of condition
            if(~this.isLoaded)
                this.load();
            end
            out = this.myStudyInfoSet.getConditionColor(cName);
        end
        
        function out = isMember(this,subjectID,chan,dType)
            %function checks combination of subject, channel and datatype
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                out = false;
            elseif(isempty(chan))
                out = true;
            else
                out = subject.isMember(chan,dType);
            end
        end
        
        function out = getCancelFlag(this)
            %if true stop current operation
            out = this.myParent.getCancelFlag();
        end
        
        function out = getAboutInfo(this)
            %get about info structure
            out = this.FLIMXParamMgrObj.getParamSection('about');
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        %% compute functions and other methods                        
        function [cimg, lblx, lbly, cw] = makeConditionMVGroupObj(this,cName,chan,MVGroupID)
            %make merged MVGroups for a study condition
            if(~this.isLoaded)
                this.load();
            end
            cimg = []; lblx = []; lbly = [];
            MVGroupObjs = this.getStudyObjs(cName,chan,MVGroupID,0,1);            
            cMVs = this.getMVGroupTargets(MVGroupID);
            if(isempty(cMVs.x) || isempty(cMVs.y))
                return
            end
            %get reference classwidth
            [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
            cw = getHistParams(this.getStatsParams(),chan,dType{1},dTypeNr(1));            
            %get merged MVGroups from subjects of condition
            for i=1:length(MVGroupObjs)
                %use whole image for scatter plots, ignore any ROIs
                [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,MVGroupObjs{i}.getROIImage([],0,1,0),MVGroupObjs{i}.getCIXLbl([],0,1,0),MVGroupObjs{i}.getCIYLbl([],0,1,0),cw);
            end
        end
                
        function [cimg, lblx, lbly, colors, logColors] = makeGlobalMVGroupObj(this,chan,MVGroupID)
            %make global MVGroup object
            if(~this.isLoaded)
                this.load();
            end
            [cimg, lblx, lbly, colors, logColors] = this.myParent.makeGlobalMVGroupObj(chan,MVGroupID);
        end
        
        function ciMerged = makeObjMerged(this,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity)
            %compute and save merged subject object for statistics
            %get subjects
            if(~this.isLoaded)
                this.load();
            end
            hg = this.getStudyObjs(cName,chan,dType,id,1);
            if(isempty(hg))
                return
            end
            ciMerged = [];
            for i = 1:length(hg)
                ROICoordinates = this.getResultROICoordinates(hg{i}.subjectName,ROIType);
                ci = hg{i}.getROIImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                ciMerged = [ciMerged; ci(:);];
            end
            %add subject representing the merged data
            condition = this.getConditionObj(cName);
            if(isempty(condition))
                %add condition to list
                condition = FDTSubject(this,[],cName);
                this.myConditionStatistics.insertEnd(condition,cName);
            end
            condition.addObjMergeID(id,chan,dType,1,ciMerged);
        end
        
%         function [subject, subjectPos] = getSubject(this,subjectID)
%             %check if subjectID is in mySubjects and return the subject
%             subject = [];
%             subjectPos = [];
%             if(ischar(subjectID))
%                 subjectPos = this.myStudyInfoSet.subName2idx(subjectID);
%             elseif(isnumeric(subjectID))
%                 if(subjectID > this.nrChildren)
%                     return
%                 else
%                     subjectPos = subjectID;
%                 end
%             end
%             if(~isempty(subjectPos))
%                 subject = this.mySubjects.getDataByPos(subjectPos);
%             end
%         end
        
        function checkStudyFiles(this)
            %check study and its corresponding files on hard disk
            curDir = dir(this.myDir);
            SubFiles = {curDir.name};
            for i = 3:size(SubFiles,2)
                subDir = fullfile(this.myDir,SubFiles{i});
                if(isfolder(subDir))
                    idx = this.myStudyInfoSet.subName2idx(SubFiles{i});
                    if(isempty(idx))
                        %something on disk, but we don't know the subject
                        [status, message, messageid] = rmdir(subDir,'s');
                    end
                end
            end
            this.isDirty = false;
        end
        
        function checkSubjectFiles(this,subjectID)
            %check data files on disk for subject and update this.subjectFiles
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                %check all subjects
                %clear all old results
                nrSubjects = this.myStudyInfoSet.nrSubjects;
                subjects = this.myStudyInfoSet.getAllSubjectNames();
                this.myStudyInfoSet.clearFilesList([]);
                for i = 1:nrSubjects
                    this.checkSubjectFiles(subjects{i});
                end
            else
                %check specific subject
                subDir = fullfile(this.myDir,subjectID);
                idx = this.myStudyInfoSet.subName2idx(subjectID);
                if(isempty(idx))
                    %we don't know this subject, try to clear it
                    this.clearSubjectFiles(subjectID)
                    return
                elseif(~isempty(idx) && ~isfolder(subDir))
                    %we know the subject but there is nothing on disk
                    this.myStudyInfoSet.clearFilesList(idx);
                    this.myStudyInfoSet.clearROI(idx);
                    this.myStudyInfoSet.clearZScaling(idx);
                    this.myStudyInfoSet.clearCrossSections(idx);
                    return
                else
                    %we know the subject and there is something on disk
                    this.myStudyInfoSet.clearFilesList(idx);
                    %find result files
                    files = rdir(sprintf('%s%sresult_ch*.mat',subDir,filesep));
                    for i = 1:length(files)
                        [~,sn] = fileparts(files(i,1).name);
                        id = str2double(sn(isstrprop(sn, 'digit')));
                        this.myStudyInfoSet.setResultOnHDD(subjectID,id);
                    end
                    %find measurement files
                    files = rdir(sprintf('%s%smeasurement_ch*.mat',subDir,filesep));
                    for i = 1:length(files)
                        [~,sn] = fileparts(files(i,1).name);
                        id = str2double(sn(isstrprop(sn, 'digit')));
                        this.myStudyInfoSet.setMeasurementOnHDD(subjectID,id);
                    end
                end                
            end
        end
        
        function clearSubjectFiles(this,subName)
            %delete data files for subject
            if(isempty(subName))
                %clear all subjects
                nrSubjects = this.myStudyInfoSet.nrSubjects;
                subjects = this.myStudyInfoSet.getAllSubjectNames();
                for i = 1:nrSubjects
                    this.clearSubjectFiles(subjects{i});
                end
            else
                %clear specific subject
                idx = this.myStudyInfoSet.subName2idx(subName);
                if(~isempty(idx))
                    this.myStudyInfoSet.clearFilesList(idx);
                    this.myStudyInfoSet.clearROI(idx);
                    this.myStudyInfoSet.clearZScaling(idx);
                    this.myStudyInfoSet.clearCrossSections(idx);
                end
                subDir = fullfile(this.myDir,subName);
                if(~isfolder(subDir))
                    return
                end
                [status, message, messageid] = rmdir(subDir,'s');
            end
            this.setDirty(true);
        end
        
        function checkConditionRef(this,colN)
            %
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.checkConditionRef(colN);
        end
        
        function swapColumn(this,col,n)
            %
            if(~this.isLoaded)
                this.load();
            end
            this.myStudyInfoSet.swapColumn(col,n);
        end
        
        function oldStudy = updateStudyVer(this,oldStudy)
            %make old study data compatible with current version
            oldStudy = this.myStudyInfoSet.updateStudyInfoSet(oldStudy);
        end
        
        function setDirty(this,flag)
            %set dirty flag for this study
            this.isDirty = logical(flag);
        end
    end %methods
end %classdef