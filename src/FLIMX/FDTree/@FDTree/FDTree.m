classdef FDTree < FDTreeNode
    %=============================================================================================================
    %
    % @file     FDTree.m
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
    % @brief    A class to handle FLIMX studies and subjects
    %
    properties(SetAccess = protected,GetAccess = protected)
        myFileLock = [];
        myDir = '';             %FDTree's working directory
        myConditionsMerged = [];     %global statistics and global MVGroup objects
        myGlobalMVGroupTargets = [];  %global MVGroup targets        
        cancelFlag = false; %flag to stop an operation
        LRUTableObjs = cell(0,1);
        LRUTableInfo = [];
        myMaxMemoryCacheSize = 250e6;
        dataSmoothAlgorithm = 0; %select data smoothing algorithm
        dataSmoothParameters = 1; %parameters for data smoothing algorithm
        shortProgressCb = cell(0,0); %list of callback functions for progressbar update (short)
        longProgressCb = cell(0,0); %list of callback functions for progressbar update (long)
        studyMgrProgressCb = cell(0,0); %callback function for progressbar update of study manager
    end    
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
        maxMemoryCacheSize = 0;
        hashEngine = [];        
    end
    
    methods
        function this = FDTree(parent,rootDir)
            % Constructor for FDTree
            this = this@FDTreeNode(parent,'FDTRoot');
            this.myDir = fullfile(rootDir,'studyData');
            if(~isfolder(this.myDir))
                [status, message, ~] = mkdir(this.myDir);
                if(~status)
                    error('FLIMX:FDTree:createStudyDataFolder','Could not create studyData folder: %s\n%s',this.myDir,message);
                end
            end
            %try to establish the lock file
            this.myFileLock = fileLock(fullfile(this.myDir,'file.lock'));
            if(~this.myFileLock.isLocked)
                delete(this.myFileLock);
                error('FLIMX:FDTree:fileLock','Could not establish file lock for database');
            end
            this.myConditionsMerged = FDTSubject(this,'GlobalMergedSubjects');
            this.myGlobalMVGroupTargets = LinkedList();
            try
                this.setShortProgressCallback(@parent.updateSplashScreenShortProgress);
            end
            this.scanForStudies();
            if(this.nrChildren == 0)
                %add default study as container for not assigned subjects
                this.addStudy('Default');
            end
        end

        function pingLRUCacheTable(this,obj)
            %ping LRU table for object obj
            %find obj in LRU table
            t = FLIMX.now();
            if(isempty(this.LRUTableObjs))
                this.LRUTableObjs(1,1) = {obj};
                this.LRUTableInfo(1,1:3) = [obj.uid,t,obj.getCacheMemorySize()];
            else
                id = abs(obj.uid - this.LRUTableInfo(:,1)) < eps;
                if(any(id))
                    %there should be only one hit in the list
                    this.LRUTableInfo(id,2:3) = [t,obj.getCacheMemorySize()];
                else
                    %obj not found -> add obj to list
                    id = size(this.LRUTableObjs,1) + 1;
                    this.LRUTableObjs(id,1) = {obj};
                    this.LRUTableInfo(id,1:3) = [obj.uid,t,obj.getCacheMemorySize()];
                end
            end
            %delete zero sized object from list
            idx = this.LRUTableInfo(:,3) == 0;
            this.LRUTableObjs(idx,:) = [];
            this.LRUTableInfo(idx,:) = [];
            this.checkLRUCacheTableSize(this.myMaxMemoryCacheSize);
        end
        
        function checkLRUCacheTableSize(this,threshold)
            %check size of cached data and remove objects from RAM if necessary
            %check total size
            if(isempty(this.LRUTableInfo) || size(this.LRUTableInfo,1) == 1)
                %nothing to do if table is empty and don't clear last element
                return
            end
            while(sum(this.LRUTableInfo(:,3)) > threshold)
                %for i = 1:size(this.LRUTableObjs,1)-1
                %find oldest entry
                [~, id] = min([this.LRUTableInfo(:,2)]);
                obj = this.LRUTableObjs{id,1};
                if(obj.isvalid)
                    obj.clearCacheMemory(); %free RAM
                end
                this.LRUTableObjs(id,:) = []; %remove obj from table
                this.LRUTableInfo(id,:) = []; %remove objs info from table
                if(size(this.LRUTableInfo,1) == 1)
                    %keep at least one entry (the just added obj)
                    break
                end
            end
        end
        
        function [entrySizes, total] = getLRUCacheTableSize(this)
            %get the current size of the cache memory
            entrySizes = this.LRUTableInfo(:,3);
            total = sum(entrySizes(:));
        end
        
        function removeObj(this,studyID,subjectID,chan,dType,id)
            %remove object from subject
            study = this.getChild(studyID);
            if(~isempty(study))
                study.removeObj(subjectID,chan,dType,id);
                this.removeObjMerged();
            end
        end
        
        function deleteChannel(this,studyID,subjectID,ch,type)
            %delete result or measurement channel of a subject (or both if type is empty)
            study = this.getChild(studyID);
            if(~isempty(study))
                study.deleteChannel(subjectID,ch,type);
                this.removeObjMerged();
            end
        end
        
        function removeSubjectResult(this,studyID,subjectID)
            %remove all results of a subject
            study = this.getChild(studyID);
            if(~isempty(study))
                study.deleteChannel(subjectID,[],'result');
                this.removeObjMerged();
            end
        end
        
        function removeSubject(this,studyID,subjectID)
            %remove a subject
            study = this.getChild(studyID);
            if(~isempty(study))
                study.removeSubject(subjectID);
                this.removeObjMerged();
            end
        end
        
        function removeMVGroup(this,studyID,MVGroupID)
            %
            study = this.getChild(studyID);
            if(~isempty(study))
                study.removeMVGroup(MVGroupID);
            end
        end
        
        function removeStudy(this,studyID)
            %delete a study
            [study, studyID] = this.getChild(studyID);
            if(~isempty(study) && ~strcmp(study.name,'Default'))
                %don't remove default study
                try
                    [status, message, messageid] = rmdir(study.myDir,'s');
                catch ME
                    
                end
                %todo: error handling
                this.deleteChildByPos(studyID);
                this.removeObjMerged();
            end
        end
        
        function removeObjMerged(this)
            %remove merged FData objects
            this.myConditionsMerged = [];
            this.myConditionsMerged = FDTSubject(this,'GlobalMergedSubjects');
        end
        
        function updateShortProgress(this,prog,text)
            %update the progress bar of a short operation
            for i = length(this.shortProgressCb):-1:1
                try
                    this.shortProgressCb{i}(prog,text);
                catch
                    this.shortProgressCb{i} = [];
                end
            end
        end
        
        function updateLongProgress(this,prog,text)
            %update the progress bar of a long operation consisting of short ops
            for i = length(this.longProgressCb):-1:1
                try
                    this.longProgressCb{i}(prog,text);
                catch
                    this.longProgressCb{i} = [];
                end
            end
        end
        
        function updateStudyMgrProgress(this,prog,text)
            %update the progress bar of study manager
            try
                this.studyMgrProgressCb(prog,text);
            catch
            end
        end
        
        %% input functions
        function study = addStudy(this,name)
            %add a study to FDTree
            %make sure name is valid
            name = studyMgr.checkFolderName(name);            
            study = this.getChild(name);
            if(~isempty(study))
                %study alread in tree
                return
            end            
            this.addChildByName(FDTStudy(this,name),name);
            %try to load the study data
            study = this.getChild(name);
            if(isempty(study))
                return
            end
        end
        
        function loadStudy(this,studyID)
            % (re)load study (used by studyMgr)
            study = this.getChild(studyID);
            if(~isempty(study))
                study.load();
            end
        end
        
        function importStudy(this,newStudyName,fn)
            %import study from export file(s)
            %check if we have this study already
            if(any(strcmpi(this.getAllStudyNames,newStudyName)))
                %ask user
                return
            end
            studyDir = fullfile(this.myDir,newStudyName);
            if(isfolder(studyDir))
                [status, message, ~] = mkdir(studyDir);
                if(~status)
                    error('FLIMX:FDTree:importStudy','Could not create study folder: %s\n%s',studyDir,message);
                end
            end
            if(~iscell(fn))
                fn = {fn};
            end
            for i = 1:length(fn)
                %load all files without any sanity checks
                unzip(fn{i},studyDir)
            end
            %check studyData.mat
            sdFile = fullfile(studyDir,'studyData.mat');
            if(isfile(sdFile))
                export = load(sdFile,'-mat');
                export = export.export;
                if(~strcmp(export.name,newStudyName))
                    %update study name
                    export.name = newStudyName;
                    save(sdFile,'export','-mat');
                end
            end
            this.addStudy(newStudyName);            
        end
        
        function addSubject(this,studyID,subjectID)
            %add empty subject by studyMgr
            subjectID = studyMgr.checkFolderName(subjectID);
            study = this.getChild(studyID);
            if(~isempty(study))
                study.addSubject(subjectID);
            end
        end
        
        function setDataSmoothFilter(this,alg,params)
            %set filtering method to smooth data
            if(alg ~= this.dataSmoothAlgorithm || params ~= this.dataSmoothParameters)
                %clear all current images to force (re-)filtering
                this.clearAllFIs([]);
                %todo: if percentages, qs, taumeans should be computed on filtered data we have to recompute them here...
                this.dataSmoothAlgorithm = alg;
                this.dataSmoothParameters = params;
            end
        end
        
        function setCancelFlag(this,val)
            %if true stop current operation
            this.cancelFlag = logical(val);
        end
        
        function setShortProgressCallback(this,cb)
            %set callback function for short progress bar
            this.shortProgressCb(end+1) = {cb};
        end
                
        function setLongProgressCallback(this,cb)
            %set callback function for long progress bar
            this.longProgressCb(end+1) = {cb};
        end
        
        function setStudyMgrProgressCb(this,cb)
            %set callback function for study manager progress bar
            this.studyMgrProgressCb = cb;
        end
        
        function setSubjectName(this,studyID,subjectID,val)
            %set subject name
            if(isempty(val))
                return
            end
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setSubjectName(subjectID,val);
            end
        end
        
        function setStudyMVGroupTargets(this,studyID,MVGroupID,val)
            %set multivariate targets
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setMVGroupTargets(MVGroupID,val);
            end
        end
        
        function setGlobalMVGroupTargets(this,MVGroupID,targets)
            %set global MVGroup targets, i.e. selected study conditions
            MVGroupTargets.name = MVGroupID;
            MVGroupTargets.targets = targets;
            this.myGlobalMVGroupTargets.insertID(MVGroupTargets,MVGroupID);
            %clear old MVGroup object
            this.myConditionsMerged.clearAllRIs(sprintf('Global%s',MVGroupID));
        end
        
        function setMVGroupName(this,studyID,MVGroupID,val)
            %set MVGroup name
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setMVGroupName(MVGroupID,val);
            end
            %change ID of global MVGroup
            this.myGlobalMVGroupTargets.changeID(MVGroupID,val);
        end
                
        function clearSubjectCI(this,studyID,subjectID)
            %clear current images (result ROI) of a subject
            study = this.getChild(studyID);
            if(~isempty(study))
                study.clearSubjectCI(subjectID);
            end
        end
        
        function clearAllCIs(this,dType)
            %clear current images of datatype dType in all subjects
            clearAllCIs@FDTreeNode(this,dType);
