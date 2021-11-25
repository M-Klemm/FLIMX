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
    properties(SetAccess = protected, GetAccess = public)        
        revision = [];              %revision of the study code/dataformat
        %myStudyInfoSet = [];        %subject info in study
        myConditionStatistics = []; %merged objects to save statistics
        IRFInfo = [];               %struct to save information on the used IRF
        dirtyFlag = false;          %flag is true if something of the study was changed
        isLoaded = false;           %flag is true if study was loaded from disk        
    end
    properties(SetAccess = private, GetAccess = private)
        subjectNames = cell(0,0);                           %list of subject names
        subjectInfoColumnNames = cell(0,0);                 %descriptions of subject info columns
        subjectInfoColumnDefaults = cell(0,0);              %default values for subject info columns
        filesHeaders = {'Subject' 'Meas. Chs' 'Result Chs'};%descriptions of channel data columns
        subjectInfo = cell(0,0);                            %additional patient data
        subjectInfoConditionDefinition = cell(0,0);         %condition / combination between patient data
        resultFileChs = cell(0,0);                          %result channels of each subject
        measurementFileChs = cell(0,0);                     %measurement channels of each subject
        MVGroupTargets = cell(0,0);                         %cluster parameters for this study
        resultCrossSection = cell(0,0);                     %cross sections for each subject
        resultROICoordinates = cell(0,0);                   %rois for each subject
        nonDefaultSizeROICoordinates = cell(0,0);           %rois for each subject and FLIM item with non-default size
        resultROIGroups = cell(0,0);                        %groups of rois defined per study
        resultZScaling = cell(0,0);                         %z scaling for each subject
        resultColorScaling = cell(0,0);                     %color scaling for each subject
        allFLIMItems = cell(0,0);                           %selected FLIM parameters, for each subject and channel
        arithmeticImageInfo = cell(0,2);                    %arithmetic image definition
        conditionColors = cell(2,0);                        %colors for conditions
        
    end
    properties (Dependent = true)
        hashEngine                  %engine for md5 hash
        myDir                       %study's working directory
        FLIMXParamMgrObj
        isDirty                     %flag is true if something of the study was changed
        nrSubjects        
    end
    
    methods
        function this = FDTStudy(parent,name)
            % Constructor for FDTStudy
            this = this@FDTreeNode(parent,name);
            this.revision = 34;
            %check my directory
            sDir = this.myDir;
            if(~isfolder(sDir))
                [status, message, ~] = mkdir(sDir);
                if(~status)
                    error('FLIMX:FDTStudy','Could not create study working folder: %s\n%s',sDir,message);
                end
            end
            %this.myStudyInfoSet = studyIS(this);
            this.myConditionStatistics = LinkedList();
            this.subjectInfoColumnNames(1,1) = {'column 1'};
            this.subjectInfoConditionDefinition(1,1) = {[]};
            this.subjectInfoColumnDefaults(1,1) = {[]};
            this.conditionColors(1,1) = {FDTree.defaultConditionName()};
            this.conditionColors(2,1) = {FDTStudy.makeRndColor()};
        end
        
        function  pingLRUCacheTable(this,obj)
            %ping LRU table for object obj
            if(~isempty(this.myParent) && this.myParent.isvalid)
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
            matFile = fullfile(this.myDir,'studyData.mat');
            try
                import = load(matFile);
            catch
                bakFile = fullfile(this.myDir,'studyData.bak');
                if(~isempty(dir(bakFile)))
                    try
                        import = load(bakFile,'-mat');
                        %import worked, save the backup as .mat file
                        [status,msg,msgID] = copyfile(bakFile,matFile);
