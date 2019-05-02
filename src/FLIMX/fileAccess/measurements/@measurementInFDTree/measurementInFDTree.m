classdef measurementInFDTree < measurementFile
    %=============================================================================================================
    %
    % @file     measurementInFDtree.m
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
    % @brief    A class to represent the measurementInFDTree class
    %
    properties(GetAccess = public, SetAccess = private)
        myFolder = '';
        roiInfoLoaded = false;
        roiMergedMask = [];
        uid = 0;
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = measurementInFDTree(hPM,myFolder)
            %constructor
            this = this@measurementFile(hPM);
            this.myFolder = myFolder;
            try
                this.uid = datenummx(clock);  %fast
            catch
                this.uid = now;  %slower
            end
            this.checkMyFiles();            
        end
        
        function delete(this)
            %destructor
            if(~isempty(this.myParent))
                %remove me from FDTree memory cache
                this.rawFluoData = [];
                this.roiFluoData = [];
                this.myParent.pingLRUCacheTable(this);
            end
        end
        
%         function flag = eq(obj1,obj2)
%             %compare two result objects
%             if(abs(obj1.uid - obj2.uid) < eps('double'))
%                 flag = true;
%             else
%                 flag = false;
%             end
%         end
        
        function deleteChannel(this,ch)
            %delete channel from memory and disk
            deleteChannel@measurementFile(this,ch);
            this.filesOnHDD(1,ch) = false;
            this.myFiles{1,ch} = [];
            fn = this.getMeasurementFileName(ch,'');
            try
                delete(fn);
            catch ME
                %todo
            end            
        end
        
        %% input methods
        function success = openChannel(this,ch)
            %load measurement data from mat file
            success = false;
            if(isempty(ch))
                return
            end
            if(length(this.myFiles) < ch)
                this.checkMyFiles();
                if(length(this.myFiles) < ch)
                    %didn't help
                    return
                end
            end
            if(~isempty(this.myFiles{1,ch}))
                %nothing to do
                success = true;
                return
            end
            %create matfile object
            fn = this.getMeasurementFileName(ch,[]);
            if(~isfile(fn))
                return
            end
            try
                this.myFiles{1,ch} = matfile(fn,'Writable',false);
            catch ME
                %todo: error handling
                warning('Could not open measurement file: %s\n%s',fn,ME.message);
                return
            end
            if(any(strcmp(who(this.myFiles{1,ch}),'measurement')))
                %this is a pre-version 203 file
                measurement = this.myFiles{1,ch}.measurement;
                %check revision
                if(measurement.revision < 201)
                    measurement.fluoFileInfo.ROIDataType = 'uint16';
                    measurement.fluoFileInfo.channel = measurement.channel;
                    measurement.fluoFileInfo.StartPosition = this.getStartPosition(measurement.fluoFileInfo.channel);
                    measurement.fluoFileInfo.EndPosition = this.getEndPosition(measurement.fluoFileInfo.channel);
                    measurement.fluoFileInfo.reflectionMask = this.getReflectionMask(measurement.fluoFileInfo.channel);
                    [measurement.fluoFileInfo.rawYSz, measurement.fluoFileInfo.rawXSz, z] = size(measurement.rawData);
                    measurement.fluoFileInfo.ROICoordinates = [];
                end
                if(measurement.revision < 202)
                    measurement.fluoFileInfo.position = 'OS';
                    measurement.fluoFileInfo.pixelResolution = 58.66666666666; %just some default value
                end
                %convert to new format of version 203
                rawData = measurement.rawData;
                fluoFileInfo = measurement.fluoFileInfo;
                ROIInfo = this.getDefaultROIInfo();
                ROIInfo.ROICoordinates = fluoFileInfo.ROICoordinates;
                ROIInfo.ROIDataType = fluoFileInfo.ROIDataType;
                fluoFileInfo = rmfield(fluoFileInfo,{'ROIDataType','ROICoordinates'});
                auxInfo.sourceFile = measurement.sourceFile;
                auxInfo.revision = 204;
                %overwrite old file
                %close open file first?
                this.myFiles{1,ch} = [];
                save(fn,'rawData', 'fluoFileInfo', 'auxInfo', 'ROIInfo','-v7.3');
                success = this.openChannel(ch);
                return
            end
            auxInfo = this.myFiles{1,ch}.auxInfo;
            if(auxInfo.revision < 205)
                %save some addition raw data info
                %make intensity images (rawDataFlat) and store them in the measurement file
                try
                    %the whole update procedure in one try block to make
                    %sure it either works completely or not at all
                    this.updateMatfile(this.myFiles{1,ch},205);
                catch ME
                    %todo: error handling
                    warning('Updating measurement file failed: %s\n%s',fn,ME.message);
                end
            end
            if(sum(ismember(who(this.myFiles{1,ch}),{'rawData', 'fluoFileInfo', 'auxInfo', 'ROIInfo'})) < 4)
                %something went wrong
                this.myFiles(1,ch) = cell(1,1);
                return
            end
            %check revision
            success = true;
        end
        
        function success = loadFileInfo(this)
            %load file info for all measurement channels
            success = false;
            for ch = 1:length(this.filesOnHDD)
                if(this.filesOnHDD(ch) && this.openChannel(ch))
                    this.setFileInfoStruct(this.myFiles{1,ch}.fluoFileInfo);
                    this.setDirtyFlags(ch,2,false);
                    success = true;
                end
            end
        end
        
        function success = loadROIInfo(this,ch)
            %load ROI info for current measurement
            success = false;
            if(this.openChannel(ch))
                %loading the ROI will clear some of the file info
                oldFI = this.fileInfo;
                ri = this.myFiles{1,ch}.ROIInfo;
                this.setROIDataType(ri.ROIDataType);
                this.setROICoord(ri.ROICoordinates);
                %write file info back so it doesn't have to be recomputed (it is valid as it was stored together on the hdd)
                this.fileInfo.reflectionMask = oldFI.reflectionMask;
                this.fileInfo.StartPosition = oldFI.StartPosition;
                this.fileInfo.EndPosition = oldFI.EndPosition;
                if(this.roiAdaptiveBinEnable && ~isempty(ri.ROIAdaptiveBinThreshold) && ri.ROIAdaptiveBinThreshold == this.roiAdaptiveBinThreshold && isfield(ri,'ROISupport'))
                    if(isfield(ri.ROISupport,'roiFluoDataFlat'))
                        this.roiFluoDataFlat{ch} = ri.ROISupport.roiFluoDataFlat;
                    end
                    if(isfield(ri.ROISupport,'roiAdaptiveBinLevels'))
                        this.roiBinLevels{ch} = ri.ROISupport.roiAdaptiveBinLevels;
                    end
                end
                if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch))
                    
                end
                this.setDirtyFlags(ch,2,false);
                this.roiInfoLoaded(ch) = true;
                success = true;
            end
        end
        
        function success = loadAuxInfo(this,ch)
            %load auxilliary info for current measurement
            success = false;
            if(this.openChannel(ch))
                this.sourceFile = this.myFiles{1,ch}.auxInfo.sourceFile;
                this.setDirtyFlags(ch,3,false);
                success = true;
            end
        end
        
        %% output methods
        function out = getCacheMemorySize(this)
            %get the size in bytes of the data that can be re-read from disk
            raw = this.rawFluoData;
            wRaw = whos('raw');
            roi = this.roiFluoData;
            wRoi = whos('roi');
            out = wRaw.bytes + wRoi.bytes;
        end
        
        function fileInfo = getFileInfoStruct(this,ch)
            %get file info struct
            if(~this.fileInfoLoaded)
                this.init();
            end
            if(~this.fileInfoLoaded)% || (~isempty(ch) && any(ch == this.nonEmptyChannelList) && length(this.myFiles) <= ch && isempty(this.myFiles{1,ch})))
                if(isempty(ch))
                    ch = this.nonEmptyChannelList(1);
                end
                this.loadFileInfo();
            end
            fileInfo = getFileInfoStruct@measurementFile(this,ch);
        end
        
        function out = getROIInfo(this,ch)            
            %get info about ROI
            if(~this.fileInfoLoaded)
                this.init();
            end
            if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch) || (~isempty(ch) && any(ch == this.nonEmptyChannelList) && length(this.myFiles) <= ch && isempty(this.myFiles{1,ch})))
                if(isempty(ch))
                    ch = this.nonEmptyChannelList(1);
                end
                this.loadROIInfo(ch);
            end
            out = getROIInfo@measurementFile(this,ch);
            
        end
        
        function out = getRawDataFlat(this,ch)
            %get intensity image of (raw) measurement data
            if(~this.fileInfoLoaded)
                this.init();
            end
            out = getRawDataFlat@measurementFile(this,ch);
        end
        
        function raw = getRawData(this,ch,useMaskFlag)
            %get raw data for channel
            if(~this.fileInfoLoaded)
                this.init();
            end
            if(nargin < 3)
                useMaskFlag = true;
            end
            raw = [];