%             for i = 1:this.myStudies.queueLen
%                 this.myStudies.getDataByPos(i).clearAllCIs(dType);
%             end
            this.myConditionsMerged.clearAllCIs(dType);
        end
        
        function clearAllFIs(this,dType)
            %clear filtered raw images of datatype dType in all subjects
            clearAllFIs@FDTreeNode(this,dType);
%             for i = 1:this.myStudies.queueLen
%                 this.myStudies.getDataByPos(i).clearAllFIs(dType);
%             end
            this.myConditionsMerged.clearAllFIs(dType);
        end
        
        function clearAllRIs(this,studyID,dType)
            %clear raw images of datatype dType in all subjects in a study
            study = this.getChild(studyID);
            if(~isempty(study))
                study.clearAllRIs(dType);
                if(strncmp(dType,'MVGroup',7))
                    %clear corresponding global MVGroup object
                    globalMVGroupID = sprintf('Global%s',dType);
                    this.myConditionsMerged.clearAllRIs(globalMVGroupID);
                end
            end
        end
        
        function clearAllMVGroupIs(this)
            %clear data of all MVGroups in all subjects
            clearAllMVGroupIs@FDTreeNode(this); 
            this.myConditionsMerged.clearAllRIs('');
        end
        
%         function clearArithmeticRIs(this,studyID)
%             %clear raw images of arithmetic images in a study
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 study.clearArithmeticRIs();
%             end
%         end
        
        function clearMVGroups(this,studyID,subjectID,dType,dTypeNr)
            %clear MVGroups if ROI changes
            study = this.getChild(studyID);
            if(~isempty(study))
                study.clearMVGroups(subjectID,dType,dTypeNr);
            end
        end
        
        function setResultROIGroup(this,studyName,grpName,grpMembers)
            %set the ROI group members for this study  
            study = this.getChild(studyName);
            if(~isempty(study))
                study.setResultROIGroup(grpName,grpMembers);
            end
        end
                
        function setResultROICoordinates(this,studyName,subjectID,dType,dTypeNr,ROIType,ROICoord)
            %set the ROI coordinates for study studyName at subject subjectID and ROIType
            study = this.getChild(studyName);
            if(~isempty(study))
                study.setResultROICoordinates(subjectID,dType,dTypeNr,ROIType,ROICoord);
