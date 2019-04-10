classdef fluoSubject < FDTreeNode
    %=============================================================================================================
    %
    % @file     fluoSubject.m
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
    % @brief    A class to represent a subject, consisting of fluoFile, result and other data
    %
    properties(GetAccess = public, SetAccess = protected)
%         name = '';
%         myParent = [];
        filesOnHDD = false(2,0);
        myMeasurement = [];
        myResult = [];      
        myParamMgr = [];        
        progressCb = cell(0,0); %callback function handles for progress bars
        lastApproxObj = cell(0,0);
        initMode = false;
        isInitialized = false;
    end
    
    properties (Dependent = true)
        myIRFMgr = [];
        
        tacRange = 0;
        nrTimeChannels = 0;
        timeChannelWidth = 0;
        nrSpectralChannels = 1;
        timeVector = [];
        ROICoordinates = [];
        
        isDirty = false;
        resultIsDirty = false;
        measurementIsDirty = false;
        nonEmptyChannelList = [];
        nonEmptyMeasurementChannelList = [];
        nonEmptyResultChannelList = [];
        resultType = '';
        position = '';
        pixelResolution = 0;
        
        aboutInfo = [];
        computationParams = [];
        folderParams = [];
        preProcessParams = [];
        basicParams = [];
        initFitParams = [];
        pixelFitParams = [];
        boundsParams = [];
        optimizationParams = [];
        volatilePixelParams = [];
    end
    
    methods
        function this = fluoSubject(parentObj,name)
            %constructor
            this = this@FDTreeNode(parentObj,name);           
            if(isa(parentObj,'FDTStudy'))
                this.initParamMgr();
            elseif(isa(parentObj,'FDTree'))
                this.initParamMgr();
                this.myParent = [];
            elseif(isa(parentObj,'paramMgr'))
                this.myParent = [];
                this.myParamMgr = subjectParamMgr(this,parentObj.getParamSection('about'));
            else
                error('fluoSubject: No handle to study or parameter manager given');
            end            
        end
        
        function  pingLRUCacheTable(this,obj)
            %ping LRU table for object obj
            if(~isempty(this.myParent))
                this.myParent.pingLRUCacheTable(obj);
            end
        end
        
        %% input methods
        function init(this)
            %init measurement and result objects 
            if(this.initMode)
                %this is a recursion
                return
            end
            this.initMode = true;
            this.loadParameters();
            this.initMode = false;
            this.isInitialized = true;
        end
        
        function initParamMgr(this)
            %reset parameter manager
            hp = this.getParentParamMgr();
            if(~isempty(hp))
                this.myParamMgr = subjectParamMgr(this,hp.getParamSection('about'));
            end            
        end        
        
        function clearCachedApproxObj(this)
            %delete the last used approximation object, this will trigger a
            %re-generation of the approx. object if required
            this.lastApproxObj = cell(0,0);
        end
        
        function setStudy(this,study)
            %set name of my study or handle to my study object
            this.myParent = study;
        end
        
        function setSubjectName(this,name)
            %set my subject name
            this.name = name;
        end
        
        function setProgressCallback(this,cb)
            %set handle to GUI function to draw progress updates
            this.progressCb(end+1) = {cb};
        end
        
        function setMeasurementROICoord(this,roi)
            %set roi coordinates for measurement, resets results
            if(~this.isInitialized)
                this.init();
            end
            this.myMeasurement.setROICoord(roi);
            this.myResult.allocResults(1:this.nrSpectralChannels,roi(4)-roi(3)+1,roi(2)-roi(1)+1);
        end
        
        function loadParameters(this,pStr,params)
            %try to load parameters by loading a result, if no result available, load them from FLIMX parameter manager
            if(isempty(this.myParamMgr) || isempty(this.myMeasurement) || isempty(this.myResult))
                return
            end            
            if(nargin == 1 && ~isempty(this.myResult.nonEmptyChannelList))
                %we've got results to load
                if(this.myResult.openChannel(this.myResult.nonEmptyChannelList(1)))                    
                    this.myParamMgr.makeVolatileParams();
                end
                if(~isempty(this.myMeasurement.nonEmptyChannelList))
                    this.myMeasurement.getROIInfo(this.myMeasurement.nonEmptyChannelList(1));
                end
                %check we have channels without a result file
                chNrs = setdiff(1:this.nrSpectralChannels,this.myResult.nonEmptyChannelList);
                if(~isempty(chNrs))
                    this.updateAuxiliaryData(chNrs);
                end
            elseif(nargin == 3 && strcmp(pStr,'batchJob'))
                %we get everything from the batch job manager
                this.myParamMgr.setParamSection('batchJob',params);
                this.updateAuxiliaryData([]);
            else
                this.update();
            end
            %load the ROI info again, as binning parameters might have changed
            this.clearCachedApproxObj();
        end        
                
        function update(this)
            %pull current paramters from FLIMX and save them into local parameter manager
%             if(~this.isInitialized)
%                 this.init();
%             end
            this.myParamMgr.setParamSection('result',this.getParentParamMgr().getParamSection('result'));
            this.updateAuxiliaryData([]);
            this.clearCachedApproxObj();
        end
        
        function updateAuxiliaryData(this,chList)
            %update auxiliaryData in my result from measurement, clears results
