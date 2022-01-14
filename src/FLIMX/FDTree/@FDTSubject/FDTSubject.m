classdef FDTSubject < fluoSubject
    %=============================================================================================================
    %
    % @file     FDTSubject.m
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
    % @brief    A class to subject in the FDTree
    %
    properties(SetAccess = protected, GetAccess = public)
        %myDir = '';             %subjects's working directory
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
    end

    methods
        function this = FDTSubject(parent,name)
            % Constructor for FDTSubject
            this = this@fluoSubject(parent,name);
            %this.myDir = sDir;
            this.reset();
        end

%         function updateFileStatus(this)
%             %update file status
%         end

        function reset(this)
            %reset measurement and result objects
            this.removeResultChannelFromMemory([]);
            this.initMode = true;
            if(~isempty(this.myMeasurement) && this.myMeasurement.isvalid)
                this.myMeasurement.delete();
            end
            if(~isempty(this.myResult) && this.myResult.isvalid)
                this.myResult.delete();
            end
            this.myMeasurement = measurement4Approx(this);
            this.myMeasurement.setProgressCallback(@this.updateProgress);
            this.myResult = result4Approx(this);
            this.initMode = false;
            chList = find(any(this.myMeasurement.dirtyFlags,2));
            if(~isempty(chList))
                %something was changed when loading the measurement (e.g. reflection mask was recalculated), save it for later use
                for i = 1:length(chList)
                    this.myMeasurement.saveMatFile2Disk(chList(i));
                end
            end
            this.isInitialized = false;
        end

        %% input methods
        
        
        function importMeasurementObj(this, obj)
            %import a measurement object to FDTree
%             ROIVec = obj.ROICoord; %save old ROIVec if there is one
%             if(~isempty(ROIVec))
%                 obj.setROICoord(ROIVec);
%             end
            if(~obj.fileInfoLoaded)
                obj.getFileInfoStruct([]);
            end
            %guess position of the eye
            %obj.guessEyePosition();
            if(isempty(obj.ROICoord))
                %get full roi
                ROIVec = [1 obj.getRawXSz() 1 obj.getRawYSz()];
                %ROIVec = importWizard.getAutoROI(obj.getRawDataFlat(ch),this.preProcessParams.roiBinning);
                if(ROIVec(1) > 5 || ROIVec(3) > 5 || ROIVec(2) < obj.rawXSz-5 || ROIVec(4) < obj.rawYSz-5)
                    obj.setROICoord(ROIVec);
                end
            end
            %read raw data
            for ch = 1:obj.nrSpectralChannels
                obj.getRawData(ch);
            end
            this.myMeasurement.importMeasurementObj(obj);
            %determine which channels changed
            chList = any(obj.dirtyFlags,2);
            for i = 1:length(chList)
                this.removeResultChannelFromMemory(chList(i));
                %old results are now invalid -> delete them
                this.deleteChannel(chList(i),'result');
            end
            this.myMeasurement.saveMatFile2Disk([]);
%             subjectApp = this.myParent.getSubject4Approx(this.name);
%             subjectApp.reset();
        end