%                 this.clearGlobalObjMerged(dType);
            end
        end
        
        function deleteResultROICoordinates(this,studyName,dType,dTypeNr,ROIType)
            %delete the ROI coordinates for study studyName at subject subjectID and ROIType
            study = this.getChild(studyName);
            if(~isempty(study))
                study.deleteResultROICoordinates(dType,dTypeNr,ROIType);
            end
        end
        
        function setResultZScaling(this,studyName,subjectID,ch,dType,dTypeNr,zValues)
            %set the z scaling for study studyName at subject subjectID and ROIType
            study = this.getChild(studyName);
            if(~isempty(study))
                study.setResultZScaling(subjectID,ch,dType,dTypeNr,zValues);
%                 this.clearGlobalObjMerged(dType);
            end
        end
        
        function setResultColorScaling(this,studyName,subjectID,ch,dType,dTypeNr,colorBorders)
            %set the z scaling for study studyName at subject subjectID and ROIType
            study = this.getChild(studyName);
            if(~isempty(study))
                study.setResultColorScaling(subjectID,ch,dType,dTypeNr,colorBorders);
            end
        end
        
        function setResultCrossSection(this,studyName,subjectID,dim,csDef)
            %set the cross section for study studyName at subject subjectID and dimension dim
            study = this.getChild(studyName);
            if(~isempty(study))
                study.setResultCrossSection(subjectID,dim,csDef);
            end
        end
                
        function setStudyName(this,studyID,newStudyName)
            %set new study name
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setName(newStudyName);
            end
            this.renameChild(studyID,newStudyName);
        end
        
        function addSubjectInfoColumnNames(this,destinationStudyName,originStudyName)
            %add column names from origin to destination study
            destStudy = this.getChild(destinationStudyName);
            originStudy = this.getChild(originStudyName);
            if(~isempty(destStudy) && ~isempty(originStudy))
                %check and update conditional columns
                newInfoCombi = originStudy.getSubjectInfoConditionalColumnDefinitions();
                oldInfoCombi = destStudy.getSubjectInfoConditionalColumnDefinitions();
                orgInfoHeads = originStudy.getDataFromStudyInfo('subjectInfoAllColumnNames');
                destInfoHeads = destStudy.getDataFromStudyInfo('subjectInfoAllColumnNames');                
                %check subjectInfoHeaders and add new
                newHeaders = setdiff(orgInfoHeads,destInfoHeads);
                if(~isempty(newHeaders))
                    %add new columns at table end
                    for i = 1:length(newHeaders)
                        destStudy.addColumn(newHeaders{i});
                    end
                end
                overWriteAllFlag = false;
                for i = 1:length(orgInfoHeads)
                    condName = orgInfoHeads{i};
                    [tf, idx] = ismember(condName,destInfoHeads);
                    if(tf && ~isempty(oldInfoCombi{idx}))
                        %a condition matches -> check if the definition is identical
                        newCol = newInfoCombi{i};
                        oldCol = oldInfoCombi{idx};
                        identFlag = strcmp(newCol.colA,oldCol.colA) && strcmp(newCol.colB,oldCol.colB) && strcmp(newCol.logOp,oldCol.logOp)...
                            && strcmp(newCol.relA,oldCol.relA) && strcmp(newCol.relB,oldCol.relB)...
                            && all(newCol.valA == oldCol.valA) && all(newCol.valB == oldCol.valB);
                        if(~identFlag && ~overWriteAllFlag)
                            choice = questdlg(sprintf('Condition ''%s'' already exists in study ''%s'' but is different from study ''%s''.\n\nDo you want to overwrite the definition in study ''%s''?',...
                                condName,destinationStudyName,originStudyName,destinationStudyName),'Inserting Conditional Column','Yes','All','No','Yes');
                            switch choice
                                case 'All'
                                    overWriteAllFlag = true;
                                case 'No'
                                    %keep old condition
                                    newInfoCombi(i) = oldInfoCombi(idx);
                            end
                        end
                    end
                end
                %set merged conditional columns
                for i = 1:length(orgInfoHeads)
                    condName = orgInfoHeads{i};
                    [~, idx] = ismember(condName,destStudy.getDataFromStudyInfo('subjectInfoAllColumnNames'));
                    destStudy.setSubjectInfoConditionalColumnDefinition(newInfoCombi(i),idx);
                end
            end
        end
        
        function copySubject(this,originStudy,oldSubjectID,destinationStudy,newSubjectID)
            %insert subjects from origin in destination study
            destStudy = this.getChild(destinationStudy);
            orgStudy = this.getChild(originStudy);
            if(~isempty(destStudy) && ~isempty(orgStudy))
                %check subject
                if(~isempty(this.getSubjectNr(destinationStudy,newSubjectID)))
                    %this is already subject
                    uiwait(errordlg(sprintf('Subject "%s" is already existent in this Study!',newSubjectID),...
                        'Error inserting Subject','modal'));
                else
                    %data to copy
                    data = orgStudy.makeInfoSetExportStruct(oldSubjectID);
                    data.subjects = {newSubjectID};
                    subjectObj = destStudy.insertSubject(newSubjectID,data);                    
                    %copy Data for FLIMXVisGUI
                    oldpath = fullfile(orgStudy.myDir,oldSubjectID);
                    newpath = fullfile(destStudy.myDir,newSubjectID);
                    if(isfolder(oldpath))
                        copyfile(oldpath,newpath);
                    end
                    subjectObj.reset();
                end
            end
        end
        
        function copySubjectROI(this,originStudy,destinationStudy,subjectID)
            %copy ROI corrdinates of a subject from one study to another (if subject exists there)
            orgStudy = this.getChild(originStudy);
            if(~orgStudy.isLoaded)
                orgStudy.load();
            end
            destStudy = this.getChild(destinationStudy);
            if(~destStudy.isLoaded)
                destStudy.load();
            end
            if(~isempty(destStudy) && ~isempty(orgStudy))
                %check if subjects exist in studies 
                orgSubject = orgStudy.getChild(subjectID);
                destSubject = destStudy.getChild(subjectID);
                if(~isempty(orgSubject) && ~isempty(destSubject))
                    %get all ROI coordinates from source
                    ROICoord = orgStudy.getResultROICoordinates(subjectID,[]);
                    %set all ROI coordinates in destination
                    destStudy.setResultROICoordinates(subjectID,'Amplitude',1,[],ROICoord);
                end
            end
        end
        
        function setSubjectInfoColumnName(this,studyID,newColumnName,idx)
            %give column at idx in study a new name
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setSubjectInfoColumnName(newColumnName,idx);
            end
        end
        
        function importStudyInfo(this,studyName,file,mode)
            %import study info (subject info table) from excel file
            study = this.getChild(studyName);
            if(~isempty(study))
                study.importStudyInfo(file,mode);
            end
        end
        
        function importSubject(this,subjectObj)
            %import a new subject object (and possibly study)
            study = this.getChild(subjectObj.getStudyName());
            if(isempty(study))
                study = this.addStudy(subjectObj.getStudyName());
            end
            if(~isempty(study))
                study.importSubject(subjectObj);
            end
        end
        
        function unloadAllChannels(this)
            %remove all channels in all subjects in all studies from memory
            studyNames = this.getAllStudyNames();
            tStart = now;
            lastUpdate = tStart;
            oneSec = 1/24/60/60;
            for i = 1:length(studyNames)
                tNow = FLIMX.now();
                study = this.getChild(studyNames{i});
                if(~isempty(study))
                    study.unloadAllChannels();
                end
                if(tNow-lastUpdate > oneSec)
                    [~, minutes, secs] = secs2hms((tNow-tStart)/oneSec/i*(length(studyNames)-i)); %mean cputime for finished runs * cycles left
                    this.updateLongProgress(i/length(studyNames),sprintf('%d%% - unloading studies: %dmin %dsec',round(100*i/length(studyNames)),round(minutes),round(secs)));
                    lastUpdate = tNow;
                end
            end
            this.updateLongProgress(0,'');
        end
        