%             if(~this.isInitialized)
%                 this.init();
%             end
            ad.fileInfo = [];
            ad.measurementROIInfo = [];
            ad.IRF.vector = [];
            ad.IRF.name = '';
            ad.scatter = [];
            updateAllChs = false;
            if(isempty(this.myMeasurement) || isempty(this.nrSpectralChannels))
                this.myResult.setAuxiliaryData(1,ad);
            else
                if(isempty(chList))
                    updateAllChs = true;
                    chList = 1:this.nrSpectralChannels;
                end
                if(isvector(chList) && ~isscalar(chList))
                    for ch = chList                        
                        %because of updating the parameters, the nr of
                        %spectral channels could have changed (switching
                        %between lifetime and anisotropy)
                        if(ch > this.nrSpectralChannels)
                            this.myResult.setAuxiliaryData(ch,[]);
                        else
                            this.updateAuxiliaryData(ch);                            
                        end                        
                    end
                    if(updateAllChs && chList(end) < this.nrSpectralChannels)
                        %we switched to anisotropy -> make auxdata for channels 3 and 4
                        chList = setdiff(1:this.nrSpectralChannels,chList);
                        for ch = chList
                            if(ch > this.nrSpectralChannels)
                                this.updateAuxiliaryData(ch);
                            end
                        end
                    end
                    return
                elseif(isscalar(chList))
                    ad.fileInfo = this.myMeasurement.getFileInfoStruct(chList);
                    ad.measurementROIInfo = this.myMeasurement.getROIInfo(chList);
                    if(isfield(ad.measurementROIInfo,'ROISupport'))
                        ad.measurementROIInfo.ROISupport = [];
                    end
                    if(~isempty(this.myIRFMgr) && ~isempty(ad.fileInfo))
                        if(this.basicParams.approximationTarget == 2 && chList > 2)
                            ch = chList -2;
                        else
                            ch = chList;
                        end
                        [tmp, ad.IRF.name] = this.myIRFMgr.getIRF(ad.fileInfo.nrTimeChannels,this.basicParams.curIRFID,ad.fileInfo.tacRange,ch);
                        if(isempty(tmp))
                            [tmp, ad.IRF.name] = this.myIRFMgr.getIRF(ad.fileInfo.nrTimeChannels,[],ad.fileInfo.tacRange,ch);
                            if(isempty(tmp))
                                tmp = zeros(ad.fileInfo.nrTimeChannels,1);
                                tmp(1,1) = 1;
                            end
                        end
                        ad.IRF.vector = uint16(tmp);
                    end
                    %scatter data %[nrTimeCh nrScatter nrSpectralCh] = size(scatter);
                    if(this.basicParams.scatterEnable)
                        if(~isempty(this.basicParams.scatterStudy))
                            if(isempty(this.myParent))
                                this.basicParams.scatterStudy = '';
                            else
                                myStudy = this.myParent;
                                if(~strcmp(myStudy.name,this.basicParams.scatterStudy))
                                    curScatterFile = myStudy.myParent.getSubject4Approx(this.basicParams.scatterStudy,this.name(),false);
                                else
                                    curScatterFile = [];
                                end
                                if(isempty(curScatterFile) || isempty(curScatterFile.nonEmptyChannelList))
                                    ad.scatter = [];
                                    this.basicParams.scatterStudy = '';
                                else
                                    %check if scatter file has an init result
                                    bp = curScatterFile.basicParams;
                                    if(~curScatterFile.isInitResult(chList) || ~strcmp(bp.curIRFID,this.basicParams.curIRFID) || curScatterFile.initFitParams.gridSize ~= 1 || bp.nExp ~= 2)
                                        %compute the init result
                                        %set some parameters to fixed values
                                        if(~strcmp(bp.curIRFID,this.basicParams.curIRFID))
                                            curScatterFile.basicParams.curIRFID = this.basicParams.curIRFID;
                                        end
                                        bp.approximationTarget = 1;
                                        bp.hybridFit = 1;
                                        bp.reconvoluteWithIRF = 1;
                                        bp.fitModel = 0;
                                        bp.nExp = 2;
                                        bp.incompleteDecay = 1;
                                        bp.tciMask = [0 0];
                                        bp.stretchedExpMask = [0 0];
                                        bp.nonLinOffsetFit = 1;
                                        bp.constMaskSaveStrCh1 = '';
                                        bp.constMaskSaveStrCh2 = '';
                                        curScatterFile.basicParams = bp;
                                        curScatterFile.boundsParams.bounds_offset.ub = 1000;
                                        curScatterFile.boundsParams.bounds_offset.lb = 0.1;
                                        if(curScatterFile.initFitParams.gridSize ~= 1)
                                            curScatterFile.initFitParams.gridSize = 1;
                                            curScatterFile.initFitParams.gridPhotons = 0;
                                            curScatterFile.preProcessParams.autoStartPos = 1;
                                            curScatterFile.preProcessParams.autoEndPos = 1;
                                            curScatterFile.preProcessParams.autoReflRem = -1;
                                            curScatterFile.preProcessParams.roiAdaptiveBinMax = 10;
                                        end
                                        apObj = curScatterFile.getInitApproxObjs(chList);
                                        resultStruct = makePixelFit(apObj,this.optimizationParams,this.aboutInfo);
                                        if(isstruct(resultStruct))
                                            if(resultStruct.chi2 > 2)
                                                %todo: throw warning / error
                                            end
                                            curScatterFile.addInitResult(chList,[1 1],resultStruct);
                                        end
                                        curScatterFile.updateSubjectChannel(chList,'result'); %update measurement as well?
                                        curScatterFile.myParent.save();
                                    end                                        
                                    offset = curScatterFile.getInitFLIMItem(chList,'Offset');                                        
                                    tmp = curScatterFile.getROIMerged(chList);
                                    if(max(tmp(:)) >= 2^16 && strcmp(ad.measurementROIInfo.ROIDataType,'uint16'))
                                        ad.scatter = zeros(ad.fileInfo.nrTimeChannels,this.volatilePixelParams.nScatter-this.basicParams.scatterIRF,'uint32');
                                    else
                                        ad.scatter = zeros(ad.fileInfo.nrTimeChannels,this.volatilePixelParams.nScatter-this.basicParams.scatterIRF,ad.measurementROIInfo.ROIDataType);
                                    end
                                    tmp = squeeze(curScatterFile.getInitData(chList,[]));  %tmp =  curScatterFile.getROIMerged(chList);
                                    %substract offset
                                    idx = tmp > 0;
                                    tmp(idx) = tmp(idx) - offset;
                                    tmp(tmp < 0) = 0;
                                    ad.scatter(:,1) = tmp;
                                end
                            end
                        end
