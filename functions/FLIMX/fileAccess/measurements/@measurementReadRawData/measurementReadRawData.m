classdef measurementReadRawData < measurementFile
    %=============================================================================================================
    %
    % @file     measurementReadRawData.m
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
    % @brief    A class to represent the measurementReadRawData class
    %
    properties(GetAccess = public, SetAccess = protected)
        sourcePath = '';
        SDTIOObj = [];
    end
    
    properties (Dependent = true)
        isSDTFile = true;
        isASCIIFile = true;
    end
    
    methods
        function this = measurementReadRawData(hPM)
            %constructor
            this = this@measurementFile(hPM);
        end
        
        %% input methods
        function setSourceFile(this,fn)
            %set file name
            setSourceFile@measurementFile(this,fn);
            this.clearRawData([]);
            this.setFileInfoStruct(measurementFile.getDefaultFileInfo());
            this.fileInfoLoaded = false;
            this.sourcePath = fileparts(fn);
            if(this.isSDTFile)
                %create SDTIO object
                this.SDTIOObj = SDTIO(fn);
                %set progressbar callback
                %this.SDTIOObj.setProgressCallback(@this.updateProgress);
            end
            this.readFluoFileInfo();
            this.ROICoord = [];
            this.clearROIData();
        end
        
        %%output methods
%         function out = getNonEmptyChannelList(this)
%             %return list of channel with measurement data
%             out = ones(1,this.nrSpectralChannels);
%         end
%         
%         function out = getLoadedChannelList(this)
%             %return a list of channels in memory
%             
%         end
        
        function out = get.isSDTFile(this)
            %
            [~, ~, ext] = fileparts(this.sourceFile);
            if(strcmpi(ext,'.sdt'))
                out = true;
            else
                out = false;
            end
        end
        
        function out = get.isASCIIFile(this)
            %
            [~, ~, ext] = fileparts(this.sourceFile);
            if(strcmpi(ext,'.txt') || strcmpi(ext,'.asc'))
                out = true;
            else
                out = false;
            end
        end
        
        function readFluoFileInfo(this)
            %get information of fluorescence data files
            if(isempty(this.sourceFile))
                return
            end
            fileInfo = measurementFile.getDefaultFileInfo();
            if(this.isSDTFile) %sdt file
                [fileInfo.tacRange, adc_res, fileInfo.nrSpectralChannels, fileInfo.rawXSz, fileInfo.rawYSz] = this.SDTIOObj.ReadHeader;
                if(fileInfo.tacRange == 0)
                    fileInfo.tacRange = 12.5084;
                end
                if(adc_res == 0)
                    adc_res = 10;
                end
            elseif(this.isASCIIFile)
                %ascii file
                try
                    raw = load(this.sourceFile,'-ASCII');
                    if(~isvector(raw))
                        %BH ascii export file
                        if(size(raw,2) > size(raw,1))
                            raw = raw';
                        end
                        adc_res = ceil(log2(size(raw,1)));
                        if(size(raw,2) == 2)
                            fileInfo.tacRange = 2^adc_res*abs(raw(2,1)-raw(1,1));
                            tmp(1,1,:) = raw(:,2);
                            this.rawFluoData(1) = {tmp};
                            this.rawFluoDataFlat(1) = cell(1,1);
                        end
                        fileInfo.rawXSz = 1;
                        fileInfo.rawYSz = 1;
                    else
                        %we can't compute tacRange and acd_res, use default
                        adc_res = 10;
                        fileInfo.tacRange = 12.5084;
                        tmp(1,1,:) = raw(:);
                        this.rawFluoData(1) = {tmp};
                        this.rawFluoDataFlat(1) = cell(1,1);
                    end
                    fileInfo.nrSpectralChannels = 1;
                catch
                    return
                end
                fileInfo.nrSpectralChannels = 1;
            else
                return
            end
            this.setNrTimeChannels(2^adc_res);
            fileInfo.nrTimeChannels = 2^adc_res;
            fileInfo.reflectionMask = cell(fileInfo.nrSpectralChannels,1);
            fileInfo.startPosition = num2cell(ones(fileInfo.nrSpectralChannels,1));
            fileInfo.endPosition = num2cell(fileInfo.nrTimeChannels.*ones(fileInfo.nrSpectralChannels,1));
            fileInfo.mergeMaxPos = zeros(fileInfo.nrSpectralChannels,1);
            this.setFileInfoStruct(fileInfo);
        end
    end
    
    methods (Sealed = true)
        %%output methods
        function out = getNonEmptyChannelList(this)
            %return list of channel with measurement data
            out = ones(1,this.nrSpectralChannels);
        end
        
        function out = getRawData(this,channel)
            %get raw data for channel
            out = [];
            if(this.nrTimeChannels == 0)
                this.readFluoFileInfo();
            end
            if(channel > this.nrSpectralChannels)
                %we don't have that channel
                return
            end
            if(length(this.rawFluoData) < channel || isempty(this.rawFluoData{channel}))
                %try to load this channel
                this.updateProgress(0,'Loading SDT File');
                if(this.isSDTFile)
                    this.rawFluoData(channel) = this.SDTIOObj.ReadData(channel);
                    this.updateProgress(0.5,'Loading SDT File');
                    this.rawFluoDataFlat(channel) = cell(1,1);
                    %[this.rawYSz,this.rawXSz, ~] = size(raw); %todo: get from sdt file header
                    this.updateProgress(1,'Loading SDT File');
                elseif(this.isASCIIFile)
                    try
                        raw = load(this.sourceFile,'-ASCII');
                        if(~isvector(raw))
                            %BH ascii export file
                            if(size(raw,2) > size(raw,1))
                                raw = raw';
                            end
                        end
                        this.rawFluoData(channel) = {raw};
                        this.rawFluoDataFlat(channel) = cell(1,1);
                    catch
                        return
                    end
                else
                    return
                end
                this.setDirtyFlags(channel,1,true);
                this.updateProgress(0,'');
            end
            out = this.rawFluoData{channel};            
        end
    end
end