%         function updateSubjectChannel(this,subjectObj,ch,flag)
%             %update a specific channel of a subject, flag signalizes 'measurement', 'result' or '' for both
%             study = this.getChild(subjectObj.getStudyName());
%             if(isempty(study))
%                 study = this.addStudy(subjectObj.getStudyName());
%             end
%             if(~isempty(study))
%                 study.updateSubjectChannel(subjectObj,ch,flag);
%                 %study.removeResultChannelFromMemory(subjectID,ch);
%                 this.removeObjMerged();
%             end            
%         end
        
%         function importResultStruct(this,studyName,subjectName,import,itemsTarget)
%             %import a new subject (and possibly study)
%             study = this.getChild(studyName);
%             if(isempty(study))
%                 study = this.addStudy(studyName);
%             end
%             if(~isempty(study))
%                 study.importResultStruct(subjectName,import,itemsTarget);
%                 this.removeObjMerged();
%             end
%         end
%         
%         function importResultObj(this,studyName,subjectName,resultObj)
%             %import a result of a new subject (and possibly study)
%             study = this.getChild(studyName);
%             if(isempty(study))
%                 study = this.addStudy(studyName);
%             end
%             if(~isempty(study))
%                 study.importResultObj(resultObj,subjectName);
%                 this.removeObjMerged();
%             end
%         end
%         
%         function importMeasurementObj(this,fluoFileObj)
%             %import a measurement of a new subject (and possibly study)
%             study = this.getChild(fluoFileObj.getStudyName());
%             if(isempty(study))
%                 study = this.addStudy(fluoFileObj.getStudyName());
%             end
%             if(~isempty(study))
%                 study.importMeasurementObj(fluoFileObj);
% %                 this.removeObjMerged();
%             end
%         end
        
        function addColumn(this,studyID,name)
            %add column to study info data
            study = this.getChild(studyID);
            if(~isempty(study))
                study.addColumn(name);
            end
        end
        
        function addConditionalColumn(this,studyID,val)
            %add new conditional column with definition val
            study = this.getChild(studyID);
            if(~isempty(study))
                study.addConditionalColumn(val);
            end
        end
        
        function setConditionalColumnDefinition(this,studyID,colName,val)
            %set definition for conditional column in study
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setConditionalColumnDefinition(colName,val);
            end
        end
        
        function removeColumn(this,studyID,colName)
            %
            study = this.getChild(studyID);
            if(~isempty(study))
                study.removeColumn(colName);
            end
        end
        
        function setSubjectInfo(this,studyID,irow,icol,newData)
            %
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setSubjectInfo(irow,icol,newData);
            end
        end
        
        function setArithmeticImageDefinition(this,studyID,aiName,aiParam)
            %set name and definition of arithmetic image for a study
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setArithmeticImageDefinition(aiName,aiParam);
                this.clearAllMVGroupIs();
            end
        end
        
        function removeArithmeticImageDefinition(this,studyID,aiName)
            %remove arithmetic image for a study
            study = this.getChild(studyID);
            if(~isempty(study))
                study.removeArithmeticImageDefinition(aiName);
            end
        end
        
        function setConditionColor(this,studyID,cName,val)
            %set condition color in study
            study = this.getChild(studyID);
            if(~isempty(study))
                study.setConditionColor(cName,val);
            end
            str = this.getGlobalMVGroupNames();
            for i = 1:length(str)
                globalMVGroupID = sprintf('Global%s',str{i});
                this.myConditionsMerged.clearAllRIs(globalMVGroupID);
            end
        end
        
        %% output functions        
        function saveStudy(this,studyID)
            %save study with studyID
            study = this.getChild(studyID);
            if(~isempty(study))
                study.save();
            end
        end
        
        function out = getWorkingDirectory(this)
            % get root directory of FDTree
            out = this.myDir;
        end
        
        function out = getFDataObj(this,studyID,subjectID,chan,dType,id,sType)
            %get FData object
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getFDataObj(subjectID,chan,dType,id,sType);
            else
                out = [];
            end
        end        
        
        function out = getSubject4Approx(this,studyID,subjectID,createNewSubjectFlag)
            %get subject object for approximation which includes measurements and results
            study = this.getChild(studyID);
            if(isempty(study) && createNewSubjectFlag)
                study = this.addStudy(studyID);
            elseif(isempty(study) && ~createNewSubjectFlag)
                out = [];
                return
            end
            out = study.getSubject4Approx(subjectID,createNewSubjectFlag);
        end
        
        function out = getSubject4Import(this,studyID,subjectID)
            %get subject object to import measurements or results
            studyID = studyMgr.checkFolderName(studyID);
            subjectID = studyMgr.checkFolderName(subjectID);
            if(isempty(studyID) || isempty(subjectID))
                out = [];
                return
            end
            study = this.getChild(studyID);
            if(isempty(study))
                study = this.addStudy(studyID);
            end            
            out = study.getSubject4Import(subjectID);
        end
        