%         function importResultObj(this, obj)
%             %import a result object to FDTree
%
%         end

        function importResultStruct(this,rs,ch,position,scaling)
            %import a result from a result struct
            this.initMode = true;
            this.myResult.importResultStruct(rs,ch,position,scaling);
            this.importResultPostProcess();
        end

        function addFLIMItems(this,ch,itemsStruct)
            %import (additional) FLIM items to this result
            %check size
            [y, x] = structfun(@size,itemsStruct);
            idx = y ~= this.YSz | x ~= this.XSz;
            if(any(idx))
                %remove the field that do not have the correct size
                fn = fieldnames(itemsStruct);
                itemsStruct = rmfield(itemsStruct,fn(idx));
            end
            if(isempty(itemsStruct))
                return
            end
            this.initMode = true;
            fn = fieldnames(itemsStruct);
            sStrLen = cellfun(@length,fn);
            digitIdx = cellfun(@(x) isstrprop(x,'digit'),fn,'UniformOutput',false);
            %scan for amplitudes and taus
            idxAnew = strncmp(fn,'Amplitude',9) & sStrLen >= 10 & sStrLen <= 11;
            idxTnew = strncmp(fn,'Tau',3) & sStrLen >= 4 & sStrLen <= 5;
            if(any(idxAnew))
                for i = find(idxAnew)'
                    idxAnew(i) = all(digitIdx{i}(10:end) == true);
                end
            end
            if(any(idxTnew))
                for i = find(idxTnew)'
                    idxTnew(i) = all(digitIdx{i}(4:end) == true);
                end
            end
            %get tau running numbers
            tNrs = [];
            if(any(idxTnew))
                idxTnew = find(idxTnew);
                tNrs = zeros(length(idxTnew),1);
                for i = 1:length(idxTnew)
                    %find running numbers of new amplitudes
                    tNrs(i) = str2double(fn{idxTnew(i)}(digitIdx{idxTnew(i)}));
                end
                tNrs = unique(tNrs);
            end
            if(any(idxAnew) && ~isempty(tNrs))
                %get amplitude running numbers
                idxAnew = find(idxAnew);
                aNrs = zeros(length(idxAnew),1);
                for i = 1:length(idxAnew)
                    %find running numbers of new amplitudes
                    aNrs(i) = str2double(fn{idxAnew(i)}(digitIdx{idxAnew(i)}));
                end
                aNrs = unique(aNrs);
                uNrs = union(aNrs,tNrs(:)); %running numbers of amplitudes and taus
                nExpNew = this.basicParams.nExp;
                for i = 1:length(uNrs)
                    if(uNrs(i) ~= nExpNew+1)
                        break
                    end
                    nExpNew = nExpNew+1;
                end
                if(nExpNew ~= this.basicParams.nExp)
                    %these amplitudes are not in the current results -> recalculate number of exponentials
                    this.basicParams.nExp = nExpNew;
                end
            end
            this.myResult.addFLIMItems(ch,itemsStruct);
            this.importResultPostProcess();
            %we might overwrite something that is used for an arithmetic image -> clear them
            %(we don't have a method to clear only a specific subject, thus clear the whole study)
            this.myParent.clearArithmeticRIs();
        end

        function importResultPostProcess(this)
            %import a result to FDTree
            this.initMode = true;
            chList = find(this.myResult.dirtyFlags);
            for i = 1:length(chList)
                %save mat files for measurements and results
                %save only result, we can assume we already have the measurement
                this.myResult.saveMatFile2Disk(chList(i)); %force reload of result with new items
                this.removeResultChannelFromMemory(chList(i));
                this.myParent.myStudyInfoSet.setAllFLIMItems(this.name,chList(i),removeNonVisItems(this.getResultNames(chList(i),false),3));
            end
            this.initMode = false;
            %clear merged objects?!
            %subjectApp = this.myParent.getSubject4Approx(this.name);
            %subjectApp.updateSubjectChannel([],'measurement'); %check if measurement is dirty before we reset the object
            %subjectApp.reset();
        end

        function setResultDirty(this,ch,flag)
            %set dirty flag
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.setDirty(ch,flag);
        end

        function setResultType(this,val)
            %set the result type string; only 'FluoDecayFit' (default) and 'ASCII' are valid
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.setResultType(val);
        end

        function setEffectiveTime(this,ch,t)
            %set the effective run time for the approximation of ch
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.setEffectiveTime(ch,t);
        end

        function setPixelFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.setPixelFLIMItem(ch,pStr,val);
        end

        function setInitFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.setInitFLIMItem(ch,pStr,val);
        end

        function addInitResult(this,ch,indices,resultStruct)
            %add single results to our inner results structure
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.addInitResult(ch,indices,resultStruct);
        end

        function addSingleResult(this,ch,row,col,resultStruct)
            %add single results to our inner results structure
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.addSingleResult(ch,row,col,resultStruct);
            if(isempty(this.myResult.getPixelFLIMItem(ch,'Intensity')))
                this.setPixelFLIMItem(ch,'Intensity',this.getROIDataFlat(ch,false));
            end
        end

        function addMultipleResults(this,ch,indices,resultStruct)
            %add mupltiple results according to their indices
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.addMultipleResults(ch,indices,resultStruct);
        end

        function addResultColumn(this,ch,col,resultStruct)
            %add complete results column from a cell array to our inner results structure
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.addResultColumn(ch,col,resultStruct);
        end

        function addResultRow(this,ch,row,resultStruct)
            %add complete results row from a cell array to our inner results structure
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.addResultRow(ch,row,resultStruct);
        end

        function clearROA(this)
            %clears measurement data and results of current region of approximation
            if(~this.isInitialized)
                this.init();
            end
            this.myMeasurement.clearROAData();
            this.clearROAResults(false);
        end

        function clearROAResults(this,saveToDiskFlag)
            %clear the results of current region of approximation
            %this.myMeasurement.clearROAData();
            if(~this.isInitialized)
                this.init();
            end
            roa = this.ROICoordinates;
            this.myResult.deleteChannel([]);
            this.myResult.allocResults(1:this.nrSpectralChannels,roa(4)-roa(3)+1,roa(2)-roa(1)+1);
            if(saveToDiskFlag)
                this.saveMatFile2Disk([]);
            end
        end
        
        function delete(this)
            %remove me from FDTree memory cache
            if(~isempty(this.myMeasurement) && this.myMeasurement.isvalid)
                this.myMeasurement.delete();
            end
            if(~isempty(this.myResult) && this.myResult.isvalid)
                this.myResult.delete();
            end
        end

        %% output
        function out = getApproximationPixelIDs(this,ch)
            %return indices of all pixels in channel ch which have the min. required number of photons
            if(~this.isInitialized)
                this.init();
            end
            out = find(this.getROIDataFlat(ch,false) >= this.basicParams.photonThreshold);
        end

%         function [parameterCell, idx] = getApproxParamCell(this,ch,pixelPool,fitDim,initFit,optimizationParams,aboutInfo)
%             %put all data needed for approximation in a cell array (corresponds to makePixelFit interface)
%             if(~this.isInitialized)
%                 this.init();
%             end
%             if(initFit)
%                 %initialization fit
%                 if(any(pixelPool > this.initFitParams.gridSize^2))
%                     parameterCell = [];
%                     idx = [];
%                     return
%                 end
%                 apObjs = this.getInitApproxObjs(ch);
%                 apObjs = apObjs(pixelPool);
%                 idx = zeros(length(pixelPool),2);
%                 [idx(:,1), idx(:,2)] = ind2sub([this.initFitParams.gridSize this.initFitParams.gridSize],pixelPool);
%                 %nPixel = this.initFitParams.gridSize^2;
%             else
%                 %ROIData = this.FLIMXObj.curSubject.getROIData(ch,[],[],[]);
%                 y = this.getROIYSz();
%                 x = this.getROIXSz();
%                 if(length(pixelPool) < 1) %we are at the end of the file
%                     parameterCell = [];
%                     idx = [];
%                     return
%                 end
%                 nPixel = length(pixelPool);
%                 %% get pixel indices and data
%                 idx = zeros(nPixel,2);
%                 parameterCell = cell(1,3);
%                 apObjs = cell(nPixel,1);
% %                 if(fitDim == 2) %x
% %                     [idx(:,2), idx(:,1)] = ind2sub([x y],pixelPool);
% %                 else %y
%                     [idx(:,1), idx(:,2)] = ind2sub([y x],pixelPool);
% %                 end
%                 for i = 1:nPixel %loop over roi pixel
%                     apObjs{i} = getApproxObj(this,ch,idx(i,1),idx(i,2));
%                 end
%             end
%             %% assemble cell
%             parameterCell(1) = {apObjs};
%             parameterCell(2) = {optimizationParams};
%             parameterCell(3) = {aboutInfo};
%         end

        function makeMeasurementROIData(this,channel,binFactor)
            %force building roi from raw data in measurement
            if(isempty(binFactor))
                binFactor = this.myMeasurement.roiBinning;
            end
            this.myMeasurement.makeROIData(channel,binFactor);
        end




%         function out = getSize(this)
%             %determine memory size of the subject
%             out = 0;
%             for i = 1:this.nrChildren
%                 chObj = this.getChildAtPos(i);
%                 if(~isempty(chObj))
%                     out = out + chObj.getSize();
%                 end
%             end
%             %todo: add fileInfo?!
%             %fprintf(1, 'Subject size %d bytes\n', out);
%         end

        function addObj(this,ch,dType,gScale,data)
            %add an object to FDTree and generate id (running number) automatically
            if(isempty(dType))
                %add only empty channel
                this.addChildByName(FDTChannel(this,ch),ch);
                return
            end
            %save size of data for whole subject if it is globally scaled
%             if(gScale && isempty(this.XSz))
                %[this.YSz, this.XSz] = size(data);
%             end
            if(gScale)
                %check if size of current data matches subject size
                [y, x, z] = size(data);
                if(~isempty(this.XSz) && (this.YSz ~= y || this.XSz ~= x || z ~= 1))
                    error('FDTree:FDTSubject:size','Size of current data matrix (%dx%d) does not match subject size (%dx%d)!',x,y,this.XSz,this.YSz);
                end
            end
            %insert data in specific channel with scaling sType
            chObj = this.getChild(ch);
            if(isempty(chObj))
                this.addChildByName(FDTChannel(this,ch),ch);%,true); %with overwrite flag
                chObj = this.getChild(ch);
            end
            chObj.addObj(dType,gScale,data);
        end

        function addObjID(this,nr,ch,dType,gScale,data)
            %add an object to FDTree with specific id (running number)
            %save size of data for whole subject if it is globally scaled