%                         if(this.basicParams.scatterIRF)
%                             if(isempty(ad.scatter))
%                                 ad.scatter = ad.IRF.vector;
%                             else
%                                 ad.scatter(:,end) = ad.IRF.vector;
%                             end
%                         end
                    end
                    this.myResult.setAuxiliaryData(chList,ad);
                end
            end
            if(isempty(this.myResult.nonEmptyChannelList) || ~(length(this.myResult.filesOnHDD) >= chList(1) && this.myResult.filesOnHDD(chList(1))))
                %we have not yet loaded a channel
                this.myParamMgr.makeVolatileParams();
            end
            for i = 1:length(chList)
                this.myResult.allocResults(chList(i),this.getROIYSz(),this.getROIXSz());
            end
        end
        
        function updatePixelResolution(this,val,target)
            %set pixel resolution field in fileInfoStruct to new value,
            %target = '' update measurement and result, target = 'm' update
            %measurement only, target = 'r' update result only
            if(~this.isInitialized)
                this.init();
            end
            if(isempty(target))
                this.myMeasurement.pixelResolution = val;
                this.myResult.setPixelResolution(val);
            elseif(strcmp(target,'m'))
                this.myMeasurement.pixelResolution = val;
            elseif(strcmp(target,'r'))
                this.myResult.setPixelResolution(val);
            end
        end
        
        function updatePosition(this,val,target)
            %set position field in fileInfoStruct to new value
            %target = '' update measurement and result, target = 'm' update
            %measurement only, target = 'r' update result only
            if(~this.isInitialized)
                this.init();
            end
            if(isempty(target))
                this.myMeasurement.position = val;
                this.myResult.setPosition(val);
            elseif(strcmp(target,'m'))
                this.myMeasurement.position = val;
            elseif(strcmp(target,'r'))
                this.myResult.setPosition(val);
            end
        end
        
        %% output
        function success = checkFileInfoLoaded(this)
            %check if a measurement channel is loaded, if not, load any channel if available
            if(~this.myMeasurement.fileInfoLoaded && ~isempty(this.myMeasurement.nonEmptyChannelList))
                this.myMeasurement.getRawData(this.myMeasurement.nonEmptyChannelList(1));
            end
            success = this.myMeasurement.fileInfoLoaded;
        end
        
        function out = getNonEmptyChannelList(this,type)
            %return list of channels which have a measurement, a result or both
            switch type
                case 'measurement'
                    out = this.myMeasurement.nonEmptyChannelList(:)';
                case 'result'
                    out = this.myResult.nonEmptyChannelList(:)';
                otherwise
                    out = union(this.myMeasurement.nonEmptyChannelList(:),this.myResult.nonEmptyChannelList(:))';
            end
        end
        
        function out = getFileInfoStruct(this,ch)
            %return fileinfo struct
            out = [];
            if(~isMultipleCall())
                %try to get file info from measurement
                if(isempty(ch) && ~isempty(this.myMeasurement.nonEmptyChannelList))
                    %pick first available channel
                    ch = this.myMeasurement.nonEmptyChannelList(1);
                end
                if(~isempty(ch))
                    out = this.myMeasurement.getFileInfoStruct(ch);
                else
                    %try to get file info from result
                    if(~this.isInitialized)
                        this.init();
                    end
                    if(~isempty(this.myResult.getNonEmptyChannelList))
                        out = this.myResult.getFileInfoStruct(ch);
                    end
                end
%                 if(isempty(out))% && this.checkFileInfoLoaded())
%                     %result doesn't have fileInfo, 
%                 end
            end
        end
        
        function saveMatFile2Disk(this,ch)
            %save measurements and results to disk, if ch is empty, save all channels
            if(isempty(this.getMyFolder()))
                %there is no path to write to -> nothing to do
                %set dirty flags to false?
                return
            end
            if(this.myMeasurement.isDirty)
                this.myMeasurement.saveMatFile2Disk(ch);
                if(~this.isInitialized)
                    this.init();
                end
            end
            if(this.myResult.isDirty)
                this.myResult.saveMatFile2Disk(ch);
            end
        end
        
        function exportMatFile(this,ch,folder)
             %save measurement and results to specific folder
             if(isempty(ch))
                for ch = 1:this.nrSpectralChannels
                    this.exportMatFile(ch,folder);
                end
                return
            end
            this.myMeasurement.exportMatFile(ch,folder);
            if(~this.isInitialized)
                this.init();
            end
            this.myResult.exportMatFile(ch,folder); 
        end
                     
%         function save2Disk(this,ch,expDir,addStr)
%             %write results to disk
%             if(nargin < 2)
%                 expDir = this.folderParams.export;
%                 addStr = '';
%             end
%             if(~isfolder(expDir))
%                 warndlg(sprintf('Could not find Export-Path:\n %s\n\nInstead results will be saved to:\n %s',expDir,cd),...
%                     'Export Path not found!','modal');
%                 expDir = cd;
%             end
%             if(strcmp(expDir(end),filesep)) %remove possible tailing '\'
%                 expDir = expDir(1:end-1);
%             end
%             expStr = fullfile(expDir,this.name,sprintf('%dexp_%dtci_%s_%s',...
%                 this.basicParams.nExp,sum(this.basicParams.tciMask),addStr,datestr(now,'dd.mmm.yyyy_HH.MM.SS')));
%             mkdir(expStr);
%             if(any(this.volatilePixelParams.globalFitMask))
%                 %global fit: save all channels
%                 for ch = 1:this.nrSpectralChannels
%                     this.myResult.saveMatFile2Disk(ch);
%                     %save measurement data as well
%                     this.myMeasurement.saveMatFile2Disk(ch,expStr);
%                 end
%             else
%                 this.myResult.saveMatFile2Disk(ch);
%                 %save measurement data as well
%                 this.myMeasurement.saveMatFile2Disk(ch,expStr);
%             end
%         end
        function out = get.isDirty(this)
            %return true if something has to be saved to hdd
            out = any(this.resultIsDirty(:)) || any(this.measurementIsDirty(:));
        end
        
%         function out = get.nonEmptyResultChannelList(this)
%             %get non empty channels of my result
%             out = this.myResult.nonEmptyChannelList;
%         end
        
        function out = get.resultType(this)
            %return string with result type
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.resultType;
        end
        
        function out = get.position(this)
            %get measurement position (e.g. OD or OS)            
            fi = this.getFileInfoStruct([]);
            if(~isempty(fi))
                out = fi.position;
            else
                out = this.myMeasurement.position;
            end
        end
        
        function out = get.pixelResolution(this)
            %get pixel resolution
            fi = this.getFileInfoStruct([]);
            if(~isempty(fi))
                out = fi.pixelResolution;
            else
                out = this.myMeasurement.pixelResolution;
            end
        end
        
        %% output methods measurement
        function out = getSourceFile(this)
            %return origin of the data
            out = this.myMeasurement.getSourceFile();
        end
        
        function out = get.tacRange(this)
            %get tac range
            fi = this.getFileInfoStruct([]);
            out = [];
            if(~isempty(fi))
                out = fi.tacRange;
            end
        end
        
        function out = get.nrTimeChannels(this)
            %get nr of time channels
            fi = this.getFileInfoStruct([]);
            out = [];
            if(~isempty(fi))
                out = fi.nrTimeChannels;
            end
        end
        
        function out = get.timeChannelWidth(this)
            %get time channel width
            fi = this.getFileInfoStruct([]);
            out = [];
            if(~isempty(fi))
                out = fi.tacRange / fi.nrTimeChannels * 1000;
            end
        end
        
        function out = get.nonEmptyChannelList(this)
            %get number of spectral channels
            out = this.getNonEmptyChannelList('');
        end
        
        function out = get.nonEmptyMeasurementChannelList(this)
            %get number of spectral channels in measurements
            out = this.myMeasurement.nonEmptyChannelList;
        end
        
        function out = get.nonEmptyResultChannelList(this)
            %get number of spectral channels in results