%         function out = getGlobalObjMerged(this,chan,dType,id,ROIType,ROISubType,ROIVicinity)
%             %get merged subjectDS of all studies
%             out = this.myConditionsMerged.getFDataObj(chan,dType,id,1);
%             if(isempty(out))
%                 %try to merge subjects
%                 this.makeGlobalObjMerged(chan,dType,id,ROIType,ROISubType,ROIVicinity);
%                 out = this.myConditionsMerged.getFDataObj(chan,dType,id,1);
%             end
%         end
        
        function out = getGlobalMVGroupObj(this,chan,dType,sType)
            %get global scatter plot object
            out = this.myConditionsMerged.getFDataObj(chan,dType,0,sType);
            if(isempty(out))
                %try to make global MVGroup
                MVGroupID = dType(7:end);
                [cimg, lblx, lbly, ~, colors, logColors] = this.makeGlobalMVGroupObj(chan,MVGroupID);
                %add MVGroup
                this.myConditionsMerged.addObjID(0,chan,dType,0,cimg);
                out = this.myConditionsMerged.getFDataObj(chan,dType,0,sType);
                if(length(lblx) >= 2)
                    out.setupXLbl(lblx(1),lblx(2)-lblx(1));
                end
                if(length(lbly) >= 2)
                    out.setupYLbl(lbly(1),lbly(2)-lbly(1));
                end
                %out.setLblX(lblx);
                %out.setLblY(lbly);
                out.setColor_data(colors,logColors);
            end
        end
        
        function out = getStudyObjMerged(this,studyID,cName,chan,dType,id,sType,ROIType,ROISubType,ROIVicinity)
            %get merged subjectDS of a certain study
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getFDataMergedObj(cName,chan,dType,id,sType,ROIType,ROISubType,ROIVicinity);
            else
                out = [];
            end
        end
        
        %         function out = getStudyObjs(this,studyID,cName,chan,dType,id)
        %             %get all objects of datatype dType from a study
        %             study = this.getChild(studyID);
        %             if(~isempty(study))
        %                 out = study.getStudyObjs(cName,chan,dType,id);
        %             else
        %                 out = [];
        %             end
        %
        %         end
        
%         function [nr, study] = getStudyNr(this,name)
%             %get study number
%             [study,nr] = this.myStudies.getDataByID(name);
%             for nr=1:this.myStudies.queueLen
%                 study = this.myStudies.getDataByPos(nr);
%                 if(strcmp(name,study.name))
%                     return
%                 end
%             end
%             nr = [];
%             study = [];
%         end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end
        
        function out = getNrStudies(this)
            % get number of studies in FDTree
            out = this.getNrOfChildren();
        end
        
        function out = getAllStudyNames(this)
            % get string of all studies
            out = this.getNamesOfAllChildren();
        end
        
        function out = getStudyConditionsStr(this,studyID)
            % get conditions of study
            study = this.getChild(studyID);
            if(isempty(studyID) || ~isa(study,'FDTStudy'))
                out = FDTree.defaultConditionName();
                return
            end
            out = [{FDTree.defaultConditionName()}; study.getDataFromStudyInfo('subjectInfoConditionalColumnNames');];
        end
                
        function out = getSubjectName(this,studyID,subjectID)
            %get subject name
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getSubjectName(subjectID);
            else
                out = [];
            end
        end
        
        function out = getSubjectNr(this,studyID,name)
            %get subject nr
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getSubjectNr(name);
            else
                out = [];
            end
        end
        
        function [measurementChs, resultChs] = getSubjectFilesStatus(this,studyID,subjectID)
            %returns which channels are available for a subject in a study
            study = this.getChild(studyID);
            if(~isempty(study))
                [measurementChs, resultChs] = study.getSubjectFilesStatus(subjectID);
            else
                measurementChs = [];
                resultChs = [];
            end            
        end
        
        function out = getStudyMVGroupTargets(this,studyID,MVGroupID)
            %get multivariate targets
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getMVGroupTargets(MVGroupID);
            else
                out = [];
            end
        end
        
        function out = getGlobalMVGroupTargets(this,MVGroupID)
            %get global MVGroup targets, i.e. selected study Conditions
            out = [];
            MVGroupTargets = this.myGlobalMVGroupTargets.getDataByID(MVGroupID);
            if(isempty(MVGroupTargets))
                return
            end
            out = MVGroupTargets.targets;
        end
        
        function str = getGlobalMVGroupNames(this)
            %get string with all global MVGroup names if computable
            str = cell(0,1);
            for i=1:this.myGlobalMVGroupTargets.queueLen
                MVGroupTargets = this.myGlobalMVGroupTargets.getDataByPos(i);
                if(size(MVGroupTargets.targets,1) >= 1)
                    cMVs = this.getStudyMVGroupTargets(MVGroupTargets.targets{1,1},MVGroupTargets.name);
                    if(~isempty(cMVs) && ~isempty(cMVs.y))
                        %MVGroup is computable
                        str(end+1,1) = {this.myGlobalMVGroupTargets.getDataByPos(i).name};
                    end
                end
            end
        end
        
        function nr = getNrSubjects(this,studyID,cName)
            %get number of subjects in study with studyID
            study = this.getChild(studyID);
            if(~isempty(study))
                nr = study.getNrSubjects(cName);
            else
                nr = [];
            end
        end
        
        function out = makeStudyInfoSetExportStruct(this,studyID,subjectID)
            %get data from study clipboard
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.makeInfoSetExportStruct(subjectID);
            else
                out = [];
            end
        end
        
        function dStr = getAllSubjectNames(this,studyID,cName)
            %get a string of all subjects
            study = this.getChild(studyID);
            if(~isempty(study))
                dStr = study.getAllSubjectNames(cName);
            else
                dStr = [];
            end
        end
        
        function [str, nrs] = getChStr(this,studyID,subjectID)
            %get a string and numbers of all channels in subject
            study = this.getChild(studyID);
            if(~isempty(study))
                [str, nrs] = study.getChStr(subjectID);
            else
                str = [];
                nrs = [];
            end
        end
        
        function str = getChObjStr(this,studyID,subjectID,ch)
            %get a string of all objects in channel ch in subject
            study = this.getChild(studyID);
            if(~isempty(study))
                str = study.getChObjStr(subjectID,ch);
            else
                str = [];
            end
        end
        
