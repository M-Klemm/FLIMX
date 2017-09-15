classdef resultFile < handle
    %=============================================================================================================
    %
    % @file     resultFile.m
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
    % @brief    A class to represent the fluoDecayFitResult class
    %
    properties(GetAccess = public, SetAccess = protected)        
        fileStub = 'result_';
        fileExt = '.mat';   
        mySubject = [];
        %myFolder = '';
        filesOnHDD = false(1,0);
        loadedChannels = false(1,0);
        results = [];
        resultSize = zeros(1,2);
        initApproximated = false(1,1);
        pixelApproximated = false(1,1);
        auxiliaryData = cell(0,0);
        resultType = 'FluoDecayFit';
        isDirty = false(1,0);
    end
    
    properties (Dependent = true)
        paramMgrObj = [];
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
        nonEmptyChannelList = [];
        loadedChannelList = [];
    end
    
    methods
        function this = resultFile(hSubject)
            %constructor
            this.mySubject = hSubject;                       
            this.results.init = cell(1,0);
            this.results.pixel = cell(1,0);
            this.results.about = FLIMX.getVersionInfo();
            this.checkMyFiles();
        end
        
        function setDirty(this,ch,val)
            %set dirty flag for this result
            this.isDirty(ch) = logical(val);
        end
        
        %% input methods
        function success = openChannel(this,ch)
            %open result files of a specific channel and store
            success = false;
            if(~isMultipleCall())
                rs = this.loadFromDisk(this.getResultFileName(ch,''));
                if(isempty(rs))                    
                    return
                end
                this.loadResult(rs);
                %check if we have the IRF used for the result
                IRFMgr = this.mySubject.myIRFMgr;
                aux = this.getAuxiliaryData(ch);
                if(strcmp('FluoDecayFit',rs.resultType) && ~isempty(IRFMgr) && ~isempty(aux) && isempty(IRFMgr.getIRF(aux.fileInfo.nrTimeChannels,aux.IRF.name,aux.fileInfo.tacRange,ch)) )
                    %we don't have this IRF yet -> add it to our IRF manager
                    irf = linspace(0,aux.fileInfo.tacRange,length(aux.IRF.vector))';
                    irf(:,2) = double(aux.IRF.vector);
                    IRFMgr.addIRF(aux.IRF.name,ch,irf,false);%this.basicParams.curIRFID
                end
                success = true;
            end
        end
        
        function loadResult(this,rs)
            %load data from result struct rs into this object
            %load aux data first because we need the file info!            
            if(isfield(rs,'auxiliaryData'))                
                this.auxiliaryData{rs.channel} = rs.auxiliaryData;
            end
            if(isempty(this.loadedChannelList))
                %this is the first result we load from this subject -> load used parameters
                if(isfield(rs,'parameters'))
                    parameters = checkStructConsistency(rs.parameters,this.paramMgrObj.getDefaults());
                else
                    parameters = this.paramMgrObj.getDefaults();
                end
                %make sure that tciMask and stretchedExp are of correct length
                if(length(parameters.basic_fit.tciMask) < parameters.basic_fit.nExp)
                    parameters.basic_fit.tciMask(1,end+1:parameters.basic_fit.nExp) = 0;
                end
                parameters.basic_fit.tciMask = parameters.basic_fit.tciMask(1,1:parameters.basic_fit.nExp);
                if(length(parameters.basic_fit.stretchedExpMask) < parameters.basic_fit.nExp)
                    parameters.basic_fit.stretchedExpMask(1,end+1:parameters.basic_fit.nExp) = 0;
                end
                parameters.basic_fit.stretchedExpMask = parameters.basic_fit.stretchedExpMask(1,1:parameters.basic_fit.nExp);                
                this.paramMgrObj.setParamSection('result',parameters);
                this.paramMgrObj.setParamSection('bounds',parameters);
                this.paramMgrObj.setParamSection('optimization',parameters);
            end
            if(isfield(rs.results,'init'))
                this.results.init{rs.channel,1} = rs.results.init;
                this.initApproximated = true(rs.channel,1);
            else
                this.results.init(rs.channel,1) = cell(1,1);
            end
            if(isfield(rs.results,'pixel'))
                this.results.pixel{rs.channel,1} = rs.results.pixel;
                this.pixelApproximated(rs.channel,1) = true;
            else
                this.results.pixel(rs.channel,1) = cell(1,1);
            end
            this.paramMgrObj.makeVolatileParams();
            this.results.about = rs.about;
            this.resultType = rs.resultType;
            this.resultSize = rs.size;
            this.loadedChannels(rs.channel,1) = true;
            %this.resultFileInfo = result.fileInfo;
        end
        
        function allocResults(this,chList,ROIYSz,ROIXSz)
            %clear old results, build new results structure
            this.resultSize = [ROIYSz,ROIXSz];
            if(isvector(chList) && ~isscalar(chList))                
                this.allocInitResult(chList);
                this.allocPixelResult(chList);
                %this.results.about = this.aboutInfo; %do we need that??
                for i = 1:length(chList)
                    this.loadedChannels(chList(i),1) = false;
                end
            elseif(isscalar(chList))