%             if(strcmp(this.resultType,'ASCII'))
                out = this.myResult.nonEmptyChannelList;
%             else
%                 out = this.myMeasurement.nonEmptyChannelList;
%             end
        end
        
        function out = get.nrSpectralChannels(this)
            %get number of spectral channels
            fi = this.getFileInfoStruct([]);
            out = [];
            if(~isempty(fi))
                out = fi.nrSpectralChannels;
            end
        end
        
        function out = get.timeVector(this)
            %get a vector of time points for each "time" class
            fi = this.getFileInfoStruct([]);
            out = [];
            if(~isempty(fi))
                out = linspace(0,fi.tacRange,fi.nrTimeChannels)';
            end
        end
        
        function out = getReflectionMask(this,channel)
            %get reflection mask of channel
            fi = this.getFileInfoStruct(channel);
            out = [];
            if(~isempty(fi))
                out = fi.reflectionMask;
            end
        end
        
        function out = getStartPosition(this,channel)
            %get start position of channel
            fi = this.getFileInfoStruct(channel);
            out = [];
            if(~isempty(fi))
                out = this.fileInfo.StartPosition;
            end
        end
        
        function out = getEndPosition(this,channel)
            %get end position of channel
            fi = this.getFileInfoStruct(channel);
            out = [];
            if(~isempty(fi))
                out = fi.EndPosition;
            end
        end
        
        function out = get.ROICoordinates(this)
            %returns the coordinates of the ROI
            if(this.checkFileInfoLoaded())
                out = this.myMeasurement.ROICoordinates;
            else
                out = zeros(4,1);
            end
        end
        
        function out = getROIXSz(this)
            %return ROI width of x axis
            out = 1;
            coord = this.myMeasurement.ROICoordinates;
            if(~isempty(coord))
                out = coord(2) - coord(1) +1;
            end
        end
        
        function out = getROIYSz(this)
            %return ROI width of y axis
            out = 1;
            coord = this.myMeasurement.ROICoordinates;
            if(~isempty(coord))
                out = coord(4) - coord(3) +1;
            end
        end
        
        function out = getRawXSz(this)
            %return raw width of x axis
            this.checkFileInfoLoaded();
            out = this.myMeasurement.rawXSz;
        end
        
        function out = getRawYSz(this)
            %return raw width of x axis
            this.checkFileInfoLoaded();
            out = this.myMeasurement.rawYSz;
        end
        
        function out = getStudyName(this)
            %get study name
            if(~isempty(this.myParent))
                out = this.myParent.name;
            else
                out = '';
            end
        end
        
        function out = getDatasetName(this)
            %get subject name
            out = this.name;
        end
        
        function out = getRawDataFlat(this,channel)
            %get intensity image of (raw) measurement data
            out = this.myMeasurement.getRawDataFlat(channel);
        end
        
        function out = getROIDataFlat(this,channel,noBinFlag)
            %get intensity of roi for channel
            out = this.myMeasurement.getROIDataFlat(channel,noBinFlag);
        end
        
        function out = getROIData(this,channel,y,x)
            %get roi data for channel
            out = this.myMeasurement.getROIData(channel,y,x);
        end
        
        function out = getROIMerged(this,channel)
            %get the ROI merged to a single decay
            out = this.myMeasurement.getROIMerged(channel);
        end
        
        function [initData,binLevels,masks,nrPixels] = getInitData(this,ch,target)
            %returns data for initialization fit of the corners of the ROI, each corner has >= target photons
            [initData,binLevels,masks,nrPixels] = this.myMeasurement.getInitData(ch,target);
        end 
        
        function out = getMyFolder(this)
            %return subjects working folder
            if(isempty(this.myParent))
                out = '';                
            else
                out = fullfile(this.myParent.myDir,this.name);
            end
        end
        
        function out = getMyParamMgr(this)
            %return subjects parameter manager
            out = this.myParamMgr;
        end
        
        function out = get.measurementIsDirty(this)
            %return flag if measurement is dirty
            out = this.myMeasurement.dirtyFlags;
        end
        
        function out = get.resultIsDirty(this)
            %return flag if result is dirty
            out = this.myResult.dirtyFlags;
        end
        
        function out = getResultType(this)
            %get the result type ('ASCII' or 'FluoDecayFit')
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.getResultType();
        end
        
        function out = getResultNames(this,ch,isInitResult)
            %get the names of the result structure
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.getResultNames(ch,isInitResult);
        end
        
        function out = isInitResult(this,ch)
            %true if init result was set
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.isInitResult(ch);
        end
        
        function out = isPixelResult(this,ch,y,x,initFit)
            %true if pixel result was set
            if(~this.isInitialized)
                this.init();
            end
            if(nargin == 2)
                out = this.myResult.isPixelResult(ch);
            else
                out = this.myResult.isPixelResult(ch,y,x,initFit);
            end
        end
        
        function out = getInitFLIMItem(this,ch,pStr)
            %return specific init result, e.g. tau 1
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.getInitFLIMItem(ch,pStr);
            if(strncmp(pStr,'AnisotropyQuick',15) && ~isempty(out) && sum(out(:)) == 0 && this.basicParams.approximationTarget == 2)
                %build AnisotropyQuick
                i1 = this.myMeasurement.getInitData(1);
                [~,m1] = max(i1,[],3);
                i4 = this.myMeasurement.getInitData(4);
                if(isempty(i4))
                    return
                end
                siz = size(m1);
                out = zeros(siz);
                tMax = size(i4,3);
                for i = 1:numel(m1)
                    [i1,i2] = ind2sub(siz,i);
                    out(i1,i2) = mean(i4(i1,i2,max(1,m1(i1,i2)):min(tMax,m1(i1,i2)+2)));
                end
                rs.AnisotropyQuick = out;
                idx = zeros(this.initFitParams.gridSize.^2,2);
                [idx(:,1), idx(:,2)] = ind2sub([this.initFitParams.gridSize this.initFitParams.gridSize],this.initFitParams.gridSize.^2);                
                this.myResult.addInitResult(ch,idx,rs);
            end
        end
        
        function out = getPixelFLIMItem(this,ch,pStr,y,x)
            %return specific pixel result, e.g. tau 1, optional pixel coordinates
            if(~this.isInitialized)
                this.init();
            end
            if(nargin == 5) %toDo: fix this ugly construct
                out = this.myResult.getPixelFLIMItem(ch,pStr,y,x);
            else
                out = this.myResult.getPixelFLIMItem(ch,pStr);
            end
            if(strncmp(pStr,'AnisotropyQuick',15) && ~isempty(out) && sum(out(:)) == 0 && this.basicParams.approximationTarget == 2)
                %build AnisotropyQuick
                i1 = this.myMeasurement.getROIData(1,[],[]);
                [~,m1] = max(i1,[],3);
                i4 = this.myMeasurement.getROIData(4,[],[]);
                if(isempty(i4))
                    return
                end
                siz = size(m1);
                out = zeros(siz);
                tMax = size(i4,3);
                for i = 1:numel(m1)
                    [i1,i2] = ind2sub(siz,i);
                    out(i1,i2) = mean(i4(i1,i2,max(1,m1(i1,i2)):min(tMax,m1(i1,i2)+2)));
                end
                %rs.AnisotropyQuick = out;
                %this.myResult.addFLIMItems(ch,rs);
                this.myResult.setPixelFLIMItem(ch,'AnisotropyQuick',out);                
                %optional: select only one pixel
                if(nargin == 5 && ~isempty(out))
                    out = squeeze(out(max(1,min(size(out,1),y)),max(1,min(size(out,2),x)),:));
                end
            end
        end
        
        function [apObj, xVec, hShift, oset, chi2, chi2Tail, TotalPhotons, iterations, time, slopeStart, iVec] = getVisParams(this,ch,y,x,initFit)
            %get parameters for visualization of current fit in channel ch
            if(~this.isInitialized)
                this.init();
            end
            if(initFit)
                apObjs = this.getInitApproxObjs(ch);
                apObj = apObjs{sub2ind([this.initFitParams.gridSize this.initFitParams.gridSize],y,x)};
            else
                apObj = this.getApproxObj(ch,y,x);
            end
            [apObj, xVec, hShift, oset, chi2, chi2Tail, TotalPhotons, iterations, time, slopeStart, iVec] = this.myResult.getVisParams(apObj,ch,y,x,initFit);
        end
        
        function out = getInitApproxObjs(this,ch)
            %make parameter structure needed for approximation of initialization
            if(~this.isInitialized)
                this.init();
            end
            vp = this.volatilePixelParams;