%             if(gScale && isempty(this.XSz))
%                 [this.YSz, this.XSz] = size(data);
%             end
            if(gScale)
                %check if size of current data matches subject size
                [y, x, z] = size(data);
                if(~isempty(this.XSz) && (this.YSz ~= y || this.XSz ~= x || z ~= 1))
                    %todo: remove this error message here
                    error('FDTree:FDTSubject:size','Size of current data matrix (%dx%d) does not match subject size (%dx%d)!',x,y,this.XSz,this.YSz);
                end
            end
            %insert data in specific channel
            chObj = this.getChild(ch);
            if(isempty(chObj))
                this.addChildByName(FDTChannel(this,ch),ch);
                chObj = this.getChild(ch);
            end
            chObj.addObjID(nr,dType,gScale,data);
        end

        function addObjMergeID(this,nr,ch,dType,gScale,data)
            %add merged FData object
            %insert data in specific channel
            chObj = this.getChild(ch);
            if(isempty(chObj))
                this.addChildByName(FDTChannel(this,ch),ch);
                chObj = this.getChild(ch);
            end
            chObj.addObjMergeID(nr,dType,gScale,data);
        end

        function addClusterID(this,ch,id,data)
            % add MVGroup object to channel
            chObj = this.getChild(ch);
            if(isempty(chObj))
                %should not be empty --> return?
                this.addChildByName(FDTChannel(this,ch),ch);
                chObj = this.getChild(ch);
            end
            chObj.addCluster(id,data);
        end

        function removeObj(this,ch,dType,id)
            %remove object from channel ch
            chObj = this.getChild(ch);
            if(isempty(chObj))
                return
            end
            chObj.removeObj(dType,id);
            %             if(chObj.getNrElements == 0)
            %                 %nothing in there anymore -> remove it from channel
            %                 this.deleteChildByName(ch);
            %             end
        end

        function removeResultChannelFromMemory(this,ch)
            %remove channel of a subject
            if(isempty(ch))
                %remove all channels
                this.deleteAllChildren();
            else
                %remove specific channel
                this.deleteChildByName(ch);
            end
%             if(this.nrChildren == 0)
%                 %reset size of image data
%                 this.XSz = [];
%                 this.YSz = [];
%             end
        end
        
        function deleteChannel(this,ch,type)
            %delete channel of a subject from memory and disk; type decides if measurement, result or both
            if(isempty(type))
                this.myMeasurement.deleteChannel(ch);
                this.myResult.deleteChannel(ch);
            elseif(strcmp(type,'measurement'))
                this.myMeasurement.deleteChannel(ch);
            elseif(strcmp(type,'result'))
                this.myResult.deleteChannel(ch);
                %this.removeResultChannelFromMemory(ch);
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
        function success = loadChannel(this,ch,forceLoadFlag)
            %load channel (measurement and results)
%             if(isMultipleCall())
%                 return
%             end
            success = false;
            persistent currentChannel
            if(isempty(currentChannel))
               currentChannel = ch;
            elseif(any((currentChannel - ch) < eps))
                %this channel is currently being loaded
                %success = true;
                return
            else %new channel -> add it to currentChannel
                currentChannel = [currentChannel, ch];
            end
            %check if there is an intensity image available
            chObj = this.getChild(ch);
            if(isempty(chObj))
                hfd = [];                
            else
                hfd = chObj.getFDataObj('Intensity',0,1); %check only linear data
            end
            intImage = [];
            %hfd = this.getFDataObj(ch,'Intensity',0,1);
            if(any(this.nonEmptyChannelList(:)) && any(ch == this.nonEmptyChannelList(:)) && (isempty(hfd) || ~this.channelResultIsLoaded(ch) || forceLoadFlag))
                this.updateShortProgress(0.33,sprintf('Load Ch %s',num2str(ch)));
                %add empty channel objects
                chObj = this.getChild(ch);
                if(isempty(chObj))
                    this.addObj(ch,[],[],[]);
                end
