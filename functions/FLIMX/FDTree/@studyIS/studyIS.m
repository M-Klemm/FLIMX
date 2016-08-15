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
        myParent = [];      %handle to study
        subjects = cell(0,0); %list of subject names
        infoHeaders = cell(0,0); %descriptions of patient data columns
        filesHeaders = {'Subject' 'Meas. Chs' 'Result Chs'}; %descriptions of channel data columns
        subjectInfo =  cell(0,0);%additional patient data
        subjectInfoCombi = cell(0,0); %condition / combination between patient data
        resultFileChs = cell(0,0); %result channels of each subject
        measurementFileChs = cell(0,0); %measurement channels of each subject
        studyClusters = cell(0,0); %cluster parameters for this study
        resultCuts = cell(0,0); %cuts for each subject
        resultROICoordinates = cell(0,0); %rois for each subject  
        resultZScaling = cell(0,0); %z scaling for each subject  
        allFLIMItems = cell(0,0); %selected FLIM parameters, for each subject and channel
        IRFInfo = []; %information per channel: which IRF was used, sum of IRF
        arithmeticImageInfo = cell(0,2);
        viewColors = cell(2,0); %colors for views
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
            this.infoHeaders(1,1) = {'column 1'};
            this.subjectInfoCombi(1,1) = {[]};
            this.viewColors(1,1) = {'-'};
            this.viewColors(2,1) = {studyIS.makeRndColor()};
        end
        
        %% input methods
        function loadStudyIS(this,import)
            %load study info set
            [import,dirtyFlag] = studyIS.checkStudyConsistency(import);            
            this.subjects = import.subjects;
            this.infoHeaders = import.infoHeaders;
            %             this.subjectFilesHeaders = import.subjectFilesHeaders;
            this.subjectInfo = import.subjectInfo;
            this.subjectInfoCombi = import.subjectInfoCombi;
            this.allFLIMItems = import.allFLIMItems;
            this.resultFileChs = import.resultFileChs;
            this.measurementFileChs = import.measurementFileChs;
            this.studyClusters = import.studyClusters;
            this.resultROICoordinates = import.resultROICoordinates;
            this.resultZScaling = import.resultZScaling;
            this.resultCuts = import.resultCuts;
            this.IRFInfo = import.IRFInfo;
            this.arithmeticImageInfo = import.arithmeticImageInfo;
            this.viewColors = import.viewColors;
            this.sortSubjects();
            this.setDirty(dirtyFlag);
        end
        
        function setSubjects(this,subjects,idx)
            %set list of subjects or single subject
            if(isempty(idx))
                %set all subjects (initial cas)
                this.subjects = [];
                this.subjects = subjects;
            else
                %set a single subject
                this.subjects(idx,1) = {subjects};
                this.setDirty(true);
            end
        end
        
        function setSubjectInfoHeaders(this,infoHeaders,idx)
            %set subjectInfoHeader(s)
            if(isempty(idx))
                %set all infoHeaders (initial case)
                this.infoHeaders = infoHeaders;
            else
                %set a single subjectInfoHeader
                oldName = this.infoHeaders{idx};
                %check if renamed colum is a reference for a combination
                for i=1:length(this.infoHeaders)
                    ref = this.subjectInfoCombi{i};
                    if(isempty(ref))
                        %column is not a combination
                        continue
                    end
                    if(strcmp(ref.colA,oldName))
                        %reference found
                        ref.colA = infoHeaders;
                        this.subjectInfoCombi{i} = ref;
                    end
                    if(strcmp(ref.colB,oldName))
                        %reference found
                        ref.colB = infoHeaders;
                        this.subjectInfoCombi{i} = ref;
                    end
                end
                %set new header
                this.infoHeaders{idx} = infoHeaders;
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
        
        function setSubjectInfoCombi(this,ref,idx)
            %set subjectInfoCombi
            if(isempty(idx))
                %set all subjectInfoCombi (initial case)
                this.subjectInfoCombi = [];
                this.subjectInfoCombi = ref;
            else
                %set single subjectInfoCombi
                this.subjectInfoCombi(idx,1) = ref;
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
        
        function setClusterTargets(this,clusterID,targets)
            %set cluster parameter for subject(s)
            if(nargin < 2)
                %set all cluster parameter (initial case)
                this.studyClusters = [];
                this.studyClusters = targets;
            else
                %set single value
                clusterNr = this.clusterName2idx(clusterID);
                if(isempty(clusterNr))
                    %add cluster
                    this.studyClusters(:,end+1) = cell(2,1);
                    clusterNr = size(this.studyClusters,2);
                    this.studyClusters(1,clusterNr) = {clusterID};
                end
                %set targets
                this.studyClusters(2,clusterNr) = {targets};
                this.setDirty(true);
            end
        end
        
        function setClusterName(this,clusterID,name)
            %set new cluster name
            clusterNr = this.clusterName2idx(clusterID);
            if(~isempty(clusterNr))
                this.studyClusters(1,clusterNr) = {name};
            end
        end
        
        function clearROI(this,idx)
            %reset ROI for subject
            if(isempty(idx))
                this.resultROICoordinates = [];
                this.resultROICoordinates = cell(size(this.subjects));
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
                this.resultZScaling = cell(size(this.subjects));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultZScaling(idx) = cell(1,1);
                    this.setDirty(true);
                end
            end
        end
        
        function clearCuts(this,idx)
            %reset cross sections
            if(isempty(idx))
                this.resultCuts = cell(size(this.subjects));
            else
                %set single value
                idx = this.subName2idx(idx);
                if(~isempty(idx))
                    this.resultCuts(idx) = cell(1,1);
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
            %set new value of subjectInfo in table studyData
            this.subjectInfo(irow,icol) = {newData};
            this.checkConditionRef([]);
            this.setDirty(true);
        end
        
        function setResultROICoordinates(this,subName,ROIType,ROICoord)
            %set the ROI vector for subject subName
            idx = this.subName2idx(subName);
            if(isempty(idx))
                %subject not in study or ROIVec size is wrong
                return
            end
            tmp = this.resultROICoordinates{idx};
            if(isempty(ROICoord))
                ROICoord = zeros(3,2,'uint16');
            elseif(size(ROICoord,1) == 2 && size(ROICoord,2) == 1)
                ROICoord(:,2:3) = zeros(2,2,'like',ROICoord);
            end
            if(isempty(ROIType))
                %set all ROI coordinates at once
                if(size(ROICoord,1) == 7 && size(ROICoord,2) == 3 && size(ROICoord,3) >= 2)
                    tmp = int16(ROICoord);
                end
            else
                if(isempty(tmp) || size(tmp,1) < 7 || size(tmp,2) < 3)
                    tmp = zeros(7,3,2,'int16');
                end
                if(ROIType >= 1 && ROIType < 6 && size(ROICoord,1) == 2 && size(ROICoord,2) == 3)
                    tmp(ROIType,1:3,1:2) = int16(ROICoord');
                elseif(ROIType >= 6 && ROIType <= 7 && size(ROICoord,1) == 2)
                    %polygons
                    if(size(ROICoord,2) > size(tmp,2))
                        tmpNew = zeros(7,size(ROICoord,2),2,'int16');
                        tmpNew(:,1:size(tmp,2),:) = tmp;
                        tmpNew(ROIType,1:size(ROICoord,2),:) = int16(ROICoord');
                        tmp = tmpNew;
                    else
                        tmp(ROIType,1:size(ROICoord,2),1:2) = int16(ROICoord');
                        tmp(ROIType,max(4,size(ROICoord,2)+1):end,:) = 0;
                    end
                    %polygon could have shrinked, remove trailing zeros
                    idxZeros = squeeze(any(any(tmp,1),3));
                    idxZeros(1:3) = true;
                    tmp(:,find(idxZeros,1,'last')+1:end,:) = [];
                end
            end
            this.resultROICoordinates(idx) = {tmp};
            this.setDirty(true);
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
            tmp{find(idxNr,1),4} = zValues;
            this.resultZScaling(idx) = {tmp};
            this.setDirty(true);
        end
        
        function setCutVec(this,subName,dim,cutVec)
            %set the cut vector for subject subName
            idx = this.subName2idx(subName);
            if(isempty(idx) || length(cutVec) ~= 3)
                %subject not in study or cutVec size is wrong
                return
            end
            tmp = this.resultCuts{idx};
            switch upper(dim)
                case 'X'
                    tmp(1:3) = cutVec;
                case 'Y'
                    tmp(4:6) = cutVec;
            end
            this.resultCuts(idx) = {tmp};
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
                
        function setCondColumn(this,colName,opt)
            %edit existing conditional column
            n = this.infoHeaderName2idx(colName);
            if(isempty(opt))
                %delete condition
                ref = [];
                this.subjectInfo(:,n) = cell(this.nrSubjects,1);
            else
                ref.colA = opt.list{opt.colA};      %column A
                ref.colB = opt.list{opt.colB};      %column B
                ref.logOp = opt.ops{opt.logOp};     %logical operator
                ref.relA = opt.ops{opt.relA + 5};   %relational operator of colA
                ref.relB = opt.ops{opt.relB + 5};   %relational operator of colB
                ref.valA = opt.valA;                %relation value of colA
                ref.valB = opt.valB;                %relation value of colB
            end
            %save new reference for condition / combination
            this.subjectInfoCombi{n} = ref;
            
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
        
        function setArithmeticImageInfo(this,aiName,aiStruct)
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
        
        function removeArithmeticImageInfo(this,aiName)
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
            this.subjects(end+1,1) = {subName};
            this.resultFileChs(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
            this.measurementFileChs(end+1,:) = cell(1,max(1,size(this.measurementFileChs,2)));
            this.subjectInfo(end+1,:) = cell(1,max(1,size(this.subjectInfo,2)));
            this.resultROICoordinates(end+1) = cell(1,1);
            this.resultZScaling(end+1) = cell(1,1);
            this.resultCuts(end+1) = cell(1,1);
            this.allFLIMItems(end+1,:) = cell(1,max(1,size(this.resultFileChs,2)));
            %sort subjects
            this.sortSubjects();
            this.checkConditionRef([]);
            this.setDirty(true);
        end
        
        function addSubjectInfoHeader(this,name)
            %add subjectInfoHeader at the end of the table
            this.infoHeaders(1,size(this.infoHeaders,2)+1) = {name};
            this.subjectInfo(:,size(this.infoHeaders,2)) = cell(size(this.subjectInfo,1),1);
            this.subjectInfoCombi(1,size(this.infoHeaders,2)) = cell(1,1);
            this.setDirty(true);
        end
        
        function addColumn(this,name)
            %insert new column at the end of the table            
            this.infoHeaders(end+1)= {name};
            this.subjectInfo(:,end+1)= cell(max(1,size(this.subjectInfo,1)),1);
            this.subjectInfoCombi(end+1) = cell(1,1);
            this.setDirty(true);
        end
        
        function addCondColumn(this,opt)
            %create a new conditional column out of two existing columns
            ref.colA = opt.list{opt.colA};      %column A
            ref.colB = opt.list{opt.colB};      %column B
            ref.logOp = opt.ops{opt.logOp};     %logical operator
            ref.relA = opt.ops{opt.relA + 5};   %relational operator of colA
            ref.relB = opt.ops{opt.relB + 5};   %relational operator of colB
            ref.valA = opt.valA;                %relation value of colA
            ref.valB = opt.valB;                %relation value of colB            
            this.addColumn(opt.name);
            %save reference for condition / combination
            n = this.infoHeaderName2idx(opt.name);
            this.subjectInfoCombi{n} = ref;
            this.setViewColor(opt.name,[]);
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
            for i = 1:length(data.infoHeaders)
                str = data.infoHeaders{i};
                [~, idx] = ismember(str,this.infoHeaders);
                this.subjectInfo(subjectPos,idx) = data.subjectInfo(1,i);
            end
            this.resultROICoordinates(subjectPos) = data.resultROICoordinates;
            this.resultZScaling(subjectPos) = data.resultZScaling;
            this.resultCuts(subjectPos) = data.resultCuts;
            this.setDirty(true);
        end
        
        function importXLS(this,raw,mode)
            %import subjects data from excel file, mode 1: delete all old, mode 2: update old & add new            
            %get subject and header names
            xlsSubs = raw(2:end,1);
            %make sure we have only strings as subjects
            idx = false(length(xlsSubs),1);
            for i = 1:length(xlsSubs)
                idx(i) = ischar(xlsSubs{i});
            end
            xlsSubs = xlsSubs(idx);
            
            %make sure we have only strings as headers
            xlsHeads = raw(1,2:end);
            idx = false(length(xlsHeads),1);
            for i = 1:length(xlsHeads)
                idx(i) = ischar(xlsHeads{i});
            end
            xlsHeads = xlsHeads(idx);
            xlsFile = raw(1,1);
            if(~ischar(xlsFile{1,1}))
                xlsFile = {'File'};
            end
            
            switch mode
                case 1 %Delete Old Info
                    this.infoHeaders = xlsHeads;
                    %                     this.subjectFilesHeaders = [xlsFile {'Channels'}];
                    this.subjectInfo = cell(0,0);
                    this.subjectInfoCombi = cell(size(this.infoHeaders));
                case 2 %Update and Add New
                    %determine already existing info headers
                    newHeads = setdiff(xlsHeads,this.infoHeaders);
                    diff = length(newHeads);
                    if(diff > 0) %add new info columns
                        this.infoHeaders(end+1:end+diff) = cell(diff,1);
                        this.subjectInfo(:,end+1:end+diff) = cell(size(this.subjectInfo,1),diff);
                        this.subjectInfoCombi(end+1:end+diff) = cell(diff,1);
                    end
                    %add new info headers
                    this.infoHeaders(end+1-diff:end) = newHeads;
                    %                     this.subjectFilesHeaders = [xlsFile {'Channels'}];
            end
            
            %update existing subjects and add new info
            for i = 1:length(this.subjects)
                idxXls = find(strcmp(this.subjects{i},xlsSubs),1);
                if(~isempty(idxXls)) %should not be empty...
                    if(size(this.subjectInfo,2) < length(this.infoHeaders))
                        diff = length(this.infoHeaders) - size(this.subjectInfo,2);
                        this.subjectInfo(:,end+1:end+diff) = cell(size(this.subjectInfo,1),diff);
                    elseif(size(this.subjectInfo,2) > length(this.infoHeaders)) %should not happen
                        this.subjectInfo = this.subjectInfo(:,1:length(this.infoHeaders));
                    end
                    this.subjectInfo(i,:) = cell(1,length(this.infoHeaders));
                    %add info data for specific subject
                    for j = 1:length(xlsHeads)
                        idxHead = find(strcmp(xlsHeads{j},this.infoHeaders),1);
                        this.subjectInfo(i,idxHead) = raw(idxXls+1,j+1);
                    end
                end
            end
            
            this = studyIS.checkStudyConsistency(this);
            this.sortSubjects();
            this.setDirty(true);
        end
        
        function setViewColor(this,vName,val)
            %set view color
            if(isempty(val) || length(val) ~= 3)
                val = studyIS.makeRndColor();
            end
            if(strcmp(vName,'-'))
                this.viewColors(2,1) = {val};
            else
                idx = find(strcmp(vName,this.viewColors(1,:)), 1);
                if(isempty(idx))
                    this.viewColors(1,end+1) = {vName};
                    this.viewColors(2,end) = {val};
                else
                    this.viewColors(2,idx) = {val};
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
%             data.resultFileChs = this.resultFileChs(idx,:);
%             data.measurementFileChs = this.measurementFileChs(idx,:);
%             data.resultROI = this.resultROI(idx);
%             data.resultCuts = this.resultCuts(idx);
%             data.subjectInfo = this.subjectInfo(idx,:);
%             data.infoHeaders = this.infoHeaders;
%             data.allFLIMItems = this.allFLIMItems(idx,:);
            export.subjects = this.subjects(idx,:);
            export.infoHeaders = this.infoHeaders;
            %             export.subjectFilesHeaders = this.subjectFilesHeaders;
            export.subjectInfo = this.subjectInfo(idx,:);
            export.subjectInfoCombi = this.subjectInfoCombi;
            export.resultFileChs = this.resultFileChs(idx,:);
            export.measurementFileChs = this.measurementFileChs(idx,:);
            export.studyClusters = this.studyClusters;
            export.resultROICoordinates = this.resultROICoordinates(idx);
            export.resultZScaling = this.resultZScaling(idx);
            export.resultCuts = this.resultCuts(idx);
            export.allFLIMItems = this.allFLIMItems(idx,:);
            export.IRFInfo = this.IRFInfo;
            export.arithmeticImageInfo = this.arithmeticImageInfo;
            export.viewColors = this.viewColors;
        end
        
        function exportXLS(this,file)
            %export Subject Data to Excel File
            if(exist(file,'file') == 2)
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
            if(size(this.subjects,1)<size(this.subjects,2))
                %check dimension
                ex(2:size(this.subjects,2)+1,1) = this.subjects(1,:)';
            else
                ex(2:size(this.subjects,1)+1,1)=this.subjects(:,1);
            end            
            %Get Subject Info
            ex(1,2:length(this.infoHeaders)+1) = this.infoHeaders;
            ex(2:size(this.subjectInfo,1)+1,2:length(this.infoHeaders)+1) = this.subjectInfo;
            %Save to file
            exportExcel(file,ex,'','','Subjectinfo','');
        end
        
        function out = getColReference(this,n)
            %return reference of a conditional column
            if(~isempty(this.infoHeaders) && length(this.subjectInfoCombi) >= n)
                out = this.subjectInfoCombi{n};
            else
                out = [];
            end
        end
        
        function out = getColConditions(this,column)
            %return names of all conditions which use column as a reference
            if(~isempty(this.infoHeaders))
                out = cell(0,0);
                n = this.infoHeaderName2idx(column);
                for i=1:length(this.infoHeaders)
                    ref = this.getColReference(i);
                    if(isempty(ref))
                        continue
                    end
                    a = this.infoHeaderName2idx(ref.colA);
                    if(strcmp(ref.logOp,'-'))
                        %second reference is inactive
                        b = 0;
                    else
                        b = this.infoHeaderName2idx(ref.colB);
                    end
                    if((a == n) || (b == n))
                        %column n is a reference column
                        out(end+1) = this.infoHeaders(i);
                    end
                end
            end
        end
        
        function out = getAllSubjectsStr(this)
            %get all subjects of this study as cell array of string
            out = this.subjects;
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
        
        function out = getStudyClusters(this)
            %
            out = this.studyClusters;
        end
        
        function out = getStudyClustersStr(this,mode)
            %get string of study clusters
            %mode 0 - get all subject clusters
            %mode 1 - get only calculable clusters
            out = cell(0,0);
            if(isempty(this.studyClusters))
                return
            end            
            clusterStr = this.studyClusters(1,:);
            clusterTargets = this.studyClusters(2,:);
            if(mode == 0)
                out = clusterStr;
                return
            end            
            %get only computable clusters
            for i=1:length(clusterStr)
                if(isempty(clusterTargets{i}.x) || isempty(clusterTargets{i}.y))
                    continue
                end
                out(end+1,1) = clusterStr(i);
            end
        end
        
        function out = getClusterTargets(this,clusterID)
            %get multivariate targets of a cluster
            clusterNr = this.clusterName2idx(clusterID);
            if(isempty(clusterNr))
                out = [];
                return
            end
            targets = this.studyClusters{2,clusterNr};
            if(isempty(targets))
                %no targets
                out = cell(0,0);
            else
                out = targets;
            end
        end
        
        function out = getSubjectInfoHeaders(this)
            %
            out = this.infoHeaders;
        end
        
%         function out = getSubjectFilesHeaders(this)
%             %
%             out = {'Subject','Channels'};
%         end
        
        function out = getSubjectInfo(this,j)
            %
            if(isempty(j))
                out = this.subjectInfo;
            else
                if(~isempty(this.subjectInfo))
                    out = this.subjectInfo(j,:);
                end
            end
        end
        
        function out = getSubjectInfoCombi(this)
            %
            out = this.subjectInfoCombi;
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
                if(~isempty(ROIType) && isscalar(ROIType) && ROIType <= size(out,1) && ROIType >= 1)
                    out = squeeze(out(ROIType,:,:))';
                    out = out(1:2,2:end);
                    if(ROIType < 6)
                        out = out(1:2,1:2);
                    elseif(ROIType >= 6 && ROIType <= 7)
                        %remove potential trailing zeros
                        idx = any(out,1);
                        idx(1:3) = true;
                        out(:,find(idx,1,'last')+1:end) = [];
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
                
        function out = getResultCuts(this,subName)
            %
            if(isempty(subName))
                out = this.resultCuts;
            else
                if(~isnumeric(subName))
                    subName = this.subName2idx(subName);
                    if(isempty(subName))
                        out = [];
                        return
                    end
                end
                out = cell2mat(this.resultCuts(subName));
            end
        end        
        
%         function data = getSubjectFromClipboard(this,subName)
%             %
%             idx = this.subName2idx(subName);
%             data.resultFileChs = this.resultFileChs(idx,:);
%             data.measurementFileChs = this.measurementFileChs(idx,:);
%             data.resultROI = this.resultROI(idx);
%             data.resultCuts = this.resultCuts(idx);
%             data.subjectInfo = this.subjectInfo(idx,:);
%             data.infoHeaders = this.infoHeaders;
%             data.allFLIMItems = this.allFLIMItems(idx,:);
%         end
        
        function data = getSubjectFilesData(this)
            %merge subjects and subjectFilesData
            if(isempty(this.subjects))
                data = [];
                return
            end
            data = cell(this.nrSubjects,3);
            data(:,1) = this.subjects;            
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
        
        function out = getDataFromStudyInfo(this,descriptor)
            %get data from study info defined by descriptor
            try
                out = this.(sprintf('%s',descriptor));
            catch
                out = [];
            end
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
        
        function [aiNames, aiParams] = getArithmeticImageInfo(this)
            %
            if(isempty(this.arithmeticImageInfo))
                aiNames = {[]}; aiParams = {[]};
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
        
        function out = getAllViewColors(this)
            %
            out = this.viewColors;
        end
        
        function out = getViewColor(this,vName)
            %returns study view color
            idx = find(strcmp(vName,this.viewColors(1,:)), 1);
            if(isempty(idx)) %we don't know that view
                out = studyIS.makeRndColor();
            else
                out = this.viewColors{2,idx};
            end
        end
        
        function views = getViewsStr(this)
            %get conditional columns as views of study
            views = cell(0,0);
            ref = this.getSubjectInfoCombi();
            idx = ~(cellfun('isempty',ref));
            views(end+1) = {'-'};   %define default 'no view'
            if(~isempty(this.infoHeaders(idx)))
                views(end+1:end+(sum(idx))) = this.infoHeaders(idx);
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
            if(length(this.subjects)>1)
                %remove arbitrary subject
                idx = this.subName2idx(subName);
                this.resultFileChs(idx,:) = [];
                this.measurementFileChs(idx,:) = [];
                this.resultROICoordinates(idx) = [];
                this.resultZScaling(idx) = [];
                this.resultCuts(idx) = [];
                this.subjects(idx) = [];
                this.subjectInfo(idx,:) = [];
                this.allFLIMItems(idx,:) = [];
            else
                %remove last subject
                this.resultFileChs = cell(0,0);
                this.measurementFileChs = cell(0,0);
                this.resultROICoordinates = cell(0,0);
                this.resultZScaling = cell(0,0);
                this.resultCuts = cell(0,0);
                this.subjects = cell(0,0);
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
                this.resultCuts(idx) = cell(1,1);
                this.allFLIMItems(idx) = cell(1,1);
                this.setDirty(true);
            end            
        end
        
        function removeColumn(this,colName)
            %delete column in table study data
            col = this.infoHeaderName2idx(colName);
            if(isempty(this.subjectInfo))
                %special case: first header has to be deleted when
                %importing study
                this.infoHeaders(col) = [];
            else
                this.infoHeaders(col) = [];
                this.subjectInfo(:,col) = [];
                this.subjectInfoCombi(col) = [];
                idx = find(strcmp(colName,this.viewColors(1,:)), 1);
                if(~isempty(idx))
                    this.viewColors(:,idx) = [];
                end
            end
            this.setDirty(true);
        end
        
        function removeCluster(this,clusterID)
            %
            clusterNr = this.clusterName2idx(clusterID);
            this.studyClusters(:,clusterNr) = [];
            this.setDirty(true);
        end
        
        %% computation and other methods
        function swapColumn(this,col,n)
            %swap column with its nth neighbor
            if(((n + col) < 1) || ((n + col) > length(this.infoHeaders)))
                %out of index
                return
            end
            %swap InfoHeaders
            temp = this.infoHeaders(col);
            this.infoHeaders(col) = this.infoHeaders(col+n);
            this.infoHeaders(col+n) = temp;
            %swap Data
            temp = this.subjectInfo(:,col);
            this.subjectInfo(:,col) = this.subjectInfo(:,col+n);
            this.subjectInfo(:,col+n) = temp;
            temp = this.subjectInfoCombi(col);
            this.subjectInfoCombi(col) = this.subjectInfoCombi(col+n);
            this.subjectInfoCombi(col+n) = temp;
            this.setDirty(true);
        end
        
        function checkConditionRef(this,colN)
            %update combinations columns
            if(isempty(this.subjectInfo) || all(all(cellfun('isempty',this.subjectInfo))))
                return
            end
            if(isempty(colN))
                %check all columns
                for i=1:length(this.infoHeaders)
                    this.checkConditionRef(i);
                end
            else
                ref = this.getColReference(colN);
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
                a = this.infoHeaderName2idx(ref.colA);
                if((a > colN) && (~isempty(this.getColReference(a))))
                    %reference is a non-updated condition column
                    this.checkConditionRef(a);
                end                
                colA = this.subjectInfo(:,a);                
                for j=1:size(colA,1)
                    if(isempty(colA{j,1}) || all(isnan(colA{j,1})))
                        if(isempty(this.getColReference(a)))
                            %non logical reference
                            colA(j,1) = {0};
                        else
                            %logical reference
                            colA(j,1) = {false};
                        end
                    end
                end                
                colA = cell2mat(colA);
                if(~(isa(colA,'double') || isa(colA,'logical')))
                    %try to convert to double
                    colA = str2num(colA);
                end
                eval(sprintf('colA = colA %s %f;',ref.relA,ref.valA));                
                %conditional column with 2 reference columns
                if(~isempty(op))
                    %create condition result for reference coulmn B
                    switch ref.relB
                        case '!='
                            ref.relB = '~=';
                    end
                    b = this.infoHeaderName2idx(ref.colB);
                    if((b > colN) && (~isempty(this.getColReference(b))))
                        %reference is a non-updated condition column
                        this.checkConditionRef(b);
                    end
                    colB = this.subjectInfo(:,b);
                    
                    for j=1:size(colB,1)
                        if(isempty(colB{j,1}) || isnan(colB{j,1}))
                            if(isempty(this.getColReference(b)))
                                %non-logical reference
                                colB(j,1) = {0};
                            else
                                %logical reference
                                colB(j,1) = {false};
                            end
                        end
                    end
                    colB = cell2mat(colB);
                    if(~(isa(colB,'double') || isa(colB,'logical')))
                        %try to convert to double
                        colA = str2num(colB);
                    end
                    eval(sprintf('colB = colB %s %f;',ref.relB,ref.valB));
                    eval(sprintf('colA = %s(colA %s colB);',neg,op));
                end
                %update values in conditional column
                this.subjectInfo(:,colN) = num2cell(colA);
            end
        end
        
        function idx = subName2idx(this,subName)
            %get the index of a subject or check if index is valid
            idx = [];
            if(ischar(subName))
                idx = find(strcmp(subName,this.subjects),1);
            elseif(isnumeric(subName))
                if(subName <= this.nrSubjects)
                    idx = subName;
                end
            end
        end
        
        function idx = clusterName2idx(this,clusterName)
            %get the index of a cluster or check if index is valid
            idx = [];
            if(isempty(this.studyClusters))
                return
            end
            if(ischar(clusterName))
                idx = find(strcmp(clusterName,this.studyClusters(1,:)),1);
            elseif(isnumeric(clusterName))
                if(clusterName <= length(this.studyClusters(1,:)))
                    idx = clusterName;
                end
            end
        end
        
        function idx = infoHeaderName2idx(this,iHName)
            %get the index of a infoHeader field or check if index is valid
            idx = [];
            if(ischar(iHName))
                idx = find(strcmp(iHName,this.infoHeaders),1);
            elseif(isnumeric(iHName))
                if(iHName <= length(this.infoHeaders))
                    idx = iHName;
                end
            end
        end
        
        function name = idx2SubName(this,id)
            %get the index of a subject or check if index is valid
            name = '';
            if(ischar(id))
                idx = find(strcmp(id,this.subjects),1);
                if(~isempty(idx))
                    %valid subject name
                    name = id;
                end
            elseif(isnumeric(id))
                if(id <= this.nrSubjects)
                    name = this.subjects{id};
                end
            end
        end
        
        function out = sortSubjects(this,varargin)
            %sort subjects and connected fields
            if(isempty(this.subjects))
                out = [];
                return
            end
            
            if(isempty(varargin))
                %sort subjects of current study
                [this.subjects, idx] = sort(this.subjects);
                this.resultFileChs = this.resultFileChs(idx,:);
                this.measurementFileChs = this.measurementFileChs(idx,:);
                this.subjectInfo = this.subjectInfo(idx,:);
                this.resultROICoordinates = this.resultROICoordinates(idx);
                this.resultZScaling = this.resultZScaling(idx);
                this.resultCuts = this.resultCuts(idx);
                this.allFLIMItems = this.allFLIMItems(idx,:);
                this.setDirty(true);
            else
                %sort subjects of imported study
                oldStudy = varargin{1};
                [oldStudy.subjects, idx] = sort(oldStudy.subjects);
                oldStudy.resultFileChs = oldStudy.resultFileChs(idx,:);
                oldStudy.measurementFileChs = oldStudy.measurementFileChs(idx,:);
                oldStudy.subjectInfo = oldStudy.subjectInfo(idx,:);
                oldStudy.resultROICoordinates = oldStudy.resultROICoordinates(idx);
                oldStudy.resultZScaling = oldStudy.resultZScaling(idx);
                oldStudy.resultCuts = oldStudy.resultCuts(idx);
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
                if(isfield(oldStudy,'color'));
                    old = oldStudy.color;
                    oldStudy = rmfield(oldStudy,'color');
                else
                    tmp = jet(256);
                    old = tmp(round(rand*255+1),:);
                end
                %save color not per study but per view now
                oldStudy.viewColors = cell(2,1);
                oldStudy.viewColors(1,1) = {'-'};
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
            nr = length(this.subjects);
        end
        
    end %methods
    
    methods(Static)
        function [testStudy,dirty] = checkStudyConsistency(testStudy)
            %make sure study is not corrput
            dirty = false;
            if(isstruct(testStudy) && ~isfield(testStudy,'IRFInfo'))
                testStudy.IRFInfo = [];
            end
            nrSubjects = length(testStudy.subjects);
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
            %infoHeaders
            if(size(testStudy.infoHeaders,2) > 1)
                testStudy.infoHeaders = testStudy.infoHeaders(:);
                dirty = true;
            end
            tmpLen = length(testStudy.infoHeaders);
            if(tmpLen < nrInfoCols)
                testStudy.infoHeaders(end+1:end+nrInfoCols-tmpLen) = cell(nrInfoCols-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrInfoCols)
                testStudy.infoHeaders = testStudy.infoHeaders(1:nrInfoCols);
                dirty = true;
            end
            %subjectInfoCombi
            if(size(testStudy.subjectInfoCombi,2) > 1)
                testStudy.subjectInfoCombi = testStudy.subjectInfoCombi(:);
                dirty = true;
            end
            tmpLen = length(testStudy.subjectInfoCombi);
            if(tmpLen < nrInfoCols)
                testStudy.subjectInfoCombi(end+1:end+nrInfoCols-tmpLen) = cell(nrInfoCols-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrInfoCols)
                testStudy.subjectInfoCombi = testStudy.subjectInfoCombi(1:nrInfoCols);
                dirty = true;
            end
            %check subject info data types, logical is allowed only for conditional columns
            viewCol = cellfun('isempty',testStudy.subjectInfoCombi);
            for i = 1:length(viewCol)
                if(viewCol(i)) %normal column
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
                    elseif(all(cellclass) && ~cTypeDouble)
                        %check if we can convert all chars to double
                        %testDouble = zeros(size(cellclass));
                        cellempty = cellfun('isempty',testStudy.subjectInfo(:,i));
                        testStr = [testStudy.subjectInfo{:,i}];
                        testStr(isstrprop(testStr,'punct')) = '.';
                        testStr(isstrprop(testStr,'wspace')) = '0';
                        testDouble = zeros(size(cellclass));
                        converted = str2num(testStr);
                        if(length(converted) == sum(~cellempty))
                            testDouble(~cellempty) = converted;
                            if(any(testDouble) && all(~isnan(testDouble)) && length(testDouble) == length(cellclass))
                                testStudy.subjectInfo(:,i) = num2cell(testDouble);
                                dirty = true;
                            end
                        end
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
            %check content of infoHeaders
            if(isempty(testStudy.infoHeaders))
                %no element --> add first info header
                testStudy.infoHeaders(1,1) = {'column 1'};
                testStudy.subjectInfoCombi(1,1) = {[]};
                dirty = true;
            else
                %column header exist -> check names
                for i = 1:length(testStudy.infoHeaders)
                    if(isempty(testStudy.infoHeaders{i}))
                        %there is no validate name
                        colname = sprintf('column %d',i);
                        testStudy.infoHeaders(i)= {colname};
                        dirty = true;
                    end
                    %check if we have a corresponding field in subjectInfoCombi
                    if(length(testStudy.subjectInfoCombi) < i)
                        testStudy.subjectInfoCombi(i) = cell(1,1);
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
            %resultCuts
            if(size(testStudy.resultCuts,2) > 1)
                testStudy.resultCuts = testStudy.resultCuts(:);
                dirty = true;
            end
            tmpLen = length(testStudy.resultCuts);
            if(tmpLen < nrSubjects)
                testStudy.resultCuts(end+1:end+nrSubjects-tmpLen) = cell(nrSubjects-tmpLen,1);
                dirty = true;
            elseif(tmpLen > nrSubjects)
                testStudy.resultCuts = testStudy.resultCuts(1:nrSubjects);
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
            %view colors
            if(isempty(testStudy.viewColors))
                %set color for "default" view
                testStudy.viewColors(1,1) = {'-'};
                testStudy.viewColors(2,1) = {studyIS.makeRndColor()};
                dirty = true;
            end
            newColors = setdiff(testStudy.infoHeaders(~viewCol),testStudy.viewColors(1,:));
            for i = 1:length(newColors)
                testStudy.viewColors(1,end+1) = newColors(i);
                testStudy.viewColors(2,end) = {studyIS.makeRndColor()};
            end
            delColors = setdiff(testStudy.viewColors(1,:),testStudy.infoHeaders(~viewCol));
            delColors = delColors(~strcmp(delColors,'-'));
            for i = 1:length(delColors)
                idx = find(strcmp(delColors{i},testStudy.viewColors(1,:)), 1);
                if(isempty(idx))
                    testStudy.viewColors(:,idx) = [];
                end
            end
            if(~isempty(newColors) || ~isempty(delColors))
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
        
        function [op, neg] = str2logicOp(str)
            %convert a (descriptive) string to a logical operand
            neg = '';
            switch str
                case '-' %no combination
                    op = '';
                case 'AND'
                    op = '&';
                case 'OR'
                    op = '|';
                case '!AND'
                    op = '&';
                    neg = '~';
                case '!OR'
                    op = '|';
                    neg = '~';
                case 'XOR'
                    op = 'xor';
                    neg = '';
                otherwise
                    op = str;
            end
        end
        
        function out = makeRndColor()
            %generate random RGB color from jet colormap
            tmp = jet(256);
            out = tmp(round(rand*255+1),:);
        end
    end
    
end