%                 if(all(this.resultSize) && ~all(this.resultSize == [ROIYSz,ROIXSz]))
%                     return
%                 end
                %this.resultSize = [ROIYSz,ROIXSz];
                this.allocInitResult(chList);
                this.allocPixelResult(chList);
                this.loadedChannels(chList,1) = false;
            end            
        end
        
        function allocInitResult(this,ch)
            %clear old init results, build new init results structure
            if(isempty(ch))
                this.results.init = cell(0,0);
                this.initApproximated = false;
                return
            end
            if(isscalar(ch))
                this.results.init(ch,1) = {this.makeResultStructs(this.initFitParams.gridSize,this.initFitParams.gridSize)};
                this.initApproximated(ch,1) = false;
            else
                for i = ch
                    this.allocInitResult(i);
                end
            end
        end
        
        function allocPixelResult(this,ch)
            %clear old pixel results, build new pixel results structure
            if(isempty(ch))
                this.results.pixel = cell(0,0);
                this.pixelApproximated = false;
                return
            elseif(isscalar(ch))
                this.results.pixel(ch,1) = {this.makeResultStructs(this.resultSize(1),this.resultSize(2))};
                this.pixelApproximated(ch,1) = false;
            else
                for i = ch
                    this.allocPixelResult(i);
                end
            end
        end
        
        function setPixelResolution(this,val)
            %set pixel resolution to a new value
            for ch = this.nonEmptyChannelList                
                ad = this.getAuxiliaryData(ch);
                if(~isempty(ad))
                    ad.fileInfo.pixelResolution = val;
                    this.auxiliaryData{ch} = ad;
                    this.setDirty(ch,true);
                end
            end
        end   
        
        function setPosition(this,val)
            %set position to a new value (OD or OS)
            for ch = 1:length(this.auxiliaryData)
                ad = this.getAuxiliaryData(ch);
                if(~isempty(ad))
                    ad.fileInfo.position = val;
                    this.auxiliaryData{ch} = ad;
                    this.setDirty(ch,true);
                end
            end
        end  
        
        function setAuxiliaryData(this,ch,ad)
            %set auxiliary data for channel ch
            %todo: check structure
            this.auxiliaryData{ch} = ad;
        end
        
        function setInitFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            if(ch > length(this.results.init))
                return
            end
            %check if size is correct
            [y, x, z] = size(val);
            if(this.initFitParams.gridSize == x && this.initFitParams.gridSize == y)
                this.results.init{ch,1}.(pStr) = val;
            else
                error('fluoDecayFitResult:setInitFLIMItem','Size of initFLIMItem (%d, %d) does not match size of init grid (%d, %d)',y,x,this.initFitParams.gridSize,this.initFitParams.gridSize);
            end
            this.setDirty(ch,true);
        end
        
        function setPixelFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            if(ch > length(this.results.pixel))
                return
            end
            %check if size is correct
            [y, x, z] = size(val);
            if(this.resultSize(2) == x && this.resultSize(1) == y)
                this.results.pixel{ch,1}.(pStr) = val;
            else
                error('fluoDecayFitResult:setPixelFLIMItem','Size of pixelFLIMItem (%d, %d) does not match ROI size (%d, %d)',y,x,this.resultSize(1),this.resultSize(2));
            end
            this.setDirty(ch,true);
        end        
        
        
        %% output methods
        function out = getAuxiliaryData(this,ch)
            %get auxiliary data for channel ch
            if(any(ch == this.nonEmptyChannelList) && ~any(ch == this.loadedChannelList))
                %we have requested channel, but it is not loaded -> load it
                this.getFileInfoStruct(ch);
            end
            if(length(this.auxiliaryData) >= ch) %any(ch == this.nonEmptyChannelList) && 
                out = this.auxiliaryData{ch};
            else
                out = [];
            end
        end
   
        function out = getAboutInfo(this)
            %return about struct
            out = this.results.about;
        end
        
        function out = getResultType(this)
            %return result type string
            out = this.resultType;
        end
        
        function out = getFileInfoStruct(this,ch)
            %result file info struct, if ch ist empty return fileInfo from any channel
            if(isempty(ch) && ~isMultipleCall())
                %get fileInfo from any channel
                if(isempty(this.loadedChannelList))
                    if(isempty(this.nonEmptyChannelList))
                        %we don't have any file
                        %we still might have something stored
                        ch = find(~cellfun('isempty',this.auxiliaryData),1);
                        if(isempty(ch))
                            %we don't have anything
                            out = [];
                            return
                        end
                    else
                        %try to load a channel
                        ch = this.nonEmptyChannelList(1);
                        this.openChannel(ch);
                    end
                else
                    ch = this.loadedChannelList(1);
                end 
            elseif(isMultipleCall())
                ch = 1;
            end
            if((length(this.auxiliaryData) < ch) || isempty(this.auxiliaryData{ch}) && ismember(ch,this.nonEmptyChannelList))
                %load first available result
                this.openChannel(ch);
                %file info should not be empty anymore                
            end 
            if(length(this.auxiliaryData) < ch || isempty(this.auxiliaryData{ch}))
                out = [];
            else
                out = this.auxiliaryData{ch}.fileInfo;                
            end
        end
        
        function out = getResultNames(this,ch,isInitResult)
            %get the names of the result structure
            out = cell(0,0);
            if(isInitResult && ~isempty(ch) && length(this.results.init) >= ch)
                out = fieldnames(this.results.init{ch,1});
                %             elseif(~isempty(ch) && any(ch == this.nonEmptyChannelList))%length(this.results.pixel) >= ch && ~isempty(this.results.pixel{ch,1}))
                %                 if(~any(ch == this.loadedChannelList))
                %                     this.openChannel(ch);
            elseif(~isempty(ch) && length(this.results.pixel) >= ch && ~isempty(this.results.pixel{ch,1}))
                out = fieldnames(this.results.pixel{ch,1});
            end
            if(~isempty(out))
                for i = 1:this.basicParams.nExp
                    out(end+1) = {sprintf('AmplitudePercent%d',i)};
                    out(end+1) = {sprintf('Q%d',i)};
                end
                out(end+1) = {'TauMean'};
            end
        end
        
        function out = isInitResult(this,ch)
            %true if init result was set
            if(~isempty(ch) && ~any(this.loadedChannelList == ch) && any(this.nonEmptyChannelList == ch))
                %we have to load this channel first
                this.openChannel(ch);
            end
            if(ch > length(this.initApproximated))
                out = false;
            else
                out = this.initApproximated(ch);
            end
        end
        
        function out = isPixelResult(this,ch,y,x,initFit)
            %true if pixel result was set
            if(~isempty(ch) && ~any(this.loadedChannelList == ch) && any(this.nonEmptyChannelList == ch))
                %we have to load this channel first
                this.openChannel(ch);
            end
            out = false;
            if(nargin == 2)
                if(ch <= length(this.pixelApproximated))
                    out = this.pixelApproximated(ch);
                end
            elseif(initFit)
                if(this.isInitResult(ch) && this.results.init{ch,1}.chi2(y,x))
                    out = true;
                end
            else
                if(this.isPixelResult(ch) && this.results.pixel{ch,1}.chi2(y,x))
                    out = true;
                end
            end
        end
        
        function out = getNonEmptyChannelList(this)
             %return list of channels with result data
             %out = find(~cellfun('isempty',this.results.pixel));
             %out = union(find(~cellfun('isempty',this.results.pixel)),find(this.filesOnHDD));
             if(isempty(this.filesOnHDD))
                 out = unique([find(this.initApproximated);find(this.pixelApproximated);]);
             else
                 out = find(this.filesOnHDD);
             end
                 
