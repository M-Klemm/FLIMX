classdef IRFMgr < handle
    %=============================================================================================================
    %
    % @file     IRFMgr.m
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
    % @brief    A class to manage IRF file access
    %
    properties(GetAccess = public, SetAccess = private)
        myDir = ''; 
        IRFStorage = cell(0,0);
        IRFNames = cell(0,0);
        FLIMXObj = []; 
    end
    properties (Dependent = true)
    end
    
    methods
        function this = IRFMgr(flimX,IRFDir)
            %constructor for IRFMgr
            this.FLIMXObj = flimX;            
            this.setIRFDir(IRFDir);
            if(~isfolder(this.myDir))
                [status, message, ~] = mkdir(this.myDir);
                if(~status)
                    error('FLIMX:IRFMgr:createDataFolder','Could not create IRF data folder: %s\n%s',this.myDir,message);
                end
            end
            this.loadIRFs();
        end
        
        %% input methods
        function setIRFDir(this,IRFDir)
            %sets a path to IRF directory
            this.myDir = IRFDir;
        end
        
        function addIRF(this,IRFName,specCh,data,overWriteFlag)
            %add a new IRF to our repository, if IRF already exists and overWriteFlag = true, replace old IRF            
            if(isempty(data))
                return
            end
            [a,b] = size(data);
            if(a > b)
                timeChs = a;
                nVec = b;
            else
                data = data';
                timeChs = b;
                nVec = a;
            end
            if(nVec == 1)
                %no time vector, build one
                timeChs = ceil(timeChs);
                tacRange = this.FLIMXObj.curSubject.tacRange;
                timeVec = linspace(0,tacRange,timeChs);
            else
                timeVec = data(:,1);
            end
            if((~isempty(this.getIRF(timeChs,IRFName,timeVec(end),specCh)) && ~overWriteFlag) || nVec > 2)
                return
            end            
            if(specCh > 0 && ~isempty(data) && ~isempty(timeVec)) %&& timeChs >= 256 
                export = zeros(timeChs,2);
                export(:,1) = timeVec;
                export(1:size(data,1),2) = data(1:size(data,1),end);
                save(fullfile(this.myDir,sprintf('IRF_%d_ch%d_%s.asc',timeChs,specCh,IRFName)),'export','-ASCII');
            end
            this.loadIRFs();
        end
        
        function loadIRFs(this)
            %load IRFs from data directory
            files = dir(fullfile(this.myDir,'*.asc'));
            fns = {files.name};
            fns = fns(~[files.isdir]);
            idx = strncmp(fns,'IRF',3);
            fns = fns(idx);
            %fns = char(sort(fns)); %make sure filenames are correctly sorted
            IDs = cell(length(fns),1);
            timeChs = zeros(size(IDs));
            specChs = zeros(size(IDs));
            for i = 1:length(fns)
                tmp = fns{i};
                idx = strfind(tmp,'_');
                if(length(tmp) < 13 || length(idx) < 3)
                    continue
                end                 
                timeChs(i) = str2double(tmp(idx(1)+1:idx(2)-1));           
                specChs(i) = str2double(tmp(idx(2)+3:idx(3)-1));
                [~,IDs{i}] = fileparts(tmp(idx(3)+1:end));
            end
            idx = isnan(timeChs) | isnan(specChs);
            timeChs(idx) = [];
            specChs(idx) = [];
            IDs(idx) = [];
            if(isempty(timeChs))
                return
            end
            this.IRFNames = unique(IDs);
            u_tChs = unique(timeChs);
            u_sChs = unique(specChs);
            this.IRFStorage = cell(max(u_tChs),length(this.IRFNames),80,max(u_sChs)); %time channels, names, laser repetition rate, spectral channels
            %find all channels belonging to an IRF and load them
            for i=1:length(this.IRFNames)
                idx = find(strcmp(this.IRFNames{i},IDs));
                %load irfs from disc
                for j = 1:length(idx)                    
                    try
                        tmp = load(fullfile(this.myDir,sprintf('IRF_%d_ch%d_%s.asc',timeChs(idx(j)),specChs(idx(j)),this.IRFNames{i})),'-ASCII');
                        repRate = round(1000./(tmp(end,1)+tmp(2,1)));
                        this.IRFStorage{timeChs(idx(j)),i,repRate,specChs(idx(j))} = tmp(:,2);
                    end
                end
            end
        end
                
        %% output methods
        function irf = getCurIRF(this,channel)
            %get current IRF for channel
            irf = this.getIRF(this.FLIMXObj.curSubject.nrTimeChannels,this.FLIMXObj.paramMgr.getParamSection('basic_fit').curIRFID,this.FLIMXObj.curSubject.tacRange,channel);
            if(~isempty(irf))
                irf = irf/max(irf(:)); 
            end
        end
        
        function [irf, irfName] = getIRF(this,timeChans,id,tacRange,specChannel)
            %get the irf for spectral channel and time channels with id and tacRange in ns
            timeRes = timeChans;
            repRate = round(1000/tacRange);
            [a, b, c, d] = size(this.IRFStorage);
            if(isempty(id))
                %use first available IRF
                id = this.getIRFNames(timeChans);
                if(~isempty(id) && iscell(id))
                    id = id{1};
                end
            end
            if(ischar(id))
                id = this.name2Id(id);
            end
            if(isempty(id) || id > b || specChannel > d || timeRes > a || repRate > c)
                irf = [];
                irfName = '';
            else
                irf = squeeze(this.IRFStorage{timeRes,id,repRate,specChannel});
                irfName = this.IRFNames{id};
            end
        end
        
        function deleteIRF(this,timeChans,id,specChannel)
            %delete the irf for spectral channel and time channels with id and tacRange in ns
            if(ischar(id))
                id = this.name2Id(id);
            end
            fn = fullfile(this.myDir,sprintf('IRF_%d_ch%d_%s.asc',timeChans,specChannel,this.IRFNames{id}));
            if(~isempty(id) && isfile(fn))
                delete(fn);
            end
            this.loadIRFs();
        end
        
        function out = getTimeResolutions(this)
            %get possible IRF time resolutions
            tmp = ~cellfun(@isempty,this.IRFStorage);
            tmp = squeeze(sum(sum(sum(tmp,2),3),4));
            out = find(tmp);
        end
        
        function [str, mask] = getIRFNames(this,timeChans)
            %get possible irf names for current time resolution
            if(isempty(timeChans) || timeChans > size(this.IRFStorage,1))
                str = '';
                mask = [];
                return
            end
            p = timeChans;
            b = false(size(this.IRFStorage,2),1);
            for i=1:length(b)
                tmp = squeeze(~cellfun(@isempty,this.IRFStorage(p,i,:,:)));
                tmp = squeeze(sum(sum(tmp,1),2));
                if(any(tmp(:)))
                    b(i) = true;
                end
            end
            str = this.IRFNames(b,1);
            mask = find(b);
        end        
        
        function out = getRepRates(this,timeChans,id)
            %get possible repetition rates (1 / tac range)
            timeRes = timeChans;
            [a, b, c, d] = size(this.IRFStorage);
            if(ischar(id))
                id = this.name2Id(id);
            end                        
            if(isempty(id) || id > b || timeRes > a)
                out = [];
            else
                tmp = squeeze(~cellfun(@isempty,this.IRFStorage(timeRes,id,:,:)));
                tmp = sum(tmp,2);
                out = find(tmp);
            end
        end
        
        function out = getSpectralChNrs(this,timeChans,id,tacRange)
            %get spectral channel numbers of a specific IRF or of all IRFs if id is empty            
            if(isempty(id))
                %return spectral channel numbers of all IRFs
%                 tmp = ~cellfun(@isempty,this.IRFStorage);
%                 tmp = squeeze(sum(sum(sum(tmp,1),3),4));
                out = size(this.IRFStorage,4);
            elseif(~isempty(timeChans))
                repRate = round(1000/tacRange);
                if(ischar(id))
                    id = this.name2Id(id);
                end
                timeRes = timeChans;
                [a, b, c, d] = size(this.IRFStorage);
                if(isempty(id) || id > b || timeRes > a || repRate > c)
                    out = [];
                else
                    tmp = squeeze(~cellfun(@isempty,this.IRFStorage(timeRes,id,repRate,:)));
                    out = find(tmp);
                end
            end
        end
        
        function out = name2Id(this,str)
            %convert irf name to its id
            out = find(strcmp(str,this.IRFNames),1);
        end
        
        %% internal methods
        
    end %methods
    
    methods(Static)
        
        
    end
end %classdef