%                         if(~status)
%                             %todo: error / log message
%                         end
                    catch
                        %file not found
                        %todo: error / log message
                        return
                    end
                else
                    return
                end
            end            
            if(isfield(import,'checksum') && ~isempty(import.checksum) && ~isempty(this.hashEngine))
                this.hashEngine.reset();
                this.hashEngine.update(getByteStreamFromArray(import.export));
                myImportHash = typecast(this.hashEngine.digest, 'uint8');
                if(length(myImportHash(:)) ~= length(import.checksum(:)) || ~all(myImportHash(:) == import.checksum(:)))
                    warning('Loading study from %s failed because hash values did not match.\n', this.myDir);
                    %return
                end
            end
            import = import.export;
            if(import.revision < this.revision)
                %version problem
                import = this.updateStudyVer(import);
            end            
            %dirtyOld = this.dirtyFlag; %loadStudyIS may reset dirty flag from revision update
            this.name = import.name;
            %this.myStudyInfoSet.loadStudyIS(import);
            %load study info set
            [import,dirty] = FDTStudy.checkStudyConsistency(import);            
            this.subjectNames = import.subjectNames;
            this.subjectInfoColumnNames = import.subjectInfoColumnNames;
            %             this.subjectFilesHeaders = import.subjectFilesHeaders;
            this.subjectInfo = import.subjectInfo;
            this.subjectInfoConditionDefinition = import.subjectInfoConditionDefinition;
            this.subjectInfoColumnDefaults = import.subjectInfoColumnDefaults;
            this.allFLIMItems = import.allFLIMItems;
            this.resultFileChs = import.resultFileChs;
            this.measurementFileChs = import.measurementFileChs;
            this.MVGroupTargets = import.MVGroupTargets;
            this.resultROIGroups = import.resultROIGroups;
            this.resultROICoordinates = import.resultROICoordinates;
            this.nonDefaultSizeROICoordinates = import.nonDefaultSizeROICoordinates;
            this.resultZScaling = import.resultZScaling;
            this.resultColorScaling = import.resultColorScaling;
            this.resultCrossSection = import.resultCrossSection;
            this.IRFInfo = import.IRFInfo;
            this.arithmeticImageInfo = import.arithmeticImageInfo;
            this.conditionColors = import.conditionColors;
            this.sortSubjects();
            %this.setDirty(dirty);
            
            %this.checkSubjectFiles('');
            this.setDirty(dirty || this.dirtyFlag);
            if(this.dirtyFlag)
                %study version updated
                this.save();
            end            
            %create subjects (but load them on demand)
            subjects = this.subjectNames;
            for i=1:length(subjects)
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
                subject = FDTSubject(this,subjectName);
                this.addChildByName(subject,subjectName);
                % add a subject to this study
                if(~isempty(this.subName2idx(subjectName)))
                    %this is already a subject
                    return
                end
                this.subjectNames(end+1,1) = {subjectName};
                this.resultFileChs(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
                this.measurementFileChs(end+1,:) = cell(1,max(1,size(this.measurementFileChs,2)));
                this.subjectInfo(end+1,:) = cell(1,max(1,size(this.subjectInfo,2)));
                %add default values
                idx = ~cellfun(@isempty,this.subjectInfoColumnDefaults);
                this.subjectInfo(end,idx) = this.subjectInfoColumnDefaults(idx,1);
                this.resultROICoordinates(end+1) = cell(1,1);
                this.nonDefaultSizeROICoordinates(end+1) = cell(1,1);
                this.resultZScaling(end+1) = cell(1,1);
                this.resultColorScaling(end+1) = cell(1,1);
                this.resultCrossSection(end+1) = cell(1,1);
                this.allFLIMItems(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
                %sort subjects
                this.sortSubjects();
                this.checkConditionRef([]);
                this.setDirty(true);
            end
        end
        
        function setSubjectName(this,subjectID,newName)
            %set subject name
            if(~this.isLoaded)
                this.load();
            end
            [subject, idx] = this.getChild(subjectID);
            if(~isempty(subject))
                %set name in tree
                subject.setSubjectName(newName);
                %set name in study info set
                %this.myStudyInfoSet.setSubjectName(newName,idx);
                if(isempty(idx))
                    %set all subjects (initial cas)
                    this.subjectNames = [];
                    this.subjectNames = newName;
                else
                    %set a single subject
                    this.subjectNames(idx,1) = {newName};
                    this.setDirty(true);
                end
                
                this.renameChild(subjectID,newName);
                this.sortSubjects();
                %save because study info on disk was changed
                this.save();
            end
        end
        
%         function setMVGroupColor(this,MVGroupID,val)
%             %set MVGroup color
%             if(~this.isLoaded)
%                 this.load();
%             end
%             if(isempty(MVGroupID))
%                 return
%             end
%             %set condition color
%             if(isempty(val) || length(val) ~= 3)
%                 val = FDTStudy.makeRndColor();
%             end            
%             MVGroupNr = this.MVGroupName2idx(MVGroupID);
%             if(isempty(MVGroupNr))
%                 %add MVGroup
%                 this.MVGroupTargets(:,end+1) = cell(3,1);
%                 MVGroupNr = size(this.MVGroupTargets,2);
%                 this.MVGroupTargets(1,MVGroupNr) = {MVGroupID};
%             end
%             %set color
%             this.MVGroupTargets(3,MVGroupNr) = {val};
%             this.setDirty(true);            
%         end
            
        function setMVGroupTargets(this,MVGroupID,targets)
            %set multivariate targets for MVGroup
            if(~this.isLoaded)
                this.load();
            end
            if(nargin < 2)
                %set all MVGroup parameter (initial case)
                this.MVGroupTargets = [];
                this.MVGroupTargets = targets;
            else
                %set single value
                MVGroupNr = this.MVGroupName2idx(MVGroupID);
                if(isempty(MVGroupNr))
                    %add MVGroup
                    this.MVGroupTargets(:,end+1) = cell(2,1);
                    MVGroupNr = size(this.MVGroupTargets,2);
                    this.MVGroupTargets(1,MVGroupNr) = {MVGroupID};
                end
                %set targets
                this.MVGroupTargets(2,MVGroupNr) = {targets};
                this.setDirty(true);
            end
        end
        
        function setMVGroupName(this,MVGroupID,val)
            %set MVGroup name
            if(~this.isLoaded)
                this.load();
            end
            %set name of local MVGroup objects
            subStr = this.getAllSubjectNames(FDTree.defaultConditionName());
            for i=1:length(subStr)
                subject = this.getChild(subStr{i});
                if(~isempty(subject))
                    subject.setdType(MVGroupID,val);
                end
            end
            %set name of condition MVGroup objects
            conditionStr = this.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
            conditionMVGroupID = sprintf('Condition%s',MVGroupID);
            for i=1:length(conditionStr)
                condition = this.getConditionObj(conditionStr{i});
                if(~isempty(condition))
                    condition.setdType(conditionMVGroupID,sprintf('Condition%s',val));
                end
            end
            %set name in study info set
            MVGroupNr = this.MVGroupName2idx(MVGroupID);
            if(~isempty(MVGroupNr))
                this.MVGroupTargets(1,MVGroupNr) = {val};
            end
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
        
        function clearAllMVGroupIs(this)
            %clear data of all MVGroups in all subjects
            clearAllMVGroupIs@FDTreeNode(this); 
            for i = 1:this.myConditionStatistics.queueLen
                this.myConditionStatistics.getDataByPos(i).clearAllRIs('');
            end
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
            oldFolder = this.myDir;
            oldName = this.name;
            %save all changes in subjects and study info
            this.save();
            this.name = name;            
            %change directory            
            newFolder = this.myDir;
            lastUpdate = clock;
            tStart = clock;
            this.updateStudyMgrProgress(0.01,'Renaming study...');
            try
                [status,msg,msgID] = movefile(oldFolder,newFolder);
                if(~status)
                    %renaming the folder failed -> return
                    %todo: issue error / warning
                    this.name = oldName;
                    this.updateStudyMgrProgress(1,sprintf('Renaming study failed: %s',msg));
                    pause(1);
                    this.updateStudyMgrProgress(0,'');
                    return
                end
            catch ME
                %renaming the folder failed -> return
                %todo: issue error / warning
                this.name = oldName;
                this.updateStudyMgrProgress(1,sprintf('Renaming study failed: %s',ME.msgtext));
                pause(1);
                this.updateStudyMgrProgress(0,'');
                return
            end            
            %clear all cached subject data in study
            for i = 1:this.nrChildren
                subject = this.getChildAtPos(i);
                subject.reset();
                if(etime(clock, lastUpdate) > 0.5)
                    [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(this.nrChildren-i)); %mean cputime for finished runs * cycles left
                    this.updateStudyMgrProgress(i/this.nrChildren,sprintf('Renaming study: %0.1f%% - Time left: %dmin %.0fsec',100*i/this.nrChildren,minutes+hours*60,secs));
                    lastUpdate = clock;
                end
            end
            this.setDirty(true);
            %save new name
            this.save();
            this.updateStudyMgrProgress(0,'');
        end
        
        function setStudyDir(this,sDir)
            %set the working directory for this study object
            this.myDir = sDir;
        end
        
        function setResultROIGroup(this,grpName,grpMembers)
            %set the ROI group members for this study  
            if(~this.isLoaded)
                this.load();
            end
            %set the ROI group members for this study
            if(isempty(grpName))
                if(isempty(grpMembers))
                    %deleted last group
                    this.resultROIGroups = [];
                elseif(size(grpMembers,2) == 2)
                    %set all groups at once
                    this.resultROIGroups = grpMembers;
                end
            else
                if(isempty(this.resultROIGroups))
                    this.resultROIGroups = cell(1,2);
                    this.resultROIGroups{1,1} = grpName;
                    this.resultROIGroups(1,2) = grpMembers;
                else
                    idx = find(strcmp(this.resultROIGroups(:,1),grpName),1,'first');
                    if(isempty(idx))
                        this.resultROIGroups{end+1,1} = grpName;
                        idx = size(this.resultROIGroups,1);
                    end
                    this.resultROIGroups(idx,2) = grpMembers;
                    [~,i] = sort(this.resultROIGroups(:,1));
                    this.resultROIGroups = this.resultROIGroups(i,:);
                end
            end
            this.setDirty(true);
            %clear results?!
            this.clearAllCIs([]);
            this.clearArithmeticRIs(); %todo: check if an AI uses an ROI
            this.clearObjMerged();            
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
                sizeFlag = subject.getDefaultSizeFlag(dType);
                %set the ROI vector for subject
                subIdx = this.subName2idx(subjectID);
                if(isempty(subIdx))
                    %subject not in study or ROIVec size is wrong
                    return
                end                
                if(isempty(ROICoord))
                    ROICoord = zeros(2,3,'uint16');
                elseif(size(ROICoord,1) == 2 && size(ROICoord,2) == 1)
                    ROICoord(:,2:3) = zeros(2,2,'like',ROICoord);
                end
                if(isempty(ROIType))
                    %set all ROI coordinates at once
                    if(size(ROICoord,1) >= 7 && size(ROICoord,2) >= 3 && size(ROICoord,3) >= 2)
                        roiTmp = int16(ROICoord);
                    end
                else
                    if(sizeFlag)
                        roiTmp = this.resultROICoordinates{subIdx};
                    else
                        subTmp = this.nonDefaultSizeROICoordinates{subIdx};
                        if(isempty(subTmp))
                            dTIdx = [];
                        else
                            dTIdx = find(strcmp(subTmp(:,1),dType),1);
                        end
                        if(isempty(dTIdx))
                            roiTmp = [];
                        else
                            roiTmp = subTmp{dTIdx,2};
                        end
                    end
                    if(isempty(roiTmp) || size(roiTmp,1) < 7 || size(roiTmp,2) < 3)
                        roiTmp = ROICtrl.getDefaultROIStruct();
                    end
                    ROIType = int16(ROIType);
                    idx = find(abs(roiTmp(:,1,1) - ROIType) < eps,1,'first');
                    if(isempty(idx))
                        %new ROI
                        this.addResultROIType(ROIType);
                        if(sizeFlag)
                            roiTmp = this.resultROICoordinates{subIdx};
                        else
                            subTmp = this.nonDefaultSizeROICoordinates{subIdx};
                            if(isempty(subTmp))
                                dTIdx = [];
                            else
                                dTIdx = find(strcmp(subTmp(:,1),dType),1);
                            end
                            if(isempty(dTIdx))
                                roiTmp = [];
                            else
                                roiTmp = subTmp{dTIdx,2};
                            end
                        end
                        idx = find(abs(roiTmp(:,1,1) - ROIType) < eps,1,'first');
                    end
                    if(ROIType >= 1000 && ROIType < 4000 && size(ROICoord,1) == 2 && size(ROICoord,2) == 3)
                        %ETDRS, rectangle or cricle
                        roiTmp(idx,1:3,1:2) = int16(ROICoord');
                    elseif(ROIType > 4000 && ROIType < 5000 && size(ROICoord,1) == 2)
                        %polygons
                        if(size(ROICoord,2) > size(roiTmp,2))
                            tmpNew = zeros(size(roiTmp,1),size(ROICoord,2),2,'int16');
                            tmpNew(:,1:size(roiTmp,2),:) = roiTmp;
                            tmpNew(idx,1:size(ROICoord,2),:) = int16(ROICoord');
                            roiTmp = tmpNew;
                        else
                            roiTmp(idx,1:size(ROICoord,2),1:2) = int16(ROICoord');
                            roiTmp(idx,max(4,size(ROICoord,2)+1):end,:) = 0;
                        end
                        %polygon could have shrinked, remove trailing zeros
                        idxZeros = squeeze(any(any(roiTmp,1),3));
                        idxZeros(1:3) = true;
                        roiTmp(:,find(idxZeros,1,'last')+1:end,:) = [];
                    end
                    %store ROIType just to be sure it is correct
                    roiTmp(idx,1,1) = ROIType;
                end
                if(sizeFlag)
                    this.resultROICoordinates(subIdx) = {roiTmp};
                else
                    subTmp = this.nonDefaultSizeROICoordinates{subIdx};
                    if(isempty(subTmp))
                        dTIdx = [];
                    else
                        dTIdx = find(strcmp(subTmp(:,1),dType),1);
                    end
                    if(isempty(dTIdx))
                        %dType not found -> add it
                        subTmp{end+1,1} = dType;
                        dTIdx = size(subTmp,1);
                    end
                    subTmp(dTIdx,2) = {roiTmp};
                    this.nonDefaultSizeROICoordinates(subIdx) = {subTmp};
                end                
                this.setDirty(true);
%             else
                %this FLIM item (chunk) has a different size than the subject
                %subject.setResultROICoordinates(dType,ROIType,ROICoord);

%             end
            this.clearArithmeticRIs(); %todo: check if an AI uses an ROI
            this.clearObjMerged();
            this.clearMVGroups(subjectID,dType,dTypeNr);
            this.clearAllMVGroupIs();
        end
        
        function removeResultROIType(this,ROIType)
            %remove ROIType from all subjects
            if(~this.isLoaded)
                this.load();
            end
            for i = 1:this.nrSubjects
                tmp = this.resultROICoordinates{i};
                if(isempty(tmp))
                    continue
                end
                idx = find(abs(tmp(:,1,1) - ROIType) < eps,1,'first');
                if(~isempty(idx))
                    tmp(idx,:,:) = [];
                    this.resultROICoordinates(i) = {tmp};
                end
                %update all existing non default size ROIs
                ndsr = this.nonDefaultSizeROICoordinates{i};
                if(~isempty(ndsr) && iscell(ndsr) && size(ndsr,2) == 2)
                    for j = 1:size(ndsr,1)
                        %loop over non default size data types
                        tmp = ndsr{j,2};
                        idx = find(abs(tmp(:,1,1) - ROIType) < eps,1,'first');
                        if(~isempty(idx))
                            tmp(idx,:,:) = [];
                            ndsr{j,2} = tmp;
                        end
                    end
                    this.nonDefaultSizeROICoordinates{i} = ndsr;
                end
            end
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
            %set the ROI vector for subject
            idx = this.subName2idx(subjectID);
            if(isempty(idx) || isempty(dType) || length(zValues) ~= 3)
                %subject not in study or z values size is wrong
                return
            end
            tmp = this.resultZScaling{idx};
            if(isempty(tmp))
                tmp = cell(0,4);
            end
            idxCh = ch == [tmp{:,1}];
            idxCh = idxCh(:);
            if(~any(idxCh))
                %channel not found
                idxCh(end+1,1) = true;
                tmp{idxCh,1} = ch;
                tmp{idxCh,2} = dType;
                tmp{idxCh,3} = dTypeNr;
            end
            idxType = strcmp(dType,tmp(:,2));
            idxType = idxType(:) & idxCh(:);
            if(~any(idxType))
                %dType not found
                idxCh(end+1,1) = true;
                idxType(end+1,1) = true;
                tmp{idxType,1} = ch;
                tmp{idxType,2} = dType;
                tmp{idxType,3} = dTypeNr;
            end
            idxNr = dTypeNr == [tmp{:,3}];
            idxNr = idxNr(:) & idxType(:) & idxCh(:);
            if(~any(idxNr))
                %dType number not found
                idxNr(end+1,1) = true;
                tmp{idxNr,1} = ch;
                tmp{idxNr,2} = dType;
                tmp{idxNr,3} = dTypeNr;
            end
            tmp{find(idxNr,1),4} = single(zValues);
            this.resultZScaling(idx) = {tmp};
            this.setDirty(true);
            %clean up
            this.clearObjMerged();
            this.clearMVGroups(subjectID,dType,dTypeNr);
        end
        
        function setResultColorScaling(this,subjectID,ch,dType,dTypeNr,colorBorders)
            %set the color scaling at subject subjectID
            if(~this.isLoaded)
                this.load();
            end
            %check if target is a condition
            allConditions = [{FDTree.defaultConditionName()}; this.getDataFromStudyInfo('subjectInfoConditionalColumnNames');];
            idx = strcmp(allConditions,subjectID);
            if(any(idx) || ~isempty(this.getChild(subjectID)))
                %set the color scaling at subject subjectID
                %check if target is a condition
                if(strcmp(subjectID,FDTree.defaultConditionName()))
                    %default condition: all subjects
                    subIdx = 1:this.nrSubjects;
                elseif(any(strcmp(subjectID,this.getDataFromStudyInfo('subjectInfoConditionalColumnNames'))))
                    %specific condition
                    subInfo = this.getSubjectInfo([]);
                    subIdx = find(cell2mat(subInfo(:,this.subjectInfoColumnName2idx(subjectID))));
                else
                    %single subject
                    subIdx = this.subName2idx(subjectID);
                end
                if(isempty(subIdx) || isempty(dType) || length(colorBorders) ~= 3)
                    %subject not in study or color values size is wrong
                    return
                end
                for i = 1:length(subIdx)
                    tmp = this.resultColorScaling{subIdx(i)};
                    if(isempty(tmp))
                        tmp = cell(0,4);
                    end
                    idxCh = ch == [tmp{:,1}];
                    idxCh = idxCh(:);
                    if(~any(idxCh))
                        %channel not found
                        idxCh(end+1,1) = true;
                        tmp{idxCh,1} = ch;
                        tmp{idxCh,2} = dType;
                        tmp{idxCh,3} = dTypeNr;
                    end
                    idxType = strcmp(dType,tmp(:,2));
                    idxType = idxType(:) & idxCh(:);
                    if(~any(idxType))
                        %dType not found
                        idxCh(end+1,1) = true;
                        idxType(end+1,1) = true;
                        tmp{idxType,1} = ch;
                        tmp{idxType,2} = dType;
                        tmp{idxType,3} = dTypeNr;
                    end
                    idxNr = dTypeNr == [tmp{:,3}];
                    idxNr = idxNr(:) & idxType(:) & idxCh(:);
                    if(~any(idxNr))
                        %dType number not found
                        idxNr(end+1,1) = true;
                        tmp{idxNr,1} = ch;
                        tmp{idxNr,2} = dType;
                        tmp{idxNr,3} = dTypeNr;
                    end
                    if(isempty(tmp) || isempty(tmp{find(idxNr,1),4}) || any(tmp{find(idxNr,1),4} ~= colorBorders,'all'))
                        tmp{find(idxNr,1),4} = colorBorders;
                        this.resultColorScaling(subIdx(i)) = {tmp};
                        this.setDirty(true);
                    end
                end
            end
        end
        
        function setResultCrossSection(this,subjectID,dim,csDef)
            %set the cross section for subject subjectID and dimension dim
            if(~this.isLoaded)
                this.load();
            end
            %set the cross section for subject
            idx = this.subName2idx(subjectID);
            if(isempty(idx) || length(csDef) ~= 3)
                %subject not in study or csDef size is wrong
                return
            end
            tmp = this.resultCrossSection{idx};
            switch upper(dim)
                case 'X'
                    tmp(1:3) = csDef;
                case 'Y'
                    tmp(4:6) = csDef;
            end
            this.resultCrossSection(idx) = {tmp};
            this.setDirty(true);
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
            %set selected FLIM parameters for subject
            idx = this.subName2idx(subjectID);
            if(isempty(idx) || ch < 1)
                %subject not in study
                return
            end
            this.allFLIMItems(idx,ch) = {items};
            this.setDirty(true);
        end
        
        function subjectObj = insertSubject(this,subjectID,subInfo)
            %create a new subject and store its subject info
            subjectObj = this.addSubject(subjectID);
            %insert subject data into study info
            %from clipboard or while importing studies            
            subjectPos = this.subName2idx(subjectID);
            this.resultFileChs(subjectPos,1:length(subInfo.resultFileChs)) = subInfo.resultFileChs;
            this.measurementFileChs(subjectPos,1:length(subInfo.measurementFileChs)) = subInfo.measurementFileChs;
            this.allFLIMItems(subjectPos,1:length(subInfo.allFLIMItems)) = subInfo.allFLIMItems;            
            %fill subject info fields with data
            for i = 1:length(subInfo.subjectInfoColumnNames)
                str = subInfo.subjectInfoColumnNames{i,1};
                [~, idx] = ismember(str,this.subjectInfoColumnNames);
                this.subjectInfo(subjectPos,idx) = subInfo.subjectInfo(1,i);
            end
            %update ROICoordinates, if neccessary
            subVec = 1:this.nrSubjects;
            subVec(subjectPos) = [];
            if(~isempty(subVec))
                roiStudy = this.resultROICoordinates{subVec(1)};
                roiSubject = subInfo.resultROICoordinates{1,1};
                if(~isempty(roiStudy) && ~isempty(roiSubject))
                    %check which ROIs are missing in the subject
                    d = setdiff(roiStudy(:,1,1),roiSubject(:,1,1));
                    for i = 1:length(d)
                        [val,idx] = min(abs(roiSubject(:,1,1) - d(i)));
                        if(val > 0)
                            tmpNew = zeros(size(roiSubject,1)+val,size(roiSubject,2),size(roiSubject,3),'int16');
                            tmpNew(1:idx,:,:) = roiSubject(1:idx,:,:);
                            tmpNew(idx+val+1:end,:,:) = roiSubject(idx+1:end,:,:);
                            tmpNew(idx+1:idx+val,1,1) = (roiSubject(idx,1,1)+1 : 1 : roiSubject(idx,1,1)+val)';
                            roiSubject = tmpNew;
                        end
                    end
                    subInfo.resultROICoordinates{1,1} = roiSubject;
                    %check which ROIs are missing in the study
                    d = setdiff(roiSubject(:,1,1),roiStudy(:,1,1));
                    for i = 1:length(d)
                        this.addResultROIType(d(i));
                    end
                end
            end
            this.resultROICoordinates(subjectPos) = subInfo.resultROICoordinates;
            this.resultZScaling(subjectPos) = subInfo.resultZScaling;
            this.resultColorScaling(subjectPos) = subInfo.resultColorScaling;
            this.resultCrossSection(subjectPos) = subInfo.resultCrossSection;
            this.setDirty(true);
        end
        
        function addColumn(this,colName,defaultVal)
            %add new column to study info
            if(~this.isLoaded)
                this.load();
            end
            %insert new column at the end of the table            
            this.subjectInfoColumnNames(end+1,1)= {colName};
            this.subjectInfo(:,end+1)= cell(max(1,size(this.subjectInfo,1)),1);
            this.subjectInfoConditionDefinition(end+1,1) = cell(1,1);
            this.subjectInfoColumnDefaults(end+1,1) = cell(1,1);
            this.setSubjectInfoColumnDefaultValue(colName,defaultVal);
            this.setDirty(true);
        end
        
        function addConditionalColumn(this,val)
            %add new conditional column to study info with definition val
            if(~this.isLoaded)
                this.load();
            end
            %create a new conditional column out of two existing columns
            ref.colA = val.list{val.colA};      %column A
            ref.colB = val.list{val.colB};      %column B
            ref.logOp = val.ops{val.logOp};     %logical operator
            ref.relA = val.ops{val.relA + 6};   %relational operator of colA
            ref.relB = val.ops{val.relB + 6};   %relational operator of colB
            ref.valA = val.valA;                %relation value of colA
            ref.valB = val.valB;                %relation value of colB            
            this.addColumn(val.name,[]);
            %save reference for condition / combination
            n = this.subjectInfoColumnName2idx(val.name);
            this.subjectInfoConditionDefinition{n,1} = ref;
            this.setConditionColor(val.name,[]);
            %update conditions / combinations
            this.checkConditionRef(n);
            this.setDirty(true);
        end
        
        function setConditionalColumnDefinition(this,colName,val)
            %set definition for conditional column
            if(~this.isLoaded)
                this.load();
            end
            n = this.subjectInfoColumnName2idx(colName);
            if(isempty(val))
                %delete condition
                ref = [];
                this.subjectInfo(:,n) = cell(this.nrSubjects,1);
            else
                ref.colA = val.list{val.colA};      %column A
                ref.colB = val.list{val.colB};      %column B
                ref.logOp = val.ops{val.logOp};     %logical operator
                ref.relA = val.ops{val.relA + 6};   %relational operator of colA
                ref.relB = val.ops{val.relB + 6};   %relational operator of colB
                ref.valA = val.valA;                %relation value of colA
                ref.valB = val.valB;                %relation value of colB
            end
            %save new reference for condition / combination
            this.subjectInfoConditionDefinition{n,1} = ref;            
            %update conditions / combinations
            this.checkConditionRef([]);
            this.setDirty(true);
        end
        
        function setSubjectInfoColumnDefaultValue(this,colName,val)
            %set default value for a regular column
            if(~this.isLoaded)
                this.load();
            end
            n = this.subjectInfoColumnName2idx(colName);
            %save new reference for condition / combination
            this.subjectInfoColumnDefaults{n,1} = val;
            %write default value to all subjects of than column
            if(~isempty(val) && this.nrSubjects > 0)
                if(isnumeric(val))
                    this.subjectInfo(:,n) = num2cell(repmat(val,this.nrSubjects,1));
                else
                    this.subjectInfo(:,n) = repmat({val},this.nrSubjects,1);               
                end
            end
            this.setDirty(true);
        end
        
        function setSubjectInfoColumnName(this,newColumnName,idx)
            %give column at idx a new name
            if(~this.isLoaded)
                this.load();
            end
            %check if idx is a conditional column
            conditions = this.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
            allColumnNames = this.getDataFromStudyInfo('subjectInfoAllColumnNames');
            colName = allColumnNames{idx};
            if(ismember(colName,conditions))
                condition = this.getConditionObj(colName);
                if(~isempty(condition))
                    %we have this condition in FDtree, change name of condition
                    condition.setSubjectName(newColumnName);
                end
            end
            %set column name in study info data
            %give column at idx a new name
            if(isempty(idx))
                %set all subjectInfoColumnNames (initial case)
                this.subjectInfoColumnNames = newColumnName;
            else
                %set a single subjectInfoHeader
                oldName = this.subjectInfoColumnNames{idx,1};
                %check if renamed colum is a reference for a conditional column
                for i=1:length(this.subjectInfoColumnNames)
                    ref = this.subjectInfoConditionDefinition{i,1};
                    if(isempty(ref))
                        %column is not a conditional column
                        continue
                    end
                    if(strcmp(ref.colA,oldName))
                        %reference found
                        ref.colA = newColumnName;
                        this.subjectInfoConditionDefinition{i,1} = ref;
                    end
                    if(strcmp(ref.colB,oldName))
                        %reference found
                        ref.colB = newColumnName;
                        this.subjectInfoConditionDefinition{i,1} = ref;
                    end
                end
                %set new column name
                this.subjectInfoColumnNames{idx,1} = newColumnName;
                this.setDirty(true);
            end
        end
        
        function setSubjectInfo(this,irow,icol,newData)
            %set data in subject info at specific row and column
            if(~this.isLoaded)
                this.load();
            end
            %set data in subject info at specific row and column
            idx = find(~cellfun(@isempty,this.subjectInfo(:,icol)));
            if(isempty(idx) && (~isnumeric(newData) && all(isstrprop(newData,'digit')) || ischar(newData) && length(newData) >= 2 && strcmp(newData(1),'-') && all(isstrprop(newData(2:end),'digit'))))
                %the subject info column is empty and the data seems to be numeric -> convert it
                newData = str2double(newData);
            elseif(~isempty(idx) && ~isnumeric(newData) && isnumeric(this.subjectInfo{idx(1),icol}))
                %there is old data, which is numeric -> also convert the new data (if this is a string it will become NaN)
                newData = str2double(newData);
            end
            this.subjectInfo(irow,icol) = {newData};
            this.checkConditionRef([]);
            this.setDirty(true);
        end
        
        function setSubjectInfoConditionalColumnDefinition(this,def,idx)
            %set definition def of a conditional column with the index idx
            if(~this.isLoaded)
                this.load();
            end
            %set definition def of a conditional column with the index idx
            if(idx <= size(this.subjectInfoConditionDefinition,1))
                %set single definition
                this.subjectInfoConditionDefinition(idx,1) = def;
                this.setDirty(true);
            end
        end
        
        function importStudyInfo(this,file,mode)
            %import study info (subject info table) from excel file, mode 1: delete all old, mode 2: update old & add new
            if(~this.isLoaded)
                this.load();
            end
            %check file
            [~,~,ext] = fileparts(file);
            if(~(strcmp(ext,'.xls') || strcmp(ext,'.xlsx')) || isempty(dir(file)))
                %file not found
                return
            end
            typ = xlsfinfo(file);
            if(isempty(typ))
                %no excel file
                errordlg('This is not an Excel file!','No Excel file','modal')
                return;
            end
            desc = sheetnames(file);
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
            newSubs = setdiff(xlsSubs,this.getAllSubjectNames(FDTree.defaultConditionName()));
            %add new subjects
            for i=1:length(newSubs)
                this.addSubject(newSubs{i});
            end
            %import study info (subject info table) from excel file, mode 1: delete all old, mode 2: update old & add new
            %get subject and header names
            xlsSubs = raw(2:end,1);
            %make sure we have only strings as subjects
            idx = cellfun(@ischar,xlsSubs);
            xlsSubs = xlsSubs(idx);
            %make sure we have only strings as headers
            xlsHeads = raw(1,2:end);
            idx = cellfun(@ischar,xlsHeads);
            xlsHeads = xlsHeads(idx);
            xlsFile = raw(1,1);
            if(~ischar(xlsFile{1,1}))
                xlsFile = {'File'};
            end
            switch mode
                case 1 %Delete Old Info
                    this.subjectInfoColumnNames = xlsHeads;
                    this.subjectInfo = cell(0,0);
                    this.subjectInfoConditionDefinition = cell(size(this.subjectInfoColumnNames));
                    this.subjectInfoColumnDefaults = cell(size(this.subjectInfoColumnNames));
                case 2 %Update and Add New
                    %remove existing conditional columns from import
                    for i = length(xlsHeads):-1:1
                        if(~isempty(this.getConditionalColumnDefinition(this.subjectInfoColumnName2idx(xlsHeads{i}))))
                            xlsHeads(i) = [];
                        end
                    end
                    %determine already existing info headers
                    newHeads = setdiff(xlsHeads,this.subjectInfoColumnNames);
                    diff = length(newHeads);
                    if(diff > 0) %add new info columns
                        this.subjectInfoColumnNames(end+1:end+diff,1) = cell(diff,1);
                        this.subjectInfo(:,end+1:end+diff) = cell(size(this.subjectInfo,1),diff);
                        this.subjectInfoConditionDefinition(end+1:end+diff,1) = cell(diff,1);
                        this.subjectInfoColumnDefaults(end+1:end+diff,1) = cell(diff,1);
                    end
                    %add new info headers
                    this.subjectInfoColumnNames(end+1-diff:end,1) = newHeads;
            end
            %update existing subjects and add new info
            for i = 1:length(this.subjectNames)
                idxXls = find(strcmp(this.subjectNames{i},xlsSubs),1);
                if(~isempty(idxXls)) %should not be empty...
                    if(size(this.subjectInfo,2) < length(this.subjectInfoColumnNames))
                        diff = length(this.subjectInfoColumnNames) - size(this.subjectInfo,2);
                        this.subjectInfo(:,end+1:end+diff) = cell(size(this.subjectInfo,1),diff);
                    elseif(size(this.subjectInfo,2) > length(this.subjectInfoColumnNames)) %should not happen
                        this.subjectInfo = this.subjectInfo(:,1:length(this.subjectInfoColumnNames));
                    end
                    %this.subjectInfo(i,:) = cell(1,length(this.subjectInfoColumnNames));
                    %add info data for specific subject
                    for j = 1:length(xlsHeads)
                        idxHeadThis = find(strcmp(xlsHeads{j},this.subjectInfoColumnNames),1);
                        idxHeadImport = find(strcmp(xlsHeads{j},raw(1,:)),1);
                        this.subjectInfo(i,idxHeadThis) = raw(idxXls+1,idxHeadImport);
                    end
                end
            end
            this = FDTStudy.checkStudyConsistency(this);
            this.sortSubjects();
            this.checkConditionRef([]); %update conditional columns
            this.setDirty(true);
        end
        
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
            if(~this.isLoaded)
                return
            end
            subStr = this.getAllSubjectNames(FDTree.defaultConditionName());
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
        
        function setArithmeticImageDefinition(this,aiName,aiParam)
            %set name and definition of arithmetic image for a study
            this.clearArithmeticRIs();
            if(~this.isLoaded)
                this.load();
            end
            %set arithmetic image info
            if(isempty(aiName))
                return
            end
            idx = find(strcmp(aiName,this.arithmeticImageInfo(:,1)));
            if(isempty(idx))
                %new image
                if(isempty(this.arithmeticImageInfo) || isempty(this.arithmeticImageInfo{1,1}))
                    %first arithmetic image for this study
                    this.arithmeticImageInfo(1,1) = {aiName};
                    this.arithmeticImageInfo(1,2) = {aiParam};
                else
                    this.arithmeticImageInfo(end+1,1) = {aiName};
                    this.arithmeticImageInfo(end,2) = {aiParam};
                end
            else
                this.arithmeticImageInfo(idx,2) = {aiParam};
            end
            this.setDirty(true);
        end
        
        function setConditionColor(this,cName,val)
            %set condition color
            if(~this.isLoaded)
                this.load();
            end
            %set condition color
            if(isempty(val) || length(val) ~= 3)
                val = FDTStudy.makeRndColor();
            end
            if(strcmp(cName,FDTree.defaultConditionName()))
                this.conditionColors(2,1) = {val};
            else
                idx = find(strcmp(cName,this.conditionColors(1,:)), 1);
                if(isempty(idx))
                    this.conditionColors(1,end+1) = {cName};
                    this.conditionColors(2,end) = {val};
                else
                    this.conditionColors(2,idx) = {val};
                end
            end
            this.setDirty(true);
        end
        
        %% removing functions
        function removeArithmeticImageDefinition(this,aiName)
            %remove arithmetic image for a study
            if(~this.isLoaded)
                this.load();
            end
            idx = find(strcmp(aiName,this.arithmeticImageInfo(:,1)));
            if(~isempty(idx))
                this.arithmeticImageInfo(idx,:) = [];
                if(isempty(this.arithmeticImageInfo))
                    this.arithmeticImageInfo = cell(1,2);
                end
                this.setDirty(true);
            end
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
                    this.removeSubjectResult(subjectID);
                    this.clearObjMerged(ch);
                end
            end
        end
        
        function removeSubject(this,subjectID)
            %remove a subject
            if(~this.isLoaded)
                this.load();
            end
            [subject, subjectPos] = this.getChild(subjectID);
            if(~isempty(subject))
                subject.delete();
                this.deleteChildByPos(subjectPos);
                %remove subject subjectID from this study
                idx = this.subName2idx(subjectID);
                if(isempty(idx))
                    %subject not in study
                    return
                end
                if(length(this.subjectNames) > 1)
                    %remove arbitrary subject
                    this.resultFileChs(idx,:) = [];
                    this.measurementFileChs(idx,:) = [];
                    this.resultROICoordinates(idx) = [];
                    this.nonDefaultSizeROICoordinates(idx) = [];
                    this.resultZScaling(idx) = [];
                    this.resultColorScaling(idx) = [];
                    this.resultCrossSection(idx) = [];
                    this.subjectNames(idx) = [];
                    this.subjectInfo(idx,:) = [];
                    this.allFLIMItems(idx,:) = [];
                else
                    %remove last subject
                    this.resultFileChs = cell(0,0);
                    this.measurementFileChs = cell(0,0);
                    this.resultROICoordinates = cell(0,0);
                    this.nonDefaultSizeROICoordinates = cell(0,0);
                    this.resultZScaling = cell(0,0);
                    this.resultColorScaling = cell(0,0);
                    this.resultCrossSection = cell(0,0);
                    this.subjectNames = cell(0,0);
                    this.subjectInfo = cell(0,0);
                    this.allFLIMItems = cell(0,0);
                end
                this.setDirty(true);
                %clean up
                this.clearObjMerged();
            end
            %new
            this.clearSubjectFiles(subjectID);
        end
        
        function removeMVGroup(this,MVGroupID)
            %remove MVGroup and corresponding objects            
            if(~this.isLoaded)
                this.load();
            end
            %delete local MVGroup objects
            subStr = this.getAllSubjectNames(FDTree.defaultConditionName());
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
            conditionStr = this.getDataFromStudyInfo('subjectInfoConditionalColumnNames');
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
            %delete MVGroup parameter in study info
            MVGroupNr = this.MVGroupName2idx(MVGroupID);
            this.MVGroupTargets(:,MVGroupNr) = [];
            %delete saved ROIs
            for i = 1:this.nrSubjects
                tmp = this.nonDefaultSizeROICoordinates{i};
                idx = find(strcmp(MVGroupID,tmp(:,1)),1);
                if(~isempty(idx))
                    tmp(idx,:) = [];
                    if(isempty(tmp))
                        tmp = cell(1,1);
                    end
                end
                this.nonDefaultSizeROICoordinates{i} = tmp;
            end
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
                    subStr = this.getAllSubjectNames(this.myConditionStatistics.getDataByPos(i).name);
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
                curGS = subject.getDefaultSizeFlag(dType);
                for i = 1:length(MVGroupStr)
                    cMVs = this.getMVGroupTargets(MVGroupStr{i});
                    cDType = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                    cGS = subject.getDefaultSizeFlag(cDType{1});
                    tmp = sprintf('%s %d',dType,dTypeNr);
                    if(ismember(tmp,cMVs.x) || ismember(tmp,cMVs.y) || curGS && cGS)
                        %clear local MVGroups
                        subject.clearAllRIs(MVGroupStr{i})
                        %clear condition MVGroups
                        for j = 1:this.myConditionStatistics.queueLen
                            subStr = this.getAllSubjectNames(this.myConditionStatistics.getDataByPos(j).name);
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
            cond = this.getColumnDependencies(colName);
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
            %delete column in table study data
            col = this.subjectInfoColumnName2idx(colName);
            if(isempty(this.subjectInfo))
                %special case: first header has to be deleted when
                %importing study
                this.subjectInfoColumnNames(col,:) = [];
            else
                this.subjectInfoColumnNames(col,:) = [];
                this.subjectInfo(:,col) = [];
                this.subjectInfoConditionDefinition(col,:) = [];
                this.subjectInfoColumnDefaults(col,:) = [];
                idx = find(strcmp(colName,this.conditionColors(1,:)), 1);
                if(~isempty(idx))
                    this.conditionColors(:,idx) = [];
                end
            end
            this.setDirty(true);
        end
        
        %% output functions
        function save(this)
            %save current study data to disk
            if(~this.isDirty || isMultipleCall())
                return
            end
            export = this.makeExportStruct([]);
            export.name = this.name;
            export.revision = this.revision;
            matFile = fullfile(this.myDir,'studyData.mat');
            bakFile = fullfile(this.myDir,'studyData.bak');
            if(~isempty(this.hashEngine))
                this.hashEngine.reset();
                this.hashEngine.update(getByteStreamFromArray(export));
                checksum = typecast(this.hashEngine.digest, 'uint8');
            else
                checksum = [];
            end
            %try to rename old file
            if(~isempty(dir(bakFile)))
                try
                    delete(bakFile);
                catch ME
                end
            end
            if(~isempty(dir(matFile)))
                [renameStatus,renameMsg,renameMsgID] = movefile(matFile,bakFile);
                if(~renameStatus)
                    warning('Warning: Unable to rename %s to file %s', matFile,bakFile);
                    %delete(fileMat);
                end
            end
            save(matFile,'export','checksum');
            %remove unnecessary files
            this.dirtyFlag = false;
            if(this.isDirty)
                %there are changes in subjects -> save them
                for i = 1:this.nrChildren
                    subject = this.getChildAtPos(i);
                    if(subject.isDirty)
                        subject.saveMatFile2Disk([]);
                    end
                end
            end
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
            else
                out = subject.getFDataObj(chan,dType,id,sType);
            end
        end
        
        function out = isArithmeticImage(this,dType)
            %return true, if dType is an arithmetic image
            aiNames = this.getArithmeticImageDefinition();
            idx = strcmp(dType,aiNames);
            out = sum(idx) == 1;
        end
        
        function out = arithmeticImagesRequiredFor(this,aiNameTarget)
            %return list of arithmetic images, which are needed to compute aiNameTarget
            out = cell(0,0);
            if(~this.isArithmeticImage(aiNameTarget))
                return
            end
            [allAiNames, aiParams] = this.getArithmeticImageDefinition();
            idx = strcmp(aiNameTarget,allAiNames);
            aiParams = aiParams{idx};
            if(this.isArithmeticImage(aiParams.FLIMItemA))
                out = union(aiParams.FLIMItemA,this.arithmeticImagesRequiredFor(aiParams.FLIMItemA));
            end
            if(strcmp(aiParams.compAgainstB,'FLIMItem') && ~strcmp(aiParams.opA,'-no op-') && this.isArithmeticImage(aiParams.FLIMItemB))
                %check FLIMItemC
                out = union(aiParams.FLIMItemB,out);
                out = union(out,this.arithmeticImagesRequiredFor(aiParams.FLIMItemB));
            elseif(strcmp(aiParams.compAgainstC,'FLIMItem') && ~strcmp(aiParams.opB,'-no op-') && ~strcmp(aiParams.FLIMItemC,aiNameTarget))
                %check FLIMItemC
                out = union(aiParams.FLIMItemC,out);
                out = union(out,this.arithmeticImagesRequiredFor(aiParams.FLIMItemC));
            end
            out = unique(out);
        end
        
        function out = arithmeticImagesDependingOn(this,aiNameUT,aiNameTarget)
            %return list of arithmetic images from aiNameUT (under test; if empty, test all arithmetic images), which depend on aiNameTarget (= which need aiNameTarget to be computed)
            out = cell(0,0);
            if(~isempty(aiNameUT) && ~this.isArithmeticImage(aiNameUT) || ~this.isArithmeticImage(aiNameTarget))
                return
            end
            [allAiNames, allAiParams] = this.getArithmeticImageDefinition();
            if(~isempty(aiNameUT))
                %investigate only specific ai
                idx = strcmp(aiNameUT,allAiNames);
                allAiNames = allAiNames(idx);
                allAiParams = allAiParams(idx);
            end            
            %find direct hits
            for i = 1:length(allAiNames)
                p = allAiParams{i};
                if(strcmp(p.FLIMItemA,aiNameTarget) || strcmp(p.compAgainstB,'FLIMItem') && ~strcmp(p.opA,'-no op-') && strcmp(p.FLIMItemB,aiNameTarget) ||...
                        strcmp(p.compAgainstC,'FLIMItem') && ~strcmp(p.opB,'-no op-') && strcmp(p.FLIMItemC,aiNameTarget))
                    out(end+1,1) = allAiNames(i);
                    continue
                end
            end
            out = unique(out);
            if(isempty(out))
                return
            end
            %check indirect hits
            while true
                indirectHitFound = false;
                for i = 1:length(allAiNames)
                    tmp = this.arithmeticImagesRequiredFor(allAiNames(i));
                    if(any(ismember(tmp,out)) && ~any(ismember(allAiNames(i),out)))
                        out(end+1,1) = allAiNames(i);
                        indirectHitFound = true;
                    end
                end
                if(~indirectHitFound)
                    break
                end
            end
        end
        
        function out = getSubject4Approx(this,subjectID,createNewSubjectFlag)
            %get subject object which includes measurements and results
            if(~this.isLoaded)
                this.load();
            end
            if(~ischar(subjectID))
                subjectID = this.idx2SubName(subjectID);
            end
            out = this.getChild(subjectID);
            if(isempty(out) && createNewSubjectFlag)
                out = this.addSubject(subjectID);
            elseif(isempty(out) && ~createNewSubjectFlag)
                out = [];
            end
        end
        
        function out = getSubject4Import(this,subjectID)
            %get subject object to import measurements or results
            if(~this.isLoaded)
                this.load();
            end
            if(~ischar(subjectID))
                subjectID = this.idx2SubName(subjectID);
            end
            out = subject4Import(this,subjectID);
        end
        
        function [resultObj, isBH, chNrs] = getResultObj(this,subjectID,chan)
            %get fluoDecayFitResult object, chan = [] loads all channels
            if(~this.isLoaded)
                this.load();
            end
            %get all FLIM data for subject subjectID
            resultObj = []; isBH = false;
            chNrs = cell2mat(this.getResultFileChs(subjectID));
            if(isempty(chan) && ~isempty(chNrs))
                chan = chNrs;
            elseif(~any(chNrs == chan) || (isempty(chan) && isempty(chNrs)))
                %channel not found
                return
            end
            if(~ischar(subjectID))
                subjectID = this.idx2SubName(subjectID);
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
                subjectNames = this.getAllSubjectNames(cName);
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
                    condition = FDTSubject(this,cName);
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
            nr = this.subName2idx(subjectID);
        end
        
        function [measurementChs, resultChs, position, resolution] = getSubjectFilesStatus(this,subjectID)
            %returns which channels are available for a subject in a study            
            subject = this.getChild(subjectID);
            if(isempty(subject))
                measurementChs = []; resultChs = []; position = []; resolution = [];
            else
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
            %get multivariate targets of a MVGroup
            MVGroupNr = this.MVGroupName2idx(MVGroupID);
            if(isempty(MVGroupNr))
                out = [];
                return
            end
            targets = this.MVGroupTargets{2,MVGroupNr};
            if(isempty(targets))
                %no targets
                out = cell(0,0);
            else
                out = targets;
            end
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
                idx = this.subjectInfoColumnName2idx(cName);
                si = this.getSubjectInfo([]);
                col = cell2mat(si(:,idx));
                nr = sum(col);
            end
        end
        
        function dStr = getAllSubjectNames(this,cName)
            %get a string of all subjects in the study
            if(~this.isLoaded)
                this.load();
            end
            dStr = this.getNamesOfAllChildren();%cell(0,0);
            if(strcmp(cName,FDTree.defaultConditionName()))
                %no condition selected, show all subjects
                return
            end
            %show only subjects which fulfill the conditional column
            idx = this.subjectInfoColumnName2idx(cName);
            si = this.getSubjectInfo([]);
            col = cell2mat(si(:,idx));
            dStr = dStr(col);
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
            else
                str = subject.getChObjStr(ch);
                MVGroupNames = this.getMVGroupNames(1);
                idx = strncmp('MVGroup_',MVGroupNames,8);
                if(~isempty(idx))
                    MVGroupNames = MVGroupNames(idx);
                end
                str = unique([str; MVGroupNames]);
            end            
        end
        
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
            if(any(strcmp(dataProc,{'mean','median'})))
                data = zeros(length(hg),1);
            else
                %ne pre-allocation for raw data export
                data = [];
            end
            for i = 1:length(hg)
                %tmp = hg{i}.getFullImage();
                ROICoordinates = this.getResultROICoordinates(hg{i}.subjectName,dType,ROIType);
                if(isempty(ROICoordinates))
                    ROICoordinates = [hg{i}.rawImgYSz; hg{i}.rawImgXSz];
                end
                tmp = hg{i}.getImgSeg(hg{i}.getFullImage(),ROICoordinates,ROIType,ROISubType,ROIVicinity,hg{i}.getFileInfoStruct(),this.getVicinityInfo());
                switch dataProc
                    case 'mean'
                        data(i) = mean(tmp(~isinf(tmp)),'omitnan'); %tmp(~isnan(tmp) & ~isinf(tmp))
                    case 'median'
                        data(i) = median(tmp(~isinf(tmp)),'omitnan'); %tmp(~isnan(tmp) & ~isinf(tmp))
                    otherwise
                        data = [data; tmp(:)];
                end
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
                    ROICoordinates = this.getResultROICoordinates(hg{1}.subjectName,dType,ROIType);
                    [~, histMerge, centers] = hg{1}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
                    histTable = zeros(length(hg),length(centers));
                    colDescription = cell(length(hg),1);
                    for i = 1:length(hg)
                        %just make sure that histograms correspond to subject names
                        %c = hg{i}.getCIHistCentersStrict();
                        colDescription(i) = {hg{i}.subjectName};
                        ROICoordinates = this.getResultROICoordinates(colDescription{i},dType,ROIType);
                        [~, histTemp, cTemp]= hg{i}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,true);
                        if(isempty(cTemp))
                            continue
                        end
                        if(isempty(centers))
                            centers = cTemp;
                            histTable(i,1:length(histTemp)) = histTemp;
                        else
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
            stats = NaN(nSubs,length(statsDesc));
            subjectDesc = cell(nSubs,1);
            for i = 1:nSubs
                subjectDesc(i) = {hg{i}.subjectName};
                ROICoordinates = this.getResultROICoordinates(subjectDesc{i},dType,ROIType);
%                 if(ROIType < 0)
%                     %ROI group
%                     [tmp, ~, ~] = hg{i}.makeROIGroupStatistics(ROIType,ROISubType,ROIVicinity,strictFlag);
%                 else
                    if(ROIType > 0 && ~any(ROICoordinates(:)))
                        tmp = NaN;
                    else
                        tmp = hg{i}.makeStatistics(ROICoordinates,ROIType,ROISubType,ROIVicinity,strictFlag);                        
                    end
%                 end 
                if(~isempty(tmp))
                    stats(i,:) = tmp;
                end
            end
        end
        
        function items = getAllFLIMItems(this,subjectID,ch)
            %return all FLIM items (FDTChunk names) of a specific subject or the whole study
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                %get FLIM parameters for all subjects
                items = this.allFLIMItems;
            else
                %get FLIM parameters for subject subjectID
                idx = this.subName2idx(subjectID);
                if(isempty(idx) || ch < 1 || ch > size(this.resultFileChs,2))
                    %subject not in study or channel not valid
                    items = [];
                    return
                end
                items = this.allFLIMItems{idx,ch};
            end
        end
        
        function out = getMVGroupNames(this,mode)
            %get list of MVGroups in study
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            if(~this.isLoaded)
                this.load();
            end
            out = cell(0,0);
            if(isempty(this.MVGroupTargets))
                return
            end            
            MVGroupStr = this.MVGroupTargets(1,:);
            MVGroupT = this.MVGroupTargets(2,:);
            if(mode == 0)
                out = MVGroupStr;
                return
            end            
            %get only computable MVGroups
            for i = 1:length(MVGroupStr)
                if(isempty(MVGroupT{i}.x) || isempty(MVGroupT{i}.y) && ~all(ismember(MVGroupT{i}.x,MVGroupStr)))
                    continue
                end
                out(end+1,1) = MVGroupStr(i);
            end
        end
        
        function out = getConditionalColumnDefinition(this,colName)
            %return definition of a conditional column with index idx
            if(~this.isLoaded)
                this.load();
            end
            n = this.subjectInfoColumnName2idx(colName);
            if(~isempty(n) && ~isempty(this.subjectInfoColumnNames) && length(this.subjectInfoConditionDefinition) >= n)
                out = this.subjectInfoConditionDefinition{n,1};
            else
                out = [];
            end
        end
        
        function out = getSubjectInfoColumnDefaultValue(this,colName)
            %return default value for a regular column with index idx
            if(~this.isLoaded)
                this.load();
            end
            n = this.subjectInfoColumnName2idx(colName);
            if(~isempty(n) && ~isempty(this.subjectInfoColumnNames) && length(this.subjectInfoColumnDefaults) >= n)
                out = this.subjectInfoColumnDefaults{n,1};
            else
                out = [];
            end
        end
                
        function out = getSubjectInfo(this,subjectID)
            %return the data of all columns in subject info
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                out = this.subjectInfo;
            else
                if(~isempty(this.subjectInfo))
                    %todo: check if subjectID is valid!
                    out = this.subjectInfo(subjectID,:);
                end
            end
        end
        
        function out = getSubjectInfoConditionalColumnDefinitions(this)
            %return definitions of all conditional columns in subject info
            if(~this.isLoaded)
                this.load();
            end
            out = this.subjectInfoConditionDefinition;
        end
        
        function out = getResultROIGroup(this,grpName)
            %return the ROI group names and members for this study 
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(grpName))
                out = this.resultROIGroups;
            else
                idx = find(strcmp(this.resultROIGroups(:,1),grpName),1,'first');
                if(isempty(idx))
                    out = [];
                else
                    out = this.resultROIGroups(idx,2);
                end
            end
        end
        
        function [ids, str] = getResultROITypes(this)
            %return the different ROI types for a study
            if(~this.isLoaded)
                this.load();
            end
            idx = find(~cellfun(@isempty,this.resultROICoordinates),1,'first');
            if(isempty(idx))
                allROT = ROICtrl.getDefaultROIStruct();
                ids = allROT(:,1,1);
                str = arrayfun(@ROICtrl.ROIType2ROIItem,ids,'UniformOutput',false);
            else
                ids = this.resultROICoordinates{idx,1}(:,1,1);
                str = arrayfun(@ROICtrl.ROIType2ROIItem,ids,'UniformOutput',false);
            end
        end
        
        function out = getResultROICoordinates(this,subjectID,dType,ROIType)
            %return ROI coordinates for ROIType in a subject
            if(~this.isLoaded)
                this.load();
            end
            subject = this.getChild(subjectID);
            if(isempty(subject))
                return
            end
            if(isempty(ROIType) || subject.getDefaultSizeFlag(dType))
                %return ROI coordinates for specific subject and ROI type
                if(isempty(subjectID))
                    out = this.resultROICoordinates;
                else
                    if(~isnumeric(subjectID))
                        subjectID = this.subName2idx(subjectID);
                        if(isempty(subjectID))
                            out = [];
                            return
                        end
                    end
                    %out = double(cell2mat(this.resultROICoordinates(subjectID)));
                    out = FDTChunk.extractROICoordinates(cell2mat(this.resultROICoordinates(subjectID)),ROIType);
                    %                 if(~isempty(out) && ~isempty(ROIType) && isscalar(ROIType) && ROIType > 1000)
                    %                     idx = find(abs(out(:,1,1) - ROIType) < eps,1,'first');
                    %                     if(~isempty(idx))
                    %                         out = squeeze(out(idx,:,:))';
                    %                         out = out(1:2,2:end);
                    %                         if(ROIType < 4000)
                    %                             out = out(1:2,1:2);
                    %                         elseif(ROIType > 4000 && ROIType < 5000)
                    %                             %remove potential trailing zeros
                    %                             idx = any(out,1);
                    %                             idx(1:3) = true;
                    %                             out(:,find(idx,1,'last')+1:end) = [];
                    %                         end
                    %                     else
                    %                         out = [];
                    %                     end
                    %                 elseif(isempty(ROIType))
                    %                     %return all ROI coordinates
                    %                 else
                    %                     out = [];
                    %                 end
                end
            else
                %this FLIM item (chunk) has a different size than the subject
                if(isempty(subjectID))
                    out = this.nonDefaultSizeROICoordinates;
                else
                    out = [];
                    if(~isnumeric(subjectID))
                        subjectID = this.subName2idx(subjectID);
                        if(isempty(subjectID))
                            return
                        end
                    end
                    tmp = this.nonDefaultSizeROICoordinates{subjectID};
                    if(isempty(tmp))
                        return
                    end
                    idx = find(strcmp(dType,tmp(:,1)),1);
                    if(isempty(idx))
                        %dType not found
                        return
                    end
                    out = FDTChunk.extractROICoordinates(cell2mat(tmp(idx,2)),ROIType);
                end
                %out = subject.getROICoordinates(dType,ROIType);
            end
        end
        
        function out = getResultZScaling(this,subjectID,ch,dType,dTypeNr)
            %return z scaling values for specific subject and data type
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                out = this.resultZScaling;
            else
                if(~isnumeric(subjectID))
                    subjectID = this.subName2idx(subjectID);
                    if(isempty(subjectID))
                        out = [];
                        return
                    end
                end
                out = [];
                tmp = this.resultZScaling{subjectID};
                if(isempty(tmp))
                    return
                end
                idxCh = ch == [tmp{:,1}];
                if(~any(idxCh))
                    %channel number not found
                    return
                end
                idxType = strcmp(dType,tmp(:,2));
                idxType = idxType(:) & idxCh(:);
                if(~any(idxType))
                    %dType not found
                    return
                end
                idxNr = dTypeNr == [tmp{:,3}];
                idxNr = idxNr(:) & idxType(:) & idxCh(:);
                if(~any(idxNr))
                    %dType number not found
                    return
                end
                out = tmp{find(idxNr,1),4};
            end
        end
        
        function out = getResultColorScaling(this,subjectID,ch,dType,dTypeNr)
            %return color scaling values for specific subject and data type
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                out = this.resultColorScaling;
            else
                if(~isnumeric(subjectID))
                    subjectID = this.subName2idx(subjectID);
                    if(isempty(subjectID))
                        out = [];
                        return
                    end
                end
                out = [];
                tmp = this.resultColorScaling{subjectID};
                if(isempty(tmp))
                    return
                end
                idxCh = ch == [tmp{:,1}];
                if(~any(idxCh))
                    %channel number not found
                    return
                end
                idxType = strcmp(dType,tmp(:,2));
                idxType = idxType(:) & idxCh(:);
                if(~any(idxType))
                    %dType not found
                    return
                end
                idxNr = dTypeNr == [tmp{:,3}];
                idxNr = idxNr(:) & idxType(:) & idxCh(:);
                if(~any(idxNr))
                    %dType number not found
                    return
                end
                out = tmp{find(idxNr,1),4};
            end
        end
                
        function out = getResultCrossSection(this,subjectID)
            %return cross section defintion for subject
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                out = this.resultCrossSection;
            else
                if(~isnumeric(subjectID))
                    subjectID = this.subName2idx(subjectID);
                    if(isempty(subjectID))
                        out = [];
                        return
                    end
                end
                out = cell2mat(this.resultCrossSection(subjectID));
            end
        end
        
        function data = makeInfoSetExportStruct(this,subjectID)
            %create a struct, which contains all the study info
            if(~this.isLoaded)
                this.load();
            end
            data = this.makeExportStruct(subjectID);
        end
        
        function idx = subjectInfoColumnName2idx(this,columnName)
            %get the index of a subject info column or check if index is valid
            if(~this.isLoaded)
                this.load();
            end
            idx = [];
            if(ischar(columnName))
                idx = find(strcmp(columnName,this.subjectInfoColumnNames),1);
            elseif(isnumeric(columnName))
                if(columnName <= length(this.subjectInfoColumnNames))
                    idx = columnName;
                end
            end
        end
        
        function data = getSubjectFilesData(this)
            %return a cell with subject names, their measurement and result channels
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
        
        function exportStudyInfo(this,file)
            %export study info (subject info table) to excel file
            if(~this.isLoaded)
                this.load();
            end
            %export study info (subject info table) to excel file
            if(isfile(file))
                [~, desc] = xlsfinfo(file);
                idx = find(strcmp('Subjectinfo',desc),1);
                if(~isempty(idx))
                    %spreadsheet is already in the selected file
                    [~, ~, raw] = xlsread(file,'Subjectinfo');
                    if(size(raw,1)>(size(this.subjectInfo,1)+1))...
                            ||(size(raw,2)>(size(this.subjectInfo,2)+1))
                        %delete old data in the spreadsheet
                        ex = cell(size(raw));
                    end
                end
            end
            %Get Subjects
            ex(1,1) = this.filesHeaders(1,1);
            if(size(this.subjectNames,1)<size(this.subjectNames,2))
                %check dimension
                ex(2:size(this.subjectNames,2)+1,1) = this.subjectNames(1,:)';
            else
                ex(2:size(this.subjectNames,1)+1,1) = this.subjectNames(:,1);
            end
            %Get Subject Info
            ex(1,2:length(this.subjectInfoColumnNames)+1) = this.subjectInfoColumnNames;
            ex(2:size(this.subjectInfo,1)+1,2:length(this.subjectInfoColumnNames)+1) = this.subjectInfo;
            %Save to file
            exportExcel(file,ex,'','','Subjectinfo','');
        end
        
        function out = getAllIRFInfo(this)
            %returns the IRFInfo struct
            if(~this.isLoaded)
                this.load();
            end
            out = this.IRFInfo;
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
        
        function [aiNames, aiParams] = getArithmeticImageDefinition(this)
            %get names and definitions of arithmetic images for a study
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(this.arithmeticImageInfo) || isempty(this.arithmeticImageInfo{1,1}))
                aiNames = {''}; 
                aiParams = {''};
                return
            end
            aiNames = this.arithmeticImageInfo(:,1);
            aiParams = this.arithmeticImageInfo(:,2);
        end
        
        function out = getConditionColor(this,cName)
            %returns study condition color
            if(~this.isLoaded)
                this.load();
            end
            if(strcmp(cName,FDTree.defaultConditionName()))
                idx = 1;
            else
                idx = find(strcmp(cName,this.conditionColors(1,:)), 1);
            end
            if(isempty(idx)) %we don't know that condition
                out = FDTStudy.makeRndColor();
            else
                out = this.conditionColors{2,idx};
            end
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
        
        function out = getWorkingDirectory(this)
            %return this studies working directory
            out = this.myDir;
        end
        
        function out = getDataFromStudyInfo(this,descriptor,subjectID,colName)
            %get data from study info defined by descriptor
            if(~this.isLoaded)
                this.load();
            end
            switch descriptor
                case 'subjectInfoData'
                    out = this.subjectInfo;
                    if(nargin >= 3)
                        %return subject info only for specific subject
                        idx = this.subName2idx(subjectID);
                        if(isempty(idx))
                            %subject does not exist
                            out = [];
                            return
                        else
                            out = out(idx,:);
                        end
                    end
                    if(nargin == 4)
                        %return subject info only for specific column
                        idx = this.subjectInfoColumnName2idx(colName);
                        if(isempty(idx))
                            %column does not exist
                            out = [];
                            return
                        else
                            out = out{1,idx};
                        end
                    end
                case 'resultFileChannels'
                    out = this.resultFileChs;
                case 'measurementFileChannels'
                    out = this.measurementFileChs;
                case 'subjectInfoAllColumnNames'
                    out = this.subjectInfoColumnNames;
                case 'subjectInfoConditionalColumnNames'
                    ref = this.getSubjectInfoConditionalColumnDefinitions();
                    idx = ~(cellfun('isempty',ref));
                    out = this.subjectInfoColumnNames(idx,1);
                case 'subjectInfoRegularColumnNames'
                    ref = this.getSubjectInfoConditionalColumnDefinitions();
                    idx = cellfun('isempty',ref);
                    out = this.subjectInfoColumnNames(idx,1);
                case 'subjectInfoRegularNumericColumnNames'                    
                    ref = this.getSubjectInfoConditionalColumnDefinitions();
                    idx = cellfun('isempty',ref);
                    tmp = cellfun(@isnumeric,this.subjectInfo) & ~cellfun(@isempty,this.subjectInfo);
                    if(isempty(tmp))
                        out = cell(0,0);
                    else
                        idx = idx & any(tmp,1)';
                        out = this.subjectInfoColumnNames(idx,1);
                    end
                otherwise
                    out = [];
            end
        end        
        
        %% compute functions and other methods
        function [cimg, lblx, lbly, cw] = makeConditionMVGroupObj(this,cName,chan,MVGroupID)
            %make merged MVGroups for a study condition
            if(~this.isLoaded)
                this.load();
            end
            this.updateLongProgress(0.01,'Scatter Plot...');
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
                if(~isempty(MVGroupObjs{i}.getROIImage([],0,1,0)))
                    [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,MVGroupObjs{i}.getROIImage([],0,1,0),MVGroupObjs{i}.getCIXLbl([],0,1,0),MVGroupObjs{i}.getCIYLbl([],0,1,0),cw);
                end
                this.updateLongProgress(i/length(MVGroupObjs),sprintf('Scatter Plot: %0.1f%%',100*i/length(MVGroupObjs)));
            end
            this.updateLongProgress(0,'');
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
                ROICoordinates = this.getResultROICoordinates(hg{i}.subjectName,dType,ROIType);
                ci = hg{i}.getROIImage(ROICoordinates,ROIType,ROISubType,ROIVicinity);
                ciMerged = [ciMerged; ci(:);];
            end
            %add subject representing the merged data
            condition = this.getConditionObj(cName);
            if(isempty(condition))
                %add condition to list
                condition = FDTSubject(this,cName);
                this.myConditionStatistics.insertEnd(condition,cName);
            end
            condition.addObjMergeID(id,chan,dType,1,ciMerged);
        end
        
        function checkSubjectFiles(this,subjectID)
            %check data files on disk for subject and update this.subjectFiles
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(subjectID))
                %check all subjects
                %clear all old results
                %nrSubjects = this.myStudyInfoSet.nrSubjects;
                subjects = this.subjectNames;
                this.clearFilesList([]);
                for i = 1:this.nrSubjects
                    this.checkSubjectFiles(subjects{i});
                end
            else
                %check specific subject
                subDir = fullfile(this.myDir,subjectID);
                idx = this.subName2idx(subjectID);
                if(isempty(idx))
                    %we don't know this subject, try to clear it
                    %this.clearSubjectFiles(subjectID)
                    return
                elseif(~isempty(idx) && ~isfolder(subDir))
                    %we know the subject but there is nothing on disk
                    this.clearFilesList(idx);
                    this.clearROI(idx);
                    this.clearZScaling(idx);
                    this.clearCrossSections(idx);
                    return
                else
                    %we know the subject and there is something on disk
                    this.clearFilesList(idx);
                    %find result files
                    files = rdir(sprintf('%s%sresult_ch*.mat',subDir,filesep));
                    for i = 1:length(files)
                        [~,sn] = fileparts(files(i,1).name);
                        id = str2double(sn(isstrprop(sn, 'digit')));
                        this.setResultOnHDD(subjectID,id);
                    end
                    %find measurement files
                    files = rdir(sprintf('%s%smeasurement_ch*.mat',subDir,filesep));
                    for i = 1:length(files)
                        [~,sn] = fileparts(files(i,1).name);
                        id = str2double(sn(isstrprop(sn, 'digit')));
                        this.setMeasurementOnHDD(subjectID,id);
                    end
                end                
            end
        end
        
        function clearSubjectFiles(this,subjectID)
            %delete data files for subject
            if(isempty(subjectID))
                %clear all subjects
                %nrSubjects = this.myStudyInfoSet.nrSubjects;
                subjects = this.subjectNames;
                for i = 1:this.nrSubjects
                    this.clearSubjectFiles(subjects{i});
                end
            else
                %clear specific subject
                idx = this.subName2idx(subjectID);
                if(~isempty(idx))
                    this.clearFilesList(idx);
                    this.clearROI(idx);
                    this.clearZScaling(idx);
                    this.clearCrossSections(idx);
                end
                subDir = fullfile(this.myDir,subjectID);
                if(~isfolder(subDir))
                    return
                end
                [status, message, messageid] = rmdir(subDir,'s');
            end
            this.setDirty(true);
        end
        
        function checkConditionRef(this,colN)
            %update combinations columns
            if(~this.isLoaded)
                this.load();
            end
            if(isempty(this.subjectInfo) || all(all(cellfun('isempty',this.subjectInfo))))
                return
            end
            if(isempty(colN))
                %check all columns
                for i=1:length(this.subjectInfoColumnNames)
                    this.checkConditionRef(i);
                end
            else
                ref = this.getConditionalColumnDefinition(colN);
                if(isempty(ref))
                    %column is not a combination
                    return
                end
                %convert logical operators
                [op, neg] = this.str2logicOp(ref.logOp);
                %create condition result for reference column A
                switch ref.relA
                    case '!='
                        ref.relA = '~=';
                end
                a = this.subjectInfoColumnName2idx(ref.colA);
                if((a > colN) && (~isempty(this.getConditionalColumnDefinition(a))))
                    %reference is a non-updated condition column
                    this.checkConditionRef(a);
                end
                colA = this.subjectInfo(:,a);
                %determine column class
                cellclass = cellfun(@ischar,colA);
                if(any(cellclass))
                    colADoubleFlag = false;
                else
                    colADoubleFlag = true;
                end
                for j=1:size(colA,1)
                    if(isempty(colA{j,1}) || all(isnan(colA{j,1})))
                        if(isempty(this.getConditionalColumnDefinition(a)))
                            %non logical reference
                            if(colADoubleFlag)
                                colA(j,1) = {0};
                            else
                                colA(j,1) = {''};
                            end
                        else
                            %logical reference
                            colA(j,1) = {false};
                        end
                    end
                end
                if(colADoubleFlag)
                    colA = cell2mat(colA);
                    if(~(isa(colA,'double') || isa(colA,'logical')))
                        %try to convert to double
                        colA = str2num(colA);
                    end
                    if(ischar(ref.valA))
                        %try to convert
                        tmp = str2num(ref.valA);
                        if(~isempty(tmp))
                            ref.valA = tmp;
                        end
                    end
                    if(ischar(ref.valA))
                        %comparison value for A does not fit
                        colA = false(size(colA));
                    else
                        eval(sprintf('colA = colA %s %f;',ref.relA,ref.valA));
                    end
                else
                    if(~ischar(ref.valA))
                        %try to convert to char
                        ref.valA = num2str(ref.valA);
                    end
                    %column of characters
                    if(strcmp(ref.relA,'=='))
                        colA = strcmp(colA,ref.valA);
                    else
                        colA = ~strcmp(colA,ref.valA);
                    end
                end
                %conditional column with 2 reference columns
                if(~isempty(op))
                    %create condition result for reference coulmn B
                    switch ref.relB
                        case '!='
                            ref.relB = '~=';
                    end
                    b = this.subjectInfoColumnName2idx(ref.colB);
                    if((b > colN) && (~isempty(this.getConditionalColumnDefinition(b))))
                        %reference is a non-updated condition column
                        this.checkConditionRef(b);
                    end
                    colB = this.subjectInfo(:,b);
                    cellclass = cellfun(@ischar,colB);
                    if(any(cellclass))
                        colBDoubleFlag = false;
                    else
                        colBDoubleFlag = true;
                    end
                    for j=1:size(colB,1)
                        if(isempty(colB{j,1}) || isnan(colB{j,1}))
                            if(isempty(this.getConditionalColumnDefinition(b)))
                                %non-logical reference
                                if(colBDoubleFlag)
                                    colB(j,1) = {0};
                                else
                                    colB(j,1) = {''};
                                end
                            else
                                %logical reference
                                colB(j,1) = {false};
                            end
                        end
                    end
                    if(colBDoubleFlag)
                        colB = cell2mat(colB);
                        if(~(isa(colB,'double') || isa(colB,'logical')))
                            %try to convert to double
                            colB = str2num(colB);
                        end
                        if(ischar(ref.valB))
                            %try to convert
                            tmp = str2num(ref.valB);
                            if(~isempty(tmp))
                                ref.valB = tmp;
                            end
                        end
                        if(ischar(ref.valB))
                            %comparison value for A does not fit
                            colB = false(size(colB));
                        else
                            if(strcmpi(ref.relB,'xor'))
                                eval(sprintf('colB = %s(colB,%f);',lower(ref.relB),ref.valB));
                            else
                                eval(sprintf('colB = colB %s %f;',ref.relB,ref.valB));
                            end
                        end
                    else
                        if(~ischar(ref.valB))
                            %try to convert to char
                            ref.valB = num2str(ref.valB);
                        end
                        %column of characters
                        if(strcmp(ref.relB,'=='))
                            colA = strcmp(colB,ref.valB);
                        else
                            colA = ~strcmp(colB,ref.valB);
                        end
                    end
                    if(strcmpi(op,'xor'))
                        eval(sprintf('colA = %s%s(colA,colB);',neg,lower(op)));
                    else
                        eval(sprintf('colA = %s(colA %s colB);',neg,op));
                    end
                end
                %update values in conditional column
                this.subjectInfo(:,colN) = num2cell(colA);
            end
        end
        
        function swapColumn(this,col,n)
            %swap column with its nth neighbor
            if(~this.isLoaded)
                this.load();
            end            
            if(((n + col) < 1) || ((n + col) > length(this.subjectInfoColumnNames)))
                %out of index
                return
            end
            %swap subjectInfoColumnNames
            temp = this.subjectInfoColumnNames(col,1);
            this.subjectInfoColumnNames(col,1) = this.subjectInfoColumnNames(col+n,1);
            this.subjectInfoColumnNames(col+n,1) = temp;
            %swap Data
            temp = this.subjectInfo(:,col);
            this.subjectInfo(:,col) = this.subjectInfo(:,col+n);
            this.subjectInfo(:,col+n) = temp;
            temp = this.subjectInfoConditionDefinition(col,1);
            this.subjectInfoConditionDefinition(col,1) = this.subjectInfoConditionDefinition(col+n,1);
            this.subjectInfoConditionDefinition(col+n,1) = temp;            
            temp = this.subjectInfoColumnDefaults(col,1);
            this.subjectInfoColumnDefaults(col,1) = this.subjectInfoColumnDefaults(col+n,1);
            this.subjectInfoColumnDefaults(col+n,1) = temp;            
            this.setDirty(true);
        end
        
        function oldStudy = updateStudyVer(this,oldStudy)
            %make old study data compatible with current version
            %             if(oldStudy.revision < 2)
            %                 oldStudy.subjects = oldStudy.subjects(:);
            %             end
            %
            %             if(oldStudy.revision < 4)
            %                 %make study compatible for combinations
            %                 oldStudy.subjectInfoCombi = cell(1,size(oldStudy.subjectInfoHeaders,2));
            %             end
            %
            %             if(oldStudy.revision < 6)
            %                 %file format of saved datafiles has changed - convert them
            %                 dirStruct = rdir(sprintf('%s\\**\\*.mat',this.myParent.myDir));
            %                 hwb = waitbar(0,'study update');
            %                 tStart = clock;
            %                 for i = 1:length(dirStruct)
            %                     [~, fn] = fileparts(dirStruct(i).name);
            %                     if(~strcmp(fn,'studyData'))
            %                         try
            %                             export = load(dirStruct(i).name);
            %                             export = updateFitResultsStruct(export.export);
            %                             save(dirStruct(i).name,'export');
            %                         end
            %                     end
            %                     [~, minutes secs] = secs2hms(etime(clock,tStart)/i*(length(dirStruct)-i)); %mean cputime for finished runs * cycles left
            %                     waitbar(i/length(dirStruct), hwb,[sprintf('study update: %03.1f',i/length(dirStruct)*100) '% done - Time left: ' num2str(minutes,'%02.0f') 'min ' num2str(secs,'%02.0f') 'sec'] );
            %                 end
            %                 close(hwb);
            %             end
            %
            %             if(oldStudy.revision < 7)
            %                 %check subject cuts
            %                 oldStudy.subjectCuts = cell(length(oldStudy.subjects),1);
            %             end
            %
            %             if(oldStudy.revision < 8)
            %                 %add IRF struct
            %                 oldStudy.IRFInfo = [];
            %                 %re-scale B&H amplitudes
            %                 dirStruct = rdir(sprintf('%s\\**\\*.mat',this.myParent.myDir));
            %                 hwb = waitbar(0,'study update');
            %                 tStart = clock;
            %                 for i = 1:length(dirStruct)
            %                     [~, fn] = fileparts(dirStruct(i).name);
            %                     if(~strcmp(fn,'studyData'))
            %                         try
            %                             export = load(dirStruct(i).name);
            %                             export = export.export;
            %                             if(isempty(export.data.fluo.roi))
            %                                 %this is a B&H result
            %                                 amps = fieldnames(export.results.pixel);
            %                                 idx = find(strncmpi('Amplitude',amps,9));
            %                                 for j = 1:length(idx)
            %                                     export.results.pixel.(amps{j}) = export.results.pixel.(amps{j})./100000; %100000 was fixed multiplicator for B&H results
            %                                 end
            %                                 save(dirStruct(i).name,'export');
            %                             else
            %                                 %read IRF info
            %                                 this.setIRFInfo(export.data.fluo.curChannel,export.parameters.basic.curIRFID,export.parameters.dynamic.timeChans,export.parameters.basic.curIRFID);
            %                                 oldStudy.IRFInfo = this.IRFInfo;
            %                             end
            %                         end
            %                     end
            %                     [~, minutes secs] = secs2hms(etime(clock,tStart)/i*(length(dirStruct)-i)); %mean cputime for finished runs * cycles left
            %                     waitbar(i/length(dirStruct), hwb,[sprintf('study update: %03.1f',i/length(dirStruct)*100) '% done - Time left: ' num2str(minutes,'%02.0f') 'min ' num2str(secs,'%02.0f') 'sec'] );
            %                 end
            %                 close(hwb);
            %             end
            
            if(oldStudy.revision < 9)
                oldStudy.arithmeticImageInfo = [];
            end
            
            if(oldStudy.revision < 11)
                oldStudy.studyClusters = cell(0,0);
                tmp = jet(256);
                oldStudy.color = tmp(round(rand*255+1),:);
            end
            
            if(oldStudy.revision < 12)
                if(isfield(oldStudy,'color'))
                    old = oldStudy.color;
                    oldStudy = rmfield(oldStudy,'color');
                else
                    tmp = jet(256);
                    old = tmp(round(rand*255+1),:);
                end
                %save color not per study but per view now
                oldStudy.viewColors = cell(2,1);
                oldStudy.viewColors(1,1) = {FDTree.defaultConditionName()};
                oldStudy.viewColors(2,1) = {old};
            end
            
            if(oldStudy.revision < 13)
                %file format of saved datafiles has changed - convert them
                dirStruct = rdir(sprintf('%s\\**\\*.mat',this.myParent.myDir));
                hwb = waitbar(0,'study update');
                tStart = clock;
                for i = 1:length(dirStruct)
                    [~, fn] = fileparts(dirStruct(i).name);
                    if(~strcmp(fn,'studyData'))
                        try
                            export = load(dirStruct(i).name);
                            result = resultFile.updateFitResultsStruct(export,this.getAboutInfo());
                            save(strrep(dirStruct(i).name,'file','result_ch'),'result');
%                             if(~isempty(measurement))
%                                 save(strrep(dirStruct(i).name,'file','measurement_ch'),'measurement');
%                             end
                            delete(dirStruct(i).name); %remove old file
                        catch
                            %todo: notify user that update failed 
                        end
                    end
                    [~, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(dirStruct)-i)); %mean cputime for finished runs * cycles left
                    waitbar(i/length(dirStruct), hwb,[sprintf('study update: %03.1f',i/length(dirStruct)*100) '% done - Time left: ' num2str(minutes,'%02.0f') 'min ' num2str(secs,'%02.0f') 'sec'] );
                end
                close(hwb);
            end
            
            if(oldStudy.revision < 15)
                %study info set was updated
                if(isfield(oldStudy,'subjectInfoHeaders'))
                    oldStudy.infoHeaders = oldStudy.subjectInfoHeaders;
                    oldStudy = rmfield(oldStudy,'subjectInfoHeaders');
                end
                if(isfield(oldStudy,'subjectFilesHeaders'))
                    %                     oldStudy.filesHeaders = oldStudy.subjectFilesHeaders;
                    oldStudy = rmfield(oldStudy,'subjectFilesHeaders');
                end
                if(isfield(oldStudy,'subjectFiles'))
                    oldStudy.resultFileChs = oldStudy.subjectFiles;
                    oldStudy.measurementFileChs = cell(size(oldStudy.subjectFiles));
                    oldStudy = rmfield(oldStudy,'subjectFiles');
                end
                if(isfield(oldStudy,'subjectScalings'))
                    oldStudy.resultROI = oldStudy.subjectScalings;
                    oldStudy = rmfield(oldStudy,'subjectScalings');
                end
                if(isfield(oldStudy,'subjectCuts'))
                    oldStudy.resultCuts = oldStudy.subjectCuts;
                    oldStudy = rmfield(oldStudy,'subjectCuts');
                end
            end 
            
            if(oldStudy.revision < 16)
                %new fields resultROIType, resultROISubType, resultROISubTypeAnchor; renamed resultROI to resultROICoordinates
                if(isfield(oldStudy,'resultROI'))
                    oldStudy.resultROICoordinates = oldStudy.resultROI;
                    oldStudy.resultROIType = cell(size(oldStudy.resultROI));
                    oldStudy.resultROISubType = cell(size(oldStudy.resultROI));
                    oldStudy.resultROISubTypeAnchor = cell(size(oldStudy.resultROI));
                    oldStudy = rmfield(oldStudy,'resultROI');
                end
            end
            
            if(oldStudy.revision < 17)
                %changed the way ROI coordinates are saved, remove resultROISubTypeAnchor
                new = [];
                if(isfield(oldStudy,'resultROICoordinates'))
                    old = oldStudy.resultROICoordinates;
                    new = cell(size(old));
                    for i = 1:size(new,1)                        
                        if(~isempty(old{i,1}) && length(old{i,1}) == 6)
                            tmp = zeros(7,3,2,'int16'); %7 ROI types; enable/invert flags, coordinates, parameters; y, x
                            tmp(2,1,1) = 1;
                            tmp(2,2:3,1) = old{i,1}(5:6); %y coordinates
                            tmp(2,2:3,2) = old{i,1}(2:3); %x coordinates
                            new(i,1) = {tmp};
                        end                        
                    end
                end
                if(isfield(oldStudy,'resultROISubTypeAnchor'))
                    old = oldStudy.resultROISubTypeAnchor;
                    if(isempty(new))
                        new = cell(size(old));
                    end
                    for i = 1:min(size(new,1),size(old,1))
                        if(~isempty(old{i,1}) && length(old{i,1}) == 2)
                            if(isempty(new{i,1}))
                                tmp = zeros(7,3,2,'int16');%7 ROI types; enable/invert flags, coordinates, parameters; y, x
                            else
                                tmp = new{i,1};
                            end
                            tmp(1,1,1) = 1;
                            tmp(1,2,:) = old{i,1};
                            new(i,1) = {tmp};
                        end
                    end
                    oldStudy = rmfield(oldStudy,'resultROISubTypeAnchor');
                end
                if(~isempty(new))
                    oldStudy.resultROICoordinates = new;
                end
            end
            
            if(oldStudy.revision < 18)
                if(isfield(oldStudy,'resultROIType'))
                    oldStudy = rmfield(oldStudy,'resultROIType');
                end
                if(isfield(oldStudy,'resultROISubType'))
                    oldStudy = rmfield(oldStudy,'resultROISubType');
                end
                if(isfield(oldStudy,'studyClusters')) %add default ROI info to MVGroups
                    ROI.ROIType = 0;
                    ROI.ROISubType = 1;
                    ROI.ROIInvertFlag = 0;
                    for i = 1:size(oldStudy.studyClusters,2)
                        if(strncmp(oldStudy.studyClusters{1,i},'Cluster',7))
                            %clusters have been renamed to MVGroup
                            oldStudy.studyClusters{1,i}(1:7) = 'MVGroup';
                        end
                        %now we need ROI info for MVGroups
                        oldStudy.studyClusters{2,i}.ROI = ROI;
                    end                    
                end
            end
            
            if(oldStudy.revision < 19)
                if(isfield(oldStudy,'selFLIMItems'))
                    oldStudy = rmfield(oldStudy,'selFLIMItems');
                end
            end
            
            if(oldStudy.revision < 20)
                if(isfield(oldStudy,'arithmeticImageInfo'))
                    for i = 1:size(oldStudy.arithmeticImageInfo,1)
                        tmp = oldStudy.arithmeticImageInfo{i,2};
                        tmp.normalizeA = 0;
                        tmp.normalizeB = 0;
                        oldStudy.arithmeticImageInfo{i,2} = tmp;
                    end
                end                
            end
            
            if(oldStudy.revision < 21)
                %new field resultZScaling
                if(isfield(oldStudy,'resultROICoordinates'))
                    oldStudy.resultZScaling = cell(size(oldStudy.resultROICoordinates));
                end
            end
            
            if(oldStudy.revision < 22)
                %add channel to resultZScaling
                if(isfield(oldStudy,'resultZScaling'))
                    tmp = oldStudy.resultZScaling;
                    idx = ~cellfun(@isempty,tmp);
                    if(any(idx))
                        idx = find(idx);
                        for i = 1:length(idx)
                            tmp3 = tmp{idx(i)};
                            tmp3(:,2:end+1) = tmp3;
                            tmp3(:,1) = {1}; %set old z scaling to channel 1
                            tmp(idx(i)) = {tmp3};
                        end
                        oldStudy.resultZScaling = tmp;
                    end
                end
            end
            
            if(oldStudy.revision < 23)
                %change name of default column
                if(isfield(oldStudy,'viewColors') && size(oldStudy.viewColors,1) > 1 && size(oldStudy.viewColors,2) > 1 && strcmp(oldStudy.viewColors(1,1),'-'))
                    oldStudy.viewColors(1,1) = {FDTree.defaultConditionName()};
                end                
            end
            
            if(oldStudy.revision < 24)
                %new field resultColorScaling
                if(isfield(oldStudy,'resultZScaling'))
                    oldStudy.resultColorScaling = cell(size(oldStudy.resultZScaling));
                end
            end
            
            if(oldStudy.revision < 25)
                %change name of condition color field
                if(isfield(oldStudy,'viewColors'))
                    oldStudy.conditionColors = oldStudy.viewColors;
                    oldStudy = rmfield(oldStudy,'viewColors');
                end
            end
            
            if(oldStudy.revision < 26)
                %change names of a few fields
                if(isfield(oldStudy,'subjects'))
                    oldStudy.subjectNames = oldStudy.subjects;
                    oldStudy = rmfield(oldStudy,'subjects');
                end
                if(isfield(oldStudy,'subjectInfoCombi'))
                    oldStudy.subjectInfoConditionDefinition = oldStudy.subjectInfoCombi;
                    oldStudy = rmfield(oldStudy,'subjectInfoCombi');
                end
                if(isfield(oldStudy,'resultCuts'))
                    oldStudy.resultCrossSection = oldStudy.resultCuts;
                    oldStudy = rmfield(oldStudy,'resultCuts');
                end
                if(isfield(oldStudy,'infoHeaders'))
                    oldStudy.subjectInfoColumnNames = oldStudy.infoHeaders;
                    oldStudy = rmfield(oldStudy,'infoHeaders');
                end
            end
            
            if(oldStudy.revision < 27)
                %update arithmetic image info
                if(isfield(oldStudy,'arithmeticImageInfo'))
                    for i = 1:size(oldStudy.arithmeticImageInfo,1)
                        tmp = oldStudy.arithmeticImageInfo{i,2};
                        if(isfield(tmp,'valCombi') && strcmp(tmp.valCombi,'-'))
                            tmp.valCombi = '-no op-';
                        end
                        oldStudy.arithmeticImageInfo{i,2} = tmp;
                    end
                end
            end
                        
            if(oldStudy.revision < 28)
                %update arithmetic image info                
                if(isfield(oldStudy,'arithmeticImageInfo'))
                    def = AICtrl.getDefStruct;
                    for i = 1:size(oldStudy.arithmeticImageInfo,1)
                        tmp = oldStudy.arithmeticImageInfo{i,2};
                        if(isfield(tmp,'valCombi'))
                            if(strcmp(tmp.valCombi,'-none-'))
                                tmp.opB = '-no op-';
                            else
                                tmp.opB = tmp.valCombi;
                            end
                        end
                        if(isfield(tmp,'compAgainst'))
                            tmp.compAgainstB = tmp.compAgainst;
                        end
                        if(isfield(tmp,'valB'))
                            tmp.valC = tmp.valB;
                        end
                        if(isfield(tmp,'valA'))
                            tmp.valB = tmp.valA;
                        end
                        tmp = orderfields(checkStructConsistency(tmp,def));
                        oldStudy.arithmeticImageInfo{i,2} = tmp;
                    end
                end
            end
            
            if(oldStudy.revision < 29)
                %update arithmetic image info                
                if(isfield(oldStudy,'arithmeticImageInfo'))
                    def = AICtrl.getDefStruct;
                    for i = 1:size(oldStudy.arithmeticImageInfo,1)
                        tmp = oldStudy.arithmeticImageInfo{i,2};
                        tmp = orderfields(checkStructConsistency(tmp,def));
                        oldStudy.arithmeticImageInfo{i,2} = tmp;
                    end
                end
            end
            
            if(oldStudy.revision < 30)
                %ROIs now get IDs
                if(isfield(oldStudy,'resultROICoordinates'))
                    for i = 1:size(oldStudy.resultROICoordinates,1)
                        tmp = oldStudy.resultROICoordinates{i,1};
                        if(size(tmp,1) == 7)
                            %each ROI Type gets an ID (ETDRS: 1000, rectange: 2000, circle: 3000, polygon: 4000) and a running number
                            tmp(:,1,1) = [1001,2001,2002,3001,3002,4001,4002];
                        else
                            %should not happen -> delete invalid ROI
                            tmp = zeros(7,3,2,'int16');
                            tmp(:,1,1) = [1001,2001,2002,3001,3002,4001,4002];
                        end
                        oldStudy.resultROICoordinates{i,1} = tmp;
                    end
                end
                if(isfield(oldStudy,'studyClusters'))
                    oldStudy.MVGroupTargets = oldStudy.studyClusters;
                    ROIVec = [1001,2001,2002,3001,3002,4001,4002];
                    for i = 1:size(oldStudy.MVGroupTargets,2)                        
                        if(~isempty(oldStudy.MVGroupTargets(:,i)))                            
                            oldStudy.MVGroupTargets{2,i}.ROI.ROIVicinity = 1;
                            if(oldStudy.MVGroupTargets{2,i}.ROI.ROIType >= 1 && oldStudy.MVGroupTargets{2,i}.ROI.ROIType <= 7)
                                oldStudy.MVGroupTargets{2,i}.ROI.ROIType = ROIVec(oldStudy.MVGroupTargets{2,i}.ROI.ROIType);