%              if(isempty(this.initApproximated))
%                  out = find(this.filesOnHDD);
%              else
%                  out = unique([find(this.initApproximated);find(this.pixelApproximated);find(this.filesOnHDD);]);
%              end
             out = out(:)';
         end
        
        function out = getInitFLIMItem(this,ch,pStr)
            %return specific init result, e.g. tau 1
            out = [];
            if((isempty(this.results.init) || length(this.results.init) < ch|| isempty(this.results.init{ch,1})) && ~any(this.nonEmptyChannelList == ch))
                return
            end
            if((isempty(this.results.init) || length(this.results.init) < ch|| isempty(this.results.init{ch,1})) && ~any(this.loadedChannelList == ch))
                %what if channel is dirty?
                this.openChannel(ch);
                if(isempty(this.results.init{ch,1}))
                    %something went wrong
                    return
                end
            end
            if(isfield(this.results.init{ch,1},pStr))
                out = this.results.init{ch,1}.(pStr);
            elseif(strncmp(pStr,'AmplitudePercent',16))
                %make amplitude in percent
                nr = str2double(pStr(17:end));
                if(isnan(nr))
                    out = [];
                    return
                end
                out = this.getInitFLIMItem(ch,sprintf('Amplitude%d',nr));
                tmp = zeros(size(out,1),size(out,2),this.basicParams.nExp);
                for i = 1:size(tmp,3)
                    tmp2 = this.getInitFLIMItem(ch,sprintf('Amplitude%d',i));
                    if(~isempty(tmp2) && size(tmp,1) == size(tmp2,1) && size(tmp,2) == size(tmp2,2))
                        tmp(:,:,i) = tmp2;
                    end
                end
                out(isnan(out)) = 0;
                out = 100*out./sum(tmp,3);
            elseif(strncmp(pStr,'Q',1))
                %make Q
                nr = str2double(pStr(2:end));
                if(isnan(nr))
                    out = [];
                    return
                end
                out = this.getInitFLIMItem(ch,sprintf('Amplitude%d',nr)) .* this.getInitFLIMItem(ch,sprintf('Tau%d',nr));
                %Q1= a1*T1*100/(a1*T1+a2*T2+a3*T3)
                tmp = zeros(size(out));
                if(isempty(tmp))
                    return
                end
                for i = 1:this.basicParams.nExp
                    tmp = tmp + this.getInitFLIMItem(ch,sprintf('Amplitude%d',i)).* this.getInitFLIMItem(ch,sprintf('Tau%d',i));
                end
                out(isnan(out)) = 0;
                out = out ./ tmp .* 100;
            elseif(strncmp(pStr,'TauMean',7))
                %make mean of taus                
                %Tm= a1*T1+a2*T2+a3*T3/(a1+a2+a3)
                amp = this.getInitFLIMItem(ch,'Amplitude1');
                tmp = zeros(size(amp)); 
                out = zeros(size(amp));
                for i = 1:this.basicParams.nExp
                    amp = this.getInitFLIMItem(ch,sprintf('Amplitude%d',i));
                    tmp = tmp + amp .* this.getInitFLIMItem(ch,sprintf('Tau%d',i));
                    out = out + amp;
                end
                out = tmp./out;
                out(isnan(out)) = 0;
