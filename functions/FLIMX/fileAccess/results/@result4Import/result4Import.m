classdef result4Import < resultFile
    %=============================================================================================================
    %
    % @file     result4Import.m
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
    % @brief    A class to represent a result object used to import results
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = result4Import(hSubject)
            %constructor
            this = this@resultFile(hSubject);
        end
        
        %% input
        
%         function ch = importResult(this,fn,resultType,chFlag,position,scaling)
%             %load result from disk, if chFlag = true load all channels;
%             %in case of ascii import chFlag = channel number of imported data
%             ch = 0;
%             switch resultType
%                 case 3 %FLIMXFit result
%                     if(iscell(fn))
%                         fn = fn{1};
%                     end
%                     [path,fileName] = fileparts(fn);
%                     chIdx = strfind(fileName,'ch');
%                     if(~isempty(chIdx) && chFlag)
%                         %look for all files (channels) with similar file name
%                         files = rdir(sprintf('%s%s%s*.mat',path,filesep,fileName(1:chIdx)));
%                         for i = 1:length(files)
%                             ch = this.openChannel(files(i,1).name);
%                         end
%                     else
%                         ch = this.openChannel(fn);
%                     end
%                 case {1,2} %B&H result file#
%                     ch = chFlag;
%                     if(nargin < 6)
%                         fi = measurementFile.getDefaultFileInfo();
%                         position = fi.position;
%                         scaling = fi.pixelResolution;
%                     end
%                     %read ASCII files
%                     file = cell(1,length(fn));
%                     for i = 1:length(fn)
%                         [path, name, ext] = fileparts(fn{i});
%                         file(i) = {[name,ext]};
%                     end
%                     try
%                         rs = FLIMXFitResultImport.ASCII2ResultStruct(file,path,this.mySubject.name,resultType,ch);
%                     catch ME
%                         uiwait(errordlg(sprintf('%s\n\nImport aborted.',ME.message),'Error loading B&H results','modal'));
%                         return
%                     end
%                     if(~isfield(rs,'results'))
%                         return
%                     end
%                     fields = fieldnames(rs.results.pixel);
%                     if(isempty(fields))
%                         return
%                     end
%                     %check that number of taus and amps match                    
%                     nA = sum(strncmp('Amplitude',fields,9));
%                     nT = sum(strncmp('Tau',fields,3));
%                     %check number of paramters
%                     if(nA ~= nT)
%                         uiwait(errordlg(sprintf('Number of Amplitudes (%d) and Taus (%d) does not match!\n\nImport aborted.',nA,nT),'Error loading B&H results','modal'));
%                         return
%                     end
%                     %check size of channel
%                     if(~isempty(this.filesOnHDD) && ~isempty(this.loadedChannelList) && ~all(this.resultSize == size(rs.results.pixel.Amplitude1)))
%                         uiwait(errordlg(sprintf('Size of channel %d result (%dx%d) does not match subject result size (%dx%d)!\n\nImport aborted.',ch,size(rs.results.pixel.Amplitude1,1),size(rs.results.pixel.Amplitude1,2),this.resultSize(1),this.resultSize(2)),'Error loading B&H results','modal'));
%                         return
%                     end
%                     rs = resultFile.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
%                     rs.auxiliaryData.fileInfo.position = position;
%                     rs.auxiliaryData.fileInfo.pixelResolution = scaling;
%                     this.loadResult(rs);
%                     this.setDirty(ch,true);
%                     %update fileInfo of other channels
%                     if(ch > 1)
%                         for i = 1:ch-1
%                             this.auxiliaryData{i}.fileInfo.nrSpectralChannels = rs.auxiliaryData.fileInfo.nrSpectralChannels;
%                             this.setDirty(i,true);
%                         end
%                     end
%             end
%         end
        
        function importResultStruct(this,rs,ch,position,scaling)
            %import a result struct into this object, the result struct must have the same format as a result file
            %make sure version is correct
            rs = resultFile.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
            rs.auxiliaryData.fileInfo.position = position;
            rs.auxiliaryData.fileInfo.pixelResolution = scaling;
            this.loadResult(rs);
            this.setDirty(ch,true);
            %update fileInfo of other channels
            if(ch > 1)
                for i = 1:ch-1
                    this.auxiliaryData{i}.fileInfo.nrSpectralChannels = rs.auxiliaryData.fileInfo.nrSpectralChannels;
                    this.setDirty(i,true);
                end
            end
        end
        
        function addFLIMItems(this,ch,itemsStruct)
            %add FLIM items to our inner results structure, here: FLIM items do not need to be allocated previously!
            tmp = this.getPixelResult(ch);
            fn = fieldnames(itemsStruct);
            for l = 1:length(fn)
                if(all(size(itemsStruct.(fn{l})) == this.resultSize))
                    tmp.(fn{l}) = itemsStruct.(fn{l});
                end
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.setDirty(ch,true);
            this.loadedChannels(ch,1) = true;
        end
        
    end%methods
    
    methods(Static)
        function [fileGroups, fileGroupCounts] = detectFileGroups(path,ext)
            %determine the file groups (if there multi file stubs), input file extension(s) in addition to .asc as cell array
            fileGroups = {};
            fileGroupCounts = 0;
            %always look for .asc files
            fileExt = {'.asc'};
            if(iscell(ext))
                fileExt(2:1+length(ext)) = ext;
            elseif(ischar(ext) && length(ext) == 4)
                fileExt(2) = {ext};
            end
            fileExt = unique(fileExt);
            %scan folder for files
            files = [];
            for i = 1:length(fileExt)
                tmp = rdir(fullfile(path,['*' fileExt{i}]));
                files = [files;tmp];
            end
            if(size(files,1) == 0)                
                return
            end
            [~,fileNames,e] = cellfun(@fileparts,{files(:).name},'UniformOutput',false);
            %try to find ***a1.asc
            fnTmp = fileNames(strcmp(e,'.asc'));
            ampsInPercentFlag = false;
            if(any(contains(fnTmp,'_a1') & ~contains(fnTmp,'[%]')))
                %remove % amplitudes
                idx = contains(fileNames,'[%]') & strcmp(e,'.asc'); %remove amps in percent
                fileNames(idx) = [];
                e(idx) = [];
                fnTmp = fileNames(strcmp(e,'.asc'));
                a1Id = find(contains(fnTmp,'_a1'));                
            else
                %try to find amplitudes in %
                a1Id = find(contains(fnTmp,'_a1') & contains(fnTmp,'[%]'));
                if(~isempty(a1Id))
                    %remove amplitudes which are not scaled in %
                    idx = find(cellfun(@length,fnTmp) >= 3);
                    for i = length(idx):-1:1
                        tmp = fnTmp{idx(i)};
                        tmp = tmp(end-2:end);
                        if(strcmp(tmp(1:2),'_a') && isstrprop(tmp(3),'digit'))
                            fnTmp(idx(i)) = [];
                            e(idx(i)) = [];
                        end
                    end
                    ampsInPercentFlag = true;
                end
            end
            if(~isempty(a1Id))
                fileStub = cell(length(a1Id),1);
                for i = 1:length(a1Id)
                    stub = fnTmp{a1Id(i)};
                    if(ampsInPercentFlag)
                        stub = stub(1:end-5); %remove _a1[%]
                    else
                        stub = stub(1:end-2); %remove _a1
                    end
                    %check for single channel and multiple channels
                    chPos = regexp(stub,'-Ch\d+-_');
                    if(~isempty(chPos))% && strcmp(stub(end),'-') && chDigitLength >= 1 && chDigitLength <= 2)
                        %we have at least 2 channels
                        fileStub{i} = stub(1:chPos-1);
                    else
                        %single channel without the -Chx-_ in the name
                        fileStub{i} = stub;
                    end
                end
                % find prevailing file stub
                fileGroups = unique(fileStub);
                fileGroupCounts = zeros(length(fileGroups),1);
                for i=1:length(fileGroups)
                    idx = strncmp(fnTmp,fileGroups{i},length(fileGroups{i}));
                    fileGroupCounts(i) = sum(idx);
                end
            end
            %check if there are remaining files, which don't belong to an a1.asc (or if we didn't find an a1.asc)
            if(sum(fileGroupCounts(:)) ~= length(fileNames))
                %remove the files that already belong to a file stub
                fnTmp = fileNames;
                for i = 1:length(fileGroups)
                    idx = strncmp(fnTmp,fileGroups{i},length(fileGroups{i}));
                    fnTmp(idx) = [];
                end
                %now look for underscores and find similar strings in file names
                fileStub = {};
                while any(~cellfun(@isempty,fnTmp))
                    stub = fnTmp{1};
                    id_ = strfind(stub,'_');
                    if(isempty(id_))
                        fnTmp(1) = [];
                        continue
                    end
                    for i = length(id_):-1:1
                        idx = strncmp(fnTmp,stub,id_(i));
                        if(sum(idx(:)) > 1)
                            %we found at least one partner
                            fileStub(end+1,1) = {stub(1:id_(i))};
                            fnTmp(idx) = [];
                            break
                        elseif(i == 1)
                            fileStub(end+1,1) = {stub};
                            fnTmp(idx) = [];
                        end
                    end
                end
                %count occurences
                for i=1:length(fileStub)
                    idx = strncmp(fileNames,fileStub{i},length(fileStub{i}));
                    fileGroups(end+1,1) = fileStub(i);
                    fileGroupCounts(end+1) = sum(idx);
                end
            end
        end
        
        function rs = ASCIIFilesInGroup2ResultStruct(path,ext,fileGroupName,subjectName,hProgress)
            %convert ASCII parameter files to internal result format            
            if(isempty(fileGroupName))
                rs = [];
                return
            end
            if(nargin < 5)
                hProgress = [];
            end
            tStart = clock;
            try
                hProgress(0.01,'Scanning...');
            end
            %always look for .asc files
            fileExt = {'.asc'};
            if(iscell(ext))
                fileExt(2:1+length(ext)) = ext;
            elseif(ischar(ext) && length(ext) == 4)
                fileExt(2) = {ext};
            end
            fileExt = unique(fileExt);
            %make sure .asc is the first position
            ascId = find(strcmp(fileExt,'.asc'),1);
            fileExt = circshift(fileExt,ascId-1);
            %scan for files
            files = [];
            for i = 1:length(fileExt)
                tmp = rdir(fullfile(path,[fileGroupName '*' fileExt{i}]));
                files = [files;tmp];
            end
            if(isempty(files))
                rs = [];
                return
            end            
            [~,fileNames,e] = cellfun(@fileparts,{files(:).name},'UniformOutput',false);
            %try to find ***a1.asc or ***a1[%].asc
            if( ~any(strcmp(e,'.asc') & contains(fileNames,'_a1') & ~contains(fileNames,'[%]')) && any(strcmp(e,'.asc') & contains(fileNames,'_a1') & contains(fileNames,'[%]')))
                ampsInPercentFlag = true;
            else
                ampsInPercentFlag = false;
            end
            rs.results.pixel.Amplitude1 = [];
            for i = 1:length(files)
                [~,filename,curExt] = fileparts(files(i).name);
                chanNr = 1;
                chPos = regexp(filename,'-Ch\d{1,2}-_','once');
                if(isempty(chPos))
                    curName = filename(min(length(fileGroupName)+1,length(filename)):end);
                else
                    str = filename(chPos:chPos+5);
                    idx = isstrprop(str,'digit');
                    chanNr = str2double(str(idx));
                    curName = filename(min(length(filename),chPos+6):end);
                end
                if(isempty(curName) || ~ampsInPercentFlag && contains(curName,'[%]') || strcmp(curName,'trace'))
                    %error or amplitude in percent or data trace
                    continue
                end
                curNr = [];
                if(strcmp(curName(1),'a') && sum(isstrprop(curName,'digit')) == 1 && length(curName) == 2 ||  sum(isstrprop(curName,'digit')) == 2 && length(curName) == 3)
                    %regular amplitude
                    if(ampsInPercentFlag)
                        %ignore regular amplitudes
                        continue
                    end
                    curNr = str2double(curName(isstrprop(curName,'digit')));
                    curName = 'Amplitude';
                elseif(ampsInPercentFlag && strcmp(curName(1),'a') && sum(isstrprop(curName,'digit')) == 1 && length(curName) == 5 || sum(isstrprop(curName,'digit')) == 2 && length(curName) == 6)
                    %amplitude in percent
                    curNr = str2double(curName(isstrprop(curName,'digit')));
                    curName = 'Amplitude';
                elseif(strcmp(curName(1),'t') && sum(isstrprop(curName,'digit')) >= 1 && sum(isstrprop(curName,'digit')) <= 2 && length(curName) <= 3)
                    curNr = str2double(curName(isstrprop(curName,'digit')));
                    curName = 'Tau';
                else
                    %get datatype from filename; remove not allowed characters
                    curName = studyMgr.checkStructFieldName(curName);
                end
                file = fullfile(path,[filename,curExt]);
                switch curExt
                    case '.asc'
                        data_temp = load(file,'-ASCII');
                    case {'.bmp', '.tif', '.tiff', '.png'}
                        try
                            [data_temp,map,transparency] = imread(file);
                            [~,~,zm] = size(data_temp);
                            if(zm == 1 && length(unique(data_temp)) < 3)
                                data_temp = logical(data_temp);                            
                            elseif(zm == 3)
                                %convert image to binary image
                                data_temp = rgb2ind(data_temp(:,:,1:3),0.1,'nodither');
                                if(~any(data_temp(:)) || all(data_temp(:)) && any(transparency(:)))
                                    %there is no structure in the RGB channels, try to use the transparency channel
                                    data_temp = logical(transparency);
                                end
                            elseif(zm == 4)
                                %convert image to binary image
                                transparency = squeeze(data_temp(:,:,4));
                                data_temp = rgb2ind(data_temp(:,:,1:3),0.1,'nodither');
                                if(~any(data_temp(:)) || all(data_temp(:)))
                                    %there is no structure in the RGB channels, try to use the transparency channel
                                    %this is the transparency mask, we use its inverted version
                                    data_temp = ~transparency > 0.1;
                                end
                            end
                        catch
                            %reading image failed
                            %todo: message user
                            continue
                        end
                end
                %restrict B&H amplitudes to <= 1 and amplify
                %                 if(strcmp(dType,'Amplitude') && median(data_temp(:)) < 0.5)
                %                     data_temp(data_temp > 1) = 0;
                %                     data_temp = data_temp .* 100000;
                %                 end
                %check if we have that curName already
                if(length(rs) >= chanNr && any(strcmp(fieldnames(rs(chanNr).results.pixel),curName)))
                    curName = [curName '_' curExt(2:end)];
                end
                rs(chanNr).results.pixel.(sprintf('%s%d',curName,curNr)) = data_temp;
                try
                    [~, minutes, secs] = secs2hms(etime(clock,tStart)/i*(length(files)-i));
                    hProgress(i/length(files),sprintf('%02.1f%% ETA: %dmin %.0fsec',100*i/length(files),minutes,secs));
                end
            end
            for ch = 1:length(rs)
                %remove empty fields
                fn = fieldnames(rs(ch).results.pixel);
                for i = 1:length(fn)
                    if(isempty(rs(ch).results.pixel.(fn{i})))
                        rs(ch).results.pixel = rmfield(rs(ch).results.pixel,fn{i});
                    end
                end
                if(~isempty(rs(ch).results))
                    rs(ch).results.pixel = orderfields(rs(ch).results.pixel);
                    rs(ch).roiCoordinates = [];
                    rs(ch).channel = ch;
                    rs(ch).name = subjectName;
                    rs(ch).resultType = 'ASCII';
                    rs(ch).about.results_revision = 200;
                end
            end
            try
                hProgress(0,'');
            end
        end
    end
end%classdef