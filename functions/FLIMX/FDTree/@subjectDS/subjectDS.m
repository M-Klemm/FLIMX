classdef subjectDS < handle
    %=============================================================================================================
    %
    % @file     subjectDS.m
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
    % @brief    A class to represent list of channels.
    %
    properties(SetAccess = protected, GetAccess = public)
        name = [];
        width = [];
        height = [];
        myParent = [];
        myChannels = [];
        myFileInfo = cell(0,0);
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];        
    end
    
    methods
        function this = subjectDS(parent,name)
            % Constructor for DS.
            this.myParent = parent;
            this.name = name;
            this.myChannels = LinkedList();
        end
        
        function addObj(this,chan,dType,gScale,data)
            %
            if(isempty(dType))
                %add only empty channel
                this.myChannels.insertID(Channel(this),chan);
                return
            end
            
            %save size of data for whole subject if it is globally scaled
            if(gScale && isempty(this.width))
                [this.height, this.width] = size(data);
            end
            
            if(gScale)
                %check if size of current data matches subject size
                [y, x] = size(data);
                if(this.height ~= y || this.width ~= x)
                    error('FDTree:DS:size','Size of current data matrix (%dx%d) does not match subject size (%dx%d)!',x,y,this.width,this.height);
                end
            end
            %insert data in specific channel with scaling sType
            chObj = this.myChannels.getDataByID(chan);
            if(isempty(chObj))
                this.myChannels.insertID(Channel(this),chan,true);
                chObj = this.myChannels.getDataByID(chan);
            end
            chObj.addObj(dType,gScale,data);
        end
        
        function addObjID(this,nr,chan,dType,gScale,data)
            %
            %save size of data for whole subject if it is globally scaled
            if(gScale && isempty(this.width))
                [this.height, this.width] = size(data);
            end
            
            if(gScale)
                %check if size of current data matches subject size
                [y, x, z] = size(data);
                if(this.height ~= y || this.width ~= x || z ~= 1)
                    %todo: remove this error message here
                    error('FDTree:DS:size','Size of current data matrix (%dx%d) does not match subject size (%dx%d)!',x,y,this.width,this.height);
                end
            end
            %insert data in specific channel
            chObj = this.myChannels.getDataByID(chan);
            if(isempty(chObj))
                this.myChannels.insertID(Channel(this),chan);
                chObj = this.myChannels.getDataByID(chan);
            end
            chObj.addObjID(nr,dType,gScale,data);
        end
        
        function addObjMergeID(this,nr,chan,dType,gScale,data)
            %add merged FData object
            
            %insert data in specific channel
            chObj = this.myChannels.getDataByID(chan);
            if(isempty(chObj))
                this.myChannels.insertID(Channel(this),chan);
                chObj = this.myChannels.getDataByID(chan);
            end
            chObj.addObjMergeID(nr,dType,gScale,data);
        end
        
        function addClusterID(this,chan,id,data)
            % add cluster object to channel
            chObj = this.myChannels.getDataByID(chan);
            if(isempty(chObj))
                %should not be empty --> return?
                this.myChannels.insertID(Channel(this),chan);
                chObj = this.myChannels.getDataByID(chan);
            end
            chObj.addCluster(id,data);
        end
        
        function removeObj(this,ch,dType,id)
            %remove object from channel ch
            chObj = this.myChannels.getDataByID(ch);
            if(isempty(chObj))
                return
            end
            chObj.removeObj(dType,id);
            %             if(chObj.getNrElements == 0)
            %                 %nothing in there anymore -> remove it from channel
            %                 this.myChannels.removeID(ch);
            %             end
        end
        
        function removeChannel(this,ch)
            %remove channel of a subject
            if(isempty(ch))
                %remove all channels
                while(this.myChannels.queueLen > 0)
                    this.myChannels.removePos(this.myChannels.queueLen);
                end
            else
                %remove specific channel
                this.myChannels.removeID(ch);
            end
            if(this.myChannels.queueLen == 0)
                %reset size of image data
                this.width = [];
                this.height = [];
            end
        end
        
        function updateShortProgress(this,prog,text)
            %update the progress bar of a short operation
            this.myParent.updateShortProgress(prog,text);
        end
        
        function updateLongProgress(this,prog,text)
            %update the progress bar of a long operation consisting of short ops
            this.myParent.updateLongProgress(prog,text);
        end
        
        %% input functions
        function loadChannel(this,chan)
            %load channel (measurement and results)
            [measurements, results] = this.myParent.getSubjectFilesStatus(this.name);
            if(any(results == chan))
                %we have a result, load it
                this.loadChannelResult(chan);
            elseif(any(measurements == chan))
                %we don't have approximation results, try to load measurement
                this.loadChannelMeasurement(chan,false);
            end
        end
        
        function loadChannelMeasurement(this,chan,forceFlag)
            %load measurement data in channel chan
            hfd = this.getFDataObj(chan,'Intensity',0,1); %check only linear data
            if(isempty(hfd) || forceFlag)
                this.updateShortProgress(1,sprintf('Importing (Ch %s)',num2str(chan)));
                mo = this.myParent.getSubject4Approx(this.name);
                if(~isempty(mo))                    
                    int = mo.getROIDataFlat(chan,true);
                    if(~isempty(int) && (isempty(this.height) || isempty(this.width)) || ~isempty(int) && (size(int,1) == this.height && size(int,2) == this.width))
                        this.addObjID(0,chan,'Intensity',1,int);
                    else
                        %try raw data
                        int = mo.getRawDataFlat(chan);
                        if(~isempty(int) && ~isempty(this.height) && ~isempty(this.width) && size(int,1) == this.height && size(int,2) == this.width)
                            this.addObjID(0,chan,'Intensity',1,int);
                        else
                            %we could not get a intensity image
                            %todo: throw warning / error message
                            this.updateShortProgress(0,'');
                            return
                        end
                    end
                    allItems = this.myParent.getAllFLIMItems(this.name,chan);
                    if(isempty(allItems))
                        this.myParent.setAllFLIMItems(this.name,chan,{'Intensity'});
                    end
                    this.myFileInfo{chan,1} = mo.getFileInfoStruct(chan);                    
                end
                this.updateShortProgress(0,'');
            end
        end
        
        function loadChannelResult(this,chan)
            %load results in channel chan            
            if(~this.channelResultIsLoaded(chan))
                %try to load channel
                this.updateShortProgress(0.5,sprintf('Importing (Ch %s)',num2str(chan)));
                [resultObj, isASCIIResult] = this.myParent.getResultObj(this.name,chan); %todo: replace with subject object
                %check items (e.g. amps, taus) which are going to be loaded
                allItems = this.myParent.getAllFLIMItems(this.name,chan);
                if(isempty(allItems) && ~isempty(resultObj))
                    %check items (e.g. amps, taus) which are going to be loaded
                    %try to get the result items again
                    allItems = removeNonVisItems(resultObj.getResultNames(chan,false),3);
                    if(~isempty(allItems))
                        this.myParent.setAllFLIMItems(this.name,chan,allItems);
                    end
                elseif(isempty(allItems) && isempty(resultObj))
                    %this might be a measurement without result
                    this.updateShortProgress(0,sprintf('Importing (Ch %s)',num2str(chan)));
                    return
                elseif(~isempty(allItems) && isempty(resultObj))
                    this.updateShortProgress(0,sprintf('Importing (Ch %s)',num2str(chan)));
                    %there is nothing we can do
                    return
                end
                this.myFileInfo{chan,1} = resultObj.getFileInfoStruct(chan);
                newItems = removeNonVisItems(allItems,this.FLIMXParamMgrObj.generalParams.flimParameterView);
                cutVec = this.myParent.getResultCuts(this.name);
                %we may update an exiting subject -> remove unwanted items
                chObj = this.myChannels.getDataByID(chan);
                if(~isempty(chObj))
                    loadedItems = chObj.getChObjStr();
                else
                    loadedItems = [];
                end
                if(~isempty(loadedItems))
                    %find items to be removed
                    itemsDelete = setdiff(loadedItems,newItems);
                    for i = 1:length(itemsDelete)
                        %strip of tailing numbers
                        dType = itemsDelete{i};
                        dTypeNr = str2double(dType(isstrprop(dType, 'digit')));
                        if(isnan(dTypeNr))
                            dTypeNr = 1;
                        end
                        dType = dType(isstrprop(dType, 'alpha'));
                        this.removeObj(chan,dType,dTypeNr);
                        switch lower(dType)
                            case 'amplitude'
                                this.removeObj(chan,'AmplitudePercent',dTypeNr);
                                this.removeObj(chan,'Q',dTypeNr);
                            case 'tau'
                                this.removeObj(chan,'Q',dTypeNr);
                        end
                    end
                end
                %add newItems
                nr_e = numel(newItems);
                for i=1:nr_e
                    dType = newItems{i};
                    %strip of tailing numbers
                    dTypeNr = str2double(dType(isstrprop(dType, 'digit')));
                    if(isnan(dTypeNr))
                        dTypeNr = 1;
                    end
                    dType = dType(isstrprop(dType, 'alpha'));
                    data_temp = resultObj.getPixelFLIMItem(chan,newItems{i});
                    if(isempty(data_temp))
                        continue
                    end
                    if(isASCIIResult && strncmpi('Amplitude',dType,9) && length(dType) <= 11)
                        %scale amplitudes with IRF integral
                        %data_temp = data_temp .* this.myParent.myStudyInfoSet.getIRFInfo(chan);
                        data_temp = data_temp .* 10000;
                    end
                    try
                        this.addObjID(dTypeNr,chan,dType,1,data_temp);
                    catch ME
                        msg = regexp(ME.identifier,':','split');
                        uiwait(warndlg(sprintf('An Error occured in %s\n\n''%s''\n\nImporting channel %d of subject ''%s'' has been aborted!',ME.identifier,ME.message,chan,this.name),'Error importing Data','modal'));
                        if(strcmp(msg(end),'size'))
                            %abort, make sure nothing of this channel is left
                            this.removeChannel(chan);
                            return
                        end
                    end
                end
                this.updateShortProgress(1,sprintf('Importing (Ch %s)',num2str(chan))); %0.5
                %intensity image
                hfd = this.getFDataObj(chan,'Intensity',0,1); %check only linear data
                if(isempty(hfd))
                    if(isASCIIResult)
                        %we got a converted ascii file
                        %try to get the intensity image from a measurement file
                        this.loadChannelMeasurement(chan,false);
                        hfd = this.getFDataObj(chan,'Intensity',0,1);
                        if(isempty(hfd))
                            ampItems = allItems(cellfun(@length,allItems)==10);
                            ampItems = ampItems(strncmp('Amplitude',ampItems,9));
                            if(~isempty(ampItems))
                                int = resultObj.getPixelFLIMItem(chan,ampItems{1});
                                for i=2:length(ampItems)
                                    %no checking if dimensions agree - todo?!
                                    int = int + resultObj.getPixelFLIMItem(chan,ampItems{i});
                                end
                                if(isASCIIResult)
                                    int = int.*10000;
                                end
                                this.addObjID(0,chan,'Intensity',1,int);
                            end
                        end
                    else
                        this.addObjID(0,chan,'Intensity',1,resultObj.getPixelFLIMItem(chan,'Intensity'));
                    end
                end
                %make arithmetic images
                this.myParent.clearArithmeticRIs();
                if(~isempty(cutVec) && length(cutVec) == 6)
                    %set cuts for new items
                    this.setCutVec('X',cutVec(1:3));
                    this.setCutVec('Y',cutVec(4:6));
                end
                %this.updateShortProgress(1,sprintf('Finished. (Ch %s)',num2str(chan)));
                this.updateShortProgress(0,'');
            end            
        end
        
        function setSubjectName(this,val)
            %set subject name
            this.name = val;
        end
        
        function setdType(this,dType,val)
            %set new dType (new chunk name)
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).setdType(dType,val);
            end
        end
        
        function setResultROICoordinates(this,dType,ROIType,ROICoord)
            %set the ROI vector for dimension dim
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).setResultROICoordinates(dType,ROIType,ROICoord);
            end
        end
        
        function setCutVec(this,dim,cutVec)
            %set the cut vector for dimension dim
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).setCutVec(dim,cutVec);
            end
        end
        
        function clearAllCIs(this,dType)
            %clear current immages of datatype dType in all subjects
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).clearAllCIs(dType);
            end
        end
        
        function clearAllFIs(this,dType)
            %clear filtered raw immages of datatype dType in all subjects
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).clearAllFIs(dType);
            end
        end
        
        function clearAllRIs(this,dType)
            %clear raw images of datatype dType in all subjects
            for i = 1:this.myChannels.queueLen
                this.myChannels.getDataByPos(i).clearAllRIs(dType);
            end
        end
        %% output functions
        function h = getFDataObj(this,ch,dType,id,sType)
            %get FData object
            h = [];
            if(isempty(ch))
                chObj = this.myChannels.getDataByPos(1);
            else
                chObj = this.myChannels.getDataByID(ch);
            end
            if(isempty(chObj) && ~isempty(ch))
                if(strncmp(dType,'MVGroup',7) || strncmp(dType,'ConditionMVGroup',16)...
                        || strncmp(dType,'GlobalMVGroup',13))
                    this.myChannels.insertID(Channel(this),ch);
                    chObj = this.myChannels.getDataByID(ch);
                else                    
                    return
                end
            elseif(isempty(chObj) && isempty(ch))
                return
            end
            h = chObj.getFDataObj(dType,id,sType);
        end
        
        function nr = getNrChannels(this)
            %get number of channels in subject
            nr = this.myChannels.queueLen;
        end
        
        function out = getSubjectName(this)
            %get subject name
            out = this.name;
        end
        
        function out = getClusterTargets(this,clusterNr)
            %get multivariate targets
            gMVs = this.myParent.getClusterTargets(clusterNr);
            chObj = this.myChannels.getDataByPos(1);
            if(~isempty(chObj))
                myObjs = chObj.getChObjStr();
            else
                myObjs = '';
            end
            out.x = cell(0,0);
            out.y = cell(0,0);
            if(~isstruct(gMVs) || isstruct(gMVs) && ~all(isfield(gMVs,{'x','y','ROI'})));
                %we did not get cluster targets
                warning('subjectDS:getClusterTargets','Could not get cluster targets for subject ''%s'' in study ''%s''',this.name,this.myParent.name);
                return
            end
            out.ROI = gMVs.ROI;
            for i = 1:length(gMVs.x)
                idx = strcmpi(gMVs.x{i}, myObjs);
                if(any(idx))
                    out.x(end+1) = gMVs.x(i);
                end
            end
            for i = 1:length(gMVs.y)
                idx = strcmpi(gMVs.y{i}, myObjs);
                if(any(idx))
                    out.y(end+1) = gMVs.y(i);
                end
            end
        end
        
        function nr = getMyChannelNr(this,caller)
            %return the current channel number
            for i = 1:this.myChannels.queueLen
                [chObj,nr] = this.myChannels.getDataByPos(i);
                if(~isempty(chObj) && chObj == caller)
                    return
                end
            end
            nr = [];
        end
        