%                 channels = subObj.nonEmptyChannelList;
%                 for j = 1:length(channels)
%                     %this.checkIRFInfo(j);
%                     chObj = this.getChild(channels(j));
%                     if(isempty(chObj))
%                         this.addObj(this.name,channels(j),[],[],[]);
%                     end
%                 end
                %try to load intensity image
                if(isempty(hfd) || forceLoadFlag)
                    intImage = this.getROIDataFlat(ch,true);
                    allItems = this.myParent.getAllFLIMItems(this.name,ch);
                    if(~isempty(intImage) && (isempty(this.YSz) || isempty(this.XSz)) || ~isempty(intImage) && (size(intImage,1) == this.YSz && size(intImage,2) == this.XSz))
                        this.addObjID(0,ch,'Intensity',1,intImage);
                        if(isempty(allItems))
                            this.myParent.setAllFLIMItems(this.name,ch,{'Intensity'});
                        end
                    else
                        %try raw data
                        intImage = this.getRawDataFlat(ch);
                        if(~isempty(intImage) && ~isempty(this.YSz) && ~isempty(this.XSz) && size(intImage,1) == this.YSz && size(intImage,2) == this.XSz)
                            this.addObjID(0,ch,'Intensity',1,intImage);
                            if(isempty(allItems))
                                this.myParent.setAllFLIMItems(this.name,ch,{'Intensity'});
                            end
                        else
                            %we could not get a intensity image
                            %todo: throw warning / error message
                            %this.updateShortProgress(0,'');
                            %return
                        end
                    end
                else
                    intImage = hfd.rawImage;
                end
                %load result
                if(~this.channelResultIsLoaded(ch) || forceLoadFlag)
                    if(~any(this.myResult.filesOnHDD(:)) && ~any(this.myResult.pixelApproximated(:)))
                        %nothing to do
                        this.updateShortProgress(0,'');
                        idx = ((currentChannel - ch) < eps);
                        currentChannel(idx) = [];
                        return
                    end
                    this.updateShortProgress(0.66,sprintf('Load Ch %s',num2str(ch)));
%                     subObj = this.getSubject4Approx();
%                     if(~any(subObj.nonEmptyResultChannelList == ch))
%                         %subject doesn't have the requested channel
%                         return
%                     end
                    isASCIIResult = strcmp(this.resultType,'ASCII');
                    %check items (e.g. amps, taus) which are going to be loaded
                    allItems = this.myResult.getResultNames(ch,false);
                    %allItems = this.myParent.getAllFLIMItems(this.name,ch);
                    if(isempty(allItems))% && ~isempty(subObj))
                        %check items (e.g. amps, taus) which are going to be loaded
                        %try to get the result items again
                        allItems = removeNonVisItems(this.getResultNames(ch,false),3);
                        if(~isempty(allItems))
                            this.myParent.setAllFLIMItems(this.name,ch,allItems);
                        end
%                     elseif(isempty(allItems) && isempty(subObj))
%                         %this might be a measurement without result
%                         this.updateShortProgress(0,sprintf('Importing (Ch %s)',num2str(ch)));
%                         return
%                     elseif(~isempty(allItems) && isempty(subObj))
%                         this.updateShortProgress(0,sprintf('Importing (Ch %s)',num2str(ch)));
%                         %there is nothing we can do
%                         return
                    end
                    newItems = removeNonVisItems(allItems,this.FLIMXParamMgrObj.generalParams.flimParameterView);
                    csDef = this.myParent.getResultCrossSection(this.name);
                    %we may update an existing subject -> remove unwanted items
                    chObj = this.getChild(ch);
                    if(~isempty(chObj))
                        loadedItems = chObj.getChObjStr();
                    else
                        loadedItems = [];
                    end
                    if(~isempty(loadedItems))
                        %find items to be removed
                        itemsDelete = setdiff(loadedItems,newItems);
                        itemsDelete = setdiff(itemsDelete,'Intensity');
                        itemsDelete = setdiff(itemsDelete,this.myParent.getArithmeticImageDefinition());
                        for i = 1:length(itemsDelete)
                            %strip of tailing numbers
                            dType = itemsDelete{i};
                            dTypeNr = str2double(dType(isstrprop(dType, 'digit')));
                            if(isnan(dTypeNr))
                                dTypeNr = 1;
                            end
                            dType = dType(isstrprop(dType, 'alpha'));
                            this.removeObj(ch,dType,dTypeNr);
                            switch lower(dType)
                                case 'amplitude'
                                    this.removeObj(ch,'AmplitudePercent',dTypeNr);
                                    this.removeObj(ch,'Q',dTypeNr);
                                case 'tau'
                                    this.removeObj(ch,'Q',dTypeNr);
                            end
                        end
                    end
                    %add newItems
                    nr_e = numel(newItems);
                    for i=1:nr_e
                        dType = newItems{i};
                        %strip off tailing numbers
                        dTypeNr = str2double(dType(isstrprop(dType, 'digit')));
                        if(isnan(dTypeNr))
                            dTypeNr = 1;
                        end
                        dType = dType(isstrprop(dType, 'alpha'));
                        data_temp = this.getPixelFLIMItem(ch,newItems{i});
                        if(isempty(data_temp))
                            continue
                        end
                        if(isASCIIResult && strncmpi('Amplitude',dType,9) && length(dType) <= 11)
                            %scale amplitudes with IRF integral
                            %data_temp = data_temp .* this.myParent.myStudyInfoSet.getIRFInfo(chan);
                            data_temp = data_temp .* 10000;
                        end
                        try
                            this.addObjID(dTypeNr,ch,dType,1,data_temp);
                        catch ME
                            msg = regexp(ME.identifier,':','split');
                            uiwait(warndlg(sprintf('An Error occured in %s\n\n''%s''\n\nLoading channel %d of subject ''%s'' has been aborted!',ME.identifier,ME.message,ch,this.name),'Error importing Data','modal'));
                            if(strcmp(msg(end),'size'))
                                %abort, make sure nothing of this channel is left
                                this.removeResultChannelFromMemory(ch);
                                idx = ((currentChannel - ch) < eps);
                                currentChannel(idx) = [];
                                return
                            end
                        end
                    end
                    %find pixel without approximated fluorescence lifetime
                    tmp = this.getPixelFLIMItem(ch,'AmplitudePercent1');
                    if(this.myResult.isPixelResult(ch) && ~isempty(tmp))
                        ignoreMask = isnan(tmp);
                        chObj = this.getChild(ch);
                        chObj.setIgnoredPixelsMask(ignoreMask);
                    end
                    this.updateShortProgress(1,sprintf('Load Ch %s',num2str(ch))); %0.5
                    %check intensity image stored in result file
                    intImageResult = this.getPixelFLIMItem(ch,'Intensity');
                    %hfd = this.getFDataObj(ch,'Intensity',0,1); %check only linear data
                    if(isASCIIResult && isempty(intImage) && isempty(intImageResult))
                        %no intensity image -> approximate it from amplitudes
                        ampItems = allItems(cellfun(@length,allItems) == 10);
                        ampItems = ampItems(strncmp('Amplitude',ampItems,9));
                        if(~isempty(ampItems))
                            intImage = this.getPixelFLIMItem(ch,ampItems{1});
                            for i = 2:length(ampItems)
                                %no checking if dimensions agree - todo?!
                                intImage = intImage + this.getPixelFLIMItem(ch,ampItems{i});
                            end
                            if(isASCIIResult)
                                intImage = intImage.*10000;
                            end
                            this.addObjID(0,ch,'Intensity',1,intImage);
                        end
                    end
                end
                this.updateShortProgress(0,'');
            end
            idx = ((currentChannel - ch) < eps);
            currentChannel(idx) = [];
            success = true;
        end

        function setSubjectName(this,val)
            %set subject name
            %save possible changes
            this.myMeasurement.saveMatFile2Disk([]);
            this.myResult.saveMatFile2Disk([]);
            %rename working folder (if one exists)
            oldpath = this.getWorkingDirectory();
            idx = strfind(oldpath,this.name);
            if(~isempty(idx) && idx(end) > 1)
                newpath = [oldpath(1:idx(end)-1),val];
                if(isfolder(oldpath))
                    try
                        [status,msg,msgID] = movefile(oldpath,newpath);
                    catch ME
                    end
                end
                this.name = val;
                this.reset();
            end
        end

        function setdType(this,dType,val)
            %set new dType (new chunk name)
            for i = 1:this.nrChildren
                this.getChildAtPos(i).setdType(dType,val);
            end
        end