%             elseif(strncmp(pStr,'GoodnessOfFit',13))
%                 %compute goodness of fit statistics
%                 %Q = 1/gamma(v/2)*integral(exp(-t)*t^((v/2)-1)dt; chi² to inf; v = degrees of freedom; Q > 0.1 = good, Q < 0.001 = bad
%                 v = this.volatilePixelParams.nApproxParamsAllCh;
%                 fun = @(t,v) exp(-t).*t.^((v/2)-1);                
%                 if(nargin == 5)
%                     chi = this.getInitFLIMItem(ch,pStr,y,x);
%                     out = integral(@(t)fun(t,v),chi/2,inf)./gamma(v/2);
%                     return
%                 else
%                     chi = this.getInitFLIMItem(ch,pStr);
%                     out = zeros(size(chi));
%                     parfor i = 1:numel(chi)
%                         if(~isnan(chi(i)) && ~isinf(chi(i)))
%                             out(i) = integral(@(t)fun(t,v),chi(i)/2,inf)./gamma(v/2);
%                         end
%                     end
%                 end
            end
            %post processing
            if(strncmp(pStr,'MaximumPosition',15) && ~isempty(out) && ~isempty(this.getFileInfoStruct(ch)))
                out = out .* this.getFileInfoStruct(ch).timeChannelWidth;                
            end
        end
        
        function out = getPixelFLIMItem(this,ch,pStr,y,x)
            %return specific pixel result, e.g. tau 1, optional pixel coordinates
            out = [];
            if((isempty(this.results.pixel) || length(this.results.pixel) < ch || isempty(this.results.pixel{ch,1})) && ~any(this.nonEmptyChannelList == ch))
                return
            end
            if(isempty(this.results.pixel) || length(this.results.pixel) < ch || isempty(this.results.pixel{ch,1}) || ~any(this.loadedChannelList == ch))
                %what if channel is dirty?
                this.openChannel(ch);
                if(isempty(this.results.pixel{ch,1}))
                    %something went wrong
                    return
                end
            end
            if(isfield(this.results.pixel{ch,1},pStr))
                out = this.results.pixel{ch,1}.(pStr);
            elseif(strncmp(pStr,'AmplitudePercent',16))
                %make amplitude in percent
                nr = str2double(pStr(17:end));
                if(isnan(nr) || nr > this.basicParams.nExp)
                    out = [];
                    return
                end
                out = this.getPixelFLIMItem(ch,sprintf('Amplitude%d',nr));
                tmp = zeros(size(out,1),size(out,2),this.basicParams.nExp);
                for i = 1:size(tmp,3)
                    tmp2 = this.getPixelFLIMItem(ch,sprintf('Amplitude%d',i));
                    if(~isempty(tmp2) && size(tmp,1) == size(tmp2,1) && size(tmp,2) == size(tmp2,2))
                        tmp(:,:,i) = tmp2;
                    end
                end
                out(isnan(out)) = 0;
                out = 100*out./sum(abs(tmp),3);
            elseif(strncmp(pStr,'Q',1))
                %make Q
                nr = str2double(pStr(2:end));
                if(isnan(nr) || nr > this.basicParams.nExp)
                    out = [];
                    return
                end
                out = this.getPixelFLIMItem(ch,sprintf('Amplitude%d',nr)) .* this.getPixelFLIMItem(ch,sprintf('Tau%d',nr));
                %Q1= a1*T1*100/(a1*T1+a2*T2+a3*T3)
                tmp = zeros(size(out));
                for i = 1:this.basicParams.nExp
                    tmp = tmp + this.getPixelFLIMItem(ch,sprintf('Amplitude%d',i)).* this.getPixelFLIMItem(ch,sprintf('Tau%d',i));
                end
                out(isnan(out)) = 0;
                out = out ./ tmp .* 100;
            elseif(strncmp(pStr,'TauMean',7))
                %make mean of taus                
                %Tm= a1*T1+a2*T2+a3*T3/(a1+a2+a3)
                amp = this.getPixelFLIMItem(ch,'Amplitude1');
                tmp = zeros(size(amp)); 
                out = zeros(size(amp));
                for i = 1:this.basicParams.nExp
                    amp = this.getPixelFLIMItem(ch,sprintf('Amplitude%d',i));
                    tmp = tmp + amp .* this.getPixelFLIMItem(ch,sprintf('Tau%d',i));
                    out = out + amp;
                end
                out = tmp./out;
                out(isnan(out)) = 0;
%             elseif(strncmp(pStr,'GoodnessOfFit',13))
%                 %compute goodness of fit statistics
%                 %Q = 1/gamma(v/2)*integral(exp(-t)*t^((v/2)-1)dt; chi² to inf; v = degrees of freedom; Q > 0.1 = good, Q < 0.001 = bad
%                 v = this.volatilePixelParams.nApproxParamsAllCh;
%                 fun = @(t,v) exp(-t).*t.^((v/2)-1);                
%                 if(nargin == 5)
%                     chi = this.getPixelFLIMItem(ch,pStr,y,x);
%                     out = integral(@(t)fun(t,v),chi/2,inf)./gamma(v/2);
%                     return
%                 else
%                     chi = this.getPixelFLIMItem(ch,pStr);
%                     out = zeros(size(chi));
%                     parfor i = 1:numel(chi)
%                         if(~isnan(chi(i)) && ~isinf(chi(i)))
%                             out(i) = integral(@(t)fun(t,v),chi(i)/2,inf)./gamma(v/2);
%                         end
%                     end
%                 end
            end
            %post processing
            if(strncmp(pStr,'MaximumPosition',15) && ~isempty(out))
                out = out .* this.mySubject.timeChannelWidth;                
            end
            %optional: select only one pixel
            if(nargin == 5 && ~isempty(out))
                out = squeeze(out(max(1,min(size(out,1),y)),max(1,min(size(out,2),x)),:));
            end
        end
        
        function out = makeExportStruct(this,ch)
            %build the structure with results for export
            if(length(this.pixelApproximated) < ch || ~(this.pixelApproximated(ch) || length(this.initApproximated) < ch || this.initApproximated(ch)))
                out = [];
                return
            end
            out.results.pixel = this.getPixelResult(ch);
            out.about = this.aboutInfo;
            %save important data and parameters
            out.parameters.volatile = this.volatilePixelParams;
            out.parameters.pre_processing = this.preProcessParams;
            out.parameters.basic_fit = this.basicParams;
            out.parameters.init_fit = this.initFitParams;
            out.parameters.pixel_fit = this.pixelFitParams;
            out.parameters.bounds = this.boundsParams;
            out.parameters.optimization = this.optimizationParams;
            out.parameters.computation = this.computationParams;
            out.resultType = this.resultType;
            out.channel = ch;
            out.size = this.resultSize;
            out.auxiliaryData = this.getAuxiliaryData(ch);
            out.results.init = this.getInitResult(ch);
            %additional info
            out.name = this.mySubject.name;
            [~, fileName, ext] = fileparts(this.mySubject.getSourceFile());
            roi = this.mySubject.ROICoordinates;
            if(~any(roi))
                roi = [1, out.size(2), 1, out.size(1)];
            end
            int = this.mySubject.getRawDataFlat(ch);
            if(length(roi) == 4 && ~isempty(int) && size(int,1) >= roi(4) && size(int,2) >= roi(2))
                int = int(roi(3):roi(4),roi(1):roi(2));
            else
                int = [];
            end
            out.sourceFile = [fileName ext];
            out.roiCoordinates =  roi;
            out.results.pixel.Intensity = int;
            out.results.reflectionMask = this.mySubject.getReflectionMask(ch);
        end        
        
        function exportMatFile(this,ch,fn)
            %save result channel to disk
            result = this.makeExportStruct(ch);
            if(isempty(result))
                return
            end
            fn = this.getResultFileName(ch,fn);
            [pathstr, ~, ~] = fileparts(fn);
             if(~isdir(pathstr))
                 [status, message, ~] = mkdir(pathstr);
                 if(~status)
                     error('FLIMX:resultFile:exportMatFile','Could not create path for result file export: %s\n%s',pathstr,message);
                 end
             end
            save(fn,'result');
        end
        
        function results = makeResultStructs(this,y,x)
            %build result structure
            bp = this.basicParams;
            vp = this.volatilePixelParams;
            for i = 1 : bp.nExp
                a = sprintf('Amplitude%d',i);
                ag = sprintf('AmplitudeGuess%d',i);
                t = sprintf('Tau%d',i);
                tg = sprintf('TauGuess%d',i);
                r = sprintf('RAUC%d',i);
                results.(a) = zeros(y,x);
                results.(ag) = zeros(y,x);
                results.(t) = zeros(y,x);
                results.(tg) = zeros(y,x);
                results.(r) = zeros(y,x);
            end
            for i = 1:(bp.nExp + vp.nScatter)
                r = sprintf('RAUCIS%d',i);
                results.(r) = zeros(y,x);
            end
            tcis = find(bp.tciMask);
            nTci = length(tcis);
            if(nTci > 0)
                for i = 1 : nTci
                    tci_str = sprintf('tc%d',tcis(i));
                    tcig_str = sprintf('tcGuess%d',tcis(i));
                    results.(tci_str) = zeros(y,x);
                    results.(tcig_str) = zeros(y,x);
                end
            end
            Betas = find(bp.stretchedExpMask);
            if(~isempty(Betas))
                for i = 1 : length(Betas)
                    se_str = sprintf('Beta%d',Betas(i));
                    results.(se_str) = zeros(y,x);
                end
            end
            %todo: fix scatter allocation
            for i = 1 : vp.nScatter
                a = sprintf('ScatterAmplitude%d',i);
                s = sprintf('ScatterShift%d',i);
                o = sprintf('ScatterOffset%d',i);
                results.(a) = zeros(y,x);
                results.(s) = zeros(y,x);
                results.(o) = zeros(y,x);
            end
            results.Offset = zeros(y,x);
            results.Time = zeros(y,x);
            results.Iterations = zeros(y,x);
            results.FunctionEvaluations = zeros(y,x);
            results.chi2 = zeros(y,x);
            results.chi2Tail = zeros(y,x);
            results.hShift = zeros(y,x);
            results.StartPosition = ones(y,x);
            results.EndPosition = ones(y,x);
                %todo: fix me
%             else
%                 results.EndPosition = ones(y,x).*this.resultFileInfo.nrTimeChannels;
%             end
            results.MaximumPosition = zeros(y,x);
            results.TotalPhotons = zeros(y,x);
            results.MaximumPhotons = zeros(y,x);
            results.hostname = cell(y,x);
            results.standalone = zeros(y,x);
            results.OffsetGuess = zeros(y,x);
            results.TauMeanGuess = zeros(y,x);
            results.SlopeStartPosition = zeros(y,x);
            results.hShiftGuess = zeros(y,x);
            if(this.basicParams.approximationTarget == 2)
                results.AnisotropyQuick = zeros(y,x);
            end
            %toDo: fix allocation
            results.x_vec = zeros(y,x,vp.nModelParamsPerCh);
            results.iVec = zeros(y,x,vp.nModelParamsPerCh);            
            results.EffectiveTime = 0;
            results = orderfields(results);
        end
        
        function out = getMyFolder(this)
            %return current working folder
            out = this.mySubject.getMyFolder();
        end
        
        function checkMyFiles(this)
            %check in my folder for result files
            if(isempty(this.getMyFolder()))
                return
            end
            files = rdir(fullfile(this.getMyFolder(),['*' this.fileExt]));
            for i = 1:length(files)
                [~,fileName] = fileparts(files(i,1).name);                
                if(strncmpi(fileName,this.fileStub,7) && length(fileName) == 11)
                    chIdx = str2double(fileName(10:11));
                    if(~isempty(chIdx))
                        this.filesOnHDD(chIdx,1) = true;
                    end
                end
            end            
        end
        
        function rs = loadFromDisk(this,resFN)
            %load a FLIMX result struct rs (contains one channel) from disk
            rs = [];
            if(~exist(resFN,'file'))
                return
            end
            rs = load(resFN);
            %update result to latest version
            rs = resultFile.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
        end
        
        function saveMatFile2Disk(this,ch)
            %save result channel to disk
            %fn = this.getResultFileName(ch,'');
            this.exportMatFile(ch,'');
            this.setDirty(ch,false);
        end
                
        function [apObj, xVec, hShift, oset, chi2, chi2Tail, TotalPhotons, FunctionEvaluations, time, slopeStart, iVec] = getVisParams(this,apObj,ch,y,x,initFit)
            %get parameters for visualization of current fit in channel ch
            if(initFit)
                %show merge data                
                fileInfo = apObj.getFileInfo(ch);
                if(~this.isInitResult(ch))
                    rs = this.makeResultStructs(1,1);
                    hShift = rs.hShift;
                    oset = rs.Offset;
                    xVec = squeeze(rs.x_vec);
                    chi2 = rs.chi2;
                    chi2Tail = rs.chi2Tail;
                    TotalPhotons = rs.TotalPhotons;
                    FunctionEvaluations = rs.FunctionEvaluations;
                    time = rs.Time;
                    slopeStart = rs.SlopeStartPosition;
                    iVec = squeeze(rs.iVec);
                else
                    xVec = squeeze(this.results.init{ch,1}.x_vec(y,x,:));
                    hShift = this.results.init{ch,1}.hShift(y,x);
                    oset = this.results.init{ch,1}.Offset(y,x);                   
                    fileInfo.StartPosition = this.results.init{ch,1}.StartPosition(y,x);
                    fileInfo.EndPosition = this.results.init{ch,1}.EndPosition(y,x);
                    %fileInfo.reflectionMask =
                    %this.fluoFileObj.getReflectionMask(ch); %todo: fixme
                    chi2 = this.results.init{ch,1}.chi2(y,x);
                    chi2Tail = this.results.init{ch,1}.chi2Tail(y,x);
                    TotalPhotons = this.results.init{ch,1}.TotalPhotons(y,x);
                    FunctionEvaluations = this.results.init{ch,1}.FunctionEvaluations(y,x);
                    time = this.results.init{ch,1}.Time(y,x);
                    slopeStart = this.results.init{ch,1}.SlopeStartPosition(y,x);
                    iVec = squeeze(this.results.init{ch,1}.iVec(y,x,:));
                end                
            else
                %pixel data                              
                fileInfo = apObj.getFileInfo(ch);
                y = min(y,this.resultSize(1));
                x = min(x,this.resultSize(2));
                if(~this.isPixelResult(ch) || strncmp(this.resultType,'ASCII',5))
                    rs = this.makeResultStructs(1,1);
                    hShift = rs.hShift;
                    oset = rs.Offset;
                    xVec = squeeze(rs.x_vec);
                    chi2 = rs.chi2;
                    chi2Tail = rs.chi2Tail;
                    TotalPhotons = rs.TotalPhotons;
                    FunctionEvaluations = rs.FunctionEvaluations;
                    time = rs.Time;
                    slopeStart = rs.SlopeStartPosition;
                    iVec = squeeze(rs.iVec);
                else
                    hShift = this.getPixelFLIMItem(ch,'hShift',y,x);  %this.results.pixel{ch,1}.hShift(y,x);
                    oset = this.getPixelFLIMItem(ch,'Offset',y,x);  %this.results.pixel{ch,1}.Offset(y,x);
                    xVec = this.getPixelFLIMItem(ch,'x_vec',y,x);  %squeeze(this.results.pixel{ch,1}.x_vec(y,x,:));
                    fileInfo.StartPosition = this.getPixelFLIMItem(ch,'StartPosition',y,x);  %this.results.pixel{ch,1}.StartPosition(y,x);
                    fileInfo.EndPosition = this.getPixelFLIMItem(ch,'EndPosition',y,x);  %this.results.pixel{ch,1}.EndPosition(y,x);
                    chi2 = this.getPixelFLIMItem(ch,'chi2',y,x);  %this.results.pixel{ch,1}.chi2(y,x);
                    chi2Tail = this.getPixelFLIMItem(ch,'chi2Tail',y,x);  %this.results.pixel{ch,1}.chi2Tail(y,x);
                    TotalPhotons = this.getPixelFLIMItem(ch,'TotalPhotons',y,x);  %this.results.pixel{ch,1}.TotalPhotons(y,x);
                    FunctionEvaluations = this.getPixelFLIMItem(ch,'FunctionEvaluations',y,x);  %this.results.pixel{ch,1}.FunctionEvaluations(y,x);
                    time = this.getPixelFLIMItem(ch,'Time',y,x);  %this.results.pixel{ch,1}.Time(y,x);
                    slopeStart = this.getPixelFLIMItem(ch,'SlopeStartPosition',y,x);  %this.results.pixel{ch,1}.SlopeStartPosition(y,x);
                    iVec = this.getPixelFLIMItem(ch,'iVec',y,x);  %squeeze(this.results.pixel{ch,1}.iVec(y,x,:));
                end
            end
            apObj.setCurrentChannel(ch);
            bp = apObj.basicParams;
            bp.errorMode = 1;
            bp.heightMode = 1;
            xVec(end) = oset;
            if(bp.hybridFit)
                %switch off hybrid fitting for result display
                %replace hybrid fit parameters with their corresponding results
                bp.hybridFit = 0;
                %                 vcp = apObj.getVolatileChannelParams(ch);
                %                 vcp.cMask = zeros(size(vcp.cMask));
                %                 vcp.cVec = [];
                %                 apObj.setVolatileChannelParams(ch,vcp);
            end
            for chIdx = 1:apObj.nrChannels
                bp.(sprintf('constMaskSaveStrCh%d',chIdx)) = {''};
            end
            apObj.basicParams = bp;
        end
        
        %% dependent properties  
        function out = get.paramMgrObj(this)
            %return handle to parameter manager
            out = this.mySubject.myParamMgr;
        end
        
        function params = get.aboutInfo(this)
            %get version info of me
            params = this.results.about; %this.paramMgrObj.getParamSection('about');
        end
        
        function params = get.computationParams(this)
            %get computation parameters
            params = this.paramMgrObj.getParamSection('computation');
        end
        
        function params = get.preProcessParams(this)
            %get pre processing parameters
            params = this.paramMgrObj.getParamSection('pre_processing');
        end
        
        function params = get.basicParams(this)
            %get basic fit parameters
            params = this.paramMgrObj.getParamSection('basic_fit');
        end
        
        function params = get.initFitParams(this)
            %get initialization fitParams struct
            params = this.paramMgrObj.getParamSection('init_fit');
        end
        
        function params = get.pixelFitParams(this)
            %get pixel fitParams struct
            params = this.paramMgrObj.getParamSection('pixel_fit');
        end
        
        function params = get.optimizationParams(this)
            %get optimization parameters
            params = this.paramMgrObj.getParamSection('optimization');
        end
        
        function params = get.boundsParams(this)
            %get bounds
            params = this.paramMgrObj.getParamSection('bounds');
        end
        
        function params = get.volatilePixelParams(this)
            %get bounds
            params = this.paramMgrObj.getParamSection('volatilePixel');
        end
%         
%         function params = getVolatileChannelParams(this,ch)
%             %get volatileChannelParams, all channels if ch = 0
%             params = this.resultParamMgrObj.getParamSection('volatileChannel',ch);
%         end

        function out = get.nonEmptyChannelList(this)
            %return a list of channel numbers "with data"
            out = this.getNonEmptyChannelList();
        end
        
        function out = get.loadedChannelList(this)
            %return a list of channels in memory
            %out = intersect(this.nonEmptyChannelList,find(~cellfun('isempty',this.auxiliaryData))');
            out = find(this.loadedChannels);
        end
        
    end %methods
    
    methods (Access = protected)
        function out = getResultFileName(this,ch,folder)
            %returns path and filename for channel ch
            if(isempty(folder))
                out = fullfile(this.getMyFolder(),sprintf('%sch%02d%s',this.fileStub,ch,this.fileExt));
            else
                out = fullfile(folder,sprintf('%sch%02d%s',this.fileStub,ch,this.fileExt));
            end
        end
        
        function out = getInitResult(this,ch)
            %return init result structure
            out = [];
            if(isempty(this.results.init{ch,1}) && ~ismember(ch,this.nonEmptyChannelList))
                return
            end
            if(isempty(this.results.init{ch,1}) && ~ismember(ch,this.loadedChannelList))
                %what if channel is dirty?
                this.openChannel(ch);
            end
            out = this.results.init{ch,1};
        end
        
        function out = getPixelResult(this,ch)
            %return pixel result structure
            out = [];
            if(isempty(this.results.pixel{ch,1}) && ~ismember(ch,this.nonEmptyChannelList))
                return
            end
            if(isempty(this.results.pixel{ch,1}) && ~ismember(ch,this.loadedChannelList))
                %what if channel is dirty?
                this.openChannel(ch);
            end
            out = this.results.pixel{ch,1};
        end
    end
    
    methods(Static)        
        function [result, data] = updateFitResultsStruct(rs,aboutInfo)
            %update result structure to current layout
            result = [];
            data = [];
            if(isfield(rs,'export'))
                rs = rs.export;
                if(~isfield(rs,'about'))
                    
                elseif(rs.about.results_revision < 122)
                    uiwait(errordlg(sprintf('Result file is too old.\nRequired revision is: 1.30.\nFound revision is: %1.2f.',rs.export.about.results_revision/100),'modal'));
                    return
                end
                %update rs rev13x to the rev200 layout                
                result.sourceFile = '';
                result.IRFName = '';
                if(isfield(rs,'data') && isfield(rs.data,'fluo'))
                    if(isfield(rs.data.fluo,'name'))
                        result.name = rs.data.fluo.name;
                    else
                        result.name = '';
                    end
                    if(isfield(rs.data.fluo,'curChannel'))
                        result.channel = rs.data.fluo.curChannel;
                    else
                        result.channel = 1; %assume channel 1
                    end
                    if(isfield(rs.data.fluo,'roi'))
                        result.roiCoordinates = rs.data.fluo.roi;
                    else
                        result.roiCoordinates = [];
                    end
                    if(isfield(rs.data,'curIRF'))
                        result.IRFVector = rs.data.curIRF;
                    else
                        result.IRFVector = [];
                    end
                end
                %about structure
                if(isfield(rs,'about'))
                    result.about = rs.about;
                end
                result.about.results_revision = 249; %aboutInfo.results_revision;
                %actual results
                if(isfield(rs,'results'))
                    result.results = rs.results;
                end
                
                %update parameters
                if(~isfield(rs,'parameters'))
                    %ascii result -> we're finished
                    result.resultType = 'ASCII';
                else
                    result.resultType = 'FluoDecayFit';
                    if(isfield(rs.parameters,'dynamic'))
                        if(isfield(rs.parameters.dynamic,'nScatter'))
                            result.parameters.volatile.nScatter = rs.parameters.dynamic.nScatter;
                        end
                        if(isfield(rs.parameters.dynamic,'nParams'))
                            result.parameters.volatile.nApproxParamsPerCh = rs.parameters.dynamic.nParams;
                        end
                        if(isfield(rs.parameters.dynamic,'cVec'))
                            result.parameters.volatile.cVec = rs.parameters.dynamic.cVec;
                        end
                        if(isfield(rs.parameters.dynamic,'cMask'))
                            result.parameters.volatile.cMask = rs.parameters.dynamic.cMask;
                        end
                    end
                    if(isfield(rs.parameters,'basic'))
                        result.parameters.basic_fit = rs.parameters.basic;
                    end
                    if(isfield(rs.parameters,'init'))
                        result.parameters.init_fit = rs.parameters.init;
                    end
                    if(isfield(rs.parameters,'pixel'))
                        result.parameters.pixel_fit = rs.parameters.pixel;
                    end
                    if(isfield(rs.parameters,'optimization'))
                        result.parameters.optimization = rs.parameters.optimization;
                    end
                    if(isfield(rs.parameters,'bounds'))
                        result.parameters.bounds = rs.parameters.bounds;
                    end
                    if(isfield(rs.parameters,'preProcessing'))
                        result.parameters.pre_processing = rs.parameters.preProcessing;
                    end
                    if(isfield(rs.parameters,'computation'))
                        result.parameters.computation = rs.parameters.computation;
                    end
                end
                %if ASCII result: make about info complete and we're finished
                if(strcmp(result.resultType,'ASCII'))
                    result.about.config_revision = 100;
                    result.about.client_revision = 100;
                    result.about.core_revision = 100;
                end
                %make struct for new data file
                data.revision = aboutInfo.measurement_revision;
                data.channel = result.channel;
                if(isfield(rs,'data'))
                    if(isfield(rs.data,'time'))
                        data.fluoFileInfo.tacRange = rs.data.time(end)/1000;
                        data.fluoFileInfo.nrTimeChannels = length(rs.data.time);
                    else
                        data.fluoFileInfo.tacRange = 12.5084; %just some default value
                        data.fluoFileInfo.nrTimeChannels = 1024; %just some default value
                    end
                    if(isfield(rs.data,'fluo'))
                        if(isfield(rs.data.fluo,'curFile'))
                            [~, name, ext] = fileparts(rs.data.fluo.curFile);
                            result.sourceFile = [name ext];
                        end
                        if(isfield(rs.data.fluo,'nrChannels'))
                            data.fluoFileInfo.nrSpectralChannels = rs.data.fluo.nrChannels;
                        else
                            data.fluoFileInfo.nrSpectralChannels = result.channel; %just some default value
                        end
                        %raw data was not saved in old results, approximate shape, fill the rest with zeros
                        if(isfield(rs.data.fluo,'cut') && isfield(rs.data.fluo,'rawFlat'))
                            roi = result.roiCoordinates;
                            result.results.pixel.Intensity = rs.data.fluo.rawFlat(roi(3):roi(4),roi(1):roi(2));
                            data.rawData = zeros(size(rs.data.fluo.rawFlat,1),size(rs.data.fluo.rawFlat,2),data.fluoFileInfo.nrTimeChannels,'uint16');
                            data.rawData(roi(3):roi(4),roi(1):roi(2),:) = rs.data.fluo.cut;
                            %we don't have the true raw data anymore, cut data is already binned
                            %workaround:
                            result.parameters.pre_processing.roiBinning = 0;
                        else
                            data.rawData = [];
                        end
                    end
                end
                data.sourceFile = result.sourceFile;
            end
            %% rev2xx result
            if(isfield(rs,'result'))
                result = rs.result;                
            elseif(isempty(result) && isfield(rs,'about') && isfield(rs.about,'results_revision') && rs.about.results_revision >= 200)
                result = rs;
            end
            %if ASCII result: complete about info
            if(strcmp(result.resultType,'ASCII'))
                result.about.config_revision = 100;
                result.about.client_revision = 100;
                result.about.core_revision = 100;
                %result.measurement_revision = 100;
                if(isfield(result.results,'pixel'))
                    result.parameters.basicFit.nExp = sum(strncmpi('Amplitude',fieldnames(result.results.pixel),9));
                end
                result.IRFName = '';
                result.IRFVector = [];
                result.sourceFile = '';
            end
            if(result.about.results_revision == 200)
                %we have to rename a few parameter fields
                if(isfield(result.parameters,'basicFit'))
                    result.parameters.basic_fit = result.parameters.basicFit;
                    result.parameters = rmfield(result.parameters,{'basicFit'});
                end
                if(isfield(result.parameters,'init'))
                    result.parameters.init_fit = result.parameters.init;
                    result.parameters = rmfield(result.parameters,{'init'});
                end
                if(isfield(result.parameters,'initFit'))
                    result.parameters.init_fit = result.parameters.initFit;
                    result.parameters = rmfield(result.parameters,{'initFit'});
                end
                if(isfield(result.parameters,'pixel'))
                    result.parameters.pixel_fit = result.parameters.pixel;
                    result.parameters = rmfield(result.parameters,{'pixel'});
                end
                if(isfield(result.parameters,'pixelFit'))
                    result.parameters.pixel_fit = result.parameters.pixelFit;
                    result.parameters = rmfield(result.parameters,{'pixelFit'});
                end
            end
            if(result.about.results_revision < 220 && strcmp(result.resultType,'FluoDecayFit'))
                %move reflection mask, add iVec
                %take the reflection mask from pixel result, we simply don't expect/support init only results...
                if(isfield(result.results,'reflectionMask'))
                    result.results.reflectionMask = result.results.pixel.reflectionMask;
                    result.results.pixel = rmfield(result.results.pixel,{'reflectionMask','cMask','cVec'});
                end
                %add optimizer initialization (guess values)                
                result.results.pixel.iVec = zeros(size(result.results.pixel.x_vec));
                for i = 1:result.parameters.basic_fit.nExp
                    ag = sprintf('AmplitudeGuess%d',i);
                    tg = sprintf('TauGuess%d',i);
                    result.results.init.(ag) = 0;
                    result.results.init.(tg) = 0;
                    result.results.pixel.(ag) = zeros(size(result.results.pixel.Amplitude1));
                    result.results.pixel.(tg) = zeros(size(result.results.pixel.Amplitude1));
                end
            end
            if(result.about.results_revision < 238 && strcmp(result.resultType,'FluoDecayFit'))
                %move parameters related to initialization fit
                bp = result.parameters.basic_fit;
                ip = result.parameters.init_fit;
                if(isfield(bp,'fixHShiftGridSize'))
                    ip.gridSize = bp.fixHShiftGridSize;
                    bp = rmfield(bp,{'fixHShiftGridSize'});
                end
                if(isfield(bp,'initGridPhotons'))
                    ip.gridPhotons = bp.initGridPhotons;
                    bp = rmfield(bp,{'initGridPhotons'});
                end
                if(~isfield(bp,'scatterEnable'))
                    bp.scatterEnable = 0;
                    bp.scatterStudy = '';
                    bp.scatterIRF = 0;
                end
                result.parameters.basic_fit = bp;
                result.parameters.init_fit = ip;
                
            end
            if(result.about.results_revision < 240 && strcmp(result.resultType,'FluoDecayFit'))
                fileInfo.timeChannelWidth = 12.5084 / 1024 * 1000; %we simply assume 80 MHz @ 1024 channels
                fileInfo.nrTimeChannels = 1024;
                fileInfo.channel = result.channel;
                fileInfo.nrSpectralChannels = result.channel;
                params.basicFit = result.parameters.basic_fit;
                params.pixelFit = result.parameters.pixel_fit;
                params.bounds = result.parameters.bounds;
                params.preProcessing = result.parameters.pre_processing;
                params.computation = result.parameters.computation;
                apObj = fluoPixelModel({result.IRFVector},fileInfo,params,result.channel);
                branchList = {'init','pixel'};
                for bi = 1:length(branchList)
                    branch = branchList{bi};
                    if(isfield(result.results,branch))
                        result.results.(branch).vShift = [];
                        result.parameters.volatile.nModelParamsPerCh = result.parameters.volatile.nModelParamsPerCh-1;
                        %xVec
                        xMat = result.results.(branch).x_vec;
                        xMat(:,:,end-1) = [];
                        xMatNew = zeros(size(xMat,1),size(xMat,2),apObj.volatilePixelParams.nModelParamsPerCh);
                        for i = 1:size(xMat,1)
                            [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents(squeeze(xMat(i,:,:))',false,result.channel);
                            hShift = hShift .* fileInfo.timeChannelWidth;
                            tcis = -tcis;
                            scShifts = -scShifts;
                            xMatNew(i,:,:) = apObj.getFullXVec(result.channel,amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset)';
                        end
                        result.results.(branch).x_vec = xMatNew;
                        %iVec
                        if(isfield(result.results.(branch),'iVec'))
                            iMat = result.results.(branch).iVec;
                            iMat(:,:,end-1) = [];
                            iMatNew = zeros(size(iMat,1),size(iMat,2),apObj.volatilePixelParams.nModelParamsPerCh);
                            for i = 1:size(iMat,1)
                                [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents(squeeze(iMat(i,:,:))',false,result.channel);
                                hShift = hShift .* fileInfo.timeChannelWidth;
                                tcis = -tcis;
                                scShifts = -scShifts;
                                iMatNew(i,:,:) = apObj.getFullXVec(result.channel,amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset)';
                            end
                            result.results.(branch).iVec = iMatNew;
                        end
                        %tci
                        nTci = find(params.basicFit.tciMask);
                        for i = nTci
                            strOld = sprintf('tc%d',i);
                            if(isfield(result.results.(branch),strOld))
                                result.results.(branch).(strOld) = -result.results.(branch).(strOld);
                            end
                        end
                        %hShift
                        if(isfield(result.results.(branch),'hShift'))
                            result.results.(branch).hShift = result.results.(branch).hShift .* fileInfo.timeChannelWidth;
                        end
                        if(isfield(result.results.(branch),'hShiftGuess'))
                            result.results.(branch).hShiftGuess = result.results.(branch).hShiftGuess .* fileInfo.timeChannelWidth;
                        end
                        %scatter
                        for i = 1:apObj.volatilePixelParams.nScatter
                            strOld = sprintf('ShiftScatter%d',i);
                            if(isfield(result.results.(branch),strOld))
                                result.results.(branch).(strOld) = -result.results.(branch).(strOld);
                            end
                        end
                    end
                end                
            end
            if(result.about.results_revision < 250)
                result.auxiliaryData.IRF.vector = result.IRFVector;
                result.auxiliaryData.IRF.name = result.IRFName;
                if(strcmp(result.resultType,'FluoDecayFit'))
                    result.auxiliaryData.scatter = repmat(result.IRFVector,1,result.parameters.volatile.nScatter); %we don't have the scatter data, use IRF instead so result will at least load
                else
                    result.auxiliaryData.scatter = [];
                end
                fileInfo.tacRange = 12.5084;%we simply assume 80 MHz @ 1024 channels
                fileInfo.nrTimeChannels = 1024;
                fileInfo.timeChannelWidth = 12.5084 / 1024 * 1000;
                fileInfo.nrSpectralChannels = result.channel;
                if(strcmp(result.resultType,'FluoDecayFit'))
                    fileInfo.reflectionMask = result.results.reflectionMask;
                else
                    fileInfo.reflectionMask = ones(fileInfo.nrTimeChannels,1);
                end
                fileInfo.StartPosition = 1;
                fileInfo.EndPosition = fileInfo.nrTimeChannels;
                fileInfo.channel = result.channel;
                result = rmfield(result,{'IRFVector','IRFName'});
                result.auxiliaryData.fileInfo = fileInfo;
                if(isfield(result.results,'pixel'))
                    fn = fieldnames(result.results.pixel);
                    if(~isempty(fn))
                        [YSz, XSz] = size(result.results.pixel.(fn{1}));
                    else
                        YSz = 0;
                        XSz = 0;
                    end
                else
                    YSz = 0;
                    XSz = 0;
                end
                result.size = [YSz, XSz];
            end
            if(result.about.results_revision < 251 && strcmp(result.resultType,'FluoDecayFit'))
                %rename scatter results
                branchList = {'init','pixel'};
                itemList = {'Shift','Amplitude','Offset'};
                for bi = 1:length(branchList)
                    branch = branchList{bi};
                    if(isfield(result.results,branch))
                        for i = 1:result.parameters.volatile.nScatter
                            for j = 1:length(itemList)
                                item = itemList{j};
                                strOld = sprintf('%sScatter%d',item,i);
                                if(isfield(result.results.(branch),strOld))
                                    strNew = sprintf('Scatter%s%d',item,i);
                                    result.results.(branch).(strNew) = result.results.(branch).(strOld);
                                    result.results.(branch) = rmfield(result.results.(branch),strOld);
                                end
                            end
                        end
                    end
                end                    
            end
            if(result.about.results_revision < 252)
                result.auxiliaryData.fileInfo = checkStructConsistency(result.auxiliaryData.fileInfo,measurementFile.getDefaultFileInfo());
            end
            if(result.about.results_revision < 253 && strcmp(result.resultType,'FluoDecayFit'))
                %oldIRFID = result.parameters.basic_fit.curIRFID;
                new = result.auxiliaryData.IRF.name;
                if(ischar(new) && length(new) > 4)
                    if(strcmp(new(end-3:end),'.asc'))
                        new(end-3:end) = '';
                    end
                    if(strcmp(new(1),'_'))
                        new(1) = '';
                    end
                    result.parameters.basic_fit.curIRFID = new;
                end                
            end
            if(result.about.results_revision < 254 && strcmp(result.resultType,'FluoDecayFit'))
                %aux data: ROIInfo was moved out of fileInfo
                result.auxiliaryData.measurementROIInfo = measurementFile.getDefaultROIInfo();
                if(isfield(result.auxiliaryData.fileInfo,'ROIDataType'))
                    result.auxiliaryData.measurementROIInfo.ROIDataType = result.auxiliaryData.fileInfo.ROIDataType;
                end
                if(isfield(result.auxiliaryData.fileInfo,'ROICoordinates'))
                    result.auxiliaryData.measurementROIInfo.ROICoordinates = result.auxiliaryData.fileInfo.ROICoordinates;
                end
                result.auxiliaryData.fileInfo = checkStructConsistency(result.auxiliaryData.fileInfo,measurementFile.getDefaultFileInfo());
            end
            if(result.about.results_revision < 255 && strcmp(result.resultType,'FluoDecayFit'))
                %figure of merrit computation parameters have changed
                if(isfield(result.parameters,'basic_fit') && isfield(result.parameters.basic_fit,'fittedChiWeighting') && result.parameters.basic_fit.fittedChiWeighting == 1)
                    result.parameters.basic_fit.chiWeightingMode = 3;
                    result.parameters.basic_fit = rmfield(result.parameters.basic_fit,{'fittedChiWeighting'});
                else
                    result.parameters.basic_fit.chiWeightingMode = 1;
                end
                if(isfield(result.parameters,'basic_fit') && isfield(result.parameters.basic_fit,'errorMode'))
                    result.parameters.basic_fit.errorMode = max(1,result.parameters.basic_fit.errorMode-1);
                else
                    result.parameters.basic_fit.errorMode = 1;
                end
            end
            %set current version
            result.about.results_revision = aboutInfo.results_revision;
        end
        
    end %methods(Static)
    
    methods (Abstract)
    end
end

