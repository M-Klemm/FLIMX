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
        filesOnHDD = false(1,0);
        myFiles = cell(0,0);
        roiInfoLoaded = false;
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = measurementInFDTree(hPM,myFolder)
            %constructor
            this = this@measurementFile(hPM);
            this.myFolder = myFolder;
            this.checkMyFiles();
            if(any(this.filesOnHDD))
                %load file info of an available channel
                this.getFileInfoStruct([]);
                %this.loadROIInfo(this.nonEmptyChannelList(1));
            end
        end
        
        %% input methods
        function checkMyFiles(this)
            %check my folder for measurement files
            if(isempty(this.getMyFolder()))
                return
            end
            files = rdir(fullfile(this.getMyFolder(),'*.mat'));
            for i = 1:length(files)
                [~,fileName] = fileparts(files(i,1).name);                
                if(strncmpi(fileName,this.fileStub,12) && length(fileName) == 16)
                    chIdx = str2double(fileName(15:16));
                    if(~isempty(chIdx))
                        this.filesOnHDD(1,chIdx) = true;                        
                    end
                end
            end
            this.myFiles = cell(1,length(this.filesOnHDD));
        end
        
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
             if(~exist(fn,'file'))
                 return
             end
             try
                 this.myFiles{1,ch} = matfile(fn,'Writable',false);
             catch ME
                 %todo: error handling
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
                 auxInfo.revision = FLIMX.getVersionInfo().measurement_revision;
                 %overwrite old file
                 save(fn,'rawData', 'fluoFileInfo', 'auxInfo', 'ROIInfo','-v7.3');
                 success = this.openChannel(ch);
                 return
             end
             if(~all(ismember(who(this.myFiles{1,ch}),{'rawData', 'fluoFileInfo', 'auxInfo', 'ROIInfo'})))
                 %something went wrong
                 this.myFiles(1,ch) = cell(1,1);
                 return
             end
             %check revision
             success = true;
        end
        
        function success = loadRawData(this,ch)
            %load raw data for current measurement
            success = false;
            if(this.openChannel(ch))
                fi = this.myFiles{1,ch}.fluoFileInfo;
                %just a security check before we load the data
                if(fi.channel == ch)
                    this.setRawData(ch,this.myFiles{1,ch}.rawData);
                    this.setDirtyFlags(ch,1,false);
                    if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch))
                        this.loadROIInfo(ch);
                        this.setDirtyFlags(ch,4,false);
                    end
                    success = true;
                end
            end            
        end
        
        function success = loadFileInfo(this,ch)
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
                ri = this.myFiles{1,ch}.ROIInfo;
                this.setROIDataType(ri.ROIDataType);
                this.setROICoord(ri.ROICoordinates);
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
        
        function fileInfo = getFileInfoStruct(this,ch)
            %get file info struct
            if(~this.fileInfoLoaded || (~isempty(ch) && any(ch == this.nonEmptyChannelList) && length(this.myFiles) <= ch && isempty(this.myFiles{1,ch})))
                if(isempty(ch))
                    ch = this.nonEmptyChannelList(1);
                end
                this.loadFileInfo(ch);
            end
            fileInfo = getFileInfoStruct@measurementFile(this,ch);
        end
        
        function out = getROIInfo(this,ch)
            %get info about ROI
            if(length(this.roiInfoLoaded) < ch || ~this.roiInfoLoaded(ch) || (~isempty(ch) && any(ch == this.nonEmptyChannelList) && length(this.myFiles) <= ch && isempty(this.myFiles{1,ch})))
                if(isempty(ch))
                    ch = this.nonEmptyChannelList(1);
                end
                this.loadROIInfo(ch);
            end
            out = getROIInfo@measurementFile(this,ch);
            
        end
        
        function raw = getRawData(this,ch)
            %get raw data for channel
            raw = [];
            if(this.paramMgrObj.basicParams.approximationTarget == 2 && ch > 2)
                return
            end
            if(any(this.nonEmptyChannelList == ch))
                if(~any(this.loadedChannelList == ch))
                    %we have to load it from disk first
                    if(this.loadRawData(ch))
%                         if(~this.fileInfoLoaded)
%                             this.fileInfoLoaded = true;
%                         end
                        raw = this.rawFluoData{ch};
                    end
                else
                    raw = this.rawFluoData{ch};
                end                
            end
        end  
        
        function out = getMyFolder(this)
            %return current working folder
            if(ischar(this.myFolder))
                out = this.myFolder;
            else
                out = feval(this.myFolder);
            end
        end
        
        function out = getNonEmptyChannelList(this)
            %return a list of channel numbers "with data"
            out = find(this.filesOnHDD);
        end
        
        function out = getLoadedChannelList(this)
            %return a list of channels in memory
            if(isempty(this.rawFluoData))
                out = false(size(this.nonEmptyChannelList));
            else
                out = fastIntersect(this.nonEmptyChannelList,find(~cellfun('isempty',this.rawFluoData)));
            end
        end
    end %methods
end %classdef