%         function setResultROICoordinates(this,dType,ROIType,ROICoord)
%             %set the ROI for all channels
%             for i = 1:this.nrChildren
%                 this.getChildAtPos(i).setResultROICoordinates(dType,ROIType,ROICoord);
%             end
%         end

        function setResultCrossSection(this,dim,csDef)
            %set the cross section for dimension dim
            for i = 1:this.nrChildren
                this.getChildAtPos(i).setResultCrossSection(dim,csDef);
            end
        end

        %% output functions
        function h = getFDataObj(this,ch,dType,id,sType)
            %get FData object
            h = [];
            if(~this.channelResultIsLoaded(ch))% && ~isMultipleCall())
                if(~this.loadChannel(ch,false))
                    return
                end
            end            
            if(isempty(ch))
                chObj = this.getChild(1);
            else
                chObj = this.getChild(ch);
            end
            if(isempty(chObj) && ~isempty(ch))
                if(strncmp(dType,'MVGroup',7) || strncmp(dType,'ConditionMVGroup',16) || strncmp(dType,'GlobalMVGroup',13))
                    this.addChildByName(FDTChannel(this,ch),ch);
                    chObj = this.getChild(ch);
                else
                    return
                end
            elseif(isempty(chObj) && isempty(ch))
                return
            end
            h = chObj.getFDataObj(dType,id,sType);
            %check if is arithmetic image
            [aiNames, aiParams] = this.myParent.getArithmeticImageDefinition();
            idx = strcmp(dType,aiNames);
            if(sum(idx) == 1 && (isempty(h) || isempty(h.getFullImage()))) %found 1 arithmetic image, try to get image data
                %(re)build arithmetic image
                this.makeArithmeticImage(aiNames{idx},aiParams{idx});
                h = chObj.getFDataObj(dType,id,sType);
            end            
        end

        function nr = getNrChannels(this)
            %get number of channels in subject
            nr = this.nrChildren;
        end

        function out = getMVGroupTargets(this,MVGroupNr)
            %get multivariate targets
            out = this.myParent.getMVGroupTargets(MVGroupNr);
        end

%         function nr = getMyChannelNr(this,caller)
%             %return the current channel number
%             for i = 1:this.nrChildren
%                 [chObj,nr] = this.getChildAtPos(i);
%                 if(~isempty(chObj) && chObj == caller)
%                     return
%                 end
%             end
%             nr = [];
%         end

        function [str, nrs] = getChStr(this)
            %get a string of all channels in subject
            nrs = this.nonEmptyChannelList(:);
            str = sprintfc('Ch %d',nrs);
        end

        function str = getChObjStr(this,ch)
            %get a string of all objects in channel ch in subject
            if(~this.channelResultIsLoaded(ch))
                this.loadChannel(ch,false);
            end
            chObj = this.getChild(ch);
            if(isempty(chObj))
                str = '';
                return
            else
                %get existing FLIMitems in channel + arithmetic images (which may have not been computed yet)
                str = this.myParent.getArithmeticImageDefinition();
                if(isempty(str{1}))
                    %no arithmetic images
                    str = sort(chObj.getChObjStr());
                else
                    %add arithmetic images to the list of channel objects
                    str = unique([chObj.getChObjStr(); str]);
                end
            end
        end

        function out = getMVGroupNames(this,mode)
            %get list of MVGroups in study
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            out = this.myParent.getMVGroupNames(mode);
        end

        function out = getHeight(this)
            %get height of subject
            out = this.YSz;
        end

        function out = getWidth(this)
            %get width of subject
            out = this.XSz;
        end

        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.myParent.getVicinityInfo();
        end

        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end
        
        function out = getROIGroup(this,grpName)
            %get the ROI group names and members
            out = this.myParent.getResultROIGroup(grpName);
        end

        function out = getROICoordinates(this,dType,ROIType)
            %get coordinates of ROI
