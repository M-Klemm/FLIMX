classdef FDTree < handle
    %=============================================================================================================
    %
    % @file     FDTree.m
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
    % @brief    A class to handle FLIMX studies and subjects
    %
    properties(SetAccess = protected,GetAccess = protected)
        myFileLock = [];
        myParent = [];
        myDir = '';             %FStudyMgr's working directory
        myStudies = [];         %list of studies
        myViewsMerged = [];     %global statistics and global cluster objects
        myClusterTargets = [];  %global cluster targets        
        cancelFlag = false; %flag to stop an operation
        saveMaxMem = false;    %max memory saving flag
        dataSmoothAlgorithm = 0; %select data smoothing algorithm
        dataSmoothParameters = 1; %parameters for data smoothing algorithm
        shortProgressCb = cell(0,0); %list of callback functions for progressbar update (short)
        longProgressCb = cell(0,0); %list of callback functions for progressbar update (long)
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
    end
    
    methods
        function this = FDTree(parent,rootDir)
            % Constructor for FDTree
            this.myDir = fullfile(rootDir,'studyData');
            if(~isdir(this.myDir))
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
            this.myParent = parent;
            this.myStudies = LinkedList();
            this.myViewsMerged = subjectDS(this,'GlobalMergedSubjects');
            this.myClusterTargets = LinkedList();
            this.saveMaxMem = this.getSaveMaxMemFlag();
            %Add default study as container for not assigned subjects
            if(this.myStudies.queueLen == 0)
                this.addStudy('Default');
            end
            try
                this.setShortProgressCallback(@parent.updateSplashScreenProgressShort);
            end
            this.scanForStudies();
        end
        
        function removeObj(this,studyID,subjectID,chan,dType,id)
            %remove object from subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeObj(subjectID,chan,dType,id);
                this.removeObjMerged();
            end
        end
        
        function removeChannel(this,studyID,subjectID,ch)
            %remove channel of a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeChannel(subjectID,ch);
                this.removeObjMerged();
            end
        end
        
        function removeSubjectResult(this,studyID,subjectID)
            %remove all results of a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeSubjectResult(subjectID);
                this.removeObjMerged();
            end
        end
        
        function removeSubject(this,studyID,subjectID)
            %remove a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeSubject(subjectID);
                this.removeObjMerged();
            end
        end
        
        function removeCluster(this,studyID,clusterID)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeCluster(clusterID);
            end
        end
        
        function removeStudy(this,studyID)
            %remove a study
            [study, studyID] = this.getStudy(studyID);
            if(~isempty(study) && ~strcmp(study.name,'Default'))
                %don't remove default study
                [status, message, messageid] = rmdir(study.myDir,'s');
                this.myStudies.removePos(studyID);
                this.removeObjMerged();
            end
        end
        
        function removeObjMerged(this)
            %remove merged FData objects
            this.myViewsMerged = [];
            this.myViewsMerged = subjectDS(this,'GlobalMergedSubjects');
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
        
        %% input functions
        function study = addStudy(this,name)
            %add a study to studyMgr
            %check name
            name = studyMgr.checkFolderName(name);
            %make folder for study
            study = this.getStudy(name);
            if(~isempty(study))
                %study alread in tree
                return
            end
            sDir = fullfile(this.myDir,name);
            if(~isdir(sDir))
                [status, message, ~] = mkdir(sDir);
                if(~status)
                    error('FLIMX:FDTree:addStudy','Could not create study folder: %s\n%s',sDir,message);
                end
            end
            this.myStudies.insertID(FStudy(this,sDir,name),name);
            %try to load the study data
            study = this.getStudy(name);
            if(isempty(study))
                return
            end
            study.load();
        end
        
        function loadStudy(this,studyID)
            % (re)load study (used by studyMgr)
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.load();
            end
        end
        
        function importStudy(this,newStudyName,fn)
            %import study from export file(s)
            %check if we have this study already
            if(any(strcmp(this.getStudyNames,newStudyName)))
                %ask user
                return
            end
            studyDir = fullfile(this.myDir,newStudyName);
            if(~exist(studyDir,'dir'))
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
            if(exist(sdFile,'file'))
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
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.addSubject(subjectID);
            end
        end
        
        function setSaveMaxMemFlag(this,val)
            %set save maximal memory flag an clear all current images
            val = logical(val);
            if(val ~= this.saveMaxMem && val == true) %val = true -> Save-Mode = 'on'
                %clear all current images to save memory
                this.clearAllCIs([]);
            end
            this.saveMaxMem = val;
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
            %set callback function for short progress bar
            this.longProgressCb(end+1) = {cb};
        end
        
        function setSubjectName(this,studyID,subjectID,val)
            %set subject name
            if(isempty(val))
                return
            end
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setSubjectName(subjectID,val);
            end
        end
        
        function setClusterTargets(this,studyID,clusterID,val)
            %set multivariate targets
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setClusterTargets(clusterID,val);
            end
        end
        
        function setGlobalClusterTargets(this,clusterID,targets)
            %set global cluster targets, i.e. selected study views
            clusterTargets.name = clusterID;
            clusterTargets.targets = targets;
            this.myClusterTargets.insertID(clusterTargets,clusterID);
            %clear old cluster object
            this.myViewsMerged.clearAllRIs(sprintf('Global%s',clusterID));
        end
        
        function setClusterName(this,studyID,clusterID,val)
            %set cluster name
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setClusterName(clusterID,val);
            end
            %change ID of global cluster
            this.myClusterTargets.changeID(clusterID,val);
        end
                
        function clearSubjectCI(this,studyID,subjectID)
            %clear current images (result ROI) of a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.clearSubjectCI(subjectID);
            end
        end
        
        function clearAllCIs(this,dType)
            %clear current immages of datatype dType in all subjects
            for i = 1:this.myStudies.queueLen
                this.myStudies.getDataByPos(i).clearAllCIs(dType);
            end
            this.myViewsMerged.clearAllCIs(dType);
        end
        
        function clearAllFIs(this,dType)
            %clear filtered raw immages of datatype dType in all subjects
            for i = 1:this.myStudies.queueLen
                this.myStudies.getDataByPos(i).clearAllFIs(dType);
            end
            this.myViewsMerged.clearAllFIs(dType);
        end
        
        function clearClusters(this,studyID,subjectID,dType,dTypeNr)
            %clear clusters if ROI changes
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.clearClusters(subjectID,dType,dTypeNr);
            end
        end
                
        function setResultROICoordinates(this,studyName,subjectID,dType,dTypeNr,ROIType,ROICoord)
            %set the ROI coordinates for study studyName at subject subjectID and ROIType
            study = this.getStudy(studyName);
            if(~isempty(study))
                study.setResultROICoordinates(subjectID,dType,dTypeNr,ROIType,ROICoord);
                this.clearGlobalObjMerged(dType);
            end
        end
        
        function setResultZScaling(this,studyName,subjectID,ch,dType,dTypeNr,zValues)
            %set the z scaling for study studyName at subject subjectID and ROIType
            study = this.getStudy(studyName);
            if(~isempty(study))
                study.setResultZScaling(subjectID,ch,dType,dTypeNr,zValues);
                this.clearGlobalObjMerged(dType);
            end
        end
        
        function setResultColorScaling(this,studyName,subjectID,ch,dType,dTypeNr,colorBorders)
            %set the z scaling for study studyName at subject subjectID and ROIType
            study = this.getStudy(studyName);
            if(~isempty(study))
                study.setResultColorScaling(subjectID,ch,dType,dTypeNr,colorBorders);
            end
        end
        
        function setCutVec(this,studyName,subjectID,dim,cutVec)
            %set the cut vector for study studyName at subject subjectID and dimension dim
            study = this.getStudy(studyName);
            if(~isempty(study))
                study.setCutVec(subjectID,dim,cutVec);
            end
        end
                
        function setStudyName(this,studyID,newStudyName)
            %set new study name
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setName(newStudyName);
                newPath = fullfile(this.myDir,newStudyName);
                study.setStudyDir(newPath);
            end
            this.myStudies.changeID(studyID,newStudyName);
        end
        
        function insertColumnHeaders(this,destination,origin)
            %insert column headers from origin in destination study
            destStudy = this.getStudy(destination);
            originStudy = this.getStudy(origin);
            if(~isempty(destStudy) && ~isempty(originStudy))
                %check and update conditional columns
                infoCombi = originStudy.getSubjectInfoCombi();
                oldInfoCombi = destStudy.getSubjectInfoCombi();
                orgInfoHeads = originStudy.getSubjectInfoHeaders();
                destInfoHeads = destStudy.getSubjectInfoHeaders();                
                %check subjectInfoHeaders and add new
                newHeaders = setdiff(orgInfoHeads,destInfoHeads);
                if(~isempty(newHeaders))
                    %add new columns at table end
                    for i = 1:length(newHeaders)
                        destStudy.addColumn(newHeaders{i});
                    end
                end                
                for i = 1:length(orgInfoHeads)
                    str = orgInfoHeads{i};
                    [tf, idx] = ismember(str,destInfoHeads);
                    if(tf && ~isempty(oldInfoCombi{idx}))
                        choice = questdlg(sprintf('Do you want to overwrite the condition of "%s"?',...
                            str),'Inserting Conditional Column','OK','Cancel','OK');
                        switch choice
                            case 'Cancel'
                                %keep old condition
                                infoCombi(i) = oldInfoCombi(idx);
                        end
                    end
                end
                %set merged conditional columns
                for i = 1:length(orgInfoHeads)
                    str = orgInfoHeads{i};
                    [~, idx] = ismember(str,destStudy.getSubjectInfoHeaders());
                    destStudy.setSubjectInfoCombi(infoCombi(i),idx);
                end
            end
        end
        
        function copySubject(this,originStudy,oldSubjectID,destinationStudy,newSubjectID)
            %insert subjects from origin in destination study
            destStudy = this.getStudy(destinationStudy);
            orgStudy = this.getStudy(originStudy);
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
                    destStudy.insertSubject(newSubjectID,data);
                    
                    %copy Data for FLIMXVisGUI
                    oldpath = fullfile(orgStudy.myDir,oldSubjectID);
                    newpath = fullfile(destStudy.myDir,newSubjectID);
                    if(exist(oldpath,'dir') ~= 0)
                        copyfile(oldpath,newpath);
                    end
                end
            end
        end
        
        function copySubjectROI(this,originStudy,destinationStudy,subjectID)
            %copy ROI corrdinates of a subject from one study to another (if subject exists there)
            orgStudy = this.getStudy(originStudy);
            destStudy = this.getStudy(destinationStudy);            
            if(~isempty(destStudy) && ~isempty(orgStudy))
                %check if subjects exist in studies 
                orgSubject = orgStudy.getSubject(subjectID);
                destSubject = destStudy.getSubject(subjectID);
                if(~isempty(orgSubject) && ~isempty(destSubject))
                    %get all ROI coordinates from source
                    ROICoord = orgStudy.getResultROICoordinates(subjectID,[]);
                    %set all ROI coordinates in destination
                    destStudy.setResultROICoordinates(subjectID,'Amplitude',1,[],ROICoord);
                end
            end
        end
        
        function setSubjectInfoHeaders(this,studyID,subjectInfoHeaders,idx)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setSubjectInfoHeaders(subjectInfoHeaders,idx);
            end
        end
        
        function importXLS(this,studyName,file,mode)
            %
            study = this.getStudy(studyName);
            if(~isempty(study))
                study.importXLS(file,mode);
            end
        end
        
        function importSubject(this,subjectObj)
            %import a new subject object (and possibly study)
            study = this.getStudy(subjectObj.getStudyName());
            if(isempty(study))
                study = this.addStudy(subjectObj.getStudyName());
            end
            if(~isempty(study))
                study.importSubject(subjectObj);
            end
        end
        
        function unloadAllChannels(this)
            %remove all channels in all subjects in all studies from memory
            studyNames = this.getStudyNames();
            tStart = now;
            lastUpdate = tStart;
            oneSec = 1/24/60/60;
            for i = 1:length(studyNames)
                try
                    tNow = datenummx(clock);  %fast
                catch
                    tNow = now;  %slower
                end
                study = this.getStudy(studyNames{i});
                if(~isempty(study))
                    study.unloadAllChannels();
                end
                if(tNow-lastUpdate > oneSec)
                    [~, minutes, secs] = secs2hms((tNow-tStart)/oneSec/i*(length(studyNames)-i)); %mean cputime for finished runs * cycles left
                    this.updateLongProgress(i/length(studyNames),sprintf('Time left: %dmin %.0fsec - Unloading study ''%s''',minutes,secs,studyNames{i}));
                    lastUpdate = tNow;
                end
            end
            this.updateLongProgress(0,'');
        end
        
        function updateSubjectChannel(this,subjectObj,ch,flag)
            %update a specific channel of a subject, flag signalizes 'measurement', 'result' or '' for both
            study = this.getStudy(subjectObj.getStudyName());
            if(isempty(study))
                study = this.addStudy(subjectObj.getStudyName());
            end
            if(~isempty(study))
                study.updateSubjectChannel(subjectObj,ch,flag);
                %study.removeChannel(subjectID,ch);
                this.removeObjMerged();
            end            
        end
        