%             if(this.paramMgrObj.basicParams.approximationTarget == 2 && ch > 2)
%                 return
%             end
            if(any(this.nonEmptyChannelList == ch))
                if(~any(this.loadedChannelList == ch))
                    %we have to load it from disk first
                    if(this.loadRawData(ch))
                        %                         if(~this.fileInfoLoaded)
                        %                             this.fileInfoLoaded = true;
                        %                         end
                        if(any(this.loadedChannelList == ch))
                            raw = getRawData@measurementFile(this,ch,useMaskFlag);
                        end
                    end
                else
                    raw = getRawData@measurementFile(this,ch,useMaskFlag);
                end
            elseif(this.paramMgrObj.basicParams.approximationTarget == 2 && ch > 2)
                raw = getRawData@measurementFile(this,ch,useMaskFlag);
            end
            if(~isempty(this.myParent))
                this.myParent.pingLRUCacheTable(this);
            end
        end
        
        function out = getWorkingDirectory(this)
            %return current working folder
            if(ischar(this.myFolder))
                out = this.myFolder;
            elseif(isa(this.myFolder, 'function_handle'))
                out = feval(this.myFolder);
            else
                out = '';
            end
        end
        
        function out = getMyParamMgr(this)
            %return current parameter manager
            if(ischar(this.myParamMgr))
                out = this.myParamMgr;
            else
                out = feval(this.myParamMgr);
            end
        end
        
        function out = getNonEmptyChannelList(this)
            %return a list of channel numbers "with data"
            nec1 = getNonEmptyChannelList@measurementFile(this);
            nec2 = find(this.filesOnHDD);
            out = unique([nec1(:);nec2(:)]);
        end
        
        function out = getLoadedChannelList(this)
            %return a list of channels in memory
            if(~this.fileInfoLoaded) %need this here?
                this.init();
            end
            if(isempty(this.rawFluoData))
                out = false(size(this.nonEmptyChannelList));
            else
                out = fastIntersect(this.nonEmptyChannelList,find(~cellfun('isempty',this.rawFluoData)));
            end
        end
        
        function out = getROIMerged(this,channel)
            %get the ROI merged to a single decay
            if(~this.fileInfoLoaded)
                this.init();
            end
            bp = this.paramMgrObj.basicParams;
            if(bp.approximationTarget == 2)
                if(length(this.roiMerged) < channel || isempty(this.roiMerged{channel}))
                    %merge raw ROI to single decay
                    raw = this.getRawData(channel);
                    if(isvector(raw))
                        this.roiMerged(channel) = {raw};
                    elseif(~isempty(raw) && ndims(raw) == 3)
                        raw = raw(this.ROICoordinates(3):this.ROICoordinates(4),this.ROICoordinates(1):this.ROICoordinates(2),:);
                        rawFlat = sum(raw,3);
                        mv = max(rawFlat(:));
                        if(isempty(this.roiMergedMask))
                            mask = rawFlat >= mv/10;
                            this.roiMergedMask = mask;
                        else
                            mask = this.roiMergedMask;
                        end
                        raw = reshape(raw,[size(raw,1)*size(raw,2),size(raw,3)]);
                        this.roiMerged(channel) = {sum(raw(mask(:),:),1)'};
                        %this.roiMerged(channel) = {sum(reshape(raw(this.ROICoordinates(3):this.ROICoordinates(4),this.ROICoordinates(1):this.ROICoordinates(2),:),[],size(raw,3)),1)'};
                    end
                end
                if(length(this.roiMerged) < channel || isempty(this.roiMerged{channel}))
                    %still no data available
                    out = [];
                else
                    out = this.roiMerged{channel};
                end
            else
                out = getROIMerged@measurementFile(this,channel);
            end
        end
        
        function clearROIData(this)
            %clear everything except for the measurement data
            if(~this.fileInfoLoaded)
                this.init();
            end
            this.roiMergedMask = [];
            clearROIData@measurementFile(this);
        end
        
        function clearCacheMemory(this)
            %remove raw and roi data from RAM as this can be read from disk and recomputed
            if(this.isDirty)
                this.saveMatFile2Disk([]);
            end
            this.rawFluoData = cell(0,0);
            this.roiFluoData = cell(0,0);
            %fprintf('cleared cache of %s measurement\n',this.myParent.name);
        end
    end %methods
    
    methods (Access = protected)
        function init(this)
            %initialize object with data from disk (file info, ROA info, aux info, cached data)
            if(any(this.filesOnHDD))
                %load file info of an available channel
                this.initMode = true;
                %this.getFileInfoStruct([]);
                chList = this.nonEmptyChannelList();                
                %this.loadROIInfo(this.nonEmptyChannelList(1));
                for i = 1:length(chList)
                    ch = chList(i);
                    %load ROA info
                    if(this.filesOnHDD(ch) && this.openChannel(ch))
                        %load intensity image
                        if(~any(ismember(who(this.myFiles{1,ch}),{'rawDataFlat'})))
                            %try to update the file again
                            this.updateMatfile(this.myFiles{1,ch},205);
                        end
                        this.rawFluoDataFlat{ch,1} = this.myFiles{1,ch}.rawDataFlat;
                        this.rawMaskData{ch,1} = this.myFiles{1,ch}.rawMaskData;
                        %load file info
                        this.setFileInfoStruct(this.myFiles{1,ch}.fluoFileInfo);
                        %load the ROA
                        ri = this.myFiles{1,ch}.ROIInfo;
                        this.ROIDataType = ri.ROIDataType;
                        %this.setROICoord(ri.ROICoordinates);
                        coord = ri.ROICoordinates;
                        if(~isempty(this.rawXSz))
                            coord(2) = min(coord(2),this.rawXSz);
                        end
                        if(~isempty(this.rawYSz))
                            coord(4) = min(coord(4),this.rawYSz);
                        end
                        this.ROICoord = coord(:);
                        if(this.roiAdaptiveBinEnable && ~isempty(ri.ROIAdaptiveBinThreshold) && ri.ROIAdaptiveBinThreshold == this.roiAdaptiveBinThreshold && isfield(ri,'ROISupport'))
                            if(isfield(ri.ROISupport,'roiFluoDataFlat'))
                                this.roiFluoDataFlat{ch} = ri.ROISupport.roiFluoDataFlat;
                            end
                            if(isfield(ri.ROISupport,'roiAdaptiveBinLevels'))
                                this.roiBinLevels{ch} = ri.ROISupport.roiAdaptiveBinLevels;
                            end
                        end
                        this.roiMerged{ch} = ri.ROIMerged;
                        if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch))
                            
                        end
                        this.roiInfoLoaded(ch) = true;
                    end
                end
                %load aux info
                ai = this.myFiles{1,ch}.auxInfo;
                this.sourceFile = ai.sourceFile;