%             if(isempty(ROIType) || this.getDefaultSizeFlag(dType))
                out = this.myParent.getResultROICoordinates(this.name,dType,ROIType);
%             else
%                 %this FLIM item (chunk) has a different size than the subject
%                 for ch = 1:this.nrChildren
%                     if(~this.channelResultIsLoaded(ch))
%                         this.loadChannel(ch,false);
%                     end
%                     chObj = this.getChild(ch);
%                     if(~isempty(chObj))
%                         %both channels should have the same ROi coordinates -> first non-empty channel is good enough
%                         out = chObj.getROICoordinates(dType,ROIType);
%                         return
%                     end
%                 end
%             end
        end

        function out = getZScaling(this,ch,dType,dTypeNr)
            %get z scaling
            out = this.myParent.getResultZScaling(this.name,ch,dType,dTypeNr);
        end

        function out = getColorScaling(this,ch,dType,dTypeNr)
            %get color scaling
            out = this.myParent.getResultColorScaling(this.name,ch,dType,dTypeNr);
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

        function out = channelResultIsLoaded(this,ch)
            %return true if subject was loaded from disk
            chObj = this.getChild(ch);
            if(~isempty(chObj))
                cos = chObj.getChObjStr();
                aid = this.myParent.getArithmeticImageDefinition();         
                if(~isempty(aid) && iscell(aid) && all(cellfun(@ischar,aid)))
                    idx = ismember(cos,aid);
                    cos(idx) = [];
                end
                idx = ismember(cos,'Intensity');
                cos(idx) = [];
                out = ~isempty(cos);
            else
                out = false;
            end
        end

        function out = isMember(this,ch,dType)
            %function checks combination of channel and datatype
            if(~this.channelResultIsLoaded(ch))
                this.loadChannel(ch,false);
            end
            chObj = this.getChild(ch);
            if(isempty(chObj))
                out = false;
            else
                out = chObj.isMember(dType);
            end
        end

        function out = isArithmeticImage(this,dType)
            %return true, if dType is an arithmetic image
            out = this.myParent.isArithmeticImage(dType);
        end

        function out = getDefaultSizeFlag(this,dType)
            %return true, if FLIM item (of dType) has the subject's default size
            out = false;
            for ch = 1:this.nrChildren
                if(~this.channelResultIsLoaded(ch))
                    this.loadChannel(ch,false);
                end
                chObj = this.getChild(ch);
                if(~isempty(chObj))
                    out = chObj.getDefaultSizeFlag(dType);
                    return
                end
            end
        end
        