%         function str = getMVGroupNames(this,studyID,subjectID,ch)
%             %get a string of all MVGroup objects in channel ch in subject
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 str = study.getMVGroupNames(subjectID,ch);
%             else
%                 str = [];
%             end
%         end
        
        function out = getHeight(this,studyID,subjectID)
            %get image height in a subject
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getHeight(subjectID);
            else
                out = [];
            end
        end
        
        function out = getWidth(this,studyID,subjectID)
            %get image width in a subject
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getWidth(subjectID);
            else
                out = [];
            end
        end
        
        function out = getResultROIGroup(this,studyID,grpName)
            %return the ROI group names and members for this study 
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getResultROIGroup(grpName);
            else
                out = [];
            end
        end
        
        function [ids, str] = getResultROITypes(this,studyID)
            %return the different ROI types for a study 
            study = this.getChild(studyID);
            if(~isempty(study))
                [ids, str] = study.getResultROITypes();
            else
                ids = [];
                str = '';
            end
        end
        
        function out = getResultROICoordinates(this,studyID,subjectID,ROIType)
            %return ROI coordinates for ROIType in a subject in a study
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getResultROICoordinates(subjectID,ROIType);
            else
                out = [];
            end
        end
        
        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.FLIMXParamMgrObj.roiParams;
        end
                
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            alg = this.dataSmoothAlgorithm ;
            params = this.dataSmoothParameters;
        end  
                        
%         function [centers, histTable] = getGlobalHistogram(this,chan,dType,id)
%             %combine all histograms of channel chan, datatype dType and 'running number' id into a single table
%             hg = this.getGlobalObjMerged(chan,dType,id);
%             if(isempty(hg) || hg.isEmptyStat)
%                 %try to build merged object
%                 this.makeGlobalObjMerged(chan,dType,id);
%                 hg = this.getGlobalObjMerged(chan,dType,id);
%             end
%             if(~isempty(hg))
%                 centers = hg.getCIHistCenters();
%                 histTable = hg.getCIHist();
%             else
%                 centers = []; histTable = [];
%             end
%         end
        
        function [centers, histMerge, histTable, colDescription] = getStudyHistogram(this,studyID,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity)
            %combine all histograms of study studyID, channel chan, datatype dType and 'running number' id into a single table
            study = this.getChild(studyID);
            if(~isempty(study))
                if(nargout == 2)
                    [centers, histMerge] = study.getStudyHistogram(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity);
                else
                    [centers, histMerge, histTable, colDescription] = study.getStudyHistogram(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity);
                end
            else
                centers = []; histTable = []; histMerge = []; colDescription = cell(0,0);
            end
        end
        
        function [stats, statsDesc, subjectDesc] = getStudyStatistics(this,studyID,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,strictFlag)
            %get statistics for all subjects in study studyID, Condition cName and channel chan of datatype dType with 'running number' id
            study = this.getChild(studyID);
            if(~isempty(study))
                [stats, statsDesc, subjectDesc] = study.getStudyStatistics(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,strictFlag);
            else
                stats = []; statsDesc = []; subjectDesc = [];
            end
        end
        
        function data = getStudyPayload(this,studyID,cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,dataProc)
            %get merged payload from all subjects of study studyID, channel chan, datatype dType and 'running number' within a study for a certain ROI
            study = this.getChild(studyID);
            if(~isempty(study))
                data = study.getStudyPayload(cName,chan,dType,id,ROIType,ROISubType,ROIVicinity,dataProc);
            else
                data = [];
            end            
        end
        
        function out = getIRFMgr(this)
            %get IRF mgr from fitObj
            out = this.myParent.irfMgr;            
        end
        
%         function out = getIRFStr(this,timeChannels)
%             %get names of all IRFs from fitObj
%             out = this.myParent.irfMgr.getIRFStr(timeChannels);            
%         end 
        
%         function out = getSubjectInfoHeaders(this,studyID)
%             %get subject info headers from study data
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 out = study.myStudyInfoSet.getDataFromStudyInfo('subjectInfoAllColumnNames');
%             else
%                 out = [];
%             end
%         end
%         
%         function out = getSubjectInfo(this,studyID,idx)
%             %get subject info from study data
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectInfo(idx);
%             else
%                 out = [];
%             end
%         end
        
%         function out = getSubjectFilesHeaders(this,studyID)
%             %get subject file headers from study data
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectFilesHeaders();
%             else
%                 out = [];
%             end
%         end
        
        function out = getSubjectFilesData(this,studyID)
            %get subject files data from study data
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getSubjectFilesData();
            else
                out = [];
            end
        end
        
%         function out = getSubjectFiles(this,studyID,idx)
%             %get subject files from study data
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectFiles(idx);
%             else
%                 out = [];
%             end
%         end
        
        function out = getMVGroupNames(this,studyID,mode)
            %get list of MVGroups in study
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getMVGroupNames(mode);
            else
                out = [];
            end
        end
        
%         function out = getSubjectInfoConditionalColumnDefinitions(this,studyID)
%             %get subject info combi from study data
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectInfoConditionalColumnDefinitions();
%             else
%                 out = [];
%             end
%         end
        
        function out = getStudyRevision(this,studyID)
            %get study revision
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.revision;
            else
                out = [];
            end
        end
        
        function items = getAllFLIMItems(this,studyID,subjectID,chan)
            %get all items of a study, subject and channel
            study = this.getChild(studyID);
            if(~isempty(study))
                items = study.getAllFLIMItems(subjectID,chan);
            else
                items = [];
            end
        end
        
        function out = getDataFromStudyInfo(this,studyID,descriptor,subName,colName)
            %get data from study info defined by descriptor
            study = this.getChild(studyID);
            if(~isempty(study))
                switch nargin
                case 3
                    out = study.getDataFromStudyInfo(descriptor);
                case 4
                    out = study.getDataFromStudyInfo(descriptor,subName);
                case 5
                    out = study.getDataFromStudyInfo(descriptor,subName,colName);
                otherwise
                    out = [];
                end
            else
                out = [];
            end
        end
        
        function out = getConditionalColumnDefinition(this,studyID,idx)
            %return definition of a conditional column with index idx in study
            study = this.getChild(studyID);
            if(~isempty(studyID))
                out = study.getConditionalColumnDefinition(idx);
            else
                out = [];
            end
        end
        
        function idx = subjectInfoColumnName2idx(this,studyID,columnName)
            %get the index of a subject info column or check if index is valid
            study = this.getChild(studyID);
            if(~isempty(study))
                idx = study.subjectInfoColumnName2idx(columnName);
            end
        end
        
        function out = getAllIRFInfo(this,studyID)
            %
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.getAllIRFInfo();
            else
                out = [];
            end
        end
        