%             params.volatileChannel = this.getVolatileChannelParams(0);
            params.basicFit = this.basicParams;
            params.preProcessing = this.preProcessParams;
            params.computation = this.computationParams;
            params.bounds = this.boundsParams;
            params.pixelFit = this.initFitParams;
            %set optimizerInitStrategy for init fits to 1 (use guess values)
            params.basicFit.optimizerInitStrategy = 1;
            ad = this.myResult.getAuxiliaryData(ch);
            %fix certain parameters to values from initialization
            if(params.basicFit.approximationTarget == 2 && params.basicFit.anisotropyR0Method == 2 && ch < 3)
                idx = strcmp(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)),'Tau 2');
                params.basicFit.(sprintf('constMaskSaveValCh%d',ch)) = double(params.basicFit.(sprintf('constMaskSaveValCh%d',ch)));
                if(~any(idx))
                    if(isempty(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))) || ~iscell(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))))
                        params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)) = cell(0,0);
                    end
                    params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))(end+1,1) = {'Tau 2'};
                    params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(1,end+1) = 0;
                end
            end
            if(any(this.volatilePixelParams.globalFitMask))
                allIRFs = cell(1,ad.fileInfo.nrSpectralChannels);
                for ch = 1:ad.fileInfo.nrSpectralChannels
                    ad = this.myResult.getAuxiliaryData(ch);
                    fileInfo(ch) = ad.fileInfo;
                    allIRFs{ch} = ad.IRF.vector;
                end
                data = zeros(params.pixelFit.gridSize,params.pixelFit.gridSize,fileInfo(ch).nrTimeChannels,fileInfo(ch).nrSpectralChannels,ad.measurementROIInfo.ROIDataType);
                scatterData = zeros(fileInfo(ch).nrTimeChannels,vp.nScatter,fileInfo(ch).nrSpectralChannels,ad.measurementROIInfo.ROIDataType);
                nrPixels = zeros(params.pixelFit.gridSize,params.pixelFit.gridSize);
                for ch = 1:fileInfo(ch).nrSpectralChannels
                    data(:,:,:,ch) = this.myMeasurement.getInitData(ch,params.pixelFit.gridPhotons);
                    if(vp.nScatter > 0)
                        scatterData(:,:,ch) = ad.scatter;
                    end
                end
            else
                fileInfo(ch) = ad.fileInfo;
                allIRFs{ch} = ad.IRF.vector;
                [data,~,~,nrPixels] = this.myMeasurement.getInitData(ch,params.pixelFit.gridPhotons);
                scatterData = ad.scatter;
            end
            %             if(params.pixelFit.gridSize > 1)
            %                 %switch off offset fixation in case of initialization grid
            %                 idx = strcmpi('offset',params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)));
            %                 params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))(idx) = [];
            %             end
            %adjust fixed offset according to number of pixels used
            if(ch < 3 || params.basicFit.approximationTarget == 1)
                idx = strcmp(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)),'Offset');
                if(any(idx))
                    %fixed offset is usually for static binning 2; now scale it with the average number of pixels used for initialization
                    params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(idx(1)) = params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(end) ./ params.pixelFit.gridSize^2 .* mean(nrPixels(:));
                end
            end
            out = cell(params.pixelFit.gridSize^2,1);
            for i = 1:params.pixelFit.gridSize^2
                [r, c] = ind2sub([params.pixelFit.gridSize params.pixelFit.gridSize],i);
                tmp = fluoPixelModel(allIRFs,fileInfo,params,ch);
                assert(r <= size(data,1) && c <= size(data,2),'FLIMX:fluoSubject:getInitApproxObjs','Expected init data to be at least %dx%d - got %dx%dx%dx%d.',r,c,size(data,1),size(data,2),size(data,3),size(data,4));
                tmp.setMeasurementData(squeeze(data(r,c,:,:)));
                if(~isempty(scatterData))
                    tmp.setScatterData(scatterData);
                end
                init = this.getInitFLIMItem(ch,'iVec');
                init = squeeze(init(r,c,:));
                if(sum(init(:)) > 0)
                    tmp.setInitializationData(ch,tmp.getNonConstantXVec(ch,init));
                end
                if(params.basicFit.approximationTarget == 2 && params.basicFit.anisotropyR0Method == 2 && ch < 3)
                    idx = find(strcmp(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)),'Tau 2'),1);
                    if(~isempty(idx) && params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(idx) == 0)
                        %update for tau 2 for anisotropy calculation
                        tmp3 = this.myResult.getInitFLIMItem(3,'TauMean');
                        if(size(tmp3,1) >= r && size(tmp3,2) >= c)
                            val = tmp3(r,c);
                        else
                            val = [];
                        end
                        if(~isempty(val))
                            vcp = tmp.getVolatileChannelParams(ch);
                            idx = find(strcmp('Tau 2',tmp.volatilePixelParams.modelParamsString),1);
                            if(vcp.cMask(idx))
                                tmp2 = cumsum(abs(vcp.cMask));
                                vcp.cVec(tmp2(idx)) = val;
                                tmp.setVolatileChannelParams(ch,vcp);
                            end
                        end
                    end
                end
                out{i} = tmp;
            end
        end
        
        function out = getApproxObjCopy(this,ch)
            %get a copy of the approx. object
            if(~this.isInitialized)
                this.init();
            end
            if(length(this.lastApproxObj) < ch || isempty(this.lastApproxObj{ch}))
                this.lastApproxObj{ch} = this.makeApproxObj(ch);
            end
            out = copy(this.lastApproxObj{ch});
        end
        
        function out = makeApproxObj(this,ch)
            %build an approximation object
            if(~this.isInitialized)
                this.init();
            end
            vp = this.volatilePixelParams;
            params.basicFit = this.basicParams;
            params.preProcessing = this.preProcessParams;
            params.computation = this.computationParams;
            params.bounds = this.boundsParams;
            params.pixelFit = this.pixelFitParams;            
            if(params.basicFit.approximationTarget == 2 && params.basicFit.anisotropyR0Method == 2 && ch < 3)
                idx = strcmp(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)),'Tau 2');
                params.basicFit.(sprintf('constMaskSaveValCh%d',ch)) = double(params.basicFit.(sprintf('constMaskSaveValCh%d',ch)));
                if(~any(idx))
                    if(isempty(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))) || ~iscell(params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))))
                        params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)) = cell(0,0);
                    end
                    params.basicFit.(sprintf('constMaskSaveStrCh%d',ch))(end+1,1) = {'Tau 2'};
                    params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(1,end+1) = 0;
                end
            end
            if(any(vp.globalFitMask))
                allIRFs = cell(1,this.myMeasurement.nrSpectralChannels);
                for chTmp = 1:this.myMeasurement.nrSpectralChannels
                    params.basicFit.(sprintf('constMaskSaveValCh%d',chTmp)) = double(params.basicFit.(sprintf('constMaskSaveValCh%d',chTmp)));
                    for i = 1:length(params.basicFit.fix2InitTargets)
                        sStr = params.basicFit.(sprintf('constMaskSaveStrCh%d',chTmp));
                        idx = find(strcmp(params.basicFit.fix2InitTargets{i},sStr),1);
                        if(isempty(idx))
                            idx = length(sStr)+1;
                        end
                        sStr{idx} = params.basicFit.fix2InitTargets{i};
                        params.basicFit.(sprintf('constMaskSaveStrCh%d',chTmp)) = sStr;
                        params.basicFit.(sprintf('constMaskSaveValCh%d',chTmp))(idx) = 0;
                    end
                    ad = this.myResult.getAuxiliaryData(chTmp);
                    fileInfo(chTmp) = ad.fileInfo;
                    if(strcmp(this.myResult.resultType,'ASCII'))
                        ad.IRF.vector = this.myIRFMgr.getCurIRF(chTmp);
                    end
                    allIRFs{chTmp} = ad.IRF.vector;
                end
                scatterData = zeros(fileInfo(ch).nrTimeChannels,vp.nScatter,fileInfo(ch).nrSpectralChannels,ad.measurementROIInfo.ROIDataType);
                cw = ones(fileInfo(ch).nrTimeChannels,fileInfo(ch).nrSpectralChannels,'single');
                for chTmp = 1:fileInfo(ch).nrSpectralChannels
                    if(vp.nScatter > 0)
                        scatterData(:,:,chTmp) = ad.scatter;
                    end
                    if(params.basicFit.chiWeightingMode == 4)
                        cw(:,chTmp) = single(this.myMeasurement.getROIMerged(chTmp));
                    end
                end
            else
                params.basicFit.(sprintf('constMaskSaveValCh%d',ch)) = double(params.basicFit.(sprintf('constMaskSaveValCh%d',ch)));
                for i = 1:length(params.basicFit.fix2InitTargets)
                    sStr = params.basicFit.(sprintf('constMaskSaveStrCh%d',ch));
                    idx = find(strcmp(params.basicFit.fix2InitTargets{i},sStr),1);
                    if(isempty(idx))
                        idx = length(sStr)+1;
                    end
                    sStr{idx} = params.basicFit.fix2InitTargets{i};
                    params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
                    params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(idx) = 0;
                end
                ad = this.myResult.getAuxiliaryData(ch);
                fileInfo(ch) = ad.fileInfo;
                if(strcmp(this.myResult.resultType,'ASCII'))
                    ad.IRF.vector = this.myIRFMgr.getCurIRF(ch);
                end
                allIRFs{ch} = ad.IRF.vector;
                scatterData = ad.scatter;
                if(params.basicFit.chiWeightingMode == 4)
                    cw = single(this.myMeasurement.getROIMerged(ch));
                end
            end
            out = fluoPixelModel(allIRFs,fileInfo,params,ch);
            %load scatter data into the object
            if(~isempty(scatterData))
                out.setScatterData(scatterData);
            end   
            if(params.basicFit.chiWeightingMode == 4 && ~isempty(cw))                
                out.setChiWeightData(cw);
            end            
        end
                
        function out = getApproxObj(this,ch,y,x)
            %make parameter structure needed for approximation
            if(~this.isInitialized)
                this.init();
            end
            out = this.getApproxObjCopy(ch);
            %fix certain paramters to initialization values
            bp = out.basicParams;
            if(~isempty(bp.fix2InitTargets))                
                if(any(out.volatilePixelParams.globalFitMask))
                    for chTmp = 1:out.nrChannels                        
                        bp.(sprintf('constMaskSaveValCh%d',chTmp)) = double(bp.(sprintf('constMaskSaveValCh%d',chTmp)));
                        vcp = out.getVolatileChannelParams(chTmp);
                        vcp = this.updateFixedTargets(chTmp,y,x,bp,vcp,out.volatilePixelParams.modelParamsString);
                        out.setVolatileChannelParams(chTmp,vcp);
                    end
                else
                    bp.(sprintf('constMaskSaveValCh%d',ch)) = double(bp.(sprintf('constMaskSaveValCh%d',ch)));
                    vcp = out.getVolatileChannelParams(ch);
                    vcp = this.updateFixedTargets(ch,y,x,bp,vcp,out.volatilePixelParams.modelParamsString);
                    out.setVolatileChannelParams(ch,vcp);
                    %bp.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
                    %out.basicParams = bp;
                end
            end
            if(bp.approximationTarget == 2 && bp.anisotropyR0Method == 2 && ch < 3)
                idx = find(strcmp(bp.(sprintf('constMaskSaveStrCh%d',ch)),'Tau 2'),1);
                if(~isempty(idx) && bp.(sprintf('constMaskSaveValCh%d',ch))(idx) == 0)
                    %update for tau 2 for anisotropy calculation
                    val = this.myResult.getPixelFLIMItem(3,'TauMean',y,x);
                    if(~isempty(val))
                        bp.(sprintf('constMaskSaveValCh%d',ch))(idx) = val;
                        vcp = out.getVolatileChannelParams(ch);
                        idx = find(strcmp('Tau 2',out.volatilePixelParams.modelParamsString),1);
                        if(vcp.cMask(idx))
                            tmp = cumsum(abs(vcp.cMask));
                            vcp.cVec(tmp(idx)) = val;
                            out.setVolatileChannelParams(ch,vcp);
                        end
                    end
                end
            end
            %get data
            if(any(out.volatilePixelParams.globalFitMask))
                data = zeros(out.fileInfo(ch).nrTimeChannels,out.fileInfo(ch).nrSpectralChannels,this.myMeasurement.getROIInfo(ch).ROIDataType);
                for chTmp = 1:out.fileInfo(ch).nrSpectralChannels
                    data(:,chTmp) = this.myMeasurement.getROIData(chTmp,y,x);
                end
            else
                data = this.myMeasurement.getROIData(ch,y,x);
            end            
            %load measurement data into the object
            if(~isempty(data))
                out.setMeasurementData(data);
            end            
            %load neighbors
            if(out.basicParams.neighborFit)
                if(any(out.volatilePixelParams.globalFitMask))
                    nbs = this.myMeasurement.getNeigborData(1:fileInfo(ch).nrSpectralChannels,y,x,out.basicParams.neighborFit);
                else
                    nbs = this.myMeasurement.getNeigborData(ch,y,x,out.basicParams.neighborFit);
                end
                out.setNeighborData(nbs);
            end
            %load init data into the object
            if(~strcmp(this.myResult.resultType,'ASCII') && (out.basicParams.optimizerInitStrategy == 2 || ~isempty(out.basicParams.fix2InitTargets)))                
                if(any(out.volatilePixelParams.globalFitMask))
                    for chTmp = 1:out.fileInfo(ch).nrSpectralChannels
                        %out.setInitializationData(chTmp,out.getNonConstantXVec(chTmp,this.getPixelFLIMItem(chTmp,'iVec',y,x)));
                        xVec = this.getPixelFLIMItem(chTmp,'iVec',y,x);
                        if(isempty(xVec))
                        xVec = zeros(size(this.volatilePixelParams.globalFitMask));
                    end
                        %make sure taus have the right distance, exclude stretched exponentials
                        mask = find(~bp.stretchedExpMask)+bp.nExp;
                        for i = 1:length(mask)-1 %bp.nExp+1 : 2*bp.nExp-1
                            %idxIgnored(xVecCheck(mask(i),:).*bp.lifetimeGap > xVecCheck(mask(i+1),:)) = true;
                            d = xVec(mask(i+1),:) - xVec(mask(i),:).*bp.lifetimeGap;
                            if(d < 0)
                                xVec(mask(i+1),:) = xVec(mask(i+1),:) - d + eps;
                            end
                        end
                        %ensure tci ordering
                        for i = 2*bp.nExp+1 : 2*bp.nExp+sum(bp.tciMask ~= 0)-1
                            %idxIgnored(xVecCheck(i,:) > xVecCheck(i+1,:)) = true;
                            d = xVec(i+1,:) - xVec(i,:);
                            if(d < 0)
                                xVec(i+1,:) = xVec(i+1,:) - d + eps;
                            end
                        end
                        out.setInitializationData(chTmp,out.getNonConstantXVec(chTmp,xVec));
                    end
                else