%         function out = getNonDefaultSizeROICoordinates(this)
%             %get all FLIM items (dType; FDTChunk objects), which do not have the default subject image size
%             out = cell(0,0);
%             if(this.nrChildren < 1)
%                 return
%             end
%             %first channel in list is enough, as both channels have identical ROI coordinates
%             out = this.getChildAtPos(1).getNonDefaultSizeROICoordinates();
%         end

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
            %check for which channels the arithmetic image should be built
            [~, totalCh] = this.myParent.getChStr(this.name);
            if(aiParams.chA == 0 || aiParams.chB == 0 || (aiParams.chC == 0 && ~strcmp(aiParams.opB,'-no op-') && ~strcmp(aiParams.compAgainstC,'val'))) % todo: chC
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
            if(aiParams.chC == 0)
                chCList = totalCh;
            else
                chCList = repmat(aiParams.chC,1,nCh);
            end
            %loop over channels
            for chIdx = 1:nCh
                if(strcmp(aiParams.opA,'srcPixel') && strncmp(aiParams.FLIMItemA,'MVGroup',7))
                    %special method to determine the source pixels of an mv group scatter plot (2D histogram)                    
                    %get mvgroup roi and determine which pixels are not zero / NaN
                    allGrps = this.getROIGroup([]);
                    if(~isempty(allGrps))
                        grpID = find(strcmp(allGrps(:,1),aiParams.ROIB));
                    else
                        grpID = [];
                    end
                    if(~isempty(grpID))
                        %we found a ROI group
                        %ROI groups are not yet supported
                        %ROIType = -grpID;
                        ROIType = 0;
                        ROISubtype = 0;
                    elseif(strncmp(aiParams.ROIB,'ETDRS Grid#',11))
                        iETDRS = strfind(aiParams.ROIB,'->');
                        if(~isempty(iETDRS))
                            iETDRS = str2double(aiParams.ROIB(isstrprop(aiParams.ROIB,'digit')));
                            ROIType = 1000 + iETDRS;
                            eROIs = AICtrl.getDefROIString(iETDRS);
                            ROISubtype = find(strcmp(eROIs,aiParams.ROIB));
                        else
                            %should not happen
                            ROIType = 0;
                            ROISubtype = 0;
                        end
                    else
                        %circle, rectangle or polygon
                        ROIType = ROICtrl.ROIItem2ROIType(aiParams.ROIB);
                        ROISubtype = 0;
                    end
                    [dTypeA, dTypeANr] = FLIMXVisGUI.FLIMItem2TypeAndID(aiParams.FLIMItemA);
                    mvg_hfd = this.getFDataObj(chAList(chIdx),dTypeA{1},dTypeANr(1),1);
                    if(isempty(mvg_hfd))
                        return
                    end
                    sd = mvg_hfd.getSupplementalData();
                    %get ROI in mv group
                    [mvg_roi,roi_idx] = FData.getImgSeg(mvg_hfd.getFullImage(),this.getROICoordinates(dTypeA{1},ROIType),ROIType,ROISubtype,aiParams.ROIVicinityB,[],this.getVicinityInfo());                    
                    data = [];
                    if(~isempty(roi_idx) && numel(mvg_roi) == length(roi_idx))
                        %remove NaN and zeros from the ROI
                        mvg_roi = mvg_roi(~isnan(mvg_roi));
                        roi_idx(~mvg_roi) = [];
                        [row,col] = ind2sub([mvg_hfd.rawImgYSz(2),mvg_hfd.rawImgXSz(2)],roi_idx);
                        data = false([this.YSz,this.XSz]);
                        for mi = 1:length(roi_idx)
                            idx = sd(:,1) == col(mi) & sd(:,2) == row(mi);
                            if(~isempty(idx))
                                %should not happen to be empty
                                data(idx) = true;
                            end
                        end
                    end
                else
                    dataA = this.getArithmeticImageData(aiParams,'A',chAList(chIdx));
                    if(isempty(dataA))
                        continue
                    end
                    dataB = this.getArithmeticImageData(aiParams,'B',chBList(chIdx));
                    [opA, negA] = FDTStudy.str2logicOp(aiParams.opA);
                    [opB, negB] = FDTStudy.str2logicOp(aiParams.opB);
                    if(isempty(opB))
                        data = FDTSubject.calculateArithmeticImage(dataA,dataB,opA,negA);
                    else
                        %get dataC
                        dataC = this.getArithmeticImageData(aiParams,'C',chCList(chIdx));
                        %run opB first
                        data = FDTSubject.calculateArithmeticImage(dataB,dataC,opB,negB);
                        %now run opA
                        data = FDTSubject.calculateArithmeticImage(dataA,data,opA,negA);
                    end
                end
                if(isempty(data))
                    continue
                end
                %save arithmetic image
                this.addObjID(0,chAList(chIdx),aiName,1,data);
            end
            csDef = this.myParent.getResultCrossSection(this.name);
            if(~isempty(csDef) && length(csDef) == 6)
                %set cross sections for new items
                this.setResultCrossSection('X',csDef(1:3));
                this.setResultCrossSection('Y',csDef(4:6));
            end
        end

        function [cimg, lblx, cw, lbly] = makeConditionMVGroupObj(this,chan,MVGroupID)
            %make condition MVGroup for a spectral channel
            [cimg, lblx, cw, lbly] = this.myParent.makeConditionMVGroupObj(this.name,chan,MVGroupID);
        end

        function [cimg, lblx, lbly, cw, colors, logColors] = makeGlobalMVGroupObj(this,chan,MVGroupID)
            %make global MVGroup for a spectral channel
            [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalMVGroupObj(chan,MVGroupID);
        end

%         function flag = eq(ds1,ds2)
%             %compare two subjectDS objects
%             if(ischar(ds2))
%                 flag = strcmp(ds1.name,ds2);
%             else
%                 flag = strcmp(ds1.name,ds2.name);
%             end
%         end

    end %methods

        methods(Access = protected)
            function [data, idx] = getArithmeticImageData(this,aiParams,layer,ch)
                %gather data for artificial image layer (A, B or C)
                data = [];
                if(~any(strcmp({'A','B','C'},layer)))
                    return
                end
                if(strcmp(layer,'A'))
                    %layer A may only be a FLIMItem!
                    aiParams.compAgainstA = 'FLIMItem';
                end
                switch aiParams.(sprintf('compAgainst%s',layer))
                    case 'val'
                        data = aiParams.(sprintf('val%s',layer));
                    case 'FLIMItem'
                        lStr = sprintf('FLIMItem%s',layer);
                        if(strncmp(aiParams.(lStr),'subjectInfo->',13))
                            %get data from subject info
                            colName = aiParams.(lStr)(14:end);
                            switch colName
                                case 'Tau1_EstimatedByAge'
                                    data = this.getEstimatedTauByAge('Tau1',ch);                                    
                                case 'Tau2_EstimatedByAge'
                                    data = this.getEstimatedTauByAge('Tau2',ch); 
                                case 'Tau3_EstimatedByAge'
                                    data = this.getEstimatedTauByAge('Tau3',ch); 
                                case 'TauMean_EstimatedByAge'
                                    data = this.getEstimatedTauByAge('TauMean',ch); 
                                otherwise
                                    data = this.myParent.getDataFromStudyInfo('subjectInfoData',this.name,colName);
                            end
                        else
                            [dTypeB, dTypeBNr] = FLIMXVisGUI.FLIMItem2TypeAndID(aiParams.(lStr));
                            %ask study for FData object, if this is an arithmetic image, study will build it if needed
%                             %check here if channel is loaded, as this may be blocked in getFDataObj() by isMultipleCall() function
%                             if(~this.channelResultIsLoaded(ch))% && ~isMultipleCall()
%                                 this.loadChannel(ch,false);
%                             end
                            fd = this.getFDataObj(ch,dTypeB{1},dTypeBNr(1),1);
                            if(isempty(fd))
                                return
                            end
                            data = fd.getFullImage();
                            if(fd.rawImgIsLogical)
                                data(isnan(data)) = 0;
                                data = logical(data);
                            end
                        end
                        if(aiParams.normalizeB)
                            data = data ./ max(data(:),[],'omitnan');
                        end
                        if(nargout == 2)
                            idx = 1:numel(data);
                        end
                    case 'ROI'
                        lStr = sprintf('ROI%s',layer);                        
                        if(strncmp(aiParams.(lStr),'ETDRS Grid#',11))
                            iETDRS = strfind(aiParams.(lStr),'->');
                            if(~isempty(iETDRS))
                                iETDRS = str2double(aiParams.(lStr)(isstrprop(aiParams.(lStr),'digit')));
                                ROIType = 1000 + iETDRS;
                                eROIs = AICtrl.getDefROIString(iETDRS);
                                ROISubtype = find(strcmp(eROIs,aiParams.(lStr)));
                            else
                                %should not happen
                                ROIType = 0;
                                ROISubtype = 0;
                            end
                        else
                            ROIType = ROICtrl.ROIItem2ROIType(aiParams.(lStr));
                            ROISubtype = 0;
                        end
                        [dTypeA, dTypeANr] = FLIMXVisGUI.FLIMItem2TypeAndID(aiParams.FLIMItemA);
                        fd = this.getFDataObj(ch,dTypeA{1},dTypeANr(1),1);
                        if(isempty(fd))
                            return
                        end
                        [data, idx] = fd.getROIImage(this.getROICoordinates(dTypeA{1},ROIType),ROIType,ROISubtype,aiParams.(sprintf('ROIVicinity%s',layer)));
                        if(~isempty(data))
                            data = mean(data(:),'omitnan');
                        end
                end
            end

        % Override copyElement method:
%         function cpObj = copyElement(this)
%             %make sure we create the approx. obects for all channels
%             for ch = 1:this.nrSpectralChannels
%                 this.getApproxObj(ch,1,1);
%             end
%             % Make a shallow copy of all properties
%             cpObj = copyElement@matlab.mixin.Copyable(this);
%             % Make a deep copy of the DeepCp object
%             cpObj.myParent = [];
%             cpObj.progressCb = cell(0,0);
%         end
        end

        methods(Static)
            function out = calculateArithmeticImage(dataA,dataB,op,neg)
                %run operation op on dataA and dataB using the negativation flag
                idxA = ~isnan(dataA);
                idxA(idxA) = logical(dataA(idxA));
                idxB = ~isnan(dataB);
                idxB(idxB) = logical(dataB(idxB));
                if(isempty(idxA))
                    out = dataB;
                    return
                elseif(isempty(idxB))
                    out = dataA;
                    return
                end
                switch op
                    case '&'
                        eval(sprintf('idx = %s(idxA %s idxB);',neg,op));
                        out = dataA;
                        if(islogical(out))
                            out(~idx) = false;
                        end
                    case '|'
                        eval(sprintf('idx = %s(idxA %s idxB);',neg,op));
                        if(isempty(neg))
                            %this is |
                            out = zeros(size(dataA),'like',dataA);
                            out(idxB) = dataB(idxB);
                            out(idxA) = dataA(idxA);
                        else
                            %this is ~|
                            out = dataA;
                            if(islogical(out))
                                out(~idx) = false;
                            end
                        end
                    case 'xor'
                        %out = false(size(idx));
                        %eval(sprintf('out(idx) = %sxor(dataA(idx),dataB(idx));',neg));
                        eval(sprintf('idx = %sxor(idxA,idxB);',neg));
                        out = zeros(size(dataA),'like',dataA);
                        out(idxB & idx) = dataB(idxB & idx);
                        out(idxA & idx) = dataA(idxA & idx);
                    case {'dilate','erode','open','close'}
                        dataA(~idxA) = 0;
                        eval(sprintf('out = im%s(dataA,strel(''disk'',%d));',op,uint32(dataB(1))));
                        %out = logical(out);
                        idx = logical(out);
                    case 'fillLargest'
                        %select largest region and fill it
                        dataA(~idxA) = 0;
                        rp = regionprops(logical(dataA),'FilledArea','FilledImage','BoundingBox');
                        idx = false(size(dataA));
                        if(isempty(rp))
                            out = zeros(size(dataA),'like',dataA);
                        else
                            out = ones(size(dataA),'like',dataA);
                            [~,rIdx] = max([rp.FilledArea]);
                            idx(ceil(rp(rIdx).BoundingBox(2)):ceil(rp(rIdx).BoundingBox(2))+rp(rIdx).BoundingBox(4)-1,...
                                ceil(rp(rIdx).BoundingBox(1)):ceil(rp(rIdx).BoundingBox(1))+rp(rIdx).BoundingBox(3)-1) = rp(rIdx).FilledImage;
                            %idx = imfill(idx,'holes');
                            if(islogical(out))
                                out(~idx) = false;
                            end
                        end
                    case 'fillAll'
                        dataA(~idxA) = 0;
                        rp = regionprops(logical(dataA),'FilledArea','FilledImage','BoundingBox');
                        idx = false(size(dataA));
                        if(isempty(rp))
                            out = zeros(size(dataA),'like',dataA);
                        else
                            out = ones(size(dataA),'like',dataA);
                            for i = 1:length(rp)
                                idxTmp = false(size(dataA));
                                idxTmp(ceil(rp(i).BoundingBox(2)):ceil(rp(i).BoundingBox(2))+rp(i).BoundingBox(4)-1,...
                                    ceil(rp(i).BoundingBox(1)):ceil(rp(i).BoundingBox(1))+rp(i).BoundingBox(3)-1) = rp(i).FilledImage;
                                idx = idx | idxTmp;
                                %idx = imfill(idx,'holes');
                            end
                            if(islogical(out))
                                out(~idx) = false;
                            end
                        end
                    case 'remLocalMin'
                        dataA(~idxA) = 0;
                        out = imhmin(uint32(dataA),dataB(1));
                        idx = logical(out);
                    case 'min'
                        dataA(~idxA) = 0;
                        out = min(dataA(:));
                        idx = logical(out);
                    case 'max'
                        dataA(~idxA) = 0;
                        out = max(dataA(:));
                        idx = logical(out);
                    otherwise %+,-,*,/,>,<,>=,<=,==,~=
                        if(~any(idxA(:)))
                            out = dataB;
                            idx = idxB;
                        elseif(~any(idxB(:)))
                            out = dataA;
                            idx = idxA;
                        else
                            eval(sprintf('out = (dataA %s dataB);',op));
                            idx = true(size(out));
                            if(islogical(out))
                                out(~idx) = false;
                            end
                        end
                end
                if(~islogical(out))
                    out(~idx) = NaN;
                end
            end
        end
end %classdef