%         function importResultStruct(this,studyName,subjectName,import,itemsTarget)
%             %import a new subject (and possibly study)
%             study = this.getStudy(studyName);
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
%             study = this.getStudy(studyName);
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
%             study = this.getStudy(fluoFileObj.getStudyName());
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
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.addColumn(name);
            end
        end
        
        function addCondColumn(this,studyID,opt)
            %add new conditional column
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.addCondColumn(opt);
            end
        end
        
        function setCondColumn(this,studyID,colName,opt)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setCondColumn(colName,opt);
            end
        end
        
        function removeColumn(this,studyID,colName)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeColumn(colName);
            end
        end
        
        function setSubjectInfo(this,studyID,irow,icol,newData)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setSubjectInfo(irow,icol,newData);
            end
        end
        
        function setArithmeticImage(this,studyID,aiName,aiParam)
            %set name and definition of arithmetic image for a study
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setArithmeticImage(aiName,aiParam);
            end
        end
        
        function removeArithmeticImage(this,studyID,aiName)
            %remove arithmetic image for a study
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.removeArithmeticImage(aiName);
            end
        end
        
        function setViewColor(this,studyID,vName,val)
            %set view color in study
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.setViewColor(vName,val);
            end
            str = this.getGlobalClustersStr();
            for i = 1:length(str)
                globalClusterID = sprintf('Global%s',str{i});
                this.myViewsMerged.clearAllRIs(globalClusterID);
            end
        end
        
        %% output functions
        
        function saveStudy(this,studyID)
            %save study with studyID
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.save();
            end
        end
        