%                     init = this.getPixelFLIMItem(ch,'x_vec',y,x); %use previous result if there is any
%                     if(isempty(init) || ~any(init(:)))
%                         init = this.getPixelFLIMItem(ch,'iVec',y,x);
%                     end
                    %out.setInitializationData(ch,out.getNonConstantXVec(ch,this.getPixelFLIMItem(ch,'iVec',y,x)));
                    xVec = this.getPixelFLIMItem(ch,'iVec',y,x);
                    if(isempty(xVec))
                        xVec = zeros(this.volatilePixelParams.nModelParamsPerCh,1);
                    end
                    %make sure taus have the right distance, exclude stretched exponentials
                    mask = find(~bp.stretchedExpMask)+bp.nExp;
                    for i = 1:length(mask)-1 %bp.nExp+1 : 2*bp.nExp-1
                        %idxIgnored(xVecCheck(mask(i),:).*bp.lifetimeGap > xVecCheck(mask(i+1),:)) = true;
                        d = xVec(mask(i+1),:) - xVec(mask(i),:).*bp.lifetimeGap;
                        if(d < 0)
                            xVec(mask(i+1),:) = xVec(mask(i+1),:) - d + eps;
                        end
                    end
                    %ensure tci ordering
                    for i = 2*bp.nExp+1 : 2*bp.nExp+sum(bp.tciMask ~= 0)-1
                        %idxIgnored(xVecCheck(i,:) > xVecCheck(i+1,:)) = true;
                        d = xVec(i+1,:) - xVec(i,:);
                        if(d < 0)
                            xVec(i+1,:) = xVec(i+1,:) - d + eps;
                        end
                    end
                    if(~isempty(xVec))
                        out.setInitializationData(ch,out.getNonConstantXVec(ch,xVec));
                    end
                end
            end
        end
        
        
        %% output parameters
        function out = get.aboutInfo(this)
            %get version info of me
            if(~this.isInitialized)
                this.init();
            end
            out = this.myResult.aboutInfo;
        end
        
        function out = get.computationParams(this)
            %get computation parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('computation');
        end
        
        function set.computationParams(this,val)
            %set computation parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('computation',val);
        end
                
        function set.folderParams(this,val)
            %set folder parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('folders',val);
        end
        
        function out = get.preProcessParams(this)
            %get pre processing parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('pre_processing');
        end
        
        function set.preProcessParams(this,val)
            %set pre processing parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('pre_processing',val);
            this.clearCachedApproxObj();
        end
        
        function out = get.basicParams(this)
            %get basic fit parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('basic_fit');
        end
        
        function set.basicParams(this,val)
            %set basic fit parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('basic_fit',val,this.initMode);
            this.clearCachedApproxObj();
            %this.myParamMgr.makeVolatileParams();
        end
        
        function out = get.initFitParams(this)
            %get init fit parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('init_fit');
        end
        
        function set.initFitParams(this,val)
            %set init fit parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('init_fit',val);
        end
        
        function out = get.pixelFitParams(this)
            %get per pixel fit parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('pixel_fit');
        end
        
        function set.pixelFitParams(this,val)
            %set per pixel fit parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('pixel_fit',val);            
            this.clearCachedApproxObj();
        end
        
        function out = get.boundsParams(this)
            %get bounds
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('bounds');
        end
        
        function set.boundsParams(this,val)
            %set bounds
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('bounds',val);
            this.clearCachedApproxObj();
        end
        
        function out = get.optimizationParams(this)
            %get optimizer parameters
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('optimization');
        end        
        
        function set.optimizationParams(this,val)
            %set optimizer parameters
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('optimization',val);
        end
        
        function out = get.volatilePixelParams(this)
            %get volatile fit parameters for all pixels
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getParamSection('volatilePixel');
        end        
        
        function set.volatilePixelParams(this,val)
            %set volatile fit parameters for all pixels
            if(~this.isInitialized)
                this.init();
            end
            this.myParamMgr.setParamSection('volatilePixel',val);
        end
        
        function out = getVolatileChannelParams(this,ch)
            %get volatile fit parameters for specific channel (ch = empty returns cell with all channels)
            if(~this.isInitialized)
                this.init();
            end
            out = this.myParamMgr.getVolatileChannelParams(ch);
        end        
        
        function out = get.myIRFMgr(this)
            %return irf manager
            out = this.getMyIRFMgr();
        end
        
        %% compute methods
        function updateProgress(this,prog,text)
            %update progress bar for all handles we've got
            for i = length(this.progressCb):-1:1
                try
                    this.progressCb{i}(prog,text);
                catch
                    this.progressCb{i} = [];
                end
            end
        end
        
        function updateSubjectChannel(this,ch,flag)
            %update a specific channel of a subject, flag signalizes 'measurement', 'result' or '' for both
