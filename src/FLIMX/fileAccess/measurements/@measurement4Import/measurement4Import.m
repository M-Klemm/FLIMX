classdef measurement4Import < measurementInFDTree & measurementReadRawData
    %=============================================================================================================
    %
    % @file     measurement4Import.m
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
    % @brief    A class to represent the measurement4Import class
    %
    properties(GetAccess = public, SetAccess = private)
        
    end
    
    properties (Dependent = true)
        
    end
    
    methods
        function this = measurement4Import(hSubject)
            %constructor
            this = this@measurementReadRawData(hSubject.myParamMgr);
            this = this@measurementInFDTree(hSubject.myParamMgr,@hSubject.getMyFolder);
            this.dirtyFlags = true(size(this.dirtyFlags));
        end
        %% input methods
        function importMeasurementObj(this,obj)
            %import a measurement object copying its content
            %copy all properties
            this.progressCb = obj.progressCb;
            this.sourceFile = obj.sourceFile;
            this.sourcePath = obj.sourcePath;
            this.ROICoord = obj.ROICoord;
            this.rawXSz = obj.rawXSz;
            this.rawYSz = obj.rawYSz;
            this.fileInfo = obj.fileInfo;            
            this.fileInfoLoaded = obj.fileInfoLoaded;
            this.rawFluoData = obj.rawFluoData;
            this.roiFluoData = obj.roiFluoData;
            this.rawFluoDataFlat = obj.rawFluoDataFlat;
            this.roiFluoData = obj.roiFluoData;
            this.roiFluoDataFlat = obj.roiFluoDataFlat;
            this.roiMerged = obj.roiMerged;  
            this.initData = obj.initData;
            this.setDirtyFlags([],1:4,true);
        end
        
        function fileInfo = getFileInfoStruct(this,channel)
            %get file info struct
            if(~this.fileInfoLoaded)
                if(isempty(channel))
                    channel = this.nonEmptyChannelList(1);
                end
                if(~isempty(this.filesOnHDD) && any(this.filesOnHDD))
                    %we already have imported measurement files -> get fileinfo from those
                    this.loadFileInfo();
                else
                    %read fileinfo from sdt file
                    this.readFluoFileInfo();
                end
            end
            fileInfo = getFileInfoStruct@measurementFile(this,channel);
        end
        
    end %methods
    
    methods (Access = protected)
        function out = getNrSpectralChannels(this)
            %return number of spectral channels
            out = this.fileInfo.nrSpectralChannels;
        end
    end %methods (Access = protected)
        
    methods(Static)
        
        
    end %methods(Static)
end