%                 %load the fileinfo for all channels
%                 for i = 2:length(chList)
%                     ch = chList(i);
%                     if(this.filesOnHDD(ch) && this.openChannel(ch))
%                         this.setFileInfoStruct(this.myFiles{1,ch}.fluoFileInfo);
%                     end
%                 end                
            end
            this.initMode = false;
        end
        
        function success = loadRawData(this,ch)
            %load raw data for current measurement            
            success = false;
            if(this.openChannel(ch))
                fi = this.myFiles{1,ch}.fluoFileInfo;
                if(isempty(fi))
                    %file load did not work correctly
                    return
                end
                %just a security check before we load the data
                if(fi.channel == ch)
                    content = whos(this.myFiles{1,ch});
                    if(any(strcmp('rawData',{content.name})))
                        this.setRawData(ch,this.myFiles{1,ch}.rawData);
                        this.setDirtyFlags(ch,1,false);
                        if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch))
                            this.loadROIInfo(ch);
                            this.setDirtyFlags(ch,4,false);
                        end
                        success = true;
                        if(any(strcmp('rawMaskData',{content.name})))
                            this.setRawMaskData(ch,this.myFiles{1,ch}.rawMaskData);
                            this.setDirtyFlags(ch,1,false);
                        end
                    end                    
                end
            end
        end
        
        function setPosition(this,val)
            %set position
            for i = 1:length(this.nonEmptyChannelList)
                %load fileinfo of all channels
                this.getFileInfoStruct(this.nonEmptyChannelList(i));
            end
            this.fileInfo.position = val;
            if(~isempty(this.filesOnHDD))
                this.setDirtyFlags([],2,true);
            end
        end
        
        function setPixelResolution(this,val)
            %set pixel resolution
            for i = 1:length(this.nonEmptyChannelList)
                %load fileinfo of all channels
                this.getFileInfoStruct(this.nonEmptyChannelList(i));
            end
            this.fileInfo.pixelResolution = val;
            if(~isempty(this.filesOnHDD))
                this.setDirtyFlags([],2,true);
            end
        end
        
        function updateMatfile(this,hMatFile,rev)
            %update matfile
            if(rev == 205)
                rawData = hMatFile.rawData;
                ROIInfo = hMatFile.ROIInfo;
                if(isempty(rawData))
                    rawDataFlat = [];
                    ROIInfo.ROIMerged = [];
                else
                    rawDataFlat = int32(sum(rawData,3));
                    if(~isempty(ROIInfo.ROICoordinates))
                        ROIInfo.ROIMerged = sum(reshape(rawData(ROIInfo.ROICoordinates(3):ROIInfo.ROICoordinates(4),ROIInfo.ROICoordinates(1):ROIInfo.ROICoordinates(2),:),[],size(rawData,3)),1)';
                    else
                        ROIInfo.ROIMerged = squeeze(sum(rawData,1:2));
                    end
                end
                auxInfo.revision = rev;
                if(~isfield(auxInfo,'sourceFile'))
                    auxInfo.sourceFile = '';
                end
                %enable write access
                hMatFile.Properties.Writable = true;
                hMatFile.rawDataFlat = rawDataFlat;
                if(~any(ismember(who(hMatFile),{'rawMaskData'})))
                    %make sure there is always a rawDatMask field
                    hMatFile.rawMaskData = [];
                end
                hMatFile.ROIInfo = ROIInfo;
                hMatFile.auxInfo = auxInfo;
            end
        end    
    end
end %classdef