%             if(~this.isInitialized)
%                 this.init();
%             end
            subjectID = this.name;
            %todo: remove old files
            this.myParent.removeResultChannelFromMemory(subjectID,ch); %this is only defined in FDTSubject!!
            %save mat files for measurements and results
            if(strcmp(flag,'result'))
                %save only result, we can assume we already have the measurement
                %todo: make interface
                this.myResult.saveMatFile2Disk(ch);
                this.myParent.myStudyInfoSet.setAllFLIMItems(subjectID,ch,removeNonVisItems(this.getResultNames(ch,false),3));
            elseif(strcmp(flag,'measurement'))
                %todo: make interface
                this.myMeasurement.saveMatFile2Disk(ch);
                %old results are now invalid -> delete them
                this.myParent.deleteChannel(subjectID,ch,'result');
            else
                this.saveMatFile2Disk(ch);
            end
            %this.myParent.checkSubjectFiles(subjectID);
            
%             this.checkIRFInfo(ch);
%             %add empty channel
%             this.addObj(subjectID,ch,[],[],[]);
%             subject.loadChannelResult(ch);
%             subject.loadChannelMeasurement(ch);
        end
        
    end
    
    methods(Access = protected)
        function setPosition(this,val)
            %set position
            if(ischar(val))
                this.myMeasurement.position = val;
                this.myResult.setPosition(val);
            end
        end
        
        function setPixelResolution(this,val)
            %set pixel resolution
            if(isnumeric(val) && val > 0)
                this.myMeasurement.pixelResolution = val;
                this.myResult.setPixelResolution(val);
            end
        end
        
        function out = getParentParamMgr(this)
            %return parameter manager from study (parent)
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        function out = getMyIRFMgr(this)
            %helper method for get.myIRFMgr() to allow overloading
            if(isempty(this.myParent))
                out = [];
            else
                out = this.myParent.getIRFMgr();
            end
        end
        
        function vcp = updateFixedTargets(this,ch,y,x,bp,vcp,modelParamsString)
            %update fixed parameters to their current values
            for i = 1:length(bp.fix2InitTargets)
                sStr = bp.(sprintf('constMaskSaveStrCh%d',ch));
                idx = find(strcmp(bp.fix2InitTargets{i},sStr),1);
                if(isempty(idx))
                    idx = length(sStr)+1;
                    sStr{idx} = bp.fix2InitTargets{i};
                end
                [dTypeStr, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(sStr{idx});
                if(dTypeNr == 0)
                    dTypeNrStr = '';
                else
                    dTypeNrStr = num2str(dTypeNr);
                end
                val = this.myResult.getPixelFLIMItem(ch,sprintf('%sInit%s',dTypeStr{1},dTypeNrStr),y,x);
                if(isempty(val))
                    %value not found in result
                    val = 0;
                end
                %update constant vector
                idx = find(strcmp(bp.fix2InitTargets{i},modelParamsString),1);
                if(~isempty(idx) && vcp.cMask(idx))
                    tmp = cumsum(abs(vcp.cMask));
                    vcp.cVec(tmp(idx)) = val;
                end
            end
        end
    end
    
    methods(Static)
        
    end
    
end