%         function studyDir = getStudyDir(this,studyID)
%             % get directory of study
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 studyDir = study.myDir;
%             else
%                 studyDir = [];
%             end
%         end
        
        function out = getFDataObj(this,studyID,subjectID,chan,dType,id,sType)
            %get FData object
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getFDataObj(subjectID,chan,dType,id,sType);
            else
                out = [];
            end
        end
                
%         function out = getResultObj(this,studyID,subjectID,chan)
%             %get fluoDecayFitResult object, chan = [] loads all channels
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getResultObj(subjectID,chan);            
%             else
%                 out = [];
%             end
%         end
%         
%         function out = getMeasurementObj(this,studyID,subjectID,chan)
%             %get fluoFile object containing measurement data, chan = [] loads all channels
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getMeasurementObj(subjectID,chan);
%             else
%                 out = [];
%             end
%         end
        
        function out = getSubject4Approx(this,studyID,subjectID)
            %get subject object for approximation which includes measurements and results
            study = this.getStudy(studyID);
            if(isempty(study))
                study = this.addStudy(studyID);
            end
            out = study.getSubject4Approx(subjectID);
        end
        
        function out = getSubject4Import(this,studyID,subjectID)
            %get subject object to import measurements or results
            studyID = studyMgr.checkFolderName(studyID);
            subjectID = studyMgr.checkFolderName(subjectID);
            if(isempty(studyID) || isempty(subjectID))
                out = [];
                return
            end
            study = this.getStudy(studyID);
            if(isempty(study))
                study = this.addStudy(studyID);
            end            
            out = study.getSubject4Import(subjectID);
        end
        
        function out = getGlobalObjMerged(this,chan,dType,id)
            %get merged subjectDS of all studies
            out = this.myViewsMerged.getFDataObj(chan,dType,id,1);
            if(isempty(out))
                %try to merge subjects
                this.makeGlobalObjMerged(chan,dType,id);
                out = this.myViewsMerged.getFDataObj(chan,dType,id,1);
            end
        end
        
        function out = getGlobalClusterObj(this,chan,dType,sType)
            %get global cluster object
            out = this.myViewsMerged.getFDataObj(chan,dType,0,sType);
            if(isempty(out))
                %try to make global cluster
                clusterID = dType(7:end);
                [cimg, lblx, lbly, cw, colors, logColors] = this.makeGlobalCluster(chan,clusterID);
                %add cluster
                this.myViewsMerged.addObjID(0,chan,dType,0,cimg);
                out = this.myViewsMerged.getFDataObj(chan,dType,0,sType);
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
        
        function out = getStudyObjMerged(this,studyID,vName,chan,dType,id,sType)
            %get merged subjectDS of a certain study
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getFDataMergedObj(vName,chan,dType,id,sType);
            else
                out = [];
            end
        end
        
        %         function out = getStudyObjs(this,studyID,vName,chan,dType,id)
        %             %get all objects of datatype dType from a study
        %             study = this.getStudy(studyID);
        %             if(~isempty(study))
        %                 out = study.getStudyObjs(vName,chan,dType,id);
        %             else
        %                 out = [];
        %             end
        %
        %         end
        
        function [nr, study] = getStudyNr(this,name)
            %get study number
            for nr=1:this.myStudies.queueLen
                study = this.myStudies.getDataByPos(nr);
                if(strcmp(name,study.name))
                    return
                end
            end
            nr = [];
            study = [];
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end
        
        function nr = getNrStudies(this)
            % get number of studies in FDTree
            nr = this.myStudies.queueLen;
        end
        
        function str = getStudyNames(this)
            % get string of all studies
            str = cell(this.myStudies.queueLen,1);
            for i=1:this.myStudies.queueLen
                str(i,1) = {this.myStudies.getDataByPos(i).name};
            end
        end
        
        function out = getStudyViewsStr(this,studyID)
            % get views of study
            study = this.getStudy(studyID);
            if(isempty(studyID))
                out = FDTree.defaultConditionName();
                return
            end
            out = study.getViewsStr();
        end
                
        function out = getSubjectName(this,studyID,subjectID)
            %get subject name
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getSubjectName(subjectID);
            else
                out = [];
            end
        end
        
        function out = getSubjectNr(this,studyID,name)
            %get subject nr
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getSubjectNr(name);
            else
                out = [];
            end
        end
        
        function [measurementChs, resultChs] = getSubjectFilesStatus(this,studyID,subjectID)
            %returns which channels are available for a subject in a study
            study = this.getStudy(studyID);
            if(~isempty(study))
                [measurementChs, resultChs] = study.getSubjectFilesStatus(subjectID);
            else
                measurementChs = [];
                resultChs = [];
            end            
        end
        
        function out = getClusterTargets(this,studyID,clusterID)
            %get multivariate targets
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getClusterTargets(clusterID);
            else
                out = [];
            end
        end
        
        function out = getGlobalClusterTargets(this,clusterID)
            %get global cluster targets, i.e. selected study views
            out = [];
            clusterTargets = this.myClusterTargets.getDataByID(clusterID);
            if(isempty(clusterTargets))
                return
            end
            out = clusterTargets.targets;
        end
        
        function str = getGlobalClustersStr(this)
            %get string with all global cluster names if computable
            str = cell(0,1);
            for i=1:this.myClusterTargets.queueLen
                clusterTargets = this.myClusterTargets.getDataByPos(i);
                if(size(clusterTargets.targets,1) >= 1)
                    cMVs = this.getClusterTargets(clusterTargets.targets{1,1},clusterTargets.name);
                    if(~isempty(cMVs) && ~isempty(cMVs.y))
                        %cluster is computable
                        str(end+1,1) = {this.myClusterTargets.getDataByPos(i).name};
                    end
                end
            end
        end
        
        function nr = getNrSubjects(this,studyID,vName)
            %get number of subjects in study with studyID
            study = this.getStudy(studyID);
            if(~isempty(study))
                nr = study.getNrSubjects(vName);
            else
                nr = [];
            end
        end
        
        function out = makeStudyInfoSetExportStruct(this,studyID,subjectID)
            %get data from study clipboard
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.makeInfoSetExportStruct(subjectID);
            else
                out = [];
            end
        end
        
        function dStr = getSubjectsNames(this,studyID,vName)
            %get a string of all subjects
            study = this.getStudy(studyID);
            if(~isempty(study))
                dStr = study.getSubjectsNames(vName);
            else
                dStr = [];
            end
        end
        
        function [str, nrs] = getChStr(this,studyID,subjectID)
            %get a string and numbers of all channels in subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                [str, nrs] = study.getChStr(subjectID);
            else
                str = [];
                nrs = [];
            end
        end
        
        function str = getChObjStr(this,studyID,subjectID,ch)
            %get a string of all objects in channel ch in subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                str = study.getChObjStr(subjectID,ch);
            else
                str = [];
            end
        end
        
        function str = getChClusterObjStr(this,studyID,subjectID,ch)
            %get a string of all cluster objects in channel ch in subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                str = study.getChClusterObjStr(subjectID,ch);
            else
                str = [];
            end
        end
        
        function out = getHeight(this,studyID,subjectID)
            %get image height in a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getHeight(subjectID);
            else
                out = [];
            end
        end
        
        function out = getWidth(this,studyID,subjectID)
            %get image width in a subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getWidth(subjectID);
            else
                out = [];
            end
        end
        
        function out = getSaveMaxMemFlag(this)
            %get saveMaxMem flag from parent
            out = this.saveMaxMem;
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            alg = this.dataSmoothAlgorithm ;
            params = this.dataSmoothParameters;
        end  
        
        function [MSX, MSXMin, MSXMax] = getMSX(this,studyID,subjectID)
            %get manual scaling parameters for x in subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                [MSX, MSXMin, MSXMax] = study.getMSX(subjectID);
            else
                MSX = [];
                MSXMin = [];
                MSXMax = [];
            end
        end
        
        function [MSY, MSYMin, MSYMax] = getMSY(this,studyID,subjectID)
            %get manual scaling parameters for y in subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                [MSY, MSYMin, MSYMax] = study.getMSY(subjectID);
            else
                MSY = [];
                MSYMin = [];
                MSYMax = [];
            end
        end
                
        function [centers, histTable] = getGlobalHistogram(this,chan,dType,id)
            %combine all histograms of channel chan, datatype dType and 'running number' id into a single table
            hg = this.getGlobalObjMerged(chan,dType,id);
            if(isempty(hg) || hg.isEmptyStat)
                %try to build merged object
                this.makeGlobalObjMerged(chan,dType,id);
                hg = this.getGlobalObjMerged(chan,dType,id);
            end
            if(~isempty(hg))
                centers = hg.getCIHistCenters();
                histTable = hg.getCIHist();
            else
                centers = []; histTable = [];
            end
        end
        
        function [centers, histMerge, histTable, colDescription] = getStudyHistogram(this,studyID,vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag)
            %combine all histograms of study studyID, channel chan, datatype dType and 'running number' id into a single table
            study = this.getStudy(studyID);
            if(~isempty(study))
                if(nargout == 2)
                    [centers, histMerge] = study.getStudyHistogram(vName,chan,dType,id);
                else
                    [centers, histMerge, histTable, colDescription] = study.getStudyHistogram(vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag);
                end
            else
                centers = []; histTable = []; histMerge = []; colDescription = cell(0,0);
            end
        end
        
        function [stats, statsDesc, subjectDesc] = getStudyStatistics(this,studyID,vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag,strictFlag)
            %get statistics for all subjects in study studyID, view vName and channel chan of datatype dType with 'running number' id
            study = this.getStudy(studyID);
            if(~isempty(study))
                [stats, statsDesc, subjectDesc] = study.getStudyStatistics(vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag,strictFlag);
            else
                stats = []; statsDesc = []; subjectDesc = [];
            end
        end
        
        function data = getStudyPayload(this,studyID,vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag,dataProc)
            %get merged payload from all subjects of study studyID, channel chan, datatype dType and 'running number' within a study for a certain ROI
            study = this.getStudy(studyID);
            if(~isempty(study))
                data = study.getStudyPayload(vName,chan,dType,id,ROIType,ROISubType,ROIInvertFlag,dataProc);
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
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.myStudyInfoSet.getSubjectInfoHeaders();
%             else
%                 out = [];
%             end
%         end
%         
%         function out = getSubjectInfo(this,studyID,idx)
%             %get subject info from study data
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectInfo(idx);
%             else
%                 out = [];
%             end
%         end
        