%         function [str, nrs] = getChStr(this)
%             %get a string of all channels in subject
%             str = cell(0,0);
%             nrs = [];
%             for i = 1:this.myChannels.queueLen
%                 [chObj, nr] = this.myChannels.getDataByPos(i);
%                 if(~isempty(chObj))
%                     str(i,1) = {sprintf('Ch %d',nr)};
%                     nrs = [nrs nr];
%                 end
%             end
%         end
        
        function str = getChObjStr(this,ch)
            %get a string of all objects in channel ch in subject
            if(~this.channelResultIsLoaded(ch))
                this.channelResultIsLoaded(ch);
            end
            chObj = this.myChannels.getDataByID(ch);
            if(isempty(chObj))
                str = '';
                return
            else
                str = chObj.getChObjStr();
            end
        end
        
        function str = getChClusterObjStr(this,ch)
            %get a string of all cluster objects in a channel
            chObj = this.myChannels.getDataByID(ch);
            if(isempty(chObj))
                str = '';
                return
            else
                str = chObj.getChClusterObjStr();
            end
        end
        
        function out = getCutX(this)
            %get current cut position of x axis in subject
            out = this.cut_x;
        end
        
        function out = getCutXInv(this)
            %get current inv flag for cut of x axis in subject
            out = this.cut_x_inv;
        end
        
        function out = getCutY(this)
            %get current cut position of y axis in subject
            out = this.cut_y;
        end
        
        function out = getCutYInv(this)
            %get current inv flag for cut of y axis in subject
            out = this.cut_y_inv;
        end
        
        function out = getHeight(this)
            %get height of subject
            out = this.height;
        end
        
        function out = getWidth(this)
            %get width of subject
            out = this.width;
        end
        
        function out = getFileInfoStruct(this,ch)
            %get fileinfo struct
            out = [];
            if(~isempty(ch) && length(this.myFileInfo) >= ch && ch > 0)
                out = this.myFileInfo{ch,1};
            end
        end
        
        function out = getSaveMaxMemFlag(this)
            %get saveMaxMem flag from parent
            out = this.myParent.getSaveMaxMemFlag();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            out = this.myParent.getResultROICoordinates(this.name,ROIType);
        end
        
        function out = getZScaling(this,dType,dTypeNr)
            %get z scaling
            out = this.myParent.getResultZScaling(this.name,dType,dTypeNr);
        end
        
        function out = channelMesurementIsLoaded(this,chan)
            %
            hfd = this.getFDataObj(chan,'Intensity',0,1); %check only linear data
            if(isempty(hfd))
                out = false;
            else
                out = true;
            end
        end
        
        function out = channelResultIsLoaded(this,chan)
            %return true if subject was loaded from disk
            chObj = this.myChannels.getDataByID(chan);
            if(~isempty(chObj))
                out = chObj.channelResultIsLoaded();
            else
                out = false;
            end
        end
        
        function out = isMember(this,ch,dType)
            %function checks combination of channel and datatype
            chObj = this.myChannels.getDataByID(ch);
            if(isempty(chObj))
                out = false;
            else
                out = chObj.isMember(dType);
            end
        end
        
        function out = getGlobalScale(this,dType)
            %return global scale flag for dType
            out = false;
            for ch = 1:this.myChannels.queueLen
                chObj = this.myChannels.getDataByPos(ch);
                if(~chObj.channelResultIsLoaded())
                    this.loadChannelResult(ch);
                end
                if(~isempty(chObj))
                    out = chObj.getGlobalScale(dType);
                    return
                end
            end
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        %% compute functions        
        function makeArithmeticImage(this,aiName,aiParams)
            %compute arithmetic images (all if aiName is empty)
            if(isempty(aiName) || isempty(aiParams))
                return
            end
            [dTypeA, dTypeANr] = FLIMXVisGUI.FLIMItem2TypeAndID(aiParams.FLIMItemA);
            %check for which channels the arithmetic image should be built
            [~, totalCh] = this.myParent.getChStr(this.name);
            if(aiParams.chA == 0 || aiParams.chB == 0)
                nCh = length(totalCh);
            else
                nCh = 1;
            end
            if(aiParams.chA == 0)
                chAList = totalCh;
            else
                chAList = repmat(aiParams.chA,1,nCh);
            end
            if(aiParams.chB == 0)
                chBList = totalCh;
            else
                chBList = repmat(aiParams.chB,1,nCh);
            end
            %loop over channels
            for chIdx = 1:nCh
                %make sure channel was loaded from disk
                this.loadChannelResult(chAList(chIdx));
                %ask study for FData object, if this is an arithmetic image, study will buld it if needed
                fd = this.myParent.getFDataObj(this.name,chAList(chIdx),dTypeA{1},dTypeANr(1),1);
                if(isempty(fd))
                    continue
                end
                dataA = fd.getFullImage();
                if(isempty(dataA))
                    continue
                end
                if(aiParams.normalizeA)
                    dataA = dataA ./ max(dataA(:));
                end
                [op, neg] = studyIS.str2logicOp(aiParams.opA);
                if(strcmp(aiParams.compAgainst,'val'))
                    if(any(strcmp(op,{'&','|','xor'})))
                        eval(sprintf('idx = logical(dataA) %s %slogical(aiParams.valA);',op,neg));
                        data = dataA;
                        data(~idx) = nan;
                    else
                        eval(sprintf('data = dataA %s %f;',aiParams.opA,single(aiParams.valA)));
                    end
                    [op, neg] = studyIS.str2logicOp(aiParams.valCombi);
                    if(~isempty(op))
                        eval(sprintf('data = %s(data %s (dataA %s %f));',neg,op,aiParams.opB,single(aiParams.valB)));
                    end
                else %compare against another FLIMItem
                    [dTypeB, dTypeBNr] = FLIMXVisGUI.FLIMItem2TypeAndID(aiParams.FLIMItemB);
                    %make sure channel was loaded from disk
                    this.loadChannelResult(chBList(chIdx));
                    %ask study for FData object, if this is an arithmetic image, study will buld it if needed
                    fd = this.myParent.getFDataObj(this.name,chBList(chIdx),dTypeB{1},dTypeBNr(1),1);
                    if(isempty(fd))
                        continue
                    end
                    dataB = fd.getFullImage();
                    if(isempty(dataB))
                        continue
                    end
                    if(aiParams.normalizeB)
                        dataB = dataB ./ max(dataB(:));
                    end
                    if(any(strcmp(op,{'&','|','xor'})))
                        idxA = ~isnan(dataA);
                        idxA(idxA) = logical(dataA(idxA));
                        idxB = ~isnan(dataB);
                        idxB(idxB) = logical(dataB(idxB));
                        eval(sprintf('idx = %s(idxA %s idxB);',neg,op));
                        data = dataA;
                        data(~idx) = nan;
                    else
                        eval(sprintf('data = dataA %s dataB;',aiParams.opA));
                    end
                end
                if(isempty(data))
                    return
                end
                %save arithmetic image
                this.addObjID(0,chAList(chIdx),aiName,1,data);
            end
            cutVec = this.myParent.getResultCuts(this.name);
            if(~isempty(cutVec) && length(cutVec) == 6)
                %set cuts for new items
                this.setCutVec('X',cutVec(1:3));
                this.setCutVec('Y',cutVec(4:6));
            end
        end
        
        function [cimg lblx cw lbly] = makeViewCluster(this,chan,clusterID)
            %make view cluster for a spectral channel
            [cimg lblx cw lbly] = this.myParent.makeViewCluster(this.name,chan,clusterID);
        end
        
        function [cimg lblx lbly cw colors logColors] = makeGlobalCluster(this,chan,clusterID)
            %make global cluster for a spectral channel
            [cimg lblx lbly cw colors logColors] = this.myParent.makeGlobalCluster(chan,clusterID);
        end
        
        function flag = eq(ds1,ds2)
            %compare two subjectDS objects
            if(ischar(ds2))
                flag = strcmp(ds1.name,ds2);
            else
                flag = strcmp(ds1.name,ds2.name);
            end
        end
        
    end %methods
end %classdef