%         function [data isBH chNrs] = getFLIMData(this,studyID,subjectID,chan)
%             %
%             data = []; isBH = false;
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 [data isBH chNrs] = study.getFLIMData(subjectID,chan);
%             end
%         end

        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.paramMgr;
        end
        
        function out = get.maxMemoryCacheSize(this)
            %get maximum memory size used to cache data
            out = this.myMaxMemoryCacheSize;
        end
        
        function out = get.hashEngine(this)
            %return FLIMX hash engine
            out = this.myParent.hashEngine;
        end
        
        function set.maxMemoryCacheSize(this,val)
            %get maximum memory size used to cache data
            if(isnumeric(val) && val > 250e6)
                this.myMaxMemoryCacheSize = val;
                this.checkLRUCacheTableSize(val);
            end
        end
                
        function oldStudy = updateStudyVer(this,studyID,oldStudy)
            %make old study data compatible with current version
            study = this.getChild(studyID);
            if(~isempty(study))
                oldStudy = study.updateStudyVer(oldStudy);
            end
        end
        
        function isDirty = checkStudyDirtyFlag(this,studyID)
            %check if dirty flag of study is set
            study = this.getChild(studyID);
            if(~isempty(study))
                isDirty = study.isDirty;
            else
                isDirty = [];
            end
        end
        
        function exportStudies(this,list,fn)
            %export selected studies (including measurements and results) into one file per study
            nStudies = length(list);            
            h_wait = waitbar(0,'Exporting studies...');
            for i = 1:nStudies
                study = this.getChild(list{i});
                if(isempty(study))
                    continue
                end
                waitbar((i-1)/nStudies,h_wait,sprintf('Preparing study ''%s'' for export...',list{i}));
                if(study.isDirty)
                    %save changes to study (to do: ask user? at least display meassage?!)
                    study.save();
                end
                [pathstr,exportName,ext] = fileparts(fn);
                exportName = [exportName '~FLIMX~' list{i}];
                waitbar((i-1)/nStudies+0.25/nStudies,h_wait,sprintf('Checking size of study ''%s''...',list{i}));
                siz = DirSize(study.myDir);
                waitbar((i-1)/nStudies+0.5/nStudies,h_wait,sprintf('Exporting study ''%s''...',list{i}));
                th = 4*1024^3-1024^2; %1 MB safety margin
                %if directory is larger than 4GB -> split it into parts
                subjects = dir(study.myDir);
                subjects = subjects(~strncmp({subjects.name},'.',1));
                for j = 1:length(subjects)
                    if(subjects(j).bytes == 0)
                        subjects(j).bytes = DirSize(fullfile(study.myDir,subjects(j).name));
                    end
                end
                cumBytes = cumsum([subjects.bytes]);
                nParts = ceil(siz / th);
                for j = 1:nParts
                    thIdx = cumBytes >= (j-1)*th & cumBytes < j*th;
                    zipFn = fullfile(pathstr,[exportName '#' sprintf('%03d%s',j,'.zip')]);
                    try
                        zip(zipFn,{subjects(thIdx).name},study.myDir);
                        %rename zip file to .flimxstudy
                        movefile(zipFn,fullfile(pathstr,[exportName '#' sprintf('%03d%s',j,ext)]));
                    catch ME
                        warndlg(ME.message,'Error creating file');
                    end
                    waitbar((i-1)/nStudies+0.5/nStudies+0.5*j/nStudies/nParts,h_wait,sprintf('Exporting study ''%s''...',list{i}));
                end
                waitbar(i/nStudies,h_wait,sprintf('Finished.'));
            end %for-end
            close(h_wait);
        end
        
        function exportStudyInfo(this,studyID,file)
            %export study info (subject info table) to excel file
            study = this.getChild(studyID);
            if(~isempty(study))
                study.exportStudyInfo(file);
            end
        end
        
        function [aiStr, aiParam] = getArithmeticImageDefinition(this,studyID)
            %get names and definitions of arithmetic images for a study            
            aiStr = []; aiParam = [];
            if(nargin < 2)
                %for myConditionsMerged
                return
            end
            study = this.getChild(studyID);
            if(~isempty(study))
                [aiStr, aiParam] = study.getArithmeticImageDefinition();
            end
        end
        
        function out = getConditionColor(this,studyID,cName)
            %get color of Condition in study
            study = this.getChild(studyID);
            out = [];
            if(~isempty(study))
                out = study.getConditionColor(cName);
            end
        end
        
        function out = isMember(this,studyID,subjectID,chan,dType)
            %checks combination of study, subject, channel and datatype on results only
            study = this.getChild(studyID);
            if(isempty(study))
                out = false;
            elseif(isempty(subjectID))
                out = true;
            else
                out = study.isMember(subjectID,chan,dType);
            end
        end
        
        function out = isArithmeticImage(this,studyID,dType)
            %return true, if dType is an arithmetic image
            out = false;
            study = this.getChild(studyID);
            if(~isempty(study))
                out = study.isArithmeticImage(dType);
            end
        end
        
        function out = getColorMap(this)
            %get color map from FLIMXVisGUI
            %out = this.myParent.FLIMVisGUIObj.dynParams.cm;
            gp = this.FLIMXParamMgrObj.generalParams;            
            try
                out = eval(sprintf('%s(256)',lower(gp.cmType)));
            catch
                out = jet(256);
            end
        end
        
        function out = getCancelFlag(this)
            %if true stop current operation
            out = this.cancelFlag;
        end
        
        %% compute functions                