%         function out = getSubjectFilesHeaders(this,studyID)
%             %get subject file headers from study data
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectFilesHeaders();
%             else
%                 out = [];
%             end
%         end
        
        function out = getSubjectFilesData(this,studyID)
            %get subject files data from study data
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getSubjectFilesData();
            else
                out = [];
            end
        end
        
%         function out = getSubjectFiles(this,studyID,idx)
%             %get subject files from study data
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectFiles(idx);
%             else
%                 out = [];
%             end
%         end
        
        function out = getStudyClustersStr(this,studyID,mode)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getStudyClustersStr(mode);
            else
                out = [];
            end
        end
        
%         function out = getSubjectInfoCombi(this,studyID)
%             %get subject info combi from study data
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectInfoCombi();
%             else
%                 out = [];
%             end
%         end
        
        function out = getStudyRevision(this,studyID)
            %get study revision
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.revision;
            else
                out = [];
            end
        end
        
        function items = getAllFLIMItems(this,studyID,subjectID,chan)
            %get all items of a study, subject and channel
            study = this.getStudy(studyID);
            if(~isempty(study))
                items = study.getAllFLIMItems(subjectID,chan);
            else
                items = [];
            end
        end
                
%         function out = getSubjectScalings(this,studyID,idx)
%             %get subject scalings from study data
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectScalings(idx);
%             else
%                 out = [];
%             end
%         end
%         
%         function out = getSubjectCuts(this,studyID,idx)
%             %
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 out = study.getSubjectCuts(idx);
%             else
%                 out = [];
%             end
%         end
        
        function out = getDataFromStudyInfo(this,studyID,descriptor)
            %get data from study info defined by descriptor
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getDataFromStudyInfo(descriptor);
            else
                out = [];
            end
        end
        
        function out = getColReference(this,studyID,idx)
            %
            study = this.getStudy(studyID);
            if(~isempty(studyID))
                out = study.getColReference(idx);
            else
                out = [];
            end
        end
        
        function idx = infoHeaderName2idx(this,studyID,iHName)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                idx = study.infoHeaderName2idx(iHName);
            end
        end
        
        function out = getAllIRFInfo(this,studyID)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                out = study.getAllIRFInfo();
            else
                out = [];
            end
        end
        
