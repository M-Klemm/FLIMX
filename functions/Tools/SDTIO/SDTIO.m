classdef SDTIO < handle
    %=============================================================================================================
    %
    % @file     SDTIO.m
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
    % @brief    A class to read Becker & Hickl SDT files.
    %
    properties (Access=public)
        FileInformation = struct(...
            'Name',[],...
            'LastChange',[],...
            'RefreshHeader',double(ones(1,1)),...
            'Software_Revision',[])
        
        m_SDTReadInfo;
        m_hInFile;
        sdtFH;
    end
    
    methods
        function obj = SDTIO(FilePath)
            %clear variables
            %struct in struct creation for the instance of a struct
            obj.FileInformation.Name = FilePath;
            obj.UpdateFile();
            obj.m_SDTReadInfo = obj.SDTFileInfo();
            obj.m_SDTReadInfo.pSPCData = obj.SPCData();
            obj.m_SDTReadInfo.pSPCDataBlockInfo = obj.SDTDataBlockInfo();
            obj.sdtFH = obj.SDT_FILEHEADER();
        end
        function delete(obj)
            %Destructor noch richtig festlegen!!!
        end
    end
    
    methods (Access = public)
        function [tacRange, adc_res, nrSpectralChannels, rawXSz, rawYSz] = ReadHeader(obj)
            if obj.FileInformation.RefreshHeader == 1
                try
                    if(obj.ReadInfo())
                        %To-Do: Prüfen ob Res, Height, Width >0
                        tacRange = double(obj.m_SDTReadInfo.pSPCData(1).tac_range/obj.m_SDTReadInfo.pSPCData(1).tac_gain);
                        adc_res = double(obj.m_SDTReadInfo.pSPCData(1).adc_resolution);
                        nrSpectralChannels = double(obj.m_SDTReadInfo.iNumSPCData);
                        %Already checked if size is given for image, fifo or normal type
                        rawXSz = max(1,double(obj.m_SDTReadInfo.pSPCData(1).img_size_x));
                        rawYSz = max(1,double(obj.m_SDTReadInfo.pSPCData(1).img_size_y));
                    else
                        tacRange = 0;
                        adc_res = 1;
                        nrSpectralChannels = 0;
                        rawXSz = 1;
                        rawYSz = 1;
                    end
                catch
                    tacRange = 0;
                    adc_res = 1;
                    nrSpectralChannels = 0;
                    rawXSz = 1;
                    rawYSz = 1;
                    return
                end
            else
                tacRange = double(obj.m_SDTReadInfo.pSPCData(1).tac_range/obj.m_SDTReadInfo.pSPCData(1).tac_gain);
                adc_res = double(obj.m_SDTReadInfo.pSPCData(1).adc_resolution);
                nrSpectralChannels = double(obj.m_SDTReadInfo.iNumSPCData);
                %Already checked if size is given for image, fifo or normal type
                rawXSz = max(1,double(obj.m_SDTReadInfo.pSPCData(1).img_size_x));
                rawYSz = max(1,double(obj.m_SDTReadInfo.pSPCData(1).img_size_y));
            end
        end
        
        function raw = ReadData(obj, iDataBlock, pfProgress)
            %Update the file if there was any change or maybe it doesnt
            %exists anylonger
            if ~(obj.UpdateFile())
                error('File does not exist anylonger');
            end
            %If there is a new version of the file, we need to read the
            %header again
            if obj.FileInformation.RefreshHeader == 1
                try
                    obj.ReadInfo();
                catch
                    error('File Header is not consistent');
                end
            end
            if(length(obj.m_SDTReadInfo.pSPCDataBlockInfo) < iDataBlock)
                error('Datablock %d does not exist',iDataBlock);
            end
            pReqDBI = obj.m_SDTReadInfo.pSPCDataBlockInfo(iDataBlock);
            fseek(obj.m_hInFile, pReqDBI.uFileOffset, 'bof');
            
            meas_creat =  bitand(pReqDBI.uBlockType,15);
            meas_mode = bitand(pReqDBI.uBlockType,240);
            data_type = bitand(pReqDBI.uBlockType, 3840);
            %define parameters of string type and byte length
            switch data_type
                case 0
                    type_str = 'uint16=>uint16';
                    type_len = 2;
                case 1
                    type_str = 'uint32=>uint32';
                    type_len = 4;
                case 2
                    type_str = 'double=>double';
                    type_len = 8;
                otherwise
                    error('Data type not recognized cannot read block');
            end
            %Description how to read the data for different Block Types
            %To-Do: Case über alle Fälle an Daten anhand des "uBlockType"
            %aber immer Beispieldaten zum Testen erforderlich
            switch meas_mode
                case {0, 16} %DECAY_BLOCK, PAGE_BLOCK, TUIlm Style
                    resolution = 2^(obj.m_SDTReadInfo.pSPCData(iDataBlock).adc_resolution);
                    width = obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_x;
                    height = obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_y;
                    
                    no_of_curves = double(pReqDBI.uNextBlockOffset-pReqDBI.uFileOffset)/double(resolution)/type_len;
                    targetCount = double(pReqDBI.uNextBlockOffset-pReqDBI.uFileOffset)/type_len;
                    [raw, readCount] = fread(obj.m_hInFile, targetCount, type_str);
                    if(readCount ~= targetCount)
                        error('Failed to read %d characters from data block %d - got %d (file: %s).',targetCount,iDataBlock,readCount,obj.FileInformation.Name);
                    end
                    if no_of_curves == width*height
                        raw = reshape(raw, resolution, width, height);
                    else
                        raw = reshape(raw, resolution, no_of_curves);
                    end
                case 32 %FCS_BLOCK
                case 48 %FIDA_BLOCK
                case 64 %FILDA_BLOCK
                case 80 %MCS_BLOCK
                case 96 %IMAGE_BLOCK
                    if meas_creat == 8 || meas_creat == 9
                        no_of_curves = pReqDBI.uBlockLength/(2^double(obj.m_SDTReadInfo.pSPCData(iDataBlock).adc_resolution))/type_len;
                        % zip compressed blocks
                        if bitget(pReqDBI.uBlockType, 13)
                            %disp('Reading compressed data block ...')
                            zipbuf = fread(obj.m_hInFile, pReqDBI.uNextBlockOffset-pReqDBI.uFileOffset, 'uint8=>uint8');                            
                            current_folder = tempdir;
                            if(isempty(current_folder))
                                current_folder = cd;
                            end
                            fn_stub = 'FlimUnzipTemp';
                            for i = 1:100
                                fn = fullfile(current_folder,sprintf('%s%d.zip',fn_stub,i));
                                if(~exist(path,'file'))
                                    break
                                end
                            end
                            tmp_fid = fopen(fn,'w');
                            count = fwrite(tmp_fid, zipbuf,'uint8');
                            pause(1);
                            fclose(tmp_fid);                            
                            try
                                fnu=char(unzip(fn,current_folder));
                                pause(1);
                                tmp_fid = fopen(fnu, 'r');
                                raw = fread(tmp_fid, pReqDBI.uBlockLength/type_len, type_str);
                                fclose(tmp_fid);
                                delete(fn);
                                delete(fnu);
                            catch MD
                                raw = [];
                            end
                        else
                            raw = fread(obj.m_hInFile, double(blk{block_no}.block_length/type_len), type_str);
                        end
                        if(isempty(raw))
                            return
                        end
                        if(no_of_curves == obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_x*obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_y)
                            raw = reshape(raw, (2^obj.m_SDTReadInfo.pSPCData(iDataBlock).adc_resolution), obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_y, obj.m_SDTReadInfo.pSPCData(iDataBlock).img_size_x);
                        else
                            raw = reshape(raw, (2^obj.m_SDTReadInfo.pSPCData(iDataBlock).adc_resolution), no_of_curves);
                        end
                    else
                        raw = [];
                        fclose(obj.m_hInFile);
                        error('Cannot read data block');
                    end
                case 112 %MCS_TA_BLOCK
                case 128 %IMG_MCS_BLOCK
                otherwise
            end
            %Convert from uint... to cell for measurementReadRawData.m
            raw = {permute(raw,[3 2 1])};
        end
    end
    
    methods (Access = private)
        function info = ReadInfo(obj)
            %sdtFH = obj.SDT_FILEHEADER();
            
            %Update the file if there was any change or maybe it doesnt
            %exists anylonger
            if ~(obj.UpdateFile())
                info = 0;
                return;
            end
            %Open the chosen File to enable Reading
            try
                obj.m_hInFile = fopen(obj.FileInformation.Name,'r');
            catch
                info = 0;
                return;
            end
            %Clear Memory of SDTInfo
            obj.ClearSDTInfo();
            %Reading header information
            try
                StructureSDTFH = fieldnames(obj.sdtFH);
                for i=1:numel(StructureSDTFH)
                    obj.sdtFH.(StructureSDTFH{i}) = fread(obj.m_hInFile,1,class(obj.sdtFH.(StructureSDTFH{i})));
                end
            catch %ME
                info = 0;
                return;
            end
            %Read in sdt info string
            try
                fseek(obj.m_hInFile, obj.sdtFH.info_offset, 'bof');
                obj.m_SDTReadInfo.sInfoString = (fread(obj.m_hInFile,obj.sdtFH.info_length, '*char'))';
            catch
                info = 0;
                return;
            end
            %Read in sdt setup string
            try
                fseek(obj.m_hInFile, obj.sdtFH.setup_offs, 'bof');
                obj.m_SDTReadInfo.sSetupString = (fread(obj.m_hInFile,obj.sdtFH.setup_length, '*char'))';
            catch
                info = 0;
                return;
            end
            %Read in all sdt measurement description blocks
            try
                fseek(obj.m_hInFile, obj.sdtFH.setup_offs, -1);
                setup = fread(obj.m_hInFile, obj.sdtFH.setup_length, '*char');
                k = strfind(setup', 'BIN_PARA_BEGIN');
                fseek(obj.m_hInFile, obj.sdtFH.setup_offs + int32(k+15),-1);
                % 4.1 bh_bin_hdr
                fread(obj.m_hInFile, 1, 'uint32=>uint32');
                obj.FileInformation.Software_Revision = fread(obj.m_hInFile,1,'uint32=>uint32');
            catch
                %case u cant find any revision so u take '0' if u maybe use
                %a TU Ilmenau format
                obj.FileInformation.Software_Revision = 0;
            end
            try
                fseek(obj.m_hInFile, obj.sdtFH.meas_desc_block_offset, 'bof');
                obj.ReadMeasurmentDescBlocks(obj.sdtFH.no_of_meas_desc_blocks, obj.sdtFH.meas_desc_block_offset);
            catch
                info = 0;
                return;
            end
            %Read in all sdt data block headers
            try
                fseek(obj.m_hInFile, obj.sdtFH.data_block_offset, 'bof');
                obj.ReadDataBlockHeaders(obj.sdtFH.no_of_data_blocks);
            catch
                info = 0;
                return;
            end
            
            info = 1;
            obj.FileInformation.RefreshHeader = 0;
        end
        
        function info = ReadMeasurmentDescBlocks(obj, iNumBlocksToRead, offset)
            obj.m_SDTReadInfo.iNumSPCData = iNumBlocksToRead;
            %read in measurement description blocks
            StructureSDT_MEASUREMENTDESCBLOCK = fieldnames(obj.SDT_MEASUREMENTDESCBLOCK());
            for iNum=1:iNumBlocksToRead
                sdtMDescBlk = obj.SDT_MEASUREMENTDESCBLOCK();
                %read current block
                
                %Check Software Revision for Data (that u dont take too
                %much
                if obj.FileInformation.Software_Revision <= 789
                    MeasDescLength = 53;
                elseif obj.FileInformation.Software_Revision <= 809
                    MeasDescLength = 58;
                elseif obj.FileInformation.Software_Revision <= 839
                    MeasDescLength = 68;
                else MeasDescLength = numel(StructureSDT_MEASUREMENTDESCBLOCK);
                end
                
                for i=1:MeasDescLength
                    %check if you have a struct in a struct
                    if ~isstruct(sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}))
                        %check if you have to read a string
                        if ischar(sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}))
                            sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}) = (fread(obj.m_hInFile,length(sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i})),'*char'))';
                        else
                            sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}) = (fread(obj.m_hInFile,length(sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i})),class(sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}))))';
                        end
                    else
                        sdtMDescBlk.(StructureSDT_MEASUREMENTDESCBLOCK{i}) = obj.ReadStructInMeasBlock(StructureSDT_MEASUREMENTDESCBLOCK{i});
                    end
                end
                %transform into SPCDATA struct
                if sdtMDescBlk.scan_x ~= 0
                    obj.m_SDTReadInfo.pSPCData(iNum).img_size_x = sdtMDescBlk.scan_x;
                else
                    obj.m_SDTReadInfo.pSPCData(iNum).img_size_x = sdtMDescBlk.image_x;
                end
                if sdtMDescBlk.scan_y ~= 0
                    obj.m_SDTReadInfo.pSPCData(iNum).img_size_y = sdtMDescBlk.scan_y;
                else
                    obj.m_SDTReadInfo.pSPCData(iNum).img_size_y = sdtMDescBlk.image_y;
                end
                obj.m_SDTReadInfo.pSPCData(iNum).adc_resolution = int16(log2(sdtMDescBlk.adc_re));
                
                obj.m_SDTReadInfo.pSPCData(iNum).cfd_zc_level = sdtMDescBlk.cfd_zc;
                obj.m_SDTReadInfo.pSPCData(iNum).cfd_limit_low = sdtMDescBlk.cfd_ll;
                obj.m_SDTReadInfo.pSPCData(iNum).cfd_limit_high = sdtMDescBlk.cfd_lh;
                obj.m_SDTReadInfo.pSPCData(iNum).cfd_holdoff = sdtMDescBlk.cfd_hf;
                
                obj.m_SDTReadInfo.pSPCData(iNum).sync_freq_div = sdtMDescBlk.syn_fd;
                obj.m_SDTReadInfo.pSPCData(iNum).sync_holdoff = sdtMDescBlk.syn_hf;
                obj.m_SDTReadInfo.pSPCData(iNum).sync_threshold = sdtMDescBlk.syn_th;
                obj.m_SDTReadInfo.pSPCData(iNum).sync_zc_level = sdtMDescBlk.syn_zc;
                
                obj.m_SDTReadInfo.pSPCData(iNum).tac_gain = sdtMDescBlk.tac_g;
                obj.m_SDTReadInfo.pSPCData(iNum).tac_limit_high = sdtMDescBlk.tac_lh;
                obj.m_SDTReadInfo.pSPCData(iNum).tac_limit_low = sdtMDescBlk.tac_ll;
                obj.m_SDTReadInfo.pSPCData(iNum).tac_offset = sdtMDescBlk.tac_of;
                obj.m_SDTReadInfo.pSPCData(iNum).tac_range = sdtMDescBlk.tac_r * 1.0e9;
                
                % scan in image?
                if (sdtMDescBlk.meas_mode == 9)
                    obj.m_SDTReadInfo.pSPCData(iNum).mode = 2;
                end
                
                %To-Do: new way
                obj.m_SDTReadInfo.MeasurmentDescBlocks(iNum) = sdtMDescBlk;
                
                %512 Byte for every MeasDescBlock to find the right
                %position in the file, if its a normal header. the header
                %used by tu ilmenau has an other point (if there would be
                %any change in the head so it needs to be changes here)
                if obj.FileInformation.Software_Revision ~= 0
                    fseek(obj.m_hInFile, offset+512*iNum, 'bof');
                else
                    fread(obj.m_hInFile,2,'char=>char');
                end
            end
            info = 1;
        end
        
        function info = ReadDataBlockHeaders(obj, iNumDataBlocksToRead)
            obj.m_SDTReadInfo.iNumSPCData = iNumDataBlocksToRead;
            StructureSDT_DATABLOCKHEADER = fieldnames(obj.SDT_DATABLOCKHEADER());
            %read in all available data block headers
            for iNum=1:iNumDataBlocksToRead
                sdtDBH = obj.SDT_DATABLOCKHEADER();
                %read all the single data block header
                for i=1:numel(StructureSDT_DATABLOCKHEADER)
                    sdtDBH.(StructureSDT_DATABLOCKHEADER{i}) = fread(obj.m_hInFile,1,class(sdtDBH.(StructureSDT_DATABLOCKHEADER{i})));
                end
                %convert to SDTDataBlockInfo
                obj.m_SDTReadInfo.pSPCDataBlockInfo(iNum).uBlockType    = sdtDBH.block_type;
                obj.m_SDTReadInfo.pSPCDataBlockInfo(iNum).uFileOffset   = sdtDBH.data_offs;
                obj.m_SDTReadInfo.pSPCDataBlockInfo(iNum).uNextBlockOffset = sdtDBH.next_block_offs;
                obj.m_SDTReadInfo.pSPCDataBlockInfo(iNum).uBlockLength  = sdtDBH.block_length;
                obj.m_SDTReadInfo.pSPCDataBlockInfo(iNum).iSPCDataIndex = sdtDBH.meas_desc_block_no;
                %move position in file to next data block header
                if iNum < iNumDataBlocksToRead
                    fseek(obj.m_hInFile, sdtDBH.next_block_offs, 'bof');
                end
                
                %To-Do: New Way
                obj.m_SDTReadInfo.DataBlockInfo(iNum) = sdtDBH;
            end
            
            info = 1;
        end
        
        function out = ReadStructInMeasBlock(obj, StructName)
            out = obj.(['SDT_' StructName]);
            Values = fieldnames(out);
            for i=1:numel(Values)
                if ischar(out.(Values{i}))
                    out.(Values{i}) = fread(obj.m_hInFile,length(out.(Values{i})),'*char');
                else
                    out.(Values{i}) = (fread(obj.m_hInFile,length(out.(Values{i})),class(out.(Values{i}))))';
                end
            end
        end
        
        function info = UpdateFile(obj)
            try
                fopen(obj.m_hInFile);
                %fopen on 'ID' give us the path or a failure if its not
                %already open. To get the last change we need to use 'dir'
                file = dir(obj.FileInformation.Name);
                if file.date ~= obj.FileInformation.LastChange;
                    obj.m_hInFile = fopen(obj.FileInformation.Name,'r');
                    file = dir(obj.FileInformation.Name);
                    obj.FileInformation.LastChange = file.date;
                    obj.FileInformation.RefreshHeader = 1;
                end
                info = 1;
            catch
                try
                    obj.m_hInFile = fopen(obj.FileInformation.Name,'r');
                catch
                    info = 0;
                    error('File does not exist');
                end
                file = dir(obj.FileInformation.Name);
                obj.FileInformation.LastChange = file.date;
                obj.FileInformation.RefreshHeader = 1;
                info = 1;
            end
        end
        
        function ClearSDTInfo(obj)
            %Free SDTInfo memory
            obj.m_SDTReadInfo.sInfoString = [];
            obj.m_SDTReadInfo.sSetupString = [];
            obj.m_SDTReadInfo.pSPCData = obj.SPCData();
            obj.m_SDTReadInfo.pSPCDataBlockInfo = obj.SDTDataBlockInfo();
        end
        
        function SumOfBlock = sizeof(~, BlockToAdd, PartsOfBlock)
            %Get Bytes of all allocated values in struct
            bytes = zeros(1,numel(PartsOfBlock));
            for i=1:numel(PartsOfBlock)
                tmp = BlockToAdd.(PartsOfBlock{i});
                tmp = whos('tmp');
                bytes(i) = tmp.bytes;
            end
            %Sum all the Bytes out of the struct
            SumOfBlock = sum(bytes);
        end
        
        %Description of a structs used in this class which contains 4
        %other structs, so you will need obj as variable to merge
        function out = SDT_MEASUREMENTDESCBLOCK(obj)
            out = struct(...
                'time',char(zeros(1,9)),...
                'date',char(zeros(1,11)),...
                'mod_ser_no',char(zeros(1,16)),...
                'meas_mode',int16(zeros(1,1)),...
                'cfd_ll',single(zeros(1,1)),...
                'cfd_lh',single(zeros(1,1)),...
                'cfd_zc',single(zeros(1,1)),...
                'cfd_hf',single(zeros(1,1)),...
                'syn_zc',single(zeros(1,1)),...
                'syn_fd',int16(zeros(1,1)),...
                'syn_hf',single(zeros(1,1)),...
                'tac_r',single(zeros(1,1)),...
                'tac_g',int16(zeros(1,1)),...
                'tac_of',single(zeros(1,1)),...
                'tac_ll',single(zeros(1,1)),...
                'tac_lh',single(zeros(1,1)),...
                'adc_re',int16(zeros(1,1)),...
                'eal_de',int16(zeros(1,1)),...
                'ncx',int16(zeros(1,1)),...
                'ncy',int16(zeros(1,1)),...
                'page',uint16(zeros(1,1)),...
                'col_t',single(zeros(1,1)),...
                'rep_t',single(zeros(1,1)),...
                'stopt',int16(zeros(1,1)),...
                'overfl',char(zeros(1,1)),...
                'use_motor',int16(zeros(1,1)),...
                'steps',int16(zeros(1,1)),...
                'offset',single(zeros(1,1)),...
                'dither',int16(zeros(1,1)),...
                'incr',int16(zeros(1,1)),...
                'mem_bank',int16(zeros(1,1)),...
                'mod_type',char(zeros(1,16)),...
                'syn_th',single(zeros(1,1)),...
                'dead_time_comp',int16(zeros(1,1)),...
                'polarity_l',int16(zeros(1,1)),...
                'polarity_f',int16(zeros(1,1)),...
                'polarity_p',int16(zeros(1,1)),...
                'linediv',int16(zeros(1,1)),...
                'accumulate',int16(zeros(1,1)),...
                'flbck_y',int32(zeros(1,1)),...
                'flbck_x',int32(zeros(1,1)),...
                'bord_u',int32(zeros(1,1)),...
                'bord_l',int32(zeros(1,1)),...
                'pix_time',single(zeros(1,1)),...
                'pix_clk',int16(zeros(1,1)),...
                'trigger',int16(zeros(1,1)),...
                'scan_x',int32(zeros(1,1)),...
                'scan_y',int32(zeros(1,1)),...
                'scan_rx',int32(zeros(1,1)),...
                'scan_ry',int32(zeros(1,1)),...
                'fifo_typ',int16(zeros(1,1)),...
                'epx_div',int32(zeros(1,1)),...
                'mod_type_code',uint16(zeros(1,1)),...
                'mod_fpga_ver',uint16(zeros(1,1)),...
                'overflow_corr_factor',single(zeros(1,1)),...
                'adc_zoom',int32(zeros(1,1)),...
                'cycles',int32(zeros(1,1)),...
                'MeasStopInfo',[],...
                'MeasFCSInfo',[],...
                'image_x',int32(zeros(1,1)),...
                'image_y',int32(zeros(1,1)),...
                'image_rx',int32(zeros(1,1)),...
                'image_ry',int32(zeros(1,1)),...
                'xy_gain',int16(zeros(1,1)),...
                'dig_flags',int16(zeros(1,1)),...
                'adc_de',int16(zeros(1,1)),...
                'det_type',int16(zeros(1,1)),...
                'x_axis',int16(zeros(1,1)),...
                'MeasHISTInfo',[],...
                'MeasHISTInfoExt',[]);
            out.MeasStopInfo = obj.SDT_MeasStopInfo();
            out.MeasFCSInfo = obj.SDT_MeasFCSInfo();
            out.MeasHISTInfo = obj.SDT_MeasHISTInfo();
            out.MeasHISTInfoExt = obj.SDT_MeasHISTInfoExt();
        end
    end
    
    methods (Static)
        %Description of all structs used in this class
        function out = SDT_FILEHEADER()
            %Init des SDT File Header
            out = struct(...
                'revision',int16(zeros(1,1)),...
                'info_offset',int32(zeros(1,1)),...
                'info_length',int16(zeros(1,1)),...
                'setup_offs',int32(zeros(1,1)),...
                'setup_length',int16(zeros(1,1)),...
                'data_block_offset',int32(zeros(1,1)),...
                'no_of_data_blocks',int16(zeros(1,1)),...
                'data_block_length',int32(zeros(1,1)),...
                'meas_desc_block_offset',int32(zeros(1,1)),...
                'no_of_meas_desc_blocks',int16(zeros(1,1)),...
                'meas_desc_block_length',int16(zeros(1,1)),...
                'header_valid',uint16(zeros(1,1)),...
                'reserved1',uint32(zeros(1,1)),...
                'reserved2',uint16(zeros(1,1)),...
                'chksum',uint16(zeros(1,1)));
        end
        
        function out = FluoImage()
            out = struct(...
                'puPhotons',[],...
                'pfPhotons',[],...
                'iNumImages',[],...
                'SPCDATA',[],...
                'sCommentField',[]);
        end
        
        function out = SPCData()
            out = struct(...
                'base_adr',[],...
                'init',[],...
                'cfd_limit_low',[],...
                'cfd_limit_high',[],...
                'cfd_zc_level',[],...
                'cfd_holdoff',[],...
                'sync_zc_level',[],...
                'sync_holdoff',[],...
                'sync_threshold',[],...
                'tac_range',[],...
                'sync_freq_div',[],...
                'tac_gain',[],...
                'tac_offset',[],...
                'tac_limit_low',[],...
                'tac_limit_high',[],...
                'adc_resolution',[],...
                'ext_latch_delay',[],...
                'collect_time',[],...
                'display_time',[],...
                'repeat_time',[],...
                'stop_on_time',[],...
                'stop_on_ovfl',[],...
                'dither_range',[],...
                'count_incr',[],...
                'mem_bank',[],...
                'dead_time_comp',[],...
                'scan_control',[],...
                'routing_mode',[],...
                'tac_enable_hold',[],...
                'pci_card_no',[],...
                'mode',[],...
                'scan_size_x',[],...
                'scan_size_y',[],...
                'scan_rout_x',[],...
                'scan_rout_y',[],...
                'scan_flyback',[],...
                'scan_borders',[],...
                'scan_polarity',[],...
                'pixel_clock',[],...
                'line_compression',[],...
                'trigger',[],...
                'pixel_time',[],...
                'ext_pixclk_div',[],...
                'rate_count_time',[],...
                'macro_time_clk',[],...
                'add_select',[],...
                'test_eep',[],...
                'adc_zoom',[],...
                'img_size_x',[],...
                'img_size_y',[],...
                'img_rout_x',[],...
                'img_rout_y',[],...
                'xy_gain',[],...
                'master_clock',[],...
                'adc_sample_delay',[],...
                'detector_type',[],...
                'x_axis_type',[],...
                'chan_enable',[],...
                'chan_slope',[]);
        end
        
        function out = SDTFileInfo()
            out = struct(...
                'sInfoString',[],...
                'sSetupString',[],...
                'pSPCData',[],...
                'iNumSPCData',[],...
                'pSPCDataBlockInfo',[],...
                'iNumSPCDataBlocks',[]);
        end
        
        function out = SDT_MeasStopInfo()
            out = struct(...
                'status',uint16(zeros(1,1)),...
                'flags',uint16(zeros(1,1)),...
                'stop_time',single(zeros(1,1)),...
                'cur_step',int32(zeros(1,1)),...
                'cur_cycle',int32(zeros(1,1)),...
                'cur_page',int32(zeros(1,1)),...
                'min_sync_rate',single(zeros(1,1)),...
                'min_cfd_rate',single(zeros(1,1)),...
                'min_tac_rate',single(zeros(1,1)),...
                'min_adc_rate',single(zeros(1,1)),...
                'max_sync_rate',single(zeros(1,1)),...
                'max_cfd_rate',single(zeros(1,1)),...
                'max_tac_rate',single(zeros(1,1)),...
                'max_adc_rate',single(zeros(1,1)),...
                'reserved1',int32(zeros(1,1)),...
                'reserved2',single(zeros(1,1)));
        end
        
        function out = SDT_MeasFCSInfo()
            out = struct(...
                'chan',uint16(zeros(1,1)),...
                'fcs_decay_calc',uint16(zeros(1,1)),...
                'mt_resol',uint32(zeros(1,1)),...
                'cortime',single(zeros(1,1)),...
                'calc_photons',uint32(zeros(1,1)),...
                'fcs_points',int32(zeros(1,1)),...
                'end_time',single(zeros(1,1)),...
                'overruns',uint16(zeros(1,1)),...
                'fcs_type',uint16(zeros(1,1)),...
                'cross_chan',uint16(zeros(1,1)),...
                'mod',uint16(zeros(1,1)),...
                'cross_mod',uint16(zeros(1,1)),...
                'cross_mt_resol',uint32(zeros(1,1)));
        end
        
        function out = SDT_MeasHISTInfo()
            out = struct(...
                'fida_time',single(zeros(1,1)),...
                'filda_time',single(zeros(1,1)),...
                'fida_points',int32(zeros(1,1)),...
                'filda_points',int32(zeros(1,1)),...
                'mcs_time',single(zeros(1,1)),...
                'mcs_points',int32(zeros(1,1)),...
                'cross_calc_phot',uint32(zeros(1,1)),...
                'mcsta_points',uint16(zeros(1,1)),...
                'mcsta_flags',uint16(zeros(1,1)),...
                'mcsta_tpp',uint32(zeros(1,1)),...
                'calc_markers',uint32(zeros(1,1)),...
                'reserved3',uint32(zeros(1,1)));
        end
        
        function out = SDT_MeasHISTInfoExt()
            out = struct(...
                'first_frame_time',single(zeros(1,1)),...
                'frame_time',single(zeros(1,1)),...
                'line_time',single(zeros(1,1)),...
                'pixel_time',single(zeros(1,1)),...
                'info',char(zeros(1,48)));
        end
        
        function out = SDT_DATABLOCKHEADER()
            out = struct(...
                'block_no',int16(zeros(1,1)),...
                'data_offs',int32(zeros(1,1)),...
                'next_block_offs',int32(zeros(1,1)),...
                'block_type',uint16(zeros(1,1)),...
                'meas_desc_block_no',int16(zeros(1,1)),...
                'lblock_no',uint32(zeros(1,1)),...
                'block_length',uint32(zeros(1,1)));
        end
        
        function out = SDTDataBlockInfo()
            out = struct(...
                'uBlockType',[],...
                'uFileOffset',[],...
                'uBlockLength',[],...
                'uNextBlockOffset',[],...
                'iSPCDataIndex',[]);
        end
    end
end

