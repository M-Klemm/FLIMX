classdef studyIS < handle
    %=============================================================================================================
    %
    % @file     studyIS.m
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
    % @brief    A class to represent info data of a study
    %
    properties(GetAccess = protected, SetAccess = private)
        myParent = []; %handle to study
        subjectNames = cell(0,0); %list of subject names
        subjectInfoColumnNames = cell(0,0); %descriptions of patient data columns
        filesHeaders = {'Subject' 'Meas. Chs' 'Result Chs'}; %descriptions of channel data columns
        subjectInfo = cell(0,0); %additional patient data
        subjectInfoConditionDefinition = cell(0,0); %condition / combination between patient data
        resultFileChs = cell(0,0); %result channels of each subject
        measurementFileChs = cell(0,0); %measurement channels of each subject
        MVGroupTargets = cell(0,0); %cluster parameters for this study
        resultCrossSection = cell(0,0); %cross sections for each subject
        resultROICoordinates = cell(0,0); %rois for each subject  
        resultZScaling = cell(0,0); %z scaling for each subject
        resultColorScaling = cell(0,0); %color scaling for each subject
        allFLIMItems = cell(0,0); %selected FLIM parameters, for each subject and channel
        IRFInfo = []; %information per channel: which IRF was used, sum of IRF
        arithmeticImageInfo = cell(0,2);
        conditionColors = cell(2,0); %colors for conditions
    end
    
    properties (Dependent = true)
        nrSubjects = [];
    end
    
    methods
        %% general methods
        function this = studyIS(parent)
            %constructor for studyIS
            this.myParent = parent;
            %             this.subjectFilesHeaders = [{'Subject'} {'Channels'}];
            this.subjectInfoColumnNames(1,1) = {'column 1'};
            this.subjectInfoConditionDefinition(1,1) = {[]};
            this.conditionColors(1,1) = {FDTree.defaultConditionName()};
            this.conditionColors(2,1) = {studyIS.makeRndColor()};
        end
        
        %% input methods
        function loadStudyIS(this,import)
            %load study info set
            [import,dirtyFlag] = studyIS.checkStudyConsistency(import);            
            this.subjectNames = import.subjectNames;
            this.subjectInfoColumnNames = import.subjectInfoColumnNames;
            %             this.subjectFilesHeaders = import.subjectFilesHeaders;
            this.subjectInfo = import.subjectInfo;
            this.subjectInfoConditionDefinition = import.subjectInfoConditionDefinition;
            this.allFLIMItems = import.allFLIMItems;
            this.resultFileChs = import.resultFileChs;
            this.measurementFileChs = import.measurementFileChs;
            this.MVGroupTargets = import.MVGroupTargets;
            this.resultROICoordinates = import.resultROICoordinates;
            this.resultZScaling = import.resultZScaling;
            this.resultColorScaling = import.resultColorScaling;
            this.resultCrossSection = import.resultCrossSection;
            this.IRFInfo = import.IRFInfo;
            this.arithmeticImageInfo = import.arithmeticImageInfo;
            this.conditionColors = import.conditionColors;
            this.sortSubjects();
            this.setDirty(dirtyFlag);
        end
        
        function setSubjectName(this,subjects,idx)
            %set list of subjects or single subject
            if(isempty(idx))
                %set all subjects (initial cas)
                this.subjectNames = [];
                this.subjectNames = subjects;
            else
                %set a single subject
                this.subjectNames(idx,1) = {subjects};
                this.setDirty(true);
            end
        end
        
        function setSubjectInfoColumnName(this,newColumnName,idx)
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
        
        function setSubjectInfoConditionalColumnDefinition(this,ref,idx)
            %set definition def of a conditional column with the index idx
            if(idx <= size(this.subjectInfoConditionDefinition,1))
                %set single definition
                this.subjectInfoConditionDefinition(idx,1) = ref;
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
        
        function setMVGroupTargets(this,MVGroupID,targets)
            %set MVGroup parameter for subject(s)
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
        
        function setMVGroupName(this,MVGroupID,name)
            %set new MVGroup name
            MVGroupNr = this.MVGroupName2idx(MVGroupID);
            if(~isempty(MVGroupNr))
                this.MVGroupTargets(1,MVGroupNr) = {name};
            end
        end
        
        function clearROI(this,idx)
            %reset ROI for subject
            if(isempty(idx))
                this.resultROICoordinates = [];
                this.resultROICoordinates = cell(size(this.subjectNames));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultROICoordinates(idx) = cell(1,1);
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
        
        function setResultOnHDD(this,subName,ch)
            %mark a channel ch as loaded for subject subName
            idx = this.subName2idx(subName);
            if(isempty(idx))
                %subject not in study
                return
            end
            this.resultFileChs(idx,ch) = {ch};
            this.setDirty(true);
        end
        
        function setMeasurementOnHDD(this,subName,ch)
            %mark a channel ch as loaded for subject subName
            idx = this.subName2idx(subName);
            if(isempty(idx))
                %subject not in study
                return
            end
            this.measurementFileChs(idx,ch) = {ch};
            this.setDirty(true);
        end
        
        function setSubjectInfo(this,irow,icol,newData)
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
        
        function setResultROICoordinates(this,subName,ROIType,ROICoord)
            %set the ROI vector for subject subName
            subIdx = this.subName2idx(subName);
            if(isempty(subIdx))
                %subject not in study or ROIVec size is wrong
                return
            end
            tmp = this.resultROICoordinates{subIdx};
            if(isempty(ROICoord))
                ROICoord = zeros(3,2,'uint16');
            elseif(size(ROICoord,1) == 2 && size(ROICoord,2) == 1)
                ROICoord(:,2:3) = zeros(2,2,'like',ROICoord);
            end
            if(isempty(ROIType))
                %set all ROI coordinates at once
                if(size(ROICoord,1) >= 7 && size(ROICoord,2) == 3 && size(ROICoord,3) >= 2)
                    tmp = int16(ROICoord);
                end
            else
                if(isempty(tmp) || size(tmp,1) < 7 || size(tmp,2) < 3)
                    tmp = ROICtrl.getDefaultROIStruct();
                end
                ROIType = int16(ROIType);
                idx = find(abs(tmp(:,1,1) - ROIType) < eps,1,'first');
                if(isempty(idx))
                    %new ROI
                    this.addResultROIType(ROIType);
                    tmp = this.resultROICoordinates{subIdx};
                    idx = find(abs(tmp(:,1,1) - ROIType) < eps,1,'first');
                end
                if(ROIType >= 1000 && ROIType < 4000 && size(ROICoord,1) == 2 && size(ROICoord,2) == 3)
                    %ETDRS, rectangle or cricle                    
                    tmp(idx,1:3,1:2) = int16(ROICoord');                    
                elseif(ROIType > 4000 && ROIType < 5000 && size(ROICoord,1) == 2)
                    %polygons
                    if(size(ROICoord,2) > size(tmp,2))
                        tmpNew = zeros(size(tmp,1),size(ROICoord,2),2,'int16');
                        tmpNew(:,1:size(tmp,2),:) = tmp;
                        tmpNew(idx,1:size(ROICoord,2),:) = int16(ROICoord');
                        tmp = tmpNew;
                    else
                        tmp(idx,1:size(ROICoord,2),1:2) = int16(ROICoord');
                        tmp(idx,max(4,size(ROICoord,2)+1):end,:) = 0;
                    end
                    %polygon could have shrinked, remove trailing zeros
                    idxZeros = squeeze(any(any(tmp,1),3));
                    idxZeros(1:3) = true;
                    tmp(:,find(idxZeros,1,'last')+1:end,:) = [];
                end
                %store ROIType just to be sure it is correct
                tmp(idx,1,1) = ROIType;
            end
            this.resultROICoordinates(subIdx) = {tmp};
            this.setDirty(true);
        end
        
        function deleteResultROICoordinates(this,ROIType)
            %delete the ROI coordinates for ROIType
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
            end
        end
        
        function addResultROIType(this,ROIType)
            %add an empty ROIType to all subjects in this study
            for i = 1:this.nrSubjects
                tmp = this.resultROICoordinates{i};
                if(isempty(tmp))
                    continue
                end
                [val,idx] = min(abs(tmp(:,1,1) - ROIType));
                if(val > 0)
                    tmpNew = zeros(size(tmp,1)+val,size(tmp,2),size(tmp,3),'int16');
                    tmpNew(1:idx,:,:) = tmp(1:idx,:,:);
                    tmpNew(idx+val+1:end,:,:) = tmp(idx+1:end,:,:);
                    tmpNew(idx+1:idx+val,1,1) = (tmp(idx,1,1)+1 : 1 : tmp(idx,1,1)+val)';
                    tmp = tmpNew;
                    this.resultROICoordinates(i) = {tmp};
                end
            end
        end
        
        function setResultZScaling(this,subName,ch,dType,dTypeNr,zValues)
            %set the ROI vector for subject subName
            idx = this.subName2idx(subName);
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
        end
        
        function setResultColorScaling(this,subName,ch,dType,dTypeNr,colorBorders)
            %set the color scaling at subject subjectID
            idx = this.subName2idx(subName);
            if(isempty(idx) || isempty(dType) || length(colorBorders) ~= 3)
                %subject not in study or color values size is wrong
                return
            end
            tmp = this.resultColorScaling{idx};
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
            tmp{find(idxNr,1),4} = colorBorders;
            this.resultColorScaling(idx) = {tmp};
            this.setDirty(true);
        end
        
        function setResultCrossSection(this,subName,dim,csDef)
            %set the cross section for subject subName
            idx = this.subName2idx(subName);
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
        end
        
        function setAllFLIMItems(this,subName,channel,items)
            %set selected FLIM parameters for subject subName
            idx = this.subName2idx(subName);
            if(isempty(idx) || channel < 1)
                %subject not in study
                return
            end
            this.allFLIMItems(idx,channel) = {items};
            this.setDirty(true);
        end
                
        function setConditionalColumnDefinition(this,colName,val)
            %set definition for conditional column
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
        
        function setIRFInfo(this,ch,id,timeChannels,irf)
            %set IRF info
            this.IRFInfo.timeChannels = timeChannels;
            this.IRFInfo.id = id;
            if(isnumeric(ch) && ~isempty(irf))
                irf = irf./max(irf(:))*15000; % 15000 is defined by B&H
                this.IRFInfo.integral(ch) = {sum(irf(:))};
            end
        end
        
        function setArithmeticImageDefinition(this,aiName,aiStruct)
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
                    this.arithmeticImageInfo(1,2) = {aiStruct};
                else
                    this.arithmeticImageInfo(end+1,1) = {aiName};
                    this.arithmeticImageInfo(end,2) = {aiStruct};
                end
            else
                this.arithmeticImageInfo(idx,2) = {aiStruct};
            end
            this.setDirty(true);
        end
        
        function removeArithmeticImageDefinition(this,aiName)
            %set arithmetic image info
            idx = find(strcmp(aiName,this.arithmeticImageInfo(:,1)));
            if(~isempty(idx))
                this.arithmeticImageInfo(idx,:) = [];
                if(isempty(this.arithmeticImageInfo))
                    this.arithmeticImageInfo = cell(1,2);
                end
                this.setDirty(true);
            end
        end
        
        function addSubject(this,subName)
            % add a subject to this study
            if(~isempty(this.subName2idx(subName)))
                %this is already subject
                return
            end
            this.subjectNames(end+1,1) = {subName};
            this.resultFileChs(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
            this.measurementFileChs(end+1,:) = cell(1,max(1,size(this.measurementFileChs,2)));
            this.subjectInfo(end+1,:) = cell(1,max(1,size(this.subjectInfo,2)));
            this.resultROICoordinates(end+1) = cell(1,1);
            this.resultZScaling(end+1) = cell(1,1);
            this.resultColorScaling(end+1) = cell(1,1);
            this.resultCrossSection(end+1) = cell(1,1);
            this.allFLIMItems(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
            %sort subjects
            this.sortSubjects();
            this.checkConditionRef([]);
            this.setDirty(true);
        end
                       
        function addColumn(this,name)
            %insert new column at the end of the table            
            this.subjectInfoColumnNames(end+1,1)= {name};
            this.subjectInfo(:,end+1)= cell(max(1,size(this.subjectInfo,1)),1);
            this.subjectInfoConditionDefinition(end+1,1) = cell(1,1);
            this.setDirty(true);
        end
        
        function addConditionalColumn(this,val)
            %create a new conditional column out of two existing columns
            ref.colA = val.list{val.colA};      %column A
            ref.colB = val.list{val.colB};      %column B
            ref.logOp = val.ops{val.logOp};     %logical operator
            ref.relA = val.ops{val.relA + 6};   %relational operator of colA
            ref.relB = val.ops{val.relB + 6};   %relational operator of colB
            ref.valA = val.valA;                %relation value of colA
            ref.valB = val.valB;                %relation value of colB            
            this.addColumn(val.name);
            %save reference for condition / combination
            n = this.subjectInfoColumnName2idx(val.name);
            this.subjectInfoConditionDefinition{n,1} = ref;
            this.setConditionColor(val.name,[]);
            %update conditions / combinations
            this.checkConditionRef(n);
            this.setDirty(true);
        end
        
        function insertSubject(this,subName,data)
            %insert subject data into studyIS
            %from clipboard or while importing studies            
            subjectPos = this.subName2idx(subName);
            this.resultFileChs(subjectPos,1:length(data.resultFileChs)) = data.resultFileChs;
            this.measurementFileChs(subjectPos,1:length(data.measurementFileChs)) = data.measurementFileChs;
            this.allFLIMItems(subjectPos,1:length(data.allFLIMItems)) = data.allFLIMItems;            
            %fill subject info fields with data
            for i = 1:length(data.subjectInfoColumnNames)
                str = data.subjectInfoColumnNames{i,1};
                [~, idx] = ismember(str,this.subjectInfoColumnNames);
                this.subjectInfo(subjectPos,idx) = data.subjectInfo(1,i);
            end
            %update ROICoordinates, if neccessary
            subVec = 1:this.nrSubjects;
            subVec(subjectPos) = [];
            if(~isempty(subVec))
                roiStudy = this.resultROICoordinates{subVec(1)};
                roiSubject = data.resultROICoordinates{1,1};
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
                    data.resultROICoordinates{1,1} = roiSubject;
                    %check which ROIs are missing in the study
                    d = setdiff(roiSubject(:,1,1),roiStudy(:,1,1));
                    for i = 1:length(d)
                        this.addResultROIType(d(i));
                    end
                end
            end
            this.resultROICoordinates(subjectPos) = data.resultROICoordinates;
            this.resultZScaling(subjectPos) = data.resultZScaling;
            this.resultColorScaling(subjectPos) = data.resultColorScaling;
            this.resultCrossSection(subjectPos) = data.resultCrossSection;
            this.setDirty(true);
        end
        
        function importStudyInfo(this,raw,mode)
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
            this = studyIS.checkStudyConsistency(this);
            this.sortSubjects();
            this.checkConditionRef([]); %update conditional columns
            this.setDirty(true);
        end
        
        function setConditionColor(this,cName,val)
            %set condition color
            if(isempty(val) || length(val) ~= 3)
                val = studyIS.makeRndColor();
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
        
        %% output methods
        function items = getAllFLIMItems(this,subName,channel)
            if(isempty(subName))
                %get FLIM parameters for all subjects
                items = this.allFLIMItems;
            else
                %get FLIM parameters for subject subName
                idx = this.subName2idx(subName);
                if(isempty(idx) || channel < 1 || channel > size(this.resultFileChs,2))
                    %subject not in study or channel not valid
                    items = [];
                    return
                end
                items = this.allFLIMItems{idx,channel};
            end
        end
                
        function export = makeExportStruct(this,subjectID)
            %make all data of this class as struct
            idx = this.subName2idx(subjectID);
            if(isempty(idx))
                idx = ':';
            end
            export.subjectNames = this.subjectNames(idx,:);
            export.subjectInfoColumnNames = this.subjectInfoColumnNames;
            %             export.subjectFilesHeaders = this.subjectFilesHeaders;
            export.subjectInfo = this.subjectInfo(idx,:);
            export.subjectInfoConditionDefinition = this.subjectInfoConditionDefinition;
            export.resultFileChs = this.resultFileChs(idx,:);
            export.measurementFileChs = this.measurementFileChs(idx,:);
            export.MVGroupTargets = this.MVGroupTargets;
            export.resultROICoordinates = this.resultROICoordinates(idx);
            export.resultZScaling = this.resultZScaling(idx);
            export.resultColorScaling = this.resultColorScaling(idx);
            export.resultCrossSection = this.resultCrossSection(idx);
            export.allFLIMItems = this.allFLIMItems(idx,:);
            export.IRFInfo = this.IRFInfo;
            export.arithmeticImageInfo = this.arithmeticImageInfo;
            export.conditionColors = this.conditionColors;
        end
        
        function exportStudyInfo(this,file)
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
        
        function out = getConditionalColumnDefinition(this,idx)
            %return definition of a conditional column with index idx
            if(~isempty(idx) && ~isempty(this.subjectInfoColumnNames) && length(this.subjectInfoConditionDefinition) >= idx)
                out = this.subjectInfoConditionDefinition{idx,1};
            else
                out = [];
            end
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
        
        function out = getAllSubjectNames(this)
            %get all subjects of this study as cell array of strings
            out = this.subjectNames;
        end
        
        function out = getResultFileChs(this,subName)
            %get indices channels which carry a result
            if(isempty(subName))
                out = this.resultFileChs;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = this.resultFileChs(subName,:);
            end
        end
        
        function out = getMeasurementFileChs(this,subName)
            %get indices channels which carry a measurement
            if(isempty(subName))
                out = this.measurementFileChs;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = this.measurementFileChs(subName,:);
            end
        end
        
        function out = getFileChs(this,subName)
            %get indices channels which carry a measurement, a result or both for a subject
            m = this.getMeasurementFileChs(subName);
            r = this.getResultFileChs(subName);
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
        
        function out = getMVGroupNames(this,mode)
            %get string of study MVGroups
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            out = cell(0,0);
            if(isempty(this.MVGroupTargets))
                return
            end            
            MVGroupStr = this.MVGroupTargets(1,:);
            MVGroupTargets = this.MVGroupTargets(2,:);
            if(mode == 0)
                out = MVGroupStr;
                return
            end            
            %get only computable MVGroups
            for i=1:length(MVGroupStr)
                if(isempty(MVGroupTargets{i}.x) || isempty(MVGroupTargets{i}.y))
                    continue
                end
                out(end+1,1) = MVGroupStr(i);
            end
        end
        
        function out = getMVGroupTargets(this,MVGroupID)
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
                
        function out = getSubjectInfo(this,j)
            %return definitions of all columns in subject info
            if(isempty(j))
                out = this.subjectInfo;
            else
                if(~isempty(this.subjectInfo))
                    out = this.subjectInfo(j,:);
                end
            end
        end
        
        function out = getSubjectInfoConditionalColumnDefinitions(this)
            %return definitions of all conditional columns
            out = this.subjectInfoConditionDefinition;
        end
        
        function out = getResultROICoordinates(this,subName,ROIType)
            %return ROI coordinates for specific subject and ROI type
            if(isempty(subName))
                out = this.resultROICoordinates;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = double(cell2mat(this.resultROICoordinates(subName)));
                if(~isempty(ROIType) && isscalar(ROIType) && ROIType > 1000)
                    idx = find(abs(out(:,1,1) - ROIType) < eps,1,'first');
                    if(~isempty(idx))
                        out = squeeze(out(idx,:,:))';
                        out = out(1:2,2:end);
                        if(ROIType < 4000)
                            out = out(1:2,1:2);
                        elseif(ROIType > 4000 && ROIType < 5000)
                            %remove potential trailing zeros
                            idx = any(out,1);
                            idx(1:3) = true;
                            out(:,find(idx,1,'last')+1:end) = [];
                        end
                    else
                        out = [];
                    end
                elseif(isempty(ROIType))
                    %return all ROI coordinates                    
                else
                    out = [];
                end
            end
        end
        
        function out = getResultZScaling(this,subName,ch,dType,dTypeNr)
            %return z scaling values for specific subject and data type
            if(isempty(subName))
                out = this.resultZScaling;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = [];
                tmp = this.resultZScaling{subName};
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
        
        function out = getResultColorScaling(this,subName,ch,dType,dTypeNr)
            %return color scaling values for specific subject and data type
            if(isempty(subName))
                out = this.resultColorScaling;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = [];
                tmp = this.resultColorScaling{subName};
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
                
        function out = getResultCrossSection(this,subName)
            %get result cross section definition
            if(isempty(subName))
                out = this.resultCrossSection;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = cell2mat(this.resultCrossSection(subName));
            end
        end        
        
%         function data = getSubjectFromClipboard(this,subName)
%             %
%             idx = this.subName2idx(subName);
%             data.resultFileChs = this.resultFileChs(idx,:);
%             data.measurementFileChs = this.measurementFileChs(idx,:);
%             data.resultROI = this.resultROI(idx);
%             data.resultCrossSection = this.resultCrossSection(idx);
%             data.subjectInfo = this.subjectInfo(idx,:);
%             data.subjectInfoColumnNames = this.subjectInfoColumnNames;
%             data.allFLIMItems = this.allFLIMItems(idx,:);
%         end
        
        function data = getSubjectFilesData(this)
            %merge subjects and subjectFilesData
            if(isempty(this.subjectNames))
                data = [];
                return
            end
            data = cell(this.nrSubjects,3);
            data(:,1) = this.subjectNames;            
            for i = 1:this.nrSubjects
                %measurement files
                chs = this.measurementFileChs(i,:);
                str = '';
                for j = 1:length(chs)
                    if(~isempty(chs{j}))
                        if(isempty(str))
                            str = num2str(chs{j});
                        else
                            str = sprintf('%s, %d',str,chs{j});
                        end
                    end
                end
                if(isempty(str))
                    str = 'none';
                end
                data(i,2) = {str};
                %result files
                chs = this.resultFileChs(i,:);
                str = '';
                for j = 1:length(chs)
                    if(~isempty(chs{j}))
                        if(isempty(str))
                            str = num2str(chs{j});
                        else
                            str = sprintf('%s, %d',str,chs{j});
                        end
                    end
                end
                if(isempty(str))
                    str = 'none';
                end
                data(i,3) = {str};                
            end
        end
        
        function out = getDataFromStudyInfo(this,descriptor,subName,colName)
            %get data from study info defined by descriptor
            switch descriptor
                case 'subjectInfoData'
                    out = this.subjectInfo;
                    if(nargin >= 3)
                        %return subject info only for specific subject
                        idx = this.subName2idx(subName);
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
        
%         function out = getSubjectInfoColumnNames(this,columnType)
%             %get list of subject info columns, columnType: [] - all columns; 'reference' - only reference columns; 'condition' - only conditional columns
%             out = cell(0,0);
%             if(isempty(columnType))
%                 out = this.subjectInfoColumnNames;
%             else
%                 ref = this.getSubjectInfoConditionalColumnDefinitions();
%                 if(strcmp(columnType,'reference'))
%                     idx = cellfun('isempty',ref);
%                 elseif(strcmp(columnType,'condition'))
%                     idx = ~(cellfun('isempty',ref));
%                 else
%                     %wrong column type
%                     return                    
%                 end
%                 out = this.subjectInfoColumnNames(idx,1);
% %                 out(end+1,1) = {FDTree.defaultConditionName()};   %define default 'no condition'
% %                 if(~isempty(this.subjectInfoColumnNames(idx,1)))
% %                     out(end+1:end+(sum(idx(:))),1) = this.subjectInfoColumnNames(idx,1);
% %                 end
%             end
%         end
        
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
        
        function [aiNames, aiParams] = getArithmeticImageDefinition(this)
            %
            if(isempty(this.arithmeticImageInfo))
                aiNames = {''}; aiParams = {''};
                return
            end
            aiNames = this.arithmeticImageInfo(:,1);
            aiParams = this.arithmeticImageInfo(:,2);
        end
        
        function out = getAllArithmeticImageInfo(this)
            %
            out = this.arithmeticImageInfo;
        end
        
        function out = getAllIRFInfo(this)
            %returns the IRFInfo struct
            out = this.IRFInfo;
        end
        
%         function out = getAllConditionColors(this)
%             %return colors of all conditions
%             out = this.conditionColors;
%         end
        
        function out = getConditionColor(this,cName)
            %returns study condition color
            if(strcmp(cName,FDTree.defaultConditionName()))
                idx = 1;
            else
                idx = find(strcmp(cName,this.conditionColors(1,:)), 1);
            end
            if(isempty(idx)) %we don't know that condition
                out = studyIS.makeRndColor();
            else
                out = this.conditionColors{2,idx};
            end
        end
        
        function out = getAboutInfo(this)
            %get about info structure
            out = this.myParent.getAboutInfo();
        end
        
        %% removing methods
        function removeSubject(this,subName)
            %remove subject subName from this study
            idx = this.subName2idx(subName);
            if(isempty(idx))
                %subject not in study
                return
            end
            if(length(this.subjectNames)>1)
                %remove arbitrary subject
                idx = this.subName2idx(subName);
                this.resultFileChs(idx,:) = [];
                this.measurementFileChs(idx,:) = [];
                this.resultROICoordinates(idx) = [];
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
                this.resultZScaling = cell(0,0);
                this.resultColorScaling = cell(0,0);
                this.resultCrossSection = cell(0,0);
                this.subjectNames = cell(0,0);
                this.subjectInfo = cell(0,0);
                this.allFLIMItems = cell(0,0);
            end
            this.setDirty(true);
        end
        
        function removeSubjectResult(this,subName)
            %remove the results of subject subName from this study
            idx = this.subName2idx(subName);
            if(~isempty(idx))
                this.resultFileChs(idx,:) = cell(1,max(1,size(this.resultFileChs,2)));
                this.resultROICoordinates(idx) = cell(1,1);
                this.resultZScaling(idx) = cell(1,1);
                this.resultColorScaling(idx) = cell(1,1);
                this.resultCrossSection(idx) = cell(1,1);
                this.allFLIMItems(idx) = cell(1,1);
                this.setDirty(true);
            end            
        end
        
        function removeColumn(this,colName)
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
                idx = find(strcmp(colName,this.conditionColors(1,:)), 1);
                if(~isempty(idx))
                    this.conditionColors(:,idx) = [];
                end
            end
            this.setDirty(true);
        end
        
        function removeMVGroup(this,MVGroupID)
            %remove MVGroup
            MVGroupNr = this.MVGroupName2idx(MVGroupID);
            this.MVGroupTargets(:,MVGroupNr) = [];
            this.setDirty(true);
        end
        
        %% computation and other methods
        function swapColumn(this,col,n)
            %swap column with its nth neighbor
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
            this.setDirty(true);
        end
        
        function checkConditionRef(this,colN)
            %update combinations columns
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
        
        function idx = subName2idx(this,subName)
            %get the index of a subject or check if index is valid
            idx = [];
            if(ischar(subName))
                idx = find(strcmp(subName,this.subjectNames),1);
            elseif(isnumeric(subName))
                if(subName <= this.nrSubjects)
                    idx = subName;
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
        
        function idx = subjectInfoColumnName2idx(this,columnName)
            %get the index of a subject info column or check if index is valid
            idx = [];
            if(ischar(columnName))
                idx = find(strcmp(columnName,this.subjectInfoColumnNames),1);
            elseif(isnumeric(columnName))
                if(columnName <= length(this.subjectInfoColumnNames))
                    idx = columnName;
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
            elseif(isnumeric(id))
                if(id <= this.nrSubjects)
                    name = this.subjectNames{id};
                end
            end
        end
        
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
                oldStudy.resultZScaling = oldStudy.resultZScaling(idx);
                oldStudy.resultColorScaling = oldStudy.resultColorScaling(idx);
                oldStudy.resultCrossSection = oldStudy.resultCrossSection(idx);
                oldStudy.allFLIMItems = oldStudy.allFLIMItems(idx,:);
                out = oldStudy;
            end
        end
        
        function oldStudy = updateStudyInfoSet(this,oldStudy)
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
            
            this.setDirty(true);
        end
        
        function setDirty(this,flag)
            %set dirty flag for this study
            this.myParent.setDirty(logical(flag));
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
        
    end %methods
    
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
                testStudy.resultROICoordinates(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultROICoordinates = testStudy.resultROICoordinates(1:nrSubjects);
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
                testStudy.conditionColors(2,end) = {studyIS.makeRndColor()};
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
                testStudy.conditionColors(2,1) = {studyIS.makeRndColor()};
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
    end
    
end