%         function [data isBH chNrs] = getFLIMData(this,studyID,subjectID,chan)
%             %
%             data = []; isBH = false;
%             study = this.getStudy(studyID);
%             if(~isempty(study))
%                 [data isBH chNrs] = study.getFLIMData(subjectID,chan);
%             end
%         end

        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.paramMgr;
        end
                
        function oldStudy = updateStudyVer(this,studyID,oldStudy)
            %make old study data compatible with current version
            study = this.getStudy(studyID);
            if(~isempty(study))
                oldStudy = study.updateStudyVer(oldStudy);
            end
        end
        
        function isDirty = checkStudyDirtyFlag(this,studyID)
            %check if dirty flag of study is set
            study = this.getStudy(studyID);
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
                study = this.getStudy(list{i});
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
        
        function exportXLS(this,studyID,file)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.exportXLS(file);
            end
        end
        
        function [aiStr, aiParam] = getArithmeticImage(this,studyID)
            %get names and definitions of arithmetic images for a study
            study = this.getStudy(studyID);
            aiStr = []; aiParam = [];
            if(~isempty(study))
                [aiStr, aiParam] = study.getArithmeticImage();
            end
        end
        
        function out = getViewColor(this,studyID,vName)
            %get color of view in study
            study = this.getStudy(studyID);
            out = [];
            if(~isempty(study))
                out = study.getViewColor(vName);
            end
        end
        
        function out = isMember(this,studyID,subjectID,chan,dType)
            %checks combination of study, subject, channel and datatype on results only
            study = this.getStudy(studyID);
            if(isempty(study))
                out = false;
            elseif(isempty(subjectID))
                out = true;
            else
                out = study.isMember(subjectID,chan,dType);
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
        function makeGlobalObjMerged(this,chan,dType,id)
            %make global merged FData object
            ciMerged = [];
            for i=1:this.myStudies.queueLen
                %merge image of all subjects in all studies
                hg = this.myStudies.getDataByPos(i).getStudyObjs(FDTree.defaultConditionName(),chan,dType,id,1);
                for j=1:length(hg)
                    ci = hg{j}.getROIImage(); %[],0,1,0
                    ciMerged = [ciMerged; ci(:);];
                end
            end
            %add subjectDSMerged
            this.myViewsMerged.addObjMergeID(id,chan,dType,1,ciMerged);
        end
        
        function [cimg, lblx, lbly, cw, colorCluster, logColorCluster] = makeGlobalCluster(this,chan,clusterID)
            %make global cluster object
            cimg = []; lblx = []; lbly = []; cw = []; colorCluster = []; logColorCluster = [];            
            clusterTargets = this.getGlobalClusterTargets(clusterID);
            for i=1:size(clusterTargets,1)
                study = this.getStudy(clusterTargets{i,1});
                viewClusterObj = study.getFDataMergedObj(clusterTargets{i,2},chan,sprintf('Condition%s',clusterID),0,1);
                if(isempty(viewClusterObj) || isempty(viewClusterObj.getROIImage([],0,1,0)))
                    continue
                end
                %get reference classwidth
                cMVs = this.getClusterTargets(clusterTargets{i,1},clusterID);
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                cw = getHistParams(this.getStatsParams(),chan,dType{1},dTypeNr(1));
                %get merged clusters from subjects of view
                %use whole image for scatter plots, ignore any ROIs
                [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,viewClusterObj.getROIImage([],0,1,0)./viewClusterObj.getCImax([],0,1,0)*1000,viewClusterObj.getCIXLbl([],0,1,0),viewClusterObj.getCIYLbl([],0,1,0),cw);
            end            
            if(isempty(cimg))
                return
            end
            %create colored cluster
            colorCluster = zeros(size(cimg,1),size(cimg,2),3);
            logColorCluster = zeros(size(cimg,1),size(cimg,2),3);
            for i=1:size(clusterTargets,1)
                study = this.getStudy(clusterTargets{i,1});
                viewClusterObj = study.getFDataMergedObj(clusterTargets{i,2},chan,sprintf('Condition%s',clusterID),0,1);
                curImg = mergeScatterPlotData(cimg,lblx,lbly,viewClusterObj.getROIImage([],0,1,0),viewClusterObj.getCIXLbl([],0,1,0),viewClusterObj.getCIYLbl([],0,1,0),cw);
                curImg = curImg/(max(curImg(:))-min(curImg(:)))*(size(this.getColorMap(),1)-1)+1;
                %prepare cluster coloring
                color = study.getViewColor(clusterTargets{i,2});
                cm = repmat([0:1/(size(this.getColorMap(),1)-1):1]',1,3);
                cm = [cm(:,1).*color(1) cm(:,2).*color(2) cm(:,3).*color(3)];                
                %get merged colors
                colors = cm(round(reshape(curImg,[],1)),:);
                colors = reshape(colors,[size(curImg) 3]);                
                if(sum(colorCluster(:)) > 0)
                    colorCluster = imfuse(colors,colorCluster,'blend');
                else
                    colorCluster = colors;
                end                
%                 idx = repmat(sum(colors,3) ~= 0 & sum(colorCluster,3) ~= 0, [1 1 3]);
%                 colorCluster = colorCluster + colors;
%                 colorCluster(idx) = colorCluster(idx)./2;
                %create log10 color cluster
                curImgLog = log10(curImg);
                tmp = curImgLog(curImgLog ~= -inf);
                tmp = min(tmp(:));
                curImgLog(curImgLog == -inf) = tmp;                
                curImgLog = (curImgLog-tmp)/(max(curImgLog(:))-tmp)*(size(this.getColorMap(),1)-1)+1;
                colorsLog = cm(round(reshape(curImgLog,[],1)),:);
                colorsLog = reshape(colorsLog,[size(curImgLog) 3]);
                logColorCluster = logColorCluster + colorsLog;
                idxLog = repmat(sum(colorsLog,3) ~= 0 & sum(logColorCluster,3) ~= 0, [1 1 3]);
                logColorCluster(idxLog) = logColorCluster(idxLog)./2;
            end
            %set brightness to max
            %linear scaling
            t = rgb2hsv(colorCluster);
            t2 = t(:,:,3);
            idx = logical(sum(colorCluster,3));
            %t2(idx) = t2(idx) + 1-max(t2(:));
            t2(idx) = 1;
            t(:,:,3) = t2;
            colorCluster = hsv2rgb(t);
            %log scaling
            t = rgb2hsv(logColorCluster);
            t2 = t(:,:,3);
            idx = logical(sum(logColorCluster,3));
            %t2(idx) = t2(idx) + 1-max(t2(:));
            t2(idx) = 1;
            t(:,:,3) = t2;
            logColorCluster = hsv2rgb(t);
        end
        
        
        function [study, studyID] = getStudy(this,studyID)
            %check if study is in myStudies
            if(ischar(studyID))
                %study name is input data
                [studyID, study] = this.getStudyNr(studyID);
            elseif(isnumeric(studyID))
                if(studyID > this.myStudies.queueLen)
                    %study is not in FDTree
                    studyID = [];
                    study = [];
                else
                    study = this.myStudies.getDataByPos(studyID);
                end
            else
                studyID = [];
                study = [];
            end
        end
        
        function scanForStudies(this)
            %scan the disk for studies
            dirs = dir(this.myDir);
            lastUpdate = clock;
            for i = 1:length(dirs)
                if(dirs(i,1).isdir && ~strcmp(dirs(i,1).name(1),'.'))
                    this.addStudy(dirs(i,1).name);
                    if(etime(clock, lastUpdate) > 0.5)
                        this.updateShortProgress(i/length(dirs),sprintf('Loading studies %0.1f%% complete',100*i/length(dirs)));
                        lastUpdate = clock;
                    end
                end
            end
            this.updateShortProgress(1,'Study scan 100 %% complete');
        end
        
        function swapColumn(this,studyID,col,idx)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.swapColumn(col,idx);
            end
        end
        
        function clearAllRIs(this,studyID,dType)
            %clear raw images of datatype dType in all subjects
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.clearAllRIs(dType);
                if(strncmp(dType,'MVGroup',7))
                    %clear corresponding global cluster object
                    globalClusterID = sprintf('Global%s',dType);
                    this.myViewsMerged.clearAllRIs(globalClusterID);
                end
            end
        end
        
        function clearGlobalObjMerged(this,dType)
            %clear global cluster object and statistics
            this.myViewsMerged.clearAllRIs(dType);
        end
        
        function checkConditionRef(this,studyID,colN)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.checkConditionRef(colN);
            end
        end
        
        function clearSubjectFiles(this,studyID,subjectID)
            %delete data files for subject
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.clearSubjectFiles(subjectID);
            end
        end
        
        function checkSubjectFiles(this,studyID,subjectID)
            %
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.checkSubjectFiles(subjectID);
            end
        end
        
        function checkStudyFiles(this,studyID)
            %check data files on disk for subject and update this.subjectFiles
            study = this.getStudy(studyID);
            if(~isempty(study))
                study.checkStudyFiles();
            end
        end
        
    end %methods
    
    methods(Static)
        function out = defaultConditionName()
            %return the default condition name
            out = '-all subjects-';
        end
    end %methods(static)
end %classdef