%                             else
%                                 oldStudy.MVGroupTargets{2,i}.ROI.ROIType = 0;
                            end
                        end
                    end
                    oldStudy = rmfield(oldStudy,'studyClusters');
                end
            end
            
            if(oldStudy.revision < 31)
                %update conditional columns
                if(isfield(oldStudy,'subjectInfoConditionDefinition'))
                    for i = 1:size(oldStudy.subjectInfoConditionDefinition,1)
                        tmp = oldStudy.subjectInfoConditionDefinition{i,1};
                        if(isempty(tmp))
                            continue
                        end
                        if(isfield(tmp,'logOp') && strcmp(tmp.logOp,'-'))
                            tmp.logOp = '-no op-';
                            oldStudy.subjectInfoConditionDefinition{i,1} = tmp;
                        end
                    end
                end
            end
            
            if(oldStudy.revision < 32)
                %add ROI groups
                oldStudy.resultROIGroups = cell(0,0);                
            end
            
            if(oldStudy.revision < 33)
                %add nonDefaultSizeROICoordinates
                oldStudy.nonDefaultSizeROICoordinates = cell(0,0);                
            end
            
            if(oldStudy.revision < 34)
                %add subjectInfoColumnDefaults
                oldStudy.subjectInfoColumnDefaults = cell(size(oldStudy.subjectInfoColumnNames));
            end
            
            this.setDirty(true);
        end
        
        function setDirty(this,flag)
            %set dirty flag for this study
            this.dirtyFlag = logical(flag);
        end
        
        function flag = eq(s1,s2)
            %compare two study objects
            if(ischar(s2))
                flag = strcmp(s1.name,s2);
            else
                flag = strcmp(s1.name,s2.name);
            end
        end
        
        %% dependent properties
        function nr = get.nrSubjects(this)
            %how many subjects are in this study?
            nr = length(this.subjectNames);
        end        
                
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        function out = get.isDirty(this)
            %return true if something in the study has changed
            out = this.dirtyFlag;
            if(~out)
                %check if subjects have changes
                tmp = this.getChildenDirtyFlags();
                if(isempty(tmp))
                    return
                end
                if(iscell(tmp))
                    tmp = cell2mat(tmp);
                    out = any(tmp(:));
                end
            end
        end
        
        function out = get.myDir(this)
            %return this studies working directory
            out = fullfile(this.myParent.getWorkingDirectory(),this.name);
        end
        
        function out = get.hashEngine(this)
            %return FLIMX hash engine
            out = this.myParent.hashEngine;
        end
        
    end %methods
    
    methods(Access = private)
        function out = sortSubjects(this,varargin)
            %sort subjects and connected fields
            if(isempty(this.subjectNames))
                out = [];
                return
            end            
            if(isempty(varargin))
                %sort subjects of current study
                [this.subjectNames, idx] = sort(this.subjectNames);
                if(~all(idx(:) == (1:this.nrSubjects)'))
                    %study was not already sorted
                    this.resultFileChs = this.resultFileChs(idx,:);
                    this.measurementFileChs = this.measurementFileChs(idx,:);
                    this.subjectInfo = this.subjectInfo(idx,:);
                    this.resultROICoordinates = this.resultROICoordinates(idx);
                    this.nonDefaultSizeROICoordinates = this.nonDefaultSizeROICoordinates(idx);
                    this.resultZScaling = this.resultZScaling(idx);
                    this.resultColorScaling = this.resultColorScaling(idx);
                    this.resultCrossSection = this.resultCrossSection(idx);
                    this.allFLIMItems = this.allFLIMItems(idx,:);
                    this.setDirty(true);
                end
            else
                %sort subjects of imported study
                oldStudy = varargin{1};
                [oldStudy.subjectNames, idx] = sort(oldStudy.subjectNames);
                oldStudy.resultFileChs = oldStudy.resultFileChs(idx,:);
                oldStudy.measurementFileChs = oldStudy.measurementFileChs(idx,:);
                oldStudy.subjectInfo = oldStudy.subjectInfo(idx,:);
                oldStudy.resultROICoordinates = oldStudy.resultROICoordinates(idx);
                oldStudy.nonDefaultSizeROICoordinates = oldStudy.nonDefaultSizeROICoordinates(idx);
                oldStudy.resultZScaling = oldStudy.resultZScaling(idx);
                oldStudy.resultColorScaling = oldStudy.resultColorScaling(idx);
                oldStudy.resultCrossSection = oldStudy.resultCrossSection(idx);
                oldStudy.allFLIMItems = oldStudy.allFLIMItems(idx,:);
                out = oldStudy;
            end
        end
        
        function setSubjectFileHeaders(this,subjectFileHeaders,idx)
            %set subjectFileHeaders
            if(isempty(idx))
                %set all subjectFileHeaders (initial case)
                this.subjectFileHeaders = [];
                this.subjectFileHeaders = subjectFileHeaders;
            else
                %set a single subjectFileHeader
                this.subjectFileHeaders(idx) = subjectFileHeaders;
                this.setDirty(true);
            end
        end        
        
        function clearFilesList(this,idx)
            %clear lists of result and measurement files which keep track of the channels on HDD
            if(isempty(idx))
                this.resultFileChs = cell(this.nrSubjects,max(1,size(this.resultFileChs,2)));
                this.measurementFileChs = cell(this.nrSubjects,max(1,size(this.measurementFileChs,2)));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultFileChs(idx,:) = cell(1,max(1,size(this.resultFileChs,2)));
                    this.measurementFileChs(idx,:) = cell(1,max(1,size(this.measurementFileChs,2)));
                    this.setDirty(true);
                end
            end
        end
        
        function clearROI(this,idx)
            %reset ROI for subject
            if(isempty(idx))
                this.resultROICoordinates = [];
                this.resultROICoordinates = cell(size(this.subjectNames));
                %also delete non default size ROIs?
                %this.nonDefaultSizeROICoordinates = [];
                %this.nonDefaultSizeROICoordinates = cell(size(this.subjectNames));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultROICoordinates(idx) = cell(1,1);
                    %also delete non default size ROIs?
                    %this.nonDefaultSizeROICoordinates(idx) = cell(1,1);
                    this.setDirty(true);
                end
            end
        end
        
        function clearZScaling(this,idx)
            %reset z scaling for subject
            if(isempty(idx))
                this.resultZScaling = [];
                this.resultZScaling = cell(size(this.subjectNames));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultZScaling(idx) = cell(1,1);
                    this.setDirty(true);
                end
            end
        end
        
        function clearColorScaling(this,idx)
            %reset color scaling for subject
            if(isempty(idx))
                this.resultColorScaling = [];
                this.resultColorScaling = cell(size(this.subjectNames));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultColorScaling(idx) = cell(1,1);
                    this.setDirty(true);
                end
            end
        end
        
        function clearCrossSections(this,idx)
            %reset cross sections
            if(isempty(idx))
                this.resultCrossSection = cell(size(this.subjectNames));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultCrossSection(idx) = cell(1,1);
                    this.setDirty(true);
                end
            end
        end
        
        function setResultOnHDD(this,subjectID,ch)
            %mark a channel ch as loaded for subject subjectID
            idx = this.subName2idx(subjectID);
            if(isempty(idx))
                %subject not in study
                return
            end
            this.resultFileChs(idx,ch) = {ch};
            this.setDirty(true);
        end
        
        function setMeasurementOnHDD(this,subjectID,ch)
            %mark a channel ch as loaded for subject subjectID
            idx = this.subName2idx(subjectID);
            if(isempty(idx))
                %subject not in study
                return
            end
            this.measurementFileChs(idx,ch) = {ch};
            this.setDirty(true);
        end
        
        function addResultROIType(this,ROIType)
            %add an empty ROIType to all subjects in this study
            %this.resultROICoordinates = cellfun(@(x)FDTChunk.addResultROIType(x,ROIType),this.resultROICoordinates);
            for i = 1:this.nrSubjects
                this.resultROICoordinates{i} = FDTStudy.insertResultROIType(this.resultROICoordinates{i},ROIType);
                %update all existing non default size ROIs
                tmp = this.nonDefaultSizeROICoordinates{i};
                if(~isempty(tmp) && iscell(tmp) && size(tmp,2) == 2)
                    for j = 1:size(tmp,1)
                        tmp{j,2} = FDTStudy.insertResultROIType(tmp{j,2},ROIType);
                    end
                    this.nonDefaultSizeROICoordinates{i} = tmp;
                end
            end
        end
        
        function setIRFInfo(this,ch,id,timeChannels,irf)
            %set IRF info
            this.IRFInfo.timeChannels = timeChannels;
            this.IRFInfo.id = id;
            if(isnumeric(ch) && ~isempty(irf))
                irf = irf./max(irf(:))*15000; % 15000 is defined by B&H
                this.IRFInfo.integral(ch) = {sum(irf(:))};
            end
        end
        
        %% output methods                
        function export = makeExportStruct(this,subjectID)
            %store all data of this study in a struct
            idx = this.subName2idx(subjectID);
            if(isempty(idx))
                idx = ':';
            end
            export.subjectNames = this.subjectNames(idx,:);
            export.subjectInfoColumnNames = this.subjectInfoColumnNames;
            export.subjectInfo = this.subjectInfo(idx,:);
            export.subjectInfoConditionDefinition = this.subjectInfoConditionDefinition;
            export.subjectInfoColumnDefaults = this.subjectInfoColumnDefaults;
            export.resultFileChs = this.resultFileChs(idx,:);
            export.measurementFileChs = this.measurementFileChs(idx,:);
            export.MVGroupTargets = this.MVGroupTargets;
            export.resultROIGroups = this.resultROIGroups;
            export.resultROICoordinates = this.resultROICoordinates(idx);
            export.nonDefaultSizeROICoordinates = this.nonDefaultSizeROICoordinates(idx);
            export.resultZScaling = this.resultZScaling(idx);
            export.resultColorScaling = this.resultColorScaling(idx);
            export.resultCrossSection = this.resultCrossSection(idx);
            export.allFLIMItems = this.allFLIMItems(idx,:);
            export.IRFInfo = this.IRFInfo;
            export.arithmeticImageInfo = this.arithmeticImageInfo;
            export.conditionColors = this.conditionColors;            
        end
        
        function out = getColumnDependencies(this,columnName)
            %return names of all conditions which use columnName as a reference
            if(~isempty(this.subjectInfoColumnNames))
                out = cell(0,0);
                n = this.subjectInfoColumnName2idx(columnName);
                for i=1:length(this.subjectInfoColumnNames)
                    ref = this.getConditionalColumnDefinition(i);
                    if(isempty(ref))
                        continue
                    end
                    a = this.subjectInfoColumnName2idx(ref.colA);
                    if(strcmp(ref.logOp,'-no op-'))
                        %second reference is inactive
                        b = 0;
                    else
                        b = this.subjectInfoColumnName2idx(ref.colB);
                    end
                    if((a == n) || (b == n))
                        %column n is a reference column
                        out(end+1) = this.subjectInfoColumnNames(i,1);
                    end
                end
            end
        end

        function out = getResultFileChs(this,subjectID)
            %get indices channels which carry a result
            if(isempty(subjectID))
                out = this.resultFileChs;
            else
                if(~isnumeric(subjectID))
                    subjectID = this.subName2idx(subjectID);
                    if(isempty(subjectID))
                        out = [];
                        return
                    end
                end
                out = this.resultFileChs(subjectID,:);
            end
        end
        
        function out = getMeasurementFileChs(this,subjectID)
            %get indices channels which carry a measurement
            if(isempty(subjectID))
                out = this.measurementFileChs;
            else
                if(~isnumeric(subjectID))
                    subjectID = this.subName2idx(subjectID);
                    if(isempty(subjectID))
                        out = [];
                        return
                    end
                end
                out = this.measurementFileChs(subjectID,:);
            end
        end
        
        function out = getFileChs(this,subjectID)
            %get indices channels which carry a measurement, a result or both for a subject
            m = this.getMeasurementFileChs(subjectID);
            r = this.getResultFileChs(subjectID);
            if(size(m,1) ~= size(r,1))
                out = [];
                return
            end
            out = cell(size(m,1),max(size(m,2),size(r,2)));
            for i = 1:size(m,1)
                tmp = unique([m{i,:},r{i,:}]);
                if(~isempty(tmp))
                    out(i,tmp) = num2cell(tmp);
                end
            end
        end
        
        function out = getStudyMVGroups(this)
            %get study MVGroups
            out = this.MVGroupTargets;
        end
       
        function [integral, id, timeChannels] = getIRFInfo(this,ch)
            %get info on used IRF for channel chStr
            integral = [];
            id = [];
            timeChannels = [];
            if(~isempty(this.IRFInfo))
                if(isnumeric(ch) && isfield(this.IRFInfo,'integral') && ch <= length(this.IRFInfo.integral))
                    integral = this.IRFInfo.integral{ch};
                end
                id = this.IRFInfo.id;
                timeChannels = this.IRFInfo.timeChannels;
            end
        end        
        
        function out = getAllArithmeticImageInfo(this)
            %
            out = this.arithmeticImageInfo;
        end
        
        function removeSubjectResult(this,subjectID)
            %remove the results of subject subjectID from this study
            idx = this.subName2idx(subjectID);
            if(~isempty(idx))
                this.resultFileChs(idx,:) = cell(1,max(1,size(this.resultFileChs,2)));
                this.resultROICoordinates(idx) = cell(1,1);
                this.nonDefaultSizeROICoordinates(idx) = cell(1,1);
                this.resultZScaling(idx) = cell(1,1);
                this.resultColorScaling(idx) = cell(1,1);
                this.resultCrossSection(idx) = cell(1,1);
                this.allFLIMItems(idx) = cell(1,1);
                this.setDirty(true);
            end            
        end
        
        function idx = subName2idx(this,subjectID)
            %get the index of a subject or check if index is valid
            idx = [];
            if(ischar(subjectID))
                idx = find(strcmp(subjectID,this.subjectNames),1);
            elseif(isnumeric(subjectID))
                if(subjectID <= this.nrSubjects)
                    idx = subjectID;
                end
            end
        end
        
        function idx = MVGroupName2idx(this,MVGroupName)
            %get the index of a MVGroup or check if index is valid
            idx = [];
            if(isempty(this.MVGroupTargets))
                return
            end
            if(ischar(MVGroupName))
                idx = find(strcmp(MVGroupName,this.MVGroupTargets(1,:)),1);
            elseif(isnumeric(MVGroupName))
                if(MVGroupName <= length(this.MVGroupTargets(1,:)))
                    idx = MVGroupName;
                end
            end
        end       
       
        function name = idx2SubName(this,id)
            %get the index of a subject or check if index is valid
            name = '';
            if(ischar(id))
                idx = find(strcmp(id,this.subjectNames),1);
                if(~isempty(idx))
                    %valid subject name
                    name = id;
                end
            elseif(isnumeric(id) && ~isempty(id))
                if(id <= this.nrSubjects && id > 0)
                    name = this.subjectNames{id};
                end
            end
        end
        
    end %methods(Access = private)
    
    methods(Static)
        function [testStudy,dirty] = checkStudyConsistency(testStudy)
            %make sure study is not corrput
            dirty = false;
            if(isstruct(testStudy) && ~isfield(testStudy,'IRFInfo'))
                testStudy.IRFInfo = [];
            end
            nrSubjects = length(testStudy.subjectNames);
            %result files
            tmpLen = size(testStudy.resultFileChs,1);
            if(tmpLen < nrSubjects)
                testStudy.resultFileChs(end+1:end+nrSubjects-tmpLen,:) = cell(nrSubjects-tmpLen,size(testStudy.resultFileChs,2));
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultFileChs = testStudy.resultFileChs(1:nrSubjects,:);
                dirty = true;
            end
            %measurement files
            tmpLen = size(testStudy.measurementFileChs,1);
            if(tmpLen < nrSubjects)
                testStudy.measurementFileChs(end+1:end+nrSubjects-tmpLen,:) = cell(nrSubjects-tmpLen,size(testStudy.measurementFileChs,2));
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.measurementFileChs = testStudy.measurementFileChs(1:nrSubjects,:);
                dirty = true;
            end
            %arithmeticImageInfo
            if(isstruct(testStudy) && ~isfield(testStudy,'arithmeticImageInfo') || ~iscell(testStudy.arithmeticImageInfo))
                testStudy.arithmeticImageInfo = cell(0,2);
            end
            if(size(testStudy.arithmeticImageInfo,2) < 2)
                testStudy.arithmeticImageInfo(:,2) = cell(size(testStudy.arithmeticImageInfo,1),1);
                dirty = true;
            elseif(size(testStudy.arithmeticImageInfo,2) > 2)
                testStudy.arithmeticImageInfo = testStudy.arithmeticImageInfo(:,1:2);
                dirty = true;
            end
            %subjectInfo
            tmpLen = size(testStudy.subjectInfo,1);
            if(tmpLen < nrSubjects)
                testStudy.subjectInfo(end+1:end+nrSubjects-tmpLen,:) = cell(nrSubjects-tmpLen,size(testStudy.subjectInfo,2));
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.subjectInfo = testStudy.subjectInfo(1:nrSubjects,:);
                dirty = true;
            end
            nrInfoCols = size(testStudy.subjectInfo,2);%isstrprop
            tmpTestChar = cellfun(@ischar,testStudy.subjectInfo);
            tmpTestCharSum = sum(tmpTestChar,1);
            idx = find(tmpTestCharSum > 0 & tmpTestCharSum < size(tmpTestChar,1));
            for i = 1:length(idx)
                %we've found columns which have chars in only a few rows
                if(sum(cellfun(@(x) isempty(x) || ~any(isstrprop(x,'alpha')),testStudy.subjectInfo(tmpTestChar(:,idx(i)),idx(i)))) == tmpTestCharSum(idx(i)))
                    %all rows with char datatype actually do not contain any usefull text
                    testStudy.subjectInfo(tmpTestChar(:,idx(i)),idx(i)) = num2cell(cellfun(@str2double,testStudy.subjectInfo(tmpTestChar(:,idx(i)),idx(i))));
                end                
            end
            %subjectInfoColumnNames
            if(size(testStudy.subjectInfoColumnNames,2) > 1)
                testStudy.subjectInfoColumnNames = testStudy.subjectInfoColumnNames(:);
                dirty = true;
            end
            tmpLen = length(testStudy.subjectInfoColumnNames);
            if(tmpLen < nrInfoCols)
                testStudy.subjectInfoColumnNames(end+1:end+nrInfoCols-tmpLen,1) = cell(nrInfoCols-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrInfoCols)
                testStudy.subjectInfoColumnNames = testStudy.subjectInfoColumnNames(1:nrInfoCols);
                dirty = true;
            end
            %subjectInfoConditionDefinition
            if(size(testStudy.subjectInfoConditionDefinition,2) > 1)
                testStudy.subjectInfoConditionDefinition = testStudy.subjectInfoConditionDefinition(:);
                dirty = true;
            end
            tmpLen = length(testStudy.subjectInfoConditionDefinition);
            if(tmpLen < nrInfoCols)
                testStudy.subjectInfoConditionDefinition(end+1:end+nrInfoCols-tmpLen,1) = cell(nrInfoCols-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrInfoCols)
                testStudy.subjectInfoConditionDefinition = testStudy.subjectInfoConditionDefinition(1:nrInfoCols);
                dirty = true;
            end
            %subjectInfoColumnDefaults
            if(size(testStudy.subjectInfoColumnDefaults,2) > 1)
                testStudy.subjectInfoColumnDefaults = testStudy.subjectInfoColumnDefaults(:);
                dirty = true;
            end
            tmpLen = length(testStudy.subjectInfoColumnDefaults);
            if(tmpLen < nrInfoCols)
                testStudy.subjectInfoColumnDefaults(end+1:end+nrInfoCols-tmpLen,1) = cell(nrInfoCols-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrInfoCols)
                testStudy.subjectInfoColumnDefaults = testStudy.subjectInfoColumnDefaults(1:nrInfoCols);
                dirty = true;
            end
            %check subject info data types, logical is allowed only for conditional columns
            conditionCol = cellfun('isempty',testStudy.subjectInfoConditionDefinition);
            for i = 1:length(conditionCol)
                if(conditionCol(i)) %normal column
                    cellclass = cellfun('isclass',testStudy.subjectInfo(:,i),'char');
                    if(any(cellclass))
                        cTypeDouble = false;
                    else
                        cellclass = cellfun('isclass',testStudy.subjectInfo(:,i),'double');
                        cTypeDouble = true;
                    end
                    if(~all(cellclass))
                        %not all elemtents are double -> convert them
                        idx = find(~cellclass);
                        for j = 1:length(idx)
                            if(cTypeDouble)
                                testStudy.subjectInfo(idx(j),i) = {double(testStudy.subjectInfo{idx(j),i})};
                            else
                                testStudy.subjectInfo(idx(j),i) = {char(testStudy.subjectInfo{idx(j),i})};
                            end
                        end
                        dirty = true;
%                     elseif(all(cellclass) && ~cTypeDouble)
%                         %check if we can convert all chars to double
%                         %testDouble = zeros(size(cellclass));
%                         cellempty = cellfun('isempty',testStudy.subjectInfo(:,i));
%                         testStr = [testStudy.subjectInfo{:,i}];
%                         testStr(isstrprop(testStr,'punct')) = '.';
%                         testStr(isstrprop(testStr,'wspace')) = '0';
%                         testDouble = zeros(size(cellclass));
%                         converted = str2num(testStr);
%                         if(length(converted) == sum(~cellempty))
%                             testDouble(~cellempty) = converted;
%                             if(any(testDouble) && all(~isnan(testDouble)) && length(testDouble) == length(cellclass))
%                                 testStudy.subjectInfo(:,i) = num2cell(testDouble);
%                                 dirty = true;
%                             end
%                         end
                    end
                else %condition colum
                    %not all elemtents are logical -> convert them
                    cellclass = cellfun('isclass',testStudy.subjectInfo(:,i),'logical');
                    if(~all(cellclass))
                        %not all elemtents are logical -> convert them
                        idx = find(~cellclass);
                        for j = 1:length(idx)
                            if(isempty(testStudy.subjectInfo{idx(j),i}))
                                testStudy.subjectInfo(idx(j),i) = {false(1,1)};
                            else
                                testStudy.subjectInfo(idx(j),i) = {logical(testStudy.subjectInfo{idx(j),i})};
                            end
                        end
                        dirty = true;
                    end
                end
            end            
            %check content of subjectInfoColumnNames
            if(isempty(testStudy.subjectInfoColumnNames))
                %no element --> add first info header
                testStudy.subjectInfoColumnNames(1,1) = {'column 1'};
                testStudy.subjectInfoConditionDefinition(1,1) = {[]};
                testStudy.subjectInfo(:,1) = cell(max(1,size(testStudy.subjectInfo,1)),1);
                dirty = true;
            else
                %column header exist -> check names
                for i = 1:length(testStudy.subjectInfoColumnNames)
                    if(isempty(testStudy.subjectInfoColumnNames{i,1}))
                        %there is no validate name
                        colname = sprintf('column %d',i);
                        testStudy.subjectInfoColumnNames(i,1)= {colname};
                        dirty = true;
                    end
                    %check if we have a corresponding field in subjectInfoConditionDefinition
                    if(length(testStudy.subjectInfoConditionDefinition) < i)
                        testStudy.subjectInfoConditionDefinition(i,1) = cell(1,1);
                        dirty = true;
                    end
                end
            end
            %resultROICoordinates
            if(size(testStudy.resultROICoordinates,2) > 1)
                testStudy.resultROICoordinates = testStudy.resultROICoordinates(:);
                dirty = true;
            end
            tmpLen = length(testStudy.resultROICoordinates);
            if(tmpLen < nrSubjects)
                testStudy.resultROICoordinates(end+1:end+nrSubjects-tmpLen,1) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultROICoordinates = testStudy.resultROICoordinates(1:nrSubjects);
                dirty = true;
            end
            %nonDefaultSizeROICoordinates
            if(size(testStudy.nonDefaultSizeROICoordinates,2) > 1)
                testStudy.nonDefaultSizeROICoordinates = testStudy.nonDefaultSizeROICoordinates(:);
                dirty = true;
            end
            tmpLen = size(testStudy.nonDefaultSizeROICoordinates,1);
            if(tmpLen < nrSubjects)
                testStudy.nonDefaultSizeROICoordinates(end+1:end+nrSubjects-tmpLen,1) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.nonDefaultSizeROICoordinates = testStudy.nonDefaultSizeROICoordinates(1:nrSubjects);
                dirty = true;
            end
            %resultZScaling
            if(size(testStudy.resultZScaling,2) > 1)
                testStudy.resultZScaling = testStudy.resultZScaling(:);
                dirty = true;
            end
            tmpLen = length(testStudy.resultZScaling);
            if(tmpLen < nrSubjects)
                testStudy.resultZScaling(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultZScaling = testStudy.resultZScaling(1:nrSubjects);
                dirty = true;
            end
            %resultColorScaling
            if(size(testStudy.resultColorScaling,2) > 1)
                testStudy.resultColorScaling = testStudy.resultColorScaling(:);
                dirty = true;
            end
            tmpLen = length(testStudy.resultColorScaling);
            if(tmpLen < nrSubjects)
                testStudy.resultColorScaling(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultColorScaling = testStudy.resultColorScaling(1:nrSubjects);
                dirty = true;
            end
            %resultCrossSection
            if(size(testStudy.resultCrossSection,2) > 1)
                testStudy.resultCrossSection = testStudy.resultCrossSection(:);
                dirty = true;
            end
            tmpLen = length(testStudy.resultCrossSection);
            if(tmpLen < nrSubjects)
                testStudy.resultCrossSection(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultCrossSection = testStudy.resultCrossSection(1:nrSubjects);
                dirty = true;
            end
            %all FLIMItems
            nrChannels = size(testStudy.resultFileChs,2);
            tmpLen = size(testStudy.allFLIMItems,2);
            if(tmpLen < nrChannels)
                testStudy.allFLIMItems(:,end+1:end+nrChannels-tmpLen) = cell(nrSubjects,nrChannels-tmpLen);
                idx = ~cellfun('isempty',testStudy.resultFileChs(:,1)); %assume channel 1 as reference
                testStudy.allFLIMItems(idx,tmpLen+1:nrChannels) = repmat(testStudy.allFLIMItems(idx,1),1,nrChannels-tmpLen);
                dirty = true;
            elseif(tmpLen > nrChannels)
                testStudy.allFLIMItems = testStudy.allFLIMItems(:,1:nrChannels);
                dirty = true;
            end
            tmpLen = size(testStudy.allFLIMItems,1);
            if(tmpLen < nrSubjects)
                testStudy.allFLIMItems(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,nrChannels);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.allFLIMItems = testStudy.allFLIMItems(1:nrSubjects,:);
                dirty = true;
            end
            %             [testStudy.allFLIMItems,dTmp] = studyIS.checkFLIMItems(testStudy.allFLIMItems);
            %             dirty = dirty || dTmp;
            %condition colors            
            newColors = setdiff(testStudy.subjectInfoColumnNames(~conditionCol,1),testStudy.conditionColors(1,:));
            for i = 1:length(newColors)
                testStudy.conditionColors(1,end+1) = newColors(i);
                testStudy.conditionColors(2,end) = {FDTStudy.makeRndColor()};
            end
            delColors = setdiff(testStudy.conditionColors(1,:),testStudy.subjectInfoColumnNames(~conditionCol,1));
            delColors = delColors(~strcmp(delColors,FDTree.defaultConditionName()));
            for i = 1:length(delColors)
                idx = find(strcmp(delColors{i},testStudy.conditionColors(1,:)), 1);
                if(~isempty(idx))
                    testStudy.conditionColors(:,idx) = [];
                end
            end
            if(~isempty(newColors) || ~isempty(delColors))
                dirty = true;
            end
            if(isempty(testStudy.conditionColors))
                %set color for "default" condition
                testStudy.conditionColors(1,1) = {FDTree.defaultConditionName()};
                testStudy.conditionColors(2,1) = {FDTStudy.makeRndColor()};
                dirty = true;
            end            
        end
        
        %         function [FLIMItems,dirty] = checkFLIMItems(FLIMItems)
        %             %check and repair FLIMItems cell array
        %             dirty = false;
        %             if(length(FLIMItems)>1)
        %                 t1 = FLIMItems(:,1);
        %                 t2 = FLIMItems;
        %                 t2(1:end,1) = {[]};
        %                 %create correct cell array
        %                 FLIMItems = cell(size(FLIMItems,1)...
        %                     +size(FLIMItems,2)-1,1);
        %                 FLIMItems(1:length(t1),1) = t1;
        %                 %move corrupt data entrys
        %                 dn = ~cellfun('isempty',t2);
        %                 loc = find(dn);     %find positions of corrupt entrys
        %                 if(~isempty(loc))
        %                     for i=1:length(loc)
        %                         FLIMItems(loc(i),1) = t2(loc(i));
        %                     end
        %                 end
        %                 dirty = true;
        %             end
        %         end
        
        function [op, neg, opWeight] = str2logicOp(str)
            %convert a (descriptive) string to a logical operand
            neg = '';
            opWeight = inf;
            switch str
                case {'-no op-','-none-'} %no combination
                    op = '';
                case 'AND'
                    op = '&';
                    opWeight = 4;
                case 'OR'
                    op = '|';
                    opWeight = 5;
                case '!AND'
                    op = '&';
                    neg = '~';
                    opWeight = 4;
                case '!OR'
                    op = '|';
                    neg = '~';
                    opWeight = 5;
                case 'XOR'
                    op = 'xor';
                    neg = '';
                    opWeight = 1;
                case {'+','-','.*','./'}
                    op = str;
                    opWeight = 2;
                case '!='
                    op = '~=';
                    neg = '';
                    opWeight = 3;
                otherwise % <,<=,>,>=,==
                    op = str;
                    opWeight = 3;
            end
        end
        
        function out = makeRndColor()
            %generate random RGB color from jet colormap
            tmp = jet(256);
            out = tmp(round(rand*255+1),:);
        end
        
        function ROICoord = insertResultROIType(ROICoord,ROIType)
            %add an empty ROIType
            if(isempty(ROICoord))
                ROICoord = ROICtrl.getDefaultROIStruct();
            end
            [val,idx] = min(abs(ROICoord(:,1,1) - ROIType));
            if(val > 0)
                tmpNew = zeros(size(ROICoord,1)+val,size(ROICoord,2),size(ROICoord,3),'int16');
                tmpNew(1:idx,:,:) = ROICoord(1:idx,:,:);
                tmpNew(idx+val+1:end,:,:) = ROICoord(idx+1:end,:,:);
                tmpNew(idx+1:idx+val,1,1) = (ROICoord(idx,1,1)+1 : 1 : ROICoord(idx,1,1)+val)';
                ROICoord = tmpNew;
            end
        end
    end %methods(static)
end %classdef