%         function makeGlobalObjMerged(this,chan,dType,id,ROIType,ROISubType,ROIVicinity)
%             %make global merged FData object
%             ciMerged = [];
%             for i=1:this.nrChildren
%                 %merge image of all subjects in all studies
%                 %hg = this.getChildAtPos(i).getStudyObjs(FDTree.defaultConditionName(),chan,dType,id,1);
%                 study = this.getChild(i);
%                 if(isempty(study))
%                     continue
%                 end
%                 ciMergedStudy = study.makeObjMerged(FDTree.defaultConditionName(),chan,dType,id,ROIType,ROISubType,ROIVicinity);
% %                 for j=1:length(hg)
% %                     ci = hg{j}.getROIImage(); %[],0,1,0
%                     ciMerged = [ciMerged; ciMergedStudy(:);];
% %                 end
%             end
%             %add subjectDSMerged
%             this.myConditionsMerged.addObjMergeID(id,chan,dType,1,ciMerged);
%         end
        
        function [cimg, lblx, lbly, cw, colorMVGroup, logColorMVGroup] = makeGlobalMVGroupObj(this,chan,MVGroupID)
            %make global MVGroup object
            cimg = []; lblx = []; lbly = []; cw = []; colorMVGroup = []; logColorMVGroup = [];            
            MVGroupTargets = this.getGlobalMVGroupTargets(MVGroupID);
            for i=1:size(MVGroupTargets,1)
                study = this.getChild(MVGroupTargets{i,1});
                conditionMVGroupObj = study.getFDataMergedObj(MVGroupTargets{i,2},chan,sprintf('Condition%s',MVGroupID),0,1);
                if(isempty(conditionMVGroupObj) || isempty(conditionMVGroupObj.getROIImage([],0,1,0)))
                    continue
                end
                %get reference classwidth
                cMVs = this.getStudyMVGroupTargets(MVGroupTargets{i,1},MVGroupID);
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                cw = getHistParams(this.getStatsParams(),chan,dType{1},dTypeNr(1));
                %get merged MVGroups from subjects of condition
                %use whole image for scatter plots, ignore any ROIs
                [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,conditionMVGroupObj.getROIImage([],0,1,0)./conditionMVGroupObj.getCImax([],0,1,0)*1000,conditionMVGroupObj.getCIXLbl([],0,1,0),conditionMVGroupObj.getCIYLbl([],0,1,0),cw);
            end            
            if(isempty(cimg))
                return
            end
            %create colored MVGroup
            colorMVGroup = zeros(size(cimg,1),size(cimg,2),3);
            logColorMVGroup = zeros(size(cimg,1),size(cimg,2),3);
            cimg = zeros(size(cimg));
            for i=1:size(MVGroupTargets,1)
                study = this.getChild(MVGroupTargets{i,1});
                conditionMVGroupObj = study.getFDataMergedObj(MVGroupTargets{i,2},chan,sprintf('Condition%s',MVGroupID),0,1);
                curImg = mergeScatterPlotData(cimg,lblx,lbly,conditionMVGroupObj.getROIImage([],0,1,0),conditionMVGroupObj.getCIXLbl([],0,1,0),conditionMVGroupObj.getCIYLbl([],0,1,0),cw);
                curImg = curImg/(max(curImg(:))-min(curImg(:)))*(size(this.getColorMap(),1)-1)+1;
                %prepare MVGroup coloring
                color = study.getConditionColor(MVGroupTargets{i,2});
                cm = repmat([0:1/(size(this.getColorMap(),1)-1):1]',1,3);
                cm = [cm(:,1).*color(1) cm(:,2).*color(2) cm(:,3).*color(3)];                
                %get merged colors
                colors = cm(round(reshape(curImg,[],1)),:);
                colors = reshape(colors,[size(curImg) 3]);                
                if(sum(colorMVGroup(:)) > 0)
                    colorMVGroup = imfuse(colors,colorMVGroup,'blend');
                else
                    colorMVGroup = colors;
                end                
%                 idx = repmat(sum(colors,3) ~= 0 & sum(colorMVGroup,3) ~= 0, [1 1 3]);
%                 colorMVGroup = colorMVGroup + colors;
%                 colorMVGroup(idx) = colorMVGroup(idx)./2;
                %create log10 color MVGroup
                curImgLog = log10(curImg);
                tmp = curImgLog(curImgLog ~= -inf);
                tmp = min(tmp(:));
                curImgLog(curImgLog == -inf) = tmp;                
                curImgLog = (curImgLog-tmp)/(max(curImgLog(:))-tmp)*(size(this.getColorMap(),1)-1)+1;
                colorsLog = cm(round(reshape(curImgLog,[],1)),:);
                colorsLog = reshape(colorsLog,[size(curImgLog) 3]);
                logColorMVGroup = logColorMVGroup + colorsLog;
                idxLog = repmat(sum(colorsLog,3) ~= 0 & sum(logColorMVGroup,3) ~= 0, [1 1 3]);
                logColorMVGroup(idxLog) = logColorMVGroup(idxLog)./2;
            end
            %set brightness to max
            %linear scaling
            t = rgb2hsv(colorMVGroup);
            t2 = t(:,:,3);
            idx = logical(sum(colorMVGroup,3));
            %t2(idx) = t2(idx) + 1-max(t2(:));
            t2(idx) = 1;
            t(:,:,3) = t2;
            colorMVGroup = hsv2rgb(t);
            %log scaling
            t = rgb2hsv(logColorMVGroup);
            t2 = t(:,:,3);
            idx = logical(sum(logColorMVGroup,3));
            %t2(idx) = t2(idx) + 1-max(t2(:));
            t2(idx) = 1;
            t(:,:,3) = t2;
            logColorMVGroup = hsv2rgb(t);
        end
                
        function scanForStudies(this)
            %scan the disk for studies
            dirs = dir(this.myDir);
            lastUpdate = clock;
            for i = 1:length(dirs)
                if(dirs(i,1).isdir && ~strcmp(dirs(i,1).name(1),'.'))
                    this.addStudy(dirs(i,1).name);
                    if(etime(clock, lastUpdate) > 0.5)
                        this.updateShortProgress(i/length(dirs),sprintf('Load studies %0.1f%% complete',100*i/length(dirs)));
                        lastUpdate = clock;
                    end
                end
            end
            this.updateShortProgress(1,'Study scan 100 %% complete');
        end
        
        function swapColumn(this,studyID,col,idx)
            %swap column in study info
            study = this.getChild(studyID);
            if(~isempty(study))
                study.swapColumn(col,idx);
            end
        end
        
%         function clearGlobalObjMerged(this,dType)
%             %clear global MVGroup object and statistics
%             this.myConditionsMerged.clearAllRIs(dType);
%         end
        
        function checkConditionRef(this,studyID,colN)
            %
            study = this.getChild(studyID);
            if(~isempty(study))
                study.checkConditionRef(colN);
            end
        end
        
        function clearSubjectFiles(this,studyID,subjectID)
            %delete data files for subject
            study = this.getChild(studyID);
            if(~isempty(study))
                study.clearSubjectFiles(subjectID);
            end
        end
        
        function checkSubjectFiles(this,studyID,subjectID)
            %check the data files on disk in a study for a specific subject or all subjects (subjectID = []) and update internal structs
            study = this.getChild(studyID);
            if(~isempty(study))
                study.checkSubjectFiles(subjectID);
            end
        end
        
%         function checkStudyFiles(this,studyID)
%             %check data files on disk for subject and update this.subjectFiles
%             study = this.getChild(studyID);
%             if(~isempty(study))
%                 study.checkStudyFiles();
%             end
%         end
        
    end %methods
    
    methods(Static)
        function out = defaultConditionName()
            %return the default condition name
            out = '-all subjects-';
        end
    end %methods(static)
end %classdef